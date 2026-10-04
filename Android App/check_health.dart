// ignore_for_file: avoid_print
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  const String base = 'https://my-freellmapi-server.onrender.com';
  
  final res1 = await http.get(Uri.parse('$base/health'));
  print('/health -> ${res1.statusCode}');
  
  final res2 = await http.get(Uri.parse('$base/v1/models'), headers: {'Authorization': 'Bearer ${Platform.environment['FREELLMAPI_API_KEY'] ?? ''}'});
  print('/v1/models -> ${res2.statusCode}');
}
