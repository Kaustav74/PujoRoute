import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/puja_calendar_data.dart';
import 'package:pujoroute/data/pujas_data.dart';

void main() {
  group('Durga Puja 2026 AI Calendar and Panjika Tests', () {
    test('Official 2026 Calendar contains all 8 major festival milestones', () {
      expect(kDurgaPujaCalendar2026.length, equals(8));
      final ids = kDurgaPujaCalendar2026.map((d) => d.id).toList();
      expect(ids, containsAll([
        'mahalaya',
        'panchami',
        'shashthi',
        'saptami',
        'ashtami',
        'nabami',
        'dashami',
        'lakshmi_puja',
      ]));
    });

    test('Dates match authentic 2026 Kolkata Panjika schedule', () {
      final mahalaya = getPujaDayById('mahalaya');
      final shashthi = getPujaDayById('shashthi');
      final ashtami = getPujaDayById('ashtami');
      final dashami = getPujaDayById('dashami');
      final lakshmi = getPujaDayById('lakshmi_puja');

      expect(mahalaya.dateFormatted, contains('10 October 2026'));
      expect(shashthi.dateFormatted, contains('17 October 2026'));
      expect(ashtami.dateFormatted, contains('19 October 2026'));
      expect(dashami.dateFormatted, contains('21 October 2026'));
      expect(lakshmi.dateFormatted, contains('25 October 2026'));
      expect(getPujaDayById('panchami').dateFormatted, contains('15 October 2026'));
    });

    test('Tithi windows match Drik Panchang / Vishuddha and Beni Madhab (Kolkata 2026)', () {
      final ashtami = getPujaDayById('ashtami');
      expect(ashtami.getTithiTimings(), contains('19 Oct 10:52 AM'));
      expect(ashtami.getTithiTimings(isTraditionalPara: true), contains('19 Oct 07:50 AM'));
      expect(getPujaDayById('dashami').getTithiTimings(), contains('21 Oct 02:12 PM'));
      expect(getPujaDayById('lakshmi_puja').auspiciousMoments, contains('10:56 PM - 11:46 PM'));
      for (final d in pujaCalendar2026) {
        expect(d.tithiEnd.isAfter(d.tithiStart), isTrue);
      }
    });

    test('Maha Ashtami has verified Sandhi Puja timing window (Belur Math & Traditional Para)', () {
      final ashtami = getPujaDayById('ashtami');
      expect(ashtami.auspiciousMoments.toUpperCase(), contains('SANDHI PUJA'));
      expect(ashtami.getAuspiciousMoments(isTraditionalPara: false), contains('10:28 AM'));
      expect(ashtami.getAuspiciousMoments(isTraditionalPara: true), contains('07:26 AM'));
      expect(ashtami.crowdLevel, equals(1.0)); // Peak footfall
    });

    test('Every day has complete Bengali titles, rituals, and AI tips', () {
      for (final day in kDurgaPujaCalendar2026) {
        expect(day.titleBengali.isNotEmpty, isTrue);
        expect(day.titleEnglish.isNotEmpty, isTrue);
        expect(day.tithiName.isNotEmpty, isTrue);
        expect(day.tithiTimings.isNotEmpty, isTrue);
        expect(day.auspiciousMoments.isNotEmpty, isTrue);
        expect(day.ritualSignificance.isNotEmpty, isTrue);
        expect(day.attireAndBhog.isNotEmpty, isTrue);
        expect(day.crowdForecast.isNotEmpty, isTrue);
        expect(day.bestVisitingHours.isNotEmpty, isTrue);
        expect(day.recommendedPandalIds.isNotEmpty, isTrue);
        expect(day.aiProTips.isNotEmpty, isTrue);
      }
    });

    test('Recommended pandal IDs match real pandals in master 504 registry', () {
      final allPandalIds = kAllKolkataPujas.map((p) => p.id).toSet();
      for (final day in kDurgaPujaCalendar2026) {
        for (final recId in day.recommendedPandalIds) {
          expect(allPandalIds.contains(recId), isTrue);
        }
      }
    });

    test('getDaysRemaining accurately computes days until each specific tithi', () {
      final fakeNow = DateTime(2026, 10, 1);
      final mahalaya = getPujaDayById('mahalaya');
      final shashthi = getPujaDayById('shashthi');
      final ashtami = getPujaDayById('ashtami');

      expect(mahalaya.getDaysRemaining(fakeNow), equals(9)); // Oct 10 - Oct 1 = 9 days
      expect(shashthi.getDaysRemaining(fakeNow), equals(16)); // Oct 17 - Oct 1 = 16 days
      expect(ashtami.getDaysRemaining(fakeNow), equals(18)); // Oct 19 - Oct 1 = 18 days
    });
  });
}
