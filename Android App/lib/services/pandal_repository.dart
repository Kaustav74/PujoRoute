import 'dart:math' as math;
import '../data/pujas_data.dart';

/// Production-grade Local Read Replica for PujoRoute (Durga Puja 2026).
/// Provides 0-network offline access to 504 verified pandals.
class PandalRepository {
  static const String schemaVersion = '1';
  static const String datasetVersion = '2026.x';
  static const int expectedRecordCount = 504;

  /// Singleton instance
  static final PandalRepository _instance = PandalRepository._internal();
  factory PandalRepository() => _instance;
  PandalRepository._internal();

  /// Return all 504 verified pandals packaged in local read replica
  List<Pandal> get allPandals => List.unmodifiable(kAllKolkataPujas);

  /// Total count of local pandal records
  int get recordCount => kAllKolkataPujas.length;

  /// Validate complete dataset integrity (504 records, unique IDs, non-null fields, valid coordinates)
  bool validateDatasetIntegrity() {
    if (kAllKolkataPujas.length != expectedRecordCount) {
      throw StateError(
          'Dataset integrity failure: Expected $expectedRecordCount records, found ${kAllKolkataPujas.length}');
    }

    final idSet = <String>{};
    for (final pandal in kAllKolkataPujas) {
      if (pandal.id.trim().isEmpty) {
        throw StateError('Dataset integrity failure: Pandal contains empty ID');
      }
      if (idSet.contains(pandal.id)) {
        throw StateError('Dataset integrity failure: Duplicate ID "${pandal.id}"');
      }
      idSet.add(pandal.id);

      if (pandal.name.trim().isEmpty) {
        throw StateError('Dataset integrity failure: Pandal ${pandal.id} has empty name');
      }

      if (!isValidCoordinates(pandal.lat, pandal.lon)) {
        throw StateError(
            'Dataset integrity failure: Invalid coordinates (${pandal.lat}, ${pandal.lon}) for ${pandal.id}');
      }
    }
    return true;
  }

  /// Coordinate range check (-90 to 90 lat, -180 to 180 lon, non-NaN, non-Infinite)
  bool isValidCoordinates(double lat, double lon) {
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) {
      return false;
    }
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }

  /// Search local pandals by keyword matching name, zone, subsection, category, landmark, metroStation, or history
  List<Pandal> searchPandals(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return allPandals;

    return kAllKolkataPujas.where((pandal) {
      return pandal.name.toLowerCase().contains(cleanQuery) ||
          pandal.zone.toLowerCase().contains(cleanQuery) ||
          pandal.category.toLowerCase().contains(cleanQuery) ||
          pandal.subsection.toLowerCase().contains(cleanQuery) ||
          pandal.landmark.toLowerCase().contains(cleanQuery) ||
          pandal.metroStation.toLowerCase().contains(cleanQuery) ||
          pandal.history.toLowerCase().contains(cleanQuery);
    }).toList();
  }

  /// Filter pandals by zone, category, or subsection
  List<Pandal> filterPandals({String? zone, String? category, String? subsection}) {
    return kAllKolkataPujas.where((pandal) {
      if (zone != null && zone.isNotEmpty && zone != 'All') {
        if (pandal.zone.toLowerCase() != zone.toLowerCase()) return false;
      }
      if (category != null && category.isNotEmpty && category != 'All') {
        if (pandal.category.toLowerCase() != category.toLowerCase()) return false;
      }
      if (subsection != null && subsection.isNotEmpty && subsection != 'All') {
        if (pandal.subsection.toLowerCase() != subsection.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  /// Calculate distance between two lat/lon points in meters using Haversine formula
  double calculateHaversineDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180.0;

  /// Sort pandals by distance from user lat/lon (nearest first)
  List<Pandal> sortByDistance(double userLat, double userLon,
      {List<Pandal>? pandals}) {
    if (!isValidCoordinates(userLat, userLon)) return pandals ?? allPandals;

    final list = List<Pandal>.from(pandals ?? kAllKolkataPujas);
    list.sort((a, b) {
      final distA = calculateHaversineDistanceMeters(userLat, userLon, a.lat, a.lon);
      final distB = calculateHaversineDistanceMeters(userLat, userLon, b.lat, b.lon);
      return distA.compareTo(distB);
    });
    return list;
  }

  /// Sort pandals alphabetically by name
  List<Pandal> sortAlphabetically({List<Pandal>? pandals}) {
    final list = List<Pandal>.from(pandals ?? kAllKolkataPujas);
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Lookup pandal by exact ID
  Pandal? getPandalById(String id) {
    try {
      return kAllKolkataPujas.firstWhere((pandal) => pandal.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Generate Google Maps Search URL without network request
  String getGoogleMapsUrl(Pandal pandal) {
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${pandal.name}, Kolkata')}';
  }

  /// Generate Google Maps Directions URL (walking mode) without network request
  String getDirectionsUrl(double fromLat, double fromLon, Pandal pandal) {
    return 'https://www.google.com/maps/dir/?api=1&origin=$fromLat,$fromLon&destination=${Uri.encodeComponent('${pandal.name}, Kolkata')}&travelmode=walking';
  }
}
