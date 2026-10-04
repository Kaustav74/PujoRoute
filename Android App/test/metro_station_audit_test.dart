// Regression tests for the Oct 2026 Metro-station audit (PR audit-metro-stations).
// Sources: OpenStreetMap station nodes (osm_base 2026-10-04) and Wikipedia
// "List of Kolkata Metro stations" (rev 1378014463, 55 operational stations).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/hardened_pujo_optimizer.dart';
import 'package:pujoroute/services/metro_graph_service.dart';

double _m(double a, double b, double c, double d) =>
    HardenedPujoOptimizer.distance(a, b, c, d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final metro = MetroGraphService.instance;

  test('every operational station (Oct 2026) is in the graph with coordinates', () {
    const operational = [
      // Orange Line extension Hemanta Mukhopadhyay - Beleghata (opened 22 Aug 2025)
      'VIP Bazar', 'Ritwik Ghatak', 'Barun Sengupta', 'Beleghata',
      // Yellow Line Noapara - Jai Hind Bimanbandar (opened 22 Aug 2025)
      'Noapara', 'Dum Dum Cantonment', 'Jessore Road', 'Jai Hind Bimanbandar',
    ];
    for (final s in operational) {
      expect(metro.hasStation(s), isTrue, reason: s);
      expect(MetroGraphService.kStationCoordinates.containsKey(s), isTrue, reason: s);
    }
    final all = {
      ...MetroGraphService.kBlueLineStations,
      ...MetroGraphService.kGreenLineStations,
      ...MetroGraphService.kPurpleLineStations,
      ...MetroGraphService.kOrangeLineStations,
      ...MetroGraphService.kYellowLineStations,
    };
    expect(all.length, 55);
    expect(MetroGraphService.kStationCoordinates.keys.toSet(), all);
  });

  test('stations that are not open yet are not in the graph', () {
    for (final s in ['Gour Kishore Ghosh', 'Nalban', 'IT Centre', 'Chinar Park', 'Mominpur', 'Khidirpur', 'Victoria']) {
      expect(MetroGraphService.kStationCoordinates.containsKey(s), isFalse, reason: s);
    }
  });

  test('lines for new stations and the Noapara interchange', () {
    expect(metro.getLineForStation('Beleghata'), 'Orange Line');
    expect(metro.getLineForStation('Jessore Road'), 'Yellow Line');
    expect(metro.getLineForStation('Airport'), 'Yellow Line');
    final ic = metro.getInterchange('Blue Line', 'Yellow Line');
    expect(ic, isNotNull);
    expect(ic!.station, 'Noapara');
  });

  test('station coordinates match OpenStreetMap (spot checks, <= 100 m)', () {
    const osm = {
      'Baranagar': [22.65308, 88.38060],
      'Dakshineswar': [22.65403, 88.36375],
      'Salt Lake Sector V': [22.58094, 88.42909],
      'Howrah Maidan': [22.58386, 88.33400],
      'Satyajit Ray': [22.48468, 88.39264],
      'Esplanade': [22.56361, 88.35121],
      'Mahanayak Uttam Kumar': [22.49477, 88.34509],
    };
    osm.forEach((name, c) {
      final a = MetroGraphService.kStationCoordinates[name]!;
      expect(_m(a[0], a[1], c[0], c[1]), lessThan(100), reason: name);
    });
  });

  test('assigned station is the nearest (or within 300 m of it) for every pandal', () {
    // Exceptions flagged in the audit, deliberately unchanged:
    //  - coordinates are an unverified placeholder (name says another locality);
    //  - west-bank (Howrah) pandals keep a Howrah station even when a station
    //    across the Hooghly is nearer in a straight line.
    const flagged = {
      'bhowanipore-sanatan-dharmautsahini-sobha', 'seventy-six-pally-sarbojanin-durgotsab',
      'tollygunge-road-27-pally-bijoyee-sangha', 'southern-satadal', 'lake-yuba-sangha',
      'tarun-brindo-sarbojonin-durga-puja-mondop', 'fatehpur-bazar-durga-puja-pandal',
      'salkia-bharat-sangha', 'salkia-sadharan-durga-puja-jatadhari-park', 'salkia-santi-sangha',
    };
    const coords = MetroGraphService.kStationCoordinates;
    final offenders = <String>[];
    for (final p in kAllKolkataPujas) {
      if (flagged.contains(p.id)) continue;
      final st = metro.getCanonicalStation(p.metroStation)!;
      final assigned = _m(p.lat, p.lon, coords[st]![0], coords[st]![1]);
      final nearest = coords.values.map((c) => _m(p.lat, p.lon, c[0], c[1])).reduce((a, b) => a < b ? a : b);
      if (assigned - nearest > 300) offenders.add('${p.id}: $st');
    }
    expect(offenders, isEmpty);
  });

  test('metro_graph.json lists the same stations as the in-memory lines', () {
    final data = jsonDecode(File('assets/data/metro_graph.json').readAsStringSync()) as Map<String, dynamic>;
    final lines = data['lines'] as Map<String, dynamic>;
    List<String> st(String k) => (lines[k]['stations'] as List).cast<String>();
    expect(st('blue'), MetroGraphService.kBlueLineStations);
    expect(st('green'), MetroGraphService.kGreenLineStations);
    expect(st('purple'), MetroGraphService.kPurpleLineStations);
    expect(st('orange'), MetroGraphService.kOrangeLineStations);
    expect(st('yellow'), MetroGraphService.kYellowLineStations);
  });
}
