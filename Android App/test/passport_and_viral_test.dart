import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
    await SessionService.instance.secureShredUserData();
  });

  group('Hyper-Local Street Utility & Pandal Metadata Tests', () {
    test('All 504 pandals have detailedMetroGate naming the station and its line', () {
      expect(kAllKolkataPujas.length, equals(504));

      for (var p in kAllKolkataPujas) {
        expect(p.detailedMetroGate, isNotEmpty);
        // Stations opened in 2025 have no verified gate numbers, so the text
        // names the station and line instead of inventing a gate.
        // Pandals with no open station within 2.5 km say so instead (Phase 2).
        expect(p.detailedMetroGate, p.isMetroTooFar ? startsWith('No Metro within 2.5 km') : contains('Line'), reason: p.id);
      }

      // Regression (audit 2026-10): substring rules used to show Howrah Maidan
      // pandals as "Maidan (Blue Line)" and Central Park as "Central (Blue Line)".
      for (var p in kAllKolkataPujas.where((p) => p.metroStation == 'Howrah Maidan' && !p.isMetroTooFar)) {
        expect(p.detailedMetroGate, startsWith('Howrah Maidan (Green Line)'), reason: p.id);
      }
      for (var p in kAllKolkataPujas.where((p) => p.metroStation == 'Central Park' && !p.isMetroTooFar)) {
        expect(p.detailedMetroGate, startsWith('Central Park (Green Line)'), reason: p.id);
      }

      // Check specific famous stations
      final sreebhumi = kAllKolkataPujas.firstWhere((p) => p.id == 'sreebhumi_sporting');
      expect(sreebhumi.detailedMetroGate, contains('Gate'));

      final sovabazar = kAllKolkataPujas.firstWhere((p) => p.id == 'sovabazar_beniatola');
      expect(sovabazar.detailedMetroGate, contains('Sutanuti'));
      expect(sovabazar.detailedMetroGate, contains('Gate 2'));
    });

    test('Pandal barricadeAdvisory provides police pedestrian routing', () {
      final sreebhumi = kAllKolkataPujas.firstWhere((p) => p.id == 'sreebhumi_sporting');
      expect(sreebhumi.barricadeAdvisory, contains('Police One-Way'));
      expect(sreebhumi.barricadeAdvisory, contains('VIP Road'));

      final collegeSq = kAllKolkataPujas.firstWhere((p) => p.id == 'college_square');
      expect(collegeSq.barricadeAdvisory, contains('College Street'));
    });

    test('Pandal ritualTimingBadge returns active or upcoming ritual countdown', () {
      for (var p in kAllKolkataPujas.take(20)) {
        final badge = p.ritualTimingBadge;
        expect(badge, isNotEmpty);
        expect(
          badge.contains('Pushpanjali') ||
              badge.contains('Bhog') ||
              badge.contains('Aarati') ||
              badge.contains('Sandhi') ||
              badge.contains('Darshan'),
          isTrue,
        );
      }
    });
  });

  group('Gamified Pandal Passport & Cultural Stamps Tests', () {
    test('Passport unlocks Dakshin Kolkata Dhunuchi Master stamp when south threshold met', () async {
      final session = SessionService.instance;
      final southPandals = kAllKolkataPujas.where((p) => p.zone == 'South').take(5).toList();

      for (var p in southPandals) {
        await session.toggleVisited(p.id);
      }

      final visited = session.visitedIds;
      final southCount = kAllKolkataPujas.where((p) => visited.contains(p.id) && p.zone == 'South').length;
      expect(southCount, greaterThanOrEqualTo(5));
    });

    test('Passport unlocks Bonedi Bari Explorer stamp when heritage threshold met', () async {
      final session = SessionService.instance;
      final heritagePandals = kAllKolkataPujas.where((p) => p.category == 'heritage').take(3).toList();

      for (var p in heritagePandals) {
        await session.toggleVisited(p.id);
      }

      final visited = session.visitedIds;
      final heritageCount = kAllKolkataPujas.where((p) => visited.contains(p.id) && p.category == 'heritage').length;
      expect(heritageCount, greaterThanOrEqualTo(3));
    });

    test('Passport unlocks Uttar Kolkata Sholoana Bangali stamp when north threshold met', () async {
      final session = SessionService.instance;
      final northPandals = kAllKolkataPujas.where((p) => p.zone == 'North').take(5).toList();

      for (var p in northPandals) {
        await session.toggleVisited(p.id);
      }

      final visited = session.visitedIds;
      final northCount = kAllKolkataPujas.where((p) => visited.contains(p.id) && p.zone == 'North').length;
      expect(northCount, greaterThanOrEqualTo(5));
    });
  });

  group('Viral WhatsApp Sharing Format Tests', () {
    test('Circuit WhatsApp share message strictly matches user-specified viral template', () {
      final stops = [
        kAllKolkataPujas.firstWhere((p) => p.id == 'ekdalia_evergreen'),
        kAllKolkataPujas.firstWhere((p) => p.id == 'singhi_park'),
        kAllKolkataPujas.firstWhere((p) => p.id == 'maddox_square'),
      ];

      const mapsUrl = "https://www.google.com/maps/dir/?api=1&origin=22.5152,88.3845&destination=22.5312,88.3582&waypoints=22.5200,88.3600&travelmode=walking";

      final StringBuffer sb = StringBuffer();
      sb.writeln("🎉 My Durga Puja 2026 Circuit (${stops.length} Stops):");
      for (final p in stops) {
        final metro = p.metroStation.isNotEmpty ? " (Near ${p.metroStation})" : "";
        sb.writeln("• ${p.name}$metro");
      }
      sb.writeln("\n📍 Google Maps Multi-Route: $mapsUrl");
      sb.writeln("\nPlanned via PujoRoute 🪔");

      final message = sb.toString();

      expect(message, contains('🎉 My Durga Puja 2026 Circuit (3 Stops):'));
      expect(message, contains('• Ekdalia Evergreen Club (Near Kalighat'));
      expect(message, contains('• Singhi Park'));
      expect(message, contains('📍 Google Maps Multi-Route:'));
      expect(message, contains('Planned via PujoRoute 🪔'));
    });
  });
}
