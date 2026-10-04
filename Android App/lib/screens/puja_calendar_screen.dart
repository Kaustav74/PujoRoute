import 'dart:async';
import 'package:flutter/material.dart';
import '../data/puja_calendar_data.dart';
import '../data/pujas_data.dart';
import '../widgets/alpana_header.dart';
import '../services/session_service.dart';
import 'circuit_studio_screen.dart';

const Color kSindoorRed = Color(0xFFE62E2D);
const Color kDeepMaroon = Color(0xFF880E14);
const Color kMarigoldAmber = Color(0xFFFFB300);
const Color kMidnightBlue = Color(0xFF0D0D1E);
const Color kTranslucentObsidian = Color(0xFF1C1C2E);
const Color kKashWhite = Color(0xFFFFF8E7);

class PujaCalendarScreen extends StatefulWidget {
  final double userLat;
  final double userLon;
  final String initialDayId;
  final String? initialSchool;

  const PujaCalendarScreen({
    super.key,
    this.userLat = 22.5726,
    this.userLon = 88.3639,
    this.initialDayId = 'ashtami',
    this.initialSchool,
  });

  @override
  State<PujaCalendarScreen> createState() => _PujaCalendarScreenState();
}

class _PujaCalendarScreenState extends State<PujaCalendarScreen> {
  late String _selectedDayId;
  bool _isTraditionalPara =
      false; // false = Belur Math (Vishuddha), true = Traditional Para (Beni Madhab)
  Timer? _tickerTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDayId = widget.initialDayId;
    if (widget.initialSchool == 'traditional' ||
        widget.initialSchool == 'beni_madhab') {
      _isTraditionalPara = true;
    } else if (widget.initialSchool == 'vishuddha' ||
        widget.initialSchool == 'belur_math') {
      _isTraditionalPara = false;
    }
    _now = DateTime.now();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  String _formatMonospaceTicker(Duration diff) {
    if (diff.isNegative) return "00d : 00h : 00m : 00s";
    final days = diff.inDays.toString().padLeft(2, '0');
    final hours = (diff.inHours % 24).toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "${days}d : ${hours}h : ${minutes}m : ${seconds}s";
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = getPujaDayById(_selectedDayId);
    final daysRemaining = selectedDay.daysRemaining;

    // Dynamic Target Epoch Determination
    DateTime activeTargetTime = selectedDay.targetDateTime;
    String activeMilestoneTitle = selectedDay.titleEnglish;
    if (activeTargetTime.isBefore(_now)) {
      final nextMilestone = getNextActiveMilestone(_now);
      if (nextMilestone.targetDateTime.isAfter(_now)) {
        activeTargetTime = nextMilestone.targetDateTime;
        activeMilestoneTitle = nextMilestone.name;
      }
    }
    final Duration remainingDuration = activeTargetTime.difference(_now);
    final String tickerText = _formatMonospaceTicker(remainingDuration);

    // Resolve recommended pandal objects from ID list
    final recommendedPandals = kAllKolkataPujas
        .where((p) => selectedDay.recommendedPandalIds.contains(p.id))
        .toList();

    return Scaffold(
      backgroundColor: kMidnightBlue,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB71C1C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'শারদ পঞ্জিকা ২০২৬',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Durga Puja 2026 Calendar & Tithis',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [],
      ),
      body: Column(
        children: [
          // 1. Traditional Alpana Decorative Top Banner
          AlpanaHeader(
            height: 86,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kMarigoldAmber.withValues(alpha: 0.2),
                      border: Border.all(color: kMarigoldAmber, width: 1.5),
                    ),
                    child: const Text('🪔', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'মা আসছেন — আনন্দময়ী দুর্গোৎসব',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: kKashWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          remainingDuration.isNegative
                              ? '🎉 Sharodotsav is here! Shubho Durgotsav!'
                              : '⏳ $tickerText until $activeMilestoneTitle',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFFFD54F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Panjika Tradition Toggle: Belur Math vs Traditional Para (50/50 Symmetric Segmented Switcher)
          Container(
            color: const Color(0xFF141224),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1A30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: () => setState(() => _isTraditionalPara = false),
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            vertical: 9, horizontal: 8),
                        decoration: BoxDecoration(
                          color: !_isTraditionalPara
                              ? kSindoorRed
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: !_isTraditionalPara
                              ? [
                                  BoxShadow(
                                      color: kSindoorRed.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1))
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isTraditionalPara) ...[
                              const Icon(Icons.check,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Belur Math (Vishuddha)',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: !_isTraditionalPara
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: !_isTraditionalPara
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: () => setState(() => _isTraditionalPara = true),
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            vertical: 9, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _isTraditionalPara
                              ? const Color(0xFFFF8F00)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _isTraditionalPara
                              ? [
                                  BoxShadow(
                                      color: const Color(0xFFFF8F00)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1))
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isTraditionalPara) ...[
                              const Icon(Icons.check,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Traditional (Beni Madhab)',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: _isTraditionalPara
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 11.5,
                                    fontWeight: _isTraditionalPara
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Horizontal Scrollable Tithi Selector
          Container(
            color: const Color(0xFF141224),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: kDurgaPujaCalendar2026.map((day) {
                  final isSelected = day.id == _selectedDayId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedDayId = day.id);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [kSindoorRed, kMarigoldAmber],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected ? null : kTranslucentObsidian,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? kMarigoldAmber : Colors.white12,
                            width: 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: kSindoorRed.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getDayIcon(day.id),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              day.dayName,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 3. Main Detail Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prominent Tithi Days Left Countdown Card (Clean, Full-Width & Non-Redundant)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: daysRemaining > 0
                          ? [const Color(0xFF2C1914), const Color(0xFF1E1428)]
                          : (daysRemaining == 0
                              ? [
                                  const Color(0xFF132C19),
                                  const Color(0xFF12241C)
                                ]
                              : [
                                  const Color(0xFF232332),
                                  const Color(0xFF1A1A26)
                                ]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: daysRemaining > 0
                          ? kMarigoldAmber.withValues(alpha: 0.3)
                          : (daysRemaining == 0
                              ? Colors.greenAccent.withValues(alpha: 0.3)
                              : Colors.white12),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (daysRemaining > 0
                                  ? kMarigoldAmber
                                  : (daysRemaining == 0
                                      ? Colors.greenAccent
                                      : Colors.white38))
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          daysRemaining > 0
                              ? Icons.hourglass_top_rounded
                              : (daysRemaining == 0
                                  ? Icons.celebration_rounded
                                  : Icons.check_circle_outline),
                          color: daysRemaining > 0
                              ? kMarigoldAmber
                              : (daysRemaining == 0
                                  ? Colors.greenAccent
                                  : Colors.white70),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              daysRemaining > 0
                                  ? '${selectedDay.daysRemaining} DAYS REMAINING'
                                  : (daysRemaining == 0
                                      ? 'CELEBRATING TODAY'
                                      : 'TITHI CONCLUDED'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: daysRemaining > 0
                                    ? kMarigoldAmber
                                    : (daysRemaining == 0
                                        ? Colors.greenAccent
                                        : Colors.white70),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              daysRemaining > 0
                                  ? '${selectedDay.dayName} • ${selectedDay.dateFormatted}'
                                  : (daysRemaining == 0
                                      ? 'Maa Durga is here — enjoy the divine celebrations!'
                                      : 'Concluded on ${selectedDay.dateFormatted}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Header Day Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A111A), Color(0xFF1C1C2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: kSindoorRed.withValues(alpha: 0.5), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: kSindoorRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              selectedDay.dayName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '📅 ${selectedDay.dateFormatted}',
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedDay.titleBengali,
                        style: const TextStyle(
                          color: kKashWhite,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedDay.titleEnglish,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.access_time_filled,
                                    color: kMarigoldAmber, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'TITHI TIMINGS',
                                  style: TextStyle(
                                    color: kMarigoldAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              selectedDay
                                  .getTithiTimings(
                                      isTraditionalPara: _isTraditionalPara)
                                  .replaceAll(' | ', '\n• '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Card 1: Auspicious Moments & Sacred Panjika Muhurats (Structured Key-Value Badges)
                _buildSectionCard(
                  title: _isTraditionalPara
                      ? 'Auspicious Muhurats (Beni Madhab)'
                      : 'Auspicious Muhurats (Vishuddha)',
                  icon: Icons.brightness_high,
                  accentColor: _isTraditionalPara
                      ? const Color(0xFFFFB300)
                      : kSindoorRed,
                  child: _buildAuspiciousMomentsContent(
                    selectedDay.getAuspiciousMoments(
                        isTraditionalPara: _isTraditionalPara),
                    _isTraditionalPara ? const Color(0xFFFFB300) : kSindoorRed,
                  ),
                ),

                const SizedBox(height: 14),

                // Card 2: Vedic Ritual Significance
                _buildSectionCard(
                  title: 'Ritual Heritage & Significance',
                  icon: Icons.auto_awesome,
                  accentColor: const Color(0xFFFF7043),
                  child: Text(
                    selectedDay.ritualSignificance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Card 3: Crowd Forecast & Best Visiting Strategy
                _buildSectionCard(
                  title: 'Crowd Advisory & Optimal Visiting Hours',
                  icon: Icons.groups,
                  accentColor: _getCrowdColor(selectedDay.crowdLevel),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: selectedDay.crowdLevel,
                                backgroundColor: Colors.white12,
                                color: _getCrowdColor(selectedDay.crowdLevel),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            selectedDay.crowdForecast,
                            style: TextStyle(
                              color: _getCrowdColor(selectedDay.crowdLevel),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Recommended Timing Windows:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...selectedDay.bestVisitingHours.map((window) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('⏱️ ',
                                    style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    window,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Card 4: Festive Attire & Traditional Bhog
                _buildSectionCard(
                  title: 'Traditional Attire & Festive Bhog',
                  icon: Icons.restaurant_menu,
                  accentColor: const Color(0xFF81C784),
                  child: Text(
                    selectedDay.attireAndBhog,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Card 5: AI Curated Pandals for this Day
                if (recommendedPandals.isNotEmpty)
                  _buildSectionCard(
                    title: 'Recommended Pandals for ${selectedDay.dayName}',
                    icon: Icons.temple_hindu,
                    accentColor: kMarigoldAmber,
                    child: Column(
                      children: recommendedPandals.map((p) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '📍 ${p.subsection}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFD54F),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '🚇 ${p.metroStation}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  SessionService.instance.isInCircuit(p.id)
                                      ? Icons.remove_circle_outline
                                      : Icons.add_circle_outline,
                                  color:
                                      SessionService.instance.isInCircuit(p.id)
                                          ? Colors.redAccent
                                          : kMarigoldAmber,
                                ),
                                tooltip:
                                    SessionService.instance.isInCircuit(p.id)
                                        ? 'Remove from Circuit'
                                        : 'Add to Circuit',
                                onPressed: () async {
                                  await SessionService.instance
                                      .toggleCircuit(p.id);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 14),

                // Card 6: AI Pro Hopping Tips
                _buildSectionCard(
                  title: 'Survival Pro-Tips',
                  icon: Icons.tips_and_updates,
                  accentColor: const Color(0xFF64B5F6),
                  child: Column(
                    children: selectedDay.aiProTips.map((tip) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 ', style: TextStyle(fontSize: 12)),
                            Expanded(
                              child: Text(
                                tip,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 20),

                // Bottom Action Buttons: Open Circuit Studio or Chat with AI
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kSindoorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.alt_route_rounded, size: 18),
                        label: const Text(
                          'Plan Itinerary',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          // Add recommended pandals to circuit and navigate to Circuit Studio
                          for (final p in recommendedPandals) {
                            if (!SessionService.instance.isInCircuit(p.id)) {
                              SessionService.instance.toggleCircuit(p.id);
                            }
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CircuitStudioScreen(
                                userLat: widget.userLat,
                                userLon: widget.userLon,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kTranslucentObsidian,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.3), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAuspiciousMomentsContent(String rawText, Color accentColor) {
    final items = rawText
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (items.isEmpty) {
      return Text(rawText,
          style: const TextStyle(color: Color(0xFFFFF9C4), fontSize: 13));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final colonIdx = item.indexOf(':');
        String badge = '';
        String timing = item;
        if (colonIdx != -1) {
          badge = item.substring(0, colonIdx).trim();
          timing = item.substring(colonIdx + 1).trim();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                timing,
                style: const TextStyle(
                  color: Color(0xFFFFF9C4),
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getCrowdColor(double level) {
    if (level <= 0.4) return Colors.greenAccent;
    if (level <= 0.7) return Colors.amber;
    if (level <= 0.9) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _getDayIcon(String id) {
    switch (id) {
      case 'mahalaya':
        return '🐚';
      case 'panchami':
        return '✨';
      case 'shashthi':
        return '🌿';
      case 'saptami':
        return '🌊';
      case 'ashtami':
        return '🪔';
      case 'nabami':
        return '🔥';
      case 'dashami':
        return '🌺';
      case 'lakshmi_puja':
        return '🌾';
      default:
        return '🪷';
    }
  }
}
