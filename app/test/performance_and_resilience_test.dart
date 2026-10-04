import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/services/pandal_repository.dart';
import 'package:pujoroute/services/ai_token_gate_service.dart';
import 'package:pujoroute/services/quick_reply_service.dart';

void main() {
  group('PujoRoute Performance & Surge-Resilience Layer Tests', () {
    late PandalRepository repo;
    late AiTokenGateService tokenGate;
    late QuickReplyService quickReply;

    setUp(() {
      repo = PandalRepository();
      tokenGate = AiTokenGateService();
      tokenGate.reset();
      quickReply = QuickReplyService();
    });

    test('1. PandalRepository packages exactly 504 verified pandal records', () {
      expect(repo.recordCount, equals(504));
      expect(repo.allPandals.length, equals(504));
    });

    test('2. datasetVersion is 2026.x and schemaVersion is 1', () {
      expect(PandalRepository.datasetVersion, equals('2026.x'));
      expect(PandalRepository.schemaVersion, equals('1'));
    });

    test('3. validateDatasetIntegrity() succeeds on intact 504 pandal dataset', () {
      expect(repo.validateDatasetIntegrity(), isTrue);
    });

    test('4. isValidCoordinates() rejects invalid or out-of-bound lat/lon', () {
      expect(repo.isValidCoordinates(22.5726, 88.3639), isTrue);
      expect(repo.isValidCoordinates(95.0, 88.3639), isFalse);
      expect(repo.isValidCoordinates(-91.0, 88.3639), isFalse);
      expect(repo.isValidCoordinates(22.5726, 185.0), isFalse);
      expect(repo.isValidCoordinates(double.nan, 88.3639), isFalse);
      expect(repo.isValidCoordinates(22.5726, double.infinity), isFalse);
    });

    test('5. All 504 pandal IDs are unique and non-empty', () {
      final ids = <String>{};
      for (final p in repo.allPandals) {
        expect(p.id.trim().isNotEmpty, isTrue, reason: 'Empty ID found');
        expect(ids.contains(p.id), isFalse, reason: 'Duplicate ID: ${p.id}');
        ids.add(p.id);
      }
      expect(ids.length, equals(504));
    });

    test('6. All 504 pandal names are non-empty strings', () {
      for (final p in repo.allPandals) {
        expect(p.name.trim().isNotEmpty, isTrue, reason: 'Empty name for ID ${p.id}');
      }
    });

    test('7. All 504 pandals have valid Kolkata geographic coordinates', () {
      for (final p in repo.allPandals) {
        expect(repo.isValidCoordinates(p.lat, p.lon), isTrue,
            reason: 'Invalid coordinates (${p.lat}, ${p.lon}) for ${p.id}');
        expect(p.lat >= 22.0 && p.lat <= 23.5, isTrue,
            reason: 'Latitude out of Kolkata range: ${p.lat}');
        expect(p.lon >= 87.0 && p.lon <= 89.5, isTrue,
            reason: 'Longitude out of Greater Kolkata range: ${p.lon}');
      }
    });

    test('8. searchPandals("ekdalia") returns Ekdalia Evergreen offline', () {
      final results = repo.searchPandals("ekdalia");
      expect(results.isNotEmpty, isTrue);
      expect(results.first.name.toLowerCase(), contains("ekdalia"));
    });

    test('9. searchPandals("north") filters North zone pandals offline', () {
      final results = repo.searchPandals("north");
      expect(results.isNotEmpty, isTrue);
      for (final p in results.take(5)) {
        final matches = p.zone.toLowerCase().contains("north") ||
            p.name.toLowerCase().contains("north") ||
            p.subsection.toLowerCase().contains("north");
        expect(matches, isTrue);
      }
    });

    test('10. filterPandals(category: "heritage") returns only heritage Bonedi Bari pandals offline', () {
      final heritage = repo.filterPandals(category: 'heritage');
      expect(heritage.isNotEmpty, isTrue);
      for (final p in heritage) {
        expect(p.category, equals('heritage'));
      }
    });

    test('11. sortByDistance() sorts pandals in ascending Haversine order', () {
      const userLat = 22.5186; // Rashbehari crossing
      const userLon = 88.3636;
      final sorted = repo.sortByDistance(userLat, userLon);

      expect(sorted.length, equals(504));
      double prevDist = 0.0;
      for (int i = 0; i < 10; i++) {
        final dist = repo.calculateHaversineDistanceMeters(
            userLat, userLon, sorted[i].lat, sorted[i].lon);
        expect(dist >= prevDist, isTrue,
            reason: 'Distance out of order at index $i: $dist vs $prevDist');
        prevDist = dist;
      }
    });

    test('12. sortAlphabetically() sorts pandals alphabetically by name', () {
      final sorted = repo.sortAlphabetically();
      expect(sorted.length, equals(504));
      for (int i = 0; i < sorted.length - 1; i++) {
        final cmp = sorted[i].name.toLowerCase().compareTo(sorted[i + 1].name.toLowerCase());
        expect(cmp <= 0, isTrue,
            reason: 'Alphabetical order failed at index $i: "${sorted[i].name}" vs "${sorted[i + 1].name}"');
      }
    });

    test('13. getGoogleMapsUrl() generates valid maps URL without network API calls', () {
      final pandal = repo.allPandals.first;
      final url = repo.getGoogleMapsUrl(pandal);
      expect(url, equals('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${pandal.name}, Kolkata")}'));
    });

    test('14. getDirectionsUrl() generates valid walking directions URL without network calls', () {
      final pandal = repo.allPandals.first;
      const userLat = 22.5726;
      const userLon = 88.3639;
      final url = repo.getDirectionsUrl(userLat, userLon, pandal);
      expect(url, contains('https://www.google.com/maps/dir/?api=1'));
      expect(url, contains('origin=22.5726,88.3639'));
      expect(url, contains('destination=${Uri.encodeComponent("${pandal.name}, Kolkata")}'));
      expect(url, contains('travelmode=walking'));
    });

    test('15. AiTokenGateService permits 2 queries per 5-minute rolling window', () {
      expect(tokenGate.remainingTokens, equals(2));
      expect(tokenGate.canMakeQuery(), isTrue);

      final token1 = tokenGate.tryConsumeToken();
      expect(token1, isTrue);
      tokenGate.releaseInFlight();
      expect(tokenGate.remainingTokens, equals(1));

      final token2 = tokenGate.tryConsumeToken();
      expect(token2, isTrue);
      tokenGate.releaseInFlight();
      expect(tokenGate.remainingTokens, equals(0));
    });

    test('16. AiTokenGateService rejects 3rd query when quota exhausted', () {
      tokenGate.tryConsumeToken();
      tokenGate.releaseInFlight();
      tokenGate.tryConsumeToken();
      tokenGate.releaseInFlight();

      expect(tokenGate.canMakeQuery(), isFalse);
      final token3 = tokenGate.tryConsumeToken();
      expect(token3, isFalse);
    });

    test('17. AiTokenGateService.reset() clears timestamps and restores quota', () {
      tokenGate.tryConsumeToken();
      tokenGate.releaseInFlight();
      tokenGate.tryConsumeToken();
      tokenGate.releaseInFlight();
      expect(tokenGate.remainingTokens, equals(0));

      tokenGate.reset();
      expect(tokenGate.remainingTokens, equals(2));
      expect(tokenGate.canMakeQuery(), isTrue);
    });

    test('18. QuickReplyService matches "sandhi puja" offline with 0 token consumption', () {
      final match = quickReply.matchQuery("When is Sandhi Puja 2026?");
      expect(match, isNotNull);
      expect(match!.id, equals("sandhi_puja"));
      expect(match.response, contains("19 October 2026"));
      expect(tokenGate.remainingTokens, equals(2), reason: 'Quick reply consumed AI token');
    });

    test('19. QuickReplyService matches "metro hours" and "rashbehari" offline', () {
      final metroMatch = quickReply.matchQuery("What are the Metro timing hours?");
      expect(metroMatch, isNotNull);
      expect(metroMatch!.id, equals("metro_hours"));

      final trafficMatch = quickReply.matchQuery("Rashbehari traffic update");
      expect(trafficMatch, isNotNull);
      expect(trafficMatch!.id, equals("rashbehari_traffic"));
    });

    test('20. QuickReplyService returns null for non-static complex queries', () {
      final match = quickReply.matchQuery("What is quantum computing?");
      expect(match, isNull);
    });
  });
}
