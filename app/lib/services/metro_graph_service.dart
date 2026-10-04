import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/pujas_data.dart';

class InterchangeInfo {
  final String station;
  final List<String> connects;
  final String instructions;

  const InterchangeInfo({
    required this.station,
    required this.connects,
    required this.instructions,
  });
}

enum TransitRecommendation {
  walk, // Green: Close distance (< 1.3 km or 1-stop < 1.5 km)
  metroRecommended, // Blue: Meaningful distance on same line (saves time/effort)
  metroPossible, // Grey/Cyan: Transfer required or alternative auto/cab
}

/// Metadata about a single pandal's nearest metro station and walking distance
class PandalMetroInfo {
  final Pandal pandal;
  final String station;
  final String line;
  final String gate;
  final double distanceToMetroMeters;

  const PandalMetroInfo({
    required this.pandal,
    required this.station,
    required this.line,
    required this.gate,
    required this.distanceToMetroMeters,
  });
}

/// Practical, honest transit decision between two consecutive circuit pandals
class MetroHopGuidance {
  final int hopIndex;
  final Pandal fromPandal;
  final Pandal toPandal;
  final PandalMetroInfo fromInfo;
  final PandalMetroInfo toInfo;
  final double directWalkMeters;
  final int directWalkMinutes;
  final TransitRecommendation recommendation;
  final String recommendationLabel; // "Walk", "Metro Recommended", "Metro Possible"
  final String headline;
  final String detailedAdvice;
  final String? boardStation;
  final String? alightStation;
  final String? line;
  final String? direction;
  final int stationCount;
  final int estimatedMetroMinutes;
  final String? interchangeStation;
  final bool isInterchange;
  final int fareRupees;

  const MetroHopGuidance({
    required this.hopIndex,
    required this.fromPandal,
    required this.toPandal,
    required this.fromInfo,
    required this.toInfo,
    required this.directWalkMeters,
    required this.directWalkMinutes,
    required this.recommendation,
    required this.recommendationLabel,
    required this.headline,
    required this.detailedAdvice,
    this.boardStation,
    this.alightStation,
    this.line,
    this.direction,
    this.stationCount = 0,
    this.estimatedMetroMinutes = 0,
    this.interchangeStation,
    this.isInterchange = false,
    this.fareRupees = 0,
  });
}

/// Complete summary for the entire circuit
class MetroGuideSummary {
  final List<MetroHopGuidance> hops;
  final int walkCount;
  final int metroRecommendedCount;
  final int metroPossibleCount;
  final Set<String> linesTouched;

  const MetroGuideSummary({
    required this.hops,
    required this.walkCount,
    required this.metroRecommendedCount,
    required this.metroPossibleCount,
    required this.linesTouched,
  });
}

class MetroGraphService {
  static final MetroGraphService _instance = MetroGraphService._internal();
  factory MetroGraphService() => _instance;
  static MetroGraphService get instance => _instance;

  MetroGraphService._internal();

  bool _isLoaded = false;
  Map<String, List<String>> _lines = {};
  List<InterchangeInfo> _interchanges = [];
  Map<String, String> _forbiddenAliases = {};

  // Line 1: North-South Corridor (Dakshineswar - Kavi Subhash)
  static const List<String> kBlueLineStations = [
    'Dakshineswar',
    'Baranagar',
    'Noapara',
    'Dum Dum',
    'Belgachia',
    'Shyambazar',
    'Sovabazar Sutanuti',
    'Girish Park',
    'Mahatma Gandhi Road',
    'Central',
    'Chandni Chowk',
    'Esplanade',
    'Park Street',
    'Maidan',
    'Rabindra Sadan',
    'Netaji Bhavan',
    'Jatin Das Park',
    'Kalighat',
    'Rabindra Sarobar',
    'Mahanayak Uttam Kumar',
    'Netaji',
    'Masterda Surya Sen',
    'Gitanjali',
    'Kavi Nazrul',
    'Shahid Khudiram',
    'Kavi Subhash'
  ];

  // Line 2: East-West Corridor (Howrah Maidan - Salt Lake Sector V)
  static const List<String> kGreenLineStations = [
    'Howrah Maidan',
    'Howrah Railway Station',
    'Mahakaran',
    'Esplanade',
    'Sealdah',
    'Phoolbagan',
    'Salt Lake Stadium',
    'Bengal Chemical',
    'City Centre',
    'Central Park',
    'Karunamoyee',
    'Salt Lake Sector V'
  ];

  // Line 3: Purple Line (Joka - Majerhat)
  static const List<String> kPurpleLineStations = [
    'Joka',
    'Thakurpukur',
    'Sakher Bazar',
    'Behala Chowrasta',
    'Behala Bazar',
    'Taratala',
    'Majerhat',
  ];

  // Line 6: Orange Line (Kavi Subhash - Hemanta Mukhopadhyay / Ruby)
  static const List<String> kOrangeLineStations = [
    'Kavi Subhash',
    'Satyajit Ray',
    'Jyotirindra Nandi',
    'Kavi Sukanta',
    'Hemanta Mukhopadhyay',
  ];

  static const Map<String, String> kCanonicalAliases = {
    'shobhabazar sutanuti': 'Sovabazar Sutanuti',
    'shovabazar sutanuti': 'Sovabazar Sutanuti',
    'sovabazar': 'Sovabazar Sutanuti',
    'shobhabazar': 'Sovabazar Sutanuti',
    'belgachhia': 'Belgachia',
    'belgachia': 'Belgachia',
    'karunamayee': 'Karunamoyee',
    'karunamoyee': 'Karunamoyee',
    'salt lake sector-v': 'Salt Lake Sector V',
    'salt lake sector v': 'Salt Lake Sector V',
    'sector v': 'Salt Lake Sector V',
    'sector-v': 'Salt Lake Sector V',
    'mg road': 'Mahatma Gandhi Road',
    'mahatma gandhi road': 'Mahatma Gandhi Road',
    'ruby': 'Hemanta Mukhopadhyay',
    'hemanta mukhopadhyay': 'Hemanta Mukhopadhyay',
    'tollygunge': 'Mahanayak Uttam Kumar',
    'kudghat': 'Netaji',
    'bansdroni': 'Masterda Surya Sen',
    'naktala': 'Gitanjali',
    'garia bazar': 'Kavi Nazrul',
    'briji': 'Shahid Khudiram',
    'new garia': 'Kavi Subhash',
    'howrah': 'Howrah Railway Station',
  };

  static const Map<String, List<double>> kStationCoordinates = {
    'Dakshineswar': [22.6536, 88.3582],
    'Baranagar': [22.6394, 88.3683],
    'Noapara': [22.6247, 88.3842],
    'Dum Dum': [22.6217, 88.3934],
    'Belgachia': [22.6067, 88.3820],
    'Shyambazar': [22.6025, 88.3719],
    'Sovabazar Sutanuti': [22.5975, 88.3688],
    'Girish Park': [22.5866, 88.3639],
    'Mahatma Gandhi Road': [22.5796, 88.3598],
    'Central': [22.5694, 88.3586],
    'Chandni Chowk': [22.5661, 88.3556],
    'Esplanade': [22.5647, 88.3524],
    'Park Street': [22.5516, 88.3516],
    'Maidan': [22.5451, 88.3475],
    'Rabindra Sadan': [22.5375, 88.3444],
    'Netaji Bhavan': [22.5312, 88.3441],
    'Jatin Das Park': [22.5222, 88.3448],
    'Kalighat': [22.5178, 88.3468],
    'Rabindra Sarobar': [22.5085, 88.3467],
    'Mahanayak Uttam Kumar': [22.4988, 88.3458],
    'Netaji': [22.4892, 88.3452],
    'Masterda Surya Sen': [22.4776, 88.3442],
    'Gitanjali': [22.4697, 88.3436],
    'Kavi Nazrul': [22.4578, 88.3430],
    'Shahid Khudiram': [22.4485, 88.3432],
    'Kavi Subhash': [22.4414, 88.3976],
    'Howrah Maidan': [22.5855, 88.3283],
    'Howrah Railway Station': [22.5840, 88.3415],
    'Mahakaran': [22.5732, 88.3496],
    'Sealdah': [22.5670, 88.3712],
    'Phoolbagan': [22.5714, 88.3912],
    'Salt Lake Stadium': [22.5707, 88.4063],
    'Bengal Chemical': [22.5772, 88.4076],
    'City Centre': [22.5878, 88.4116],
    'Central Park': [22.5888, 88.4208],
    'Karunamoyee': [22.5855, 88.4162],
    'Salt Lake Sector V': [22.5804, 88.4357],
    'Majerhat': [22.5186, 88.3228],
    'Taratala': [22.5074, 88.3188],
    'Behala Bazar': [22.4988, 88.3180],
    'Behala Chowrasta': [22.4905, 88.3142],
    'Sakher Bazar': [22.4819, 88.3115],
    'Thakurpukur': [22.4632, 88.3078],
    'Joka': [22.4520, 88.3040],
    'Hemanta Mukhopadhyay': [22.5133, 88.4005],
    'Kavi Sukanta': [22.5020, 88.3980],
    'Jyotirindra Nandi': [22.4920, 88.3970],
    'Satyajit Ray': [22.4700, 88.3970],
  };

  /// Initialize and load static topology graph
  Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/metro_graph.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      _parseGraphData(data);
      _isLoaded = true;
    } catch (e) {
      debugPrint(
          "MetroGraphService loading notice (using in-memory fallback): $e");
      _loadFallbackData();
      _isLoaded = true;
    }
  }

  void _loadFallbackData() {
    _lines = {
      'blue': List.from(kBlueLineStations),
      'green': List.from(kGreenLineStations),
      'purple': List.from(kPurpleLineStations),
      'orange': List.from(kOrangeLineStations),
    };
    _interchanges = [
      const InterchangeInfo(
        station: 'Esplanade',
        connects: ['blue', 'green'],
        instructions:
            'Follow designated interchange concourse at Esplanade to transfer between Blue Line and Green Line platforms.',
      ),
      const InterchangeInfo(
        station: 'Kavi Subhash',
        connects: ['blue', 'orange'],
        instructions:
            'Direct concourse interchange at Kavi Subhash (New Garia) connecting Blue Line and Orange Line (EM Bypass).',
      ),
      const InterchangeInfo(
        station: 'Majerhat',
        connects: ['purple', 'blue'],
        instructions:
            'Take short road/auto connection (8-10 mins) between Majerhat/Taratala and Kalighat / Rabindra Sarobar (Blue Line).',
      ),
    ];
    _forbiddenAliases = {
      'bagbazar': 'Shyambazar or Sovabazar Sutanuti',
      'lake town': 'Belgachia or Karunamoyee plus appropriate onward transport',
      'gariahat': 'Kalighat or another verified appropriate connection',
    };
  }

  void _parseGraphData(Map<String, dynamic> data) {
    final linesMap = data['lines'] as Map<String, dynamic>? ?? {};
    _lines = {};
    linesMap.forEach((key, val) {
      final stations = (val['stations'] as List?)?.cast<String>() ?? [];
      _lines[key] = stations;
    });

    if (!_lines.containsKey('purple')) {
      _lines['purple'] = List.from(kPurpleLineStations);
    }
    if (!_lines.containsKey('orange')) {
      _lines['orange'] = List.from(kOrangeLineStations);
    }

    final interchangesList = data['interchanges'] as List? ?? [];
    _interchanges = interchangesList.map((item) {
      final m = item as Map<String, dynamic>;
      return InterchangeInfo(
        station: m['station'] ?? 'Esplanade',
        connects:
            (m['connects'] as List?)?.cast<String>() ?? ['blue', 'green'],
        instructions: m['instructions'] ?? '',
      );
    }).toList();

    final aliasesMap = data['forbidden_aliases'] as Map<String, dynamic>? ?? {};
    _forbiddenAliases = {};
    aliasesMap.forEach((key, val) {
      _forbiddenAliases[key.toLowerCase()] = val.toString();
    });
  }

  /// Verifies if a given station name exists in the official topology
  bool hasStation(String stationName) {
    if (!_isLoaded) _loadFallbackData();
    final nameLower = stationName.trim().toLowerCase();
    for (final list in _lines.values) {
      if (list.any((s) => s.toLowerCase() == nameLower)) return true;
    }
    return false;
  }

  /// Gets the canonical station name if matched or fuzzy-matched
  String? getCanonicalStation(String stationName) {
    if (!_isLoaded) _loadFallbackData();
    final nameLower = stationName.trim().toLowerCase();

    // 0. Known aliases lookup
    if (kCanonicalAliases.containsKey(nameLower)) {
      return kCanonicalAliases[nameLower];
    }

    // 1. Exact match (highest priority)
    for (final list in _lines.values) {
      for (final s in list) {
        if (s.toLowerCase() == nameLower) return s;
      }
    }

    // 2. Substring match (longest match wins to prevent "Howrah Maidan" matching "Maidan")
    String? bestMatch;
    int bestLength = 0;
    for (final list in _lines.values) {
      for (final s in list) {
        final sLower = s.toLowerCase();
        if (sLower.contains(nameLower) || nameLower.contains(sLower)) {
          if (s.length > bestLength) {
            bestMatch = s;
            bestLength = s.length;
          }
        }
      }
    }
    return bestMatch;
  }

  /// Retrieves the Metro Line for a given station
  String? getLineForStation(String stationName) {
    if (!_isLoaded) _loadFallbackData();
    final canonical = getCanonicalStation(stationName);
    if (canonical == null) return null;

    final canonicalLower = canonical.toLowerCase();
    if (_lines['blue']?.any((s) => s.toLowerCase() == canonicalLower) == true) {
      return 'Blue Line';
    }
    if (_lines['green']?.any((s) => s.toLowerCase() == canonicalLower) ==
        true) {
      return 'Green Line';
    }
    if (_lines['purple']?.any((s) => s.toLowerCase() == canonicalLower) ==
        true) {
      return 'Purple Line';
    }
    if (_lines['orange']?.any((s) => s.toLowerCase() == canonicalLower) ==
        true) {
      return 'Orange Line';
    }
    return null;
  }

  /// Checks if a transfer is valid between lineA and lineB
  InterchangeInfo? getInterchange(String lineA, String lineB) {
    if (!_isLoaded) _loadFallbackData();
    final a = lineA.toLowerCase().replaceAll(' line', '');
    final b = lineB.toLowerCase().replaceAll(' line', '');
    if (a == b) return null;

    for (final interchange in _interchanges) {
      if (interchange.connects.contains(a) &&
          interchange.connects.contains(b)) {
        return interchange;
      }
    }
    return null;
  }

  /// Checks forbidden alias warnings
  String? getForbiddenAliasWarning(String input) {
    if (!_isLoaded) _loadFallbackData();
    final inputLower = input.toLowerCase();
    for (final entry in _forbiddenAliases.entries) {
      if (inputLower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Validates whether a station belongs to a specified Metro line
  bool validateStationLine(String stationName, String expectedLine) {
    final actualLine = getLineForStation(stationName);
    if (actualLine == null) return false;
    return actualLine.toLowerCase().contains(expectedLine.toLowerCase()) ||
        expectedLine.toLowerCase().contains(actualLine.toLowerCase());
  }

  // -------------------------------------------------------------
  // ADVANCED TRANSIT ROUTING ENGINE FOR CIRCUIT STUDIO
  // -------------------------------------------------------------

  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Calculates fare based on station hop count following Kolkata Metro slabs
  int _calculateFare(int totalStations) {
    if (totalStations <= 2) return 5;
    if (totalStations <= 5) return 10;
    if (totalStations <= 9) return 15;
    if (totalStations <= 16) return 20;
    return 25;
  }

  /// Extracts basic nearest metro information for a pandal
  PandalMetroInfo getPandalMetroInfo(Pandal p) {
    final canonical =
        getCanonicalStation(p.metroStation) ?? p.metroStation.trim();
    final line = getLineForStation(canonical) ?? 'Blue Line';
    final coords = kStationCoordinates[canonical];
    double dist = 0.0;
    if (coords != null) {
      dist = _haversineMeters(p.lat, p.lon, coords[0], coords[1]);
    }
    return PandalMetroInfo(
      pandal: p,
      station: canonical,
      line: line,
      gate: p.detailedMetroGate,
      distanceToMetroMeters: dist,
    );
  }

  /// Evaluates and generates a simple, honest transit decision between two consecutive pandals
  MetroHopGuidance buildMetroHopGuidance({
    required int hopIndex,
    required Pandal fromP,
    required Pandal toP,
  }) {
    if (!_isLoaded) _loadFallbackData();

    final infoA = getPandalMetroInfo(fromP);
    final infoB = getPandalMetroInfo(toP);

    final walkDist = _haversineMeters(fromP.lat, fromP.lon, toP.lat, toP.lon);
    final walkMins = max(2, (walkDist / 75.0).round());
    final walkKm = (walkDist / 1000.0).toStringAsFixed(1);

    final sameStation =
        infoA.station.toLowerCase() == infoB.station.toLowerCase();

    // 1. Core Rule: Direct walk if distance < 1.3 km (or same station)
    if (walkDist < 1300 || sameStation) {
      final reason = sameStation
          ? 'Both pandals are near ${infoA.station} (~${walkDist.round()} m apart).'
          : 'Direct walk is only $walkKm km (~$walkMins mins).';
      return MetroHopGuidance(
        hopIndex: hopIndex,
        fromPandal: fromP,
        toPandal: toP,
        fromInfo: infoA,
        toInfo: infoB,
        directWalkMeters: walkDist,
        directWalkMinutes: walkMins,
        recommendation: TransitRecommendation.walk,
        recommendationLabel: 'Walk',
        headline: '🚶 Recommend Walk ($walkKm km)',
        detailedAdvice:
            '$reason Walking directly through festival streets avoids ticket queues, security checks, and platform stairs.',
      );
    }

    // 2. Both pandals on the same metro line
    if (infoA.line == infoB.line) {
      final lineList = _getLineList(infoA.line);
      final idxA = _findStationIndex(lineList, infoA.station);
      final idxB = _findStationIndex(lineList, infoB.station);

      if (idxA != -1 && idxB != -1) {
        final stationHops = (idxB - idxA).abs();

        // Safety Rule: 1 station hop under 1.8 km -> prefer walking!
        if (stationHops == 1 && walkDist < 1800) {
          return MetroHopGuidance(
            hopIndex: hopIndex,
            fromPandal: fromP,
            toPandal: toP,
            fromInfo: infoA,
            toInfo: infoB,
            directWalkMeters: walkDist,
            directWalkMinutes: walkMins,
            recommendation: TransitRecommendation.walk,
            recommendationLabel: 'Walk',
            headline: '🚶 Recommend Walk ($walkKm km)',
            detailedAdvice:
                'Only 1 station away (${infoA.station} ➔ ${infoB.station}). Station entry, security lines, and platform wait will take longer than walking directly.',
          );
        }

        // Meaningful distance on same line -> Metro Recommended
        final direction = _calculateDirection(infoA.line, idxA, idxB);
        final trainMins = stationHops * 2 + 3;
        final fare = _calculateFare(stationHops);

        final lastMileA = infoA.distanceToMetroMeters > 0
            ? 'Walk ~${infoA.distanceToMetroMeters.round()} m to ${infoA.station}'
            : 'Access ${infoA.station}';
        final lastMileB = infoB.distanceToMetroMeters > 0
            ? 'Walk ~${infoB.distanceToMetroMeters.round()} m from ${infoB.station} to ${toP.name}'
            : 'Exit to ${toP.name}';

        return MetroHopGuidance(
          hopIndex: hopIndex,
          fromPandal: fromP,
          toPandal: toP,
          fromInfo: infoA,
          toInfo: infoB,
          directWalkMeters: walkDist,
          directWalkMinutes: walkMins,
          recommendation: TransitRecommendation.metroRecommended,
          recommendationLabel: 'Metro Recommended',
          headline:
              '🚇 Metro Recommended ($stationHops stops, ~$trainMins mins)',
          detailedAdvice:
              '$lastMileA ➔ Board ${infoA.line} ($direction) ➔ Ride $stationHops stops to ${infoB.station} ➔ $lastMileB.',
          boardStation: infoA.station,
          alightStation: infoB.station,
          line: infoA.line,
          direction: direction,
          stationCount: stationHops,
          estimatedMetroMinutes: trainMins,
          fareRupees: fare,
        );
      }
    }

    // 3. Different Lines: Check interchange
    // Blue <-> Green Interchange via Esplanade
    if ((infoA.line == 'Blue Line' && infoB.line == 'Green Line') ||
        (infoA.line == 'Green Line' && infoB.line == 'Blue Line')) {
      const blueList = kBlueLineStations;
      const greenList = kGreenLineStations;
      final isBlueFirst = infoA.line == 'Blue Line';

      final blueStation = isBlueFirst ? infoA.station : infoB.station;
      final greenStation = isBlueFirst ? infoB.station : infoA.station;

      final idxBlue = _findStationIndex(blueList, blueStation);
      final idxGreen = _findStationIndex(greenList, greenStation);
      final idxBlueEsp = blueList.indexOf('Esplanade');
      final idxGreenEsp = greenList.indexOf('Esplanade');

      final stops1 = isBlueFirst
          ? (idxBlue - idxBlueEsp).abs()
          : (idxGreen - idxGreenEsp).abs();
      final stops2 = isBlueFirst
          ? (idxGreen - idxGreenEsp).abs()
          : (idxBlue - idxBlueEsp).abs();
      final totalStops = stops1 + stops2;
      final totalMins = (totalStops * 2) + 7;
      final fare = _calculateFare(totalStops);

      final isRiverTunnel = (idxGreen <= 2);

      return MetroHopGuidance(
        hopIndex: hopIndex,
        fromPandal: fromP,
        toPandal: toP,
        fromInfo: infoA,
        toInfo: infoB,
        directWalkMeters: walkDist,
        directWalkMinutes: walkMins,
        recommendation: TransitRecommendation.metroPossible,
        recommendationLabel: 'Metro Possible',
        headline: '🔄 Metro Transfer at Esplanade ($totalStops stops)',
        detailedAdvice:
            'Board ${infoA.line} at ${infoA.station} to Esplanade ($stops1 stops) ➔ Transfer concourse ➔ ${infoB.line} to ${infoB.station} ($stops2 stops).${isRiverTunnel ? ' 🌊 River tunnel active.' : ''} (Tip: If hailing a cab/auto is convenient, compare road traffic).',
        boardStation: infoA.station,
        alightStation: infoB.station,
        line: '${infoA.line} ➔ ${infoB.line}',
        direction: 'Via Esplanade Interchange',
        stationCount: totalStops,
        estimatedMetroMinutes: totalMins,
        interchangeStation: 'Esplanade',
        isInterchange: true,
        fareRupees: fare,
      );
    }

    // Blue <-> Orange Interchange via Kavi Subhash
    if ((infoA.line == 'Blue Line' && infoB.line == 'Orange Line') ||
        (infoA.line == 'Orange Line' && infoB.line == 'Blue Line')) {
      const blueList = kBlueLineStations;
      const orangeList = kOrangeLineStations;
      final isBlueFirst = infoA.line == 'Blue Line';

      final blueStation = isBlueFirst ? infoA.station : infoB.station;
      final orangeStation = isBlueFirst ? infoB.station : infoA.station;

      final idxBlue = _findStationIndex(blueList, blueStation);
      final idxOrange = _findStationIndex(orangeList, orangeStation);
      final idxBlueKS = blueList.indexOf('Kavi Subhash');
      final idxOrangeKS = orangeList.indexOf('Kavi Subhash');

      final stops1 = isBlueFirst
          ? (idxBlue - idxBlueKS).abs()
          : (idxOrange - idxOrangeKS).abs();
      final stops2 = isBlueFirst
          ? (idxOrange - idxOrangeKS).abs()
          : (idxBlue - idxBlueKS).abs();
      final totalStops = stops1 + stops2;
      final totalMins = (totalStops * 2) + 6;
      final fare = _calculateFare(totalStops);

      return MetroHopGuidance(
        hopIndex: hopIndex,
        fromPandal: fromP,
        toPandal: toP,
        fromInfo: infoA,
        toInfo: infoB,
        directWalkMeters: walkDist,
        directWalkMinutes: walkMins,
        recommendation: TransitRecommendation.metroPossible,
        recommendationLabel: 'Metro Possible',
        headline: '🔄 Metro Transfer at Kavi Subhash ($totalStops stops)',
        detailedAdvice:
            'Board ${infoA.line} at ${infoA.station} to Kavi Subhash ($stops1 stops) ➔ Switch to ${infoB.line} platform ➔ Alight at ${infoB.station} ($stops2 stops).',
        boardStation: infoA.station,
        alightStation: infoB.station,
        line: '${infoA.line} ➔ ${infoB.line}',
        direction: 'Via Kavi Subhash Interchange',
        stationCount: totalStops,
        estimatedMetroMinutes: totalMins,
        interchangeStation: 'Kavi Subhash',
        isInterchange: true,
        fareRupees: fare,
      );
    }

    // Other multi-line combinations (e.g. Purple Line to Blue/Green)
    return MetroHopGuidance(
      hopIndex: hopIndex,
      fromPandal: fromP,
      toPandal: toP,
      fromInfo: infoA,
      toInfo: infoB,
      directWalkMeters: walkDist,
      directWalkMinutes: walkMins,
      recommendation: TransitRecommendation.metroPossible,
      recommendationLabel: 'Metro + Auto',
      headline: '🚕 Shared Auto / Metro Recommended ($walkKm km)',
      detailedAdvice:
          'Cross-corridor connection between ${infoA.station} (${infoA.line}) and ${infoB.station} (${infoB.line}). Take shared auto/cab or Metro with road link.',
    );
  }

  /// Builds a complete circuit metro guide summary
  MetroGuideSummary buildCircuitMetroGuide(List<Pandal> stops) {
    if (stops.length < 2) {
      return const MetroGuideSummary(
        hops: [],
        walkCount: 0,
        metroRecommendedCount: 0,
        metroPossibleCount: 0,
        linesTouched: {},
      );
    }

    final hops = <MetroHopGuidance>[];
    int walkCount = 0;
    int metroRecCount = 0;
    int metroPossCount = 0;
    final lines = <String>{};

    for (int i = 1; i < stops.length; i++) {
      final guidance = buildMetroHopGuidance(
        hopIndex: i,
        fromP: stops[i - 1],
        toP: stops[i],
      );
      hops.add(guidance);
      if (guidance.recommendation == TransitRecommendation.walk) {
        walkCount++;
      } else if (guidance.recommendation ==
          TransitRecommendation.metroRecommended) {
        metroRecCount++;
        if (guidance.line != null) lines.add(guidance.line!);
      } else {
        metroPossCount++;
        if (guidance.line != null) lines.add(guidance.line!);
      }
    }

    return MetroGuideSummary(
      hops: hops,
      walkCount: walkCount,
      metroRecommendedCount: metroRecCount,
      metroPossibleCount: metroPossCount,
      linesTouched: lines,
    );
  }

  List<String> _getLineList(String lineName) {
    final lower = lineName.toLowerCase();
    if (lower.contains('green')) return kGreenLineStations;
    if (lower.contains('purple')) return kPurpleLineStations;
    if (lower.contains('orange')) return kOrangeLineStations;
    return kBlueLineStations;
  }

  int _findStationIndex(List<String> list, String station) {
    final canonical = getCanonicalStation(station)?.toLowerCase() ??
        station.toLowerCase();
    for (int i = 0; i < list.length; i++) {
      if (list[i].toLowerCase() == canonical) return i;
    }
    for (int i = 0; i < list.length; i++) {
      if (list[i].toLowerCase().contains(canonical) ||
          canonical.contains(list[i].toLowerCase())) {
        return i;
      }
    }
    return -1;
  }

  String _calculateDirection(String line, int fromIdx, int toIdx) {
    final isForward = toIdx > fromIdx;
    final lower = line.toLowerCase();
    if (lower.contains('blue')) {
      return isForward
          ? 'Southbound (towards Kavi Subhash)'
          : 'Northbound (towards Dakshineswar)';
    }
    if (lower.contains('green')) {
      return isForward
          ? 'Eastbound (towards Salt Lake Sector-V)'
          : 'Westbound (towards Howrah Maidan)';
    }
    if (lower.contains('purple')) {
      return isForward
          ? 'Northbound (towards Majerhat)'
          : 'Southbound (towards Joka / Thakurpukur)';
    }
    if (lower.contains('orange')) {
      return isForward
          ? 'Northbound (towards Hemanta Mukhopadhyay / Ruby)'
          : 'Southbound (towards Kavi Subhash)';
    }
    return 'Inbound Service';
  }
}
