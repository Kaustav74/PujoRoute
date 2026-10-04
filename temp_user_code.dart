<USER_REQUEST>
Dart
import 'dart:math';

/// Representation of a Durga Puja pandal node.
class Pandal {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String zone;

  /// Priority indicator: Lower numbers represent higher prestige/crowd significance.
  /// E.g., 1 = Mega Pandal (Suruchi, Sreebhumi), 500 = Local Para Pandal.
  final int popularityRank;

  const Pandal({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.zone,
    this.popularityRank = 999,
  });
}

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

class HardenedPujoOptimizer {
  static const double _epsilon = 0.00001;
  static const double _earthRadiusMeters = 6371000.0;

  // Allows visiting an adjacent pandal within 250m even if slightly retrograde
  static const double _localClusterDetourThreshold = 250.0;

  /// Calculates geodesic distance between two points using the Haversine formula.
  static double distance(double lat1, double lon1, double lat2, double lon2) {
    final double dLat = _rad(lat2 - lat1);
    final double dLon = _rad(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return _earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * (pi / 180.0);

  /// Generates an ordered, non-looping pandal hopping circuit.
  ///
  /// Guarantees:
  /// 1. Uniqueness: No pandal is visited more than once.
  /// 2. Determinism: Identical inputs yield identical outputs.
  /// 3. Fixed Termination: Terminates at the closest feasible pandal to [homeLat, homeLng].
  /// 4. Cardinality: Returns exactly [requestedStops] unless directional dead-ends occur.
  static RoutingResult generateHomeBoundCircuit({
    required List<Pandal> pool,
    required double startLat,
    required double startLng,
    required double homeLat,
    required double homeLng,
    required int requestedStops,
  }) {
    if (pool.isEmpty || requestedStops <= 0) {
      return const RoutingResult(
        route: [],
        totalWalkingMeters: 0,
        walkToHomeMeters: 0,
        fellBackEarly: true,
        diagnostics: 'Input pool empty or invalid target stops requested.',
      );
    }

    // 1. Deduplicate input pool by ID
    final Map<String, Pandal> uniqueMap = {for (var p in pool) p.id: p};
    final List<Pandal> candidates = uniqueMap.values.toList();

    // 2. Lock & reserve the terminal pandal closest to home
    candidates.sort((a, b) {
      final dA = distance(a.lat, a.lng, homeLat, homeLng);
      final dB = distance(b.lat, b.lng, homeLat, homeLng);
      if ((dA - dB).abs() > _epsilon) return dA.compareTo(dB);
      if (a.popularityRank != b.popularityRank) {
        return a.popularityRank.compareTo(b.popularityRank);
      }
      return a.id.compareTo(b.id);
    });

    final Pandal terminalPandal = candidates.first;
    final double terminalToHomeMeters = distance(
      terminalPandal.lat,
      terminalPandal.lng,
      homeLat,
      homeLng,
    );

    // 3. Handle requestedStops == 1 edge case
    if (requestedStops == 1) {
      return RoutingResult(
        route: [terminalPandal],
        totalWalkingMeters: 0,
        walkToHomeMeters: terminalToHomeMeters,
        fellBackEarly: false,
        diagnostics: 'Single-stop circuit locked to terminal home-anchor.',
      );
    }

    // 4. Handle candidates count <= requestedStops edge case
    if (candidates.length <= requestedStops) {
      candidates.sort((a, b) {
        final distA = distance(startLat, startLng, a.lat, a.lng);
        final distB = distance(startLat, startLng, b.lat, b.lng);
        if ((distA - distB).abs() > _epsilon) return distA.compareTo(distB);
        return a.popularityRank.compareTo(b.popularityRank);
      });

      return RoutingResult(
        route: candidates,
        totalWalkingMeters: _computePathDistance(candidates),
        walkToHomeMeters: distance(
          candidates.last.lat,
          candidates.last.lng,
          homeLat,
          homeLng,
        ),
        fellBackEarly: candidates.length < requestedStops,
        diagnostics: 'Available candidates (${candidates.length}) <= requested ($requestedStops). All used.',
      );
    }

    // Isolate intermediate candidates by excluding the reserved terminal
    final Map<String, Pandal> intermediateMap = {
      for (var p in candidates) if (p.id != terminalPandal.id) p.id: p
    };

    // 5. Select origin-balanced start node (prevents deep retrograde launches)
    final List<Pandal> startPool = intermediateMap.values.toList();
    startPool.sort((a, b) {
      final dStartA = distance(startLat, startLng, a.lat, a.lng);
      final dStartB = distance(startLat, startLng, b.lat, b.lng);
      final dTermA = distance(a.lat, a.lng, terminalPandal.lat, terminalPandal.lng);
      final dTermB = distance(b.lat, b.lng, terminalPandal.lat, terminalPandal.lng);

      // Score balances proximity to user with progress toward terminal
      final scoreA = dStartA + (0.40 * dTermA);
      final scoreB = dStartB + (0.40 * dTermB);

      if ((scoreA - scoreB).abs() > _epsilon) return scoreA.compareTo(scoreB);
      if (a.popularityRank != b.popularityRank) {
        return a.popularityRank.compareTo(b.popularityRank);
      }
      return a.id.compareTo(b.id);
    });

    final Pandal startPandal = startPool.first;
    final List<Pandal> route = [startPandal];
    intermediateMap.remove(startPandal.id);

    // 6. Directional corridor search with O(1) visited-set removals
    final int intermediateTarget = requestedStops - 1;
    Pandal current = startPandal;

    while (route.length < intermediateTarget && intermediateMap.isNotEmpty) {
      final double currentDistToTerminal = distance(
        current.lat,
        current.lng,
        terminalPandal.lat,
        terminalPandal.lng,
      );

      Pandal? bestCandidate;
      double minHeuristicScore = double.infinity;

      for (final candidate in intermediateMap.values) {
        final double stepDist = distance(current.lat, current.lng, candidate.lat, candidate.lng);
        final double candidateDistToTerminal = distance(
          candidate.lat,
          candidate.lng,
          terminalPandal.lat,
          terminalPandal.lng,
        );

        final bool pullsTowardTerminal =
            candidateDistToTerminal < (currentDistToTerminal + _epsilon);
        final bool isImmediateClusterNeighbor = stepDist <= _localClusterDetourThreshold;

        // Discard nodes moving backward unless within the immediate walking cluster
        if (!pullsTowardTerminal && !isImmediateClusterNeighbor) {
          continue;
        }

        final double score = stepDist + (0.30 * candidateDistToTerminal);

        if (score < (minHeuristicScore - _epsilon)) {
          minHeuristicScore = score;
          bestCandidate = candidate;
        } else if ((score - minHeuristicScore).abs() <= _epsilon) {
          if (bestCandidate == null || candidate.popularityRank < bestCandidate.popularityRank) {
            bestCandidate = candidate;
          } else if (candidate.popularityRank == bestCandidate.popularityRank &&
              candidate.id.compareTo(bestCandidate.id) < 0) {
            bestCandidate = candidate;
          }
        }
      }

      if (bestCandidate != null) {
        route.add(bestCandidate);
        intermediateMap.remove(bestCandidate.id);
        current = bestCandidate;
      } else {
        break; // Directional corridor exhausted
      }
    }

    // 7. Append the locked home terminal
    route.add(terminalPandal);

    final bool fellBackEarly = route.length < requestedStops;
    final String diag = fellBackEarly
        ? 'Directional constraints curtailed route at ${route.length}/$requestedStops stops to eliminate backtracking.'
        : 'Successfully generated full directional route with $requestedStops stops ending near home.';

    return RoutingResult(
      route: route,
      totalWalkingMeters: _computePathDistance(route),
      walkToHomeMeters: terminalToHomeMeters,
      fellBackEarly: fellBackEarly,
      diagnostics: diag,
    );
  }

  static double _computePathDistance(List<Pandal> path) {
    if (path.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      sum += distance(path[i].lat, path[i].lng, path[i + 1].lat, path[i + 1].lng);
    }
    return sum;
  }
}
Key Refactorings Applied

Origin-Balanced Start: Replaced the greedy start selection with dStart + 0.40 * dTerminal, preventing the algorithm from kicking off into a dead-end direction opposite home.

Single-Stop Contract: Added an explicit branch for requestedStops == 1 that returns [terminalPandal] directly with totalWalkingMeters: 0.

O(1) Hash Map Lookups: Replaced List.removeWhere() with Map.remove(id), eliminating repeated array scanning and reallocation during path traversal.

Dual Distance Reporting: RoutingResult now separates totalWalkingMeters (the pandal-to-pandal walking itinerary) from walkToHomeMeters (the final leg from the last pandal to your actual front door).
Make sure the pandals are not reduced while causin backtracking, just  it should  be an opttimised route, like in the above program. do waht is necessary
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-09-18T20:20:11+05:30.
</ADDITIONAL_METADATA>
<USER_SETTINGS_CHANGE>
The user changed setting `Model Selection` from Gemini 3.1 Pro (High) to Gemini 3.8 Flash (High). No need to comment on this change if the user doesn't ask about it. If reporting what model you are, please use a human readable name instead of the exact string.
</USER_SETTINGS_CHANGE>