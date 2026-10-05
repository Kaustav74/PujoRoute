import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';

void main() {
  test(
      'kDistinctPandalCount is derived from data (504 records - 15 duplicates)',
      () {
    expect(kDistinctPandalCount,
        kAllKolkataPujas.where((p) => !p.isDuplicateEntry).length);
    expect(kDistinctPandalCount, 489);
  });

  test('No pandal description contains stray markdown', () {
    for (final p in kAllKolkataPujas) {
      expect(p.history.contains('*'), isFalse, reason: p.id);
      expect(p.history.contains('__'), isFalse, reason: p.id);
    }
  });

  test('No description claims police/authority partnership or endorsement', () {
    final re =
        RegExp(r'police|tie-up|endorse|mayor award', caseSensitive: false);
    for (final p in kAllKolkataPujas) {
      expect(re.hasMatch(p.history), isFalse, reason: p.id);
    }
  });

  test('Category chip counts (distinct) add up to kDistinctPandalCount', () {
    final distinct = kAllKolkataPujas.where((p) => !p.isDuplicateEntry);
    final mega = distinct.where((p) => p.category == 'mega').length;
    final heritage = distinct.where((p) => p.category == 'heritage').length;
    expect(mega + heritage, kDistinctPandalCount);
  });
}
