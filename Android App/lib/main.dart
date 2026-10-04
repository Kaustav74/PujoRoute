import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'services/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionService.instance.init();
  runApp(const PujoRouteApp());
}

class PujoRouteApp extends StatelessWidget {
  const PujoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PujoRoute — Kolkata Durga Puja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D1E), // Deep Midnight Blue
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE62E2D), // Electric Vermillion / Sindoor Red
          secondary: Color(0xFFFFB300), // Glowing Marigold / Warm Amber
          surface: Color(0xFF1C1C2E), // Translucent Obsidian
          onPrimary: Colors.white,
          onSecondary: Colors.black87,
          onSurface: Colors.white,
        ),
        cardColor: const Color(0xFF1C1C2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D1E),
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Outfit'),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
