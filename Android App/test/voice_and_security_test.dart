import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pujoroute/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Security and Data Shredder Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('secureShredUserData wipes all bookmarks, visited, history, emergency contacts, and circuits', () async {
      final session = SessionService.instance;
      await session.init();

      // Seed mock telemetry and user data
      await session.toggleBookmark('sreebhumi_sporting');
      await session.toggleVisited('college_square');
      await session.saveEmergencyProfile(phone: '9830012345', name: 'Anirban', blood: 'B+');
      await session.saveLastPosition(22.5726, 88.3639);
      await session.saveCircuit(['sreebhumi_sporting', 'college_square'], true);
      await session.reportCrowdStatus('sreebhumi_sporting', 'slow');

      // Verify data was populated
      expect(session.bookmarkedIds, contains('sreebhumi_sporting'));
      expect(session.visitedIds, contains('college_square'));
      expect(session.emergencyPhone, equals('9830012345'));
      expect(session.emergencyName, equals('Anirban'));
      expect(session.isCircuitActive, isTrue);
      expect(session.activeCircuitIds, hasLength(2));
      expect(session.getCrowdReport('sreebhumi_sporting'), equals('slow'));

      // Cryptographic Shred Execution
      await session.secureShredUserData();

      // Verify all data is shredded and wiped clean
      expect(session.bookmarkedIds, isEmpty);
      expect(session.visitedIds, isEmpty);
      expect(session.emergencyPhone, isEmpty);
      expect(session.emergencyName, isEmpty);
      expect(session.isCircuitActive, isFalse);
      expect(session.activeCircuitIds, isEmpty);
      expect(session.getCrowdReport('sreebhumi_sporting'), isNull);
      expect(session.lastLat, isNull);
      expect(session.lastLon, isNull);
    });

    test('Auto-Speak toggle persists in SessionService', () async {
      final session = SessionService.instance;
      await session.init();

      expect(session.isAutoSpeakEnabled, isTrue);
      await session.setAutoSpeakEnabled(false);
      expect(session.isAutoSpeakEnabled, isFalse);
      await session.setAutoSpeakEnabled(true);
      expect(session.isAutoSpeakEnabled, isTrue);
    });

    test('saveEmergencyProfile persists on-device and round-trips', () async {
      final session = SessionService.instance;
      await session.init();

      await session.saveEmergencyProfile(phone: '9830099999', name: 'Kaustav', blood: 'O+');

      expect(session.emergencyPhone, equals('9830099999'));
      expect(session.emergencyName, equals('Kaustav'));
      expect(session.bloodGroup, equals('O+'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pujo_emergency_phone'), equals('9830099999'));
    });
  });
}
