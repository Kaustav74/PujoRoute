// ignore_for_file: avoid_print
import 'package:http/http.dart' as http;

void main() async {
  const String base = 'https://my-freellmapi-server.onrender.com';
  
  final res1 = await http.get(Uri.parse('$base/health'));
  print('/health -> ${res1.statusCode}');
  
  final res2 = await http.get(Uri.parse('$base/v1/models'), headers: {'Authorization': 'Bearer freellmapi-60361c293a499d1f5786eb8f96d950e842d171c84d32576b'});
  print('/v1/models -> ${res2.statusCode}');
}
