import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/pujas_data.dart';
import '../services/session_service.dart';

class CulturalStamp {
  final String id;
  final String title;
  final String titleBengali;
  final String description;
  final String icon;
  final bool Function(Set<String> visitedIds, Map<String, Pandal> idMap) isUnlocked;

  const CulturalStamp({
    required this.id,
    required this.title,
    required this.titleBengali,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

class PandalPassportScreen extends StatefulWidget {
  final double userLat;
  final double userLon;

  const PandalPassportScreen({
    super.key,
    required this.userLat,
    required this.userLon,
  });

  @override
  State<PandalPassportScreen> createState() => _PandalPassportScreenState();
}

class _PandalPassportScreenState extends State<PandalPassportScreen> {
  static const Color kMidnightOled = Color(0xFF0A0A14);
  static const Color kSindoorRed = Color(0xFFE62E2D);
  static const Color kMarigoldAmber = Color(0xFFFFB300);
  static const Color kCardBackground = Color(0xFF141424);

  late Map<String, Pandal> _idToPandal;

  final List<CulturalStamp> _stamps = [
    CulturalStamp(
      id: 'dhunuchi_master',
      title: 'Dakshin Kolkata Dhunuchi Master',
      titleBengali: 'দক্ষিণ কলকাতা ধুনুচি মাস্টার',
      description: 'Visit 5 South Kolkata mega celebrations (Suruchi, Ekdalia, Tridhara, Singhi, Chetla)',
      icon: '🪔',
      isUnlocked: (visited, map) {
        int count = 0;
        for (final id in visited) {
          final p = map[id];
          if (p != null && p.zone == 'South' && p.category == 'mega') count++;
        }
        return count >= 5;
      },
    ),
    CulturalStamp(
      id: 'bonedi_explorer',
      title: 'Bonedi Bari Heritage Explorer',
      titleBengali: 'বনেদি বাড়ি হেরিটেজ এক্সপ্লোরার',
      description: 'Experience 3 aristocratic zamindar baris (Sovabazar, Hatkhola, etc.)',
      icon: '🏛️',
      isUnlocked: (visited, map) {
        int count = 0;
        for (final id in visited) {
          final p = map[id];
          if (p != null && p.category == 'heritage') count++;
        }
        return count >= 3;
      },
    ),
    CulturalStamp(
      id: 'uttar_kolkata_sholoana',
      title: 'Uttar Kolkata Sholoana Bangali',
      titleBengali: 'উত্তর কলকাতা ষোলআনা বাঙালি',
      description: 'Visit iconic North Kolkata heritage centers (Bagbazar, Kumartuli, Ahiritola)',
      icon: '🌊',
      isUnlocked: (visited, map) {
        int count = 0;
        for (final id in visited) {
          final p = map[id];
          if (p != null && p.zone == 'North') count++;
        }
        return count >= 4;
      },
    ),
    CulturalStamp(
      id: 'saltlake_cosmo',
      title: 'Salt Lake Cosmopolitan Hopping',
      titleBengali: 'সল্টলেক কসমোপলিটান হপিং',
      description: 'Explore 3 grand Township architectural pandals (FD Block, BJ Block, EC Block)',
      icon: '🏙️',
      isUnlocked: (visited, map) {
        int count = 0;
        for (final id in visited) {
          final p = map[id];
          if (p != null && p.zone == 'Salt Lake') count++;
        }
        return count >= 3;
      },
    ),
    CulturalStamp(
      id: 'midnight_legend',
      title: 'Midnight All-Night Hopping Legend',
      titleBengali: 'অল-নাইট হপিং লেজেন্ড',
      description: 'Clock in at least 8 pandal check-ins across the city circuit',
      icon: '🔥',
      isUnlocked: (visited, map) => visited.length >= 8,
    ),
    CulturalStamp(
      id: 'food_addabaaj',
      title: 'Kolkata Street Food Addabaaj',
      titleBengali: 'কলকাতা স্ট্রিট ফুড আড্ডাবাজ',
      description: 'Visit Maddox Square, College Square, or Kumartuli culture hubs',
      icon: '🥟',
      isUnlocked: (visited, map) {
        return visited.any((id) =>
            id.contains('maddox') || id.contains('college') || id.contains('kumartuli') || id.contains('ballygunge'));
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _idToPandal = {for (var p in kAllKolkataPujas) p.id: p};
  }

  double _getDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;
    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Pandal? _findNearestCheckInCandidate() {
    final visited = SessionService.instance.visitedIds;
    Pandal? nearest;
    double minD = double.infinity;

    for (final p in kAllKolkataPujas) {
      if (!visited.contains(p.id)) {
        final d = _getDistanceMeters(widget.userLat, widget.userLon, p.lat, p.lon);
        if (d < minD) {
          minD = d;
          nearest = p;
        }
      }
    }
    return nearest;
  }

  void _checkInNearestPandal() async {
    final nearest = _findNearestCheckInCandidate();
    if (nearest == null) return;

    final dist = _getDistanceMeters(widget.userLat, widget.userLon, nearest.lat, nearest.lon).round();

    await SessionService.instance.toggleVisited(nearest.id);
    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E1428),
        content: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Checked in to ${nearest.name}! (~${dist > 1000 ? "${(dist / 1000).toStringAsFixed(1)}km" : "${dist}m"} away). Passport stamped.',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserHoppingRank(int visitedCount) {
    if (visitedCount >= 15) return 'Maha Pandal Samrat (মহা প্যান্ডেল সম্রাট)';
    if (visitedCount >= 10) return 'Kolkata Street Legend (প্যান্ডেল হপিং লেজেন্ড)';
    if (visitedCount >= 6) return 'Dhunuchi Master (ধুনুচি মাস্টার)';
    if (visitedCount >= 3) return 'Active Pujo Explorer (উৎসাহী দর্শনার্থী)';
    return 'Pandal Hopping Beginner (নবাগত দর্শনার্থী)';
  }

  void _sharePassportToWhatsApp() async {
    final visited = SessionService.instance.visitedIds;
    final rank = _getUserHoppingRank(visited.length);

    final unlockedStamps = _stamps.where((s) => s.isUnlocked(visited, _idToPandal)).toList();

    final StringBuffer sb = StringBuffer();
    sb.writeln("🏆 *My Official Kolkata Durga Puja 2026 Passport*");
    sb.writeln("Visited: ${visited.length} / 504 Pandals (${((visited.length / 504) * 100).toStringAsFixed(1)}%)");
    sb.writeln("🎖️ *Rank:* $rank\n");

    if (unlockedStamps.isNotEmpty) {
      sb.writeln("🪔 *Unlocked Cultural Badges:*");
      for (final s in unlockedStamps) {
        sb.writeln("${s.icon} ${s.title} (${s.titleBengali})");
      }
    } else {
      sb.writeln("📍 Hopping journey started! Unlocking cultural stamps tonight.");
    }

    sb.writeln("\nPlan and track your zero-backtracking hopping route with *PujoRoute* ✨");

    final encodedText = Uri.encodeComponent(sb.toString());
    final url = Uri.parse('whatsapp://send?text=$encodedText');
    final fallbackUrl = Uri.parse('https://wa.me/?text=$encodedText');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp is not installed on this device.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to launch WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visited = SessionService.instance.visitedIds;
    final visitedCount = visited.length;
    final rank = _getUserHoppingRank(visitedCount);
    final nearestCandidate = _findNearestCheckInCandidate();
    final nearestDist = nearestCandidate != null
        ? _getDistanceMeters(widget.userLat, widget.userLon, nearestCandidate.lat, nearestCandidate.lon).round()
        : 0;

    return Scaffold(
      backgroundColor: kMidnightOled,
      appBar: AppBar(
        backgroundColor: kMidnightOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🛂', style: TextStyle(fontSize: 22)),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pandal Passport',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'প্যান্ডেল পাসপোর্ট ও কালচারাল স্ট্যাম্প',
                  style: TextStyle(color: kMarigoldAmber, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.greenAccent),
            tooltip: 'Share Passport to WhatsApp',
            onPressed: _sharePassportToWhatsApp,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Passport Identity Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B0000), Color(0xFF1E1024)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kMarigoldAmber, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: kSindoorRed.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('🏛️', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          'KOLKATA PUJO PASSPORT 2026',
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '${((visitedCount / 504) * 100).toStringAsFixed(1)}% Done',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kMarigoldAmber, width: 2),
                        color: Colors.black26,
                      ),
                      child: const Center(
                        child: Text('🪔', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rank,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$visitedCount of 504 Pandals Visited',
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (visitedCount / 504).clamp(0.0, 1.0),
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(kMarigoldAmber),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Manual Pandal Search & Stamp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kCardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'SEARCH & STAMP PANDALS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Autocomplete<Pandal>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Pandal>.empty();
                    }
                    final query = textEditingValue.text.toLowerCase();
                    return kAllKolkataPujas.where((p) {
                      return p.name.toLowerCase().contains(query) ||
                             p.id.toLowerCase().contains(query);
                    }).take(5); // Show top 5 matches
                  },
                  displayStringForOption: (Pandal p) => p.name,
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type a pandal name (e.g. Suruchi...)',
                        hintStyle: const TextStyle(color: Colors.white38),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        color: Colors.transparent,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 64, // approximate width
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252540),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.white12),
                            itemBuilder: (BuildContext context, int index) {
                              final Pandal p = options.elementAt(index);
                              final bool isStamped = SessionService.instance.isVisited(p.id);
                              return ListTile(
                                dense: true,
                                title: Text(p.name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(p.zone, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                trailing: isStamped
                                    ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                                    : const Icon(Icons.add_circle_outline, color: kMarigoldAmber, size: 20),
                                onTap: () {
                                  onSelected(p);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onSelected: (Pandal p) {
                    final isStamped = SessionService.instance.isVisited(p.id);
                    if (isStamped) {
                      // Unstamp
                      SessionService.instance.toggleVisited(p.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Removed stamp for ${p.name}')),
                      );
                    } else {
                      // Stamp
                      SessionService.instance.toggleVisited(p.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Stamped ${p.name}! 🛂'),
                          backgroundColor: Colors.greenAccent.shade700,
                        ),
                      );
                    }
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Instant 1-Tap Check-In Card
          if (nearestCandidate != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kCardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_location_alt, color: Colors.greenAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEAREST DARSHAN CHECK-IN',
                          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nearestCandidate.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${nearestCandidate.subsection} • ~${nearestDist > 1000 ? "${(nearestDist / 1000).toStringAsFixed(1)}km" : "${nearestDist}m"} away',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _checkInNearestPandal,
                    child: const Text('Stamp 🛂', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Share to WhatsApp Banner
          InkWell(
            onTap: _sharePassportToWhatsApp,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B3D2F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Text('🟢', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Passport to WhatsApp & Instagram',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          'Brag your hopping rank and cultural stamps to your group',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.greenAccent, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Cultural Stamps Section Title
          const Row(
            children: [
              Text('🎖️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'COLLECTIBLE CULTURAL STAMPS',
                style: TextStyle(color: kMarigoldAmber, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cultural Stamps Grid
          ..._stamps.map((stamp) {
            final isUnlocked = stamp.isUnlocked(visited, _idToPandal);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUnlocked ? const Color(0xFF1E1C30) : const Color(0xFF12121E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUnlocked ? kMarigoldAmber.withOpacity(0.6) : Colors.white10,
                  width: isUnlocked ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isUnlocked ? kMarigoldAmber.withOpacity(0.18) : Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(color: isUnlocked ? kMarigoldAmber : Colors.white12),
                    ),
                    child: Center(
                      child: Text(
                        stamp.icon,
                        style: TextStyle(fontSize: 24, color: isUnlocked ? null : Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stamp.title,
                                style: TextStyle(
                                  color: isUnlocked ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (isUnlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'UNLOCKED',
                                  style: TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              const Text('🔒 Locked', style: TextStyle(color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stamp.titleBengali,
                          style: TextStyle(color: isUnlocked ? kMarigoldAmber : Colors.white30, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stamp.description,
                          style: TextStyle(color: isUnlocked ? Colors.white70 : Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
