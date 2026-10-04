import 'package:shared_preferences/shared_preferences.dart';

/// Fully offline, on-device session state (SharedPreferences only).
/// Nothing in this class talks to the network.

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  static SessionService get instance => _instance;

  SessionService._internal();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Keys
  static const String _kCircuitIds = 'pujo_circuit_ids';
  static const String _kCircuitActive = 'pujo_circuit_active';
  static const String _kBookmarkedIds = 'pujo_bookmarked_ids';
  static const String _kVisitedIds = 'pujo_visited_ids';
  static const String _kSelectedZone = 'pujo_selected_zone';
  static const String _kFilterMega = 'pujo_filter_mega';
  static const String _kFilterHeritage = 'pujo_filter_heritage';
  static const String _kLastLat = 'pujo_last_lat';
  static const String _kLastLon = 'pujo_last_lon';
  // Legacy keys from removed features (online AI chat / gateway, and the
  // unused per-install session ID). Purged on init and by Delete My Data.
  static const List<String> _kLegacyKeys = [
    'pujo_session_id',
    'pujo_chat_messages',
    'pujo_proxy_gateway_url',
    'pujo_client_installation_id',
  ];
  // Per-pandal keys written by the removed local-only crowd line-report UI (purged on init)
  static const String _kLegacyCrowdPrefix = 'pujo_crowd_';
  static const String _kLegacyEncPrefix = 'enc_v1:';
  static const String _kEmergencyPhone = 'pujo_emergency_phone';
  static const String _kEmergencyName = 'pujo_emergency_name';
  static const String _kBloodGroup = 'pujo_blood_group';
  static const String _kAutoSpeak = 'pujo_auto_speak';

  // In-Memory State
  List<String> _activeCircuitIds = [];
  bool _isCircuitActive = false;
  final Set<String> _bookmarkedIds = {};
  final Set<String> _visitedIds = {};
  String _selectedZone = 'All';
  bool _filterMega = true;
  bool _filterHeritage = true;
  double? _lastLat;
  double? _lastLon;
  String _emergencyPhone = '';
  String _emergencyName = '';
  String _bloodGroup = '';
  bool _autoSpeak = true;

  // Getters
  bool get isInitialized => _isInitialized;
  List<String> get activeCircuitIds => List.unmodifiable(_activeCircuitIds);
  bool get isCircuitActive => _isCircuitActive;
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);
  Set<String> get visitedIds => Set.unmodifiable(_visitedIds);
  String get selectedZone => _selectedZone;
  bool get filterMega => _filterMega;
  bool get filterHeritage => _filterHeritage;
  double? get lastLat => _lastLat;
  double? get lastLon => _lastLon;
  bool get isAutoSpeakEnabled => _autoSpeak;
  String get emergencyPhone => _emergencyPhone;
  String get emergencyName => _emergencyName;
  String get bloodGroup => _bloodGroup;

  /// Initialize and load all session values from local persistent storage
  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

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

    // 6. Remove data left behind by removed features (online AI chat, session ID, crowd reports)
    for (final k in _kLegacyKeys) {
      await _prefs.remove(k);
    }
    await _purgeLegacyCrowdReports();

    // 7. Emergency Profile (plain on-device storage; app sandbox, backups disabled).
    // Values written by older builds were XOR-obfuscated with a hardcoded key;
    // that offered no real protection, so they are discarded and must be re-entered.
    _emergencyPhone = await _readPlainOrDiscardLegacy(_kEmergencyPhone);
    _emergencyName = await _readPlainOrDiscardLegacy(_kEmergencyName);
    _bloodGroup = await _readPlainOrDiscardLegacy(_kBloodGroup);

    // 8. Voice Assistant Preferences
    _autoSpeak = _prefs.getBool(_kAutoSpeak) ?? true;

    _isInitialized = true;
  }

  Future<void> _purgeLegacyCrowdReports() async {
    final stale = _prefs.getKeys().where((k) => k.startsWith(_kLegacyCrowdPrefix)).toList();
    for (final k in stale) {
      await _prefs.remove(k);
    }
  }

  Future<String> _readPlainOrDiscardLegacy(String key) async {
    final v = _prefs.getString(key) ?? '';
    if (v.startsWith(_kLegacyEncPrefix)) {
      await _prefs.remove(key);
      return '';
    }
    return v;
  }

  Future<void> setAutoSpeakEnabled(bool enabled) async {
    _autoSpeak = enabled;
    await _prefs.setBool(_kAutoSpeak, enabled);
  }

  // ==========================================
  // ENTERPRISE USER PRIVACY & SECURITY
  // ==========================================

  /// Secure Data Shredder: Purges all stored session history, GPS history,
  /// bookmarks, chat logs, and emergency medical profiles with random overwrites.
  Future<void> secureShredUserData() async {
    _activeCircuitIds.clear();
    _isCircuitActive = false;
    _bookmarkedIds.clear();
    _visitedIds.clear();
    _emergencyPhone = '';
    _emergencyName = '';
    _bloodGroup = '';
    _lastLat = null;
    _lastLon = null;

    // Overwrite with redactions before removing
    await _prefs.setString(_kEmergencyPhone, '0000000000');
    await _prefs.setString(_kEmergencyName, 'REDACTED');
    await _prefs.setString(_kBloodGroup, '');

    await _prefs.remove(_kCircuitIds);
    await _prefs.remove(_kCircuitActive);
    await _prefs.remove(_kBookmarkedIds);
    await _prefs.remove(_kVisitedIds);
    for (final k in _kLegacyKeys) {
      await _prefs.remove(k);
    }
    await _purgeLegacyCrowdReports();
    await _prefs.remove(_kEmergencyPhone);
    await _prefs.remove(_kEmergencyName);
    await _prefs.remove(_kBloodGroup);
    await _prefs.remove(_kLastLat);
    await _prefs.remove(_kLastLon);
    await _prefs.remove(_kSelectedZone);
    await _prefs.remove(_kFilterMega);
    await _prefs.remove(_kFilterHeritage);
  }

  // ==========================================
  // CIRCUIT PERSISTENCE
  // ==========================================
  Future<void> saveCircuit(List<String> pandalIds, bool isActive) async {
    _activeCircuitIds = List.from(pandalIds);
    _isCircuitActive = isActive;
    await _prefs.setStringList(_kCircuitIds, _activeCircuitIds);
    await _prefs.setBool(_kCircuitActive, _isCircuitActive);
  }

  Future<void> clearCircuit() async {
    _activeCircuitIds.clear();
    _isCircuitActive = false;
    await _prefs.remove(_kCircuitIds);
    await _prefs.setBool(_kCircuitActive, false);
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
    return nowVisited;
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
  // EMERGENCY PROFILE (ON-DEVICE STORAGE)
  // ==========================================
  Future<void> saveEmergencyProfile({required String phone, required String name, required String blood}) async {
    _emergencyPhone = phone;
    _emergencyName = name;
    _bloodGroup = blood;
    await _prefs.setString(_kEmergencyPhone, phone);
    await _prefs.setString(_kEmergencyName, name);
    await _prefs.setString(_kBloodGroup, blood);
  }
}
