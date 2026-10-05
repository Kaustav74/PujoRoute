// Phone marketing screenshots (1080x1920 px = 360x640 logical @ 3x).
//
// NOT part of the normal `flutter test` run (lives outside test/). Run with:
//   flutter test screenshot_test/
// Output dir: $PUJOROUTE_SCREENSHOT_DIR, default
//   /workspace/pujoroute-marketing/phone-screenshots
// Optional fallback fonts (Bengali / emoji) are loaded when found; set
// $PUJOROUTE_EXTRA_FONTS to a ':'-separated list of extra .ttf paths.
//
// The OpenStreetMap tiles cannot load in tests (HTTP is stubbed to 400), so the
// map canvas shows the bundled offline placeholder tile.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pujoroute/main.dart';
import 'package:pujoroute/data/pujas_data.dart';
import 'package:pujoroute/screens/map_screen.dart';
import 'package:pujoroute/services/metro_graph_service.dart';
import 'package:pujoroute/services/session_service.dart';

final String outDir = Platform.environment['PUJOROUTE_SCREENSHOT_DIR'] ??
    '/workspace/pujoroute-marketing/phone-screenshots';

const _fallbackFamilies = ['NotoSansBengali', 'NotoColorEmoji', 'DejaVuSans'];
final _boundaryKey = GlobalKey();

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  // .../flutter/bin/cache/dart-sdk/bin/dart -> .../flutter
  return File(Platform.resolvedExecutable)
      .parent
      .parent
      .parent
      .parent
      .parent
      .path;
}

Future<void> _loadFile(String family, List<String> candidates) async {
  for (final path in candidates) {
    final f = File(path);
    if (f.existsSync()) {
      final bytes = f.readAsBytesSync();
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return;
    }
  }
  // ignore: avoid_print
  print('screenshot test: font $family not found (looked in $candidates)');
}

Future<void> _loadFonts() async {
  final root = _flutterRoot();
  final material = '$root/bin/cache/artifacts/material_fonts';

  // App font (bundled asset).
  final outfit = FontLoader('Outfit')
    ..addFont(rootBundle.load('assets/fonts/Outfit-Variable.ttf'));
  await outfit.load();

  // Roboto (Material default) + Material icons.
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Light', 'Black', 'Italic']) {
    final f = File('$material/Roboto-$w.ttf');
    if (f.existsSync()) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await roboto.load();
  await _loadFile('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);

  // Fallbacks for Bengali script and emoji used throughout the UI.
  final extra = (Platform.environment['PUJOROUTE_EXTRA_FONTS'] ?? '')
      .split(':')
      .where((s) => s.isNotEmpty)
      .toList();
  await _loadFile('NotoSansBengali', [
    ...extra.where((p) => p.toLowerCase().contains('bengali')),
    '/workspace/pujoroute-marketing/fonts/NotoSansBengali.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansBengali-Regular.ttf',
  ]);
  await _loadFile('NotoColorEmoji', [
    ...extra.where((p) => p.toLowerCase().contains('emoji')),
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    '$root/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
  ]);
  // Symbols such as ➔ that neither Outfit nor Noto cover.
  await _loadFile(
      'DejaVuSans', ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']);
  // TextStyle(fontFamily: 'monospace') maps to the system mono font on Android.
  await _loadFile('monospace', [
    '/usr/share/fonts/truetype/sand-box/google/Roboto Mono/RobotoMono-VariableFont_wght.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
  ]);
}

/// The real app theme, with glyph fallbacks for Bengali/emoji added (the
/// test engine has no system fallback fonts, unlike a phone).
ThemeData _appTheme(WidgetTester tester) {
  final app =
      const PujoRouteApp().build(tester.element(find.byType(Container).first));
  final theme = (app as MaterialApp).theme!;
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: _fallbackFamilies),
    primaryTextTheme:
        theme.primaryTextTheme.apply(fontFamilyFallback: _fallbackFamilies),
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(Container());
  final theme = _appTheme(tester);
  await tester.pumpWidget(RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const MapScreen(),
    ),
  ));
  await tester.runAsync(() async {
    final ctx = tester.element(find.byType(MapScreen));
    await precacheImage(const AssetImage('assets/images/durga_logo.png'), ctx);
    await precacheImage(
        const AssetImage('assets/images/offline_tile.png'), ctx);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _settle(tester);
}

/// The map has a repeating pulse animation, so pumpAndSettle never settles.
Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Let tile error images / asset decodes finish, then repaint.
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester, frames: 4);
  await tester.runAsync(() async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('screenshot: $outDir/$name.png (${image.width}x${image.height})');
  });
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(f.first, warnIfMissed: false);
  await _settle(tester);
}

void main() {
  final mega = kAllKolkataPujas.where((p) => p.category == 'mega').toList();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'pujo_bookmarked_ids': mega.take(4).map((p) => p.id).toList(),
      'pujo_visited_ids': mega.skip(1).take(3).map((p) => p.id).toList(),
    });
    await SessionService.instance.init();
    for (final p in mega.take(4)) {
      if (!SessionService.instance.isBookmarked(p.id)) {
        await SessionService.instance.toggleBookmark(p.id);
      }
    }
    for (final p in mega.skip(1).take(3)) {
      if (!SessionService.instance.isVisited(p.id)) {
        await SessionService.instance.toggleVisited(p.id);
      }
    }
    await SessionService.instance.saveEmergencyProfile(
        phone: '+91 98300 00000', name: 'Ananya Sen', blood: 'B+');
    await MetroGraphService.instance.initialize();
    await _loadFonts();
  });

  testWidgets('01 home (map with offline placeholder tiles)', (tester) async {
    await _pumpApp(tester);
    expect(kDistinctPandalCount, 489);
    expect(find.textContaining('Search 489 pandals'), findsOneWidget);
    await _shot(tester, '01_home');
  });

  testWidgets('02 pandal list / search', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'Park');
    await _settle(tester);
    // Expand the bottom sheet to show the result list.
    await tester.drag(
        find.textContaining('NEAREST TO YOU'), const Offset(0, -380));
    await _settle(tester, frames: 20);
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    await _shot(tester, '02_pandal_list_search');
  });

  testWidgets('03 pandal detail', (tester) async {
    // A pandal with a verified location and a plain, claim-free description.
    const detailId = '64-pally-durgotsav-committee';
    final detail = kAllKolkataPujas.firstWhere((p) => p.id == detailId);
    expect(detail.isLocationUnverified, isFalse);
    expect(detail.history.contains('*'), isFalse);
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, detail.name);
    await _settle(tester);
    await tester.drag(
        find.textContaining('NEAREST TO YOU'), const Offset(0, -380));
    await _settle(tester, frames: 20);
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    await tester.tap(find.text(detail.name).last, warnIfMissed: false);
    await _settle(tester, frames: 20);
    expect(find.textContaining(detail.history.substring(0, 40)), findsWidgets);
    // Removed fake "live" UI must not come back.
    expect(find.textContaining('GATE STATUS'), findsNothing);
    expect(find.textContaining('CROWD SPEED'), findsNothing);
    expect(find.textContaining('LIVE LINE CHECK-IN'), findsNothing);
    await _shot(tester, '03_pandal_detail');
  });

  testWidgets('04 route planner + 05 metro station guide', (tester) async {
    // Start near Dakshineswar: at default settings (All / mega / 8 stops) this
    // circuit includes a real Metro hop, so the guide shows a Metro ride. From
    // most start positions every hop is a walk (audit Phase 3).
    await SessionService.instance.saveLastPosition(22.654, 88.3637);
    addTearDown(() => SessionService.instance.saveLastPosition(22.5152, 88.3845));
    await _pumpApp(tester);
    await _tapText(tester, 'Route Planner');
    await _settle(tester, frames: 10);
    await _tapText(tester, '⚡ Generate Route');
    await _settle(tester, frames: 30);
    // Back to top for the planner shot.
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, 3000));
    await _settle(tester, frames: 10);
    await _shot(tester, '04_route_planner');
    await _tapText(tester, '🚇 Generate Metro Station Guide');
    await _settle(tester, frames: 20);
    expect(find.textContaining('Metro Recommended'), findsWidgets);
    await _shot(tester, '05_metro_station_guide');
  });

  testWidgets('06 panjika / tithi', (tester) async {
    await _pumpApp(tester);
    await _tapText(tester, '2026 Tithi');
    await _settle(tester, frames: 20);
    await _shot(tester, '06_panjika_tithi');
  });

  testWidgets('07 passport / bookmarks', (tester) async {
    await _pumpApp(tester);
    await _tapText(tester, 'Passport');
    await _settle(tester, frames: 20);
    expect(find.textContaining('of 489 Pandals Visited'), findsOneWidget);
    await _shot(tester, '07_passport_bookmarks');
  });

  testWidgets('08 offline emergency pass', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Offline Emergency Pass'));
    await _settle(tester, frames: 10);
    expect(find.textContaining('Session:'), findsNothing);
    // The search hint behind the overlay must show the real distinct count.
    expect(find.textContaining('504'), findsNothing);
    await _shot(tester, '08_offline_emergency_pass');
  });
}
