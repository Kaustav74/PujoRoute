import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/services/emergency_service.dart';
import 'package:pujoroute/services/live_feed_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Belur Math & Vishuddha Siddhanta Panjika 2026 Alignment', () {
    test('panjika_2026.json contains accurate Belur Math Sandhi Puja and ritual timings', () {
      final file = File('assets/data/panjika_2026.json');
      expect(file.existsSync(), isTrue, reason: 'assets/data/panjika_2026.json must exist');

      final content = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      expect(data['year'], equals(2026));
      expect(data['almanac_benchmark'], contains('Vishuddha Siddhanta'));
      expect(data['almanac_benchmark'], contains('Belur Math'));

      final List milestones = data['milestones'];
      expect(milestones.length, equals(8));

      // Locate Ashtami
      final ashtami = milestones.firstWhere((m) => m['id'] == 'ashtami');
      expect(ashtami, isNotNull);

      final rituals = ashtami['rituals'];
      expect(rituals['sandhi_puja_start'], equals('10:28 AM'));
      expect(rituals['sandhi_puja_end'], equals('11:16 AM'));
      expect(rituals['balidan_moment'], equals('10:52 AM'));
      expect(rituals['pushpanjali_cutoff'], equals('10:15 AM'));
    });
  });

  group('Emergency Service & Bystander Intent Engine Tests', () {
    final emergency = EmergencyService.instance;

    test('isEmergencyIntent triggers accurately on Bengali and English distress terms', () {
      expect(emergency.isEmergencyIntent('Lost my friend in the crowd!'), isTrue);
      expect(emergency.isEmergencyIntent('Medical emergency near pandal'), isTrue);
      expect(emergency.isEmergencyIntent('Someone fainted, need doctor'), isTrue);
      expect(emergency.isEmergencyIntent('Amake bachan, bipod e porechi'), isTrue);
      expect(emergency.isEmergencyIntent('Police booth kothay?'), isTrue);
      expect(emergency.isEmergencyIntent('First aid center needed urgently'), isTrue);
      expect(emergency.isEmergencyIntent('Chest pain, ambulance dorkar'), isTrue);
      expect(emergency.isEmergencyIntent('pocketmaar hoyeche purse churi'), isTrue);

      // Normal navigation queries must not trigger emergency
      expect(emergency.isEmergencyIntent('Suggest 3 quiet bonedi baris near Sovabazar'), isFalse);
      expect(emergency.isEmergencyIntent('How far is Sreebhumi from Ultadanga?'), isFalse);
      expect(emergency.isEmergencyIntent('What is the nearest metro to Tridhara?'), isFalse);
    });

    test('findNearestHospital accurately resolves closest casualty center', () {
      // Near South Kolkata / Bhawanipore (around SSKM Hospital 22.5385, 88.3444)
      final hospSouth = emergency.findNearestHospital(22.5400, 88.3450);
      expect(hospSouth.name, contains('SSKM'));
      expect(hospSouth.phone, isNotEmpty);

      // Near North Kolkata / Belgachia (around RG Kar 22.6041, 88.3752)
      final hospNorth = emergency.findNearestHospital(22.6050, 88.3740);
      expect(hospNorth.name, contains('R.G. Kar'));

      // Near EM Bypass / Ruby (22.5135, 88.4025)
      final hospEast = emergency.findNearestHospital(22.5135, 88.4010);
      expect(hospEast.name, contains('Ruby'));
    });

    test('findNearestPoliceBooth only returns the verified Lalbazar control room', () {
      expect(EmergencyService.kPoliceBooths.length, 1);
      final booth = emergency.findNearestPoliceBooth(22.5200, 88.3600);
      expect(booth.division, contains('Lalbazar'));
      expect(booth.contact, contains('033-2214-3230'));
    });

    test('generateEmergencyGuidance produces direct helpline and casualty ward info without conversational fluff', () {
      final text = emergency.generateEmergencyGuidance(
        'I lost my brother in the crowd near Maddox Square',
        22.5280,
        88.3580,
      );

      expect(text, contains('EMERGENCY'));
      expect(text, contains('100')); // Police
      expect(text, contains('1091')); // Women helpline (Kolkata)
      expect(text, isNot(contains('1090')), reason: '1090 is not a Kolkata/WB helpline');
      expect(text, contains('Fire Brigade: 101'));
      expect(text, contains('Lalbazar'));
      expect(text, contains('1098')); // Child helpline
      expect(text, isNot(contains('102 / 108')));
    });

    test('medical guidance never claims a hospital status (offline data)', () {
      // Every hospital in the bundled list, reached via its own coordinates.
      for (final h in EmergencyService.kKolkataCasualtyHospitals) {
        final text = emergency.generateEmergencyGuidance('medical emergency', h.lat, h.lon);
        expect(text, contains('Call ahead to confirm'));
        expect(text, isNot(contains('24x7')));
        expect(text, isNot(contains('Facility Status')));
        expect(text, isNot(contains('Active')));
      }
    });
  });

  group('Live Feed Service & Traffic Bypass Tests', () {
    final live = LiveFeedService.instance;

    test('shouldRerouteAround accurately detects high congestion pandals', () {
      // Sreebhumi Sporting Club is on VIP Road (Severe crowd pressure, 75m wait)
      expect(live.shouldRerouteAround('Sreebhumi Sporting Club'), isTrue);

      // Suruchi Sangha is on New Alipore (Barricaded diversion, 60m wait)
      expect(live.shouldRerouteAround('Suruchi Sangha'), isTrue);

      // Smooth flowing pandals (<60m wait) should not trigger mandatory reroute
      expect(live.shouldRerouteAround('Ekdalia Evergreen Club'), isFalse);
      expect(live.shouldRerouteAround('Sovabazar Rajbari'), isFalse);
    });

    test('shouldRerouteAround does not match empty or very short names (regression)', () {
      expect(live.shouldRerouteAround(''), isFalse);
      expect(live.shouldRerouteAround('  '), isFalse);
      expect(live.shouldRerouteAround('Sre'), isFalse);
    });

    test('getPandalLiveStatus provides valid wait time and status indicator', () {
      final waitInfo = live.getPandalLiveStatus('Suruchi Sangha');
      expect(waitInfo['wait'], inInclusiveRange(5, 120));
      expect(waitInfo['advisory'].toString().isNotEmpty, isTrue);
      expect(['smooth', 'moderate', 'heavy'], contains(waitInfo['status']));
    });
  });
}
