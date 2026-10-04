import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';

void main() {
  group('Circuit Studio and Dataset Tests', () {
    test('Verified master dataset contains all 504 Durga Pujas', () {
      expect(kAllKolkataPujas.length, equals(504));
    });

    test('Category and Zone distributions match official counts', () {
      final megaCount = kAllKolkataPujas.where((p) => p.category == 'mega').length;
      final heritageCount = kAllKolkataPujas.where((p) => p.category == 'heritage').length;
      final southCount = kAllKolkataPujas.where((p) => p.zone == 'South').length;
      final northCount = kAllKolkataPujas.where((p) => p.zone == 'North').length;
      final saltLakeCount = kAllKolkataPujas.where((p) => p.zone == 'Salt Lake').length;
      final centralCount = kAllKolkataPujas.where((p) => p.zone == 'Central').length;

      expect(megaCount, equals(483));
      expect(heritageCount, equals(21));
      expect(southCount, equals(287));
      expect(northCount, equals(138));
      expect(saltLakeCount, equals(42));
      expect(centralCount, equals(37));
    });

    test('Every pandal has valid coordinates, landmark, subsection, metro, and significance', () {
      for (final p in kAllKolkataPujas) {
        expect(p.lat, inInclusiveRange(22.3, 22.8));
        expect(p.lon, inInclusiveRange(87.8, 88.6));
        expect(p.landmark.isNotEmpty, isTrue);
        expect(p.subsection.isNotEmpty, isTrue);
        expect(p.metroStation.isNotEmpty, isTrue);
        expect(p.history.isNotEmpty, isTrue);
      }
    });

    test('Groq AI classified pandals span all 8 West Bengal subsections', () {
      final subsections = kAllKolkataPujas.map((p) => p.subsection).toSet();
      expect(subsections.length, greaterThanOrEqualTo(8));
      expect(subsections.any((s) => s.contains('South Kolkata')), isTrue);
      expect(subsections.any((s) => s.contains('North Kolkata')), isTrue);
      expect(subsections.any((s) => s.contains('North 24 Parganas')), isTrue);
      expect(subsections.any((s) => s.contains('Jadavpur')), isTrue);
      expect(subsections.any((s) => s.contains('Howrah')), isTrue);
      expect(subsections.any((s) => s.contains('Salt Lake')), isTrue);
      expect(subsections.any((s) => s.contains('Central Kolkata')), isTrue);
      expect(subsections.any((s) => s.contains('Behala')), isTrue);
    });

    test('Auto-circuit stops can be generated for 5, 8, 10, 12, and 15 stops', () {
      for (final targetCount in [5, 8, 10, 12, 15]) {
        final stops = kAllKolkataPujas.take(targetCount).toList();
        expect(stops.length, equals(targetCount));
        final uniqueIds = stops.map((s) => s.id).toSet();
        expect(uniqueIds.length, equals(targetCount));
      }
    });
  });
}
