import '../data/pujas_data.dart';
import 'pandal_deduplication_service.dart';
import 'pandal_repository.dart';

/// Ranked local search over the bundled pandal dataset.
/// External geocoding is a separate concern and never invents local records.
class PandalSearchService {
  PandalSearchService._();
  static final PandalSearchService instance = PandalSearchService._();

  static final Map<String, String> _aliases = {
    'prattoy': 'pratty',
    'pratty': 'prattoy',
    'natun': 'nutan',
    'nutan': 'natun',
    'sarbojanin': 'sarbojonin',
    'sarbojonin': 'sarbojanin',
    'ahiritola': 'ahritola',
    'shobhabazar': 'sovabazar',
    'sovabazar': 'shobhabazar',
    'behala': 'behala',
    'kalyani': 'kalyani',
  };

  /// Score and return local matches. Empty query returns the filtered base set.
  List<Pandal> search(
    String query, {
    List<Pandal>? pool,
    String? zone,
    String? category,
    bool excludeDuplicates = true,
    int? limit,
  }) {
    final base = (pool ?? PandalRepository().allPandals).where((p) {
      if (excludeDuplicates && p.isDuplicateEntry) return false;
      if (zone != null && zone.isNotEmpty && zone != 'All' && p.zone != zone) {
        return false;
      }
      if (category != null &&
          category.isNotEmpty &&
          category != 'All' &&
          p.category != category) {
        return false;
      }
      return true;
    }).toList();

    final q = _normalize(query);
    if (q.isEmpty) {
      return limit == null ? base : base.take(limit).toList();
    }

    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final scored = <_Scored>[];
    for (final p in base) {
      final score = _score(p, q, words);
      if (score > 0) scored.add(_Scored(p, score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.pandal.name.compareTo(b.pandal.name);
    });
    final result = scored.map((s) => s.pandal).toList();
    return limit == null ? result : result.take(limit).toList();
  }

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static int _score(Pandal p, String q, List<String> words) {
    final name = _normalize(p.name);
    final id = _normalize(p.id);
    final fields = [
      name,
      id,
      _normalize(p.zone),
      _normalize(p.subsection),
      _normalize(p.category),
      _normalize(p.landmark),
      _normalize(p.metroStation),
      _normalize(p.history),
    ];

    if (name == q || id == q) return 1000;
    if (name.startsWith(q)) return 800;
    if (name.contains(q)) return 600;

    var wordHits = 0;
    for (final w in words) {
      final variants = {w, _aliases[w] ?? w};
      final hit = fields.any((f) => variants.any((v) => f.contains(v)));
      if (hit) wordHits++;
    }
    if (wordHits == words.length && words.isNotEmpty) return 400 + wordHits;
    if (wordHits > 0) return 100 + wordHits;
    return 0;
  }
}

class _Scored {
  final Pandal pandal;
  final int score;
  _Scored(this.pandal, this.score);
}
