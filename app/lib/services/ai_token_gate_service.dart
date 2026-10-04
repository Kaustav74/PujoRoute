/// Client-side AI Surge Token Gate for AI Sathi (PujoRoute Durga Puja 2026).
/// Limits AI queries to 2 per 5-minute rolling window per device/session to prevent server surge overload.
class AiTokenGateService {
  static const int maxQueriesPerWindow = 2;
  static const Duration windowDuration = Duration(minutes: 5);

  final List<DateTime> _queryTimestamps = [];
  bool _isRequestInFlight = false;

  /// Singleton instance
  static final AiTokenGateService _instance = AiTokenGateService._internal();
  factory AiTokenGateService() => _instance;
  AiTokenGateService._internal();

  /// Whether a request is currently active/in-flight
  bool get isRequestInFlight => _isRequestInFlight;

  void setRequestInFlight(bool value) {
    _isRequestInFlight = value;
  }

  /// Remove timestamps older than the 5-minute rolling window
  void _pruneExpiredTimestamps() {
    final now = DateTime.now();
    _queryTimestamps.removeWhere(
        (timestamp) => now.difference(timestamp) >= windowDuration);
  }

  /// Number of queries used in the active 5-minute window
  int get activeQueryCount {
    _pruneExpiredTimestamps();
    return _queryTimestamps.length;
  }

  /// Number of remaining tokens (max 2)
  int get remainingTokens {
    _pruneExpiredTimestamps();
    final remaining = maxQueriesPerWindow - _queryTimestamps.length;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether user can make an AI query right now
  bool canMakeQuery() {
    _pruneExpiredTimestamps();
    return !_isRequestInFlight && _queryTimestamps.length < maxQueriesPerWindow;
  }

  /// Try to consume 1 token for an AI request. Returns true if successful.
  bool tryConsumeToken() {
    _pruneExpiredTimestamps();
    if (canMakeQuery()) {
      _queryTimestamps.add(DateTime.now());
      _isRequestInFlight = true;
      return true;
    }
    return false;
  }

  /// Signal request completed
  void releaseInFlight() {
    _isRequestInFlight = false;
  }

  /// Duration until the oldest token in the window expires and a new token becomes available
  Duration get timeUntilNextToken {
    _pruneExpiredTimestamps();
    if (_queryTimestamps.isEmpty || _queryTimestamps.length < maxQueriesPerWindow) {
      return Duration.zero;
    }
    final oldest = _queryTimestamps.first;
    final now = DateTime.now();
    final elapsed = now.difference(oldest);
    final remaining = windowDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Reset internal gate state (for tests or debug session reset)
  void reset() {
    _queryTimestamps.clear();
    _isRequestInFlight = false;
  }
}
