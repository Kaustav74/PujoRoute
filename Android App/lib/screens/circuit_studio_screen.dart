import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/external_links.dart';
import '../data/pujas_data.dart';
import '../data/puja_calendar_data.dart';
import '../services/session_service.dart';
import '../services/live_feed_service.dart';
import '../services/pandal_deduplication_service.dart';
import '../services/hardened_pujo_optimizer.dart';
import '../services/metro_graph_service.dart';
import 'puja_calendar_screen.dart';

class MetroStationLocation {
  final String name;
  final double lat;
  final double lon;
  final String line;

  const MetroStationLocation(this.name, this.lat, this.lon, this.line);
}

/// Station locations for map links, derived from the single audited source
/// (MetroGraphService.kStationCoordinates, OpenStreetMap station nodes).
/// This used to be a separate hand-typed table with several stations 1-3 km off
/// (e.g. Kavi Subhash, Shahid Khudiram, Kavi Nazrul) and missing stations.
final List<MetroStationLocation> kKolkataMetroCoordinates = [
  for (final e in MetroGraphService.kStationCoordinates.entries)
    MetroStationLocation(e.key, e.value[0], e.value[1], _lineLabel(e.key)),
];

String _lineLabel(String station) {
  final lines = <String>[
    if (MetroGraphService.kBlueLineStations.contains(station)) 'Blue Line',
    if (MetroGraphService.kGreenLineStations.contains(station)) 'Green Line',
    if (MetroGraphService.kPurpleLineStations.contains(station)) 'Purple Line',
    if (MetroGraphService.kOrangeLineStations.contains(station)) 'Orange Line',
    if (MetroGraphService.kYellowLineStations.contains(station)) 'Yellow Line',
  ];
  return lines.join(' / ');
}

class CircuitStudioScreen extends StatefulWidget {
  final double userLat;
  final double userLon;
  final String? initialZone;
  final int? initialStops;

  const CircuitStudioScreen({
    super.key,
    required this.userLat,
    required this.userLon,
    this.initialZone,
    this.initialStops,
  });

  @override
  State<CircuitStudioScreen> createState() => _CircuitStudioScreenState();
}

class _CircuitStudioScreenState extends State<CircuitStudioScreen> {
  // Theme constants
  static const Color kMidnightBlue = Color(0xFF0D0D1E);
  static const Color kSindoorRed = Color(0xFFE62E2D);
  static const Color kMarigoldAmber = Color(0xFFFFB300);
  static const Color kTranslucentObsidian = Color(0xCC1C1C2E);

  // Configuration State
  String _selectedZone =
      'All'; // 'All', 'North', 'South', 'Salt Lake', 'Central'
  int _targetStopCount = 8; // 3 to 15 stops
  String _circuitStyle =
      'mega'; // 'mega', 'heritage', 'nearest', 'bookmarked'
  bool _optimizeByMetro =
      false; // Transit optimization via Kolkata Metro corridors
  bool _rerouteHeavyTraffic =
      false; // Skip pandals on the bundled offline list of usually congested spots
  bool _excludeVisitedStamps =
      true; // Exclude completed / passport-stamped pandals from route generation

  // Generated Circuit
  List<Pandal> _circuitStops = [];
  List<Pandal> _pendingForcedStops = [];
  int _selectedNewTotalStops = 7;
  bool _isGenerating = false;
  String _aiNarrative = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialZone != null && widget.initialZone!.isNotEmpty) {
      _selectedZone = widget.initialZone!;
    }
    if (widget.initialStops != null && widget.initialStops! > 0) {
      _targetStopCount = widget.initialStops!;
    }
    if (widget.initialZone != null || widget.initialStops != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateCircuit();
      });
    } else {
      _loadExistingOrGenerateDefault();
    }
  }

  void _loadExistingOrGenerateDefault() {
    final session = SessionService.instance;
    if (session.activeCircuitIds.isNotEmpty) {
      final Map<String, Pandal> idMap = {
        for (var p in kAllKolkataPujas) p.id: p
      };
      final existing = session.activeCircuitIds
          .map((id) => idMap[id])
          .whereType<Pandal>()
          .toList();
      if (existing.isNotEmpty) {
        setState(() {
          _circuitStops = existing;
          _targetStopCount = existing.length > 5 ? existing.length : 8;
          _aiNarrative =
              'Active circuit loaded from your persistent session. You can reorder, add, or generate a new itinerary.';
        });
        return;
      }
    }
    // Auto-generate initial 8-stop circuit
    _generateCircuit();
  }

  // Haversine Distance in meters with 1.25x Kolkata street turn factor
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
    return r * c * 1.25;
  }


  void _generateCircuit() async {
    setState(() {
      _isGenerating = true;
    });

    // Yield to the event loop so the loading spinner can render
    await Future.delayed(const Duration(milliseconds: 50));

    // 1. Filter candidates by zone & style (with Context-Aware Deduplication)
    List<Pandal> pool = PandalDeduplicationService.instance
        .deduplicate(List.from(kAllKolkataPujas.where((p) => p.hasMappableLocation)));

    if (_selectedZone != 'All') {
      pool = pool.where((p) => p.zone == _selectedZone).toList();
    }

    // Passport Stamped / Already Visited Filter
    if (_excludeVisitedStamps) {
      final visited = SessionService.instance.visitedIds;
      final unvisited =
          pool.where((p) => !visited.contains(p.id)).toList();
      if (unvisited.isNotEmpty) {
        pool = unvisited;
      }
    }

    // Offline list of usually congested spots (static, bundled; not live data)
    if (_rerouteHeavyTraffic) {
      final filtered = pool
          .where((p) => !LiveFeedService.instance.shouldRerouteAround(p.name))
          .toList();
      if (filtered.isNotEmpty) {
        pool = filtered;
      }
    }

    if (_circuitStyle == 'heritage') {
      pool = pool.where((p) => p.category == 'heritage').toList();
      if (pool.isEmpty) {
        pool =
            List.from(kAllKolkataPujas.where(
                (p) => p.category == 'heritage' && p.hasMappableLocation));
      }
    } else if (_circuitStyle == 'mega') {
      pool = pool.where((p) => p.category == 'mega').toList();
    } else if (_circuitStyle == 'bookmarked') {
      final bIds = SessionService.instance.bookmarkedIds;
      final bookmarkedPool = pool.where((p) => bIds.contains(p.id)).toList();
      if (bookmarkedPool.isNotEmpty) {
        pool = bookmarkedPool;
      }
    }

    // 2. Metro Anchor & Candidate Selection
    Pandal? metroStartAnchor;
    Pandal? metroEndAnchor;
    final int count = min(_targetStopCount, pool.length);

    if (_optimizeByMetro) {
      final metroCandidates =
          pool.where(HardenedPujoOptimizer.hasUsableMetro).toList();
      if (metroCandidates.isNotEmpty) {
        // Start Anchor: closest metro station pandal from user location
        metroCandidates.sort((a, b) {
          final da =
              _getDistanceMeters(widget.userLat, widget.userLon, a.lat, a.lon);
          final db =
              _getDistanceMeters(widget.userLat, widget.userLon, b.lat, b.lon);
          return da.compareTo(db);
        });
        final start = metroCandidates.first;
        metroStartAnchor = start;

        // Exit Anchor: a metro pandal at walking-circuit distance (not the
        // farthest one in the pool).
        if (count >= 3) {
          metroEndAnchor = HardenedPujoOptimizer.pickMetroExitAnchor(
              start: start, candidates: metroCandidates, stops: count);
        }
      }
    }

    final double originLat = metroStartAnchor?.lat ?? widget.userLat;
    final double originLon = metroStartAnchor?.lon ?? widget.userLon;
    final double destLat = metroEndAnchor?.lat ?? widget.userLat;
    final double destLon = metroEndAnchor?.lon ?? widget.userLon;

    // 3. Hardened Pujo Optimizer: Full cardinality, home-bound, zero backtracking
    final RoutingResult routingResult =
        HardenedPujoOptimizer.generateHomeBoundCircuit(
      pool: pool,
      startLat: originLat,
      startLng: originLon,
      homeLat: destLat,
      homeLng: destLon,
      requestedStops: count,
    );

    final List<Pandal> finalRoute = routingResult.route;

    // 5. Calculate total distance & narrative
    double totalMeters = 0;
    if (finalRoute.isNotEmpty) {
      totalMeters += _getDistanceMeters(widget.userLat, widget.userLon,
          finalRoute.first.lat, finalRoute.first.lon);
      for (int i = 0; i < finalRoute.length - 1; i++) {
        totalMeters += _getDistanceMeters(finalRoute[i].lat, finalRoute[i].lon,
            finalRoute[i + 1].lat, finalRoute[i + 1].lon);
      }
    }
    final double totalKm = totalMeters / 1000;
    final int totalMins = max(10, (totalMeters / 75).round());

    String styleDesc = 'Mega Thematic';
    if (_circuitStyle == 'heritage') styleDesc = 'Historic Bonedi Bari';
    if (_circuitStyle == 'nearest') styleDesc = 'Shortest Walk';
    if (_circuitStyle == 'bookmarked') styleDesc = 'Bookmarked Favorites';

    String narrative =
        '✅ Route ready: ${finalRoute.length} $styleDesc stops in $_selectedZone Kolkata. Total walk: ${totalKm.toStringAsFixed(1)} km (~$totalMins mins). 2-Opt path optimization active.';
    if (_rerouteHeavyTraffic) {
      narrative +=
          ' Skipping pandals on our offline list of usually congested spots.';
    }
    if (_optimizeByMetro && finalRoute.isNotEmpty) {
      narrative +=
          ' 🚇 Metro Anchors Active: Start at ${finalRoute.first.name} (${finalRoute.first.detailedMetroGate})';
      if (finalRoute.length > 1 &&
          HardenedPujoOptimizer.hasUsableMetro(finalRoute.last)) {
        narrative += ' → Exit near ${finalRoute.last.metroStation} Metro.';
      } else {
        narrative += '.';
      }
    }
    if (_excludeVisitedStamps) {
      final visitedCount = SessionService.instance.visitedIds.length;
      if (visitedCount > 0) {
        narrative += ' 🛂 Excluded $visitedCount passport-stamped pandals.';
      }
    }

    setState(() {
      _circuitStops = finalRoute;
      _aiNarrative = narrative;
      _isGenerating = false;
    });
  }

  void _activateCircuitOnMap() async {
    if (_circuitStops.isEmpty) return;
    final ids = _circuitStops.map((p) => p.id).toList();
    await SessionService.instance.saveCircuit(ids, true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🚀 Activated ${_circuitStops.length}-stop circuit! Route displayed on map.'),
        backgroundColor: kSindoorRed,
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context, true);
  }

  /// Lead sentence for the Metro guide when no hop is a Metro ride, so a
  /// "0 Metro" circuit is explained rather than looking broken.
  String _noMetroExplanation(MetroGuideSummary summary) {
    if (summary.metroRecommendedCount > 0 || summary.hops.isEmpty) return '';
    final why = summary.walkCount == summary.hops.length
        ? 'every hop in this circuit is a short walk.'
        : 'for each longer hop, walking (or an auto / cab) is quicker than the full Metro trip.';
    return 'No Metro ride between pandals: $why Circuits are built from pandals close to each other, so most need no Metro; use it to reach the first pandal or to travel between areas. ';
  }

  MetroStationLocation _getNearestMetroForPandal(Pandal p) {
    // Resolve the pandal's assigned station exactly (alias-aware). The old
    // substring scan matched 'Central Park' to 'Central' and 'Howrah Maidan'
    // to 'Maidan'.
    final canonical =
        MetroGraphService.instance.getCanonicalStation(p.metroStation);
    if (canonical != null) {
      for (final m in kKolkataMetroCoordinates) {
        if (m.name == canonical) return m;
      }
    }
    MetroStationLocation nearest = kKolkataMetroCoordinates.first;
    double minDist = double.infinity;
    for (final m in kKolkataMetroCoordinates) {
      final d = _getDistanceMeters(p.lat, p.lon, m.lat, m.lon);
      if (d < minDist) {
        minDist = d;
        nearest = m;
      }
    }
    return nearest;
  }

  List<Pandal> _applyHeavyTrafficBypass(List<Pandal> stops) {
    if (!_rerouteHeavyTraffic) return stops;
    final filtered = stops
        .where((p) => !LiveFeedService.instance.shouldRerouteAround(p.name))
        .toList();
    return filtered.isNotEmpty ? filtered : stops;
  }

  /// Builds the list of Google Maps leg URLs for the given circuit.
  /// Each leg has at most 11 points (origin + 9 waypoints + destination).
  /// Returns a list of (url, pandal-names-in-leg) pairs.
  /// Helper to create the best searchable string for Google Maps
  String _placeQuery(Pandal p) {
    if (p.landmark.trim().isNotEmpty && p.landmark.length > 8) {
      return '${p.landmark}, Kolkata';
    }
    return '${p.name}, ${p.zone} Kolkata';
  }

  List<MapEntry<String, List<String>>> _buildCircuitLegs(
      {bool useCoordinates = false}) {
    final activeStops = _applyHeavyTrafficBypass(_circuitStops);
    if (activeStops.isEmpty) return [];

    // Clean invalid coordinates first
    final cleanStops = activeStops.where((p) {
      return p.lat.abs() > 1 && p.lon.abs() > 1 && p.name.trim().isNotEmpty;
    }).toList();

    if (cleanStops.isEmpty) return [];

    // Build ordered list: [origin, pandal1, pandal2, ..., pandalN]
    final List<String> allPoints = [];
    final List<String> allLabels = []; // human-readable labels

    if (_optimizeByMetro) {
      final startMetro = _getNearestMetroForPandal(cleanStops.first);
      allPoints.add(useCoordinates
          ? '${startMetro.lat.toStringAsFixed(6)},${startMetro.lon.toStringAsFixed(6)}'
          : '${cleanStops.first.metroStation} Metro Station, Kolkata');
      allLabels.add('🚇 ${cleanStops.first.metroStation} Metro');

      for (final p in cleanStops) {
        allPoints.add(useCoordinates
            ? '${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}'
            : _placeQuery(p));
        allLabels.add(p.name);
      }

      final endMetro = _getNearestMetroForPandal(cleanStops.last);
      allPoints.add(useCoordinates
          ? '${endMetro.lat.toStringAsFixed(6)},${endMetro.lon.toStringAsFixed(6)}'
          : '${cleanStops.last.metroStation} Metro Station, Kolkata');
      allLabels.add('🚇 ${cleanStops.last.metroStation} Metro');
    } else {
      final bool hasUserLoc = widget.userLat != 0.0 && widget.userLon != 0.0;
      if (hasUserLoc) {
        allPoints.add(
            '${widget.userLat.toStringAsFixed(6)},${widget.userLon.toStringAsFixed(6)}');
        allLabels.add('📍 Your Location');
      }
      for (final p in cleanStops) {
        allPoints.add(useCoordinates
            ? '${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}'
            : _placeQuery(p));
        allLabels.add(p.name);
      }
    }

    if (allPoints.length < 2) return [];

    // Split into legs of up to 11 points each
    const int maxPointsPerLeg = 11;
    final List<MapEntry<String, List<String>>> legs = [];
    int i = 0;
    while (i < allPoints.length - 1) {
      final end = (i + maxPointsPerLeg).clamp(0, allPoints.length);
      final legPoints = allPoints.sublist(i, end);
      final legLabels = allLabels.sublist(i, end);

      final origin = legPoints.first;
      final destination = legPoints.last;
      final waypoints = legPoints.length > 2
          ? legPoints.sublist(1, legPoints.length - 1).join('|')
          : '';

      final url = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': origin,
        'destination': destination,
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
        'travelmode': 'walking',
      }).toString();

      legs.add(MapEntry(url, legLabels));
      i = end - 1; // overlap
    }
    return legs;
  }

  void _openGoogleMapsMultiStop({bool useCoordinates = false}) async {
    if (_circuitStops.isEmpty) return;

    final legs = _buildCircuitLegs(useCoordinates: useCoordinates);
    if (legs.isEmpty) return;

    // Single leg: launch directly
    if (legs.length == 1) {
      final url = Uri.parse(legs.first.key);
      if (await openExternalLink(context, url)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(useCoordinates
                ? '📍 Opened Google Maps with GPS coordinates.'
                : '🗺️ Opened Google Maps with readable pandal names.'),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 5),
            action: useCoordinates
                ? null
                : SnackBarAction(
                    label: 'Use GPS Coords',
                    textColor: const Color(0xFFFFB300),
                    onPressed: () =>
                        _openGoogleMapsMultiStop(useCoordinates: true),
                  ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Google Maps.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // Multiple legs: show bottom sheet with leg cards
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CircuitLegsSheet(
        legs: legs,
        totalPandals: _circuitStops.length,
        isUsingCoordinates: useCoordinates,
        onToggleCoordinates: () {
          Navigator.pop(ctx);
          _openGoogleMapsMultiStop(useCoordinates: !useCoordinates);
        },
      ),
    );
  }

  void _openSinglePandalInMaps(Pandal p, {bool useCoordinates = false}) async {
    final destination = useCoordinates
        ? '${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}'
        : _placeQuery(p);
    final bool hasUserLoc = widget.userLat != 0.0 && widget.userLon != 0.0;
    final String origin = hasUserLoc
        ? '${widget.userLat.toStringAsFixed(6)},${widget.userLon.toStringAsFixed(6)}'
        : '';

    final Uri url;
    if (hasUserLoc) {
      url = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': origin,
        'destination': destination,
        'travelmode': 'walking',
      });
    } else {
      url = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': destination,
      });
    }

    if (!mounted) return;
    await openExternalLink(context, url);
  }

  void _shareCircuitToWhatsApp() async {
    if (_circuitStops.isEmpty) return;

    // Clean invalid coordinates first
    final cleanStops = _circuitStops.where((p) {
      return p.lat.abs() > 1 && p.lon.abs() > 1 && p.name.trim().isNotEmpty;
    }).toList();

    if (cleanStops.isEmpty) return;

    // Build ordered list of all coordinate points
    final List<String> allPoints = [];
    // Privacy: the shared message must not leak the sender's live GPS
    // position, so shared routes start at the first pandal.
    for (final p in cleanStops) {
      allPoints.add('${p.lat.toStringAsFixed(6)},${p.lon.toStringAsFixed(6)}');
    }

    // Split into legs of up to 11 points (origin + 9 waypoints + destination)
    const int maxPointsPerLeg = 11;
    final List<String> mapUrls = [];
    int i = 0;
    while (i < allPoints.length - 1) {
      final end = (i + maxPointsPerLeg).clamp(0, allPoints.length);
      final leg = allPoints.sublist(i, end);
      final origin = leg.first;
      final destination = leg.last;
      final waypoints = leg.length > 2
          ? leg.sublist(1, leg.length - 1).join('|')
          : '';
      final mapsUrl = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': origin,
        'destination': destination,
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
        'travelmode': 'walking',
      }).toString();
      mapUrls.add(mapsUrl);
      i = end - 1;
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln(
        "🎉 My Durga Puja 2026 Circuit (${cleanStops.length} Stops):");
    for (final p in cleanStops) {
      final metro =
          p.metroStation.isNotEmpty ? " (Near ${p.metroStation})" : "";
      sb.writeln("• ${p.name}$metro");
    }
    if (mapUrls.length == 1) {
      sb.writeln("\n📍 Google Maps Route: ${mapUrls.first}");
    } else {
      for (int legIdx = 0; legIdx < mapUrls.length; legIdx++) {
        sb.writeln("\n📍 Leg ${legIdx + 1}: ${mapUrls[legIdx]}");
      }
    }
    sb.writeln("\nPlanned via PujoRoute 🪔");

    final encodedText = Uri.encodeComponent(sb.toString());
    final url = Uri.parse('whatsapp://send?text=$encodedText');
    final fallbackUrl = Uri.parse('https://wa.me/?text=$encodedText');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('WhatsApp is not installed on this device.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp.')),
      );
    }
  }

  void _loadDayPreset(String dayId) {
    final day = getPujaDayById(dayId);
    final Map<String, Pandal> idMap = {for (var p in kAllKolkataPujas) p.id: p};
    final matched = day.recommendedPandalIds
        .map((id) => idMap[id])
        .whereType<Pandal>()
        .toList();

    if (matched.isNotEmpty) {
      setState(() {
        _circuitStops = matched;
        _aiNarrative =
            'Curated 2026 circuit loaded for ${day.titleEnglish} (${day.dateFormatted}). Auspicious moments: ${day.auspiciousMoments.split('|').first.trim()}.';
      });
      SessionService.instance
          .saveCircuit(matched.map((p) => p.id).toList(), true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Loaded ${matched.length} curated stops for ${day.dayName}!')),
      );
    }
  }

  Widget _buildTithiPresetChip(String dayId, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ActionChip(
        backgroundColor: const Color(0xFF2E1924),
        side: const BorderSide(color: Color(0x59FFB300)),
        label: Text(
          label,
          style: const TextStyle(
              color: Color(0xFFFFF8E7),
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
        onPressed: () => _loadDayPreset(dayId),
      ),
    );
  }

  void _showAddPandalPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String filter = '';
        bool hideStampedInPicker = _excludeVisitedStamps;
        final Set<Pandal> selectedPandals = {};

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final existingIds = _circuitStops.map((p) => p.id).toSet();
            final visitedIds = SessionService.instance.visitedIds;
            final referenceLat = _circuitStops.isNotEmpty
                ? _circuitStops.last.lat
                : widget.userLat;
            final referenceLon = _circuitStops.isNotEmpty
                ? _circuitStops.last.lon
                : widget.userLon;
            final referenceName = _circuitStops.isNotEmpty
                ? _circuitStops.last.name
                : 'Your Location';

            final available = kAllKolkataPujas
                .where((p) =>
                    p.hasMappableLocation &&
                    !existingIds.contains(p.id) &&
                    (!hideStampedInPicker || !visitedIds.contains(p.id)) &&
                    (filter.isEmpty ||
                        p.name.toLowerCase().contains(filter.toLowerCase()) ||
                        p.zone.toLowerCase().contains(filter.toLowerCase()) ||
                        p.landmark
                            .toLowerCase()
                            .contains(filter.toLowerCase())))
                .toList();

            // Sort available by distance from reference location
            available.sort((a, b) {
              final da =
                  _getDistanceMeters(referenceLat, referenceLon, a.lat, a.lon);
              final db =
                  _getDistanceMeters(referenceLat, referenceLon, b.lat, b.lon);
              return da.compareTo(db);
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border:
                    Border(top: BorderSide(color: kMarigoldAmber, width: 2.5)),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Pandal to Circuit',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          if (visitedIds.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  hideStampedInPicker = !hideStampedInPicker;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hideStampedInPicker
                                      ? Colors.purple.withValues(alpha: 0.25)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hideStampedInPicker
                                        ? Colors.purpleAccent
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  hideStampedInPicker
                                      ? '🛂 Hide Stamped'
                                      : '🛂 Show Stamped',
                                  style: TextStyle(
                                    color: hideStampedInPicker
                                        ? Colors.purpleAccent
                                        : Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: kMarigoldAmber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${available.length} available',
                              style: const TextStyle(
                                  color: kMarigoldAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'Search 504 Kolkata pandals by name, zone, landmark...',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon:
                          const Icon(Icons.search, color: kMarigoldAmber),
                      filled: true,
                      fillColor: const Color(0xFF1C1C2E),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        filter = val;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distances computed from: $referenceName',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (c, idx) {
                        final p = available[idx];
                        final isSelected = selectedPandals.any((s) => s.id == p.id);
                        final dist = _getDistanceMeters(
                                referenceLat, referenceLon, p.lat, p.lon)
                            .round();
                        final isMega = p.category == 'mega';

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF262640)
                                : const Color(0xFF1C1C2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? kMarigoldAmber
                                  : Colors.white10,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedPandals.removeWhere((s) => s.id == p.id);
                                } else {
                                  selectedPandals.add(p);
                                }
                              });
                            },
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isSelected
                                        ? kMarigoldAmber
                                        : (isMega ? kSindoorRed : kMarigoldAmber))
                                    .withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : (isMega
                                        ? Icons.local_fire_department
                                        : Icons.account_balance),
                                color: isSelected
                                    ? kMarigoldAmber
                                    : (isMega ? kSindoorRed : kMarigoldAmber),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: TextStyle(
                                color: isSelected ? kMarigoldAmber : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text(
                                  '${p.zone} • ${dist > 1000 ? "${(dist / 1000).toStringAsFixed(1)}km" : "${dist}m"} from ${_circuitStops.isNotEmpty ? "last stop" : "you"}',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 11.5),
                                ),
                                if (p.metroStation.isNotEmpty)
                                  Text(
                                    '🚇 ${p.metroStation}',
                                    style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 10.5),
                                  ),
                                if (visitedIds.contains(p.id))
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.purple.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      '🛂 Stamped in Passport (Completed)',
                                      style: TextStyle(
                                          color: Colors.purpleAccent,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? const Color(0xFF2E7D32)
                                    : kSindoorRed,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selectedPandals.removeWhere((s) => s.id == p.id);
                                  } else {
                                    selectedPandals.add(p);
                                  }
                                });
                              },
                              child: Text(
                                isSelected ? 'Selected ✓' : '+ Select',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Action Bar when pandals are selected (Option C Flow)
                  if (selectedPandals.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E34),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kMarigoldAmber,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: kMarigoldAmber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${selectedPandals.length} Selected',
                              style: const TextStyle(
                                color: kMarigoldAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kMarigoldAmber,
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                final chosen = selectedPandals.toList();
                                Navigator.pop(ctx);
                                _showConfigureAndRegenerateSheet(chosen);
                              },
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text(
                                'Configure Stops →',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Option C Bottom Sheet: Lets user review added pandals, select new total stops, and regenerate AI Circuit.
  void _showConfigureAndRegenerateSheet(List<Pandal> newlyAdded) {
    if (newlyAdded.isEmpty) return;

    _pendingForcedStops = newlyAdded;
    _selectedNewTotalStops = (_circuitStops.length + newlyAdded.length).clamp(
      max(newlyAdded.length + 1, 4),
      15,
    );

    final List<int> stopOptions = [];
    final minStops = max(newlyAdded.length + 1, 3);
    for (int count = minStops; count <= 15; count++) {
      stopOptions.add(count);
    }
    if (!stopOptions.contains(_selectedNewTotalStops)) {
      _selectedNewTotalStops = stopOptions.first;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF141424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border:
                    Border(top: BorderSide(color: kMarigoldAmber, width: 2.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kMarigoldAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: kMarigoldAmber, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Regenerate Route',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Guaranteed to include ${newlyAdded.length} added pandal(s)',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mandatory pandals preview
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PANDALS TO INCLUDE (MANDATORY):',
                          style: TextStyle(
                            color: kMarigoldAmber,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: newlyAdded.map((p) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: kSindoorRed.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: kSindoorRed.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: kSindoorRed, size: 13),
                                  const SizedBox(width: 5),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Option C: Total stops selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Choose New Total Stops:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kMarigoldAmber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$_selectedNewTotalStops Stops',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: stopOptions.map((count) {
                        final isSelected = count == _selectedNewTotalStops;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$count'),
                            selected: isSelected,
                            selectedColor: kMarigoldAmber,
                            backgroundColor: const Color(0xFF1C1C2E),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.black87
                                  : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12.5,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? kMarigoldAmber
                                  : Colors.white12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() {
                                  _selectedNewTotalStops = count;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Regenerate Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSindoorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _regenerateCircuitWithForcedStops(
                            _pendingForcedStops, _selectedNewTotalStops);
                      },
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        'Regenerate Route ($_selectedNewTotalStops Stops)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Regenerates circuit with user-specified forced pandals and target stops count.
  void _regenerateCircuitWithForcedStops(
      List<Pandal> newlyAdded, int newTotalStops) async {
    if (newlyAdded.isEmpty && _circuitStops.isEmpty) return;

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kMarigoldAmber),
      ),
    );

    // Yield to let dialog render
    await Future.delayed(const Duration(milliseconds: 100));

    // 1. Prepare candidate pool
    final mappable = kAllKolkataPujas.where((p) => p.hasMappableLocation);
    List<Pandal> pool = _selectedZone == 'All'
        ? mappable.toList()
        : mappable.where((p) => p.zone == _selectedZone).toList();

    // Ensure all existing circuit stops and forced stops are present in candidate pool
    final Map<String, Pandal> poolMap = {for (var p in pool) p.id: p};
    for (final p in _circuitStops) {
      poolMap[p.id] = p;
    }
    for (final p in newlyAdded) {
      poolMap[p.id] = p;
    }
    pool = poolMap.values.toList();

    // Passport Stamped / Already Visited Filter (preserving user-specified forced stops)
    if (_excludeVisitedStamps) {
      final visited = SessionService.instance.visitedIds;
      final forcedIds = newlyAdded.map((p) => p.id).toSet();
      final unvisited = pool
          .where((p) => !visited.contains(p.id) || forcedIds.contains(p.id))
          .toList();
      if (unvisited.isNotEmpty) {
        pool = unvisited;
      }
    }

    // 2. Metro Anchoring if enabled
    Pandal? metroStartAnchor;
    Pandal? metroEndAnchor;
    if (_optimizeByMetro && pool.isNotEmpty) {
      final metroCandidates =
          pool.where(HardenedPujoOptimizer.hasUsableMetro).toList();
      if (metroCandidates.isNotEmpty) {
        metroCandidates.sort((a, b) => _getDistanceMeters(
                widget.userLat, widget.userLon, a.lat, a.lon)
            .compareTo(_getDistanceMeters(
                widget.userLat, widget.userLon, b.lat, b.lon)));
        final start = metroCandidates.first;
        metroStartAnchor = start;
        metroEndAnchor = HardenedPujoOptimizer.pickMetroExitAnchor(
            start: start, candidates: metroCandidates, stops: newTotalStops);
      }
    }

    final double originLat = metroStartAnchor?.lat ?? widget.userLat;
    final double originLon = metroStartAnchor?.lon ?? widget.userLon;
    final double destLat = metroEndAnchor?.lat ?? widget.userLat;
    final double destLon = metroEndAnchor?.lon ?? widget.userLon;

    setState(() {
      _isGenerating = true;
      _targetStopCount = newTotalStops;
    });

    final RoutingResult routingResult =
        HardenedPujoOptimizer.generateHomeBoundCircuit(
      pool: pool,
      startLat: originLat,
      startLng: originLon,
      homeLat: destLat,
      homeLng: destLon,
      requestedStops: newTotalStops,
      forcedStops: newlyAdded,
    );

    if (mounted) {
      Navigator.pop(context); // Dismiss loading dialog
    }

    final List<Pandal> finalRoute = routingResult.route;

    if (finalRoute.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate route'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate metrics
    double totalMeters = 0;
    if (finalRoute.isNotEmpty) {
      totalMeters += _getDistanceMeters(widget.userLat, widget.userLon,
          finalRoute.first.lat, finalRoute.first.lon);
      for (int i = 0; i < finalRoute.length - 1; i++) {
        totalMeters += _getDistanceMeters(finalRoute[i].lat, finalRoute[i].lon,
            finalRoute[i + 1].lat, finalRoute[i + 1].lon);
      }
    }
    final double totalKm = totalMeters / 1000;
    final int totalMins = max(10, (totalMeters / 75).round());

    final String namesList = newlyAdded.map((p) => p.name).join(', ');
    final String narrative =
        '✅ Route regenerated: ${finalRoute.length} stops including: $namesList. '
        'Total walk: ${totalKm.toStringAsFixed(1)} km (~$totalMins mins). ${routingResult.diagnostics}';

    setState(() {
      _circuitStops = finalRoute;
      _pendingForcedStops = [];
      _aiNarrative = narrative;
      _isGenerating = false;
    });

    SessionService.instance
        .saveCircuit(_circuitStops.map((s) => s.id).toList(), true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated ${finalRoute.length} stops • ${totalKm.toStringAsFixed(1)} km\n${routingResult.diagnostics}',
        ),
        backgroundColor: Colors.green[800],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showMetroStationGuideModal() {
    if (_circuitStops.isEmpty) return;

    final summary =
        MetroGraphService.instance.buildCircuitMetroGuide(_circuitStops);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Color(0xFF141424),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border:
                Border(top: BorderSide(color: Colors.cyanAccent, width: 2.5)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),

              // Title Bar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyanAccent),
                    ),
                    child: const Icon(Icons.subway_rounded,
                        color: Colors.cyanAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KOLKATA METRO ROUTE & GUIDE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Text(
                          'Practical Transit Routing: Walk vs. Metro',
                          style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Decision Summary Header Pills
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.greenAccent.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_walk,
                            color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          '${summary.walkCount} Walk Recommended',
                          style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (summary.metroRecommendedCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.subway_rounded,
                            color: Colors.cyanAccent, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          '${summary.metroRecommendedCount} Metro Recommended',
                          style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (summary.metroPossibleCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alt_route,
                              color: Colors.amberAccent, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            '${summary.metroPossibleCount} Metro / Auto Link',
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Soft Note for Peak Puja Crowding
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1D2B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: Colors.amberAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_noMetroExplanation(summary)}How this guide decides: hops under 1.3 km are walks; for longer hops it compares walking with the full Metro trip (walk to the station + ~10 mins for entry, security and platform wait + ride + walk from the station) and suggests the Metro only when that is faster. Evening queues at busy stations during Puja can be longer.',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 11, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Hop List or Single Pandal
              Expanded(
                child: _circuitStops.length == 1
                    ? _buildSinglePandalMetroView(_circuitStops.first)
                    : ListView.builder(
                        itemCount: summary.hops.length,
                        itemBuilder: (context, idx) {
                          final hop = summary.hops[idx];
                          return _buildMetroHopCard(hop);
                        },
                      ),
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Dismiss',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openGoogleMapsMultiStop();
                      },
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('Open Circuit in Maps',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSinglePandalMetroView(Pandal p) {
    final info = MetroGraphService.instance.getPandalMetroInfo(p);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_drop, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141424),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NEAREST METRO: ${info.station.toUpperCase()}',
                      style: const TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        info.line,
                        style: const TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.directions_subway,
                        color: Colors.tealAccent, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        info.gate,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (info.distanceToMetroMeters > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🚶 Last-mile walk: ~${info.distanceToMetroMeters.round()} m from station to pandal.',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '📍 Landmark: ${p.landmark}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (p.barricadeAdvisory.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('🚧 ${p.barricadeAdvisory}',
                      style: const TextStyle(
                          color: Color(0xFFFFD54F), fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetroHopCard(MetroHopGuidance hop) {
    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;
    String badgeText;

    switch (hop.recommendation) {
      case TransitRecommendation.walk:
        badgeColor = Colors.greenAccent;
        badgeBg = Colors.green.withValues(alpha: 0.2);
        badgeIcon = Icons.directions_walk;
        badgeText = 'WALK';
        break;
      case TransitRecommendation.metroRecommended:
        badgeColor = Colors.cyanAccent;
        badgeBg = Colors.cyan.withValues(alpha: 0.2);
        badgeIcon = Icons.subway_rounded;
        badgeText = 'METRO';
        break;
      case TransitRecommendation.metroPossible:
        badgeColor = Colors.amberAccent;
        badgeBg = Colors.amber.withValues(alpha: 0.2);
        badgeIcon = Icons.alt_route;
        badgeText = 'POSSIBLE';
        break;
    }

    final walkKm = (hop.directWalkMeters / 1000.0).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hop Header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${hop.hopIndex}',
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${hop.fromPandal.name} ➔ ${hop.toPandal.name}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, color: badgeColor, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      badgeText,
                      style: TextStyle(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Distance & Duration Metrics Bar
          Row(
            children: [
              const Icon(Icons.straighten, color: Colors.white54, size: 13),
              const SizedBox(width: 4),
              Text(
                'Direct Walk: $walkKm km (~${hop.directWalkMinutes} mins)',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
              if (hop.recommendation != TransitRecommendation.walk &&
                  hop.stationCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '• 🚇 ${hop.stationCount} stops${hop.fareRupees > 0 ? ' (~₹${hop.fareRupees})' : ''}',
                  style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Advice / Recommendation Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131322),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hop.headline,
                  style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5),
                ),
                const SizedBox(height: 4),
                Text(
                  hop.detailedAdvice,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Station Details Sub-Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141424),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.trip_origin,
                              color: Colors.lightBlueAccent, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'ORIGIN METRO',
                            style: TextStyle(
                                color: Colors.lightBlueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hop.fromInfo.station} (${hop.fromInfo.line.replaceAll(' Line', '')})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '~${hop.fromInfo.distanceToMetroMeters.round()} m from pandal',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141424),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.tealAccent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.tealAccent, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'DESTINATION METRO',
                            style: TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hop.toInfo.station} (${hop.toInfo.line.replaceAll(' Line', '')})',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '~${hop.toInfo.distanceToMetroMeters.round()} m to pandal',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Total Circuit Stats
    double totalMeters = 0;
    if (_circuitStops.isNotEmpty) {
      totalMeters += _getDistanceMeters(widget.userLat, widget.userLon,
          _circuitStops.first.lat, _circuitStops.first.lon);
      for (int i = 0; i < _circuitStops.length - 1; i++) {
        totalMeters += _getDistanceMeters(
            _circuitStops[i].lat,
            _circuitStops[i].lon,
            _circuitStops[i + 1].lat,
            _circuitStops[i + 1].lon);
      }
    }
    final double totalKm = totalMeters / 1000;
    final int totalMins = max(5, (totalMeters / 75).round());

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
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [kSindoorRed, kMarigoldAmber]),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Circuit Studio',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                  Text(
                    'Automated Hopping Route Optimizer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: kMarigoldAmber,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF25D366)),
            tooltip: 'Share Itinerary to WhatsApp',
            onPressed: _shareCircuitToWhatsApp,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: kMarigoldAmber),
            tooltip: 'Puja 2026 Calendar & Tithis',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PujaCalendarScreen(
                    userLat: widget.userLat,
                    userLon: widget.userLon,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Re-generate Circuit',
            onPressed: _generateCircuit,
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable Settings & Route Timeline
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              children: [
                if (_circuitStops.length > 10)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFFFD54F), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You have ${_circuitStops.length} pandals. Google Maps allows max 10 stops. The route will be split into ${(_circuitStops.length / 10).ceil()} consecutive map legs.',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2026 Tithi Hopping Presets Card
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF880E14), Color(0xFF1E1428)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: kMarigoldAmber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('🪔', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '2026 TITHI HOPPING PRESETS',
                              style: TextStyle(
                                color: Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PujaCalendarScreen(
                                    userLat: widget.userLat,
                                    userLon: widget.userLon,
                                  ),
                                ),
                              );
                            },
                            child: const Row(
                              children: [
                                Text('Full Calendar',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                                Icon(Icons.chevron_right,
                                    color: kMarigoldAmber, size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTithiPresetChip(
                                'panchami', '✨ Panchami Preview'),
                            _buildTithiPresetChip(
                                'shashthi', '🌿 Shashthi Bodhon'),
                            _buildTithiPresetChip(
                                'saptami', '🌊 Saptami Heritage'),
                            _buildTithiPresetChip(
                                'ashtami', '🪔 Maha Ashtami Special'),
                            _buildTithiPresetChip(
                                'nabami', '🔥 Nabami All-Night'),
                            _buildTithiPresetChip(
                                'dashami', '🌺 Dashami Bisarjan'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 1. Circuit Generator Controls
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kTranslucentObsidian,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kMarigoldAmber.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.tune, color: kMarigoldAmber, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'CIRCUIT SPECIFICATIONS',
                            style: TextStyle(
                                color: kMarigoldAmber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Zone Selector Chips
                      const Text('Target Zone:',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          'All',
                          'North',
                          'South',
                          'Salt Lake',
                          'Central'
                        ].map((zone) {
                          final isSelected = _selectedZone == zone;
                          return ChoiceChip(
                            label: Text(zone,
                                style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            selected: isSelected,
                            selectedColor: kMarigoldAmber,
                            backgroundColor: const Color(0xFF26263A),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _selectedZone = zone);
                                _generateCircuit();
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Stop Count Stepper & Smooth Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Number of Stops:',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF26263A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: kMarigoldAmber.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove,
                                      size: 16, color: kMarigoldAmber),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  constraints: const BoxConstraints(),
                                  onPressed: _targetStopCount > 3
                                      ? () {
                                          setState(() => _targetStopCount--);
                                          _generateCircuit();
                                        }
                                      : null,
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '$_targetStopCount Stops',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add,
                                      size: 16, color: kMarigoldAmber),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  constraints: const BoxConstraints(),
                                  onPressed: _targetStopCount < 15
                                      ? () {
                                          setState(() => _targetStopCount++);
                                          _generateCircuit();
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: kSindoorRed,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: kMarigoldAmber,
                          overlayColor: kSindoorRed.withOpacity(0.2),
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                        ),
                        child: Slider(
                          value: _targetStopCount.toDouble(),
                          min: 3,
                          max: 15,
                          divisions: 12,
                          label: '$_targetStopCount stops',
                          onChanged: (val) {
                            setState(() => _targetStopCount = val.round());
                          },
                          onChangeEnd: (_) => _generateCircuit(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Hopping Style / Priority with Distinct Active States
                      const Text('Theme Priority:',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          {'id': 'mega', 'label': '🔥 Mega Themes'},
                          {
                            'id': 'heritage',
                            'label': '🏛️ Heritage Bonedi Bari'
                          },
                          {'id': 'nearest', 'label': '📍 Shortest Walk'},
                          {'id': 'bookmarked', 'label': '⭐ My Bookmarks'},
                        ].map((s) {
                          final isSelected = _circuitStyle == s['id'];
                          final bool isHeritage = s['id'] == 'heritage';
                          return ChoiceChip(
                            label: Text(
                              s['label']!,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: isHeritage
                                ? const Color(0xFFC84B31)
                                : kSindoorRed,
                            backgroundColor: const Color(0xFF26263A),
                            side: BorderSide(
                              color: isSelected
                                  ? (isHeritage ? kMarigoldAmber : kSindoorRed)
                                  : Colors.white12,
                              width: isSelected ? 1.5 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            onSelected: (val) {
                              if (val) {
                                setState(() => _circuitStyle = s['id']!);
                                _generateCircuit();
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Transit Optimization: By Metro Corridor
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _optimizeByMetro
                              ? Colors.cyan.withValues(alpha: 0.12)
                              : const Color(0xFF202034),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _optimizeByMetro
                                ? Colors.cyanAccent.withValues(alpha: 0.5)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.subway_rounded,
                                color: _optimizeByMetro
                                    ? Colors.cyanAccent
                                    : Colors.white54,
                                size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Optimize by Kolkata Metro',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    'Anchors circuit start to nearest Blue/Green Line gate',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _optimizeByMetro,
                              activeColor: Colors.cyanAccent,
                              onChanged: (val) {
                                setState(() => _optimizeByMetro = val);
                                _generateCircuit();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Avoid known congestion spots (offline list)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _rerouteHeavyTraffic
                              ? Colors.orange.withValues(alpha: 0.15)
                              : const Color(0xFF202034),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _rerouteHeavyTraffic
                                ? Colors.orangeAccent.withValues(alpha: 0.6)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.alt_route_rounded,
                                color: _rerouteHeavyTraffic
                                    ? Colors.orangeAccent
                                    : Colors.white54,
                                size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Avoid known congestion spots',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    'Skips pandals on our offline list of usually congested areas',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _rerouteHeavyTraffic,
                              activeColor: Colors.orangeAccent,
                              onChanged: (val) {
                                setState(() => _rerouteHeavyTraffic = val);
                                _generateCircuit();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Exclude Passport Stamped / Completed Pandals
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _excludeVisitedStamps
                              ? Colors.purple.withValues(alpha: 0.15)
                              : const Color(0xFF202034),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _excludeVisitedStamps
                                ? Colors.purpleAccent.withValues(alpha: 0.6)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_rounded,
                                color: _excludeVisitedStamps
                                    ? Colors.purpleAccent
                                    : Colors.white54,
                                size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Exclude Passport Stamped',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.purpleAccent
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${SessionService.instance.visitedIds.length} Done',
                                          style: const TextStyle(
                                            color: Colors.purpleAccent,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    'Excludes completed/visited pandals from route generation',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _excludeVisitedStamps,
                              activeColor: Colors.purpleAccent,
                              onChanged: (val) {
                                setState(() => _excludeVisitedStamps = val);
                                _generateCircuit();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Generate AI Circuit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSindoorRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                          ),
                          onPressed: _isGenerating ? null : _generateCircuit,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            _isGenerating
                                ? 'Optimizing Route...'
                                : '⚡ Generate Route',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.cyanAccent,
                            side: const BorderSide(
                                color: Colors.cyanAccent, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _circuitStops.isEmpty
                              ? null
                              : _showMetroStationGuideModal,
                          icon: const Icon(Icons.subway_rounded, size: 18),
                          label: const Text(
                            '🚇 Generate Metro Station Guide',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Circuit Summary Banner
                if (_circuitStops.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1E34),
                          const Color(0xFF281C2E)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kSindoorRed.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.route,
                                    color: kSindoorRed, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${_circuitStops.length} STOPS PLANNED',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              '${totalKm.toStringAsFixed(1)} km • ~$totalMins min walk',
                              style: const TextStyle(
                                  color: kMarigoldAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                        if (_aiNarrative.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _aiNarrative,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 3. Stop-by-Stop Itinerary Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'ROUTE SEQUENCE (DRAG TO REORDER):',
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF26263A),
                        foregroundColor: kMarigoldAmber,
                        side:
                            const BorderSide(color: kMarigoldAmber, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: _showAddPandalPicker,
                      icon: const Icon(Icons.add_circle,
                          color: kMarigoldAmber, size: 16),
                      label: const Text('+ Add Stop',
                          style: TextStyle(
                              color: kMarigoldAmber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 4. Stops List
                if (_circuitStops.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    alignment: Alignment.center,
                    child: const Text(
                        'No stops in circuit. Tap Generate above!',
                        style: TextStyle(color: Colors.white54)),
                  )
                else
                  ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _circuitStops.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _circuitStops.removeAt(oldIndex);
                        _circuitStops.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, idx) {
                      final p = _circuitStops[idx];
                      final isFirst = idx == 0;
                      final isLast = idx == _circuitStops.length - 1;
                      final isMega = p.category == 'mega';

                      return Container(
                        key: ValueKey(p.id),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: kTranslucentObsidian,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            // Explicit Vertical Drag Handle (Six-Dots Grid)
                            ReorderableDragStartListener(
                              index: idx,
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(Icons.drag_indicator,
                                    color: Colors.white38, size: 22),
                              ),
                            ),

                            // Stop Number Badge
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? Colors.green
                                    : (isLast ? kSindoorRed : kMarigoldAmber),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Pandal Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${isMega ? "🔥 Mega Theme" : "🏛️ Heritage"} • 📍 ${p.subsection}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: isMega
                                            ? kSindoorRed
                                            : kMarigoldAmber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '🚇 ${p.detailedMetroGate}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10.5),
                                  ),
                                  if (p.barricadeAdvisory.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '🚧 ${p.barricadeAdvisory}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Maps Shortcut Button
                            IconButton(
                              icon: const Icon(Icons.navigation,
                                  color: Colors.white60, size: 20),
                              tooltip: 'Open in Google Maps',
                              onPressed: () => _openSinglePandalInMaps(p),
                            ),

                            // Delete Stop Button
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white38, size: 20),
                              tooltip: 'Remove stop',
                              onPressed: () {
                                setState(() {
                                  _circuitStops.removeAt(idx);
                                });
                              },
                            ),

                            // Drag Handle Icon
                            const Icon(Icons.drag_handle,
                                color: Colors.white24, size: 22),
                          ],
                        ),
                      );
                    },
                  ),
                if (_circuitStops.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMarigoldAmber,
                          side: const BorderSide(
                              color: kMarigoldAmber, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAddPandalPicker,
                        icon: const Icon(Icons.add_location_alt_outlined,
                            size: 18),
                        label: const Text('+ Add Another Stop to Circuit',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Action Bar: WhatsApp Share, Start on Map & Launch Google Maps
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF141424),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prominent WhatsApp Share Button (Viral Social Mechanics)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    onPressed:
                        _circuitStops.isEmpty ? null : _shareCircuitToWhatsApp,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text(
                      'Share Itinerary to WhatsApp (গ্রুপে রুট পাঠান)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Open Multi-Stop in Google Maps
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMarigoldAmber,
                          side: const BorderSide(
                              color: kMarigoldAmber, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _circuitStops.isEmpty
                            ? null
                            : _openGoogleMapsMultiStop,
                        icon: const Icon(Icons.map, size: 18),
                        label: const Text('Google Maps Route',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Activate on App Map
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSindoorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        onPressed: _circuitStops.isEmpty
                            ? null
                            : _activateCircuitOnMap,
                        icon: const Icon(Icons.navigation, size: 18),
                        label: const Text('Start on Map',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing multi-leg circuit map links when >10 pandals selected.
class _CircuitLegsSheet extends StatelessWidget {
  final List<MapEntry<String, List<String>>> legs;
  final int totalPandals;
  final bool isUsingCoordinates;
  final VoidCallback? onToggleCoordinates;

  const _CircuitLegsSheet({
    required this.legs,
    required this.totalPandals,
    this.isUsingCoordinates = false,
    this.onToggleCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE62E2D), Color(0xFFFFB300)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Circuit Route — ${legs.length} Legs',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalPandals pandals • Google Maps supports max 10 stops per route',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Security notice
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🔒 Secure: No API keys or personal data shared. Routes use only pandal names & coordinates via URL.',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Leg cards
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: legs.length,
                itemBuilder: (ctx, idx) {
                  final leg = legs[idx];
                  final labels = leg.value;
                  final isLast = idx == legs.length - 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252540),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Leg header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB300),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'LEG ${idx + 1}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${labels.length} stops',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              const Spacer(),
                              if (!isLast)
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.link, color: Colors.white38, size: 14),
                                    SizedBox(width: 4),
                                    Text('→ Leg ${1}',
                                        style: TextStyle(
                                            color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        // Pandal list
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Column(
                            children: [
                              for (int i = 0; i < labels.length; i++)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: i == 0
                                              ? Colors.greenAccent
                                                  .withValues(alpha: 0.2)
                                              : i == labels.length - 1
                                                  ? Colors.redAccent
                                                      .withValues(alpha: 0.2)
                                                  : const Color(0xFFFFB300)
                                                      .withValues(alpha: 0.15),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            color: i == 0
                                                ? Colors.greenAccent
                                                : i == labels.length - 1
                                                    ? Colors.redAccent
                                                    : const Color(0xFFFFD54F),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          labels[i],
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (i == 0)
                                        const Text('START',
                                            style: TextStyle(
                                                color: Colors.greenAccent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      if (i == labels.length - 1)
                                        const Text('END',
                                            style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Launch button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB300),
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final url = Uri.parse(leg.key);
                                await openExternalLink(context, url);
                              },
                              icon:
                                  const Icon(Icons.navigation_rounded, size: 16),
                              label: Text(
                                'Open Leg ${idx + 1} in Google Maps',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (onToggleCoordinates != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onToggleCoordinates,
                    icon: Icon(
                      isUsingCoordinates
                          ? Icons.label_rounded
                          : Icons.gps_fixed_rounded,
                      size: 15,
                      color: const Color(0xFFFFB300),
                    ),
                    label: Text(
                      isUsingCoordinates
                          ? 'Switch to Readable Pandal Names'
                          : 'Having trouble? Open with GPS coordinates',
                      style: const TextStyle(
                        color: Color(0xFFFFB300),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),

            // Launch all button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE62E2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    for (int i = 0; i < legs.length; i++) {
                      final url = Uri.parse(legs[i].key);
                      if (!context.mounted) return;
                      if (await openExternalLink(context, url)) {
                        if (i < legs.length - 1) {
                          await Future.delayed(const Duration(seconds: 2));
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(
                    'Launch All ${legs.length} Legs at Once',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
