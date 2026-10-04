import 'package:flutter/material.dart';
import '../services/spatial_facility_service.dart';

class HeritageProfileScreen extends StatelessWidget {
  const HeritageProfileScreen({super.key});

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
        title: const Text('🏛️ Pathuriaghata Ghosh Bari', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.star_border, color: kMarigoldAmber), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kTranslucentObsidian,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kMarigoldAmber.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.door_front_door, color: Colors.greenAccent, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('STATUS: 🟢 OPEN TO VISITORS', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text('⏱️ Gates Close: 01:30 PM (for Bhog)\n👥 Line Status: 🟢 Moving Fast (5 min wait)', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            
            // History
            const Text('📜 QUICK HISTORY & HERITAGE:', style: TextStyle(color: kMarigoldAmber, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kTranslucentObsidian,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Started in 1846. Famous for its magnificent Thakur Dalan and traditional clay idols. '
                'The family has preserved the heritage rituals meticulously over the centuries with ancestral Ekchala Pratima.',
                style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 22),

            // Facilities
            const Text('🚻 FACILITIES NEARBY (DYNAMIC DETECTION):', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final fac = SpatialFacilityService.instance.getNearestFacilitiesForCoords(22.5910, 88.3562);
                return Container(
                  decoration: BoxDecoration(
                    color: kTranslucentObsidian,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.wc, color: kMarigoldAmber),
                        title: const Text('Nearest Clean Washroom', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(fac.washroomInfo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        dense: true,
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      ListTile(
                        leading: const Icon(Icons.water_drop, color: Colors.cyanAccent),
                        title: const Text('Safe Drinking Water', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(fac.waterInfo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        dense: true,
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      ListTile(
                        leading: const Icon(Icons.local_police, color: kSindoorRed),
                        title: const Text('Police Assistance Booth', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(fac.policeInfo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        dense: true,
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.explore),
                label: const Text('NAVIGATE NEXT HOP (POLICE ALIGNED)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSindoorRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: kSindoorRed.withOpacity(0.5),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
