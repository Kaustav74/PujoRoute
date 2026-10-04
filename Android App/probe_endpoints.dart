// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String base = 'https://my-freellmapi-server.onrender.com';
  const String key = '***REMOVED***';
  final List<String> candidatePaths = ['/v1/chat/completions', '/chat/completions', '/api/chat', '/v1', '/'];

  for (final path in candidatePaths) {
    final target = '$base$path';
    try {
      final response = await http.post(
        Uri.parse(target),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key'},
        body: jsonEncode({'model': 'qwen/qwen3.8-27b', 'messages': [{'role': 'user', 'content': 'hi'}], 'max_tokens': 5}),
      ).timeout(const Duration(seconds: 15));
      print('[$target] -> HTTP Status: ${response.statusCode}');
      print('Body preview: ${response.body.substring(0, response.body.length > 50 ? 50 : response.body.length)}');
    } catch (e) {
      print('[$target] -> Network error');
    }
  }
}
