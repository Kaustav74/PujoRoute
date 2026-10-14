import 'dart:async';
import 'dart:io';
import '../data/pujas_data.dart';
import 'pandal_search_service.dart';
import 'external_places_service.dart';
import 'pandal_deduplication_service.dart';

/// Represents the combined result of a hybrid search query.
class HybridSearchResult {
  final String query;
  final List<Pandal> localMatches;
  final List<ExternalPlaceCandidate> onlineCandidates;
  final bool isOnlineSearching;
  final String? onlineError;

  const HybridSearchResult({
    required this.query,
    required this.localMatches,
    required this.onlineCandidates,
    this.isOnlineSearching = false,
    this.onlineError,
  });

  HybridSearchResult copyWith({
    String? query,
    List<Pandal>? localMatches,
    List<ExternalPlaceCandidate>? onlineCandidates,
    bool? isOnlineSearching,
    String? onlineError,
  }) {
    return HybridSearchResult(
      query: query ?? this.query,
      localMatches: localMatches ?? this.localMatches,
      onlineCandidates: onlineCandidates ?? this.onlineCandidates,
      isOnlineSearching: isOnlineSearching ?? this.isOnlineSearching,
      onlineError: onlineError,
    );
  }
}

/// Hybrid search engine coordinating immediate offline local pandal matching
/// with online Geoapify place discovery and cross-source deduplication.
class HybridPandalSearchService {
  final PandalSearchService _localService;
  final ExternalPlacesService _externalService;
  final PandalDeduplicationService _dedupService;

  HybridPandalSearchService({
    PandalSearchService? localService,
    ExternalPlacesService? externalService,
    PandalDeduplicationService? dedupService,
  })  : _localService = localService ?? PandalSearchService.instance,
        _externalService = externalService ?? ExternalPlacesService.instance,
        _dedupService = dedupService ?? PandalDeduplicationService.instance;

  static final HybridPandalSearchService instance = HybridPandalSearchService();

  /// Synchronously search local bundled pandals. Returns immediately with deterministic ranking.
  List<Pandal> searchLocal(
    String query, {
    List<Pandal>? pool,
    List<Pandal>? sourceList,
    String? zone,
    String? category,
    double? userLat,
    double? userLon,
    int? limit,
    bool returnAllOnEmpty = true,
  }) {
    return _localService.search(
      query,
      pool: pool,
      sourceList: sourceList,
      zone: zone,
      category: category,
      userLat: userLat,
      userLon: userLon,
      limit: limit,
      returnAllOnEmpty: returnAllOnEmpty,
      excludeDuplicates: true,
      includeUnverified: false,
    );
  }

  /// Perform online search via Geoapify (with OSM fallback) with strict coordinate validation.
  Future<List<ExternalPlaceCandidate>> searchOnline(
    String query, {
    HttpClient? customClient,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      return await _externalService.searchPlaces(
        q,
        customClient: customClient,
        timeout: timeout,
      );
    } catch (e) {
      return const [];
    }
  }

  /// Check whether an external candidate matches any known local pandal or existing stop.
  bool isCandidateDuplicate(
    ExternalPlaceCandidate candidate,
    Iterable<Pandal> knownPandals,
  ) {
    if (!ExternalPlacesService.isValidCoordinate(candidate.lat, candidate.lon)) {
      return true; // Invalid coordinates should be treated as unusable/duplicate
    }
    final candidatePandal = candidate.toPandal();
    for (final existing in knownPandals) {
      if (existing.id == candidatePandal.id) return true;
      if (_dedupService.isDuplicatePair(existing, candidatePandal)) {
        return true;
      }
      // Proximity check (< 120m) with token overlap
      final dist = _dedupService.haversineMeters(
        existing.lat,
        existing.lon,
        candidate.lat,
        candidate.lon,
      );
      if (dist < 120.0) {
        final t1 = _dedupService.extractCoreTokens(existing.name);
        final t2 = _dedupService.extractCoreTokens(candidate.name);
        if (t1.isNotEmpty && t2.isNotEmpty && t1.intersection(t2).isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  }

  /// Filters out online candidates that already exist in local matches or circuit stops.
  List<ExternalPlaceCandidate> filterCrossSourceDuplicates(
    List<ExternalPlaceCandidate> candidates,
    Iterable<Pandal> existingPandals,
  ) {
    return candidates.where((c) => !isCandidateDuplicate(c, existingPandals)).toList();
  }

  /// Executes a unified hybrid query.
  /// 1. Immediately returns local matches without blocking.
  /// 2. Asynchronously queries Geoapify if query length >= 2.
  /// 3. Filters out cross-source duplicates.
  Future<HybridSearchResult> searchHybrid(
    String query, {
    List<Pandal>? pool,
    List<Pandal>? existingCircuitStops,
    double? userLat,
    double? userLon,
    int localLimit = 20,
    HttpClient? customClient,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final cleanQ = query.trim();

    // 1. Immediate local search
    final localMatches = searchLocal(
      cleanQ,
      pool: pool,
      userLat: userLat,
      userLon: userLon,
      limit: localLimit,
      returnAllOnEmpty: cleanQ.isEmpty,
    );

    if (cleanQ.length < 2) {
      return HybridSearchResult(
        query: cleanQ,
        localMatches: localMatches,
        onlineCandidates: const [],
        isOnlineSearching: false,
      );
    }

    // 2. Online search with cross-source deduplication
    try {
      final rawCandidates = await searchOnline(
        cleanQ,
        customClient: customClient,
        timeout: timeout,
      );

      final combinedCheck = <Pandal>[
        ...localMatches,
        if (existingCircuitStops != null) ...existingCircuitStops,
      ];

      final filteredCandidates = filterCrossSourceDuplicates(
        rawCandidates,
        combinedCheck,
      );

      return HybridSearchResult(
        query: cleanQ,
        localMatches: localMatches,
        onlineCandidates: filteredCandidates,
        isOnlineSearching: false,
      );
    } catch (e) {
      return HybridSearchResult(
        query: cleanQ,
        localMatches: localMatches,
        onlineCandidates: const [],
        isOnlineSearching: false,
        onlineError: 'Online places search currently unavailable.',
      );
    }
  }
}
