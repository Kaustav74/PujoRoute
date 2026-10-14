import 'dart:math' as math;
import '../data/pujas_data.dart';
import '../services/pandal_deduplication_service.dart';
import '../services/session_service.dart';
import 'pandal_repository.dart';

/// Production-grade unified search service for PujoRoute.
/// Powers Map search, Circuit Studio stop search, and Pandal Passport autocomplete.
class PandalSearchService {
  PandalSearchService._();
  static final PandalSearchService instance = PandalSearchService._();

  /// Canonical alias mapping for transliteration variations in Bengali/English.
  static const Map<String, List<String>> _kAliases = {
    'puja': ['pujo', 'pujas', 'durgapuja', 'durgapujo'],
    'pujo': ['puja', 'pujas', 'durgapuja', 'durgapujo'],
    'sarbojanin': ['sarbojonin', 'sarbajanin', 'sarvajanin'],
    'sarbojonin': ['sarbojanin', 'sarbajanin', 'sarvajanin'],
    'sarbajanin': ['sarbojanin', 'sarbojonin', 'sarvajanin'],
    'samity': ['samiti', 'samitee', 'committee'],
    'samiti': ['samity', 'samitee', 'committee'],
    'committee': ['samity', 'samiti', 'samitee'],
    'sangha': ['shangha', 'club'],
    'shangha': ['sangha', 'club'],
    'palli': ['pally'],
    'pally': ['palli'],
    'durgotsab': ['durgotsav', 'durgotsabh'],
    'durgotsav': ['durgotsab', 'durgotsabh'],
    'bagbazar': ['baghbazar', 'bag bazar'],
    'baghbazar': ['bagbazar', 'bag bazar'],
    'sobhabazar': ['shobhabazar', 'sovabazar', 'shovabazar'],
    'shobhabazar': ['sobhabazar', 'sovabazar', 'shovabazar'],
    'kumartuli': ['kumortuli', 'kumar tuli'],
    'kumortuli': ['kumartuli', 'kumar tuli'],
    'mudiali': ['mudeali', 'mudi ali'],
    'mudeali': ['mudiali', 'mudi ali'],
    'bhowanipore': ['bhawanipore', 'bhowanipur', 'bhawanipur'],
    'bhowanipur': ['bhowanipore', 'bhawanipore', 'bhawanipur'],
    'baroari': ['barowari'],
    'barowari': ['baroari'],
    'utsav': ['utsab'],
    'utsab': ['utsav'],
    'rashbehari': ['rasbehari', 'rashbihari'],
    'hatibagan': ['hati bagan'],
    'chetla': ['chetlah'],
    'saltlake': ['salt lake'],
    'newtown': ['new town'],
    'ballygunge': ['ballygunj'],
    'jadavpur': ['jadabpur'],
    'prattoy': ['pratty'],
    'pratty': ['prattoy'],
    'natun': ['nutan'],
    'nutan': ['natun'],
    'ahiritola': ['ahritola'],
  };

  /// Clean, trim and normalize text
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[\-_/\\,.:;()!?"' "'" r']'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Expand tokens with transliteration and phonetical variations
  static Set<String> expandTokenWithAliases(String token) {
    final clean = normalize(token);
    if (clean.isEmpty) return const {};
    final Set<String> expanded = {clean};
    final directAliases = _kAliases[clean];
    if (directAliases != null) {
      expanded.addAll(directAliases);
    }
    // Also check reverse alias mapping
    for (final entry in _kAliases.entries) {
      if (entry.value.contains(clean)) {
        expanded.add(entry.key);
        expanded.addAll(entry.value);
      }
    }
    return expanded;
  }

  /// Primary search method
  List<Pandal> search(
    String query, {
    List<Pandal>? pool,
    List<Pandal>? sourceList,
    String? zone,
    String? category,
    bool? filterMega,
    bool? filterHeritage,
    String? metroStation,
    bool? onlyBookmarked,
    bool? onlyVisited,
    bool excludeDuplicates = true,
    bool includeUnverified = false,
    double? userLat,
    double? userLon,
    bool returnAllOnEmpty = true,
    int? limit,
  }) {
    final cleanQuery = normalize(query);
    final source = pool ?? sourceList ?? PandalRepository().allPandals;

    // Filter baseline dataset
    Iterable<Pandal> filteredPool = source.where((p) {
      if (excludeDuplicates && p.isDuplicateEntry) return false;
      // If query is empty, exclude unverified pandals unless explicitly requested
      if (p.isLocationUnverified && !includeUnverified && cleanQuery.isEmpty) {
        return false;
      }
      if (zone != null && zone.isNotEmpty && zone != 'All') {
        if (zone == 'Bookmarked ⭐') {
          if (!SessionService.instance.isBookmarked(p.id)) return false;
        } else if (zone == 'Visited ✅') {
          if (!SessionService.instance.isVisited(p.id)) return false;
        } else if (p.zone.toLowerCase() != zone.toLowerCase()) {
          return false;
        }
      }
      if (category != null &&
          category.isNotEmpty &&
          category != 'All' &&
          p.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      if (onlyBookmarked == true && !SessionService.instance.isBookmarked(p.id)) {
        return false;
      }
      if (onlyVisited == true && !SessionService.instance.isVisited(p.id)) {
        return false;
      }
      if (filterMega == false && p.category == 'mega') return false;
      if (filterHeritage == false && p.category == 'heritage') return false;
      if (metroStation != null &&
          metroStation.isNotEmpty &&
          p.metroStation.toLowerCase() != metroStation.toLowerCase()) {
        return false;
      }
      return true;
    });

    if (cleanQuery.isEmpty) {
      if (!returnAllOnEmpty) return const [];
      final list = filteredPool.toList();
      _sortDefault(list, userLat: userLat, userLon: userLon);
      if (limit != null && limit > 0 && list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    }

    final queryTokens = cleanQuery.split(' ').where((w) => w.isNotEmpty).toList();
    if (queryTokens.isEmpty) {
      if (!returnAllOnEmpty) return const [];
      final list = filteredPool.toList();
      _sortDefault(list, userLat: userLat, userLon: userLon);
      if (limit != null && limit > 0 && list.length > limit) {
        return list.sublist(0, limit);
      }
      return list;
    }

    // Match and score each pandal
    final scored = <_ScoredPandal>[];
    for (final pandal in filteredPool) {
      final score = _calculateScore(pandal, cleanQuery, queryTokens);
      if (score > 0) {
        scored.add(_ScoredPandal(pandal, score));
      }
    }

    // Sort scored items: highest score first, then tie-breaking
    scored.sort((a, b) {
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      // If user location is available and scores are equal, sort by distance
      if (userLat != null && userLon != null) {
        final distA = _distance(userLat, userLon, a.pandal.lat, a.pandal.lon);
        final distB = _distance(userLat, userLon, b.pandal.lat, b.pandal.lon);
        final cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
      }
      // Unverified locations last among equal scores
      if (a.pandal.isLocationUnverified != b.pandal.isLocationUnverified) {
        return a.pandal.isLocationUnverified ? 1 : -1;
      }
      // Deterministic tie-breaker: popularityRank then name
      if (a.pandal.popularityRank != b.pandal.popularityRank) {
        return a.pandal.popularityRank.compareTo(b.pandal.popularityRank);
      }
      return a.pandal.name.compareTo(b.pandal.name);
    });

    final results = scored.map((s) => s.pandal).toList();
    if (limit != null && limit > 0 && results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }

  /// Compute match score. Returns 0 if pandal does not qualify for query.
  static int _calculateScore(
    Pandal p,
    String cleanQuery,
    List<String> queryTokens,
  ) {
    final normName = normalize(p.name);
    final normId = normalize(p.id);
    final normLandmark = normalize(p.landmark);
    final normSubsection = normalize(p.subsection);
    final normMetro = normalize(p.metroStation);
    final normZone = normalize(p.zone);
    final normCategory = normalize(p.category);
    final normHistory = normalize(p.history);

    // Exact matches
    if (normName == cleanQuery) {
      return 1000;
    }
    if (normId == cleanQuery || p.id == cleanQuery) {
      return 950;
    }

    // Multi-token validation: all query tokens must match at least one attribute or alias
    int tokenScore = 0;
    bool allTokensMatched = true;

    for (final token in queryTokens) {
      final tokenVariants = expandTokenWithAliases(token);
      bool tokenMatched = false;
      int bestTokenBonus = 0;

      for (final variant in tokenVariants) {
        // Name checks
        if (normName == variant) {
          bestTokenBonus = math.max(bestTokenBonus, 500);
          tokenMatched = true;
        } else if (normName.startsWith('$variant ') || normName.startsWith(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 350);
          tokenMatched = true;
        } else if (normName.contains(' $variant ') || normName.endsWith(' $variant')) {
          bestTokenBonus = math.max(bestTokenBonus, 250);
          tokenMatched = true;
        } else if (normName.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 180);
          tokenMatched = true;
        }

        // ID check
        if (normId.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 120);
          tokenMatched = true;
        }

        // Landmark check
        if (normLandmark.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 90);
          tokenMatched = true;
        }

        // Subsection check
        if (normSubsection.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 80);
          tokenMatched = true;
        }

        // Metro check
        if (normMetro.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 70);
          tokenMatched = true;
        }

        // Zone check
        if (normZone.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 50);
          tokenMatched = true;
        }

        // Category check
        if (normCategory.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 40);
          tokenMatched = true;
        }

        // History check
        if (normHistory.contains(variant)) {
          bestTokenBonus = math.max(bestTokenBonus, 20);
          tokenMatched = true;
        }
      }

      if (!tokenMatched) {
        allTokensMatched = false;
        break;
      }
      tokenScore += bestTokenBonus;
    }

    if (!allTokensMatched) {
      return 0;
    }

    // Additional query-level bonuses
    int totalScore = tokenScore;

    // Full query prefix on name
    if (normName.startsWith(cleanQuery)) {
      totalScore += 250;
    } else if (normName.contains(cleanQuery)) {
      totalScore += 150;
    }

    // Verified locations receive an integrity bonus over unverified
    if (!p.isLocationUnverified) {
      totalScore += 30;
    }

    return totalScore;
  }

  static void _sortDefault(
    List<Pandal> list, {
    double? userLat,
    double? userLon,
  }) {
    list.sort((a, b) {
      if (a.isLocationUnverified != b.isLocationUnverified) {
        return a.isLocationUnverified ? 1 : -1;
      }
      if (userLat != null && userLon != null) {
        final distA = _distance(userLat, userLon, a.lat, a.lon);
        final distB = _distance(userLat, userLon, b.lat, b.lon);
        final cmp = distA.compareTo(distB);
        if (cmp != 0) return cmp;
      }
      if (a.popularityRank != b.popularityRank) {
        return a.popularityRank.compareTo(b.popularityRank);
      }
      return a.name.compareTo(b.name);
    });
  }

  static double _distance(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }
}

class _ScoredPandal {
  final Pandal pandal;
  final int score;
  const _ScoredPandal(this.pandal, this.score);
}
