import 'dart:math';
import '../data/pujas_data.dart';

class PandalDeduplicationService {
  PandalDeduplicationService._();
  static final PandalDeduplicationService instance = PandalDeduplicationService._();

  static const Set<String> kNoiseTokens = {
    'durga', 'puja', 'pujo', 'club', 'clubs', 'sangha', 'samity', 'samiti',
    'association', 'sarbojanin', 'committee', 'youth', 'utsav', 'the', 'and', 'o',
    'ground', 'grounds', 's', 'durgotsab', 'sarodotsab', 'baroari', 'mandir',
  };

  Set<String> extractCoreTokens(String name) {
    final clean = name.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return words.where((w) => !kNoiseTokens.contains(w)).toSet();
  }

  double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;
    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double jaroWinkler(String s1, String s2) {
    if (s1 == s2) return 1.0;
    final int len1 = s1.length;
    final int len2 = s2.length;
    if (len1 == 0 || len2 == 0) return 0.0;

    final int matchDistance = (max(len1, len2) ~/ 2) - 1;
    final List<bool> s1Matches = List.filled(len1, false);
    final List<bool> s2Matches = List.filled(len2, false);

    int matches = 0;
    for (int i = 0; i < len1; i++) {
      final int start = max(0, i - matchDistance);
      final int end = min(i + matchDistance + 1, len2);
      for (int j = start; j < end; j++) {
        if (s2Matches[j]) continue;
        if (s1[i] == s2[j]) {
          s1Matches[i] = true;
          s2Matches[j] = true;
          matches++;
          break;
        }
      }
    }

    if (matches == 0) return 0.0;

    int transpositions = 0;
    int k = 0;
    for (int i = 0; i < len1; i++) {
      if (!s1Matches[i]) continue;
      while (!s2Matches[k]) {
        k++;
      }
      if (s1[i] != s2[k]) transpositions++;
      k++;
    }

    final double jaro = (matches / len1 + matches / len2 + (matches - transpositions / 2.0) / matches) / 3.0;

    int prefix = 0;
    for (int i = 0; i < min(4, min(len1, len2)); i++) {
      if (s1[i] == s2[i]) {
        prefix++;
      } else {
        break;
      }
    }

    return jaro + prefix * 0.1 * (1.0 - jaro);
  }

  bool isDuplicatePair(Pandal p1, Pandal p2) {
    final double d = haversineMeters(p1.lat, p1.lon, p2.lat, p2.lon);
    final Set<String> t1 = extractCoreTokens(p1.name);
    final Set<String> t2 = extractCoreTokens(p2.name);

    if (t1.isEmpty || t2.isEmpty) return false;

    // Condition C (Never Merge): If core unique roots differ (e.g. ekdalia vs singhi), preserve both stops.
    final bool isSubset = t1.containsAll(t2) || t2.containsAll(t1);
    final List<String> sorted1 = t1.toList()..sort();
    final List<String> sorted2 = t2.toList()..sort();
    final String s1 = sorted1.join(' ');
    final String s2 = sorted2.join(' ');
    final double jw = jaroWinkler(s1, s2);

    final Set<String> intersection = t1.intersection(t2);
    if (intersection.isEmpty && !isSubset) {
      return false;
    }

    // Condition A (Definite Duplicate): d <= 25m AND Jaro-Winkler similarity >= 0.70 AND distinguishing unique roots do not conflict
    if (d <= 25.0 && jw >= 0.70) {
      final Set<String> diff1 = t1.difference(t2);
      final Set<String> diff2 = t2.difference(t1);
      if (diff1.isNotEmpty && diff2.isNotEmpty) {
        return false;
      }
      return true;
    }

    // Condition B (Coordinate Drift Duplicate): 25m < d <= 65m (or up to 200m for coordinate drift) AND one set of core tokens is a strict subset of the other
    if (d > 25.0 && d <= 200.0 && isSubset) {
      return true;
    }

    return false;
  }

  Pandal pickRicherEntry(Pandal a, Pandal b) {
    int scoreA = 0;
    int scoreB = 0;

    // History richness (substantial difference)
    if (a.history.length - b.history.length > 30) scoreA += 2;
    if (b.history.length - a.history.length > 30) scoreB += 2;

    if (a.metroStation.isNotEmpty && !a.metroStation.toLowerCase().contains('none')) scoreA += 2;
    if (b.metroStation.isNotEmpty && !b.metroStation.toLowerCase().contains('none')) scoreB += 2;

    if (a.landmark.isNotEmpty) scoreA += 1;
    if (b.landmark.isNotEmpty) scoreB += 1;

    // Prefer cleaner canonical ID (avoid '-clubs-' and shorter canonical slug)
    if (!a.id.contains('clubs') && b.id.contains('clubs')) scoreA += 2;
    if (!b.id.contains('clubs') && a.id.contains('clubs')) scoreB += 2;
    if (a.id.length < b.id.length) scoreA += 1;
    if (b.id.length < a.id.length) scoreB += 1;

    return scoreA >= scoreB ? a : b;
  }

  List<Pandal>? _cachedDeduplicated;

  List<Pandal> deduplicate(List<Pandal> source) {
    if (_cachedDeduplicated != null && source.length >= 500) {
      return List.from(_cachedDeduplicated!);
    }

    final List<Pandal> result = [];
    final Set<String> mergedIds = {};

    for (int i = 0; i < source.length; i++) {
      final p1 = source[i];
      if (mergedIds.contains(p1.id)) continue;

      Pandal best = p1;
      for (int j = i + 1; j < source.length; j++) {
        final p2 = source[j];
        if (mergedIds.contains(p2.id)) continue;

        if (isDuplicatePair(best, p2)) {
          mergedIds.add(p2.id);
          best = pickRicherEntry(best, p2);
        }
      }
      result.add(best);
    }
    
    if (source.length >= 500) {
      _cachedDeduplicated = List.from(result);
    }
    
    return result;
  }
}
