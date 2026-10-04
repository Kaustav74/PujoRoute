import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/external_links.dart';
import '../data/pujas_data.dart';
import 'circuit_studio_screen.dart';
import 'pandal_passport_screen.dart';
import 'puja_calendar_screen.dart';
import '../services/session_service.dart';
import '../services/spatial_facility_service.dart';

// Pujo Festive Theme Palette
const Color kMidnightBlue =
    Color(0xFF0D0D1E); // Deep Midnight Blue / Rich Charcoal
const Color kSindoorRed =
    Color(0xFFE62E2D); // Electric Vermillion / Sindoor Red
const Color kMarigoldAmber = Color(0xFFFFB300); // Glowing Marigold / Warm Amber
const Color kTranslucentObsidian =
    Color(0xCC1C1C2E); // Translucent Obsidian (Card Backgrounds - 80% Opacity)

/// Helper class for dynamic pin clustering on OpenStreetMap canvas
class _PandalCluster {
  final LatLng center;
  final List<Pandal> pandals;
  const _PandalCluster({required this.center, required this.pandals});
  bool get isSingle => pandals.length == 1;
}

class MapScreen extends StatefulWidget {
  final double? targetLat;
  final double? targetLng;
  final String? selectedName;

  const MapScreen({
    super.key,
    this.targetLat,
    this.targetLng,
    this.selectedName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Map and Location
  final MapController _mapController = MapController();
  // Default to Kolkata South/Kasba/Dhakuria region where festival density is high
  LatLng _userPosition = const LatLng(22.5152, 88.3845);
  double _currentZoom = 13.8;
  StreamSubscription<Position>? _positionStreamSub;

  // Pulse animation for live continuous GPS tracking (Auto-paused on idle / full sheet)
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSheetExpanded = false;

  // Filters
  bool _filterMega = true;
  bool _filterHeritage = true;
  String _selectedZone =
      'All'; // 'All', 'Bookmarked ⭐', 'Visited ✅', 'North', 'South', 'Salt Lake', 'Central'
  String _searchQuery = '';
  bool _tilesUnavailable = false;
  final TextEditingController _searchController = TextEditingController();

  // Selection & Circuit
  String? _selectedPandalId;
  List<Pandal> _hoppingCircuit = [];
  bool _isCircuitActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.selectedName != null && widget.selectedName!.isNotEmpty) {
      _searchQuery = widget.selectedName!;
      _searchController.text = widget.selectedName!;
    }

    _restoreSessionState();
    _startLiveContinuousTracking();

    if (widget.targetLat != null && widget.targetLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(widget.targetLat!, widget.targetLng!), 16.5);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_pulseController.isAnimating) _pulseController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_pulseController.isAnimating && !_isSheetExpanded) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  void _pauseMapAnimations() {
    if (_pulseController.isAnimating) _pulseController.stop();
  }

  void _resumeMapAnimations() {
    if (!_pulseController.isAnimating && !_isSheetExpanded) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _restoreSessionState() {
    final session = SessionService.instance;
    _filterMega = session.filterMega;
    _filterHeritage = session.filterHeritage;
    _selectedZone = session.selectedZone;

    if (session.lastLat != null && session.lastLon != null) {
      _userPosition = LatLng(session.lastLat!, session.lastLon!);
    }

    if (session.isCircuitActive && session.activeCircuitIds.isNotEmpty) {
      final Map<String, Pandal> pujaMap = {
        for (var p in kAllKolkataPujas) p.id: p
      };
      final restored = <Pandal>[];
      for (var id in session.activeCircuitIds) {
        if (pujaMap.containsKey(id)) {
          restored.add(pujaMap[id]!);
        }
      }
      if (restored.isNotEmpty) {
        _hoppingCircuit = restored;
        _isCircuitActive = true;
      }
    }
  }

  void _loadPersistedState() {
    setState(() {
      _restoreSessionState();
    });
  }

  // Live continuous GPS tracking with stream subscription
  Future<void> _startLiveContinuousTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // First fast initial location lookup. A cold GPS fix can exceed the
        // 4 s limit; that must not prevent the live stream below from starting.
        try {
          final initialPos = await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.medium,
                timeLimit: const Duration(seconds: 4),
              );
          if (!mounted) return;
          _handleNewLocation(initialPos.latitude, initialPos.longitude,
              notifyOutside: true);
        } catch (_) {
          // Keep the fallback position until the stream delivers a fix.
        }
        if (!mounted) return;

        // Continuous location stream for real-time tracking
        _positionStreamSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 8,
          ),
        ).listen((pos) {
          if (!mounted) return;
          _handleNewLocation(pos.latitude, pos.longitude, notifyOutside: false);
        }, onError: (_) {
          // Location services switched off mid-session: keep last position.
        });
      }
    } catch (_) {
      // Fallback position already active
    }
  }

  void _handleNewLocation(double lat, double lon,
      {bool notifyOutside = false}) {
    // If outside Kolkata/West Bengal (e.g. US emulator), snap to central Kolkata festival hub
    if (lat < 21.0 || lat > 27.5 || lon < 85.0 || lon > 90.0) {
      lat = 22.5152;
      lon = 88.3845;
      if (notifyOutside && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: kTranslucentObsidian,
            content: Text(
              '📍 Outside Kolkata detected: Snapped to South Kolkata Festival Hub',
              style:
                  TextStyle(color: kMarigoldAmber, fontWeight: FontWeight.bold),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _userPosition = LatLng(lat, lon);
    });
    SessionService.instance.saveLastPosition(lat, lon);
  }

  // Accurate Haversine Distance in meters
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
    return (r * c * 1.25); // 1.25x for Kolkata street turns
  }

  List<Pandal> _getSortedFilteredPandals() {
    List<Pandal> list = kAllKolkataPujas.where((p) {
      // Category filter
      if (p.category == 'mega' && !_filterMega) return false;
      if (p.category == 'heritage' && !_filterHeritage) return false;

      // Zone & Session Filters
      if (_selectedZone == 'Bookmarked ⭐') {
        if (!SessionService.instance.isBookmarked(p.id)) return false;
      } else if (_selectedZone == 'Visited ✅') {
        if (!SessionService.instance.isVisited(p.id)) return false;
      } else if (_selectedZone != 'All' && p.zone != _selectedZone) {
        return false;
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchLandmark = p.landmark.toLowerCase().contains(q);
        final matchMetro = p.metroStation.toLowerCase().contains(q);
        final matchSubsection = p.subsection.toLowerCase().contains(q);
        if (!matchName && !matchLandmark && !matchMetro && !matchSubsection) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort by proximity to user position
    list.sort((a, b) {
      final distA = _getDistanceMeters(
          _userPosition.latitude, _userPosition.longitude, a.lat, a.lon);
      final distB = _getDistanceMeters(
          _userPosition.latitude, _userPosition.longitude, b.lat, b.lon);
      return distA.compareTo(distB);
    });

    return list;
  }

  // Dynamic Pin Clustering algorithm based on current zoom level
  List<_PandalCluster> _buildClusters(List<Pandal> pandals, double zoom) {
    if (zoom >= 14.1 || pandals.length <= 1) {
      return pandals
          .map(
              (p) => _PandalCluster(center: LatLng(p.lat, p.lon), pandals: [p]))
          .toList();
    }

    // Adaptive grid cell size in degrees based on map zoom
    final double cellSize = 0.038 * pow(0.62, (zoom - 10.0).clamp(0.0, 4.2));
    final Map<String, List<Pandal>> grid = {};

    for (var p in pandals) {
      final int gx = (p.lat / cellSize).floor();
      final int gy = (p.lon / cellSize).floor();
      final key = '$gx:$gy';
      grid.putIfAbsent(key, () => []).add(p);
    }

    final List<_PandalCluster> clusters = [];
    for (var group in grid.values) {
      if (group.isEmpty) continue;
      double sumLat = 0;
      double sumLon = 0;
      for (var p in group) {
        sumLat += p.lat;
        sumLon += p.lon;
      }
      clusters.add(_PandalCluster(
        center: LatLng(sumLat / group.length, sumLon / group.length),
        pandals: group,
      ));
    }
    return clusters;
  }

  // Find next closest unvisited pandal for smart routing prompt
  Pandal? _findNextBestPandal(Pandal current) {
    final unvisited = kAllKolkataPujas
        .where((p) =>
            p.id != current.id && !SessionService.instance.isVisited(p.id))
        .toList();
    if (unvisited.isEmpty) return null;
    unvisited.sort((a, b) {
      final distA = _getDistanceMeters(current.lat, current.lon, a.lat, a.lon);
      final distB = _getDistanceMeters(current.lat, current.lon, b.lat, b.lon);
      return distA.compareTo(distB);
    });
    return unvisited.first;
  }

  Future<void> _openGoogleMapsWalking(Pandal p) async {
    final destination = Uri.encodeComponent('${p.name}, Kolkata');
    final bool hasUserLoc =
        _userPosition.latitude != 0.0 && _userPosition.longitude != 0.0;
    final String urlString;
    if (hasUserLoc) {
      final origin =
          '${_userPosition.latitude.toStringAsFixed(5)},${_userPosition.longitude.toStringAsFixed(5)}';
      urlString =
          'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking';
    } else {
      urlString =
          'https://www.google.com/maps/search/?api=1&query=$destination';
    }
    final url = Uri.parse(urlString);
    try {
      if (!mounted) return;
      await openExternalLink(context, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kTranslucentObsidian,
            content: Text('Navigating to ${p.name}',
                style: const TextStyle(color: kMarigoldAmber)),
          ),
        );
      }
    }
  }

  Future<void> _openGoogleMapsCircuitWalking(List<Pandal> stops) async {
    if (stops.isEmpty) return;
    if (stops.length == 1) {
      return _openGoogleMapsWalking(stops.first);
    }
    final bool hasUserLoc =
        _userPosition.latitude != 0.0 && _userPosition.longitude != 0.0;
    final origin = hasUserLoc
        ? '${_userPosition.latitude.toStringAsFixed(5)},${_userPosition.longitude.toStringAsFixed(5)}'
        : '${stops.first.lat.toStringAsFixed(5)},${stops.first.lon.toStringAsFixed(5)}';
    final destination = Uri.encodeComponent('${stops.last.name}, Kolkata');

    final intermediateStops = hasUserLoc
        ? stops.sublist(0, stops.length - 1)
        : (stops.length > 2 ? stops.sublist(1, stops.length - 1) : <Pandal>[]);
    final waypoints = intermediateStops
        .take(9)
        .map((p) => Uri.encodeComponent('${p.name}, Kolkata'))
        .join('|');

    String urlString =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking';
    if (waypoints.isNotEmpty) {
      urlString += '&waypoints=$waypoints';
    }

    final url = Uri.parse(urlString);

    try {
      if (!mounted) return;
      await openExternalLink(context, url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: kTranslucentObsidian,
            content: Text('Opening Google Maps route...',
                style: TextStyle(color: kMarigoldAmber)),
          ),
        );
      }
    }
  }

  // Enhanced Detailed Pandal Sheet with Ritual Timings, Metro Exit Gate, and Sculptor Credits
  void _showPandalDetailsModal(Pandal p, int distMeters, int durMins) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: const Color(0xFF141424),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
              top: BorderSide(
                  color:
                      p.category == 'heritage' ? kMarigoldAmber : kSindoorRed,
                  width: 3)),
          boxShadow: [
            BoxShadow(
                color: (p.category == 'heritage' ? kMarigoldAmber : kSindoorRed)
                    .withOpacity(0.3),
                blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            // Modal Grab Handle
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.category == 'heritage'
                                ? kMarigoldAmber.withOpacity(0.18)
                                : kSindoorRed.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: p.category == 'heritage'
                                  ? kMarigoldAmber
                                  : kSindoorRed,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            p.category == 'heritage'
                                ? Icons.account_balance
                                : Icons.local_fire_department,
                            color: p.category == 'heritage'
                                ? kMarigoldAmber
                                : kSindoorRed,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${p.category == 'heritage' ? '🏛️ Bonedi Bari (Heritage)' : '🔥 Mega Theme'} • ${p.zone} Kolkata',
                                style: TextStyle(
                                  color: p.category == 'heritage'
                                      ? kMarigoldAmber
                                      : kSindoorRed,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Metro Connectivity & Kolkata Police Traffic Barricade Advisory
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2636),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_subway,
                                  color: Colors.cyanAccent, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'METRO GATE & ENTRY/EXIT ORIENTATION',
                                style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 0.8),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            p.detailedMetroGate,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          if (p.barricadeAdvisory.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2210),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.amber.withOpacity(0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('🚧 ',
                                      style: TextStyle(fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      'Police Advisory: ${p.barricadeAdvisory}',
                                      style: const TextStyle(
                                          color: Color(0xFFFFE082),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 12),

                    // Cultural Significance & Heritage Background
                    const Text(
                      '🏛️ CULTURAL SIGNIFICANCE & HERITAGE',
                      style: TextStyle(
                          color: kMarigoldAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.history,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13, height: 1.45),
                    ),
                    const SizedBox(height: 12),

                    // Landmark & Subsections
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${p.landmark} • ${p.subsection}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Facilities chips - Dynamic Spatial Facility Engine
                    Builder(
                      builder: (context) {
                        final fac = SpatialFacilityService.instance
                            .getNearestFacilities(p);
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: fac.chips
                              .map((f) => Chip(
                                    backgroundColor: const Color(0xFF222234),
                                    visualDensity: VisualDensity.compact,
                                    label: Text(f,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11)),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),

            // Modal Action Bar with Session Persistence & Next-Best-Stop Prompt
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF10101C),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  final bool isBookmarked =
                      SessionService.instance.isBookmarked(p.id);
                  final bool isVisited =
                      SessionService.instance.isVisited(p.id);

                  return Row(
                    children: [
                      // Direct Google Maps Navigation
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSindoorRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 4,
                            shadowColor: kSindoorRed.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openGoogleMapsWalking(p);
                          },
                          icon: const Icon(Icons.navigation, size: 18),
                          label: const Text('Navigate Maps',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Bookmark Button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: isBookmarked
                              ? kMarigoldAmber.withOpacity(0.3)
                              : const Color(0xFF26263A),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: isBookmarked
                            ? 'Remove Bookmark'
                            : 'Bookmark Pandal',
                        icon: Icon(
                          isBookmarked ? Icons.star : Icons.star_border,
                          color: kMarigoldAmber,
                          size: 20,
                        ),
                        onPressed: () async {
                          await SessionService.instance.toggleBookmark(p.id);
                          setModalState(() {});
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 6),

                      // Visited Button with Smart Next-Best-Stop recommendation
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: isVisited
                              ? Colors.green.withOpacity(0.3)
                              : const Color(0xFF26263A),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: isVisited
                            ? 'Mark as Not Visited'
                            : 'Mark as Visited',
                        icon: Icon(
                          isVisited
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color:
                              isVisited ? Colors.greenAccent : Colors.white54,
                          size: 20,
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(ctx);
                          await SessionService.instance.toggleVisited(p.id);
                          final bool isNowVisited =
                              SessionService.instance.isVisited(p.id);
                          setModalState(() {});
                          setState(() {});

                          if (isNowVisited && mounted) {
                            final nextPandal = _findNextBestPandal(p);
                            if (nextPandal != null && mounted) {
                              final nextDist = _getDistanceMeters(p.lat, p.lon,
                                      nextPandal.lat, nextPandal.lon)
                                  .round();
                              nav.pop();
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF1E1428),
                                  duration: const Duration(seconds: 6),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                        color: Colors.greenAccent, width: 1.5),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: Colors.greenAccent,
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Visited: ${p.name}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '🎯 Next Best Stop: ${nextPandal.name} (~${nextDist > 1000 ? (nextDist / 1000).toStringAsFixed(1) : nextDist}${nextDist > 1000 ? 'km' : 'm'} away)',
                                        style: const TextStyle(
                                            color: kMarigoldAmber,
                                            fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  action: SnackBarAction(
                                    label: 'ROUTE NEXT',
                                    textColor: Colors.greenAccent,
                                    onPressed: () {
                                      _mapController.move(
                                          LatLng(
                                              nextPandal.lat, nextPandal.lon),
                                          15.5);
                                      _openGoogleMapsWalking(nextPandal);
                                    },
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 6),

                      // Circuit Button
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: kMarigoldAmber.withOpacity(0.2),
                          padding: const EdgeInsets.all(12),
                        ),
                        tooltip: 'Add to Circuit',
                        icon: const Icon(Icons.playlist_add,
                            color: kMarigoldAmber, size: 20),
                        onPressed: () {
                          setState(() {
                            if (!_hoppingCircuit.contains(p)) {
                              _hoppingCircuit.add(p);
                              _isCircuitActive = true;
                            }
                          });
                          SessionService.instance.saveCircuit(
                              _hoppingCircuit.map((x) => x.id).toList(), true);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: kTranslucentObsidian,
                              content: Text(
                                'Added ${p.name} to hopping circuit (${_hoppingCircuit.length} stops)',
                                style: const TextStyle(color: kMarigoldAmber),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyOfflineCard() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTranslucentObsidian,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: kSindoorRed, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: kSindoorRed, size: 26),
            SizedBox(width: 10),
            Text('Offline Emergency Pass',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KOLKATA POLICE PUJA HELPLINES',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildEmergencyTile('Lalbazar Control Room',
                  '100 / 033-2214-3230', Icons.local_police),
              _buildEmergencyTile(
                  'Women Helpline', '1091', Icons.support_agent),
              _buildEmergencyTile(
                  'Ambulance / Medical', '102 / 108', Icons.medical_services),
              _buildEmergencyTile(
                  'Fire Brigade', '101', Icons.local_fire_department),
              _buildEmergencyTile(
                  'Rail / Metro Helpline (RailMadad)', '139', Icons.directions_subway),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: kSindoorRed,
              side: const BorderSide(color: kSindoorRed),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Delete My Data',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _confirmShredUserData(ctx),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(
                    color: kMarigoldAmber, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyTile(String title, String phone, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF222236),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: kSindoorRed, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Text(phone,
              style: const TextStyle(
                  color: kMarigoldAmber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmShredUserData(BuildContext parentCtx) {
    showDialog(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E141E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kSindoorRed, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: kSindoorRed, size: 24),
            SizedBox(width: 8),
            Text('Delete all app data?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This permanently deletes everything PujoRoute stores on this phone: bookmarks, visited pandals (Passport stamps), your saved circuit, last map position and your emergency contact / blood group.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmCtx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kSindoorRed),
            onPressed: () async {
              Navigator.pop(confirmCtx);
              Navigator.pop(parentCtx);
              await SessionService.instance.secureShredUserData();
              if (mounted) {
                _loadPersistedState();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: kTranslucentObsidian,
                    content: Text(
                      '🔒 All PujoRoute data on this device has been deleted.',
                      style: TextStyle(
                          color: kMarigoldAmber, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleList = _getSortedFilteredPandals();
    final int megaCount =
        kAllKolkataPujas.where((p) => p.category == 'mega').length;
    final int heritageCount =
        kAllKolkataPujas.where((p) => p.category == 'heritage').length;
    final clusters = _buildClusters(visibleList, _currentZoom);

    // Polyline points for hopping circuit
    List<LatLng> circuitPoints = [];
    if (_isCircuitActive && _hoppingCircuit.isNotEmpty) {
      circuitPoints.add(_userPosition);
      circuitPoints.addAll(_hoppingCircuit.map((p) => LatLng(p.lat, p.lon)));
    }

    return Scaffold(
      backgroundColor: kMidnightBlue,
      body: Stack(
        children: [
          // ==========================================
          // 1. FULL CANVAS OPENSTREETMAP VIEW
          // ==========================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userPosition,
              initialZoom: _currentZoom,
              maxZoom: 18.0,
              minZoom: 10.0,
              onPositionChanged: (pos, hasGesture) {
                if ((pos.zoom - _currentZoom).abs() > 0.15) {
                  setState(() => _currentZoom = pos.zoom);
                }
              },
            ),
            children: [
              // OpenStreetMap Standard Tiles (Fast, Free, Local Memory & Disk Buffer Caching)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.pujoroute.app',
                maxZoom: 18.0,
                keepBuffer: 3,
                panBuffer: 1,
                // No network: show a neutral placeholder tile instead of blank
                // squares, and tell the user the rest of the app still works.
                errorImage: const AssetImage('assets/images/offline_tile.png'),
                errorTileCallback: (tile, error, stackTrace) {
                  if (!_tilesUnavailable && mounted) {
                    setState(() => _tilesUnavailable = true);
                  }
                },
              ),

              // Active Hopping Circuit Polyline in Sindoor Red
              if (_isCircuitActive && circuitPoints.length > 1)
                PolylineLayer<Object>(
                  polylines: [
                    Polyline(
                      points: circuitPoints,
                      strokeWidth: 4.5,
                      color: kSindoorRed,
                    ),
                  ],
                ),

              // Markers Layer: Live GPS Pin + Dynamic Clusters
              MarkerLayer(
                markers: [
                  // Live Continuous GPS Marker with Animated Radar Pulse Ring
                  Marker(
                    point: _userPosition,
                    width: 60,
                    height: 60,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing accuracy outer wave
                            Container(
                              width: 32 * _pulseAnimation.value,
                              height: 32 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.cyanAccent.withOpacity(
                                    (0.35 / _pulseAnimation.value)
                                        .clamp(0.0, 0.4)),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(
                                      (0.6 / _pulseAnimation.value)
                                          .clamp(0.0, 0.6)),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Center Glowing Pin
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kSindoorRed,
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                      color: kSindoorRed.withOpacity(0.8),
                                      blurRadius: 10),
                                ],
                              ),
                              child: const Center(
                                child: Icon(Icons.person_pin_circle,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Dynamic Pandal Pin Clusters
                  ...clusters.map((cluster) {
                    if (!cluster.isSingle) {
                      // Numbered Cluster Badge (+N)
                      return Marker(
                        point: cluster.center,
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () {
                            final targetZoom =
                                (_currentZoom + 1.8).clamp(10.0, 16.5);
                            _mapController.move(cluster.center, targetZoom);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [kSindoorRed, Color(0xFF7A0A10)],
                                center: Alignment.topLeft,
                                radius: 0.9,
                              ),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: kMarigoldAmber, width: 2.2),
                              boxShadow: [
                                BoxShadow(
                                  color: kSindoorRed.withOpacity(0.65),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '+${cluster.pandals.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // Individual Pandal Pin
                    final p = cluster.pandals.first;
                    final bool isMega = p.category == 'mega';
                    final bool isSelected = p.id == _selectedPandalId;
                    final int indexInCircuit = _hoppingCircuit.indexOf(p);

                    return Marker(
                      point: LatLng(p.lat, p.lon),
                      width: isSelected ? 50 : 38,
                      height: isSelected ? 50 : 38,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedPandalId = p.id);
                          final dist = _getDistanceMeters(
                                  _userPosition.latitude,
                                  _userPosition.longitude,
                                  p.lat,
                                  p.lon)
                              .round();
                          final dur = max(1, (dist / 75).round());
                          _showPandalDetailsModal(p, dist, dur);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: isMega
                                ? const LinearGradient(
                                    colors: [kSindoorRed, Color(0xFFFF5252)])
                                : const LinearGradient(colors: [
                                    kMarigoldAmber,
                                    Color(0xFFFF8F00)
                                  ]),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.black87,
                              width: isSelected ? 3.5 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isMega ? kSindoorRed : kMarigoldAmber)
                                    .withOpacity(0.7),
                                blurRadius: isSelected ? 14 : 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: indexInCircuit >= 0
                                ? Text(
                                    '${indexInCircuit + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  )
                                : (SessionService.instance.isVisited(p.id)
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 20)
                                    : (SessionService.instance
                                            .isBookmarked(p.id)
                                        ? const Icon(Icons.star,
                                            color: Colors.white, size: 20)
                                        : Icon(
                                            isMega
                                                ? Icons.local_fire_department
                                                : Icons.account_balance,
                                            color: isMega
                                                ? Colors.white
                                                : Colors.black87,
                                            size: isSelected ? 24 : 18,
                                          ))),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              if (_tilesUnavailable)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Material(
                      color: kTranslucentObsidian,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _tilesUnavailable = false),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Text(
                            'Map tiles need internet. Pandals, planner & calendar work offline. (tap to hide)',
                            style: TextStyle(color: kMarigoldAmber, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Required OpenStreetMap attribution (tile usage policy)
              // Always-visible (non-collapsing) attribution, as OSM requires.
              SimpleAttributionWidget(
                alignment: Alignment.bottomLeft,
                backgroundColor: Colors.black54,
                source: const Text(
                  'OpenStreetMap contributors',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                onTap: () => openExternalLink(context,
                    Uri.parse('https://www.openstreetmap.org/copyright')),
              ),
            ],
          ),

          // ==========================================
          // 2. FLOATING TOP HEADER & FILTER PILLS
          // ==========================================
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Frosted Glass Search Bar with Durga Maa Clean Logo
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xEE121222),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: kMarigoldAmber.withOpacity(0.35), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.55),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Sacred Bengali Durga Maa Logo Avatar
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kMarigoldAmber, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: kMarigoldAmber.withOpacity(0.4),
                                blurRadius: 6),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/durga_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: kSindoorRed,
                              child: const Icon(Icons.temple_hindu,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Search Input Field
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Search 504 pandals, metro, zones...',
                            hintStyle: const TextStyle(
                                color: Colors.white38, fontSize: 12.5),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear,
                                        color: Colors.white54, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Emergency Offline Pass Shortcut
                      IconButton(
                        icon: const Icon(Icons.shield_outlined,
                            color: Colors.white60, size: 20),
                        tooltip: 'Offline Emergency Pass',
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        onPressed: _showEmergencyOfflineCard,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Minimalist Collapsible Filter Pills Bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Mega Theme Pill
                      _buildFilterPill(
                        label: '🔥 Mega ($megaCount)',
                        isActive: _filterMega,
                        activeColor: kSindoorRed,
                        onTap: () {
                          setState(() {
                            _filterMega = !_filterMega;
                            if (!_filterMega && !_filterHeritage) {
                              _filterHeritage = true;
                            }
                          });
                          SessionService.instance.saveFilters(
                              zone: _selectedZone,
                              mega: _filterMega,
                              heritage: _filterHeritage);
                        },
                      ),
                      const SizedBox(width: 6),

                      // Bonedi Bari Heritage Pill
                      _buildFilterPill(
                        label: '🏛️ Bonedi Bari ($heritageCount)',
                        isActive: _filterHeritage,
                        activeColor: kMarigoldAmber,
                        textColor:
                            _filterHeritage ? Colors.black87 : Colors.white70,
                        onTap: () {
                          setState(() {
                            _filterHeritage = !_filterHeritage;
                            if (!_filterMega && !_filterHeritage) {
                              _filterMega = true;
                            }
                          });
                          SessionService.instance.saveFilters(
                              zone: _selectedZone,
                              mega: _filterMega,
                              heritage: _filterHeritage);
                        },
                      ),
                      const SizedBox(width: 6),

                      // Bookmarked Pill
                      _buildFilterPill(
                        label:
                            '⭐ Saved (${SessionService.instance.bookmarkedIds.length})',
                        isActive: _selectedZone == 'Bookmarked ⭐',
                        activeColor: kMarigoldAmber,
                        textColor: _selectedZone == 'Bookmarked ⭐'
                            ? Colors.black87
                            : Colors.white70,
                        onTap: () {
                          setState(() {
                            _selectedZone = _selectedZone == 'Bookmarked ⭐'
                                ? 'All'
                                : 'Bookmarked ⭐';
                          });
                          SessionService.instance.saveFilters(
                              zone: _selectedZone,
                              mega: _filterMega,
                              heritage: _filterHeritage);
                        },
                      ),
                      const SizedBox(width: 6),

                      // Visited Pill
                      _buildFilterPill(
                        label:
                            '✅ Visited (${SessionService.instance.visitedIds.length})',
                        isActive: _selectedZone == 'Visited ✅',
                        activeColor: Colors.greenAccent,
                        textColor: _selectedZone == 'Visited ✅'
                            ? Colors.black87
                            : Colors.white70,
                        onTap: () {
                          setState(() {
                            _selectedZone = _selectedZone == 'Visited ✅'
                                ? 'All'
                                : 'Visited ✅';
                          });
                          SessionService.instance.saveFilters(
                              zone: _selectedZone,
                              mega: _filterMega,
                              heritage: _filterHeritage);
                        },
                      ),
                      const SizedBox(width: 6),

                      // Kolkata Zones Pills
                      ...['North', 'South', 'Salt Lake', 'Central'].map((zone) {
                        final isSelected = _selectedZone == zone;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildFilterPill(
                            label: zone,
                            isActive: isSelected,
                            activeColor: const Color(0xFF3F3D56),
                            onTap: () {
                              setState(() =>
                                  _selectedZone = isSelected ? 'All' : zone);
                              SessionService.instance.saveFilters(
                                  zone: _selectedZone,
                                  mega: _filterMega,
                                  heritage: _filterHeritage);
                            },
                          ),
                        );
                      }),

                      // 2026 AI Calendar Pill Shortcut
                      _buildFilterPill(
                        label: '🪔 2026 Tithis',
                        isActive: false,
                        activeColor: Colors.transparent,
                        borderColor: kMarigoldAmber.withOpacity(0.55),
                        textColor: kMarigoldAmber,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PujaCalendarScreen(
                                userLat: _userPosition.latitude,
                                userLon: _userPosition.longitude,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // 3. FLOATING ACTION CONTROLS ON MAP
          // ==========================================
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * 0.30,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps',
              backgroundColor: const Color(0xEE16162A),
              foregroundColor: kMarigoldAmber,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: kMarigoldAmber.withOpacity(0.4)),
              ),
              onPressed: () {
                _mapController.move(_userPosition, 15.0);
              },
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),

          // Floating Hopping Circuit Banner
          if (_isCircuitActive && _hoppingCircuit.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 100,
              left: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xF21C1C2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kSindoorRed, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.route, color: kMarigoldAmber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CircuitStudioScreen(
                                userLat: _userPosition.latitude,
                                userLon: _userPosition.longitude,
                              ),
                            ),
                          ).then((_) => _loadPersistedState());
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hop Circuit Active (${_hoppingCircuit.length} Stops)',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const Text(
                              'Tap to customize in Studio ▾',
                              style: TextStyle(
                                  color: kMarigoldAmber,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Multi-Stop Google Maps Navigation Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSindoorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.navigation, size: 13),
                      label: const Text('Maps',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () =>
                          _openGoogleMapsCircuitWalking(_hoppingCircuit),
                    ),
                    const SizedBox(width: 2),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 18),
                      onPressed: () {
                        setState(() {
                          _isCircuitActive = false;
                          _hoppingCircuit.clear();
                        });
                        SessionService.instance.clearCircuit();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ==========================================
          // 4. GESTURE-DRIVEN EXPANDABLE BOTTOM SHEET (Battery & Frame Capping)
          // ==========================================
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              final isExpanded = notification.extent > 0.65;
              if (isExpanded != _isSheetExpanded) {
                _isSheetExpanded = isExpanded;
                if (isExpanded) {
                  _pauseMapAnimations();
                } else {
                  _resumeMapAnimations();
                }
              }
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.28,
              minChildSize: 0.11,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.11, 0.28, 0.85],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10101E),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                          color: kMarigoldAmber.withOpacity(0.35), width: 1.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.7),
                          blurRadius: 18,
                          offset: const Offset(0, -5)),
                    ],
                  ),
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      // Handle & Title Bar
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            // Drag Handle Pill
                            Container(
                              width: 38,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: Colors.white30,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.near_me,
                                          color: kSindoorRed, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'NEAREST TO YOU (${visibleList.length})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Circuit Studio Shortcut
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          kSindoorRed.withOpacity(0.18),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.alt_route,
                                        color: kMarigoldAmber, size: 14),
                                    label: const Text(
                                      'Route Planner',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CircuitStudioScreen(
                                            userLat: _userPosition.latitude,
                                            userLon: _userPosition.longitude,
                                          ),
                                        ),
                                      ).then((_) => _loadPersistedState());
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Colors.white12),
                          ],
                        ),
                      ),

                      // Scrollable Pandal Cards
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final p = visibleList[index];
                              final bool isMega = p.category == 'mega';
                              final bool isSelected = p.id == _selectedPandalId;
                              final double rawDist = _getDistanceMeters(
                                  _userPosition.latitude,
                                  _userPosition.longitude,
                                  p.lat,
                                  p.lon);
                              final int distMeters = rawDist.round();
                              final int durMins =
                                  max(1, (distMeters / 75).round());

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _selectedPandalId = p.id);
                                    _mapController.move(
                                        LatLng(p.lat, p.lon), 15.5);
                                    _showPandalDetailsModal(
                                        p, distMeters, durMins);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF28283E)
                                          : kTranslucentObsidian,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? kMarigoldAmber
                                            : (isMega
                                                ? kSindoorRed.withOpacity(0.2)
                                                : kMarigoldAmber
                                                    .withOpacity(0.25)),
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Category Badge
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isMega
                                                ? kSindoorRed.withOpacity(0.18)
                                                : kMarigoldAmber
                                                    .withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Information Column
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      p.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14.5),
                                                    ),
                                                  ),
                                                  if (SessionService.instance
                                                      .isVisited(p.id))
                                                    const Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 4),
                                                      child: Icon(
                                                          Icons.check_circle,
                                                          color: Colors
                                                              .greenAccent,
                                                          size: 15),
                                                    ),
                                                  if (SessionService.instance
                                                      .isBookmarked(p.id))
                                                    const Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 4),
                                                      child: Icon(Icons.star,
                                                          color: kMarigoldAmber,
                                                          size: 15),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Text(
                                                    distMeters > 1000
                                                        ? '${(distMeters / 1000).toStringAsFixed(1)} km away'
                                                        : '$distMeters m away',
                                                    style: const TextStyle(
                                                        color: kMarigoldAmber,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11.5),
                                                  ),
                                                  const Text(' • ',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white38)),
                                                  Text('~$durMins min walk',
                                                      style: const TextStyle(
                                                          color: Colors.white60,
                                                          fontSize: 11.5)),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Icon(Icons.explore_outlined,
                                                      color: kMarigoldAmber
                                                          .withOpacity(0.85),
                                                      size: 12),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      p.subsection,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: kMarigoldAmber,
                                                          fontSize: 10.5,
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.place_outlined,
                                                      color: Colors.white38,
                                                      size: 12),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      p.landmark,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 10),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Actions: Maps + Bookmark / Visited
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: kSindoorRed,
                                                foregroundColor: Colors.white,
                                                elevation: 2,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 9,
                                                        vertical: 5),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              onPressed: () =>
                                                  _openGoogleMapsWalking(p),
                                              icon: const Icon(Icons.navigation,
                                                  size: 12),
                                              label: const Text('Maps',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                InkWell(
                                                  onTap: () async {
                                                    await SessionService
                                                        .instance
                                                        .toggleBookmark(p.id);
                                                    setState(() {});
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    child: Icon(
                                                      SessionService.instance
                                                              .isBookmarked(
                                                                  p.id)
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      color: kMarigoldAmber,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: () async {
                                                    final messenger =
                                                        ScaffoldMessenger.of(
                                                            context);
                                                    await SessionService
                                                        .instance
                                                        .toggleVisited(p.id);
                                                    final isVisited =
                                                        SessionService.instance
                                                            .isVisited(p.id);
                                                    setState(() {});
                                                    if (isVisited && mounted) {
                                                      final next =
                                                          _findNextBestPandal(
                                                              p);
                                                      if (next != null &&
                                                          mounted) {
                                                        final nextDist =
                                                            _getDistanceMeters(
                                                                    p.lat,
                                                                    p.lon,
                                                                    next.lat,
                                                                    next.lon)
                                                                .round();
                                                        messenger
                                                            .hideCurrentSnackBar();
                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                            backgroundColor:
                                                                const Color(
                                                                    0xFF1E1428),
                                                            duration:
                                                                const Duration(
                                                                    seconds: 5),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              side: const BorderSide(
                                                                  color: Colors
                                                                      .greenAccent),
                                                            ),
                                                            content: Text(
                                                              'Visited ${p.name}! Next: ${next.name} (~$nextDist m)',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12),
                                                            ),
                                                            action:
                                                                SnackBarAction(
                                                              label: 'ROUTE',
                                                              textColor: Colors
                                                                  .greenAccent,
                                                              onPressed: () =>
                                                                  _openGoogleMapsWalking(
                                                                      next),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(3),
                                                    child: Icon(
                                                      SessionService.instance
                                                              .isVisited(p.id)
                                                          ? Icons.check_circle
                                                          : Icons
                                                              .check_circle_outline,
                                                      color: SessionService
                                                              .instance
                                                              .isVisited(p.id)
                                                          ? Colors.greenAccent
                                                          : Colors.white38,
                                                      size: 18,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: visibleList.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ==========================================
      // 5. PERSISTENT 3-TAB BOTTOM NAVIGATION BAR
      // ==========================================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xF20D0D1E), // 95% obsidian
          border:
              const Border(top: BorderSide(color: Colors.white12, width: 0.8)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.map_rounded,
                  label: 'Explore',
                  isSelected: true,
                  onTap: () {},
                ),
                _buildNavItem(
                  icon: Icons.alt_route_rounded,
                  label: 'Route Planner',
                  isSelected: false,
                  badgeCount: _hoppingCircuit.isNotEmpty
                      ? _hoppingCircuit.length
                      : null,
                  onTap: () {
                    _pauseMapAnimations();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CircuitStudioScreen(
                          userLat: _userPosition.latitude,
                          userLon: _userPosition.longitude,
                        ),
                      ),
                    ).then((_) {
                      _resumeMapAnimations();
                      _loadPersistedState();
                    });
                  },
                ),
                _buildNavItem(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Passport',
                  isSelected: false,
                  badgeCount: SessionService.instance.visitedIds.isNotEmpty
                      ? SessionService.instance.visitedIds.length
                      : null,
                  onTap: () {
                    _pauseMapAnimations();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PandalPassportScreen(
                          userLat: _userPosition.latitude,
                          userLon: _userPosition.longitude,
                        ),
                      ),
                    ).then((_) {
                      _resumeMapAnimations();
                      setState(() {});
                    });
                  },
                ),

                _buildNavItem(
                  icon: Icons.calendar_month_rounded,
                  label: '2026 Tithi',
                  isSelected: false,
                  onTap: () {
                    _pauseMapAnimations();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PujaCalendarScreen(
                          userLat: _userPosition.latitude,
                          userLon: _userPosition.longitude,
                        ),
                      ),
                    ).then((_) => _resumeMapAnimations());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isActive,
    required Color activeColor,
    Color? borderColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xCC1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : (borderColor ?? Colors.white12),
            width: isActive ? 1.4 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor ?? (isActive ? Colors.white : Colors.white70),
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    final color = isSelected ? kMarigoldAmber : Colors.white54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (badgeCount != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: kSindoorRed,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
