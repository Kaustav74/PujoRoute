import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app (Google Maps / browser) without ever throwing.
///
/// On devices with no browser or Maps app (e.g. some Amazon Fire builds) or with
/// no network, `launchUrl` can return false or throw. In that case we show a
/// SnackBar with a "Copy link" action instead of crashing.
Future<bool> openExternalLink(
  BuildContext context,
  Uri url, {
  String failureMessage = 'No app found to open this link. You can copy it instead.',
}) async {
  bool ok = false;
  try {
    ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    try {
      ok = await launchUrl(url, mode: LaunchMode.platformDefault);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failureMessage),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Copy link',
          onPressed: () => Clipboard.setData(ClipboardData(text: url.toString())),
        ),
      ),
    );
  }
  return ok;
}
