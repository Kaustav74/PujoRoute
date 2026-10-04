import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PujoRoute is fully offline. These strings belonged to UI that presented
/// static or local-only data as if it were live (gate status, crowd speed,
/// 1-tap crowd reports) or exposed a debug session ID. Guard against them
/// creeping back into any user-facing screen.
void main() {
  test('lib/ contains no fake live status, crowd-report or session-ID debug UI', () {
    const banned = [
      'GATE STATUS',
      'CROWD SPEED',
      'LIVE LINE CHECK-IN',
      '1-Tap Crowd Report',
      'Crowd radar',
      'Open 24x7',
      r"'Session: ${",
      '_buildLineReportBtn',
      'reportCrowdStatus',
      'getCrowdReport',
      // Route Planner: "fast lines" filtered on a field that is 'fast' for every pandal
      'Fast Lines',
      'Fast Queue',
      'Low Wait',
      // Route Planner: static congestion list presented as live traffic rerouting
      'Reroute Around Heavy Traffic',
      'Traffic bypass active',
      'police road closures',
      'police vehicular road closures',
      '>60m',
      // SOS message: never claim a hospital's status
      'Facility Status',
      '24x7 Emergency & Trauma Care Active',
      'Nearest 24x7 Hospital',
      // Unused per-install session ID
      'get sessionId',
      '_secureRandomHex',
    ];
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final b in banned) {
        if (src.contains(b)) hits.add('${f.path}: $b');
      }
    }
    expect(hits, isEmpty);
  });

  test('unreachable heritage profile / hopper navigation screens stay deleted', () {
    expect(File('lib/screens/heritage_profile_screen.dart').existsSync(), isFalse);
    expect(File('lib/screens/hopper_navigation_screen.dart').existsSync(), isFalse);
  });
}
