import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/hardened_pujo_optimizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HardenedPujoOptimizer Cardinality & Anti-Backtracking Tests', () {
    // Helper to generate a test pool of pandals with realistic Kolkata cluster spacing (<1200m between steps)
    List<Pandal> buildSamplePool() {
      return [
        Pandal.create(
          id: 'p1',
          name: 'Pandal 1 (South West)',
          lat: 22.5100,
          lng: 88.3400,
          zone: 'South',
          popularityRank: 10,
        ),
        Pandal.create(
          id: 'p2',
          name: 'Pandal 2 (South Central)',
          lat: 22.5150,
          lng: 88.3440,
          zone: 'South',
          popularityRank: 5,
        ),
        Pandal.create(
          id: 'p3',
          name: 'Pandal 3 (South East)',
          lat: 22.5200,
          lng: 88.3470,
          zone: 'South',
          popularityRank: 1,
        ),
        Pandal.create(
          id: 'p4',
          name: 'Pandal 4 (Central South)',
          lat: 22.5250,
          lng: 88.3500,
          zone: 'South',
          popularityRank: 20,
        ),
        Pandal.create(
          id: 'p5',
          name: 'Pandal 5 (Central)',
          lat: 22.5300,
          lng: 88.3520,
          zone: 'Central',
          popularityRank: 8,
        ),
        Pandal.create(
          id: 'p6',
          name: 'Pandal 6 (Park Street)',
          lat: 22.5360,
          lng: 88.3540,
          zone: 'Central',
          popularityRank: 12,
        ),
        Pandal.create(
          id: 'p7',
          name: 'Pandal 7 (Esplanade)',
          lat: 22.5420,
          lng: 88.3550,
          zone: 'Central',
          popularityRank: 2,
        ),
        Pandal.create(
          id: 'p8',
          name: 'Pandal 8 (College Square)',
          lat: 22.5480,
          lng: 88.3570,
          zone: 'Central',
          popularityRank: 3,
        ),
        Pandal.create(
          id: 'p9',
          name: 'Pandal 9 (Girish Park)',
          lat: 22.5540,
          lng: 88.3590,
          zone: 'North',
          popularityRank: 15,
        ),
        Pandal.create(
          id: 'p10',
          name: 'Pandal 10 (Sovabazar)',
          lat: 22.5600,
          lng: 88.3610,
          zone: 'North',
          popularityRank: 4,
        ),
        Pandal.create(
          id: 'p11',
          name: 'Pandal 11 (Bagbazar)',
          lat: 22.5660,
          lng: 88.3630,
          zone: 'North',
          popularityRank: 2,
        ),
        Pandal.create(
          id: 'p12',
          name: 'Pandal 12 (Shyambazar Five Point)',
          lat: 22.5700,
          lng: 88.3650,
          zone: 'North',
          popularityRank: 6,
        ),
      ];
    }

    test('1. Full Cardinality Preservation: No premature truncation on requested stops', () {
      final pool = buildSamplePool();
      const startLat = 22.5050;
      const startLng = 88.3380;
      const homeLat = 22.5720;
      const homeLng = 88.3660;

      // Request 8 stops out of 12 available
      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: pool,
        startLat: startLat,
        startLng: startLng,
        homeLat: homeLat,
        homeLng: homeLng,
        requestedStops: 8,
      );

      expect(result.route.length, 8,
          reason: 'Optimizer must return exactly 8 stops without premature truncation');
      expect(result.fellBackEarly, false);

      final ids = result.route.map((p) => p.id).toSet();
      expect(ids.length, 8, reason: 'Every stop must be unique');
      expect(result.route.last.id, 'p12',
          reason: 'p12 is closest to homeLat/homeLng (22.5720, 88.3660)');
    });

    test('2. Adaptive Detour Handling: Fulfills target stops even with lateral detour', () {
      final sparsePool = [
        Pandal.create(id: 's1', name: 'Sparse 1', lat: 22.5100, lng: 88.3500, zone: 'South'),
        Pandal.create(id: 's2', name: 'Sparse 2', lat: 22.5170, lng: 88.3500, zone: 'South'),
        Pandal.create(id: 's3', name: 'Sparse 3', lat: 22.5180, lng: 88.3550, zone: 'South'),
        Pandal.create(id: 's4', name: 'Sparse 4', lat: 22.5240, lng: 88.3500, zone: 'Central'),
        Pandal.create(id: 's5', name: 'Sparse 5', lat: 22.5310, lng: 88.3500, zone: 'Central'),
        Pandal.create(id: 's6', name: 'Sparse 6', lat: 22.5380, lng: 88.3500, zone: 'North'),
      ];

      const startLat = 22.5050;
      const startLng = 88.3500;
      const homeLat = 22.5400;
      const homeLng = 88.3500;

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: sparsePool,
        startLat: startLat,
        startLng: startLng,
        homeLat: homeLat,
        homeLng: homeLng,
        requestedStops: 5,
      );

      expect(result.route.length, 5,
          reason: 'Adaptive progression must successfully incorporate 5 stops');
      expect(result.fellBackEarly, false);
      expect(result.route.last.id, 's6', reason: 'Terminal stop must anchor closest to home');
    });

    test('3. Single-stop request contract', () {
      final pool = buildSamplePool();
      const homeLat = 22.5420;
      const homeLng = 88.3550; // Exactly at Esplanade (p7)

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: pool,
        startLat: 22.5100,
        startLng: 88.3400,
        homeLat: homeLat,
        homeLng: homeLng,
        requestedStops: 1,
      );

      expect(result.route.length, 1);
      expect(result.route.first.id, 'p7');
      expect(result.totalWalkingMeters, 0.0);
      expect(result.walkToHomeMeters, lessThan(10.0));
      expect(result.fellBackEarly, false);
    });

    test('4. Candidates <= requestedStops contract', () {
      final miniPool = [
        Pandal.create(id: 'm1', name: 'Mini 1', lat: 22.5100, lng: 88.3400, zone: 'South'),
        Pandal.create(id: 'm2', name: 'Mini 2', lat: 22.5150, lng: 88.3400, zone: 'South'),
        Pandal.create(id: 'm3', name: 'Mini 3', lat: 22.5200, lng: 88.3400, zone: 'South'),
      ];

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: miniPool,
        startLat: 22.5050,
        startLng: 88.3400,
        homeLat: 22.5250,
        homeLng: 88.3400,
        requestedStops: 5,
      );

      expect(result.route.length, 3);
      expect(result.fellBackEarly, true,
          reason: 'fellBackEarly is true because only 3 candidates were available for 5 requested');
    });

    test('5. Empty pool edge case', () {
      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: [],
        startLat: 22.5000,
        startLng: 88.3400,
        homeLat: 22.5500,
        homeLng: 88.3400,
        requestedStops: 5,
      );

      expect(result.route.isEmpty, true);
      expect(result.totalWalkingMeters, 0.0);
      expect(result.walkToHomeMeters, 0.0);
      expect(result.fellBackEarly, true);
    });

    test('6. Deduplication: Duplicate pandal IDs in pool are handled cleanly', () {
      final duplicatedPool = [
        Pandal.create(id: 'dup1', name: 'Dup 1', lat: 22.5100, lng: 88.3400, zone: 'South'),
        Pandal.create(id: 'dup1', name: 'Dup 1 Clone', lat: 22.5100, lng: 88.3400, zone: 'South'),
        Pandal.create(id: 'dup2', name: 'Dup 2', lat: 22.5150, lng: 88.3400, zone: 'South'),
        Pandal.create(id: 'dup3', name: 'Dup 3', lat: 22.5200, lng: 88.3400, zone: 'South'),
      ];

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: duplicatedPool,
        startLat: 22.5050,
        startLng: 88.3400,
        homeLat: 22.5250,
        homeLng: 88.3400,
        requestedStops: 3,
      );

      expect(result.route.length, 3);
      final ids = result.route.map((p) => p.id).toSet();
      expect(ids.length, 3);
    });

    test('7. Real Kolkata Dataset Integration: Generates full 10-stop route from master registry', () {
      final southPujas = kAllKolkataPujas.where((p) => p.zone == 'South').toList();
      expect(southPujas.length, greaterThan(15));

      const kalighatLat = 22.5178;
      const kalighatLng = 88.3468;
      const gariahatLat = 22.5190;
      const gariahatLng = 88.3680;

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: southPujas,
        startLat: kalighatLat,
        startLng: kalighatLng,
        homeLat: gariahatLat,
        homeLng: gariahatLng,
        requestedStops: 10,
      );

      expect(result.route.length, 10,
          reason: 'Must generate full 10 stops from real Kolkata dataset without early dropout');
      expect(result.fellBackEarly, false);
      expect(result.totalWalkingMeters, greaterThan(500.0));
      expect(result.walkToHomeMeters, greaterThan(0.0));
    });

    test('8. Forced Stops Guarantee: User-added pandals are strictly present in itinerary', () {
      final pool = buildSamplePool();
      final specialPandal = Pandal.create(
        id: 'special_para_1',
        name: 'My Heritage Para Pandal',
        lat: 22.5220,
        lng: 88.3480,
        zone: 'South',
        popularityRank: 999,
      );

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: pool,
        startLat: 22.5050,
        startLng: 88.3380,
        homeLat: 22.5720,
        homeLng: 88.3660,
        requestedStops: 6,
        forcedStops: [specialPandal],
      );

      expect(result.route.any((p) => p.id == 'special_para_1'), isTrue,
          reason: 'Forced pandal must be included in the generated circuit');
      expect(result.route.length, 6);
    });

    test('9. Max Step Constraint: Safely avoids steps exceeding 1200m', () {
      // Create pandals with a >1500m gap
      final gapPool = [
        Pandal.create(id: 'g1', name: 'Gap 1', lat: 22.5100, lng: 88.3400, zone: 'South'),
        Pandal.create(id: 'g2', name: 'Gap 2', lat: 22.5300, lng: 88.3400, zone: 'South'), // >2km gap
      ];

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: gapPool,
        startLat: 22.5080,
        startLng: 88.3400,
        homeLat: 22.5350,
        homeLng: 88.3400,
        requestedStops: 3,
      );

      expect(result.fellBackEarly, isTrue);
      expect(result.diagnostics, contains('under distance constraints'));
    });
  });
}
