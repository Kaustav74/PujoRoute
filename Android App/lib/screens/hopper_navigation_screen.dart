import 'package:flutter/material.dart';

class HopperNavigationScreen extends StatelessWidget {
  const HopperNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kMidnightBlue = Color(0xFF0D0D1E);
    const Color kSindoorRed = Color(0xFFE62E2D);
    const Color kMarigoldAmber = Color(0xFFFFB300);
    const Color kTranslucentObsidian = Color(0xCC1C1C2E);

    return Scaffold(
      backgroundColor: kMidnightBlue,
      appBar: AppBar(
        backgroundColor: kMidnightBlue,
        title: const Text('Hopper Navigation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: kSindoorRed),
            tooltip: 'Emergency Pass',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Target Info
          Container(
            padding: const EdgeInsets.all(16.0),
            color: kTranslucentObsidian,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎯 CURRENT TARGET: Ahiritola Sarbojanin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('🚶‍♂️ NEXT UP: Beniatola Sarbojanin', style: TextStyle(color: kMarigoldAmber, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          
          // Navigation Map Placeholder
          Expanded(
            child: Container(
              color: const Color(0xFF141424),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🗺️ ENFORCING POLICE PEDESTRIAN ONE-WAY LOOP', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                    const SizedBox(height: 20),
                    const Icon(Icons.arrow_downward, color: Colors.greenAccent, size: 48),
                    const Text('Walk North via BK Paul Avenue', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: kSindoorRed,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: kSindoorRed.withOpacity(0.5), blurRadius: 10),
                        ],
                      ),
                      child: const Text('⚠️ BAMBOO BARRICADE — POLICE DIVERSION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),

          // Metro Directions
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: kTranslucentObsidian,
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.train, color: kMarigoldAmber),
                    SizedBox(width: 8),
                    Text('METRO EVACUATION & DIRECT ROUTE', style: TextStyle(color: kMarigoldAmber, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'If exiting now, walk 200m East to Shovabazar Metro Station. Enter via GATE NO. 2 ONLY.',
                  style: TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
