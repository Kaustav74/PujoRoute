import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/location_status.dart';
import 'package:pujoroute/data/pujas_data.dart';

double _m(double a, double b, double c, double d) {
  const r = 6371000.0;
  final p1 = a * math.pi / 180, p2 = c * math.pi / 180;
  final x = math.pow(math.sin((p2 - p1) / 2), 2) +
      math.cos(p1) * math.cos(p2) * math.pow(math.sin((d - b) * math.pi / 360), 2);
  return 2 * r * math.asin(math.sqrt(x));
}

void main() {
  final ids = {for (final p in kAllKolkataPujas) p.id: p};

  test('location status sets reference real pandal ids', () {
    for (final id in kUnverifiedLocationIds) {
      expect(ids.containsKey(id), isTrue, reason: id);
    }
    kDuplicatePandalIds.forEach((dup, kept) {
      expect(ids.containsKey(dup), isTrue, reason: dup);
      expect(ids[kept]!.isDuplicateEntry, isFalse, reason: kept);
    });
    expect(kVerifiedLocationIds.intersection(kUnverifiedLocationIds), isEmpty);
  });

  test('Phase 3 counts: 489 distinct, 57 verified, 108 hidden as unverified', () {
    final distinct = kAllKolkataPujas.where((p) => !p.isDuplicateEntry).toList();
    expect(distinct.length, 489);
    expect(distinct.where((p) => kVerifiedLocationIds.contains(p.id)).length, 57);
    expect(distinct.where((p) => p.isLocationUnverified).length, 108);
  });

  test('Gariahat placeholder cluster no longer appears on the map', () {
    final near = kAllKolkataPujas.where((p) =>
        p.hasMappableLocation && _m(p.lat, p.lon, 22.5176, 88.3608) < 400);
    // Only pandals with an OSM-confirmed location remain (Hindustan Park,
    // Triangular Park, Ballygunge Cultural, Tridhara are all just outside or at
    // their real sites).
    for (final p in near) {
      expect(kVerifiedLocationIds.contains(p.id), isTrue, reason: p.id);
    }
  });

  test('unverified pandals suggest no Metro station', () {
    for (final p in kAllKolkataPujas.where((p) => p.isLocationUnverified)) {
      expect(p.detailedMetroGate, startsWith('Location unverified'));
      expect(p.isMetroTooFar, isFalse);
    }
  });

  test('watch pandals.json carries the same unverified / duplicate flags', () {
    final f = File('../wear/app/src/main/assets/pandals.json');
    final list = (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final unv = list.where((p) => p['loc'] == 'u').map((p) => p['id']).toSet();
    final dup = {for (final p in list.where((p) => p['dup'] != null)) p['id']: p['dup']};
    expect(unv, kUnverifiedLocationIds);
    expect(dup, kDuplicatePandalIds);
  });
}
