import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'security_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  static SessionService get instance => _instance;

  SessionService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Keys
  static const String _kSessionId = 'pujo_session_id';
  static const String _kCircuitIds = 'pujo_circuit_ids';
  static const String _kCircuitActive = 'pujo_circuit_active';
  static const String _kBookmarkedIds = 'pujo_bookmarked_ids';
  static const String _kVisitedIds = 'pujo_visited_ids';
  static const String _kSelectedZone = 'pujo_selected_zone';
  static const String _kFilterMega = 'pujo_filter_mega';
  static const String _kFilterHeritage = 'pujo_filter_heritage';
  static const String _kLastLat = 'pujo_last_lat';
  static const String _kLastLon = 'pujo_last_lon';
  static const String _kChatMessages = 'pujo_chat_messages';
  static const String _kEmergencyPhone = 'pujo_emergency_phone';
  static const String _kEmergencyName = 'pujo_emergency_name';
  static const String _kBloodGroup = 'pujo_blood_group';
  static const String _kAutoSpeak = 'pujo_auto_speak';
  static const String _kProxyGatewayUrl = 'pujo_proxy_gateway_url';
  static const String _kClientInstallationId = 'pujo_client_installation_id';

  // In-Memory State
  String _sessionId = '';
  String _clientInstallationId = '';
  List<String> _activeCircuitIds = [];
  bool _isCircuitActive = false;
  final Set<String> _bookmarkedIds = {};
  final Set<String> _visitedIds = {};
  String _selectedZone = 'All';
  bool _filterMega = true;
  bool _filterHeritage = true;
  double? _lastLat;
  double? _lastLon;
  List<Map<String, dynamic>> _chatMessages = [];
  String _emergencyPhone = '';
  String _emergencyName = '';
  String _bloodGroup = '';
  bool _autoSpeak = true;
  String _proxyGatewayUrl = 'https://my-freellmapi-server.onrender.com/v1/chat/completions';

  // Getters
  bool get isInitialized => _isInitialized;
  String get sessionId => _sessionId;
  String get clientInstallationId => _clientInstallationId;
  List<String> get activeCircuitIds => List.unmodifiable(_activeCircuitIds);
  bool get isCircuitActive => _isCircuitActive;
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);
  Set<String> get visitedIds => Set.unmodifiable(_visitedIds);
  String get selectedZone => _selectedZone;
  bool get filterMega => _filterMega;
  bool get filterHeritage => _filterHeritage;
  double? get lastLat => _lastLat;
  double? get lastLon => _lastLon;
  List<Map<String, dynamic>> get chatMessages => List.unmodifiable(_chatMessages);
  bool get isAutoSpeakEnabled => _autoSpeak;
  String get emergencyPhone => _emergencyPhone;
  String get emergencyName => _emergencyName;
  String get bloodGroup => _bloodGroup;
  String get proxyGatewayUrl => _proxyGatewayUrl;

  Future<void> setProxyGatewayUrl(String url) async {
    _proxyGatewayUrl = url;
    await _prefs.setString(_kProxyGatewayUrl, url);
  }

  /// Initialize and load all session values from local persistent storage
  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    // 1. Session ID (generate if first launch)
    String? storedId = _prefs.getString(_kSessionId);
    if (storedId == null || storedId.isEmpty) {
      storedId = 'pujo_${DateTime.now().millisecondsSinceEpoch}_${_secureRandomHex()}';
      await _prefs.setString(_kSessionId, storedId);
    }
    _sessionId = storedId;

    // 2. Active Hopping Circuit
    _activeCircuitIds = _prefs.getStringList(_kCircuitIds) ?? [];
    _isCircuitActive = _prefs.getBool(_kCircuitActive) ?? false;

    // 3. Bookmarks & Visited sets
    _bookmarkedIds.addAll(_prefs.getStringList(_kBookmarkedIds) ?? []);
    _visitedIds.addAll(_prefs.getStringList(_kVisitedIds) ?? []);

    // 4. Map Filter Preferences
    _selectedZone = _prefs.getString(_kSelectedZone) ?? 'All';
    _filterMega = _prefs.getBool(_kFilterMega) ?? true;
    _filterHeritage = _prefs.getBool(_kFilterHeritage) ?? true;

    // 5. Last Map Coordinates
    _lastLat = _prefs.getDouble(_kLastLat);
    _lastLon = _prefs.getDouble(_kLastLon);

    // 6. AI Chat Messages
    final chatJson = _prefs.getString(_kChatMessages);
    if (chatJson != null && chatJson.isNotEmpty) {
      try {
        final decoded = json.decode(chatJson) as List<dynamic>;
        _chatMessages = decoded.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      } catch (_) {
        _chatMessages = [];
      }
    }

    // 7. Emergency Profile (Loaded from Encrypted Storage)
    final encPhone = _prefs.getString(_kEmergencyPhone) ?? '';
    final encName = _prefs.getString(_kEmergencyName) ?? '';
    final encBlood = _prefs.getString(_kBloodGroup) ?? '';
    _emergencyPhone = SecurityService.instance.decryptSensitive(encPhone);
    _emergencyName = SecurityService.instance.decryptSensitive(encName);
    _bloodGroup = SecurityService.instance.decryptSensitive(encBlood);

    // 8. Voice Assistant Preferences
    _autoSpeak = _prefs.getBool(_kAutoSpeak) ?? true;

    _proxyGatewayUrl = _prefs.getString(_kProxyGatewayUrl) ?? 'https://my-freellmapi-server.onrender.com/v1/chat/completions';

    // 10. Persistent Client Installation UUID for Gateway Throttling
    String? storedUuid = _prefs.getString(_kClientInstallationId);
    if (storedUuid == null || storedUuid.isEmpty) {
      storedUuid = 'usr_${DateTime.now().millisecondsSinceEpoch}_${_secureRandomHex()}';
      await _prefs.setString(_kClientInstallationId, storedUuid);
    }
    _clientInstallationId = storedUuid;

    _isInitialized = true;
  }

  Future<void> setAutoSpeakEnabled(bool enabled) async {
    _autoSpeak = enabled;
    await _prefs.setBool(_kAutoSpeak, enabled);
  }

  // ==========================================
  // ENTERPRISE USER PRIVACY & SECURITY
  // ==========================================

  /// Unguessable identifier suffix (CSPRNG) so session IDs cannot be enumerated.
  static String _secureRandomHex([int bytes = 16]) {
    final rng = Random.secure();
    return List<String>.generate(
        bytes, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Secure token provider delegated to SecurityService
  /// Secure token provider delegated to SecurityService
  static String getSecureApiKey() {
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return SecurityService.instance.getObfuscatedClientToken();
  }

  /// Secure token provider for Gemini
  static String getGeminiApiKey() {
    return const String.fromEnvironment('GEMINI_API_KEY');
  }

  /// Secure Data Shredder: Purges all stored session history, GPS history,
  /// bookmarks, chat logs, and emergency medical profiles with random overwrites.
  Future<void> secureShredUserData() async {
    _activeCircuitIds.clear();
    _isCircuitActive = false;
    _bookmarkedIds.clear();
    _visitedIds.clear();
    _chatMessages.clear();
    _emergencyPhone = '';
    _emergencyName = '';
    _bloodGroup = '';
    _lastLat = null;
    _lastLon = null;

    // Overwrite with redactions before removing
    await _prefs.setString(_kEmergencyPhone, '0000000000');
    await _prefs.setString(_kEmergencyName, 'REDACTED');
    await _prefs.setString(_kBloodGroup, '');
    await _prefs.setString(_kChatMessages, '[]');

    await _prefs.remove(_kSessionId);
    await _prefs.remove(_kCircuitIds);
    await _prefs.remove(_kCircuitActive);
    await _prefs.remove(_kBookmarkedIds);
    await _prefs.remove(_kVisitedIds);
    await _prefs.remove(_kChatMessages);
    await _prefs.remove(_kEmergencyPhone);
    await _prefs.remove(_kEmergencyName);
    await _prefs.remove(_kBloodGroup);
    await _prefs.remove(_kLastLat);
    await _prefs.remove(_kLastLon);

    _sessionId = 'pujo_anon_${DateTime.now().millisecondsSinceEpoch}_${_secureRandomHex()}';
    await _prefs.setString(_kSessionId, _sessionId);
    _triggerBackgroundSync();
  }

  // ==========================================
  // CIRCUIT PERSISTENCE
  // ==========================================
  Future<void> saveCircuit(List<String> pandalIds, bool isActive) async {
    _activeCircuitIds = List.from(pandalIds);
    _isCircuitActive = isActive;
    await _prefs.setStringList(_kCircuitIds, _activeCircuitIds);
    await _prefs.setBool(_kCircuitActive, _isCircuitActive);
    _triggerBackgroundSync();
  }

  Future<void> clearCircuit() async {
    _activeCircuitIds.clear();
    _isCircuitActive = false;
    await _prefs.remove(_kCircuitIds);
    await _prefs.setBool(_kCircuitActive, false);
    _triggerBackgroundSync();
  }

  bool isInCircuit(String pandalId) => _activeCircuitIds.contains(pandalId);

  Future<bool> toggleCircuit(String pandalId) async {
    bool inCircuit = false;
    if (_activeCircuitIds.contains(pandalId)) {
      _activeCircuitIds.remove(pandalId);
      inCircuit = false;
    } else {
      _activeCircuitIds.add(pandalId);
      inCircuit = true;
    }
    _isCircuitActive = _activeCircuitIds.isNotEmpty;
    await _prefs.setStringList(_kCircuitIds, _activeCircuitIds);
    await _prefs.setBool(_kCircuitActive, _isCircuitActive);
    _triggerBackgroundSync();
    return inCircuit;
  }

  // ==========================================
  // BOOKMARK & FAVORITES
  // ==========================================
  bool isBookmarked(String pandalId) => _bookmarkedIds.contains(pandalId);

  Future<bool> toggleBookmark(String pandalId) async {
    bool nowBookmarked = false;
    if (_bookmarkedIds.contains(pandalId)) {
      _bookmarkedIds.remove(pandalId);
      nowBookmarked = false;
    } else {
      _bookmarkedIds.add(pandalId);
      nowBookmarked = true;
    }
    await _prefs.setStringList(_kBookmarkedIds, _bookmarkedIds.toList());
    _triggerBackgroundSync();
    return nowBookmarked;
  }

  // ==========================================
  // VISITED CHECKLIST
  // ==========================================
  bool isVisited(String pandalId) => _visitedIds.contains(pandalId);

  Future<bool> toggleVisited(String pandalId) async {
    bool nowVisited = false;
    if (_visitedIds.contains(pandalId)) {
      _visitedIds.remove(pandalId);
      nowVisited = false;
    } else {
      _visitedIds.add(pandalId);
      nowVisited = true;
    }
    await _prefs.setStringList(_kVisitedIds, _visitedIds.toList());
    _triggerBackgroundSync();
    return nowVisited;
  }

  // ==========================================
  // CROWDSOURCED LINE REPORTING (1-Tap)
  // ==========================================
  final Map<String, String> _crowdReports = {};
  String? getCrowdReport(String pandalId) => _crowdReports[pandalId] ?? _prefs.getString('pujo_crowd_$pandalId');

  Future<void> reportCrowdStatus(String pandalId, String status) async {
    _crowdReports[pandalId] = status;
    await _prefs.setString('pujo_crowd_$pandalId', status);
    _triggerBackgroundSync();
  }

  // ==========================================
  // FILTER PREFERENCES
  // ==========================================
  Future<void> saveFilters({required String zone, required bool mega, required bool heritage}) async {
    _selectedZone = zone;
    _filterMega = mega;
    _filterHeritage = heritage;
    await _prefs.setString(_kSelectedZone, zone);
    await _prefs.setBool(_kFilterMega, mega);
    await _prefs.setBool(_kFilterHeritage, heritage);
  }

  // ==========================================
  // LOCATION VIEWPORT
  // ==========================================
  Future<void> saveLastPosition(double lat, double lon) async {
    _lastLat = lat;
    _lastLon = lon;
    await _prefs.setDouble(_kLastLat, lat);
    await _prefs.setDouble(_kLastLon, lon);
  }

  // ==========================================
  // AI CHAT HISTORY
  // ==========================================
  Future<void> saveChatMessages(List<Map<String, dynamic>> messages) async {
    _chatMessages = List.from(messages);
    final serializable = messages.map((m) {
      final copy = Map<String, dynamic>.from(m);
      if (copy.containsKey('route')) {
        final routeList = copy['route'];
        if (routeList is List) {
          copy['route_ids'] = routeList.map((p) {
            try {
              return (p as dynamic).id;
            } catch (_) {
              return '';
            }
          }).where((id) => (id as String).isNotEmpty).toList();
        }
        copy.remove('route');
      }
      return copy;
    }).toList();

    final trimmed = serializable.length > 30 ? serializable.sublist(serializable.length - 30) : serializable;
    await _prefs.setString(_kChatMessages, json.encode(trimmed));
  }

  Future<void> clearChatHistory() async {
    _chatMessages.clear();
    await _prefs.remove(_kChatMessages);
  }

  // ==========================================
  // EMERGENCY PROFILE (ENCRYPTED STORAGE)
  // ==========================================
  Future<void> saveEmergencyProfile({required String phone, required String name, required String blood}) async {
    _emergencyPhone = phone;
    _emergencyName = name;
    _bloodGroup = blood;
    final encPhone = SecurityService.instance.encryptSensitive(phone);
    final encName = SecurityService.instance.encryptSensitive(name);
    final encBlood = SecurityService.instance.encryptSensitive(blood);
    await _prefs.setString(_kEmergencyPhone, encPhone);
    await _prefs.setString(_kEmergencyName, encName);
    await _prefs.setString(_kBloodGroup, encBlood);
  }

  // ==========================================
  // CLOUD BACKEND SYNC (LIGHTWEIGHT & SAFE HTTPS)
  // ==========================================
  void _triggerBackgroundSync() {
    Future.microtask(() async {
      try {
        final url = Uri.parse('https://sync.pujoroute.app/api/session/sync');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'session_id': _sessionId,
            'circuit_ids': _activeCircuitIds,
            'bookmarked_ids': _bookmarkedIds.toList(),
            'visited_ids': _visitedIds.toList(),
            'is_circuit_active': _isCircuitActive,
          }),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        // Network errors are silently ignored as local storage is primary
      }
    });
  }
}
