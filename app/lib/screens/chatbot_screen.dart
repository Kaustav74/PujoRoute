import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../data/pujas_data.dart';
import '../services/emergency_service.dart';
import '../services/live_feed_service.dart';
import '../services/session_service.dart';
import '../services/security_service.dart';
import '../services/voice_assistant_service.dart';
import '../services/duckduckgo_service.dart';
import '../services/spatial_facility_service.dart';
import '../services/deterministic_routing_service.dart';
import '../services/pandal_repository.dart';
import '../services/ai_token_gate_service.dart';
import '../services/quick_reply_service.dart';
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
  final VoiceAssistantService _voiceService = VoiceAssistantService.instance;
  final EmergencyService _emergencyService = EmergencyService.instance;
  final LiveFeedService _liveFeedService = LiveFeedService.instance;
  final DuckDuckGoSearchService _ddgService = DuckDuckGoSearchService.instance;

  static const String _groqModel = 'qwen/qwen3.8-27b';

  // Client Cooler: Max 5 questions per 60-second sliding window
  final List<DateTime> _recentRequestTimestamps = [];

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

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('api.groq.com')
          .timeout(const Duration(milliseconds: 4000));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('google.com')
            .timeout(const Duration(milliseconds: 3000));
        return fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
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

    // =========================================================================
    // 0. OFFLINE QUICK REPLY ENGINE (0-network, 0-AI token cost)
    // =========================================================================
    final offlineQuickMatch = QuickReplyService().matchQuery(query);
    if (offlineQuickMatch != null) {
      final parsedAction = offlineQuickMatch.actionTag != null
          ? parseAiActionTag(offlineQuickMatch.actionTag!)
          : null;
      setState(() {
        _messages.add({
          "role": "user",
          "text": query,
          "route": <Pandal>[],
        });
        _messages.add({
          "role": "bot",
          "text": offlineQuickMatch.response,
          "ui_action": parsedAction,
          "route": <Pandal>[],
        });
        _isLoading = false;
      });
      SessionService.instance.saveChatMessages(_messages);
      _controller.clear();
      _scrollToBottom();
      return;
    }

    // =========================================================================
    // CLIENT COOLER: 5 REQUESTS PER 60-SECOND SLIDING WINDOW THROTTLE
    // =========================================================================
    final currentTime = DateTime.now();
    _recentRequestTimestamps
        .removeWhere((t) => currentTime.difference(t).inSeconds > 60);
    if (_recentRequestTimestamps.length >= 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFE65100),
            content: Row(
              children: [
                Icon(Icons.hourglass_empty, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⏳ Client Cooler Active: Max 5 questions per minute. Please pause for a few seconds.',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // =========================================================================
    // AI SURGE TOKEN GATE: MAX 2 AI QUERIES PER 5-MINUTE WINDOW
    // =========================================================================
    if (!AiTokenGateService().canMakeQuery()) {
      setState(() {
        _messages.add({
          "role": "user",
          "text": query,
          "route": <Pandal>[],
        });
        _messages.add({
          "role": "bot",
          "text": "⚡ **AI Surge Token Gate Active**:\n"
              "You have reached the rolling limit of 2 AI queries per 5-minute window during surge hours.\n\n"
              "💡 **Offline Quick Replies** (Sandhi Puja 2026, Metro Hours, Traffic Advisories, SOS) remain **100% available offline** with zero quota consumption!",
          "route": <Pandal>[],
        });
        _isLoading = false;
      });
      SessionService.instance.saveChatMessages(_messages);
      _controller.clear();
      _scrollToBottom();
      return;
    }

    AiTokenGateService().tryConsumeToken();
    _recentRequestTimestamps.add(currentTime);

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

    // =========================================================================
    // 1. EMERGENCY INTENT ENGINE TRIGGER (Immediate bypass of AI chatter)
    // =========================================================================
    if (_emergencyService.isEmergencyQuery(query)) {
      AiTokenGateService().releaseInFlight();
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

    final qLower = query.toLowerCase();
    final bool isDatabaseStatsQuery = qLower.contains('how many') ||
        qLower.contains('database') ||
        qLower.contains('total') ||
        qLower.contains('entries') ||
        qLower.contains('stats') ||
        qLower.contains('count') ||
        qLower.contains('access') ||
        qLower.contains('dataset') ||
        qLower.contains('records');

    int requestedCount = 4;
    final countMatch = RegExp(r'\b(\d+)\s*(?:pandal|pujo|puja|stop|hop)s?\b',
            caseSensitive: false)
        .firstMatch(query);
    if (countMatch != null) {
      requestedCount = int.tryParse(countMatch.group(1) ?? '4') ?? 4;
      if (requestedCount < 2) requestedCount = 2;
      if (requestedCount > 15) requestedCount = 15;
    } else if (qLower.contains('circuit') ||
        qLower.contains('route') ||
        qLower.contains('itinerary')) {
      requestedCount = 6;
    }

    final bool isRouteQuery = qLower.contains('circuit') ||
        qLower.contains('route') ||
        qLower.contains('itinerary') ||
        qLower.contains('cross-river') ||
        qLower.contains('howrah') ||
        qLower.contains('hop');

    StrictRouteJson? strictRoute;
    if (isRouteQuery) {
      strictRoute = DeterministicRoutingService.instance
          .buildCrossRiverCircuit(count: requestedCount);
    }

    final matchedPandals =
        _searchDatabaseForContext(query, limit: max(requestedCount, 12));

    // Dynamic timestamp injection
    final now = DateTime.now();
    final timeStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} IST";

    // =========================================================================
    // 2. REAL-TIME CONNECTIVITY PROBE: ONLINE-FIRST PIPELINE
    // =========================================================================
    // Offline mode is strictly a fallback for zero internet, DNS failure or timeout.
    final bool isOnline = await _checkInternetConnection();
    if (!isOnline) {
      setState(() {
        _messages.add({
          "role": "bot",
          "text":
              "It looks like you are offline right now. Please connect to the internet so I can reach Groq for live updates.",
          "route": <Pandal>[],
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    final contextPujasStr = matchedPandals.take(requestedCount).map((p) {
      final dist =
          _getDistanceMeters(widget.lat, widget.lon, p.lat, p.lon).round();
      final dur = max(1, (dist / 75).round());
      return "${p.name} [ID: ${p.id}, Category: ${p.category}, Dist: ${dist > 1000 ? '${(dist / 1000).toStringAsFixed(1)}km' : '${dist}m'} (~$dur min walk), Metro: ${p.metroStation}, Landmark: ${p.landmark}, Notes: ${p.history}]";
    }).join("\n");

    final systemPrompt = (isRouteQuery && strictRoute != null)
        ? """
You are PujoRoute AI Sathi. Your job is ONLY to convert the following strict, pre-calculated route JSON into friendly human language.
DO NOT change, add, or omit any pandal name, metro station, line name, transfer location, walking distance, or stop order.
DO NOT invent any Metro stations (e.g., Bagbazar Metro does not exist; Sealdah transfer to Blue line does not exist).
Bagbazar Sarbojanin is a Centenary Community puja (NOT Bonedi Bari).
Sovabazar Rajbari is a Bonedi Bari (NOT Mega Theme).
Output concise, friendly human walking instructions based strictly on this JSON.

STRICT ROUTE JSON:
${strictRoute.toRawJsonString()}
"""
        : """
You are PujoRoute AI Sathi, the official festival companion for Kolkata Durga Puja 2026.
Current local device timestamp: $timeStr (Asia/Kolkata).
Active almanac benchmark: Vishuddha Siddhanta / Belur Math tradition.

FESTIVAL TIMELINE BENCHMARK (Vishuddha Siddhanta / Belur Math):
- Mahalaya: Saturday, 10 Oct 2026 (Dawn Tarpan 04:30 AM at Ganga Ghats)
- Maha Shashthi (Bodhon): Friday/Saturday, 16-17 Oct 2026 (Bodhon under Bel tree)
- Maha Saptami: Sunday, 18 Oct 2026 (Kola Bou river bath 05:45 AM)
- Maha Ashtami: Monday, 19 Oct 2026 (Kumari Puja ~09:00 AM)
  * EXACT 48-MINUTE SANDHI PUJA WINDOW: 10:28 AM – 11:16 AM (Balidan at 10:52 AM, 108 lotuses and lamps)
- Maha Navami: Tuesday, 20 Oct 2026 (Maha Homa 11:30 AM, Dhunuchi dance)
- Vijaya Dashami: Wednesday, 21 Oct 2026 (Darpan Visarjan 10:45 AM, Sindoor Khela 11:30 AM, Ganga Visarjan)
- Kojagari Lakshmi Puja: Sunday, 25 Oct 2026

PERMANENT KOLKATA PUJA TRAFFIC AXIOMS:
1. Arterial Driving (Post 3:00 PM): All major pujo arteries (Rashbehari Ave, Gariahat Rd, Central Ave, VIP Road near Sreebhumi) convert strictly to pedestrian corridors or restricted one-ways from 3:00 PM until 4:00 AM. Advise users: DO NOT drive private cars or autos; always take the Metro.
2. Metro Hours (Puja Days): Kolkata Metro (Blue Line & Green Line) runs special all-night services on Saptami, Ashtami, and Navami, running past midnight until 4:00 AM.
3. Auto-Rickshaws: Standalone auto-rickshaw routes crossing major pandal approaches (e.g., Gariahat to Garia, Shyambazar to Hatibagan) are officially suspended or truncated past 4:00 PM.
4. VIP Road / Sreebhumi: Sreebhumi entry is strictly segregated from VIP Road via service lanes; vehicles on the main VIP Road flyover are not allowed to stop.
5. Missing Circulars Protocol: If live web search finds no circulars or returns empty, DO NOT say you lack information. Advise using Kolkata's canonical rules: No private cars or autos on major pandal roads post 3:00 PM, pedestrian barricades extend 800m, and recommend Blue/Green Line Metro.

CORE OPERATIONAL PROTOCOLS:
1. BREVITY & FORMAT: Answers must be concise, crisp, and under 80 words. Use bullet points and standalone titles. No generic long intro sentences.
2. LANGUAGE MATCHING: If the user talks in Bengali, reply in Bengali. If in English, reply in English. If in Banglish, reply in Banglish.
3. TRANSIT PRIORITY: Always prioritize Kolkata Metro stations and pedestrian walking circuits.
4. SAFEGUARD FOR 2026 AWARDS: Official awards (like Biswa Bangla Sharad Samman) have NOT been decided yet as the 2026 festival takes place in October 2026. State this fact clearly if asked about winners.
5. Authentic Kolkata Pandal Rule: Only recommend celebrated, authentic Kolkata Durga Puja pandals from the provided context (e.g., Ekdalia Evergreen, Singhi Park, Suruchi Sangha, Tridhara, Maddox Square, Ballygunge Cultural, Chetla Agrani, Mudiali, Bagbazar Sarbojanin, Kumartuli Park, College Square, Sreebhumi).
6. Total master registry size: 504 verified Durga Pujas in Kolkata (490 Mega Thematic, 14 Historic Bonedi Bari Mansions).

STRICT IN-APP DEEP-LINK ACTION PROTOCOL:
Emit an [ACTION:...] tag ONLY AND EXCLUSIVELY when explicitly requested:
1. If user explicitly asks to open/plan route planner or circuit studio, append at the very end: [ACTION:OPEN_CIRCUIT_STUDIO|zone=<South/North/Central/Salt Lake/All>&stops=<num>]
2. If user explicitly asks to open/view tithi timings or says 'take me to tithi', append at the very end: [ACTION:OPEN_TITHI|day=<ashtami/saptami/shashthi/navami/dashami>&school=<vishuddha/traditional>]
3. If user explicitly asks to show/locate a pandal on the map or says 'show on map', append at the very end: [ACTION:OPEN_MAP|lat=<lat>&lng=<lng>&name=<pandal>]
For ALL OTHER queries (history, distance, info, lists, general questions, emergencies, unknown locations), DO NOT emit any ACTION tag.

User coordinates: Lat: ${widget.lat}, Lon: ${widget.lon}.
Top matching pandals from master registry:
$contextPujasStr
""";

    try {
      String? replyText;
      String engineProviderTag = '⚡ Groq Ultra-Fast (Llama 3.3)';

      final tools = [
        {
          'type': 'function',
          'function': {
            'name': 'search_live_web',
            'description':
                'Search the live web for real-time Kolkata Durga Puja 2026 news, awards, weather, police traffic advisories, or road barricades.',
            'parameters': {
              'type': 'object',
              'properties': {
                'query': {
                  'type': 'string',
                  'description':
                      'The search query string to find recent live news or information'
                }
              },
              'required': ['query'],
            }
          }
        }
      ];

      final messagesPayload = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': systemPrompt,
        },
      ];

      // Conversational Memory: Include last 5-6 turns (10 messages)
      final historyTurns = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;
      for (final m in historyTurns) {
        final r = m['role'];
        final t = m['text'] as String?;
        if (t != null && t.isNotEmpty) {
          final role = (r == 'user') ? 'user' : 'assistant';
          messagesPayload.add({
            'role': role,
            'content': t,
          });
        }
      }

      messagesPayload.add({
        'role': 'user',
        'content': query,
      });

      // 30-Second Timeout Baseline & Zero-Secret Gateway Proxy Architecture
      final String gatewayUrl = SessionService.instance.proxyGatewayUrl;
      final payload = json.encode({
        'model': _groqModel,
        'messages': messagesPayload,
        'query': query,
        'system_prompt': systemPrompt,
        'tools': tools,
        'tool_choice': 'auto',
        'temperature': 0.3,
        'max_tokens': 1200,
      });

      final headers = SecurityService.instance.createVerificationHeaders(payload);
      headers['User-Agent'] = 'PujoRoute-Android/2.0 (Kolkata Durga Puja)';

      final authMap = SecurityService.formatAuthHeader(SessionService.getSecureApiKey());
      if (authMap.containsKey('Authorization')) {
        headers.addAll(authMap);
      }

      final hasAuth = headers.containsKey('Authorization');
      final authHeaderVal = headers['Authorization'] ?? '';
      final isBearerScheme = authHeaderVal.startsWith('Bearer ');
      debugPrint("Outgoing Auth Header: ${authHeaderVal.length > 22 ? authHeaderVal.substring(0, 22) : authHeaderVal}...");
      debugPrint("AI Auth Diagnostic -> endpoint: $gatewayUrl, scheme: ${isBearerScheme ? 'Bearer' : (hasAuth ? 'Custom/Raw' : 'None')}, keyPresent: $hasAuth, length: ${authHeaderVal.length}");

      http.Response? response;
      try {
        response = await http
            .post(
              Uri.parse(gatewayUrl),
              headers: headers,
              body: payload,
            )
            .timeout(const Duration(seconds: 30));
      } catch (netErr) {
        debugPrint("Direct HTTP gateway notice: $netErr. Attempting dispatchViaProxy...");
        replyText = await SecurityService.instance.dispatchChatViaProxy(
          proxyUrl: gatewayUrl,
          prompt: query,
          systemPrompt: systemPrompt,
          messages: messagesPayload,
          timeoutSeconds: 30,
        );
        if (replyText != null && replyText.isNotEmpty) {
          engineProviderTag = '⚡ AI Sathi Proxy Gateway';
        } else {
          rethrow;
        }
      }

      if (response != null && response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is Map) {
          if (data.containsKey('choices') && (data['choices'] as List).isNotEmpty) {
            final choice = data['choices'][0];
            final message = choice['message'];

            if (message != null &&
                message['tool_calls'] != null &&
                (message['tool_calls'] as List).isNotEmpty) {
              final toolCalls = message['tool_calls'] as List;
              final firstCall = toolCalls.first;
              final callId = firstCall['id'] ?? 'call_1';
              final fnName = firstCall['function']?['name'];

              if (fnName == 'search_live_web') {
                String searchQuery = query;
                try {
                  final rawArgs = firstCall['function']?['arguments'];
                  if (rawArgs is String) {
                    final args = json.decode(rawArgs);
                    if (args['query'] != null &&
                        (args['query'] as String).isNotEmpty) {
                      searchQuery = args['query'];
                    }
                  }
                } catch (_) {}

                final ddgResults =
                    await _ddgService.search(searchQuery, maxResults: 3);
                final toolOutput = ddgResults.isNotEmpty
                    ? ddgResults.map((r) => '${r.title}: ${r.snippet}').join('\n')
                    : 'No real-time Kolkata alerts found for this query. Grounded fact: For Durga Puja 2026, official awards and winners are decided during the festival in October 2026.';

                messagesPayload.add(message as Map<String, dynamic>);
                messagesPayload.add({
                  'role': 'tool',
                  'tool_call_id': callId,
                  'name': 'search_live_web',
                  'content': toolOutput,
                });

                final secondBody = json.encode({
                  'model': _groqModel,
                  'messages': messagesPayload,
                  'temperature': 0.3,
                  'max_tokens': 1200,
                });
                final secondHeaders = SecurityService.instance.createVerificationHeaders(secondBody);
                secondHeaders['User-Agent'] = 'PujoRoute-Android/2.0 (Kolkata Durga Puja)';
                final secondAuthMap = SecurityService.formatAuthHeader(SessionService.getSecureApiKey());
                if (secondAuthMap.containsKey('Authorization')) {
                  secondHeaders.addAll(secondAuthMap);
                }

                final secondResponse = await http
                    .post(
                      Uri.parse(gatewayUrl),
                      headers: secondHeaders,
                      body: secondBody,
                    )
                    .timeout(const Duration(seconds: 30));

                if (secondResponse.statusCode == 200) {
                  final secondData = json.decode(utf8.decode(secondResponse.bodyBytes));
                  if (secondData is Map && secondData.containsKey('choices')) {
                    replyText = secondData['choices'][0]['message']['content'] as String?;
                  }
                  engineProviderTag = '🌐 Grounded via DuckDuckGo Live Search';
                }
              }
            } else if (message != null && message['content'] != null) {
              replyText = message['content'] as String?;
              engineProviderTag = '⚡ AI Sathi Gateway (Llama 3.3)';
            }
          } else if (data.containsKey('display_text')) {
            replyText = data['display_text'] as String?;
            engineProviderTag = '⚡ PujoRoute Backend AI';
          } else if (data.containsKey('reply')) {
            replyText = data['reply'] as String?;
            engineProviderTag = '⚡ PujoRoute Backend AI';
          } else if (data.containsKey('response')) {
            replyText = data['response'] as String?;
            engineProviderTag = '⚡ AI Sathi Cloud Gateway';
          }
        }
      } else if (response != null && response.statusCode != 200) {
        final statusCode = response.statusCode;
        debugPrint('AI Gateway returned HTTP status $statusCode: ${response.body}');
        if (statusCode == 401) {
          throw Exception("AI Server Authentication Error (HTTP 401).");
        } else if (statusCode == 403) {
          throw Exception("AI Server Access Restricted (HTTP 403).");
        } else if (statusCode == 404) {
          throw Exception("AI Gateway Endpoint Not Found (HTTP 404).");
        } else if (statusCode == 408) {
          throw Exception("AI Server Request Timed Out (HTTP 408).");
        } else if (statusCode == 429) {
          throw Exception("AI Server Quota Reached (HTTP 429). Please try again in a moment.");
        } else if (statusCode >= 500) {
          throw Exception("AI Server Is Currently Busy (HTTP $statusCode). Please try again.");
        } else {
          throw Exception("AI Gateway Network Error (HTTP $statusCode).");
        }
      }

      if (replyText != null && replyText.isNotEmpty) {
        bool isSanityPassed = true;
        if (strictRoute != null) {
          isSanityPassed = verifyAiSanity(replyText, strictRoute);
          if (!isSanityPassed) {
            debugPrint(
                "Client AI Sanity Guard FAILED: Discarding LLM prose and falling back to DeterministicRouteCard UI.");
            replyText =
                "Here is your verified, zero-hallucination Metro circuit:";
          }
        }

        final sanitized = _sanitizePlainText(replyText);
        setState(() {
          _messages.add({
            "role": "bot",
            "text": sanitized,
            "isOffline": false,
            "engine": strictRoute != null
                ? (isSanityPassed
                    ? '🛡️ Verified AI Formatted Route'
                    : '⚡ Deterministic Fallback Guard')
                : (engineProviderTag.isNotEmpty
                    ? engineProviderTag
                    : '⚡ AI Sathi Gateway'),
            "strictRoute": strictRoute,
            "route": isDatabaseStatsQuery
                ? <Pandal>[]
                : matchedPandals.take(requestedCount).toList(),
            "suggestions": _getTimeGatedSuggestions(),
          });
          _isLoading = false;
        });
        SessionService.instance.saveChatMessages(_messages);
        if (SessionService.instance.isAutoSpeakEnabled) {
          _voiceService.speak(sanitized);
        }
      } else {
        setState(() {
          _messages.add({
            "role": "bot",
            "text":
                "AI Sathi server is temporarily unavailable. Please try again in a moment.",
            "route": <Pandal>[],
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Chatbot exception: $e');
      String userErrorMsg = "Unable to reach AI servers. Please check your internet connection.";
      if (e is TimeoutException) {
        userErrorMsg = "Request timed out while waiting for AI servers (30s timeout). Please try again.";
      } else if (e.toString().contains("HTTP 401")) {
        userErrorMsg = "AI Server Authentication Error (HTTP 401).";
      } else if (e.toString().contains("HTTP 429")) {
        userErrorMsg = "AI Server Quota Reached (HTTP 429). Please try again in a moment.";
      } else if (e.toString().contains("HTTP 5")) {
        userErrorMsg = "AI Server is currently busy. Please try again in a moment.";
      } else if (e.toString().contains("Exception:")) {
        final raw = e.toString().replaceAll("Exception:", "").trim();
        if (raw.isNotEmpty) userErrorMsg = raw;
      }

      if (mounted) {
        setState(() {
          _messages.add({
            "role": "bot",
            "text": userErrorMsg,
            "route": <Pandal>[],
          });
          _isLoading = false;
        });
      }
    }

    AiTokenGateService().releaseInFlight();
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
    final destination = '${p.lat.toStringAsFixed(5)},${p.lon.toStringAsFixed(5)}';
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
          // SPACIOUS QUICK-ACTION CHIPS ROW
          // =========================================================================
          Container(
            height: 44,
            color: kMidnightBlue,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: _getTimeGatedSuggestions().map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                  child: ActionChip(
                    backgroundColor: const Color(0xFF1C1C2E),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    label: Text(
                      prompt,
                      style: const TextStyle(
                          color: Color(0xFFE6E6FA),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _sendMessage(prompt),
                  ),
                );
              }).toList(),
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
                      hintText: _isListening
                          ? 'Listening to your voice (Bangla / English)...'
                          : 'Ask about pandals, Sandhi Puja, routes...',
                      hintStyle: TextStyle(
                        color: _isListening ? kMarigoldAmber : Colors.white38,
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
                    gradient: const LinearGradient(
                        colors: [kSindoorRed, Color(0xFFFF5252)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: kSindoorRed.withOpacity(0.5), blurRadius: 8),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_controller.text),
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
