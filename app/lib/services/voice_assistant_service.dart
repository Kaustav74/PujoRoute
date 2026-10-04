import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import '../data/pujas_data.dart';
import 'session_service.dart';

enum VoiceIntentType {
  navigation,
  calendar,
  circuit,
  emergency,
  general,
}

class VoiceIntentResult {
  final VoiceIntentType type;
  final String originalQuery;
  final String vocalResponse;
  final Pandal? targetPandal;
  final String? targetDayId;
  final int stopCount;

  const VoiceIntentResult({
    required this.type,
    required this.originalQuery,
    required this.vocalResponse,
    this.targetPandal,
    this.targetDayId,
    this.stopCount = 8,
  });
}

class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  static VoiceAssistantService get instance => _instance;

  VoiceAssistantService._internal();

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _speech = SpeechToText();

  bool _isInitialized = false;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastSpokenWords = '';

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isSpeechAvailable => _isSpeechAvailable;
  String get lastSpokenWords => _lastSpokenWords;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Configure Native Text-To-Speech with warm Bengali / Indian English voice
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Prefer Bengali India (bn-IN) or Indian English (en-IN)
      final languages = await _tts.getLanguages;
      if (languages is List) {
        if (languages.contains("bn-IN") || languages.contains("bn")) {
          await _tts.setLanguage(languages.contains("bn-IN") ? "bn-IN" : "bn");
        } else if (languages.contains("en-IN")) {
          await _tts.setLanguage("en-IN");
        } else {
          await _tts.setLanguage("en-US");
        }
      }

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((_) {
        _isSpeaking = false;
      });

      // 2. Configure Speech-To-Text
      _isSpeechAvailable = await _speech.initialize(
        onError: (val) {
          _isListening = false;
          debugPrint("Speech recognition error: $val");
        },
        onStatus: (status) {
          _isListening = (status == "listening");
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint("VoiceAssistantService init error: $e");
      _isInitialized = true;
    }
  }

  /// Cleans markdown and formatting for natural phonetic speech synthesis
  static String cleanForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'[*#_`~]'), '')
        .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '')
        .replaceAll(RegExp(r'[•▪►▶→⚡🪔🏛️🔥🌸🌿🌊🌺🌾💡⏳🎉📍🚇🚨👮🏥]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Speaks text aloud using warm Bengali (bn-IN) or Indian English (en-IN) rendering
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    if (text.trim().isEmpty) return;

    final clean = cleanForSpeech(text);
    final hasBengaliChars = RegExp(r'[\u0980-\u09FF]').hasMatch(clean);

    try {
      final languages = await _tts.getLanguages;
      if (languages is List) {
        if (hasBengaliChars && (languages.contains("bn-IN") || languages.contains("bn"))) {
          await _tts.setLanguage(languages.contains("bn-IN") ? "bn-IN" : "bn");
          await _tts.setSpeechRate(0.48);
        } else if (languages.contains("en-IN")) {
          await _tts.setLanguage("en-IN");
          await _tts.setSpeechRate(0.50);
        } else {
          await _tts.setLanguage("en-US");
        }
      }
      await _tts.stop();
      await _tts.speak(clean);
    } catch (e) {
      debugPrint("TTS speak error: $e");
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (_) {}
  }

  /// Transcribes raw audio bytes with Groq's sub-200ms Whisper-large-v3 model
  /// Supports direct Bengali and English code-mixing
  Future<String?> transcribeWithGroqWhisper(List<int> audioBytes, {String? language}) async {
    try {
      final apiKey = SessionService.getSecureApiKey();
      final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-large-v3'
        ..fields['prompt'] = 'Kolkata Durga Puja, pandal, tithi, Bangla, English, বাংলা, একডালিয়া, সন্ধিপূজা, পুজো, কুমারটুলী, Pushpanjali, Sandhi Puja, Bonedi Bari'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.wav',
        ));

      if (language != null && language.isNotEmpty) {
        request.fields['language'] = language;
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 6));
      if (streamedResponse.statusCode == 200) {
        final respStr = await streamedResponse.stream.bytesToString();
        final data = json.decode(respStr);
        return data['text'] as String?;
      }
    } catch (e) {
      debugPrint("Groq Whisper STT transcription error: $e");
    }
    return null;
  }

  /// Starts listening for speech input with Bengali and Indian English support
  Future<void> startListening({
    required Function(String partialText) onResult,
    required Function(VoiceIntentResult intent) onIntentResolved,
    double userLat = 22.5726,
    double userLon = 88.3639,
    String? preferredLanguage, // 'bn', 'en'
  }) async {
    if (!_isInitialized) await init();
    await stopSpeaking();

    if (!_isSpeechAvailable) {
      _isSpeechAvailable = await _speech.initialize();
      if (!_isSpeechAvailable) {
        onResult("Speech recognition unavailable on this device.");
        return;
      }
    }

    _lastSpokenWords = '';
    _isListening = true;

    // Detect available Bengali / Indian English speech recognition locales (Strictly English & Bengali)
    String? preferredLocaleId;
    try {
      final locales = await _speech.locales();
      if (preferredLanguage == 'bn' && locales.any((l) => l.localeId.startsWith('bn'))) {
        preferredLocaleId = locales.firstWhere((l) => l.localeId.startsWith('bn')).localeId;
      } else if (locales.any((l) => l.localeId == 'en_IN' || l.localeId == 'en-IN')) {
        preferredLocaleId = locales.firstWhere((l) => l.localeId == 'en_IN' || l.localeId == 'en-IN').localeId;
      } else if (locales.any((l) => l.localeId.startsWith('en'))) {
        preferredLocaleId = locales.firstWhere((l) => l.localeId.startsWith('en')).localeId;
      } else if (locales.any((l) => l.localeId.startsWith('bn'))) {
        preferredLocaleId = locales.firstWhere((l) => l.localeId.startsWith('bn')).localeId;
      }
    } catch (_) {}

    await _speech.listen(
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      localeId: preferredLocaleId,
      onResult: (result) {
        _lastSpokenWords = result.recognizedWords;
        onResult(result.recognizedWords);

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          final intent = resolveVoiceIntent(
            result.recognizedWords,
            userLat: userLat,
            userLon: userLon,
          );
          onIntentResolved(intent);
        }
      },
    );
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Resolves spoken voice commands with support for English, Bengali, and Banglish
  VoiceIntentResult resolveVoiceIntent(
    String query, {
    double userLat = 22.5726,
    double userLon = 88.3639,
  }) {
    final q = query.toLowerCase().trim();

    // 1. Emergency / Safety Intent (Top Priority: English & Bengali)
    if (q.contains('emergency') ||
        q.contains('help') ||
        q.contains('police') ||
        q.contains('lost') ||
        q.contains('ambulance') ||
        q.contains('bipod') ||
        q.contains('harie') ||
        q.contains('first aid') ||
        q.contains('casualty') ||
        q.contains('hospital') ||
        q.contains('pass') ||
        q.contains('বিপদ') ||
        q.contains('পুলিশ') ||
        q.contains('সাহায্য') ||
        q.contains('হারিয়ে')) {
      return VoiceIntentResult(
        type: VoiceIntentType.emergency,
        originalQuery: query,
        vocalResponse: "Emergency mode activated. Opening your offline Emergency Safety Pass with nearest Kolkata Police assistance and hospital casualty ward contacts.",
      );
    }

    // 2. Food & Adda Intent (English, Bengali, Banglish) - Evaluated before generic location queries
    if (q.contains('roll') ||
        q.contains('adda') ||
        q.contains('khabar') ||
        q.contains('food') ||
        q.contains('phuchka') ||
        q.contains('biryani') ||
        q.contains('cha') ||
        q.contains('cutlet') ||
        q.contains('খাবার') ||
        q.contains('ফুচকা') ||
        q.contains('আড্ডা')) {
      final addaPandal = kAllKolkataPujas.firstWhere(
        (p) => p.name.toLowerCase().contains('maddox') || p.name.toLowerCase().contains('gariahat'),
        orElse: () => kAllKolkataPujas.first,
      );
      return VoiceIntentResult(
        type: VoiceIntentType.general,
        originalQuery: query,
        vocalResponse: "Maddox Square ar Gariahat-e bawaal kathi roll, cutlet ar shondher adda paben! Sathe bhalo pandal-o dekhe nin.",
        targetPandal: addaPandal,
      );
    }

    // 3. Navigation / Direction / Distance Intent: English and Bengali only
    if (q.contains('take me to') ||
        q.contains('navigate to') ||
        q.contains('go to') ||
        q.contains('directions to') ||
        q.contains('route to') ||
        q.contains('walk to') ||
        q.contains('koto dur') ||
        q.contains('koto dure') ||
        q.contains('rasta') ||
        q.contains('paid walk') ||
        q.contains('রাস্তা') ||
        q.contains('প্যান্ডেল') ||
        q.contains('দূরত্ব') ||
        q.contains('কখন যাব') ||
        q.contains('kothay')) {
      final targetPandal = _matchBestPandalFromSpokenQuery(q);
      if (targetPandal != null) {
        return VoiceIntentResult(
          type: VoiceIntentType.navigation,
          originalQuery: query,
          vocalResponse: "Opening walking navigation to ${targetPandal.name} in ${targetPandal.subsection} via Google Maps.",
          targetPandal: targetPandal,
        );
      }
    }

    // 3. Calendar / Tithi / Sandhi / Ritual Intent (Belur Math Benchmark)
    if (q.contains('sandhi') ||
        q.contains('ashtami') ||
        q.contains('tithi') ||
        q.contains('calendar') ||
        q.contains('schedule') ||
        q.contains('timing') ||
        q.contains('panjika') ||
        q.contains('mahalaya') ||
        q.contains('saptami') ||
        q.contains('nabami') ||
        q.contains('dashami') ||
        q.contains('shashthi') ||
        q.contains('panchami') ||
        q.contains('lakshmi') ||
        q.contains('kokhon') ||
        q.contains('anjali') ||
        q.contains('pushpanjali') ||
        q.contains('পুজো') ||
        q.contains('তিথি') ||
        q.contains('অঞ্জলি') ||
        q.contains('সন্ধিপূজা') ||
        q.contains('মহালয়া')) {
      String dayId = 'ashtami';
      String vocal = "Here is the official 2026 Durga Puja calendar following the Vishuddha Siddhanta and Belur Math tradition.";

      if (q.contains('sandhi') || q.contains('ashtami') || q.contains('anjali') || q.contains('pushpanjali')) {
        dayId = 'ashtami';
        vocal = "On Maha Ashtami, October 19, 2026, the sacred 48-minute Sandhi Puja window under the Belur Math benchmark is from 10:28 AM to 11:16 AM, with Balidan at 10:52 AM.";
      } else if (q.contains('mahalaya') || q.contains('মহালয়া')) {
        dayId = 'mahalaya';
        vocal = "Mahalaya is on Saturday, October 10, 2026. Dawn Tarpan along Ganga Ghats begins at 4:30 AM.";
      } else if (q.contains('saptami') || q.contains('kola bou') || q.contains('nabapatrika')) {
        dayId = 'saptami';
        vocal = "Maha Saptami is on Sunday, October 18, 2026. The sacred Kola Bou river bath takes place at dawn around 5:45 AM.";
      } else if (q.contains('nabami') || q.contains('homa') || q.contains('dhunuchi')) {
        dayId = 'nabami';
        vocal = "Maha Nabami is on Tuesday, October 20, 2026. Maha Homa starts at 11:30 AM with all-night Dhunuchi dance competitions.";
      } else if (q.contains('dashami') || q.contains('sindoor') || q.contains('bisarjan')) {
        dayId = 'dashami';
        vocal = "Bijoya Dashami is on Wednesday, October 21, 2026. Sindoor Khela runs from 11:30 AM, followed by Ganga river immersions.";
      }

      return VoiceIntentResult(
        type: VoiceIntentType.calendar,
        originalQuery: query,
        vocalResponse: vocal,
        targetDayId: dayId,
      );
    }

    // 4. Circuit / Itinerary Intent: "Plan a circuit", "8 stops", "circuit banie dao"
    if (q.contains('circuit') ||
        q.contains('itinerary') ||
        q.contains('hop') ||
        q.contains('route') ||
        q.contains('plan') ||
        q.contains('banie dao')) {
      int count = 8;
      final match = RegExp(r'\b(\d+)\b').firstMatch(q);
      if (match != null) {
        count = int.tryParse(match.group(1) ?? '8') ?? 8;
        if (count < 3) count = 3;
        if (count > 15) count = 15;
      }
      return VoiceIntentResult(
        type: VoiceIntentType.circuit,
        originalQuery: query,
        vocalResponse: "Creating an automated $count-stop pandal hopping circuit optimized for minimal walking. Opening Circuit Studio.",
        stopCount: count,
      );
    }

    // 5. Banglish Fast Route Intent
    if (q.contains('fast-e') ||
        q.contains('taratari') ||
        q.contains('fast pandal') ||
        q.contains('kom bhir') ||
        q.contains('kom queue') ||
        q.contains('shobcheye fast') ||
        q.contains('তাড়াতাড়ি')) {
      final fastPandal = kAllKolkataPujas.firstWhere((p) => p.crowdStatus == 'fast', orElse: () => kAllKolkataPujas.first);
      return VoiceIntentResult(
        type: VoiceIntentType.navigation,
        originalQuery: query,
        vocalResponse: "Ei muhurte shobcheye kom line ache ${fastPandal.name} e (~5 min walk wait). Rasta dekhe nin!",
        targetPandal: fastPandal,
      );
    }


    // 7. Fallback Pandal Discovery: check if query specifically names a pandal
    final namedPandal = _matchBestPandalFromSpokenQuery(q);
    if (namedPandal != null) {
      return VoiceIntentResult(
        type: VoiceIntentType.navigation,
        originalQuery: query,
        vocalResponse: "${namedPandal.name} is located in ${namedPandal.subsection}, nearest metro station is ${namedPandal.detailedMetroGate}. Showing walking directions.",
        targetPandal: namedPandal,
      );
    }

    // 8. General Festival AI Query
    return VoiceIntentResult(
      type: VoiceIntentType.general,
      originalQuery: query,
      vocalResponse: "Processing your request with PujoRoute festival intelligence.",
    );
  }

  Pandal? _matchBestPandalFromSpokenQuery(String query) {
    final famousKeywords = {
      'sreebhumi': 'sreebhumi_sporting',
      'শ্রীভূমি': 'sreebhumi_sporting',
      'श्रीभूमि': 'sreebhumi_sporting',
      'ekdalia': 'ekdalia_evergreen',
      'একডালিয়া': 'ekdalia_evergreen',
      'एकडालिया': 'ekdalia_evergreen',
      'maddox': 'maddox_square',
      'ম্যাডক্স': 'maddox_square',
      'मैडॉक्स': 'maddox_square',
      'singhi': 'singhi_park',
      'সিংহি': 'singhi_park',
      'सिंघी': 'singhi_park',
      'tridhara': 'tridhara_sammilani',
      'ত্রিধারা': 'tridhara_sammilani',
      'त्रिधारा': 'tridhara_sammilani',
      'college square': 'college_square',
      'কলেজ স্কোয়ার': 'college_square',
      'कॉलेज स्क्वायर': 'college_square',
      'suruchi': 'suruchi_sangha',
      'সুরুচি': 'suruchi_sangha',
      'सुरुचि': 'suruchi_sangha',
      'bagbazar': 'bagbazar_sarbojanin',
      'বাগবাজার': 'bagbazar_sarbojanin',
      'बागबाजार': 'bagbazar_sarbojanin',
      'naktala': 'naktala_udayan',
      'khelat': 'khelat_ghosh',
      'hathkhola': 'hathkhola_dutta',
      'sovabazar': 'sovabazar_beniatola',
      'ahiritola': 'ahiritola_sarbojanin',
      'behala': 'behala_club',
    };

    for (final entry in famousKeywords.entries) {
      if (query.contains(entry.key)) {
        return kAllKolkataPujas.firstWhere(
          (p) => p.id == entry.value,
          orElse: () => kAllKolkataPujas[0],
        );
      }
    }

    for (final p in kAllKolkataPujas) {
      final nameLower = p.name.toLowerCase();
      final tokens = nameLower.split(' ').where((t) => t.length > 3).toList();
      int matches = 0;
      for (final t in tokens) {
        if (query.contains(t)) matches++;
      }
      if (matches >= 2 || (tokens.length == 1 && matches == 1)) {
        return p;
      }
    }

    return null;
  }
}
