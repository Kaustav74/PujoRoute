import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/services/metro_graph_service.dart';
import 'package:pujoroute/services/deterministic_routing_service.dart';
import 'package:pujoroute/data/pujas_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Metro Graph Service Tests', () {
    test('Metro graph contains Blue Line and Green Line stations', () {
      final metroGraph = MetroGraphService.instance;
      expect(metroGraph.hasStation('Shyambazar'), true);
      expect(metroGraph.hasStation('Esplanade'), true);
      expect(metroGraph.hasStation('Howrah Maidan'), true);
      expect(metroGraph.hasStation('Sealdah'), true);
    });

    test('Bagbazar Metro Station MUST NOT exist in graph', () {
      final metroGraph = MetroGraphService.instance;
      expect(metroGraph.hasStation('Bagbazar'), false);
      expect(metroGraph.hasStation('Bagbazar Metro'), false);
      final warning = metroGraph.getForbiddenAliasWarning('Bagbazar');
      expect(warning, isNotNull);
      expect(warning, contains('Shyambazar'));
    });

    test('Esplanade is the ONLY valid interchange between Blue Line and Green Line', () {
      final metroGraph = MetroGraphService.instance;
      final interchange = metroGraph.getInterchange('Green Line', 'Blue Line');
      expect(interchange, isNotNull);
      expect(interchange!.station, 'Esplanade');
      expect(interchange.connects, containsAll(['blue', 'green']));
    });

    test('Station line validation rules', () {
      final metroGraph = MetroGraphService.instance;
      expect(metroGraph.validateStationLine('Shyambazar', 'Blue Line'), true);
      expect(metroGraph.validateStationLine('Howrah Maidan', 'Green Line'), true);
      expect(metroGraph.validateStationLine('Shyambazar', 'Green Line'), false);
    });
  });

  group('Deterministic Routing Service Tests', () {
    test('buildCrossRiverCircuit returns valid 6-stop route', () {
      final routingService = DeterministicRoutingService.instance;
      final route = routingService.buildCrossRiverCircuit(count: 6);

      expect(route.origin, 'Howrah Maidan');
      expect(route.interchange, isNotNull);
      expect(route.interchange!.station, 'Esplanade');
      expect(route.interchange!.fromLine, 'Green Line');
      expect(route.interchange!.toLine, 'Blue Line');
      expect(route.stops.length, 6);
    });

    test('All route stops strictly enforce <= 900m walking constraint', () {
      final routingService = DeterministicRoutingService.instance;
      final route = routingService.buildCrossRiverCircuit(count: 6);

      for (final stop in route.stops) {
        expect(stop.walkingDistMeters <= 900, true,
            reason: '${stop.name} walking distance ${stop.walkingDistMeters}m exceeds 900m limit');
      }
    });

    test('Bagbazar Sarbojanin is Centenary Community and Sovabazar Rajbari is Bonedi Bari', () {
      final routingService = DeterministicRoutingService.instance;
      final route = routingService.buildCrossRiverCircuit(count: 6);

      final bagbazar = route.stops.firstWhere((s) => s.name.contains('Bagbazar'));
      expect(bagbazar.category, 'Centenary Community');

      final sovabazar = route.stops.firstWhere((s) => s.name.contains('Sovabazar'));
      expect(sovabazar.category, 'Bonedi Bari');
    });

    test('validateRoute passes for valid deterministic route', () {
      final routingService = DeterministicRoutingService.instance;
      final route = routingService.buildCrossRiverCircuit(count: 6);
      final validation = routingService.validateRoute(route);

      expect(validation.isValid, true);
      expect(validation.errors.isEmpty, true);
    });

    test('validateRoute rejects route exceeding 900m walking limit', () {
      final routingService = DeterministicRoutingService.instance;
      final invalidStop = RouteStopJson(
        id: 999,
        name: 'Distant Pandal',
        category: 'Mega Theme',
        zone: 'North',
        nearestMetro: 'Shyambazar',
        metroLine: 'Blue Line',
        walkingDistMeters: 1500, // 1500m > 900m!
        lat: 22.6000,
        lng: 88.3600,
      );

      final invalidRoute = StrictRouteJson(
        origin: 'Howrah Maidan',
        stops: [invalidStop],
        constraints: {'max_walk_meters': 900},
      );

      final validation = routingService.validateRoute(invalidRoute);
      expect(validation.isValid, false);
      expect(validation.errors.any((e) => e.contains('exceeds max walking constraint')), true);
    });
  });

  group('Kolkata Metro Guide & Circuit Routing Logic Tests', () {
    final metroGraph = MetroGraphService.instance;

    test('Panchanantala to Badamtala recommends Walk, NOT 1-stop metro', () {
      final panchanantala = kAllKolkataPujas.firstWhere(
          (p) => p.name.toLowerCase().contains('panchanantala'));
      final badamtala = kAllKolkataPujas.firstWhere(
          (p) => p.name.toLowerCase().contains('badamtala'));

      expect(panchanantala.metroStation.toLowerCase(), contains('jatin das park'));
      expect(badamtala.metroStation.toLowerCase(), contains('kalighat'));

      final guidance = metroGraph.buildMetroHopGuidance(
        hopIndex: 1,
        fromP: panchanantala,
        toP: badamtala,
      );

      expect(guidance.recommendation, equals(TransitRecommendation.walk));
      expect(guidance.headline.toLowerCase(), contains('walk'));
      expect(guidance.detailedAdvice.toLowerCase(), contains('longer than walking'));
    });

    test('All 504 pandals resolve valid nearest metro info and gate', () {
      for (final p in kAllKolkataPujas) {
        final info = metroGraph.getPandalMetroInfo(p);
        expect(info.station.isNotEmpty, true, reason: '${p.name} station is empty');
        expect(info.line.isNotEmpty, true, reason: '${p.name} line is empty');
        expect(info.gate.isNotEmpty, true, reason: '${p.name} gate is empty');
        expect(info.distanceToMetroMeters, greaterThanOrEqualTo(0.0));
      }
    });

    test('buildCircuitMetroGuide summarizes multi-stop circuit accurately', () {
      final circuit = [
        kAllKolkataPujas[0], // Sovabazar / Girish Park area
        kAllKolkataPujas[1],
        kAllKolkataPujas[2],
      ];
      final summary = metroGraph.buildCircuitMetroGuide(circuit);

      expect(summary.hops.length, equals(2));
      expect(summary.walkCount + summary.metroRecommendedCount + summary.metroPossibleCount, equals(2));
    });
  });
}
