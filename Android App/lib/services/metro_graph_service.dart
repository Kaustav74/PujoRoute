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
  final String
      recommendationLabel; // "Walk", "Metro Recommended", "Metro Possible"
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

/// One single-line segment of a metro journey.
class MetroLeg {
  final String line;
  final String from;
  final String to;
  final int stops;
  final String direction;
  const MetroLeg({
    required this.line,
    required this.from,
    required this.to,
    required this.stops,
    required this.direction,
  });
}

/// Shortest metro journey between two stations over the real network.
class MetroPath {
  final List<String> stations;
  final List<MetroLeg> legs;
  final List<String> transfers;
  final List<String> roadLinks; // e.g. 'Shahid Khudiram ↔ Kavi Subhash'
  final int stops;
  final double trackMeters;
  const MetroPath({
    required this.stations,
    required this.legs,
    required this.transfers,
    required this.roadLinks,
    required this.stops,
    required this.trackMeters,
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

  // Line 1: North-South Corridor (Dakshineswar - Shahid Khudiram while Kavi Subhash is closed)
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
    // Kavi Subhash (New Garia) Blue Line platforms are CLOSED (pillar cracks,
    // services suspended 28 Jul 2025; reopening targeted for Jan 2027 per
    // News18, 21 Sep 2026 - unverified). Blue Line trains terminate at
    // Shahid Khudiram. Kavi Subhash stays open as the Orange Line terminus.
  ];

  /// Short road links (not rail interchanges) a traveller can walk or take an
  /// auto across. [station A, station B, approx. straight-line metres].
  static const List<List<Object>> kRoadLinks = [
    ['Shahid Khudiram', 'Kavi Subhash', 880],
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

  // Line 6: Orange Line (Kavi Subhash - Beleghata; extended 22 Aug 2025).
  // Beleghata - IT Centre (Sector V) is NOT open yet (trial runs from Oct 2026).
  static const List<String> kOrangeLineStations = [
    'Kavi Subhash',
    'Satyajit Ray',
    'Jyotirindra Nandi',
    'Kavi Sukanta',
    'Hemanta Mukhopadhyay',
    'VIP Bazar',
    'Ritwik Ghatak',
    'Barun Sengupta',
    'Beleghata',
  ];

  // Line 4: Yellow Line (Noapara - Jai Hind Bimanbandar / Airport; opened 22 Aug 2025)
  static const List<String> kYellowLineStations = [
    'Noapara',
    'Dum Dum Cantonment',
    'Jessore Road',
    'Jai Hind Bimanbandar',
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
    'howrah station': 'Howrah Railway Station',
    'jai hind': 'Jai Hind Bimanbandar',
    'airport': 'Jai Hind Bimanbandar',
    'metropolitan': 'Beleghata',
  };

  /// Station coordinates from OpenStreetMap (station nodes, osm_base 2026-10-04),
  /// operational status per Wikipedia "List of Kolkata Metro stations" (Oct 2026).
  static const Map<String, List<double>> kStationCoordinates = {
    'Dakshineswar': [22.6540, 88.3637],
    'Baranagar': [22.6531, 88.3806],
    'Noapara': [22.6398, 88.3941],
    'Dum Dum': [22.6211, 88.3929],
    'Belgachia': [22.6059, 88.3864],
    'Shyambazar': [22.6013, 88.3725],
    'Sovabazar Sutanuti': [22.5959, 88.3652],
    'Girish Park': [22.5871, 88.3629],
    'Mahatma Gandhi Road': [22.5809, 88.3613],
    'Central': [22.5725, 88.3587],
    'Chandni Chowk': [22.5670, 88.3542],
    'Esplanade': [22.5636, 88.3512],
    'Park Street': [22.5552, 88.3501],
    'Maidan': [22.5495, 88.3488],
    'Rabindra Sadan': [22.5415, 88.3474],
    'Netaji Bhavan': [22.5332, 88.3459],
    'Jatin Das Park': [22.5241, 88.3465],
    'Kalighat': [22.5169, 88.3458],
    'Rabindra Sarobar': [22.5072, 88.3455],
    'Mahanayak Uttam Kumar': [22.4948, 88.3451],
    'Netaji': [22.4810, 88.3460],
    'Masterda Surya Sen': [22.4734, 88.3609],
    'Gitanjali': [22.4695, 88.3700],
    'Kavi Nazrul': [22.4642, 88.3805],
    'Shahid Khudiram': [22.4660, 88.3915],
    'Kavi Subhash': [
      22.4711,
      88.3981
    ], // Orange Line station (OSM way/1364916357)
    'Howrah Maidan': [22.5839, 88.3340],
    'Howrah Railway Station': [22.5834, 88.3404],
    'Mahakaran': [22.5721, 88.3505],
    'Sealdah': [22.5666, 88.3698],
    'Phoolbagan': [22.5721, 88.3902],
    'Salt Lake Stadium': [22.5731, 88.4031],
    'Bengal Chemical': [22.5801, 88.4013],
    'City Centre': [22.5871, 88.4079],
    'Central Park': [22.5905, 88.4156],
    'Karunamoyee': [22.5864, 88.4215],
    'Salt Lake Sector V': [22.5809, 88.4291],
    'Joka': [22.4523, 88.3018],
    'Thakurpukur': [22.4644, 88.3075],
    'Sakher Bazar': [22.4748, 88.3100],
    'Behala Chowrasta': [22.4873, 88.3134],
    'Behala Bazar': [22.4988, 88.3174],
    'Taratala': [22.5077, 88.3204],
    'Majerhat': [22.5191, 88.3237],
    'Satyajit Ray': [22.4847, 88.3926],
    'Jyotirindra Nandi': [22.4956, 88.3984],
    'Kavi Sukanta': [22.5053, 88.4010],
    'Hemanta Mukhopadhyay': [22.5148, 88.4014],
    'VIP Bazar': [22.5247, 88.3962],
    'Ritwik Ghatak': [22.5330, 88.3964],
    'Barun Sengupta': [22.5438, 88.3993],
    'Beleghata': [22.5507, 88.4040],
    'Dum Dum Cantonment': [22.6376, 88.4122],
    'Jessore Road': [22.6393, 88.4298],
    'Jai Hind Bimanbandar': [22.6473, 88.4373],
  };

  /// Initialize and load static topology graph
  Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/metro_graph.json');
      // Strip a UTF-8 BOM if present: json.decode rejects it, which previously
      // made the bundled graph silently fall back to in-memory data.
      final clean = jsonString.startsWith('\uFEFF')
          ? jsonString.substring(1)
          : jsonString;
      final data = json.decode(clean) as Map<String, dynamic>;
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
      'yellow': List.from(kYellowLineStations),
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
            'No rail interchange right now: the Blue Line platforms at Kavi Subhash are closed and Blue Line trains end at Shahid Khudiram. Walk or take an auto (~1 km) between Shahid Khudiram (Blue) and Kavi Subhash (Orange).',
      ),
      const InterchangeInfo(
        station: 'Noapara',
        connects: ['blue', 'yellow'],
        instructions:
            'Noapara serves both Blue Line and Yellow Line (towards Jai Hind Bimanbandar / Airport); change platforms within the station.',
      ),
      const InterchangeInfo(
        station: 'Majerhat',
        connects: ['purple', 'blue'],
        instructions:
            'No direct rail interchange: take a short road/auto connection (8-10 mins) between Majerhat/Taratala and Kalighat / Rabindra Sarobar (Blue Line).',
      ),
    ];
    _forbiddenAliases = {
      'bagbazar': 'Shyambazar or Sovabazar Sutanuti',
      'lake town':
          'City Centre or Central Park (Green Line), Jessore Road (Yellow Line) or Belgachia (Blue Line), plus a short auto ride',
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
    if (!_lines.containsKey('yellow')) {
      _lines['yellow'] = List.from(kYellowLineStations);
    }

    final interchangesList = data['interchanges'] as List? ?? [];
    _interchanges = interchangesList.map((item) {
      final m = item as Map<String, dynamic>;
      return InterchangeInfo(
        station: m['station'] ?? 'Esplanade',
        connects: (m['connects'] as List?)?.cast<String>() ?? ['blue', 'green'],
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
    if (_lines['yellow']?.any((s) => s.toLowerCase() == canonicalLower) ==
        true) {
      return 'Yellow Line';
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

  // Planning constants for the walk-vs-metro decision (documented in
  // docs/ROUTING.md). Straight-line distances, walking at 75 m/min.
  static const double kWalkMetersPerMinute = 75.0;
  static const int kMinutesPerStop =
      2; // average Kolkata Metro inter-station run
  static const int kStationOverheadMinutes =
      10; // entry queue, security check, platform wait, exit (Puja crowds)
  static const int kTransferMinutes = 6; // change platforms at an interchange

  /// Shortest metro path between two stations over the real line topology.
  /// Transfers are only possible at stations that appear on both lines
  /// (Esplanade, Noapara). Kavi Subhash is Orange-only while its Blue Line
  /// platforms are closed; Blue <-> Orange goes via kRoadLinks. Majerhat
  /// (Purple) has NO rail link to the Blue Line, so Purple Line stations are
  /// unreachable from other lines.
  MetroPath? findMetroPath(String fromStation, String toStation) {
    if (!_isLoaded) _loadFallbackData();
    final from = getCanonicalStation(fromStation);
    final to = getCanonicalStation(toStation);
    if (from == null || to == null) return null;
    if (from == to) {
      return MetroPath(
          stations: [from],
          legs: const [],
          transfers: const [],
          roadLinks: const [],
          stops: 0,
          trackMeters: 0);
    }

    // Dijkstra over (line, station-index) nodes; cost in minutes.
    final lineKeys = _lines.keys.toList();
    String key(String line, int i) => '$line|$i';
    final dist = <String, int>{};
    final prev = <String, String>{};
    final queue = <String>[];
    for (final line in lineKeys) {
      final i = _lines[line]!.indexOf(from);
      if (i != -1) {
        dist[key(line, i)] = 0;
        queue.add(key(line, i));
      }
    }
    String? goal;
    while (queue.isNotEmpty) {
      queue.sort((x, y) => dist[x]!.compareTo(dist[y]!));
      final cur = queue.removeAt(0);
      final parts = cur.split('|');
      final line = parts[0];
      final idx = int.parse(parts[1]);
      final stations = _lines[line]!;
      if (stations[idx] == to) {
        goal = cur;
        break;
      }
      final neighbours = <MapEntry<String, int>>[];
      if (idx > 0) {
        neighbours.add(MapEntry(key(line, idx - 1), kMinutesPerStop));
      }
      if (idx < stations.length - 1) {
        neighbours.add(MapEntry(key(line, idx + 1), kMinutesPerStop));
      }
      for (final other in lineKeys) {
        if (other == line) continue;
        final j = _lines[other]!.indexOf(stations[idx]);
        if (j != -1) neighbours.add(MapEntry(key(other, j), kTransferMinutes));
      }
      // Road links (exit, walk/auto, re-enter): costed as a walk plus a
      // second station entry.
      for (final link in kRoadLinks) {
        final a = link[0] as String, b = link[1] as String;
        final metres = link[2] as int;
        final String? target =
            stations[idx] == a ? b : (stations[idx] == b ? a : null);
        if (target == null) continue;
        for (final other in lineKeys) {
          final j = _lines[other]!.indexOf(target);
          if (j != -1) {
            neighbours.add(MapEntry(
                key(other, j),
                (metres / kWalkMetersPerMinute).round() +
                    kStationOverheadMinutes));
          }
        }
      }
      for (final n in neighbours) {
        final nd = dist[cur]! + n.value;
        if (!dist.containsKey(n.key) || nd < dist[n.key]!) {
          dist[n.key] = nd;
          prev[n.key] = cur;
          if (!queue.contains(n.key)) queue.add(n.key);
        }
      }
    }
    if (goal == null) return null;

    // Reconstruct node chain.
    final chain = <String>[goal];
    while (prev.containsKey(chain.first)) {
      chain.insert(0, prev[chain.first]!);
    }
    final legs = <MetroLeg>[];
    final transfers = <String>[];
    final roadLinks = <String>[];
    final stationsOut = <String>[];
    int stops = 0;
    double track = 0;
    String? legLine;
    String? legStart;
    int legStartIdx = 0;
    int legStops = 0;
    String? lastStation;
    int lastIdx = 0;
    for (final node in chain) {
      final parts = node.split('|');
      final line = parts[0];
      final idx = int.parse(parts[1]);
      final st = _lines[line]![idx];
      if (legLine == null) {
        legLine = line;
        legStart = st;
        legStartIdx = idx;
      } else if (line != legLine) {
        // transfer at the same station, or a road link to another station
        if (st != lastStation) roadLinks.add('$lastStation ↔ $st');
        if (legStops > 0) {
          legs.add(MetroLeg(
              line: _lineDisplayName(legLine),
              from: legStart!,
              to: lastStation!,
              stops: legStops,
              direction: _calculateDirection(legLine, legStartIdx, lastIdx)));
        }
        if (st == lastStation) transfers.add(st);
        legLine = line;
        legStart = st;
        legStartIdx = idx;
        legStops = 0;
      } else {
        legStops++;
        stops++;
        final a = kStationCoordinates[lastStation];
        final b = kStationCoordinates[st];
        if (a != null && b != null) {
          track += _haversineMeters(a[0], a[1], b[0], b[1]);
        }
      }
      if (stationsOut.isEmpty || stationsOut.last != st) stationsOut.add(st);
      lastStation = st;
      lastIdx = idx;
    }
    if (legStops > 0) {
      legs.add(MetroLeg(
          line: _lineDisplayName(legLine!),
          from: legStart!,
          to: lastStation!,
          stops: legStops,
          direction: _calculateDirection(legLine, legStartIdx, lastIdx)));
    }
    return MetroPath(
        stations: stationsOut,
        legs: legs,
        transfers: transfers,
        roadLinks: roadLinks,
        stops: stops,
        trackMeters: track);
  }

  static String _lineDisplayName(String key) {
    final k = key.toLowerCase();
    return '${k[0].toUpperCase()}${k.substring(1)} Line';
  }

  /// Approximate single-journey token fare. Only the Blue Line (Line 1) and
  /// Green Line (Line 2) distance slabs are published in a form we can apply;
  /// for other lines and for interchange journeys we return 0 (not shown).
  int estimateFare(MetroPath path) {
    if (path.legs.length != 1) return 0;
    final km = path.trackMeters / 1000.0;
    final line = path.legs.first.line;
    if (line == 'Blue Line') {
      if (km <= 2) return 5;
      if (km <= 5) return 10;
      if (km <= 10) return 15;
      if (km <= 20) return 20;
      return 25;
    }
    if (line == 'Green Line') {
      if (km <= 2) return 5;
      if (km <= 5) return 10;
      if (km <= 10) return 20;
      return 30;
    }
    return 0;
  }

  /// Evaluates and generates a simple, honest transit decision between two
  /// consecutive pandals. Compares the direct walk with the full metro trip:
  /// walk to the boarding station + station overhead + ride + transfers +
  /// walk from the alighting station.
  MetroHopGuidance buildMetroHopGuidance({
    required int hopIndex,
    required Pandal fromP,
    required Pandal toP,
  }) {
    if (!_isLoaded) _loadFallbackData();

    final infoA = getPandalMetroInfo(fromP);
    final infoB = getPandalMetroInfo(toP);

    final walkDist = _haversineMeters(fromP.lat, fromP.lon, toP.lat, toP.lon);
    final walkMins = max(2, (walkDist / kWalkMetersPerMinute).round());
    final walkKm = (walkDist / 1000.0).toStringAsFixed(1);

    final sameStation =
        infoA.station.toLowerCase() == infoB.station.toLowerCase();

    MetroHopGuidance walk(String advice) => MetroHopGuidance(
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
          detailedAdvice: advice,
        );

    // 1. Short hop or same station: walk.
    if (walkDist < 1300 || sameStation) {
      final reason = sameStation
          ? 'Both pandals are near ${infoA.station} (~${walkDist.round()} m apart).'
          : 'Direct walk is only $walkKm km (~$walkMins mins).';
      return walk(
          '$reason Walking directly through festival streets avoids ticket queues, security checks, and platform stairs.');
    }

    // 2. Metro path over the real network (not offered when either pandal has
    // no open station within kNoMetroRadiusMeters).
    final tooFar = fromP.isMetroTooFar || toP.isMetroTooFar;
    final path = tooFar ? null : findMetroPath(infoA.station, infoB.station);
    if (path == null || path.stops == 0) {
      final purple = infoA.line == 'Purple Line' || infoB.line == 'Purple Line';
      final why = tooFar
          ? '${fromP.isMetroTooFar ? fromP.name : toP.name} has no Metro station within 2.5 km.'
          : purple
              ? 'The Purple Line (Joka–Majerhat) has no rail link to the other lines yet; Majerhat to the Blue Line is a road transfer.'
              : 'There is no metro connection between ${infoA.station} and ${infoB.station}.';
      return MetroHopGuidance(
        hopIndex: hopIndex,
        fromPandal: fromP,
        toPandal: toP,
        fromInfo: infoA,
        toInfo: infoB,
        directWalkMeters: walkDist,
        directWalkMinutes: walkMins,
        recommendation: TransitRecommendation.metroPossible,
        recommendationLabel: 'Auto / Cab',
        headline: walkDist > 3000
            ? '🚕 Bus / Auto / Cab ($walkKm km)'
            : '🚕 Auto / Cab or Walk ($walkKm km)',
        detailedAdvice: walkDist > 3000
            ? '$why Take a bus, auto or cab between ${fromP.name} and ${toP.name} ($walkKm km).'
            : '$why Walk (~$walkMins mins) or take an auto/cab between ${fromP.name} and ${toP.name}.',
      );
    }

    // Board where the first ride starts and alight where the last one ends.
    // If the path begins/ends with a road link (e.g. a pandal assigned to Kavi
    // Subhash heading for the Blue Line), walk straight to that station.
    final boardSt = path.legs.first.from;
    final alightSt = path.legs.last.to;
    double distTo(Pandal p, String st, PandalMetroInfo info) {
      if (st == info.station) return info.distanceToMetroMeters;
      final c = kStationCoordinates[st];
      return c == null
          ? info.distanceToMetroMeters
          : _haversineMeters(p.lat, p.lon, c[0], c[1]);
    }

    final accessM = distTo(fromP, boardSt, infoA);
    final egressM = distTo(toP, alightSt, infoB);
    final accessMins = (accessM / kWalkMetersPerMinute).round();
    final egressMins = (egressM / kWalkMetersPerMinute).round();
    int roadLinkMins = 0;
    for (int i = 1; i < path.legs.length; i++) {
      final a = path.legs[i - 1].to, b = path.legs[i].from;
      if (a == b) continue;
      final ca = kStationCoordinates[a], cb = kStationCoordinates[b];
      final m = (ca == null || cb == null)
          ? 1000.0
          : _haversineMeters(ca[0], ca[1], cb[0], cb[1]);
      roadLinkMins +=
          (m / kWalkMetersPerMinute).round() + kStationOverheadMinutes;
    }
    final interchanges = <String>[
      for (int i = 1; i < path.legs.length; i++)
        if (path.legs[i - 1].to == path.legs[i].from)
          path.legs[i].from
        else
          '${path.legs[i - 1].to} ↔ ${path.legs[i].from}'
    ];
    final rideMins = path.stops * kMinutesPerStop +
        interchanges.where((x) => !x.contains('↔')).length * kTransferMinutes +
        roadLinkMins;
    final metroTotal =
        accessMins + kStationOverheadMinutes + rideMins + egressMins;

    // 3. Metro is not faster door-to-door: walk.
    if (metroTotal >= walkMins) {
      return walk(
          'Metro would take ~$metroTotal mins door to door (~${accessM.round()} m to $boardSt, ${path.stops} stop${path.stops == 1 ? '' : 's'}, ~${egressM.round()} m from $alightSt) vs ~$walkMins mins walking directly.');
    }

    final fare = estimateFare(path);
    final lastMileA = accessM > 0
        ? 'Walk ~${accessM.round()} m to $boardSt'
        : 'Access $boardSt';
    final lastMileB = egressM > 0
        ? 'Walk ~${egressM.round()} m from $alightSt to ${toP.name}'
        : 'Exit to ${toP.name}';

    // 4. Single line: Metro Recommended.
    if (path.legs.length == 1) {
      final leg = path.legs.first;
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
            '🚇 Metro Recommended (${path.stops} stops, ~$metroTotal mins door to door)',
        detailedAdvice:
            '$lastMileA ➔ Board ${leg.line} (${leg.direction}) ➔ Ride ${path.stops} stops to $alightSt ➔ $lastMileB.',
        boardStation: boardSt,
        alightStation: alightSt,
        line: leg.line,
        direction: leg.direction,
        stationCount: path.stops,
        estimatedMetroMinutes: metroTotal,
        fareRupees: fare,
      );
    }

    // 5. One or more interchanges / road links: Metro Possible.
    final via = interchanges.join(' & ');
    final steps = <String>[lastMileA];
    for (int i = 0; i < path.legs.length; i++) {
      final leg = path.legs[i];
      if (i > 0 && leg.from != path.legs[i - 1].to) {
        steps.add(
            'Exit and walk/auto ~1 km from ${path.legs[i - 1].to} to ${leg.from}');
      }
      steps.add(
          '${i == 0 ? 'Board' : (leg.from == path.legs[i - 1].to ? 'Change to' : 'Board')} ${leg.line} (${leg.direction}) ➔ ${leg.stops} stop${leg.stops == 1 ? '' : 's'} to ${leg.to}');
    }
    steps.add(lastMileB);
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
      headline:
          '🔄 Metro via $via (${path.stops} stops, ~$metroTotal mins door to door)',
      detailedAdvice:
          '${steps.join(' ➔ ')}. (Tip: if an auto/cab is easy to find, compare road traffic.)',
      boardStation: boardSt,
      alightStation: alightSt,
      line: path.legs.map((l) => l.line).join(' ➔ '),
      direction: 'Via $via Interchange',
      stationCount: path.stops,
      estimatedMetroMinutes: metroTotal,
      interchangeStation: interchanges.first,
      isInterchange: true,
      fareRupees: fare,
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

  String _calculateDirection(String line, int fromIdx, int toIdx) {
    final isForward = toIdx > fromIdx;
    final lower = line.toLowerCase();
    if (lower.contains('blue')) {
      return isForward
          ? 'Southbound (towards Shahid Khudiram)'
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
          ? 'Northbound (towards Beleghata)'
          : 'Southbound (towards Shahid Khudiram)';
    }
    if (lower.contains('yellow')) {
      return isForward
          ? 'Eastbound (towards Jai Hind Bimanbandar / Airport)'
          : 'Westbound (towards Noapara)';
    }
    return 'Inbound Service';
  }
}
