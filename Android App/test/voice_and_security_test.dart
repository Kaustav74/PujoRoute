import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pujoroute/services/security_service.dart';
import 'package:pujoroute/services/session_service.dart';
import 'package:pujoroute/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Security and Data Shredder Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getSecureApiKey returns empty string or env token under Zero-Secret Client Architecture', () {
      final apiKey = SessionService.getSecureApiKey();
      expect(apiKey, isA<String>());
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
      await session.saveChatMessages([
        {'role': 'user', 'text': 'Take me to Sreebhumi'},
        {'role': 'bot', 'text': 'Navigating to Sreebhumi Sporting Club'},
      ]);

      // Verify data was populated
      expect(session.bookmarkedIds, contains('sreebhumi_sporting'));
      expect(session.visitedIds, contains('college_square'));
      expect(session.emergencyPhone, equals('9830012345'));
      expect(session.emergencyName, equals('Anirban'));
      expect(session.isCircuitActive, isTrue);
      expect(session.activeCircuitIds, hasLength(2));
      expect(session.chatMessages, hasLength(2));

      // Cryptographic Shred Execution
      await session.secureShredUserData();

      // Verify all data is shredded and wiped clean
      expect(session.bookmarkedIds, isEmpty);
      expect(session.visitedIds, isEmpty);
      expect(session.emergencyPhone, isEmpty);
      expect(session.emergencyName, isEmpty);
      expect(session.isCircuitActive, isFalse);
      expect(session.activeCircuitIds, isEmpty);
      expect(session.chatMessages, isEmpty);
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

    test('saveEmergencyProfile encrypts sensitive medical data in SharedPreferences', () async {
      final session = SessionService.instance;
      await session.init();

      await session.saveEmergencyProfile(phone: '9830099999', name: 'Kaustav', blood: 'O+');

      // Check getters return decrypted data
      expect(session.emergencyPhone, equals('9830099999'));
      expect(session.emergencyName, equals('Kaustav'));
      expect(session.bloodGroup, equals('O+'));

      // Check underlying SharedPreferences storage does not contain raw plaintext
      final prefs = await SharedPreferences.getInstance();
      final storedPhone = prefs.getString('pujo_emergency_phone');
      expect(storedPhone, isNotNull);
      expect(storedPhone!.contains('9830099999'), isFalse, reason: 'Plaintext phone must not be saved in storage');
      expect(storedPhone.startsWith('enc_v1:'), isTrue);
    });
  });

  group('Automated AI Voice Assistant and Intent Engine Tests', () {
    final voice = VoiceAssistantService.instance;

    test('Resolves Navigation Intent for pandal queries', () {
      final res = voice.resolveVoiceIntent('Take me to Sreebhumi');
      expect(res.type, equals(VoiceIntentType.navigation));
      expect(res.targetPandal, isNotNull);
      expect(res.targetPandal!.id, equals('sreebhumi_sporting'));
      expect(res.vocalResponse, contains('Sreebhumi'));
      expect(res.vocalResponse, contains('Google Maps'));
    });

    test('Resolves Navigation Intent for famous keywords like Ekdalia', () {
      final res = voice.resolveVoiceIntent('Navigate to Ekdalia Evergreen');
      expect(res.type, equals(VoiceIntentType.navigation));
      expect(res.targetPandal, isNotNull);
      expect(res.targetPandal!.id, equals('ekdalia_evergreen'));
      expect(res.vocalResponse, contains('Ekdalia Evergreen'));
    });

    test('Resolves Calendar and Sandhi Puja Tithi query', () {
      final res = voice.resolveVoiceIntent('When is Sandhi Puja timing?');
      expect(res.type, equals(VoiceIntentType.calendar));
      expect(res.targetDayId, equals('ashtami'));
      expect(res.vocalResponse, contains('10:28 AM to 11:16 AM'));
      expect(res.vocalResponse, contains('Belur Math'));
    });

    test('Resolves Mahalaya dawn query', () {
      final res = voice.resolveVoiceIntent('What are the timings for Mahalaya?');
      expect(res.type, equals(VoiceIntentType.calendar));
      expect(res.targetDayId, equals('mahalaya'));
      expect(res.vocalResponse, contains('October 10, 2026'));
      expect(res.vocalResponse, contains('4:30 AM'));
    });

    test('Resolves Circuit Planning Intent with custom stop count', () {
      final res = voice.resolveVoiceIntent('Plan a 12 stop pandal circuit for me');
      expect(res.type, equals(VoiceIntentType.circuit));
      expect(res.stopCount, equals(12));
      expect(res.vocalResponse, contains('12-stop'));
      expect(res.vocalResponse, contains('Circuit Studio'));
    });

    test('Resolves Emergency Safety Pass Intent', () {
      final res = voice.resolveVoiceIntent('I need emergency police helpline');
      expect(res.type, equals(VoiceIntentType.emergency));
      expect(res.vocalResponse, contains('Emergency Safety Pass'));
      expect(res.vocalResponse, contains('Kolkata Police'));
    });

    test('Markdown phonetic cleaner sanitizes text for fluid vocal speech', () {
      const markdown = 'Nomoshkar! *Welcome* to **Sreebhumi** [Open Map](https://maps.google.com) • 108 lamps 🪔⚡';
      final clean = VoiceAssistantService.cleanForSpeech(markdown);
      expect(clean, equals('Nomoshkar! Welcome to Sreebhumi Open Map 108 lamps'));
    });
  });

  group('SecurityService & Serverless Gateway Verification Tests', () {
    final security = SecurityService.instance;

    test('generateSignature creates consistent HMAC-SHA256 digests', () {
      const ts = 1725700000000;
      const payload = '{"query":"Find Bonedi Baris"}';
      final sig1 = security.generateSignature(payload, ts);
      final sig2 = security.generateSignature(payload, ts);

      expect(sig1, isNotEmpty);
      expect(sig1, equals(sig2));
      expect(sig1.length, equals(64)); // SHA-256 hex string length
    });

    test('verifySignature validates fresh signatures and rejects expired ones (>60s)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const payload = '{"test":true}';
      final validSig = security.generateSignature(payload, now);

      // Fresh signature passes
      expect(security.verifySignature(payload, now, validSig), isTrue);

      // Tampered payload fails
      expect(security.verifySignature('{"tampered":true}', now, validSig), isFalse);

      // Expired signature (> 60 seconds = 60,001 ms) fails anti-replay check
      final expiredTs = now - 60001;
      final expiredSig = security.generateSignature(payload, expiredTs);
      expect(security.verifySignature(payload, expiredTs, expiredSig), isFalse);
    });

    test('createVerificationHeaders provides all required proxy gateway headers including X-Client-UUID', () {
      final headers = security.createVerificationHeaders('{"action":"ping"}', clientUuid: 'test-uuid-12345');
      expect(headers['Content-Type'], equals('application/json'));
      expect(headers['X-PujoRoute-Signature'], isNotEmpty);
      expect(headers['X-PujoRoute-Timestamp'], isNotEmpty);
      expect(headers['X-App-Platform'], equals('android'));
      expect(headers['X-App-Integrity'], equals('verified-v1'));
      expect(headers['X-Client-UUID'], equals('test-uuid-12345'));
    });

    test('encryptSensitive and decryptSensitive correctly round-trip without data loss', () {
      const plaintext = "Emergency contact: Dr. Sen, SSKM Trauma Ward, Phone: 9831122334";
      final encrypted = security.encryptSensitive(plaintext);

      expect(encrypted.startsWith("enc_v1:"), isTrue);
      expect(encrypted.contains("9831122334"), isFalse);

      final decrypted = security.decryptSensitive(encrypted);
      expect(decrypted, equals(plaintext));
    });
  });
}
