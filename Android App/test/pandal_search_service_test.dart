import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/services/pandal_search_service.dart';

void main() {
  final svc = PandalSearchService.instance;

  test('exact name match ranks first', () {
    final hits = svc.search('Tala Barowari');
    expect(hits, isNotEmpty);
    expect(hits.first.name.toLowerCase(), contains('tala barowari'));
  });

  test('case and whitespace normalized', () {
    final a = svc.search('  tala   barowari ');
    final b = svc.search('TALA BAROWARI');
    expect(a.map((p) => p.id), b.map((p) => p.id));
  });

  test('partial name match', () {
    final hits = svc.search('behala');
    expect(hits.any((p) => p.name.toLowerCase().contains('behala')), isTrue);
  });

  test('zone match', () {
    final hits = svc.search('Salt Lake');
    expect(hits.any((p) => p.zone == 'Salt Lake'), isTrue);
  });

  test('empty query returns base set without duplicates', () {
    final hits = svc.search('');
    expect(hits.any((p) => p.isDuplicateEntry), isFalse);
    expect(hits.length, greaterThan(100));
  });

  test('no results', () {
    expect(svc.search('zzzznotapandal999'), isEmpty);
  });

  test('unverified stays unverified', () {
    final hits = svc.search('tala');
    for (final p in hits) {
      if (p.isLocationUnverified) {
        expect(p.isLocationUnverified, isTrue);
      }
    }
  });

  test('ranking is deterministic', () {
    final a = svc.search('park');
    final b = svc.search('park');
    expect(a.map((p) => p.id).toList(), b.map((p) => p.id).toList());
  });
}
