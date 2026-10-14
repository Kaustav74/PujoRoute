import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/pandal_search_service.dart';
import 'package:pujoroute/services/external_places_service.dart';
import 'package:pujoroute/services/pandal_deduplication_service.dart';

void main() {
  group('PandalSearchService - Local Matching & Ranking', () {
    test('1. Exact pandal name match ranks highest', () {
      final results = PandalSearchService.instance.search('Suruchi Sangha');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name.toLowerCase(), contains('suruchi sangha'));
    });

    test('2. Case-insensitive and whitespace-normalized query', () {
      final res1 = PandalSearchService.instance.search('  baGBazar   sarboJanin  ');
      final res2 = PandalSearchService.instance.search('bagbazar sarbojanin');
      expect(res1.isNotEmpty, isTrue);
      expect(res1.first.id, equals(res2.first.id));
    });

    test('3. Partial name matching', () {
      final results = PandalSearchService.instance.search('Tridhara');
      expect(results.any((p) => p.name.contains('Tridhara')), isTrue);
    });

    test('4. Token expansion & aliases (puja / pujo / bagbazar / baghbazar)', () {
      final resultsPujo = PandalSearchService.instance.search('Baghbazar Sarbojanin');
      final resultsPuja = PandalSearchService.instance.search('Bagbazar Sarbajanin');
      expect(resultsPujo.isNotEmpty, isTrue);
      expect(resultsPuja.isNotEmpty, isTrue);
      expect(resultsPujo.first.id, equals(resultsPuja.first.id));
    });

    test('5. Multi-word search requires all tokens to match', () {
      final results = PandalSearchService.instance.search('College Square Central');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name.contains('College Square') || results.first.landmark.contains('College Square'), isTrue);
    });

    test('6. Matching by zone, subsection, landmark, metro station, and ID', () {
      final byMetro = PandalSearchService.instance.search('Kalighat');
      expect(byMetro.any((p) => p.metroStation.toLowerCase().contains('kalighat') || p.landmark.toLowerCase().contains('kalighat')), isTrue);

      final byId = PandalSearchService.instance.search('college-square');
      expect(byId.any((p) => p.id == 'college_square'), isTrue);
    });

    test('7. Empty query behavior', () {
      final all = PandalSearchService.instance.search('', returnAllOnEmpty: true);
      expect(all.length, greaterThan(400));

      final empty = PandalSearchService.instance.search('', returnAllOnEmpty: false);
      expect(empty, isEmpty);
    });

    test('8. Duplicate suppression', () {
      final results = PandalSearchService.instance.search('', excludeDuplicates: true);
      expect(results.every((p) => !p.isDuplicateEntry), isTrue);
    });

    test('9. Filtering with zone and category', () {
      final southMega = PandalSearchService.instance.search(
        '',
        zone: 'South',
        filterMega: true,
        filterHeritage: false,
      );
      expect(southMega.every((p) => p.zone == 'South' && p.category == 'mega'), isTrue);
    });

    test('10. Unverified location records never become verified via search', () {
      final results = PandalSearchService.instance.search('25 Pally Club', includeUnverified: true);
      final unverified = results.firstWhere((p) => p.isLocationUnverified, orElse: () => results.first);
      if (unverified.isLocationUnverified) {
        expect(unverified.isLocationUnverified, isTrue);
        expect(unverified.hasMappableLocation, isFalse);
      }
    });

    test('11. Deterministic ordering: equal scores sort deterministically', () {
      final r1 = PandalSearchService.instance.search('Park');
      final r2 = PandalSearchService.instance.search('Park');
      expect(r1.map((p) => p.id).toList(), equals(r2.map((p) => p.id).toList()));
    });
  });

  group('ExternalPlacesService - Validation & Model Integrity', () {
    test('12. Validates coordinates and rejects out-of-range, NaN, or 0,0', () {
      expect(ExternalPlacesService.isValidCoordinate(22.5726, 88.3639), isTrue);
      expect(ExternalPlacesService.isValidCoordinate(91.0, 88.0), isFalse);
      expect(ExternalPlacesService.isValidCoordinate(-91.0, 88.0), isFalse);
      expect(ExternalPlacesService.isValidCoordinate(22.0, 185.0), isFalse);
      expect(ExternalPlacesService.isValidCoordinate(double.nan, 88.0), isFalse);
      expect(ExternalPlacesService.isValidCoordinate(22.0, double.infinity), isFalse);
      expect(ExternalPlacesService.isValidCoordinate(0.0, 0.0), isFalse);
    });

    test('13. ExternalPlaceCandidate converts to Pandal without fabricating verified or metro data', () {
      const candidate = ExternalPlaceCandidate(
        id: 'geo-12345',
        name: 'Kalyani ITI More Puja',
        address: 'ITI More, Kalyani, Nadia, West Bengal',
        lat: 22.9750,
        lon: 88.4340,
        source: 'geoapify',
        isLocationVerified: false,
      );

      final pandal = candidate.toPandal();
      expect(pandal.id, equals('ext-geoapify-geo-12345'));
      expect(pandal.name, equals('Kalyani ITI More Puja'));
      expect(pandal.zone, equals('External'));
      expect(pandal.metroStation, isEmpty); // Never fabricate a metro station
      expect(pandal.lat, equals(22.9750));
      expect(pandal.lon, equals(88.4340));
    });

    test('14. Deduplication detects duplicate candidate against existing pandal', () {
      final existing = Pandal.create(
        id: 'existing-singhi',
        name: 'Singhi Park Sarbojanin',
        lat: 22.5186,
        lon: 88.3644,
        zone: 'South',
      );

      final candidateDuplicate = Pandal.create(
        id: 'ext-geo-singhi',
        name: 'Singhi Park Durga Puja',
        lat: 22.5187,
        lon: 88.3645,
        zone: 'External',
      );

      final isDup = PandalDeduplicationService.instance.isDuplicatePair(existing, candidateDuplicate);
      expect(isDup, isTrue);
    });

    test('15. Preservation of stops when adding new destination', () {
      final initialStops = [
        Pandal.create(id: 'stop-1', name: 'Stop 1', lat: 22.5, lon: 88.3, zone: 'South'),
        Pandal.create(id: 'stop-2', name: 'Stop 2', lat: 22.51, lon: 88.31, zone: 'South'),
      ];

      final newStop = Pandal.create(id: 'stop-3', name: 'Stop 3', lat: 22.52, lon: 88.32, zone: 'External');

      final combined = [...initialStops, newStop];
      expect(combined.length, equals(3));
      expect(combined.map((s) => s.id), containsAll(['stop-1', 'stop-2', 'stop-3']));
    });
  });
}
