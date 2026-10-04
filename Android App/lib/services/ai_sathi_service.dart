import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// On web, route through the local CORS proxy (python cors_proxy.py on port 8081)
/// to avoid browser CORS blocks. On mobile/desktop, call Render directly.
String get _aiBaseUrl => kIsWeb
    ? 'http://localhost:8081'
    : 'https://my-freellmapi-server.onrender.com';

// Provide at build time: --dart-define=FREELLMAPI_API_KEY=... (never commit keys).
const String _aiApiKey = String.fromEnvironment('FREELLMAPI_API_KEY');

Future<String> callAiSathi(String userPrompt) async {
  final String url = '$_aiBaseUrl/v1/chat/completions';
  // Use dedicated chat models that don't emit internal chain-of-thought scratchpads
  final candidateModels = ['command-a', 'ministral-14b', 'auto'];

  for (final model in candidateModels) {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_aiApiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': '''You are AI Sathi for PujoRoute (Kolkata Durga Puja 2026).
STRICT RESPONSE RULES:
- Output ONLY the final user-facing response. NEVER output "Here's a thinking process", outline notes, scratchpad drafts, or reasoning steps.
- Belur Math: Kumari Puja is strictly on Maha Ashtami morning (~9:00 AM). Belur Math is in Howrah (NOT on the Underwater Metro line; reached via ferry, local train, or GT Road).
- Transit Ground Truth: Underwater Green Line runs Howrah Maidan -> Howrah -> Mahakaran -> Esplanade. Interchange to Blue Line is strictly at Esplanade.
- Sreebhumi Sporting Club: Located on VIP Road / Lake Town (North Kolkata, NOT Ballygunge). Private cars are strictly barred during Puja; entry is via VIP Road pedestrian corridors.
Answer directly, concisely, and respectfully in the user's language.'''
            },
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': 1000,
          'temperature': 0.1,
          'chat_template_kwargs': {'thinking': false},
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String reply =
            data['choices'][0]['message']['content'].toString().trim();

        // 1. Strip XML-style thinking tags (<think>...</think>)
        if (reply.contains('</think>')) {
          reply = reply.split('</think>').last.trim();
        }

        // 2. Strip plaintext scratchpads ("Here's a thinking process:", "1. Analyze User Input...", etc.)
        final thinkPattern = RegExp(
          r"^(?:Here'?s a thinking process|Thinking Process|Thought process):?[\s\S]*?(?=(?:###\s*Answer|\*\*Answer:\*\*|Final Answer:|1\.\s+[A-Z]|Nomoshkar|Hello|Subho|\n\n[A-Z]))",
          caseSensitive: false,
        );

        if (thinkPattern.hasMatch(reply)) {
          reply = reply.replaceFirst(thinkPattern, '').trim();
        }

        // If response is valid, return it
        if (reply.isNotEmpty) {
          return reply;
        }
      }
    } catch (_) {
      // Try next candidate model
      continue;
    }
  }

  return 'AI temporarily unavailable. Please check back in a moment.';
}

class AiSathiService {
  static String get endpoint => '$_aiBaseUrl/v1/chat/completions';
  static const String apiKey = _aiApiKey;

  static Future<String> sendMessage({
    required List<Map<String, dynamic>> messages,
    String model = 'auto',
    double temperature = 0.1,
    int maxTokens = 600,
    int timeoutSeconds = 45,
  }) async {
    final userMsg = messages.lastWhere(
      (m) => m['role'] == 'user',
      orElse: () => {'content': ''},
    )['content'] as String;
    return callAiSathi(userMsg);
  }
}

