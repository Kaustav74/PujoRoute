import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../data/pujas_data.dart';

/// Represents a location candidate found via an external geocoding / places provider.
class ExternalPlaceCandidate {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lon;
  final String source; // 'geoapify', 'osm'
  final bool isLocationVerified;

  const ExternalPlaceCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    required this.source,
    this.isLocationVerified = false,
  });

  /// Convert candidate into a Pandal object with external/unverified metadata.
  Pandal toPandal() {
    final cleanId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '-');
    return Pandal.create(
      id: 'ext-$source-$cleanId',
      name: name,
      zone: 'External',
      subsection: address.split(',').take(2).join(', ').trim(),
      lat: lat,
      lon: lon,
      landmark: address,
      history: 'Discovered via $source external search. Unverified location coordinates.',
      gateStatus: 'unknown',
      crowdStatus: 'unknown',
      metroStation: '', // Never fabricate a metro station for external places
    );
  }
}

/// Unified External Places & Geocoding Service powered by Geoapify (with OSM Nominatim fallback).
class ExternalPlacesService {
  ExternalPlacesService._();
  static final ExternalPlacesService instance = ExternalPlacesService._();

  /// Default API key for Geoapify provided by environment or default
  static const String kGeoapifyApiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: 'bd63d62af74146b2b361a6e1d2cbf090',
  );

  /// Kolkata Centroid coordinates for proximity bias
  static const double kKolkataLat = 22.5726;
  static const double kKolkataLon = 88.3639;

  /// Coordinate validity check (-90 to 90 lat, -180 to 180 lon, non-zero, non-NaN)
  static bool isValidCoordinate(double lat, double lon) {
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) return false;
    if (lat < -90.0 || lat > 90.0 || lon < -180.0 || lon > 180.0) return false;
    if (lat == 0.0 && lon == 0.0) return false;
    return true;
  }

  /// Perform external search using Geoapify Places/Geocoding with OSM fallback.
  Future<List<ExternalPlaceCandidate>> searchPlaces(
    String query, {
    HttpClient? customClient,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final bool ownsClient = (customClient == null);
    final HttpClient client = customClient ?? HttpClient();
    client.connectionTimeout = timeout;

    try {
      // 1. Primary: Geoapify Geocoding & Places Search
      if (kGeoapifyApiKey.isNotEmpty) {
        try {
          final geoapifyResults = await _searchGeoapify(q, client, timeout);
          if (geoapifyResults.isNotEmpty) return geoapifyResults;
        } catch (_) {
          // Fall through to Nominatim
        }
      }

      // 2. Fallback to OpenStreetMap Nominatim
      try {
        final osmResults = await _searchNominatim(q, client, timeout);
        return osmResults;
      } catch (_) {
        return const [];
      }
    } finally {
      if (ownsClient) {
        client.close(force: true);
      }
    }
  }

  /// Geoapify Places / Geocoding implementation with multi-query resolution
  Future<List<ExternalPlaceCandidate>> _searchGeoapify(
    String query,
    HttpClient client,
    Duration timeout,
  ) async {
    final lowerQ = query.toLowerCase();
    final List<String> attempts = [
      query,
      if (!lowerQ.contains('kolkata')) '$query Kolkata',
      if (!lowerQ.contains('bengal')) '$query West Bengal',
    ];

    final candidates = <ExternalPlaceCandidate>[];
    final seenIds = <String>{};

    for (final attempt in attempts) {
      try {
        final uri = Uri.parse(
          'https://api.geoapify.com/v1/geocode/search?'
          'text=${Uri.encodeComponent(attempt)}'
          '&filter=countrycode:in'
          '&bias=proximity:$kKolkataLon,$kKolkataLat'
          '&apiKey=$kGeoapifyApiKey',
        );

        final req = await client.getUrl(uri).timeout(timeout);
        req.headers.set(HttpHeaders.userAgentHeader, 'PujoRoute/1.0 (durga-puja-kolkata)');
        final res = await req.close().timeout(timeout);

        if (res.statusCode != 200) continue;

        final body = await res.transform(utf8.decoder).join().timeout(timeout);
        final decoded = json.decode(body) as Map<String, dynamic>;
        final features = (decoded['features'] as List?) ?? [];

        for (final feature in features) {
          if (feature is! Map) continue;
          final props = feature['properties'] as Map?;
          if (props == null) continue;

          final lat = (props['lat'] as num?)?.toDouble() ?? double.nan;
          final lon = (props['lon'] as num?)?.toDouble() ?? double.nan;
          if (!isValidCoordinate(lat, lon)) continue;

          final placeId = (props['place_id'] ?? '').toString();
          final candidateId = placeId.isNotEmpty
              ? placeId
              : 'geo-${lat.toStringAsFixed(4)}-${lon.toStringAsFixed(4)}';

          if (seenIds.contains(candidateId)) continue;
          seenIds.add(candidateId);

          final name = (props['name'] ?? props['address_line1'] ?? query).toString();
          final formatted = (props['formatted'] ?? '').toString();

          candidates.add(ExternalPlaceCandidate(
            id: candidateId,
            name: name,
            address: formatted,
            lat: lat,
            lon: lon,
            source: 'geoapify',
            isLocationVerified: false,
          ));
        }

        if (candidates.isNotEmpty) break;
      } catch (_) {
        // Continue to next query attempt
      }
    }

    // Sort candidates: prioritize Greater Kolkata / West Bengal belt (lat 22.0 to 23.5, lon 88.0 to 89.0)
    candidates.sort((a, b) {
      final aInRegion = (a.lat >= 22.0 && a.lat <= 23.5 && a.lon >= 87.8 && a.lon <= 89.0);
      final bInRegion = (b.lat >= 22.0 && b.lat <= 23.5 && b.lon >= 87.8 && b.lon <= 89.0);
      if (aInRegion != bInRegion) {
        return aInRegion ? -1 : 1;
      }
      final distA = (a.lat - kKolkataLat) * (a.lat - kKolkataLat) + (a.lon - kKolkataLon) * (a.lon - kKolkataLon);
      final distB = (b.lat - kKolkataLat) * (b.lat - kKolkataLat) + (b.lon - kKolkataLon) * (b.lon - kKolkataLon);
      return distA.compareTo(distB);
    });

    return candidates.take(6).toList();
  }

  /// OpenStreetMap Nominatim fallback implementation
  Future<List<ExternalPlaceCandidate>> _searchNominatim(
    String query,
    HttpClient client,
    Duration timeout,
  ) async {
    final cleanQ = query.contains('Kolkata') ? query : '$query Kolkata';
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?'
      'q=${Uri.encodeComponent(cleanQ)}'
      '&format=json'
      '&limit=5'
      '&viewbox=88.1,22.8,88.6,22.3',
    );

    final req = await client.getUrl(uri).timeout(timeout);
    req.headers.set(HttpHeaders.userAgentHeader, 'PujoRoute/1.0 (durga-puja-kolkata; contact@pujoroute.app)');
    final res = await req.close().timeout(timeout);

    if (res.statusCode != 200) return const [];

    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    final list = json.decode(body) as List?;
    if (list == null) return const [];

    final candidates = <ExternalPlaceCandidate>[];
    for (final item in list.take(5)) {
      if (item is! Map) continue;
      final latStr = item['lat']?.toString();
      final lonStr = item['lon']?.toString();
      if (latStr == null || lonStr == null) continue;

      final lat = double.tryParse(latStr) ?? double.nan;
      final lon = double.tryParse(lonStr) ?? double.nan;
      if (!isValidCoordinate(lat, lon)) continue;

      final osmId = (item['osm_id'] ?? '').toString();
      final name = (item['name'] ?? query).toString();
      final displayName = (item['display_name'] ?? '').toString();

      candidates.add(ExternalPlaceCandidate(
        id: osmId.isNotEmpty ? osmId : 'osm-${lat.toStringAsFixed(4)}-${lon.toStringAsFixed(4)}',
        name: name,
        address: displayName,
        lat: lat,
        lon: lon,
        source: 'osm',
        isLocationVerified: false,
      ));
    }

    return candidates;
  }
}
