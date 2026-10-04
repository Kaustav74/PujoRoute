import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/data/puja_calendar_data.dart';
import 'package:pujoroute/services/spatial_facility_service.dart';
import 'package:pujoroute/screens/circuit_studio_screen.dart';
import 'package:pujoroute/services/metro_graph_service.dart';

void main() {
  group('SpatialFacilityService Proximity & Fallback Tests', () {
    test('Calculates clean washroom, drinking water, and police booth for central/south pandals', () {
      final service = SpatialFacilityService.instance;
      // Ekdalia Evergreen in South Kolkata
      final ekdalia = kAllKolkataPujas.firstWhere((p) => p.id == 'ekdalia_evergreen');

      final facilities = service.getNearestFacilities(ekdalia);

      expect(facilities.washroomInfo, isNotEmpty);
      expect(facilities.waterInfo, isNotEmpty);
      expect(facilities.policeInfo, isNotEmpty);

      // Verify that chips contain expected iconography
      expect(facilities.chips.any((c) => c.contains('🚻')), isTrue);
      expect(facilities.chips.any((c) => c.contains('💧')), isTrue);
      expect(facilities.chips.any((c) => c.contains('👮')), isTrue);
    });

    test('Triggers volunteer assistance desk fallback when coordinates are beyond 800m', () {
      final service = SpatialFacilityService.instance;
      // Mock pandal far away in outskirts
      const remotePandal = Pandal(
        id: 'remote_outskirts_test',
        name: 'Remote Suburban Puja',
        category: 'traditional',
        zone: 'North',
        subsection: 'Outskirts Highway',
        lat: 22.8500,
        lon: 88.5000,
        landmark: 'Outskirts Highway',
        metroStation: 'None',
        history: 'Historic community puja.',
        crowdStatus: 'fast',
      );

      final facilities = service.getNearestFacilities(remotePandal);

      expect(facilities.washroomInfo, contains('Designated volunteer'));
      expect(facilities.waterInfo, contains('Designated volunteer'));
      expect(facilities.policeInfo, contains('Designated volunteer'));
    });
  });

  group('2026 Puja Milestones & Countdown Clock Tests', () {
    test('Contains all 2026 milestones with exact epoch targets', () {
      expect(kPuja2026Milestones, isNotEmpty);

      final mahalaya = kPuja2026Milestones.firstWhere((m) => m.id == 'mahalaya');
      expect(mahalaya.targetDateTime.year, equals(2026));
      expect(mahalaya.targetDateTime.month, equals(10));
      expect(mahalaya.targetDateTime.day, equals(10));
      expect(mahalaya.targetDateTime.hour, equals(6));

      final ashtami = kPuja2026Milestones.firstWhere((m) => m.id == 'ashtami');
      expect(ashtami.targetDateTime.year, equals(2026));
      expect(ashtami.targetDateTime.month, equals(10));
      expect(ashtami.targetDateTime.day, equals(19));

      final sandhi = kPuja2026Milestones.firstWhere((m) => m.id == 'sandhi_puja');
      expect(sandhi.targetDateTime.hour, equals(10));
      expect(sandhi.targetDateTime.minute, equals(28));
    });

    test('getNextActiveMilestone returns an active upcoming milestone for 2026', () {
      final next = getNextActiveMilestone(DateTime.now());
      expect(next, isNotNull);
      expect(next.name, isNotEmpty);
    });

    test('getMilestoneForDayId finds valid milestones', () {
      final shashthi = getMilestoneForDayId('shashthi');
      expect(shashthi, isNotNull);
      expect(shashthi.targetDateTime.day, equals(16));

      final dashami = getMilestoneForDayId('dashami');
      expect(dashami, isNotNull);
      expect(dashami.targetDateTime.day, equals(21));
    });
  });

  group('Kolkata Metro Coordinates & Transit Registry Tests', () {
    test('Verified Kolkata Metro Coordinates contain all key transit stations', () {
      expect(kKolkataMetroCoordinates, isNotEmpty);
      final names = kKolkataMetroCoordinates.map((m) => m.name.toLowerCase()).toList();

      expect(names.contains('kalighat'), isTrue);
      expect(names.contains('sovabazar sutanuti'), isTrue);
      expect(names.contains('esplanade'), isTrue);
      expect(names.contains('sealdah'), isTrue);
      expect(names.contains('karunamoyee'), isTrue);
      expect(names.contains('salt lake sector v'), isTrue);
      // Single source of truth: same stations and coordinates as the metro graph.
      expect(kKolkataMetroCoordinates.length, MetroGraphService.kStationCoordinates.length);
      for (final m in kKolkataMetroCoordinates) {
        expect(MetroGraphService.kStationCoordinates[m.name], [m.lat, m.lon], reason: m.name);
        expect(m.line, isNotEmpty, reason: m.name);
      }
    });
  });
}
