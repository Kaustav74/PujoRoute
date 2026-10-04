import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/pandal_deduplication_service.dart';

void main() {
  group('Pandal Deduplication Engine', () {
    final dedup = PandalDeduplicationService.instance;

    test('Noise token filtering extracts core tokens correctly', () {
      final t1 = dedup.extractCoreTokens('Purbachal Shakti Sangha Club');
      expect(t1, containsAll(['purbachal', 'shakti']));
      expect(t1.contains('club'), isFalse);
      expect(t1.contains('sangha'), isFalse);

      final t2 = dedup.extractCoreTokens('Shakti Sangha');
      expect(t2, contains('shakti'));
      expect(t2.contains('sangha'), isFalse);

      final t3 = dedup.extractCoreTokens('Ekdalia Evergreen Club');
      expect(t3, containsAll(['ekdalia', 'evergreen']));
      expect(t3.contains('club'), isFalse);

      final t4 = dedup.extractCoreTokens('Singhi Park Sarbojanin');
      expect(t4, containsAll(['singhi', 'park']));
      expect(t4.contains('sarbojanin'), isFalse);
    });

    test('Garfa/Haltu: Shakti Sangha Club and Purbachal Shakti Sangha merge into 1 record', () {
      final purbachal = kAllKolkataPujas.firstWhere((p) => p.id == 'purbachal-shakti-sangha');
      final shaktiClub = kAllKolkataPujas.firstWhere((p) => p.id == 'shakti-sangha-clubs-durga-puja-ground');

      expect(dedup.isDuplicatePair(purbachal, shaktiClub), isTrue);

      final list = [purbachal, shaktiClub];
      final deduplicated = dedup.deduplicate(list);
      expect(deduplicated.length, equals(1));
      // Richer entry is kept
      expect(deduplicated.first.id, equals('purbachal-shakti-sangha'));
    });

    test('Condition C (Never Merge): Ekdalia Evergreen and Singhi Park remain separate', () {
      final ekdalia = kAllKolkataPujas.firstWhere((p) => p.id == 'ekdalia_evergreen');
      final singhi = kAllKolkataPujas.firstWhere((p) => p.id == 'singhi_park');

      expect(dedup.isDuplicatePair(ekdalia, singhi), isFalse);

      final list = [ekdalia, singhi];
      final deduplicated = dedup.deduplicate(list);
      expect(deduplicated.length, equals(2));
    });

    test('Condition C (Never Merge): Distinct roots like Behala Natun vs Behala Trishakti never merge', () {
      final natun = kAllKolkataPujas.firstWhere((p) => p.id == 'behala-natun-sangha-puja-committee');
      final trishakti = kAllKolkataPujas.firstWhere((p) => p.id == 'behala-trishakti-sangha');

      expect(dedup.isDuplicatePair(natun, trishakti), isFalse);

      final list = [natun, trishakti];
      final deduplicated = dedup.deduplicate(list);
      expect(deduplicated.length, equals(2));
    });

    test('Telengabagan Sarbojanin and Telengabagan Sarbojanin Durgotsab merge into 1 record', () {
      final tel1 = kAllKolkataPujas.firstWhere((p) => p.id == 'telengabagan');
      final tel2 = kAllKolkataPujas.firstWhere((p) => p.id == 'telengabagan-sarbojanin-durgotsab');

      expect(dedup.isDuplicatePair(tel1, tel2), isTrue);

      final list = [tel1, tel2];
      final deduplicated = dedup.deduplicate(list);
      expect(deduplicated.length, equals(1));
      expect(deduplicated.first.id, equals('telengabagan'));
    });

    test('Richer entry selection preserves verified metro gate and historical metadata', () {
      const pA = Pandal(
        id: 'sample-pandal-a',
        name: 'Sample Durga Puja Club',
        category: 'mega',
        zone: 'South',
        subsection: 'South Kolkata',
        lat: 22.5000,
        lon: 88.3500,
        landmark: 'Near crossing',
        metroStation: 'Kalighat (Gate 2)',
        history: 'Founded in 1948 with profound cultural heritage and community involvement.',
        gateStatus: 'open',
        gateClosingTime: '01:00 PM',
        crowdStatus: 'fast',
      );

      const pB = Pandal(
        id: 'sample-pandal-clubs-b',
        name: 'Sample Durga Puja Ground',
        category: 'mega',
        zone: 'South',
        subsection: 'South Kolkata',
        lat: 22.5001,
        lon: 88.3501,
        landmark: '',
        metroStation: 'None',
        history: 'Community festival.',
        gateStatus: 'open',
        gateClosingTime: '01:00 PM',
        crowdStatus: 'fast',
      );

      final richer = dedup.pickRicherEntry(pA, pB);
      expect(richer.id, equals('sample-pandal-a'));
    });
  });

  group('2-Opt TSP Optimizer & Crossing Elimination', () {
    double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
      const double r = 6371000;
      final double phi1 = lat1 * pi / 180;
      final double phi2 = lat2 * pi / 180;
      final double deltaPhi = (lat2 - lat1) * pi / 180;
      final double deltaLambda = (lon2 - lon1) * pi / 180;
      final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
          cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return r * c * 1.25;
    }

    List<Pandal> apply2Opt(List<Pandal> route) {
      if (route.length <= 3) return route;
      List<Pandal> bestRoute = List.from(route);
      bool improved = true;
      int iterations = 0;
      const int maxIterations = 100;

      while (improved && iterations < maxIterations) {
        improved = false;
        iterations++;
        final int n = bestRoute.length;
        for (int i = 0; i <= n - 2; i++) {
          for (int j = i + 2; j < n; j++) {
            if (j + 1 >= n) continue;
            final pi = bestRoute[i];
            final pi1 = bestRoute[i + 1];
            final pj = bestRoute[j];
            final pj1 = bestRoute[j + 1];

            final double costCurrent = distanceMeters(pi.lat, pi.lon, pi1.lat, pi1.lon) +
                distanceMeters(pj.lat, pj.lon, pj1.lat, pj1.lon);
            final double costSwapped = distanceMeters(pi.lat, pi.lon, pj.lat, pj.lon) +
                distanceMeters(pi1.lat, pi1.lon, pj1.lat, pj1.lon);
            final double delta = costSwapped - costCurrent;

            if (delta < -0.001) {
              bestRoute = <Pandal>[
                ...bestRoute.sublist(0, i + 1),
                ...bestRoute.sublist(i + 1, j + 1).reversed,
                ...bestRoute.sublist(j + 1),
              ];
              improved = true;
              break;
            }
          }
          if (improved) break;
        }
      }
      return bestRoute;
    }

    double totalTourDistance(List<Pandal> route) {
      double total = 0.0;
      for (int i = 0; i < route.length - 1; i++) {
        total += distanceMeters(route[i].lat, route[i].lon, route[i + 1].lat, route[i + 1].lon);
      }
      return total;
    }

    test('2-Opt unwinds crossing diagonal paths and reduces total distance', () {
      // 4 corners of a square:
      // A (0, 0), B (0, 1), C (1, 1), D (1, 0)
      // Natural perimeter: A -> B -> C -> D
      // Crossing bowtie order: A (0,0) -> C (1,1) -> B (0,1) -> D (1,0)
      const pA = Pandal(id: 'a', name: 'A', category: 'm', zone: 'z', subsection: 's', lat: 22.50, lon: 88.35, landmark: '', metroStation: '', history: '', gateStatus: 'open', gateClosingTime: '', crowdStatus: 'fast');
      const pC = Pandal(id: 'c', name: 'C', category: 'm', zone: 'z', subsection: 's', lat: 22.51, lon: 88.36, landmark: '', metroStation: '', history: '', gateStatus: 'open', gateClosingTime: '', crowdStatus: 'fast');
      const pB = Pandal(id: 'b', name: 'B', category: 'm', zone: 'z', subsection: 's', lat: 22.50, lon: 88.36, landmark: '', metroStation: '', history: '', gateStatus: 'open', gateClosingTime: '', crowdStatus: 'fast');
      const pD = Pandal(id: 'd', name: 'D', category: 'm', zone: 'z', subsection: 's', lat: 22.51, lon: 88.35, landmark: '', metroStation: '', history: '', gateStatus: 'open', gateClosingTime: '', crowdStatus: 'fast');

      final crossedRoute = [pA, pC, pB, pD];
      final distCrossed = totalTourDistance(crossedRoute);

      final uncrossedRoute = apply2Opt(crossedRoute);
      final distUncrossed = totalTourDistance(uncrossedRoute);

      // Uncrossed distance must be strictly shorter than crossing bowtie
      expect(distUncrossed, lessThan(distCrossed));
    });
  });

  group('Google Maps Export URL Enforcement', () {
    test('Formats coordinates with 5 decimal places and walking mode', () {
      const double originLat = 22.5185432;
      const double originLon = 88.3654123;
      const double destLat = 22.5256789;
      const double destLon = 88.3712345;

      final origin = '${originLat.toStringAsFixed(5)},${originLon.toStringAsFixed(5)}';
      final dest = '${destLat.toStringAsFixed(5)},${destLon.toStringAsFixed(5)}';

      final intermediateLatLons = [
        const Point<double>(22.519001, 88.366009),
        const Point<double>(22.521008, 88.368007),
      ];

      final waypoints = intermediateLatLons
          .map((pt) => '${pt.x.toStringAsFixed(5)},${pt.y.toStringAsFixed(5)}')
          .join('%7C');

      final url = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&waypoints=$waypoints&travelmode=walking';

      expect(url, contains('origin=22.51854,88.36541'));
      expect(url, contains('destination=22.52568,88.37123'));
      expect(url, contains('waypoints=22.51900,88.36601%7C22.52101,88.36801'));
      expect(url, contains('travelmode=walking'));
      expect(url.contains('undefined'), isFalse);
      expect(url.contains('null'), isFalse);
    });
  });
}
