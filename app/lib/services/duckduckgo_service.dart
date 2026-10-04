import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DuckDuckGoSearchResult {
  final String title;
  final String snippet;
  final String url;

  const DuckDuckGoSearchResult({
    required this.title,
    required this.snippet,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'snippet': snippet,
        'url': url,
      };
}

class DuckDuckGoSearchService {
  static final DuckDuckGoSearchService _instance = DuckDuckGoSearchService._internal();
  factory DuckDuckGoSearchService() => _instance;
  static DuckDuckGoSearchService get instance => _instance;

  DuckDuckGoSearchService._internal();

  /// Executes a keyless, unblocked DuckDuckGo web search
  /// Returns a list of structured search snippets.
  Future<List<DuckDuckGoSearchResult>> search(
    String query, {
    int maxResults = 4,
    int timeoutSeconds = 6,
  }) async {
    final refinedQuery = query.toLowerCase().contains('kolkata')
        ? query
        : '$query Kolkata Durga Puja 2026';

    try {
      final searchUrl = Uri.parse(
        'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(refinedQuery)}',
      );

      final response = await http
          .get(
            searchUrl,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-IN,en;q=0.9,bn;q=0.8',
            },
          )
          .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final html = response.body;
        final results = _parseHtmlSnippets(html, maxResults);
        if (results.isNotEmpty) return results;
      }
    } catch (e) {
      debugPrint('DuckDuckGo HTML search error: $e');
    }

    // Fallback: Query Google News RSS for Kolkata Durga Puja updates
    return _fetchRssFallback(refinedQuery, maxResults);
  }

  List<DuckDuckGoSearchResult> _parseHtmlSnippets(String html, int maxResults) {
    final results = <DuckDuckGoSearchResult>[];

    final snippetRegex = RegExp(
      r'<a[^>]+class="result__snippet"[^>]*>(.*?)<\/a>',
      dotAll: true,
      caseSensitive: false,
    );

    final titleRegex = RegExp(
      r'<a[^>]+class="result__url"[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>',
      dotAll: true,
      caseSensitive: false,
    );

    final snippetMatches = snippetRegex.allMatches(html).toList();
    final titleMatches = titleRegex.allMatches(html).toList();

    for (int i = 0; i < snippetMatches.length && i < maxResults; i++) {
      final rawSnippet = snippetMatches[i].group(1) ?? '';
      final cleanSnippet = _cleanHtml(rawSnippet);

      String url = '';
      String title = '';
      if (i < titleMatches.length) {
        url = titleMatches[i].group(1)?.trim() ?? '';
        title = _cleanHtml(titleMatches[i].group(2) ?? '');
      }

      if (cleanSnippet.isNotEmpty) {
        results.add(
          DuckDuckGoSearchResult(
            title: title.isNotEmpty ? title : 'Kolkata Puja Report',
            snippet: cleanSnippet,
            url: url,
          ),
        );
      }
    }

    return results;
  }

  Future<List<DuckDuckGoSearchResult>> _fetchRssFallback(String query, int maxResults) async {
    try {
      final url = Uri.parse(
        'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=en-IN&gl=IN&ceid=IN:en',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final items = RegExp(r'<item>[\s\S]*?<title>(.*?)<\/title>[\s\S]*?<link>(.*?)<\/link>[\s\S]*?<\/item>').allMatches(response.body);
        final results = <DuckDuckGoSearchResult>[];
        for (final m in items.take(maxResults)) {
          final title = _cleanHtml(m.group(1) ?? '');
          final link = m.group(2) ?? '';
          if (title.isNotEmpty) {
            results.add(DuckDuckGoSearchResult(title: title, snippet: title, url: link));
          }
        }
        return results;
      }
    } catch (_) {}
    return [];
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
