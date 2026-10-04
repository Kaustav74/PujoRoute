// Durga Puja 2026 Panjika, Tithi Schedule & AI Festival Calendar (Kolkata, IST)
//
// Two timing modes:
//  * Belur Math (default): Vishuddha Siddhanta almanac, the one Belur Math follows.
//    https://media.belurmath.org/sri-sri-durga-puja-2026-programme-details-25017/
//  * Beni Madhab / Gupta Press (`...Traditional` fields): traditional panjika.
//    https://benimadhabsilpanjika.com/durga-puja-2026/
// Cross-checked against Drik Panchang for Kolkata (geoname-id=1275004):
//    https://www.drikpanchang.com/navratri/durga-puja/durga-puja-calendar.html?geoname-id=1275004&year=2026
//
// Each day has ONE date field, [PujaDayTithi.startsAt]. The displayed date
// ([PujaDayTithi.dateFormatted]), the calendar day ([PujaDayTithi.targetDate]),
// the countdown target ([PujaDayTithi.targetDateTime]) and the header
// milestones ([kPuja2026Milestones]) are all derived from it, so they cannot
// disagree. The clock time in each [startsAt] is the app's countdown anchor
// for that day (not a panjika value) unless a comment cites a source.

class PujaDayTithi {
  final String id;
  final String dayName;
  final String titleBengali;
  final String titleEnglish;

  /// The single source of truth for this day's date: the observance day and
  /// the exact instant (IST) the countdown runs to.
  final DateTime startsAt;
  final String tithiName;
  final String tithiTimings;
  final String auspiciousMoments;
  final String ritualSignificance;
  final String attireAndBhog;
  final String crowdForecast;
  final double crowdLevel; // 0.1 (calm) to 1.0 (extreme frenzy)
  final List<String> bestVisitingHours;
  final List<String> recommendedPandalIds;
  final List<String> aiProTips;
  final String? auspiciousMomentsTraditional;
  final String? tithiTimingsTraditional;

  PujaDayTithi({
    required this.id,
    required this.dayName,
    required this.titleBengali,
    required this.titleEnglish,
    required this.startsAt,
    required this.tithiName,
    required this.tithiTimings,
    required this.auspiciousMoments,
    required this.ritualSignificance,
    required this.attireAndBhog,
    required this.crowdForecast,
    required this.crowdLevel,
    required this.bestVisitingHours,
    required this.recommendedPandalIds,
    required this.aiProTips,
    this.auspiciousMomentsTraditional,
    this.tithiTimingsTraditional,
  });

  String getAuspiciousMoments({bool isTraditionalPara = false}) {
    if (isTraditionalPara &&
        auspiciousMomentsTraditional != null &&
        auspiciousMomentsTraditional!.isNotEmpty) {
      return auspiciousMomentsTraditional!;
    }
    return auspiciousMoments;
  }

  String getTithiTimings({bool isTraditionalPara = false}) {
    if (isTraditionalPara &&
        tithiTimingsTraditional != null &&
        tithiTimingsTraditional!.isNotEmpty) {
      return tithiTimingsTraditional!;
    }
    return tithiTimings;
  }

  /// Calendar day (midnight IST) of the observance, derived from [startsAt].
  DateTime get targetDate =>
      DateTime(startsAt.year, startsAt.month, startsAt.day);

  /// Exact countdown target (IST), derived from [startsAt].
  DateTime get targetDateTime => startsAt;

  /// Displayed date, e.g. "Friday, 16 October 2026", derived from [startsAt].
  String get dateFormatted => formatPujaDate(startsAt);

  /// Whole days left until [targetDateTime], using the same rule as the
  /// Panjika header ticker (see [countdownWholeDays]).
  int get daysRemaining => getDaysRemaining();

  int getDaysRemaining([DateTime? now]) =>
      countdownWholeDays(targetDateTime, now ?? DateTime.now());

  /// 1 = upcoming, 0 = under way (started and its calendar date has not
  /// ended yet), -1 = concluded.
  int countdownState(DateTime now) {
    if (targetDateTime.isAfter(now)) return 1;
    final endOfDay =
        DateTime(targetDate.year, targetDate.month, targetDate.day + 1);
    return now.isBefore(endOfDay) ? 0 : -1;
  }
}

/// Single countdown rule for the Panjika screen, shared by the header ticker
/// and the "days remaining" card so they always agree: whole days are the
/// floor of the remaining hours / 24, measured to the exact start time.
int countdownWholeDays(DateTime target, DateTime now) {
  final diff = target.difference(now);
  return diff.isNegative ? 0 : diff.inDays;
}

/// Header ticker text, e.g. "14d : 03h : 00m : 00s".
String formatCountdownTicker(DateTime target, DateTime now) {
  final diff = target.difference(now);
  if (diff.isNegative) return "00d : 00h : 00m : 00s";
  final days = countdownWholeDays(target, now).toString().padLeft(2, '0');
  final hours = (diff.inHours % 24).toString().padLeft(2, '0');
  final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
  return "${days}d : ${hours}h : ${minutes}m : ${seconds}s";
}

const List<String> _kWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const List<String> _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

/// "Friday, 16 October 2026". Locale-independent so the text never drifts
/// from the [DateTime] it is built from.
String formatPujaDate(DateTime d) =>
    '${_kWeekdays[d.weekday - 1]}, ${d.day} ${_kMonths[d.month - 1]} ${d.year}';

class PujaTithiDay {
  final String id;
  final String titleEn;
  final String titleBn;
  final String subTitle;
  final DateTime tithiStart;
  final DateTime tithiEnd;
  final String muhuratTitle;
  final String muhuratWindow;

  PujaTithiDay({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.subTitle,
    required this.tithiStart,
    required this.tithiEnd,
    required this.muhuratTitle,
    required this.muhuratWindow,
  });

  /// Same instant as the matching [PujaDayTithi.targetDateTime], so this
  /// list can never disagree with the Panjika screen.
  DateTime get targetDate => getPujaDayById(id).targetDateTime;

  int get daysRemaining => countdownWholeDays(targetDate, DateTime.now());
}

final List<PujaTithiDay> pujaCalendar2026 = [
  PujaTithiDay(
    id: 'mahalaya',
    titleEn: 'Mahalaya',
    titleBn: 'মহালয়া — আগমনী ও চণ্ডীপাঠ',
    subTitle: 'Mahalaya (Devi Paksha Invocation)',
    tithiStart: DateTime(2026, 10, 9, 21, 35),
    tithiEnd: DateTime(2026, 10, 10, 21, 19),
    muhuratTitle: 'Dawn Tarpan at Ganga Ghats',
    muhuratWindow: '04:30 AM - 08:30 AM',
  ),
  PujaTithiDay(
    id: 'panchami',
    titleEn: 'Maha Panchami',
    titleBn: 'মহা পঞ্চমী — আনন্দময়ী আগমনী',
    subTitle: 'Maha Panchami (Grand Inaugurations)',
    tithiStart: DateTime(2026, 10, 15, 1, 13),
    tithiEnd: DateTime(2026, 10, 16, 3, 26),
    muhuratTitle: 'VIP & Public Inaugurations',
    muhuratWindow: '04:00 PM onwards',
  ),
  PujaTithiDay(
    id: 'shashthi',
    titleEn: 'Maha Shashthi',
    titleBn: 'মহা ষষ্ঠী — বোধন, আমন্ত্রণ ও অধিবাস',
    subTitle: 'Maha Shashthi (Devi Bodhon & Awakening)',
    tithiStart: DateTime(2026, 10, 16, 3, 26),
    tithiEnd: DateTime(2026, 10, 17, 5, 55),
    muhuratTitle: 'Prabhat Kalparambha',
    muhuratWindow: '05:33 AM - 08:30 AM (Fri 16 Oct)',
  ),
  PujaTithiDay(
    id: 'saptami',
    titleEn: 'Maha Saptami',
    titleBn: 'মহা সপ্তমী — নবপত্রিকা স্নান ও প্রাণ প্রতিষ্ঠা',
    subTitle: 'Maha Saptami (Nabapatrika / Kola Bou Snan)',
    tithiStart: DateTime(2026, 10, 17, 5, 55),
    tithiEnd: DateTime(2026, 10, 18, 8, 30),
    muhuratTitle: 'Nabapatrika Pravesh & Snan (Kola Bou river bath)',
    muhuratWindow: '05:45 AM - 07:15 AM',
  ),
  PujaTithiDay(
    id: 'ashtami',
    titleEn: 'Maha Ashtami',
    titleBn: 'মহা অষ্টমী — কুমারী পূজা ও সন্ধিপূজা',
    subTitle: 'Maha Ashtami (Kumari Puja & Sandhi Puja)',
    tithiStart: DateTime(2026, 10, 18, 8, 30),
    tithiEnd: DateTime(2026, 10, 19, 10, 52),
    muhuratTitle: 'Belur Math Sandhi Puja Muhurta',
    muhuratWindow: '10:28 AM - 11:16 AM (Balidan: 10:52 AM)',
  ),
  PujaTithiDay(
    id: 'nabami',
    titleEn: 'Maha Nabami',
    titleBn: 'মহা নবমী — নবমী হোম ও ধুনুচি নাচ',
    subTitle: 'Maha Nabami (Sacred Homa & Dhunuchi Naach)',
    tithiStart: DateTime(2026, 10, 19, 10, 52),
    tithiEnd: DateTime(2026, 10, 20, 12, 51),
    muhuratTitle: 'Nabami Vihita Puja',
    muhuratWindow: '05:30 AM - 09:27 AM',
  ),
  PujaTithiDay(
    id: 'dashami',
    titleEn: 'Bijoya Dashami',
    titleBn: 'বিজয়া দশমী — সিঁদুর খেলা ও বিসর্জন',
    subTitle: 'Bijoya Dashami (Sindoor Khela & Immersion)',
    tithiStart: DateTime(2026, 10, 20, 12, 51),
    tithiEnd: DateTime(2026, 10, 21, 14, 12),
    muhuratTitle: 'Dashami Vihita Puja & Darpan Bisarjan',
    muhuratWindow: '05:35 AM - 08:30 AM',
  ),
  PujaTithiDay(
    id: 'lakshmi_puja',
    titleEn: 'Kojagori Lakshmi Puja',
    titleBn: 'কোজাগরী লক্ষ্মীপূজা — ধনধান্য ও সৌভাগ্য আরাধনা',
    subTitle: 'Kojagori Lakshmi Puja (Purnima Worship)',
    tithiStart: DateTime(2026, 10, 25, 11, 55),
    tithiEnd: DateTime(2026, 10, 26, 9, 41),
    muhuratTitle: 'Nishitha Kaal Lakshmi Aradhana',
    muhuratWindow: '10:56 PM - 11:46 PM',
  ),
];

final List<PujaDayTithi> kDurgaPujaCalendar2026 = [
  PujaDayTithi(
    id: 'mahalaya',
    dayName: 'Mahalaya',
    titleBengali: 'মহালয়া — আগমনী ও চণ্ডীপাঠ',
    titleEnglish: 'Mahalaya (Devi Paksha Invocation)',
    // Date: Sat 10 Oct, Mahalaya Amavasya. Drik Panchang Kolkata:
    // Amavasya 09 Oct 09:35 PM - 10 Oct 09:19 PM (matches tithiTimings).
    // https://www.drikpanchang.com/shraddha/tithi/amavasya-shraddha-date-time.html?year=2026&geoname-id=1275004
    // UNVERIFIED: 06:00 is the app's countdown anchor, not a panjika time.
    // No Beni Madhab / Gupta Press Amavasya times found online; none shown.
    startsAt: DateTime(2026, 10, 10, 6, 0),
    tithiName: 'Ashwin Krishna Amavasya ( পিতৃপক্ষ অবসান ও দেবীপক্ষ সূচনা )',
    tithiTimings:
        'Amavasya begins: 09 Oct 09:35 PM | Amavasya ends: 10 Oct 09:19 PM',
    auspiciousMoments:
        'Dawn Tarpan at Ganga Ghats: 04:30 AM - 08:30 AM | Birendra Krishna Bhadra Mahishasura Mardini Broadcast: 04:00 AM | Chokkhudaan (Eye Painting) at Kumartuli: All Day',
    ritualSignificance:
        'Marks the formal advent of Devi Durga to Earth. Millions gather at the banks of the Hooghly (Babughat, Ahiritola, Bagbazar) to perform Tarpan for departed ancestors. In Kumartuli, sculptors perform sacred Chokkhudaan, painting the third eye of Maa Durga in reverent meditation.',
    attireAndBhog:
        'Traditional Dhoti-Kurta or Cotton Tant Sari for early morning riverfront Tarpan. Post-tarpan traditional breakfast of Luchi and Alur Dom.',
    crowdForecast:
        'High morning rush along Ganga Ghats and Kumartuli, calm elsewhere.',
    crowdLevel: 0.35,
    bestVisitingHours: [
      '04:00 AM - 07:30 AM: Ganga Ghats for sacred Tarpan atmosphere',
      '10:00 AM - 04:00 PM: Kumartuli Artisan Quarters to see final idol touches',
      '06:00 PM - 09:00 PM: Stroll through quiet pandal preparation works',
    ],
    recommendedPandalIds: [
      'ahiritola_sarbojanin',
      'sovabazar_beniatola',
      'basu-bati-bagbazar',
      'hathkhola_dutta',
    ],
    aiProTips: [
      'Head to Kumartuli before midday to witness idol eyes being drawn without heavy barricades.',
      'Take the Circular Railway or Kolkata Metro Blue Line to Shovabazar Sutanuti to avoid riverfront traffic.',
      'Carry water bottles and wear comfortable walking footwear for clay lanes in North Kolkata.',
    ],
  ),
  PujaDayTithi(
    id: 'panchami',
    dayName: 'Panchami',
    titleBengali: 'মহা পঞ্চমী — আনন্দময়ী আগমনী',
    titleEnglish: 'Maha Panchami (Grand Inaugurations)',
    // Date: Thu 15 Oct (Panchami at sunrise). Drik Panchang Kolkata:
    // Chaturthi ends 15 Oct 01:13 AM; Panchami ends 16 Oct 03:25 AM.
    // https://www.drikpanchang.com/bengali/bengali-month-panjika.html?date=15/10/2026&geoname-id=1275004
    // UNVERIFIED: Panchami end 03:26 AM (Vishuddha, Ei Samay) vs 03:25 AM
    // (Drik Panchang; myastrology.in Vishuddha table). Sources disagree; left as is.
    // Beni Madhab 14 Oct 11:51 PM - 16 Oct 01:43 AM matches
    // https://benimadhabsilpanjika.com/durga-puja-2026/
    // UNVERIFIED: 16:00 is the app's inauguration countdown anchor.
    startsAt: DateTime(2026, 10, 15, 16, 0),
    tithiName: 'Shukla Panchami',
    tithiTimings:
        'Panchami begins: 15 Oct 01:13 AM | Panchami ends: 16 Oct 03:26 AM',
    tithiTimingsTraditional:
        'Panchami begins: 14 Oct 11:51 PM | Panchami ends: 16 Oct 01:43 AM',
    auspiciousMoments:
        'VIP & Public Inaugurations: 04:00 PM onwards | Evening Pratima Unveiling & Pandal Inaugurations: Evening',
    ritualSignificance:
        'The festive atmosphere reaches ignition. While traditional Vedic rituals begin on Sasthi, Kolkata mega theme pandals throw open their doors for public preview. Theme lighting across VIP Road, Gariahat, and College Street is switched on.',
    attireAndBhog:
        'Smart festive ethnic or contemporary fusion. Light evening street snacks: Puchka, Mughlai Paratha, and Kathi Rolls.',
    crowdForecast:
        'Moderate evening surge. Highly recommended for hassle-free viewing.',
    crowdLevel: 0.45,
    bestVisitingHours: [
      '02:00 PM - 05:30 PM: Golden window for mega pandals with almost zero wait time',
      '07:00 PM - 11:30 PM: Theme illumination stroll along Lake Town & VIP Road',
    ],
    recommendedPandalIds: [
      'sreebhumi_sporting',
      'dumdum_park_tarun',
      'dumdum_tarun_dal',
      'suruchi_sangha',
    ],
    aiProTips: [
      'This is the single best day to visit Sreebhumi and VIP Road pandals before police one-way restrictions tighten.',
      'Use the newly connected East-West Metro (Green Line) to cover Salt Lake and Central easily.',
    ],
  ),
  PujaDayTithi(
    id: 'shashthi',
    dayName: 'Maha Shashthi',
    titleBengali: 'মহা ষষ্ঠী — বোধন, আমন্ত্রণ ও অধিবাস',
    titleEnglish: 'Maha Shashthi (Devi Bodhon & Awakening)',
    // Date: Fri 16 Oct. Was displayed as "Saturday, 17 October 2026" while the
    // countdown targeted 16 Oct. Both modes put Shashthi, Kalparambha and the
    // evening Bodhon on Friday 16 Oct:
    //  Vishuddha + traditional: https://eisamay.com/astrology/religion-and-rituals/durga-puja-2026-dates-timings-sasthi-saptami-ashtami-navami-dashami-bisudhha-siddhanta-prachin-panjika-puja-nirghonto/200533534.cms
    //  Vishuddha: https://myastrology.in/utsab/maha-sasthi
    //  Beni Madhab: https://benimadhabsilpanjika.com/durga-puja-2026/
    // FLAGGED: Drik Panchang Kolkata lists 16 Oct as Shashthi / Bilva
    // Nimantran but puts Kalparambha and Akal Bodhon on Sat 17 Oct:
    // https://www.drikpanchang.com/navratri/durga-puja/bengal/kalparambha-date-time.html?year=2026&geoname-id=1275004
    // UNVERIFIED: Shashthi start 03:26 AM (Ei Samay) vs 03:25 AM (Drik,
    // myastrology.in); end 05:55 AM (Vishuddha) vs 05:54 AM (Drik). Left as is.
    // UNVERIFIED: 06:00 is the app's countdown anchor.
    startsAt: DateTime(2026, 10, 16, 6, 0),
    tithiName: 'Shukla Shashthi',
    tithiTimings:
        'Shashthi begins: 16 Oct 03:26 AM | Shashthi ends: 17 Oct 05:55 AM',
    tithiTimingsTraditional:
        'Shashthi begins: 16 Oct 01:43 AM | Shashthi ends: 17 Oct 03:47 AM',
    auspiciousMoments:
        'Bodhon, Amantran & Adhibas (Fri evening): Friday evening | Prabhat Kalparambha & Shashthi Vihita Puja (Fri 16 Oct): 05:33 AM - 08:30 AM',
    auspiciousMomentsTraditional:
        'Para Kalparambha & Shashthi Vihita Puja (Fri 16 Oct): 05:38 AM - 08:30 AM | Bodhon, Amantran & Adhibas (Fri 16 Oct): 05:45 PM - 07:15 PM',
    ritualSignificance:
        'Sacred invocation of Devi Durga under the Bilva (Bel) tree. Bodhon awakens the Goddess from her divine slumber. In the evening, Adhibas is consecrated with 27 sacred auspicious items (Mangala Dravyas) amidst the resonant roar of Dhak drums and conch shells.',
    attireAndBhog:
        'Traditional Kurta Pajama / Tussar Silk Sari. Bhog includes fruits, sweets, Batasa, and Sandesh.',
    crowdForecast:
        'High festive surge beginning at sunset. Kolkata streets turn into an open-air carnival.',
    crowdLevel: 0.65,
    bestVisitingHours: [
      '08:00 AM - 11:00 AM: Witness serene Bel tree Bodhon rituals in traditional paras',
      '01:00 PM - 05:00 PM: Smooth transit between North and Central circuits',
      '08:00 PM - 02:00 AM: Pandal hopping starts in earnest under cool night breezes',
    ],
    recommendedPandalIds: [
      'college_square',
      'sovabazar_beniatola',
      'basu-bati-bagbazar',
      'hathkhola_dutta',
    ],
    aiProTips: [
      'Focus tonight on Central & North Kolkata heritage corridors where traditional Bodhon rituals take center stage.',
      'Central Kolkata Metro stations (MG Road, Central, Chandni Chowk) allow effortless walking access to College Sq and Bowbazar.',
    ],
  ),
  PujaDayTithi(
    id: 'saptami',
    dayName: 'Maha Saptami',
    titleBengali: 'মহা সপ্তমী — নবপত্রিকা স্নান ও প্রাণ প্রতিষ্ঠা',
    titleEnglish: 'Maha Saptami (Nabapatrika / Kola Bou Snan)',
    // Date: Sun 18 Oct. Belur Math Saptami puja is Sunday 18 Oct (begins
    // 5:30 AM): https://media.belurmath.org/sri-sri-durga-puja-2026-programme-details-25017/
    // Drik Panchang Kolkata Navpatrika Puja: 18 Oct; Saptami 17 Oct 05:54 AM -
    // 18 Oct 08:27 AM:
    // https://www.drikpanchang.com/navratri/durga-puja/navpatrika-puja-date-time.html?year=2026&geoname-id=1275004
    // UNVERIFIED: Saptami end 08:30 AM (Vishuddha per Hindustan Times Bangla)
    // vs 08:29 AM (Vishuddha per Ei Samay, myastrology.in) vs 08:27 AM (Drik).
    // Sources disagree; left as is.
    // FLAGGED: Beni Madhab puts Nabapatrika Pravesh on Sat 17 Oct (Saptami
    // runs 17 and 18 Oct); this card keeps the Belur Math date.
    // UNVERIFIED: 06:00 is the app's countdown anchor.
    startsAt: DateTime(2026, 10, 18, 6, 0),
    tithiName: 'Shukla Saptami',
    tithiTimings:
        'Saptami begins: 17 Oct 05:55 AM | Saptami ends: 18 Oct 08:30 AM',
    tithiTimingsTraditional:
        'Saptami begins: 17 Oct 03:47 AM | Saptami ends: 18 Oct 05:53 AM',
    auspiciousMoments:
        'Nabapatrika Snan (Kola Bou river bath) at dawn: 05:45 AM - 07:15 AM | Belur Math Puja begins: 5:30 AM | Saptami Vihita Puja: 05:30 AM - 08:30 AM | Maha Arati: 07:00 PM',
    auspiciousMomentsTraditional:
        'Nabapatrika Pravesh, Sthapan & Saptami Vihita Puja (Sat 17 Oct): 07:04 AM - 09:28 AM | Saptami Adhik Puja (Sun 18 Oct): before 05:53 AM | Ardharatra Puja (Sun 18 Oct): 10:59 PM - 11:47 PM',
    ritualSignificance:
        'At dawn, nine plants representing nine manifestations of Mother Nature are tied together as Nabapatrika (symbolic Kola Bou), draped in a red-bordered yellow saree, bathed in the sacred Hooghly River, and ceremoniously installed beside Lord Ganesha. Prana Pratishtha infuses divine life into the clay idols.',
    attireAndBhog:
        'Yellow or red festive wear. Saptami Bhog: Basanti Pulao, Chhanar Dalna, Alur Dum, Payesh, and Chutney.',
    crowdForecast:
        'Very Heavy crowds across all zones from afternoon until 4:00 AM.',
    crowdLevel: 0.85,
    bestVisitingHours: [
      '05:30 AM - 07:00 AM: Bagbazar Ghat & Ahiritola Ghat to witness Nabapatrika Snan procession',
      '11:00 AM - 03:00 PM: South Kolkata pandals during Bhog serving hours',
      '01:00 AM - 05:00 AM: Post-midnight hopping with shorter barricade lines',
    ],
    recommendedPandalIds: [
      'ekdalia_evergreen',
      'singhi_park',
      'maddox_square',
      'ballygunge_cultural',
      'deshapriya_park',
    ],
    aiProTips: [
      'Witness the morning Kola Bou immersion procession with traditional Dhakis at Bagbazar Ghat—a quintessential Bengal memory.',
      'South Kolkata Gariahat triangle (Ekdalia - Singhi Park - Ballygunge Cultural) is best navigated entirely on foot.',
    ],
  ),
  PujaDayTithi(
    id: 'ashtami',
    dayName: 'Maha Ashtami',
    titleBengali: 'মহা অষ্টমী — কুমারী পূজা ও সন্ধিপূজা',
    titleEnglish: 'Maha Ashtami (Kumari Puja & Sandhi Puja)',
    // Date: Mon 19 Oct. The Ashtami tithi begins the previous morning
    // (18 Oct) but Mahashtami is observed on 19 Oct (Ashtami at sunrise):
    // Belur Math Mahashtami Monday 19 Oct, Kumari Puja 9:00 AM, Sandhi Puja
    // 10:28-11:16 AM: https://media.belurmath.org/sri-sri-durga-puja-2026-programme-details-25017/
    // Drik Panchang Kolkata Durgashtami 19 Oct; Ashtami 18 Oct 08:27 AM -
    // 19 Oct 10:51 AM:
    // https://www.drikpanchang.com/navratri/durga-puja/mahashtami-date-time.html?year=2026&geoname-id=1275004
    // UNVERIFIED: start 08:30 AM (Hindustan Times Bangla, Vishuddha) vs
    // 08:29 AM (Ei Samay, myastrology.in) vs 08:27 AM (Drik); end 10:52 AM
    // (Vishuddha) vs 10:51 AM (Drik). Left as is.
    // Beni Madhab 18 Oct 05:53 AM - 19 Oct 07:50 AM, Sandhi 07:26-08:14 AM
    // matches https://benimadhabsilpanjika.com/durga-puja-2026/ ; Gupta Press
    // gives 05:52:10 AM - 07:49:15 AM, Sandhi 07:25:15-08:13:15 AM
    // (Hindustan Times Bangla). Left as is.
    // UNVERIFIED: 06:30 is the app's Pushpanjali countdown anchor.
    startsAt: DateTime(2026, 10, 19, 6, 30),
    tithiName: 'Shukla Ashtami',
    tithiTimings:
        'Ashtami begins: 18 Oct 08:30 AM | Ashtami ends: 19 Oct 10:52 AM',
    tithiTimingsTraditional:
        'Ashtami begins: 18 Oct 05:53 AM | Ashtami ends: 19 Oct 07:50 AM',
    auspiciousMoments:
        'Kumari Puja at Belur Math: 09:00 AM | Belur Math Sandhi Puja Muhurta: 10:28 AM – 11:16 AM (Balidan: 10:52 AM) | Maha Ashtami Pushpanjali: 09:30 AM - 10:25 AM',
    auspiciousMomentsTraditional:
        'Traditional Para Pushpanjali: 06:30 AM - 07:05 AM | Traditional Para Sandhi Puja (Beni Madhab): 07:26 AM – 08:14 AM (Balidan: 07:50 AM) | Para Community Bhog: 12:30 PM - 02:00 PM',
    ritualSignificance:
        'The crown jewel of Durga Puja. Devotees fast until offering morning Pushpanjali. At Belur Math, a young prepubescent girl is worshipped as the living Goddess (Kumari Puja). During Sandhi Puja—the 48-minute juncture between Ashtami and Navami—Devi Chamunda is invoked with 108 blue lotuses and 108 glowing earthen diyas to slay demons Chanda and Munda.',
    attireAndBhog:
        'Quintessential Lal-Paar Sada Sari (white with crimson border) for women; Gorod/Tasor Kurta Dhoti for men. Authentic Ashtami Khichuri Bhog with Labra, Beguni, and Tomato-Khejur chutney.',
    crowdForecast:
        'MEGA PEAK FRENZY. Kolkata records its highest footfall of the entire year.',
    crowdLevel: 1.0,
    bestVisitingHours: [
      '08:30 AM - 11:00 AM: Community pandals for Pushpanjali & Sandhi Puja rituals',
      '02:00 PM - 05:00 PM: Traditional Rajbari courtyards for Kumari Puja & Bhog distribution',
      '02:30 AM - 05:30 AM: The miraculous dawn lull where even the biggest pandals have minimal lines',
    ],
    recommendedPandalIds: [
      'maddox_square',
      'naktala_udayan',
      'singhi_park',
      'ekdalia_evergreen',
      'sovabazar_beniatola',
    ],
    aiProTips: [
      'Do not plan car or taxi travel across zones between 6:00 PM and 2:00 AM. Rely on Kolkata Metro or pedestrian circuits.',
      'Be seated at your local para pandal by 09:15 AM to receive flowers and bel leaves for Ashtami Pushpanjali.',
      'Carry a small pouch with water, glucose, and power bank for the high density.',
    ],
  ),
  PujaDayTithi(
    id: 'nabami',
    dayName: 'Maha Nabami',
    titleBengali: 'মহা নবমী — নবমী হোম ও ধুনুচি নাচ',
    titleEnglish: 'Maha Nabami (Sacred Homa & Dhunuchi Naach)',
    // Date: Tue 20 Oct. Belur Math Mahanavami Tuesday 20 Oct:
    // https://media.belurmath.org/sri-sri-durga-puja-2026-programme-details-25017/
    // Drik Panchang Kolkata Bengal Maha Navami 20 Oct; Navami 19 Oct 10:51 AM
    // - 20 Oct 12:50 PM:
    // https://www.drikpanchang.com/navratri/durga-puja/bengal/maha-navami-date-time.html?year=2026&geoname-id=1275004
    // UNVERIFIED: 10:52 AM / 12:51 PM (Vishuddha: Ei Samay, myastrology.in)
    // vs 10:51 AM / 12:50 PM (Drik). Left as is.
    // UNVERIFIED: 11:30 is the app's Maha Homa countdown anchor; Belur Math
    // only says Homa is "after Bhogarati".
    startsAt: DateTime(2026, 10, 20, 11, 30),
    tithiName: 'Shukla Nabami',
    tithiTimings:
        'Nabami begins: 19 Oct 10:52 AM | Nabami ends: 20 Oct 12:51 PM',
    tithiTimingsTraditional:
        'Nabami begins: 19 Oct 07:50 AM | Nabami ends: 20 Oct 09:31 AM',
    auspiciousMoments:
        'Nabami Vihita Puja: 05:30 AM - 09:27 AM | Nabami Homa & Yajna following morning Bhog: Following morning Bhog | Evening Dhunuchi Naach: 08:00 PM - 01:00 AM',
    auspiciousMomentsTraditional:
        'Para Nabami Vihita Puja: before 07:05 AM or 08:31 AM - 09:28 AM | Para Maha Homa: before Nabami ends (09:31 AM) | Dhunuchi Dance Competitions: 07:30 PM - Midnight',
    ritualSignificance:
        'Marks the triumph of Goddess Durga over the buffalo demon Mahishasura. The grand Maha Homa consecrates wood from sacred trees with ghee and bilva leaves. At night, frenetic Dhunuchi Naach erupts in pandals—dancers balancing smoking earthen pots filled with burning coconut husk and camphor in their hands and teeth to high-tempo Dhak beats.',
    attireAndBhog:
        'Vibrant celebratory silk kurtas and designer saris. Grand feast day: Mutton Kosha, Basanti Pulao, Fish Fry, and Mishti Doi.',
    crowdForecast:
        'Peak All-Night Revelry. Crowds stay on the streets till 6:00 AM dawn.',
    crowdLevel: 0.98,
    bestVisitingHours: [
      '10:00 AM - 01:00 PM: Witness the hypnotic Maha Homa Vedic chants in pandals',
      '07:00 PM - 11:00 PM: Watch passionate Dhunuchi dance competitions',
      'Midnight - 05:00 AM: Ultimate all-night pandal hopping experience',
    ],
    recommendedPandalIds: [
      'ballygunge_cultural',
      'behala_club',
      'dumdum_park_bharat',
      'santoshpur_lake_pally',
      'suruchi_sangha',
    ],
    aiProTips: [
      'Take an afternoon nap! Tonight is the traditional all-night hopping night where metro trains run throughout the night.',
      'Visit Maddox Square around 9:00 PM for the ultimate open-air adda and Dhunuchi beats.',
    ],
  ),
  PujaDayTithi(
    id: 'dashami',
    dayName: 'Bijoya Dashami',
    titleBengali: 'বিজয়া দশমী — সিঁদুর খেলা ও বিসর্জন',
    titleEnglish: 'Bijoya Dashami (Sindoor Khela & Immersion)',
    // Date: Wed 21 Oct. Drik Panchang Kolkata Bengal Durga Visarjan 21 Oct;
    // Dashami 20 Oct 12:50 PM - 21 Oct 02:11 PM:
    // https://www.drikpanchang.com/navratri/durga-puja/bengal/durga-visarjan-date-time.html?year=2026&geoname-id=1275004
    // UNVERIFIED: 12:51 PM / 02:12 PM (Vishuddha: Ei Samay, myastrology.in)
    // vs 12:50 PM / 02:11 PM (Drik). Left as is. Belur Math's 2026 page
    // does not list Dashami.
    // UNVERIFIED: 06:00 is the app's countdown anchor.
    startsAt: DateTime(2026, 10, 21, 6, 0),
    tithiName: 'Shukla Dashami',
    tithiTimings:
        'Dashami begins: 20 Oct 12:51 PM | Dashami ends: 21 Oct 02:12 PM',
    tithiTimingsTraditional:
        'Dashami begins: 20 Oct 09:31 AM | Dashami ends: 21 Oct 10:47 AM',
    auspiciousMoments:
        'Dashami Vihita Puja & Darpan Bisarjan: 05:35 AM - 08:30 AM | Vijay Muhurat: 01:16 PM - 02:02 PM | Sindoor Khela: 11:30 AM - 03:30 PM | Ganga Ghat Bisarjan: 04:30 PM - Midnight',
    auspiciousMomentsTraditional:
        'Dashami Vihita Puja & Darpan Bisarjan: 05:40 AM - 08:31 AM | Aparajita Puja: after Bisarjan | Sindoor Khela: 11:00 AM - 03:00 PM | Bisarjan Processions: 04:00 PM - 11:00 PM',
    ritualSignificance:
        'The tearful and bittersweet farewell (Bisarjan) as Mother Durga prepares her journey back to Mount Kailash. Darpan Visarjan mirrors her departure. Married women participate in radiant Sindoor Khela, applying vermilion to Devi\'s forehead and to each other wishing long marital bliss. In the evening, solemn processions accompany the idols to the Ganga ghats. Elders are greeted with touch-feet Pranams and sweets with "Shubho Bijoya" greetings.',
    attireAndBhog:
        'Lal-Paar Sada Sari for Sindoor Khela. Evening sweet exchange: Sandesh, Rosogolla, Ghol, Nimki, and Ghugni.',
    crowdForecast:
        'High emotion and vibrant processions along riverfronts and ghats.',
    crowdLevel: 0.70,
    bestVisitingHours: [
      '11:00 AM - 02:30 PM: Bagbazar, Sovabazar, or para pandals to witness Sindoor Khela',
      '04:30 PM - 09:30 PM: Babughat and Baje Kadamtala Ghat for scenic boat-side Bisarjan',
      '07:00 PM - Midnight: Home visits and sweet sharing for Shubho Bijoya',
    ],
    recommendedPandalIds: [
      'sovabazar_beniatola',
      'basu-bati-bagbazar',
      'khelat_ghosh',
      'hathkhola_dutta',
    ],
    aiProTips: [
      'For iconic Sindoor Khela photography, arrive early at Sovabazar Rajbari or Bagbazar Sarbojanin.',
      'Head to Babughat on the strand road to watch synchronized crane immersions organized by Kolkata Police and KMC.',
      'Don\'t forget to say "Shubho Bijoya" and touch the feet of elders when visiting family and friends tonight!',
    ],
  ),
  PujaDayTithi(
    id: 'lakshmi_puja',
    dayName: 'Kojagori Lakshmi Puja',
    titleBengali: 'কোজাগরী লক্ষ্মীপূজা — ধনধান্য ও সৌভাগ্য আরাধনা',
    titleEnglish: 'Kojagori Lakshmi Puja (Purnima Worship)',
    // Date: Sun 25 Oct. Drik Panchang Kolkata Kojagara Puja 25 Oct, Nishita
    // 10:56-11:46 PM, Purnima 25 Oct 11:55 AM - 26 Oct 09:41 AM (all match):
    // https://www.drikpanchang.com/festivals/kojagara/kojagara-puja-date-time.html?year=2026&geoname-id=1275004
    // No Belur Math / Beni Madhab Lakshmi Puja times found online.
    // UNVERIFIED: 18:00 is the app's countdown anchor.
    startsAt: DateTime(2026, 10, 25, 18, 0),
    tithiName: 'Ashwin Shukla Purnima (Kojagari Purnima)',
    tithiTimings:
        'Purnima begins: 25 Oct 11:55 AM | Purnima ends: 26 Oct 09:41 AM',
    auspiciousMoments:
        'Nishitha Kaal Lakshmi Aradhana: 10:56 PM - 11:46 PM | Purnima Nishitha Puja & Alpana decoration: Nishitha window | Evening Pradosh Puja: 06:30 PM - 09:00 PM',
    ritualSignificance:
        'Observed on the full moon night following Durga Puja. Bengali courtyards and thresholds are hand-painted with intricate white rice-paste Alpana patterns depicting the sacred footsteps of Goddess Lakshmi entering the household. Families stay awake ("Ko Jago" - who is awake?) awaiting the blessing of prosperity.',
    attireAndBhog:
        'Traditional Bengali attire. Naru (coconut and sesame jaggery balls), Moa, Khichuri Bhog, Labra, and Shinni.',
    crowdForecast:
        'Warm household celebration; gentle para pandal gatherings without traffic jams.',
    crowdLevel: 0.20,
    bestVisitingHours: [
      '05:00 PM - 09:00 PM: Visiting neighborhood pandals and friends\' homes for Lakshmi Puja Bhog',
    ],
    recommendedPandalIds: [
      'khelat_ghosh',
      'hathkhola_dutta',
      'sovabazar_beniatola',
    ],
    aiProTips: [
      'Try authentic homemade Narkel Naru and Tiler Naru gifted on this auspicious harvest night.',
      'Admire the delicate hand-painted rice-flour Alpana footstep designs outside Bengali doorways.',
    ],
  ),
];

PujaDayTithi getPujaDayById(String id) {
  return kDurgaPujaCalendar2026.firstWhere(
    (day) => day.id == id,
    orElse: () => kDurgaPujaCalendar2026[0],
  );
}

int getDaysUntilDurgaPuja2026(DateTime now) {
  // Target: Maha Shashthi, from the same field as its displayed date.
  final sasthi = getPujaDayById('shashthi').targetDate;
  final diff = sasthi.difference(now).inDays;
  return diff > 0 ? diff : 0;
}

class PujaMilestoneEpoch {
  final String id;
  final String name;
  final DateTime targetDateTime;

  const PujaMilestoneEpoch({
    required this.id,
    required this.name,
    required this.targetDateTime,
  });
}

/// Sandhi Puja start (Belur Math / Vishuddha Siddhanta), Monday 19 Oct 2026:
/// https://media.belurmath.org/sri-sri-durga-puja-2026-programme-details-25017/
/// Drik Panchang Kolkata gives 10:27-11:15 AM (one minute earlier):
/// https://www.drikpanchang.com/navratri/shardiya-navratri-sandhipuja.html?year=2026&geoname-id=1275004
/// FLAGGED: the header countdown always uses the Belur Math time; Beni Madhab
/// Sandhi Puja is 07:26-08:14 AM on the same day.
final DateTime kSandhiPuja2026Start = DateTime(2026, 10, 19, 10, 28);

const Map<String, String> _kMilestoneNames = {
  'mahalaya': 'Mahalaya (Devi Invocation)',
  'panchami': 'Maha Panchami (Inaugurations)',
  'shashthi': 'Maha Shashthi (Bodhon)',
  'saptami': 'Maha Saptami (Nabapatrika)',
  'ashtami': 'Maha Ashtami (Pushpanjali)',
  'nabami': 'Maha Nabami (Maha Homa)',
  'dashami': 'Vijaya Dashami (Visarjan)',
  'lakshmi_puja': 'Kojagari Lakshmi Puja',
};

/// Header-ticker milestones. Every day's target is read from
/// [kDurgaPujaCalendar2026] (its [PujaDayTithi.startsAt]); Sandhi Puja is
/// inserted after Ashtami. Sorted by time.
final List<PujaMilestoneEpoch> kPuja2026Milestones = [
  for (final day in kDurgaPujaCalendar2026) ...[
    PujaMilestoneEpoch(
      id: day.id,
      name: _kMilestoneNames[day.id] ?? day.dayName,
      targetDateTime: day.targetDateTime,
    ),
    if (day.id == 'ashtami')
      PujaMilestoneEpoch(
        id: 'sandhi_puja',
        name: 'Auspicious Sandhi Puja',
        targetDateTime: kSandhiPuja2026Start,
      ),
  ],
]..sort((a, b) => a.targetDateTime.compareTo(b.targetDateTime));

PujaMilestoneEpoch getNextActiveMilestone(DateTime now) {
  for (final m in kPuja2026Milestones) {
    if (m.targetDateTime.isAfter(now)) {
      return m;
    }
  }
  return kPuja2026Milestones.last;
}

PujaMilestoneEpoch getMilestoneForDayId(String dayId) {
  return kPuja2026Milestones.firstWhere(
    (m) => m.id == dayId,
    orElse: () => getNextActiveMilestone(DateTime.now()),
  );
}
