// Phase 2 (route logic) audit, Oct 2026. See /workspace/pujoroute-audit/PROGRESS.md.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/hardened_pujo_optimizer.dart';
import 'package:pujoroute/services/metro_graph_service.dart';

Pandal _p(String id, double lat, double lon, String station) => Pandal(
    id: id, name: id, category: 'mega', zone: 'South', subsection: '',
    lat: lat, lon: lon, landmark: '', metroStation: station, history: '');

/// Point [metres] north of a station.
Pandal _near(String id, String station, double metres) {
  final c = MetroGraphService.kStationCoordinates[station]!;
  return _p(id, c[0] + metres / 111195.0, c[1], station);
}

void main() {
  final metro = MetroGraphService.instance;

  group('Network topology', () {
    test('Kavi Subhash is Orange-only while its Blue Line platforms are closed', () {
      expect(MetroGraphService.kBlueLineStations.last, 'Shahid Khudiram');
      expect(MetroGraphService.kBlueLineStations, isNot(contains('Kavi Subhash')));
      expect(metro.getLineForStation('Kavi Subhash'), 'Orange Line');
      expect(metro.getLineForStation('New Garia'), 'Orange Line');
    });

    test('metro_graph.json matches the Dart line lists (single topology)', () {
      final data = jsonDecode(File('assets/data/metro_graph.json').readAsStringSync());
      final lines = data['lines'] as Map<String, dynamic>;
      expect(List<String>.from(lines['blue']['stations']), MetroGraphService.kBlueLineStations);
      expect(List<String>.from(lines['green']['stations']), MetroGraphService.kGreenLineStations);
      expect(List<String>.from(lines['purple']['stations']), MetroGraphService.kPurpleLineStations);
      expect(List<String>.from(lines['orange']['stations']), MetroGraphService.kOrangeLineStations);
      expect(List<String>.from(lines['yellow']['stations']), MetroGraphService.kYellowLineStations);
    });

    test('main() loads the bundled metro graph', () {
      expect(File('lib/main.dart').readAsStringSync(), contains('MetroGraphService.instance.initialize()'));
    });
  });

  group('Metro path finding', () {
    test('same line: Kalighat to Esplanade is 6 Blue Line stops', () {
      final p = metro.findMetroPath('Kalighat', 'Esplanade')!;
      expect(p.legs.length, 1);
      expect(p.legs.first.line, 'Blue Line');
      expect(p.stops, 6);
      expect(p.transfers, isEmpty);
      expect(p.legs.first.direction, contains('Northbound'));
    });

    test('Green to Blue changes at Esplanade', () {
      final p = metro.findMetroPath('Sealdah', 'Kalighat')!;
      expect(p.transfers, ['Esplanade']);
      expect(p.legs.map((l) => l.line), ['Green Line', 'Blue Line']);
      expect(p.stops, 1 + 6);
    });

    test('Blue to Yellow changes at Noapara', () {
      final p = metro.findMetroPath('Shyambazar', 'Jai Hind Bimanbandar')!;
      expect(p.transfers, ['Noapara']);
      expect(p.legs.last.line, 'Yellow Line');
      expect(p.legs.last.stops, 3);
    });

    test('Blue to Orange needs the Shahid Khudiram to Kavi Subhash road link', () {
      final p = metro.findMetroPath('Kalighat', 'Hemanta Mukhopadhyay')!;
      expect(p.transfers, isEmpty);
      expect(p.roadLinks.single, 'Shahid Khudiram ↔ Kavi Subhash');
      expect(p.legs.first.to, 'Shahid Khudiram');
      expect(p.legs.last.from, 'Kavi Subhash');
    });

    test('Purple Line is not connected to the rest of the network', () {
      expect(metro.findMetroPath('Taratala', 'Kalighat'), isNull);
      expect(metro.findMetroPath('Joka', 'Majerhat')!.stops, 6);
    });
  });

  group('Walk vs Metro decision', () {
    test('short hop is a walk', () {
      final g = metro.buildMetroHopGuidance(
          hopIndex: 1, fromP: _near('a', 'Kalighat', 100), toP: _near('b', 'Kalighat', 900));
      expect(g.recommendation, TransitRecommendation.walk);
    });

    test('a 1-stop ride that needs long walks to and from the stations is a walk', () {
      // ~1.5 km east of each station (2 stops apart): door to door the Metro
      // is slower than walking straight across.
      Pandal east(String id, String st) {
        final c = MetroGraphService.kStationCoordinates[st]!;
        return _p(id, c[0], c[1] + 1500 / 102800.0, st);
      }
      final a = east('a', 'Rabindra Sarobar');
      final b = east('b', 'Jatin Das Park');
      final g = metro.buildMetroHopGuidance(hopIndex: 1, fromP: a, toP: b);
      expect(g.directWalkMeters, greaterThan(1300));
      expect(g.recommendation, TransitRecommendation.walk);
      expect(g.detailedAdvice, contains('door to door'));
    });

    test('long same-line hop near stations is Metro Recommended with door-to-door time', () {
      final g = metro.buildMetroHopGuidance(
          hopIndex: 1, fromP: _near('a', 'Shyambazar', 200), toP: _near('b', 'Kalighat', 200));
      expect(g.recommendation, TransitRecommendation.metroRecommended);
      expect(g.stationCount, 12);
      expect(g.estimatedMetroMinutes, lessThan(g.directWalkMinutes));
      expect(g.headline, contains('door to door'));
      expect(g.fareRupees, greaterThan(0));
    });

    test('cross-line hop names the interchange and is Metro Possible', () {
      final g = metro.buildMetroHopGuidance(
          hopIndex: 1, fromP: _near('a', 'Sealdah', 200), toP: _near('b', 'Kalighat', 200));
      expect(g.recommendation, TransitRecommendation.metroPossible);
      expect(g.recommendationLabel, 'Metro Possible');
      expect(g.headline, contains('Esplanade'));
      expect(g.isInterchange, isTrue);
    });

    test('Purple Line to Blue Line is honest about the missing rail link', () {
      final g = metro.buildMetroHopGuidance(
          hopIndex: 1, fromP: _near('a', 'Taratala', 200), toP: _near('b', 'Kalighat', 200));
      expect(g.recommendationLabel, 'Auto / Cab');
      expect(g.detailedAdvice, contains('no rail link'));
    });

    test('pandal more than 2.5 km from any station never gets a Metro suggestion', () {
      final far = _near('far', 'Joka', 6000);
      expect(far.isMetroTooFar, isTrue);
      expect(far.detailedMetroGate, startsWith('No Metro within 2.5 km'));
      final g = metro.buildMetroHopGuidance(hopIndex: 1, fromP: far, toP: _near('b', 'Kalighat', 100));
      expect(g.recommendation, isNot(TransitRecommendation.metroRecommended));
      expect(g.recommendationLabel, 'Auto / Cab');
    });
  });

  group('Optimize by Metro anchors', () {
    test('exit anchor is at walking-circuit distance, not the farthest metro pandal', () {
      final pool = kAllKolkataPujas.where(HardenedPujoOptimizer.hasUsableMetro).toList();
      final start = pool.firstWhere((p) => p.metroStation == 'Kalighat');
      final exit = HardenedPujoOptimizer.pickMetroExitAnchor(start: start, candidates: pool, stops: 8)!;
      final d = HardenedPujoOptimizer.distance(start.lat, start.lon, exit.lat, exit.lon);
      expect(d, lessThan(6000));
      expect(exit.metroStation, isNot(start.metroStation));
      expect(exit.isMetroTooFar, isFalse);
    });

    test('8-stop metro-anchored circuit has no hop longer than 5 km', () {
      final pool = kAllKolkataPujas.where((p) => p.category == 'mega').toList();
      final metroPool = pool.where(HardenedPujoOptimizer.hasUsableMetro).toList();
      final start = metroPool.firstWhere((p) => p.metroStation == 'Kalighat');
      final exit = HardenedPujoOptimizer.pickMetroExitAnchor(start: start, candidates: metroPool, stops: 8)!;
      final r = HardenedPujoOptimizer.generateHomeBoundCircuit(
          pool: pool, startLat: start.lat, startLng: start.lon,
          homeLat: exit.lat, homeLng: exit.lon, requestedStops: 8).route;
      var worst = 0.0;
      for (var i = 1; i < r.length; i++) {
        worst = max(worst, HardenedPujoOptimizer.distance(r[i - 1].lat, r[i - 1].lon, r[i].lat, r[i].lon));
      }
      expect(worst, lessThan(5000));
    });
  });

  test('pandals without a station within 2.5 km are a known, bounded set', () {
    final far = kAllKolkataPujas.where((p) => p.isMetroTooFar).length;
    // 67 after Phase 2; 50 after Phase 3, which marks placeholder locations
    // as unverified (those suggest no station at all).
    expect(far, inInclusiveRange(40, 60));
  });

  test('watch pandals.json is in sync with the phone data (station, line, gate)', () {
    final f = File('../wear/app/src/main/assets/pandals.json');
    final list = (jsonDecode(f.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final byId = {for (final w in list) w['id'] as String: w};
    expect(byId.length, kAllKolkataPujas.length);
    for (final p in kAllKolkataPujas) {
      final w = byId[p.id]!;
      expect(w['metro'],
          p.isLocationUnverified ? null : metro.getCanonicalStation(p.metroStation),
          reason: p.id);
      expect(w['gate'], p.detailedMetroGate, reason: p.id);
      expect((w['lat'] as num).toDouble(), closeTo(p.lat, 0.00006), reason: p.id);
    }
  });
}
