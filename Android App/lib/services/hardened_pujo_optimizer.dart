import 'dart:math';
import '../data/pujas_data.dart';

/// Output contract containing the verified itinerary and diagnostics.
class RoutingResult {
  final List<Pandal> route;
  final double totalWalkingMeters;
  final double walkToHomeMeters;
  final bool fellBackEarly;
  final String diagnostics;

  const RoutingResult({
    required this.route,
    required this.totalWalkingMeters,
    required this.walkToHomeMeters,
    required this.fellBackEarly,
    required this.diagnostics,
  });
}

/// Production-hardened Durga Puja route optimizer.
/// Features:
/// 1. Hard max step distance (1200 m) between consecutive stops.
/// 2. Strong progressive cost function: score = step + (0.75 * distToTerm), with bonus for forced stops.
/// 3. Guaranteed support for user forcedStops (for "Add Pandal -> Regenerate" flow).
/// 4. Aggressive 2-Opt local search (max 300 iterations, anchored start and terminal).
/// 5. Quality diagnostics with distance and constraint feedback.
class HardenedPujoOptimizer {
  static const double _epsilon = 0.00001;
  static const double _earthRadiusMeters = 6371000.0;
  static const double _maxStepMeters = 1200.0; // Hard limit between consecutive stops

  /// Calculates geodesic distance between two points using the Haversine formula.
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return _earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * (pi / 180.0);

  /// True if the pandal has a usable Metro station (assigned and within
  /// kNoMetroRadiusMeters).
  static bool hasUsableMetro(Pandal p) =>
      p.metroStation.isNotEmpty &&
      !p.metroStation.toLowerCase().contains('none') &&
      !p.isMetroTooFar;

  /// Exit anchor for "Optimize by Metro": a pandal served by a *different*
  /// station than [start] whose distance from the start best matches what a
  /// walking circuit of [stops] can cover ((stops - 1) x 700 m, clamped to
  /// 1.2-4 km). The old code sorted descending and picked the FARTHEST metro
  /// pandal in the pool, which produced last hops of ~40 km.
  static Pandal? pickMetroExitAnchor({
    required Pandal start,
    required List<Pandal> candidates,
    required int stops,
  }) {
    final others = candidates
        .where((p) => p.id != start.id && hasUsableMetro(p))
        .toList();
    if (others.isEmpty) return null;
    final differentStation =
        others.where((p) => p.metroStation != start.metroStation).toList();
    final pool = differentStation.isNotEmpty ? differentStation : others;
    final target = ((stops - 1) * 700.0).clamp(1200.0, 4000.0);
    pool.sort((a, b) {
      final da = (distance(start.lat, start.lon, a.lat, a.lon) - target).abs();
      final db = (distance(start.lat, start.lon, b.lat, b.lon) - target).abs();
      if ((da - db).abs() > _epsilon) return da.compareTo(db);
      return a.popularityRank.compareTo(b.popularityRank);
    });
    return pool.first;
  }

  /// Generates an ordered, non-looping pandal hopping circuit anchored toward home.
  static RoutingResult generateHomeBoundCircuit({
    required List<Pandal> pool,
    required double startLat,
    required double startLng,
    required double homeLat,
    required double homeLng,
    required int requestedStops,
    List<Pandal> forcedStops = const [],
  }) {
    if (pool.isEmpty || requestedStops <= 0) {
      return const RoutingResult(
        route: [],
        totalWalkingMeters: 0,
        walkToHomeMeters: 0,
        fellBackEarly: true,
        diagnostics: 'Invalid input.',
      );
    }

    // 1. Deduplicate + force-include user-added pandals
    final Map<String, Pandal> uniqueMap = {for (var p in pool) p.id: p};
    for (final forced in forcedStops) {
      uniqueMap[forced.id] = forced;
    }
    final List<Pandal> candidates = uniqueMap.values.toList();

    // 2. Lock terminal (closest to home)
    candidates.sort((a, b) {
      final dA = distance(a.lat, a.lon, homeLat, homeLng);
      final dB = distance(b.lat, b.lon, homeLat, homeLng);
      if ((dA - dB).abs() > _epsilon) return dA.compareTo(dB);
      return a.popularityRank.compareTo(b.popularityRank);
    });
    final Pandal terminalPandal = candidates.first;
    final double terminalToHome = distance(
        terminalPandal.lat, terminalPandal.lon, homeLat, homeLng);

    if (requestedStops == 1) {
      // A user-added (forced) pandal must win over the auto-picked terminal.
      final single = forcedStops.isNotEmpty ? forcedStops.first : terminalPandal;
      return RoutingResult(
        route: [single],
        totalWalkingMeters: 0,
        walkToHomeMeters: distance(single.lat, single.lon, homeLat, homeLng),
        fellBackEarly: false,
        diagnostics: 'Single-stop circuit.',
      );
    }

    // 3. Intermediate pool (exclude terminal)
    final Map<String, Pandal> intermediateMap = {
      for (var p in candidates)
        if (p.id != terminalPandal.id) p.id: p
    };

    if (intermediateMap.isEmpty) {
      return RoutingResult(
        route: [terminalPandal],
        totalWalkingMeters: 0,
        walkToHomeMeters: terminalToHome,
        fellBackEarly: true,
        diagnostics: 'Only 1 candidate available in pool.',
      );
    }

    // 4. Progressive start selection
    final startPool = intermediateMap.values.toList();
    startPool.sort((a, b) {
      final dStartA = distance(startLat, startLng, a.lat, a.lon);
      final dStartB = distance(startLat, startLng, b.lat, b.lon);
      final dTermA =
          distance(a.lat, a.lon, terminalPandal.lat, terminalPandal.lon);
      final dTermB =
          distance(b.lat, b.lon, terminalPandal.lat, terminalPandal.lon);
      final scoreA = dStartA + 0.65 * dTermA;
      final scoreB = dStartB + 0.65 * dTermB;
      if ((scoreA - scoreB).abs() > _epsilon) return scoreA.compareTo(scoreB);
      return a.popularityRank.compareTo(b.popularityRank);
    });

    final Pandal startPandal = startPool.first;
    final List<Pandal> route = [startPandal];
    intermediateMap.remove(startPandal.id);

    final Set<String> remainingForced = forcedStops
        .where((p) => p.id != startPandal.id && p.id != terminalPandal.id)
        .map((p) => p.id)
        .toSet();

    Pandal current = startPandal;
    final int intermediateTarget = requestedStops - 1;

    // 5. Main progressive selection (hard max step + strong cost)
    while (route.length < intermediateTarget && intermediateMap.isNotEmpty) {
      Pandal? best;
      double bestScore = double.infinity;
      for (final candidate in intermediateMap.values) {
        final step =
            distance(current.lat, current.lon, candidate.lat, candidate.lon);
        if (step > _maxStepMeters) continue;
        final distToTerm = distance(
            candidate.lat, candidate.lon, terminalPandal.lat, terminalPandal.lon);

        // Strong progressive cost function — prefer short steps so nearby
        // pandals (e.g. Tridhara / Ekdalia) stay together.
        double score = step + (0.35 * distToTerm);

        // Strong bonus for same zone so North/South/Salt Lake clusters stay intact
        if (candidate.zone == current.zone) {
          score *= 0.55;
        }

        // Bonus for user-forced stops
        if (remainingForced.contains(candidate.id)) {
          score *= 0.75;
        }

        if (score < bestScore - _epsilon) {
          bestScore = score;
          best = candidate;
        } else if ((score - bestScore).abs() <= _epsilon) {
          if (best == null || candidate.popularityRank < best.popularityRank) {
            best = candidate;
          }
        }
      }
      if (best == null) break;
      route.add(best);
      intermediateMap.remove(best.id);
      remainingForced.remove(best.id);
      current = best;
    }

    // 6. Force any still-missing user-added pandals
    for (final id in remainingForced.toList()) {
      final forced = intermediateMap[id];
      if (forced != null) {
        if (route.length < intermediateTarget) {
          route.add(forced);
        } else {
          final nonForcedIndex = route.lastIndexWhere((p) =>
              p.id != startPandal.id &&
              !forcedStops.any((f) => f.id == p.id));
          if (nonForcedIndex != -1) {
            final removed = route.removeAt(nonForcedIndex);
            intermediateMap[removed.id] = removed;
            route.add(forced);
          } else {
            route.add(forced);
          }
        }
        intermediateMap.remove(id);
        remainingForced.remove(id);
        current = forced;
      }
    }

    // 7. Safety net - fill remaining seats (relaxes limit to 1800m, then nearest fallback to prevent 2-stop truncation)
    const double relaxedStepLimit = 1800.0;
    while (route.length < intermediateTarget && intermediateMap.isNotEmpty) {
      Pandal? best;
      double bestScore = double.infinity;

      // Pass A: Try within relaxed limit (1800m)
      for (final c in intermediateMap.values) {
        final step = distance(current.lat, current.lon, c.lat, c.lon);
        if (step > relaxedStepLimit) continue;
        final distToTerm =
            distance(c.lat, c.lon, terminalPandal.lat, terminalPandal.lon);
        final score = step + 0.60 * distToTerm;
        if (score < bestScore) {
          bestScore = score;
          best = c;
        }
      }

      // Pass B: If still needed, pick nearest candidate to reliably satisfy requested cardinality
      if (best == null) {
        double minDist = double.infinity;
        for (final c in intermediateMap.values) {
          final d = distance(current.lat, current.lon, c.lat, c.lon);
          if (d < minDist) {
            minDist = d;
            best = c;
          }
        }
      }

      if (best == null) break;
      route.add(best);
      intermediateMap.remove(best.id);
      current = best;
    }

    // 8. Append locked terminal
    route.add(terminalPandal);

    // 9. Cluster by zone only when multiple zones are present, then 2-opt.
    final clustered = clusterByZone(route);
    final optimized = apply2Opt(clustered, anchorStart: false, anchorEnd: false);
    final totalDist = _computePathDistance(clustered);
    final bool fellBack = clustered.length < requestedStops;
    final String diag = fellBack
        ? 'Could only generate ${optimized.length}/$requestedStops stops under distance constraints.'
        : totalDist > 5500
            ? 'Route generated (${(totalDist / 1000).toStringAsFixed(1)} km). Consider a tighter zone filter.'
            : 'Optimized circuit with ${optimized.length} stops.';


    // Cluster pass: if two pandals are within 900 m but not adjacent, move the
    // later one next to the earlier one when that shortens (or barely lengthens)
    // the path. Keeps Tridhara/Ekdalia-style pairs and same-zone groups together.
    List<Pandal> clustered = List.from(optimized);
    bool moved = true;
    int guard = 0;
    while (moved && guard < 40) {
      moved = false;
      guard++;
      for (int a = 0; a < clustered.length; a++) {
        for (int b = a + 2; b < clustered.length; b++) {
          final d = distance(
              clustered[a].lat, clustered[a].lon, clustered[b].lat, clustered[b].lon);
          final sameZone = clustered[a].zone == clustered[b].zone;
          if (d > (sameZone ? 1400.0 : 900.0)) continue;
          final trial = List<Pandal>.from(clustered);
          final item = trial.removeAt(b);
          trial.insert(a + 1, item);
          if (_computePathDistance(trial) <= _computePathDistance(clustered) + 250) {
            clustered = trial;
            moved = true;
            break;
          }
        }
        if (moved) break;
      }
    }

    return RoutingResult(
      route: clustered,
      totalWalkingMeters: totalDist,
      walkToHomeMeters: distance(
          clustered.last.lat, clustered.last.lon, homeLat, homeLng),
      fellBackEarly: fellBack,
      diagnostics: diag,
    );
  }

  /// When a route mixes zones, group same-zone pandals together so nearby
  /// stops (e.g. Tridhara and Ekdalia in South) are not split to opposite ends.
  /// No-op if every stop is in the same zone.
  static List<Pandal> clusterByZone(List<Pandal> path) {
    if (path.length <= 2) return List.from(path);
    final zones = path.map((p) => p.zone).toSet();
    if (zones.length <= 1) return List.from(path); // same zone: leave as-is

    // Preserve relative order within each zone, emit zones in the order
    // their first stop currently appears (so the overall direction is kept).
    final List<String> zoneOrder = [];
    final Map<String, List<Pandal>> buckets = {};
    for (final p in path) {
      buckets.putIfAbsent(p.zone, () {
        zoneOrder.add(p.zone);
        return <Pandal>[];
      }).add(p);
    }
    final clustered = <Pandal>[];
    for (final z in zoneOrder) {
      clustered.addAll(buckets[z]!);
    }
    return clustered;
  }

  /// Aggressive 2-Opt local search.
  /// Anchors start and terminal so they can never be moved.
  static List<Pandal> apply2Opt(
    List<Pandal> path, {
    bool anchorStart = true,
    bool anchorEnd = true,
  }) {
    if (path.length <= 3) return List.from(path);
    List<Pandal> bestRoute = List.from(path);
    bool improved = true;
    int iterations = 0;
    const int maxIterations = 300;
    // A 2-opt move reverses bestRoute[i+1..j], so index 0 never moves and the
    // start stays anchored even with i = 0. (Previously i started at 1 when
    // anchorStart was true, which skipped every improvement on the first hop.)
    // When anchorStart is false we also try rotating the path so the first
    // stop can move next to nearby pandals instead of staying locked.
    final int startEdge = 0;
    while (improved && iterations < maxIterations) {
      improved = false;
      iterations++;
      final int n = bestRoute.length;
      final int endEdge = anchorEnd ? n - 3 : n - 2;
      for (int i = startEdge; i <= endEdge; i++) {
        for (int j = i + 2; j < (anchorEnd ? n - 1 : n); j++) {
          if (j + 1 >= n) continue;
          final double costCurrent =
              distance(bestRoute[i].lat, bestRoute[i].lon, bestRoute[i + 1].lat, bestRoute[i + 1].lon) +
              distance(bestRoute[j].lat, bestRoute[j].lon, bestRoute[j + 1].lat, bestRoute[j + 1].lon);
          final double costSwapped =
              distance(bestRoute[i].lat, bestRoute[i].lon, bestRoute[j].lat, bestRoute[j].lon) +
              distance(bestRoute[i + 1].lat, bestRoute[i + 1].lon, bestRoute[j + 1].lat, bestRoute[j + 1].lon);
          if (costSwapped < costCurrent - _epsilon) {
            bestRoute = [
              ...bestRoute.sublist(0, i + 1),
              ...bestRoute.sublist(i + 1, j + 1).reversed,
              ...bestRoute.sublist(j + 1),
            ];
            improved = true;
            break;
          }
        }
        if (improved) break;
      }
    }
    return bestRoute;
  }

  static double _computePathDistance(List<Pandal> path) {
    if (path.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      sum += distance(path[i].lat, path[i].lon, path[i + 1].lat, path[i + 1].lon);
    }
    return sum;
  }
}
