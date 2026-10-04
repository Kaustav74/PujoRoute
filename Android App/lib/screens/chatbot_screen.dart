import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/pujas_data.dart';
import '../services/emergency_service.dart';
import '../services/live_feed_service.dart';
import '../services/session_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/spatial_facility_service.dart';
import '../services/deterministic_routing_service.dart';
import '../services/ai_sathi_service.dart';
import '../services/ai_token_gate_service.dart';
import '../widgets/deterministic_route_card.dart';
import '../widgets/voice_assistant_dialog.dart';
import 'puja_calendar_screen.dart';
import 'circuit_studio_screen.dart';
import 'map_screen.dart';

class ParsedAiAction {
  final String actionType;
  final Map<String, String> params;

  ParsedAiAction({required this.actionType, required this.params});
}

ParsedAiAction? parseAiActionTag(String rawText) {
  final regExp = RegExp(r'\[ACTION:([A-Z_]+)(?:\|([^\]]+))?\]');
  final match = regExp.firstMatch(rawText);
  if (match == null) return null;

  final actionType = match.group(1);
  if (actionType == null) return null;

  final paramString = match.group(2) ?? '';
  final Map<String, String> params = {};
  if (paramString.isNotEmpty) {
    for (final pair in paramString.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        params[parts[0].trim()] = parts[1].trim();
      }
    }
  }

  if (actionType == 'OPEN_CIRCUIT_STUDIO' ||
      actionType == 'OPEN_TITHI' ||
      actionType == 'OPEN_MAP') {
    return ParsedAiAction(actionType: actionType, params: params);
  }
  return null;
}

String cleanTextForDisplay(String rawText) {
  final regExp = RegExp(r'\[ACTION:([A-Z_]+)(?:\|([^\]]+))?\]');
  return rawText.replaceAll(regExp, '').trim();
}

class ChatBotScreen extends StatefulWidget {
  final double lat;
  final double lon;
  final String? initialQuery;

  const ChatBotScreen({
    super.key,
    required this.lat,
    required this.lon,
    this.initialQuery,
  });

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  final bool _isPreflightChecking = false;
  final bool _isAiReady = true;
  final VoiceAssistantService _voiceService = VoiceAssistantService.instance;
  final EmergencyService _emergencyService = EmergencyService.instance;
  final LiveFeedService _liveFeedService = LiveFeedService.instance;

  @override
  void initState() {
    super.initState();
    _restoreChatHistory();
    _liveFeedService.fetchLiveKolkataWeather().then((_) {
      if (mounted) setState(() {});
    });

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _voiceService.stopSpeaking();
    _voiceService.stopListening();
    super.dispose();
  }


  /// Evaluates the device's clock to return time-gated prompt suggestions
  List<String> _getTimeGatedSuggestions() {
    final hour = DateTime.now().hour;

    // 06:00 AM - 11:00 AM: Pushpanjali, Kola Bou dawn snan, serene heritage walks
    if (hour >= 6 && hour < 11) {
      return [
        '🌸 Morning Pushpanjali Schedule 2026',
        '🌿 Nabapatrika Kola Bou Snan Ghats',
        '🏛️ Quiet Sovabazar Heritage Walk',
        '🪔 Sandhi Puja 2026 Exact Window',
        '🎒 5 South Kolkata Morning Pandals',
      ];
    }
    // 12:00 PM - 04:00 PM: Afternoon Bhog timings, indoor exhibitions, dining
    else if (hour >= 11 && hour < 17) {
      return [
        '🍱 Authentic Bhog Timings Today',
        '🏛️ Indoor Theme Pandals Near Me',
        '🍛 Best Bengali Food Adda Spots',
        '🟢 Fast-moving queues right now',
        '🎒 8-Stop Afternoon Route',
      ];
    }
    // 05:00 PM - 11:00 PM: Lighting installations, crowd alerts, metro advisories
    else if (hour >= 17 && hour < 23) {
      return [
        '✨ Top Illumination & Lighting Circuits',
        '🚨 Sreebhumi & Suruchi Crowd Alert',
        '🚇 Metro Gate Congestion Advisories',
        '🪔 Dhunuchi Naach Hotspots Tonight',
        '🎒 10 Mega Evening Pandals',
      ];
    }
    // 11:00 PM - 05:00 AM: Night-owl circuits, tea points, 24-hr metro
    else {
      return [
        '🌙 All-Night Hopping Circuit (12 Stops)',
        '☕ Operational Tea & Snack Points',
        '🚇 24-Hour Metro Train Advisory',
        '⚡ Maddox Square Midnight Adda',
        '🟢 No-queue midnight gems',
      ];
    }
  }

  Future<void> _toggleVoiceDictation() async {
    if (_isListening) {
      await _voiceService.stopListening();
      if (mounted) setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _voiceService.startListening(
        userLat: widget.lat,
        userLon: widget.lon,
        onResult: (words) {
          if (mounted) {
            setState(() {
              _controller.text = words;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          }
        },
        onIntentResolved: (intent) {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );
    }
  }

  void _restoreChatHistory() {
    final saved = SessionService.instance.chatMessages;
    if (saved.isNotEmpty) {
      final idMap = {for (var p in kAllKolkataPujas) p.id: p};
      for (var m in saved) {
        final restored = Map<String, dynamic>.from(m);
        if (restored.containsKey('route_ids') &&
            restored['route_ids'] is List) {
          final ids = restored['route_ids'] as List;
          restored['route'] =
              ids.map((id) => idMap[id]).whereType<Pandal>().toList();
        } else if (!restored.containsKey('route')) {
          restored['route'] = <Pandal>[];
        }
        _messages.add(restored);
      }
    } else {
      _loadWelcomeMessage();
    }
  }

  void _loadWelcomeMessage() {
    _messages.add({
      "role": "bot",
      "text": "Nomoshkar! 🙏 I am your **AI Sathi & Puja Guide**, grounded in real-time festival intelligence for Kolkata Durga Puja 2026.\n\n"
          "All ritual timings strictly follow the **Vishuddha Siddhanta / Belur Math tradition**.\n\n"
          "How can I assist your pandal hopping or ritual itinerary right now?",
      "suggestions": _getTimeGatedSuggestions(),
      "route": <Pandal>[],
    });
  }

  // Fast Haversine Distance in meters
  double _getDistanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;
    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (r * c * 1.25);
  }

  List<Pandal> _searchDatabaseForContext(String query, {int limit = 12}) {
    final q = query.toLowerCase().trim();

    List<Pandal> sortedByDist = List.from(kAllKolkataPujas);
    sortedByDist.sort((a, b) {
      final distA = _getDistanceMeters(widget.lat, widget.lon, a.lat, a.lon);
      final distB = _getDistanceMeters(widget.lat, widget.lon, b.lat, b.lon);
      return distA.compareTo(distB);
    });

    final stopWords = {
      'the',
      'and',
      'for',
      'about',
      'show',
      'tell',
      'what',
      'where',
      'how',
      'many',
      'entries',
      'database',
      'pandal',
      'pandals',
      'puja',
      'pujo',
      'kolkata',
      'is',
      'in',
      'at',
      'to',
      'me',
      'give',
      'find'
    };
    final tokens = q
        .split(RegExp(r'[\s,.-]+'))
        .where((t) => t.length >= 3 && !stopWords.contains(t))
        .toList();

    // Prioritize direct name, landmark, and metro station token matches
    if (tokens.isNotEmpty) {
      List<MapEntry<Pandal, int>> scored = [];
      for (var p in kAllKolkataPujas) {
        int score = 0;
        final name = p.name.toLowerCase();
        final landmark = p.landmark.toLowerCase();
        final metro = p.metroStation.toLowerCase();
        final history = p.history.toLowerCase();

        if (name.contains(q)) score += 150;
        for (var t in tokens) {
          if (name.contains(t)) score += 50;
          if (landmark.contains(t)) score += 30;
          if (metro.contains(t)) score += 30;
          if (history.contains(t)) score += 8;
        }

        if (score > 0) scored.add(MapEntry(p, score));
      }

      if (scored.isNotEmpty) {
        scored.sort((a, b) => b.value.compareTo(a.value));
        if (scored.first.value >= 30) {
          return scored.map((e) => e.key).take(limit).toList();
        }
      }
    }

    final bool wantsHeritage = q.contains('bonedi') ||
        q.contains('heritage') ||
        q.contains('rajbari') ||
        q.contains('bari') ||
        q.contains('zamindar') ||
        q.contains('traditional') ||
        q.contains('mansion');
    final bool wantsNorth = q.contains('north') ||
        q.contains('shyambazar') ||
        q.contains('baghbazar') ||
        q.contains('hatibagan') ||
        q.contains('dum dum') ||
        q.contains('ultadanga') ||
        q.contains('kumartuli');
    final bool wantsSouth = q.contains('south') ||
        q.contains('kasba') ||
        q.contains('gariahat') ||
        q.contains('jodhpur') ||
        q.contains('behala') ||
        q.contains('chetla') ||
        q.contains('ballygunge') ||
        q.contains('jadavpur');
    final bool wantsSaltLake = q.contains('salt lake') ||
        q.contains('newtown') ||
        q.contains('bidhannagar') ||
        q.contains('karunamoyee');
    final bool wantsCentral = q.contains('central') ||
        q.contains('college square') ||
        q.contains('sealdah') ||
        q.contains('bowbazar');

    if (wantsHeritage) {
      var heritagePool =
          kAllKolkataPujas.where((p) => p.category == 'heritage').toList();
      if (wantsNorth) {
        final f = heritagePool.where((p) => p.zone == 'North').toList();
        if (f.isNotEmpty) return f.take(limit).toList();
      } else if (wantsCentral) {
        final f = heritagePool.where((p) => p.zone == 'Central').toList();
        if (f.isNotEmpty) return f.take(limit).toList();
      } else if (wantsSouth) {
        final f = heritagePool.where((p) => p.zone == 'South').toList();
        if (f.isNotEmpty) return f.take(limit).toList();
      }
      return heritagePool.take(limit).toList();
    }

    if (wantsNorth) {
      return kAllKolkataPujas
          .where((p) => p.zone == 'North')
          .take(limit)
          .toList();
    }
    if (wantsSaltLake) {
      return kAllKolkataPujas
          .where((p) => p.zone == 'Salt Lake')
          .take(limit)
          .toList();
    }
    if (wantsCentral) {
      return kAllKolkataPujas
          .where((p) => p.zone == 'Central')
          .take(limit)
          .toList();
    }
    if (wantsSouth) {
      return kAllKolkataPujas
          .where((p) => p.zone == 'South')
          .take(limit)
          .toList();
    }

    if (q.contains('fast') ||
        q.contains('less crowd') ||
        q.contains('no queue')) {
      return sortedByDist
          .where((p) => p.crowdStatus == 'fast')
          .take(limit)
          .toList();
    }

    return sortedByDist.take(limit).toList();
  }

  /// Sanitizes text to ensure pure human-like plain text:
  /// removes markdown bold (** / __), italic (* / _), headers (#),
  /// and strips table pipes (|) or formatting.
  static String _sanitizePlainText(String raw) {
    if (raw.isEmpty) return raw;
    var text = raw;

    // 0. Strip XML-style thinking tags (<think>...</think>)
    if (text.contains('</think>')) {
      text = text.split('</think>').last.trim();
    }

    // 0b. Strip plaintext scratchpads
    final thinkPattern = RegExp(
      r"^(?:Here'?s a thinking process|Thinking Process|Thought process):?[\s\S]*?(?=(?:###\s*Answer|\*\*Answer:\*\*|Final Answer:|1\.\s+[A-Z]|Nomoshkar|Hello|Subho|\n\n[A-Z]))",
      caseSensitive: false,
    );
    if (thinkPattern.hasMatch(text)) {
      text = text.replaceFirst(thinkPattern, '').trim();
    }

    // 1. Remove markdown bold and italic markers (clean extraction of capture group)
    text = text.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(
        RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(
        RegExp(r'(?<!_)_([^_]+)_(?!_)'), (m) => m[1] ?? '');

    // 2. Remove markdown header markers (e.g. "### ", "## ", "# ")
    text = text.replaceAll(RegExp(r'^[ \t]*#{1,6}\s*', multiLine: true), '');

    // 3. Remove markdown table divider rows (e.g. |---|---| or |:---|:---|)
    text = text.replaceAll(
        RegExp(r'^[ \t]*\|?[\s\-:|]+\|[ \t]*$', multiLine: true), '');

    // 4. Convert markdown table rows into clean bullet/sentence lines
    final lines = text.split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isNotEmpty) {
          cleanedLines.add('• ${cells.join(' — ')}');
        }
      } else {
        cleanedLines.add(line);
      }
    }
    text = cleanedLines.join('\n');

    // 5. Clean extra empty lines
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return text.trim();
  }


  /// Client AI Sanity Guard to verify AI prose against strict route data & Kolkata Metro graph facts
  bool verifyAiSanity(String responseText, StrictRouteJson strictRoute) {
    final lowerText = responseText.toLowerCase();

    // 1. Red Flag Regex 1: Bagbazar Metro Station (Does NOT exist)
    if (RegExp(r'bagbazar\s+(?:metro|station)').hasMatch(lowerText)) {
      debugPrint("AI Sanity Violation: Claimed Bagbazar Metro Station exists");
      return false;
    }

    // 2. Red Flag Regex 2: Sealdah Blue Line Transfer (Transfer is ONLY at Esplanade)
    if (RegExp(r'(?:transfer|change).*sealdah|sealdah.*(?:transfer|interchange)').hasMatch(lowerText)) {
      debugPrint("AI Sanity Violation: Claimed transfer at Sealdah");
      return false;
    }

    // 3. Red Flag Regex 3: Excessive Walking Distance (> 900m)
    final walkKmMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:km|k\.m\.|kilometers?)\s*walk').firstMatch(lowerText);
    if (walkKmMatch != null) {
      final km = double.tryParse(walkKmMatch.group(1) ?? '0') ?? 0.0;
      if (km > 0.9) {
        debugPrint("AI Sanity Violation: Walking distance $km km exceeds 900m limit");
        return false;
      }
    }
    final walkMMatch = RegExp(r'(\d+)\s*m\s*walk').firstMatch(lowerText);
    if (walkMMatch != null) {
      final meters = int.tryParse(walkMMatch.group(1) ?? '0') ?? 0;
      if (meters > 900) {
        debugPrint("AI Sanity Violation: Walking distance $meters m exceeds 900m limit");
        return false;
      }
    }

    // 4. Red Flag Regex 4: Category Misclassification
    if (RegExp(r'bagbazar sarbojanin.*bonedi bari|bonedi bari.*bagbazar sarbojanin').hasMatch(lowerText)) {
      debugPrint("AI Sanity Violation: Bagbazar Sarbojanin misclassified as Bonedi Bari");
      return false;
    }

    // 5. Check all strict route stops are preserved
    for (final stop in strictRoute.stops) {
      final stopTokens = stop.name.toLowerCase().split(' ');
      bool matched = false;
      for (final token in stopTokens) {
        if (token.length >= 4 && lowerText.contains(token)) {
          matched = true;
          break;
        }
      }
      if (!matched) {
        debugPrint("AI Sanity Violation: Missing stop ${stop.name} in response");
        return false;
      }
    }

    return true;
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add({
        "role": "user",
        "text": query,
        "route": <Pandal>[],
      });
      _isLoading = true;
    });

    SessionService.instance.saveChatMessages(_messages);
    _controller.clear();
    _scrollToBottom();

    // Emergency intent bypass for user safety
    if (_emergencyService.isEmergencyQuery(query)) {
      final emergencyReply = _sanitizePlainText(_emergencyService
          .generateEmergencyGuidance(query, widget.lat, widget.lon));
      setState(() {
        _messages.add({
          "role": "bot",
          "text": emergencyReply,
          "isEmergency": true,
          "route": <Pandal>[],
        });
        _isLoading = false;
      });
      SessionService.instance.saveChatMessages(_messages);
      if (SessionService.instance.isAutoSpeakEnabled) {
        _voiceService.speak(emergencyReply);
      }
      _scrollToBottom();
      return;
    }

    // =========================================================================
    // 5-MINUTE AI COOLER: MAXIMUM 2 AI REQUESTS PER 5-MINUTE ROLLING WINDOW
    // =========================================================================
    final gate = AiTokenGateService();
    if (!gate.canMakeQuery()) {
      final waitTime = gate.timeUntilNextToken;
      final minutes = waitTime.inMinutes;
      final seconds = waitTime.inSeconds % 60;
      final waitStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

      setState(() {
        _messages.add({
          "role": "bot",
          "text": "⏳ **AI Cooler Active**: You have used your 2 AI queries for this window.\n\n"
              "Please wait **$waitStr** before sending your next request. This ensures balanced server capacity for all pandal-hoppers.",
          "route": <Pandal>[],
        });
        _isLoading = false;
      });
      SessionService.instance.saveChatMessages(_messages);
      _scrollToBottom();
      return;
    }

    gate.tryConsumeToken();

    try {
      const systemPrompt = """
You are AI Sathi, the official festival companion for Kolkata Durga Puja 2026 (PujoRoute).

METRO & TRANSIT GROUND TRUTH:
- Green Line sequence: Howrah Maidan -> Howrah -> Mahakaran -> Esplanade.
- Blue Line: Dakshineswar <-> Kavi Subhash via Dum Dum, Shyambazar, Shobhabazar Sutanuti, Girish Park, Central, Chandni Chowk, Esplanade, Park Street, Kalighat.
- Interchange between Green Line and Blue Line is strictly at Esplanade Station.
- To travel between Howrah (Maidan) and Sovabazar Rajbari: Board Green Line to Esplanade, interchange to Blue Line Northbound (towards Dakshineswar), and de-board at Shobhabazar Sutanuti.

CIRCUIT & ACTION TAGS:
- When recommending routes or circuits, list pandals in walking sequence with brief transit tips.
- If recommending a multi-stop circuit, append an action tag at the end, e.g.:
  [ACTION:OPEN_CIRCUIT_STUDIO|zone=North&stops=6]
  or [ACTION:OPEN_MAP|lat=22.5975&lng=88.3685&name=Sovabazar Rajbari]

Answer directly, accurately, and concisely. Keep formatting clean with bullet points.
""";

      final messagesPayload = <Map<String, dynamic>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      // Conversational Memory: Include last 6 turns
      final historyTurns = _messages.length > 8
          ? _messages.sublist(_messages.length - 8)
          : _messages;
      for (final m in historyTurns) {
        final r = m['role'];
        final t = m['text'] as String?;
        if (t != null && t.isNotEmpty && (r == 'user' || r == 'bot')) {
          messagesPayload.add({
            'role': r == 'user' ? 'user' : 'assistant',
            'content': t,
          });
        }
      }

      // Ensure current user query is present
      if (messagesPayload.isEmpty || messagesPayload.last['content'] != query) {
        messagesPayload.add({
          'role': 'user',
          'content': query,
        });
      }

      final reply = await callAiSathi(query);

      final sanitized = _sanitizePlainText(reply);
      final parsedAction = parseAiActionTag(reply);
      final matchedPandals = _searchDatabaseForContext(query, limit: 6);

      if (mounted) {
        setState(() {
          _messages.add({
            "role": "bot",
            "text": sanitized,
            "isOffline": false,
            "engine": "⚡ AI Sathi Direct",
            "ui_action": parsedAction,
            "route": matchedPandals,
            "suggestions": _getTimeGatedSuggestions(),
          });
          _isLoading = false;
        });
        SessionService.instance.saveChatMessages(_messages);
        if (SessionService.instance.isAutoSpeakEnabled) {
          _voiceService.speak(sanitized);
        }
      }
    } catch (e) {
      debugPrint('Chatbot error: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            "role": "bot",
            "text": "AI connection issue: $e",
            "route": <Pandal>[],
          });
          _isLoading = false;
        });
      }
    } finally {
      gate.releaseInFlight();
    }

    _scrollToBottom();
  }

  void _showPandalDetailsModal(Pandal p) {
    final dist =
        _getDistanceMeters(widget.lat, widget.lon, p.lat, p.lon).round();
    final isMega = p.category == 'mega';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
              top: BorderSide(
                  color: isMega
                      ? const Color(0xFFE62E2D)
                      : const Color(0xFFFFB300),
                  width: 3)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMega
                        ? const Color(0xFFE62E2D).withOpacity(0.18)
                        : const Color(0xFFFFB300).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isMega
                            ? const Color(0xFFE62E2D)
                            : const Color(0xFFFFB300)),
                  ),
                  child: Icon(
                    isMega
                        ? Icons.local_fire_department
                        : Icons.account_balance,
                    color: isMega
                        ? const Color(0xFFE62E2D)
                        : const Color(0xFFFFB300),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        '${isMega ? '🔥 Mega Theme' : '🏛️ Bonedi Bari'} • ${p.subsection} • ${dist > 1000 ? "${(dist / 1000).toStringAsFixed(1)}km" : "${dist}m"} away',
                        style: TextStyle(
                          color: isMega
                              ? const Color(0xFFE62E2D)
                              : const Color(0xFFFFB300),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Metro Station & Gate
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF192534),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_subway,
                      color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('METRO CONNECTIVITY & EXIT GATE',
                            style: TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text(p.detailedMetroGate,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        if (p.barricadeAdvisory.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('🚧 ${p.barricadeAdvisory}',
                              style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Dynamic Spatial Facilities
            Builder(
              builder: (context) {
                final fac =
                    SpatialFacilityService.instance.getNearestFacilities(p);
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: fac.chips
                      .map((f) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E34),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(f,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10.5)),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 14),

            // Significance
            const Text('🏛️ CULTURAL SIGNIFICANCE & HERITAGE',
                style: TextStyle(
                    color: Color(0xFFFFB300),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text(p.history,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.45)),

            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE62E2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigate in Maps',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openGoogleMaps(p);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300).withOpacity(0.2),
                      padding: const EdgeInsets.all(12)),
                  icon: const Icon(Icons.playlist_add,
                      color: Color(0xFFFFB300), size: 22),
                  tooltip: 'Add to Circuit',
                  onPressed: () async {
                    final circuit = List<String>.from(
                        SessionService.instance.activeCircuitIds);
                    if (!circuit.contains(p.id)) {
                      circuit.add(p.id);
                    }
                    await SessionService.instance.saveCircuit(circuit, true);
                    if (!ctx.mounted || !mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1E1428),
                        content: Text(
                            'Added ${p.name} to circuit (${circuit.length} stops)'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openGoogleMaps(Pandal p) async {
    final bool hasUserLoc = widget.lat != 0.0 && widget.lon != 0.0;
    final destination = Uri.encodeComponent('${p.name}, Kolkata');
    final String urlString;
    if (hasUserLoc) {
      final origin = '${widget.lat.toStringAsFixed(5)},${widget.lon.toStringAsFixed(5)}';
      urlString = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking';
    } else {
      urlString = 'https://www.google.com/maps/search/?api=1&query=$destination';
    }
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  void _openGoogleMapsCircuit(List<Pandal> stops) async {
    if (stops.isEmpty) return;
    if (stops.length == 1) {
      return _openGoogleMaps(stops.first);
    }
    final bool hasUserLoc = widget.lat != 0.0 && widget.lon != 0.0;
    final origin = hasUserLoc
        ? '${widget.lat.toStringAsFixed(5)},${widget.lon.toStringAsFixed(5)}'
        : '${stops.first.lat.toStringAsFixed(5)},${stops.first.lon.toStringAsFixed(5)}';
    final destination =
        '${stops.last.lat.toStringAsFixed(5)},${stops.last.lon.toStringAsFixed(5)}';

    final intermediateStops = hasUserLoc
        ? stops.sublist(0, stops.length - 1)
        : (stops.length > 2 ? stops.sublist(1, stops.length - 1) : <Pandal>[]);
    final waypoints = intermediateStops
        .take(9)
        .map((p) => '${p.lat.toStringAsFixed(5)},${p.lon.toStringAsFixed(5)}')
        .join('|');

    String urlString =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking';
    if (waypoints.isNotEmpty) {
      urlString += '&waypoints=$waypoints';
    }

    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (_) {}
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE62E2D), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFE62E2D)),
            SizedBox(width: 8),
            Text('Reset Chat History?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will clear your conversation with the Puja AI Guide and restore the welcome overview.',
          style: TextStyle(color: Colors.white70, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE62E2D),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await SessionService.instance.clearChatHistory();
              setState(() {
                _messages.clear();
                _loadWelcomeMessage();
              });
            },
            child: const Text('Reset',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color kMidnightBlue = Color(0xFF0D0D1E);
    const Color kSindoorRed = Color(0xFFE62E2D);
    const Color kMarigoldAmber = Color(0xFFFFB300);

    return Scaffold(
      backgroundColor: kMidnightBlue,
      appBar: AppBar(
        backgroundColor: kMidnightBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kMarigoldAmber, width: 1.5),
                image: const DecorationImage(
                  image: AssetImage('assets/images/durga_logo.png'),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(color: kSindoorRed.withOpacity(0.5), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Sathi • Puja Guide',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white),
                ),
                Text(
                  'Belur Math Benchmark • 504 Pujas',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: kMarigoldAmber,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Voice Assistant Dialog
          IconButton(
            icon: const Icon(Icons.mic, color: kSindoorRed),
            tooltip: 'Voice Assistant',
            onPressed: () {
              VoiceAssistantDialog.show(
                context,
                userLat: widget.lat,
                userLon: widget.lon,
              );
            },
          ),
          // Auto-Speak Toggle
          IconButton(
            icon: Icon(
              SessionService.instance.isAutoSpeakEnabled
                  ? Icons.volume_up
                  : Icons.volume_off,
              color: SessionService.instance.isAutoSpeakEnabled
                  ? kMarigoldAmber
                  : Colors.white38,
            ),
            tooltip: 'Auto-Speak Toggle',
            onPressed: () {
              setState(() {
                final newVal = !SessionService.instance.isAutoSpeakEnabled;
                SessionService.instance.setAutoSpeakEnabled(newVal);
                if (!newVal) _voiceService.stopSpeaking();
              });
            },
          ),
          // 2026 Calendar
          IconButton(
            icon: const Icon(Icons.calendar_month, color: kMarigoldAmber),
            tooltip: '2026 Tithis & Muhurats',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PujaCalendarScreen(
                      userLat: widget.lat, userLon: widget.lon),
                ),
              );
            },
          ),
          // Clear History
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Reset Chat',
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // =========================================================================
          // LIVE REAL-TIME ADVISORY TICKER BANNER (Traffic closures + Weather alert)
          // =========================================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E121E), Color(0xFF141424)],
              ),
              border: Border(
                  bottom: BorderSide(
                      color: kSindoorRed.withOpacity(0.3), width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: Color(0xFFFF8A80), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _liveFeedService.getLiveBannerTicker(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFFFEBEE),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // =========================================================================
          // CHAT STREAM (Spacious with Generous Breathing Room)
          // =========================================================================
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: _messages.length,
              itemBuilder: (itemCtx, index) {
                final msg = _messages[index];
                final bool isUser = msg['role'] == 'user';
                final rawMsgText = (msg['text'] as String?) ?? '';
                final parsedAction = parseAiActionTag(rawMsgText);
                final displayText = cleanTextForDisplay(rawMsgText);
                final List<Pandal> route =
                    (msg['route'] as List?)?.whereType<Pandal>().toList() ??
                        <Pandal>[];
                final List<String> suggestions = msg['suggestions'] != null
                    ? List<String>.from(msg['suggestions'] as List)
                    : <String>[];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(itemCtx).size.width * 0.92,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: isUser
                            ? const LinearGradient(
                                colors: [Color(0xFFC84B31), Color(0xFFE62E2D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isUser ? null : const Color(0xFF1A1A2C),
                        borderRadius: BorderRadius.circular(20).copyWith(
                          bottomRight: isUser
                              ? const Radius.circular(3)
                              : const Radius.circular(20),
                          bottomLeft: !isUser
                              ? const Radius.circular(3)
                              : const Radius.circular(20),
                        ),
                        border: Border.all(
                          color: isUser
                              ? Colors.transparent
                              : kMarigoldAmber.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isUser
                                ? const Color(0xFFC84B31).withOpacity(0.25)
                                : Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Offline Brain & Network Busy Indicators
                          if (!isUser &&
                              msg['engine'] != null &&
                              msg['engine'].toString().isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF00).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF00FF00)
                                        .withOpacity(0.3),
                                    width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      msg['engine'].toString().contains('Groq')
                                          ? Icons.bolt
                                          : Icons.public,
                                      color: const Color(0xFF00FF00),
                                      size: 14),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      msg['engine'].toString(),
                                      style: const TextStyle(
                                        color: Color(0xFF00FF00),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Main text response
                          Text(
                            _sanitizePlainText(displayText),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              height: 1.55,
                            ),
                          ),

                          // Deterministic Route Card (Zero Hallucination UI)
                          if (!isUser &&
                              msg['strictRoute'] != null &&
                              msg['strictRoute'] is StrictRouteJson) ...[
                            const SizedBox(height: 10),
                            DeterministicRouteCard(
                              route: msg['strictRoute'] as StrictRouteJson,
                              onOpenCircuitStudio: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CircuitStudioScreen(
                                      userLat: widget.lat,
                                      userLon: widget.lon,
                                    ),
                                  ),
                                );
                              },
                              onOpenMap: () {
                                final routeStops =
                                    (msg['strictRoute'] as StrictRouteJson)
                                        .stops
                                        .map((s) => Pandal(
                                              id: s.id.toString(),
                                              name: s.name,
                                              category: s.category
                                                      .toLowerCase()
                                                      .contains('bonedi')
                                                  ? 'heritage'
                                                  : 'mega',
                                              subsection: s.zone,
                                              lat: s.lat,
                                              lon: s.lng,
                                              landmark:
                                                  '${s.walkingDistMeters}m walk',
                                              metroStation: s.nearestMetro,
                                              history: '',
                                              zone: s.zone,
                                              crowdStatus: 'fast',
                                              facilities: const [
                                                'washroom',
                                                'water'
                                              ],
                                            ))
                                        .toList();
                                _openGoogleMapsCircuit(routeStops);
                              },
                            ),
                          ],

                          // Deep-Link Action Button UI
                          if (!isUser && parsedAction != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB300),
                                  foregroundColor: const Color(0xFF140D1E),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 11),
                                ),
                                icon: Icon(
                                  parsedAction.actionType ==
                                          'OPEN_CIRCUIT_STUDIO'
                                      ? Icons.alt_route
                                      : parsedAction.actionType == 'OPEN_TITHI'
                                          ? Icons.calendar_month
                                          : Icons.location_on,
                                  size: 18,
                                  color: const Color(0xFF140D1E),
                                ),
                                label: Text(
                                  parsedAction.actionType ==
                                          'OPEN_CIRCUIT_STUDIO'
                                      ? 'Open Route Planner (${parsedAction.params['zone'] ?? 'South'} • ${parsedAction.params['stops'] ?? '8'} stops)'
                                      : parsedAction.actionType == 'OPEN_TITHI'
                                          ? 'Open ${parsedAction.params['day']?.toUpperCase() ?? 'ASHTAMI'} Timings'
                                          : 'View ${parsedAction.params['name'] ?? 'Pandal'} on Map',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                onPressed: () {
                                  if (parsedAction.actionType ==
                                      'OPEN_CIRCUIT_STUDIO') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CircuitStudioScreen(
                                          userLat: widget.lat,
                                          userLon: widget.lon,
                                          initialZone:
                                              parsedAction.params['zone'],
                                          initialStops: int.tryParse(
                                              parsedAction.params['stops'] ??
                                                  ''),
                                        ),
                                      ),
                                    );
                                  } else if (parsedAction.actionType ==
                                      'OPEN_TITHI') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PujaCalendarScreen(
                                          userLat: widget.lat,
                                          userLon: widget.lon,
                                          initialDayId:
                                              parsedAction.params['day'] ??
                                                  'ashtami',
                                          initialSchool:
                                              parsedAction.params['school'],
                                        ),
                                      ),
                                    );
                                  } else if (parsedAction.actionType ==
                                      'OPEN_MAP') {
                                    final lat = double.tryParse(
                                        parsedAction.params['lat'] ?? '');
                                    final lng = double.tryParse(
                                        parsedAction.params['lng'] ??
                                            parsedAction.params['lon'] ??
                                            '');
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MapScreen(
                                          targetLat: lat,
                                          targetLng: lng,
                                          selectedName:
                                              parsedAction.params['name'],
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],

                          // Dial 112 Emergency Button
                          if (!isUser && msg['isEmergency'] == true) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE62E2D),
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 11),
                                ),
                                icon: const Icon(Icons.phone_in_talk,
                                    size: 18, color: Colors.white),
                                label: const Text(
                                  'Dial 112 Now (Kolkata Police & SOS)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                onPressed: () async {
                                  final uri = Uri.parse('tel:112');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  }
                                },
                              ),
                            ),
                          ],

                          // Read Aloud vocalization button
                          if (!isUser &&
                              (msg['text'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () {
                                  if (_voiceService.isSpeaking) {
                                    _voiceService.stopSpeaking();
                                    setState(() {});
                                  } else {
                                    _voiceService
                                        .speak(_sanitizePlainText(
                                            msg['text'] ?? ''))
                                        .then((_) {
                                      if (mounted) setState(() {});
                                    });
                                    setState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _voiceService.isSpeaking
                                            ? Icons.volume_off
                                            : Icons.volume_up_outlined,
                                        size: 14,
                                        color: kMarigoldAmber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _voiceService.isSpeaking
                                            ? 'Stop'
                                            : 'Read Aloud',
                                        style: const TextStyle(
                                          color: kMarigoldAmber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Suggestions Chips (Time-gated)
                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: suggestions
                                  .map((s) => ActionChip(
                                        backgroundColor:
                                            const Color(0xFF242438),
                                        side: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.14)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        label: Text(
                                          s,
                                          style: const TextStyle(
                                            color: Color(0xFFEDE7F6),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        onPressed: () => _sendMessage(s),
                                      ))
                                  .toList(),
                            ),
                          ],

                          // =========================================================================
                          // CONVERSATIONAL INTERACTIVE PANDAL CARDS (Replacing wall of text)
                          // =========================================================================
                          if (route.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.stars,
                                        color: kMarigoldAmber, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'RECOMMENDED PANDALS (${route.length}):',
                                      style: const TextStyle(
                                        color: kMarigoldAmber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                                // Auto-Circuit 1-Tap Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kSindoorRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                  icon: const Icon(Icons.flash_on, size: 14),
                                  label: const Text('Auto-Circuit',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    final ids = route.map((p) => p.id).toList();
                                    await SessionService.instance
                                        .saveCircuit(ids, true);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor:
                                            const Color(0xFF1C1C2E),
                                        content: Text(
                                            '⚡ Saved ${route.length}-stop circuit! Launching Google Maps...'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    _openGoogleMapsCircuit(route);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Pandal Cards List with generous internal breathing room
                            ...route.map((p) {
                              final bool isMega = p.category == 'mega';
                              final int dist = _getDistanceMeters(
                                      widget.lat, widget.lon, p.lat, p.lon)
                                  .round();
                              final int dur = max(1, (dist / 75).round());

                              return Container(
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121222),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isMega
                                        ? kSindoorRed.withOpacity(0.3)
                                        : kMarigoldAmber.withOpacity(0.35),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Name, Category, Category Badge (Transparent, No fake wait times)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isMega
                                                ? kSindoorRed.withOpacity(0.18)
                                                : kMarigoldAmber
                                                    .withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: isMega
                                                    ? kSindoorRed
                                                    : kMarigoldAmber),
                                          ),
                                          child: Icon(
                                            isMega
                                                ? Icons.local_fire_department
                                                : Icons.account_balance,
                                            color: isMega
                                                ? kSindoorRed
                                                : kMarigoldAmber,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14.5),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${p.subsection} • ${p.zone} Kolkata',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Category Badge (No simulated queue)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isMega
                                                ? kSindoorRed.withOpacity(0.18)
                                                : kMarigoldAmber
                                                    .withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isMega
                                                  ? kSindoorRed.withOpacity(0.6)
                                                  : kMarigoldAmber
                                                      .withOpacity(0.6),
                                            ),
                                          ),
                                          child: Text(
                                            isMega
                                                ? '🔥 Mega Theme'
                                                : '🏛️ Bonedi Bari',
                                            style: TextStyle(
                                              color: isMega
                                                  ? const Color(0xFFFF8A80)
                                                  : kMarigoldAmber,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Row 2: Metro connectivity with Gate & Police Barricade
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_subway,
                                            color: Colors.cyanAccent, size: 14),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            p.detailedMetroGate,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (p.barricadeAdvisory.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        '🚧 ${p.barricadeAdvisory}',
                                        style: const TextStyle(
                                            color: Color(0xFFFFD54F),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                    const SizedBox(height: 4),

                                    // Row 3: Walking Distance
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_walk,
                                            color: kMarigoldAmber, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          dist > 1000
                                              ? '${(dist / 1000).toStringAsFixed(1)} km away'
                                              : '$dist m away',
                                          style: const TextStyle(
                                              color: kMarigoldAmber,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5),
                                        ),
                                        const Text(' • ',
                                            style: TextStyle(
                                                color: Colors.white38)),
                                        Text('~$dur min walk',
                                            style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 11.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Row 4: Action Buttons [Add to Circuit] [View Details] [Navigate Maps]
                                    Row(
                                      children: [
                                        // Add to Circuit
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: kMarigoldAmber,
                                              side: BorderSide(
                                                  color: kMarigoldAmber
                                                      .withOpacity(0.5)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.playlist_add,
                                                size: 15),
                                            label: const Text('Add to Circuit',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            onPressed: () async {
                                              final circuit = List<String>.from(
                                                  SessionService.instance
                                                      .activeCircuitIds);
                                              if (!circuit.contains(p.id)) {
                                                circuit.add(p.id);
                                              }
                                              await SessionService.instance
                                                  .saveCircuit(circuit, true);
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  backgroundColor:
                                                      const Color(0xFF1E1428),
                                                  content: Text(
                                                      'Added ${p.name} to circuit (${circuit.length} stops)'),
                                                  duration: const Duration(
                                                      seconds: 2),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // View Details Modal
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Colors.white24),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.info_outline,
                                              size: 15),
                                          label: const Text('Details',
                                              style: TextStyle(fontSize: 11)),
                                          onPressed: () =>
                                              _showPandalDetailsModal(p),
                                        ),
                                        const SizedBox(width: 6),

                                        // Navigate Maps Button
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: kSindoorRed,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _openGoogleMaps(p),
                                          child: const Icon(Icons.navigation,
                                              size: 15),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              alignment: Alignment.centerLeft,
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kMarigoldAmber),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'AI Sathi is searching 504 pandals & Belur Math Panjika...',
                    style: TextStyle(
                        color: kMarigoldAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // =========================================================================
          // INPUT BAR (Spacious, Rounded & Clean)
          // =========================================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: kMidnightBlue,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: _isPreflightChecking
                          ? 'Checking AI connection...'
                          : _isListening
                              ? 'Listening...'
                              : 'Ask about pandals or routes...',
                      hintStyle: TextStyle(
                        color: _isPreflightChecking ? Colors.white54 : _isListening ? kMarigoldAmber : Colors.white38,
                        fontSize: 13,
                        fontStyle:
                            _isListening ? FontStyle.italic : FontStyle.normal,
                      ),
                      prefixIcon: IconButton(
                        icon: Icon(
                          _isListening ? Icons.stop_circle : Icons.mic,
                          color: _isListening ? kSindoorRed : kMarigoldAmber,
                          size: 22,
                        ),
                        tooltip:
                            _isListening ? 'Stop Listening' : 'Voice Dictate',
                        onPressed: _toggleVoiceDictation,
                      ),
                      filled: true,
                      fillColor: _isListening
                          ? const Color(0xFF261C2C)
                          : const Color(0xFF18182A),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _isListening
                              ? kSindoorRed
                              : kMarigoldAmber.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _isListening ? kSindoorRed : Colors.white12,
                          width: _isListening ? 1.5 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: _isListening ? kSindoorRed : kMarigoldAmber,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: _isPreflightChecking || (!_isAiReady && _controller.text.isEmpty)
                            ? [Colors.grey.shade600, Colors.grey.shade500]
                            : [kSindoorRed, const Color(0xFFFF5252)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!_isPreflightChecking)
                        BoxShadow(
                            color: _isAiReady ? kSindoorRed.withOpacity(0.5) : Colors.transparent, blurRadius: 8),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send_rounded,
                        color: _isPreflightChecking ? Colors.white54 : Colors.white, size: 20),
                    onPressed: _isPreflightChecking ? null : () => _sendMessage(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
