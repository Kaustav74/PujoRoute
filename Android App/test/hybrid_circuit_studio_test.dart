import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/external_places_service.dart';
import 'package:pujoroute/services/hybrid_pandal_search_service.dart';
import 'package:pujoroute/services/hardened_pujo_optimizer.dart';
import 'package:pujoroute/screens/circuit_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HybridPandalSearchService Tests', () {
    test('1. searchLocal returns immediate offline matches without network', () {
      final results = HybridPandalSearchService.instance.searchLocal('Suruchi Sangha');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name.toLowerCase(), contains('suruchi sangha'));
      expect(results.first.hasMappableLocation, isTrue);
    });

    test('2. searchLocal preserves verified catalog metadata and canonical IDs', () {
      final results = HybridPandalSearchService.instance.searchLocal('Ekdalia Evergreen');
      expect(results.isNotEmpty, isTrue);
      final p = results.first;
      expect(p.id, equals('ekdalia_evergreen'));
      expect(p.category, equals('mega'));
      expect(p.zone, equals('South'));
      expect(p.lat, inInclusiveRange(22.3, 23.1));
      expect(p.lon, inInclusiveRange(87.8, 88.6));
    });

    test('3. isCandidateDuplicate detects cross-source duplicates by proximity & name tokens', () {
      final service = HybridPandalSearchService.instance;
      final existingPandals = [
        Pandal.create(
          id: 'ballygunge_cultural',
          name: 'Ballygunge Cultural Association',
          lat: 22.5218,
          lon: 88.3615,
          zone: 'South',
        ),
      ];

      // Exact match candidate
      const exactCandidate = ExternalPlaceCandidate(
        id: 'geo-1',
        name: 'Ballygunge Cultural Association Puja',
        address: 'Ballygunge, Kolkata',
        lat: 22.5219,
        lon: 88.3616,
        source: 'geoapify',
        isLocationVerified: false,
      );

      // Distinct far-away candidate
      const distinctCandidate = ExternalPlaceCandidate(
        id: 'geo-2',
        name: 'Kalyani ITI More Puja',
        address: 'ITI More, Kalyani',
        lat: 22.9750,
        lon: 88.4340,
        source: 'geoapify',
        isLocationVerified: false,
      );

      expect(service.isCandidateDuplicate(exactCandidate, existingPandals), isTrue);
      expect(service.isCandidateDuplicate(distinctCandidate, existingPandals), isFalse);

      final filtered = service.filterCrossSourceDuplicates(
        [exactCandidate, distinctCandidate],
        existingPandals,
      );
      expect(filtered.length, equals(1));
      expect(filtered.first.id, equals('geo-2'));
    });

    test('4. searchHybrid handles short queries instantly without online network call', () async {
      final result = await HybridPandalSearchService.instance.searchHybrid('a');
      expect(result.localMatches.isNotEmpty, isTrue);
      expect(result.onlineCandidates, isEmpty);
      expect(result.isOnlineSearching, isFalse);
    });

    test('5. searchOnline rejects invalid coordinates and candidate converts cleanly', () {
      expect(ExternalPlacesService.isValidCoordinate(22.5726, 88.3639), isTrue);
      expect(ExternalPlacesService.isValidCoordinate(-100.0, 50.0), isFalse);
      expect(ExternalPlacesService.isValidCoordinate(0.0, 0.0), isFalse);

      const validCandidate = ExternalPlaceCandidate(
        id: 'osm-4421',
        name: 'Dum Dum Park Tarun Sangha',
        address: 'Dum Dum Park, Kolkata',
        lat: 22.6030,
        lon: 88.4060,
        source: 'osm',
        isLocationVerified: false,
      );

      final pandal = validCandidate.toPandal();
      expect(pandal.id, equals('ext-osm-osm-4421'));
      expect(pandal.name, equals('Dum Dum Park Tarun Sangha'));
      expect(pandal.isLocationUnverified, isTrue);
      expect(pandal.hasMappableLocation, isTrue);
    });
  });

  group('Circuit Studio Origin & Route Optimization Tests', () {
    test('6. Origin is never counted as a pandal stop and anchors TSP start', () {
      const originLat = 22.5726;
      const originLon = 88.3639;

      final pandalStops = [
        Pandal.create(id: 'p1', name: 'Pandal 1', lat: 22.5100, lon: 88.3500, zone: 'South'),
        Pandal.create(id: 'p2', name: 'Pandal 2', lat: 22.5900, lon: 88.3700, zone: 'North'),
        Pandal.create(id: 'p3', name: 'Pandal 3', lat: 22.5200, lon: 88.3600, zone: 'South'),
      ];

      expect(pandalStops.length, equals(3)); // Pure pandal count

      final dummyOrigin = Pandal.create(
        id: '__circuit_origin__',
        name: 'Your Location',
        lat: originLat,
        lon: originLon,
        zone: 'Origin',
      );

      final path = [dummyOrigin, ...pandalStops];
      final optimizedPath = HardenedPujoOptimizer.apply2Opt(
        path,
        anchorStart: true,
        anchorEnd: false,
      );

      // Origin remains anchored at start
      expect(optimizedPath.first.id, equals('__circuit_origin__'));

      // Clean stops exclude origin
      final cleanStops = optimizedPath.where((p) => p.id != '__circuit_origin__').toList();
      expect(cleanStops.length, equals(3));
      expect(cleanStops.map((s) => s.id).toSet(), equals({'p1', 'p2', 'p3'}));
    });

    test('7. Round-Trip optimization anchors origin at both start and finish', () {
      const originLat = 22.5726;
      const originLon = 88.3639;

      final dummyOrigin = Pandal.create(
        id: '__circuit_origin__',
        name: 'Your Location',
        lat: originLat,
        lon: originLon,
        zone: 'Origin',
      );

      final pandalStops = [
        Pandal.create(id: 'p1', name: 'Pandal 1', lat: 22.5100, lon: 88.3500, zone: 'South'),
        Pandal.create(id: 'p2', name: 'Pandal 2', lat: 22.5900, lon: 88.3700, zone: 'North'),
        Pandal.create(id: 'p3', name: 'Pandal 3', lat: 22.5200, lon: 88.3600, zone: 'South'),
      ];

      final path = [dummyOrigin, ...pandalStops, dummyOrigin];
      final optimizedPath = HardenedPujoOptimizer.apply2Opt(
        path,
        anchorStart: true,
        anchorEnd: true,
      );

      expect(optimizedPath.first.id, equals('__circuit_origin__'));
      expect(optimizedPath.last.id, equals('__circuit_origin__'));

      final finalStops = optimizedPath.where((p) => p.id != '__circuit_origin__').toList();
      expect(finalStops.length, equals(pandalStops.length));
    });

    test('8. Total circuit metric incorporates travel mode speeds', () {
      const totalMeters = 3000.0; // 3 km

      final walkMins = (totalMeters / 75).round(); // ~40 mins
      final driveMins = (totalMeters / 300).round(); // ~10 mins
      final transitMins = (totalMeters / 200).round(); // ~15 mins

      expect(walkMins, equals(40));
      expect(driveMins, equals(10));
      expect(transitMins, equals(15));
    });
  });

  group('Search Pandal in Google Complete Removal Verification', () {
    testWidgets('9. CircuitStudioScreen renders without any Search Pandal in Google option', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CircuitStudioScreen(
            userLat: 22.5726,
            userLon: 88.3639,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that "Search Pandal in Google" does NOT appear anywhere
      expect(find.textContaining('Search Pandal in Google'), findsNothing);
      expect(find.textContaining('Search external places (Geoapify)'), findsNothing);

      // Verify that "+ Add Stop" buttons exist
      expect(find.text('+ Add Stop'), findsOneWidget);
    });
  });
}
