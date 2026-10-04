import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pujoroute/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy XOR-obfuscated emergency values and online-AI leftovers are purged on init', () async {
    // SessionService is a singleton that is initialised once per isolate, so
    // this lives in its own test file (fresh isolate).
    SharedPreferences.setMockInitialValues({
      'pujo_emergency_phone': 'enc_v1:AAECAwQ=',
      'pujo_emergency_name': 'Plain Name',
      'pujo_chat_messages': '[{"role":"user"}]',
      'pujo_proxy_gateway_url': 'https://my-freellmapi-server.onrender.com/v1/chat/completions',
      'pujo_client_installation_id': 'usr_1',
    });
    await SessionService.instance.init();
    final prefs = await SharedPreferences.getInstance();

    expect(SessionService.instance.emergencyPhone, isEmpty);
    expect(prefs.containsKey('pujo_emergency_phone'), isFalse);
    expect(SessionService.instance.emergencyName, equals('Plain Name'));
    expect(prefs.containsKey('pujo_chat_messages'), isFalse);
    expect(prefs.containsKey('pujo_proxy_gateway_url'), isFalse);
    expect(prefs.containsKey('pujo_client_installation_id'), isFalse);
  });
}
