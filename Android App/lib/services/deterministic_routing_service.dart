import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'metro_graph_service.dart';

class RouteStopJson {
  final int id;
  final String name;
  final String category; // 'Mega Theme', 'Bonedi Bari', 'Centenary Community'
  final String zone; // 'North', 'South', 'Central', 'Salt Lake', 'Howrah', 'Behala'
  final String nearestMetro;
  final String metroLine; // 'Blue Line', 'Green Line'
  final int walkingDistMeters;
  final double lat;
  final double lng;

  const RouteStopJson({
    required this.id,
    required this.name,
    required this.category,
    required this.zone,
    required this.nearestMetro,
    required this.metroLine,
    required this.walkingDistMeters,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'zone': zone,
        'nearest_metro': nearestMetro,
        'metro_line': metroLine,
        'walking_dist_meters': walkingDistMeters,
        'lat': lat,
        'lng': lng,
      };

  factory RouteStopJson.fromJson(Map<String, dynamic> json) => RouteStopJson(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Mega Theme',
        zone: json['zone'] as String? ?? 'South',
        nearestMetro: json['nearest_metro'] as String? ?? '',
        metroLine: json['metro_line'] as String? ?? 'Blue Line',
        walkingDistMeters: json['walking_dist_meters'] as int? ?? 0,
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      );
}

class RouteInterchangeJson {
  final String station;
  final String fromLine;
  final String toLine;

  const RouteInterchangeJson({
    required this.station,
    required this.fromLine,
    required this.toLine,
  });

  Map<String, dynamic> toJson() => {
        'station': station,
        'from_line': fromLine,
        'to_line': toLine,
      };

  factory RouteInterchangeJson.fromJson(Map<String, dynamic> json) =>
      RouteInterchangeJson(
        station: json['station'] as String? ?? 'Esplanade',
        fromLine: json['from_line'] as String? ?? 'Green Line',
        toLine: json['to_line'] as String? ?? 'Blue Line',
      );
}

class StrictRouteJson {
  final String origin;
  final RouteInterchangeJson? interchange;
  final List<RouteStopJson> stops;
  final Map<String, dynamic> constraints;

  const StrictRouteJson({
    required this.origin,
    this.interchange,
    required this.stops,
    required this.constraints,
  });

  Map<String, dynamic> toJson() => {
        'origin': origin,
        if (interchange != null) 'interchange': interchange!.toJson(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'constraints': constraints,
      };

  factory StrictRouteJson.fromJson(Map<String, dynamic> json) => StrictRouteJson(
        origin: json['origin'] as String? ?? 'Howrah Maidan',
        interchange: json['interchange'] != null
            ? RouteInterchangeJson.fromJson(json['interchange'])
            : null,
        stops: (json['stops'] as List?)
                ?.map((e) => RouteStopJson.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        constraints: (json['constraints'] as Map<String, dynamic>?) ?? {},
      );

  String toRawJsonString() => json.encode(toJson());
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({required this.isValid, this.errors = const []});
}

class DeterministicRoutingService {
  static final DeterministicRoutingService _instance =
      DeterministicRoutingService._internal();
  factory DeterministicRoutingService() => _instance;
  static DeterministicRoutingService get instance => _instance;

  DeterministicRoutingService._internal();

  static const int kMaxWalkingDistanceMeters = 900;

  /// Authoritative Seed Verification Dataset
  static const List<RouteStopJson> kVerifiedSeedPujas = [
    RouteStopJson(
      id: 1001,
      name: 'Howrah Seva Sangha',
      category: 'Mega Theme',
      zone: 'Howrah',
      nearestMetro: 'Howrah Maidan',
      metroLine: 'Green Line',
      walkingDistMeters: 350,
      lat: 22.5855,
      lng: 88.3242,
    ),
    RouteStopJson(
      id: 1002,
      name: 'Bagbazar Sarbojanin',
      category: 'Centenary Community',
      zone: 'North',
      nearestMetro: 'Shyambazar',
      metroLine: 'Blue Line',
      walkingDistMeters: 550,
      lat: 22.6025,
      lng: 88.3685,
    ),
    RouteStopJson(
      id: 1003,
      name: 'Sovabazar Rajbari',
      category: 'Bonedi Bari',
      zone: 'North',
      nearestMetro: 'Sovabazar Sutanuti',
      metroLine: 'Blue Line',
      walkingDistMeters: 400,
      lat: 22.5976,
      lng: 88.3644,
    ),
    RouteStopJson(
      id: 1004,
      name: 'Tridhara Sammilani',
      category: 'Mega Theme',
      zone: 'South',
      nearestMetro: 'Kalighat',
      metroLine: 'Blue Line',
      walkingDistMeters: 650,
      lat: 22.5186,
      lng: 88.3639,
    ),
    RouteStopJson(
      id: 1005,
      name: 'Ballygunge Cultural',
      category: 'Mega Theme',
      zone: 'South',
      nearestMetro: 'Kalighat',
      metroLine: 'Blue Line',
      walkingDistMeters: 500,
      lat: 22.5175,
      lng: 88.3662,
    ),
    RouteStopJson(
      id: 1006,
      name: 'Chetla Agrani',
      category: 'Mega Theme',
      zone: 'South',
      nearestMetro: 'Kalighat',
      metroLine: 'Blue Line',
      walkingDistMeters: 800,
      lat: 22.5199,
      lng: 88.3444,
    ),
  ];

  /// Builds a deterministic cross-river Metro circuit (e.g. 6 stops using Howrah Maidan -> Esplanade -> Blue Line)
  StrictRouteJson buildCrossRiverCircuit({
    int count = 6,
    double maxWalkMeters = 900.0,
  }) {
    // 1. Howrah Stop (Green Line)
    final howrahStop = kVerifiedSeedPujas.firstWhere(
        (p) => p.zone == 'Howrah' && p.walkingDistMeters <= maxWalkMeters,
        orElse: () => kVerifiedSeedPujas[0]);

    // 2. South Kolkata Stops (Blue Line near Kalighat)
    final southStops = kVerifiedSeedPujas
        .where((p) => p.zone == 'South' && p.walkingDistMeters <= maxWalkMeters)
        .toList();

    // 3. North Kolkata Stops (Blue Line near Shyambazar / Sovabazar Sutanuti)
    final northStops = kVerifiedSeedPujas
        .where((p) => p.zone == 'North' && p.walkingDistMeters <= maxWalkMeters)
        .toList();

    final List<RouteStopJson> selectedStops = [
      howrahStop,
      ...southStops.take(3),
      ...northStops.take(2),
    ];

    final interchange = RouteInterchangeJson(
      station: 'Esplanade',
      fromLine: 'Green Line',
      toLine: 'Blue Line',
    );

    final route = StrictRouteJson(
      origin: 'Howrah Maidan',
      interchange: interchange,
      stops: selectedStops.take(count).toList(),
      constraints: {
        'max_walk_meters': maxWalkMeters.toInt(),
        'mode': 'metro',
        'cross_river': true,
      },
    );

    // Validate the generated route deterministically
    final validation = validateRoute(route);
    if (!validation.isValid) {
      debugPrint("Deterministic route validation warnings: ${validation.errors}");
    }

    return route;
  }

  /// Strictly validates a machine-readable route JSON against database and Metro graph rules
  ValidationResult validateRoute(StrictRouteJson route) {
    final errors = <String>[];
    final metroGraph = MetroGraphService.instance;

    if (route.stops.isEmpty) {
      errors.add("Route contains 0 stops.");
    }

    final seenIds = <int>{};
    for (int i = 0; i < route.stops.length; i++) {
      final stop = route.stops[i];

      // Check duplicates
      if (seenIds.contains(stop.id)) {
        errors.add("Duplicate pandal detected: ${stop.name} (ID: ${stop.id})");
      }
      seenIds.add(stop.id);

      // Check walking distance constraint (≤ 900m)
      if (stop.walkingDistMeters > kMaxWalkingDistanceMeters) {
        errors.add(
            "Pandal ${stop.name} exceeds max walking constraint (${stop.walkingDistMeters}m > ${kMaxWalkingDistanceMeters}m)");
      }

      // Check coordinates validity
      if (stop.lat == 0.0 || stop.lng == 0.0 || stop.lat < 22.0 || stop.lat > 23.0) {
        errors.add("Invalid geographic coordinates for ${stop.name}: (${stop.lat}, ${stop.lng})");
      }

      // Check Metro station in Metro Graph
      if (!metroGraph.hasStation(stop.nearestMetro)) {
        errors.add("Station '${stop.nearestMetro}' for ${stop.name} is not in Metro graph.");
      }

      // Check Metro line validity
      if (!metroGraph.validateStationLine(stop.nearestMetro, stop.metroLine)) {
        errors.add("Station '${stop.nearestMetro}' does not belong to line '${stop.metroLine}'");
      }

      // Check category sanity (Bagbazar Sarbojanin cannot be Bonedi Bari)
      if (stop.name.toLowerCase().contains('bagbazar') &&
          stop.category.toLowerCase().contains('bonedi')) {
        errors.add("Bagbazar Sarbojanin misclassified as Bonedi Bari.");
      }
    }

    // Check interchange validity
    if (route.interchange != null) {
      final station = route.interchange!.station;
      if (!metroGraph.hasStation(station)) {
        errors.add("Interchange station '$station' not found in Metro graph.");
      }
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
