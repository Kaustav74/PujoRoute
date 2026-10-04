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
}
