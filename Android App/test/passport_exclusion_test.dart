import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/session_service.dart';
import 'package:pujoroute/services/hardened_pujo_optimizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
    for (final id in SessionService.instance.visitedIds.toList()) {
      await SessionService.instance.toggleVisited(id);
    }
  });

  group('Pandal Descriptions Dataset Tests', () {
    test('All 504 pandals have valid, non-empty descriptions', () {
      expect(kAllKolkataPujas.length, 504);
      for (final p in kAllKolkataPujas) {
        expect(p.history.trim().isNotEmpty, isTrue, reason: 'Pandal ${p.name} has empty history');
        expect(p.history.length >= 30, isTrue, reason: 'Pandal ${p.name} has short history');
      }
    });

    test('Zero temporal specifics or replacement characters exist in descriptions', () {
      for (final p in kAllKolkataPujas) {
        expect(p.history.contains('2025:'), isFalse, reason: 'Found 2025: in ${p.name}');
        expect(p.history.contains('2026:'), isFalse, reason: 'Found 2026: in ${p.name}');
        expect(p.history.contains('Temporal Specifics'), isFalse, reason: 'Found Temporal Specifics in ${p.name}');
        expect(p.history.contains('\ufffd'), isFalse, reason: 'Found replacement char in ${p.name}');
      }
    });
  });

  group('Passport Stamped Exclusion Tests', () {
    test('Stamped pandals are excluded from routing candidates', () async {
      // Pick two pandals from North zone
      final northPandals = kAllKolkataPujas.where((p) => p.zone == 'North').toList();
      expect(northPandals.length, greaterThan(10));

      final first = northPandals[0];
      final second = northPandals[1];

      // Mark first as visited / stamped
      await SessionService.instance.toggleVisited(first.id);
      expect(SessionService.instance.isVisited(first.id), isTrue);

      // Simulate pool filtering as in Circuit Studio
      final visited = SessionService.instance.visitedIds;
      final pool = northPandals.where((p) => !visited.contains(p.id)).toList();

      expect(pool.any((p) => p.id == first.id), isFalse);
      expect(pool.any((p) => p.id == second.id), isTrue);

      // Optimize circuit with unvisited pool
      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: pool,
        startLat: 22.5726,
        startLng: 88.3639,
        homeLat: 22.5726,
        homeLng: 88.3639,
        requestedStops: 5,
      );

      expect(result.route.any((p) => p.id == first.id), isFalse);
    });

    test('Forced stops are preserved even if stamped', () async {
      final northPandals = kAllKolkataPujas.where((p) => p.zone == 'North').toList();
      final target = northPandals[0];

      await SessionService.instance.toggleVisited(target.id);
      expect(SessionService.instance.isVisited(target.id), isTrue);

      final visited = SessionService.instance.visitedIds;
      final newlyAdded = [target];
      final forcedIds = newlyAdded.map((p) => p.id).toSet();

      final pool = northPandals
          .where((p) => !visited.contains(p.id) || forcedIds.contains(p.id))
          .toList();

      expect(pool.any((p) => p.id == target.id), isTrue);

      final result = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: pool,
        startLat: 22.5726,
        startLng: 88.3639,
        homeLat: 22.5726,
        homeLng: 88.3639,
        requestedStops: 5,
        forcedStops: newlyAdded,
      );

      expect(result.route.any((p) => p.id == target.id), isTrue);
    });
  });
}
