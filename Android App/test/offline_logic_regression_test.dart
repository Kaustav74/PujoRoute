import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/hardened_pujo_optimizer.dart';
import 'package:pujoroute/services/metro_graph_service.dart';

double _km(double a, double b, double c, double d) =>
    HardenedPujoOptimizer.distance(a, b, c, d) / 1000.0;

Pandal _p(String id, double lat, double lng) =>
    Pandal.create(id: id, name: 'Pandal $id', lat: lat, lng: lng, zone: 'South');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pandal dataset integrity (504 bundled pandals)', () {
    test('504 records with unique ids and names', () {
      expect(kAllKolkataPujas.length, 504);
      expect(kAllKolkataPujas.map((p) => p.id).toSet().length, 504);
      expect(kAllKolkataPujas.map((p) => p.name.trim().toLowerCase()).toSet().length, 504);
    });

    test('all coordinates are valid and inside Greater Kolkata / Hooghly-Howrah belt', () {
      for (final p in kAllKolkataPujas) {
        expect(p.lat.isFinite && p.lon.isFinite, isTrue, reason: p.id);
        expect(p.lat, inInclusiveRange(22.3, 22.9), reason: p.id);
        expect(p.lon, inInclusiveRange(87.9, 88.6), reason: p.id);
      }
    });

    test('required text fields are non-empty and enums are valid', () {
      for (final p in kAllKolkataPujas) {
        expect(p.name.trim(), isNotEmpty, reason: p.id);
        expect(p.metroStation.trim(), isNotEmpty, reason: p.id);
        expect(['mega', 'heritage'], contains(p.category), reason: p.id);
        expect(['North', 'South', 'Central', 'Salt Lake'], contains(p.zone), reason: p.id);
      }
    });

    test('assigned metro station is a known station (regression: 150 wrong assignments)', () {
      final metro = MetroGraphService.instance;
      for (final p in kAllKolkataPujas) {
        final canonical = metro.getCanonicalStation(p.metroStation) ?? p.metroStation;
        expect(MetroGraphService.kStationCoordinates.containsKey(canonical), isTrue,
            reason: '${p.id} -> ${p.metroStation}');
      }
    });

    test('assigned metro station is never much farther than the actual nearest station', () {
      const coords = MetroGraphService.kStationCoordinates;
      final metro = MetroGraphService.instance;
      final offenders = <String>[];
      for (final p in kAllKolkataPujas) {
        final canonical = metro.getCanonicalStation(p.metroStation) ?? p.metroStation;
        final c = coords[canonical]!;
        final assigned = _km(p.lat, p.lon, c[0], c[1]);
        final nearest = coords.values.map((v) => _km(p.lat, p.lon, v[0], v[1])).reduce(min);
        if (assigned > 3.0 && assigned - nearest > 1.5) offenders.add('${p.id}: ${p.metroStation}');
      }
      expect(offenders, isEmpty);
    });

    test('Forward Club (Rashbehari) is not mapped to Dum Dum any more', () {
      final p = kAllKolkataPujas.firstWhere((p) => p.id == 'forward-club');
      expect(p.metroStation, isNot('Dum Dum'));
    });
  });

  group('Metro graph asset', () {
    test('metro_graph.json has no UTF-8 BOM and decodes as JSON (regression)', () {
      final bytes = File('assets/data/metro_graph.json').readAsBytesSync();
      expect(bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF, isFalse);
      final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final interchanges = (data['interchanges'] as List).map((e) => e['station']).toSet();
      expect(interchanges, containsAll(['Esplanade', 'Kavi Subhash']));
    });

    test('southern Blue Line stations are east of Bansdroni (coordinate regression)', () {
      const c = MetroGraphService.kStationCoordinates;
      expect(c['Kavi Nazrul']![1], greaterThan(88.37));
      expect(c['Shahid Khudiram']![1], greaterThan(88.38));
      expect(_km(c['Kavi Subhash']![0], c['Kavi Subhash']![1], 22.4723, 88.3983), lessThan(0.3));
    });
  });

  group('Route planner regressions', () {
    test('2-opt can fix a crossing on the first hop while keeping start and end anchored', () {
      // start(0,0) -> far(0,2) -> near(0,1) -> end(0,3): first hop crosses back.
      final start = _p('s', 22.50, 88.30);
      final far = _p('f', 22.50, 88.32);
      final near = _p('n', 22.50, 88.31);
      final end = _p('e', 22.50, 88.33);
      final out = HardenedPujoOptimizer.apply2Opt([start, far, near, end]);
      expect(out.first.id, 's');
      expect(out.last.id, 'e');
      expect(out.map((p) => p.id).toList(), ['s', 'n', 'f', 'e']);
    });

    test('single-stop circuit honours a user-added (forced) pandal', () {
      final pool = [_p('a', 22.50, 88.30), _p('b', 22.51, 88.31)];
      final res = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: pool,
        startLat: 22.50,
        startLng: 88.30,
        homeLat: 22.50,
        homeLng: 88.30,
        requestedStops: 1,
        forcedStops: [pool[1]],
      );
      expect(res.route.single.id, 'b');
    });

    test('empty pool and zero stops are handled without throwing', () {
      expect(
          HardenedPujoOptimizer.generateHomeBoundCircuit(
                  pool: const [], startLat: 0, startLng: 0, homeLat: 0, homeLng: 0, requestedStops: 5)
              .route,
          isEmpty);
      expect(
          HardenedPujoOptimizer.generateHomeBoundCircuit(
                  pool: [_p('a', 22.5, 88.3)], startLat: 0, startLng: 0, homeLat: 0, homeLng: 0, requestedStops: 0)
              .route,
          isEmpty);
    });

    test('route never contains duplicates and respects requested size on real data', () {
      final south = kAllKolkataPujas.where((p) => p.zone == 'South').toList();
      final res = HardenedPujoOptimizer.generateHomeBoundCircuit(
        pool: south,
        startLat: 22.5178,
        startLng: 88.3468,
        homeLat: 22.5085,
        homeLng: 88.3467,
        requestedStops: 8,
      );
      expect(res.route.length, 8);
      expect(res.route.map((p) => p.id).toSet().length, 8);
    });
  });
}
