import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujoroute/utils/external_links.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Simulates a device with no browser / Maps app (e.g. some Fire builds):
/// external launch throws, platform-default launch returns false.
class _NoHandlerLauncher extends UrlLauncherPlatform {
  int calls = 0;
  @override
  LinkDelegate? get linkDelegate => null;
  @override
  Future<bool> canLaunch(String url) async => false;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls++;
    if (options.mode == PreferredLaunchMode.externalApplication) {
      throw Exception('ActivityNotFoundException');
    }
    return false;
  }
}

class _OkLauncher extends _NoHandlerLauncher {
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    calls++;
    return true;
  }
}

Future<BuildContext> _host(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })),
  ));
  return ctx;
}

void main() {
  testWidgets('no app to open link: never throws, offers Copy link',
      (tester) async {
    final fake = _NoHandlerLauncher();
    UrlLauncherPlatform.instance = fake;
    final ctx = await _host(tester);
    final ok = await openExternalLink(
        ctx, Uri.parse('https://www.google.com/maps/dir/?api=1'));
    await tester.pump();
    expect(ok, isFalse);
    expect(fake.calls, 2); // external, then platform default
    expect(find.text('Copy link'), findsOneWidget);
  });

  testWidgets('link opens normally: no snackbar', (tester) async {
    final fake = _OkLauncher();
    UrlLauncherPlatform.instance = fake;
    final ctx = await _host(tester);
    final ok = await openExternalLink(
        ctx, Uri.parse('https://www.openstreetmap.org/copyright'));
    await tester.pump();
    expect(ok, isTrue);
    expect(fake.calls, 1);
    expect(find.text('Copy link'), findsNothing);
  });
}
