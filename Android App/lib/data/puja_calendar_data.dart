// Official Durga Puja 2026 Panjika, Tithi Schedule & AI Festival Calendar
// Based on authentic Kolkata Panjika (Vishuddha Siddhanta / Belur Math tradition).

class PujaDayTithi {
  final String id;
  final String dayName;
  final String titleBengali;
  final String titleEnglish;
  final String dateFormatted;
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

  const PujaDayTithi({
    required this.id,
    required this.dayName,
    required this.titleBengali,
    required this.titleEnglish,
    required this.dateFormatted,
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

  DateTime get targetDate {
    switch (id) {
      case 'mahalaya':
        return DateTime(2026, 10, 10);
      case 'panchami':
        return DateTime(2026, 10, 16);
      case 'shashthi':
        return DateTime(2026, 10, 17);
      case 'saptami':
        return DateTime(2026, 10, 18);
      case 'ashtami':
        return DateTime(2026, 10, 19);
      case 'nabami':
        return DateTime(2026, 10, 20);
      case 'dashami':
        return DateTime(2026, 10, 21);
      case 'lakshmi_puja':
        return DateTime(2026, 10, 25);
      default:
        return DateTime(2026, 10, 17);
    }
  }

  /// Exact Target Epoch for Durga Puja 2026 (IST)
  DateTime get targetDateTime {
    switch (id) {
      case 'mahalaya':
        return DateTime(2026, 10, 10, 6, 0, 0);
      case 'panchami':
        return DateTime(2026, 10, 16, 16, 0, 0);
      case 'shashthi':
        return DateTime(2026, 10, 16, 9, 0, 0);
      case 'saptami':
        return DateTime(2026, 10, 18, 6, 0, 0);
      case 'ashtami':
        return DateTime(2026, 10, 19, 6, 30, 0);
      case 'sandhi_puja':
        return DateTime(2026, 10, 19, 10, 28, 0);
      case 'nabami':
        return DateTime(2026, 10, 20, 11, 30, 0);
      case 'dashami':
        return DateTime(2026, 10, 21, 10, 0, 0);
      case 'lakshmi_puja':
        return DateTime(2026, 10, 25, 18, 0, 0);
      default:
        return DateTime(2026, 10, 16, 9, 0, 0);
    }
  }

  // Harmonized remaining-days calculation matching the header ticker
  int get daysRemaining {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inDays >= 0 ? difference.inDays : 0;
  }

  int getDaysRemaining([DateTime? now]) {
    final current = now ?? DateTime.now();
    final todayMidnight = DateTime(current.year, current.month, current.day);
    final targetMidnight =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
    return targetMidnight.difference(todayMidnight).inDays;
  }
}

class PujaTithiDay {
  final String id;
  final String titleEn;
  final String titleBn;
  final String subTitle;
  final DateTime targetDate;
  final DateTime tithiStart;
  final DateTime tithiEnd;
  final String muhuratTitle;
  final String muhuratWindow;

  PujaTithiDay({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.subTitle,
    required this.targetDate,
    required this.tithiStart,
    required this.tithiEnd,
    required this.muhuratTitle,
    required this.muhuratWindow,
  });

  // Harmonized remaining-days calculation matching the header ticker
  int get daysRemaining {
    final now = DateTime.now();
    final difference = targetDate.difference(now);
    return difference.inDays >= 0 ? difference.inDays : 0;
  }
}

final List<PujaTithiDay> pujaCalendar2026 = [
  PujaTithiDay(
    id: 'mahalaya',
    titleEn: 'Mahalaya',
    titleBn: 'মহালয়া — আগমনী ও চণ্ডীপাঠ',
    subTitle: 'Mahalaya (Devi Paksha Invocation)',
    targetDate: DateTime(2026, 10, 10),
    tithiStart: DateTime(2026, 10, 9, 23, 42),
    tithiEnd: DateTime(2026, 10, 10, 21, 18),
    muhuratTitle: 'Dawn Tarpan at Ganga Ghats',
    muhuratWindow: '04:30 AM - 08:30 AM',
  ),
  PujaTithiDay(
    id: 'panchami',
    titleEn: 'Maha Panchami',
    titleBn: 'মহা পঞ্চমী — আনন্দময়ী আগমনী',
    subTitle: 'Maha Panchami (Grand Inaugurations)',
    targetDate: DateTime(2026, 10, 16),
    tithiStart: DateTime(2026, 10, 15, 4, 15),
    tithiEnd: DateTime(2026, 10, 16, 5, 15),
    muhuratTitle: 'VIP & Public Inaugurations',
    muhuratWindow: '04:00 PM onwards',
  ),
  PujaTithiDay(
    id: 'shashthi',
    titleEn: 'Maha Shashthi',
    titleBn: 'মহা ষষ্ঠী — বোধন, আমন্ত্রণ ও অধিবাস',
    subTitle: 'Maha Shashthi (Devi Bodhon & Awakening)',
    targetDate: DateTime(2026, 10, 17),
    tithiStart: DateTime(2026, 10, 16, 5, 15),
    tithiEnd: DateTime(2026, 10, 17, 6, 45),
    muhuratTitle: 'Prabhat Kalparambha',
    muhuratWindow: '06:45 AM - 08:30 AM',
  ),
  PujaTithiDay(
    id: 'saptami',
    titleEn: 'Maha Saptami',
    titleBn: 'মহা সপ্তমী — নবপত্রিকা স্নান ও প্রাণ প্রতিষ্ঠা',
    subTitle: 'Maha Saptami (Nabapatrika / Kola Bou Snan)',
    targetDate: DateTime(2026, 10, 18),
    tithiStart: DateTime(2026, 10, 17, 6, 45),
    tithiEnd: DateTime(2026, 10, 18, 8, 30),
    muhuratTitle: 'Nabapatrika Pravesh & Snan (Kola Bou river bath)',
    muhuratWindow: '05:45 AM - 07:15 AM',
  ),
  PujaTithiDay(
    id: 'ashtami',
    titleEn: 'Maha Ashtami',
    titleBn: 'মহা অষ্টমী — কুমারী পূজা ও সন্ধিপূজা',
    subTitle: 'Maha Ashtami (Kumari Puja & Sandhi Puja)',
    targetDate: DateTime(2026, 10, 19),
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
    targetDate: DateTime(2026, 10, 20),
    tithiStart: DateTime(2026, 10, 19, 10, 52),
    tithiEnd: DateTime(2026, 10, 20, 12, 45),
    muhuratTitle: 'Nabami Vihita Puja & Homa',
    muhuratWindow: '09:00 AM - 11:30 AM',
  ),
  PujaTithiDay(
    id: 'dashami',
    titleEn: 'Bijoya Dashami',
    titleBn: 'বিজয়া দশমী — সিঁদুর খেলা ও বিসর্জন',
    subTitle: 'Bijoya Dashami (Sindoor Khela & Immersion)',
    targetDate: DateTime(2026, 10, 21),
    tithiStart: DateTime(2026, 10, 20, 12, 45),
    tithiEnd: DateTime(2026, 10, 21, 14, 30),
    muhuratTitle: 'Dashami Vihita Puja & Darpan Bisarjan',
    muhuratWindow: '08:30 AM - 10:30 AM',
  ),
  PujaTithiDay(
    id: 'lakshmi_puja',
    titleEn: 'Kojagori Lakshmi Puja',
    titleBn: 'কোজাগরী লক্ষ্মীপূজা — ধনধান্য ও সৌভাগ্য আরাধনা',
    subTitle: 'Kojagori Lakshmi Puja (Purnima Worship)',
    targetDate: DateTime(2026, 10, 25),
    tithiStart: DateTime(2026, 10, 24, 18, 30),
    tithiEnd: DateTime(2026, 10, 25, 17, 45),
    muhuratTitle: 'Nishitha Kaal Lakshmi Aradhana',
    muhuratWindow: '11:15 PM - 12:05 AM',
  ),
];

const List<PujaDayTithi> kDurgaPujaCalendar2026 = [
  PujaDayTithi(
    id: 'mahalaya',
    dayName: 'Mahalaya',
    titleBengali: 'মহালয়া — আগমনী ও চণ্ডীপাঠ',
    titleEnglish: 'Mahalaya (Devi Paksha Invocation)',
    dateFormatted: 'Saturday, 10 October 2026',
    tithiName: 'Ashwin Krishna Amavasya ( পিতৃপক্ষ অবসান ও দেবীপক্ষ সূচনা )',
    tithiTimings:
        'Amavasya begins: 09 Oct 11:42 PM | Amavasya ends: 10 Oct 09:18 PM',
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
    dateFormatted: 'Friday, 16 October 2026',
    tithiName: 'Shukla Panchami',
    tithiTimings:
        'Panchami begins: 15 Oct 04:15 AM | Panchami ends: 16 Oct 05:15 AM',
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
    dateFormatted: 'Saturday, 17 October 2026',
    tithiName: 'Shukla Shashthi',
    tithiTimings:
        'Shashthi begins: 16 Oct 05:15 AM | Shashthi ends: 17 Oct 06:45 AM',
    tithiTimingsTraditional:
        'Shashthi begins: 16 Oct 06:40 PM | Shashthi ends: 17 Oct 05:45 PM',
    auspiciousMoments:
        'Bodhon, Amantran & Adhibas (Fri evening): Friday evening | Prabhat Kalparambha: 06:45 AM - 08:30 AM | Shashthi Vihita Puja: 09:00 AM - 11:30 AM',
    auspiciousMomentsTraditional:
        'Para Kalparambha: 06:15 AM - 08:00 AM | Shashthi Vihita Puja: 08:30 AM - 11:00 AM | Bodhon & Adhibas: 05:45 PM - 07:15 PM',
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
    dateFormatted: 'Sunday, 18 October 2026',
    tithiName: 'Shukla Saptami',
    tithiTimings:
        'Saptami begins: 17 Oct 06:45 AM | Saptami ends: 18 Oct 08:30 AM',
    tithiTimingsTraditional:
        'Saptami begins: 17 Oct 05:45 PM | Saptami ends: 18 Oct 04:48 PM',
    auspiciousMoments:
        'Nabapatrika Snan (Kola Bou river bath) at dawn: 05:45 AM - 07:15 AM | Belur Math Puja begins: 5:30 AM | Saptami Vihita Puja: 08:30 AM - 11:00 AM | Maha Arati: 07:00 PM',
    auspiciousMomentsTraditional:
        'Kola Bou Snan at Ghat: 05:15 AM - 06:15 AM | Saptami Vihita Puja: 08:00 AM - 10:30 AM | Sandhya Arati: 06:30 PM',
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
    dateFormatted: 'Monday, 19 October 2026',
    tithiName: 'Shukla Ashtami',
    tithiTimings:
        'Ashtami begins: 18 Oct 08:30 AM | Ashtami ends: 19 Oct 10:52 AM',
    tithiTimingsTraditional:
        'Ashtami begins: 18 Oct 04:48 PM | Ashtami ends: 19 Oct 04:32 PM',
    auspiciousMoments:
        'Kumari Puja at Belur Math: 09:00 AM | Belur Math Sandhi Puja Muhurta: 10:28 AM – 11:16 AM (Balidan: 10:52 AM) | Maha Ashtami Pushpanjali: 09:30 AM - 10:25 AM',
    auspiciousMomentsTraditional:
        'Traditional Para Pushpanjali: 06:30 AM - 07:15 AM | Traditional Para Sandhi Puja (Beni Madhab): 07:26 AM – 08:14 AM (Balidan: 07:50 AM) | Para Community Bhog: 12:30 PM - 02:00 PM',
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
    dateFormatted: 'Tuesday, 20 October 2026',
    tithiName: 'Shukla Nabami',
    tithiTimings:
        'Nabami begins: 19 Oct 10:52 AM | Nabami ends: 20 Oct 12:45 PM',
    tithiTimingsTraditional:
        'Nabami begins: 19 Oct 04:32 PM | Nabami ends: 20 Oct 04:50 PM',
    auspiciousMoments:
        'Nabami Vihita Puja & Homa: 09:00 AM - 11:30 AM | Nabami Homa & Yajna following morning Bhog: Following morning Bhog | Evening Dhunuchi Naach: 08:00 PM - 01:00 AM',
    auspiciousMomentsTraditional:
        'Para Nabami Vihita Puja: 08:30 AM - 10:30 AM | Para Maha Homa: 11:00 AM - 12:30 PM | Dhunuchi Dance Competitions: 07:30 PM - Midnight',
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
    dateFormatted: 'Wednesday, 21 October 2026',
    tithiName: 'Shukla Dashami',
    tithiTimings:
        'Dashami begins: 20 Oct 12:45 PM | Dashami ends: 21 Oct 02:30 PM',
    tithiTimingsTraditional:
        'Dashami begins: 20 Oct 04:50 PM | Dashami ends: 21 Oct 05:30 PM',
    auspiciousMoments:
        'Dashami Vihita Puja & Darpan Bisarjan: 08:30 AM - 10:30 AM | Darpan Visarjan: 10:45 AM | Sindoor Khela: 11:30 AM - 03:30 PM | Ganga Ghat Bisarjan: 04:30 PM - Midnight',
    auspiciousMomentsTraditional:
        'Para Aparajita Puja: 08:00 AM - 10:00 AM | Darpan Visarjan: 10:15 AM | Sindoor Khela: 11:00 AM - 03:00 PM | Bisarjan Processions: 04:00 PM - 11:00 PM',
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
    dateFormatted: 'Sunday, 25 October 2026',
    tithiName: 'Ashwin Shukla Purnima (Kojagari Purnima)',
    tithiTimings:
        'Purnima begins: 24 Oct 06:30 PM | Purnima ends: 25 Oct 05:45 PM',
    auspiciousMoments:
        'Nishitha Kaal Lakshmi Aradhana: 11:15 PM - 12:05 AM | Purnima Nishitha Puja & Alpana decoration: Nishitha window | Evening Pradosh Puja: 06:30 PM - 09:00 PM',
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
  // Target: Maha Sasthi (17 Oct 2026)
  final sasthi = DateTime(2026, 10, 17);
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

final List<PujaMilestoneEpoch> kPuja2026Milestones = [
  PujaMilestoneEpoch(
    id: 'mahalaya',
    name: 'Mahalaya (Devi Invocation)',
    targetDateTime: DateTime(2026, 10, 10, 6, 0, 0),
  ),
  PujaMilestoneEpoch(
    id: 'panchami',
    name: 'Maha Panchami (Inaugurations)',
    targetDateTime: DateTime(2026, 10, 16, 16, 0, 0),
  ),
  PujaMilestoneEpoch(
    id: 'shashthi',
    name: 'Maha Shashthi (Bodhon)',
    targetDateTime: DateTime(2026, 10, 16, 9, 0, 0),
  ),
  PujaMilestoneEpoch(
    id: 'saptami',
    name: 'Maha Saptami (Nabapatrika)',
    targetDateTime: DateTime(2026, 10, 18, 6, 0, 0),
  ),
  PujaMilestoneEpoch(
    id: 'ashtami',
    name: 'Maha Ashtami (Pushpanjali)',
    targetDateTime: DateTime(2026, 10, 19, 6, 30, 0),
  ),
  PujaMilestoneEpoch(
    id: 'sandhi_puja',
    name: 'Auspicious Sandhi Puja',
    targetDateTime: DateTime(2026, 10, 19, 10, 28, 0),
  ),
  PujaMilestoneEpoch(
    id: 'nabami',
    name: 'Maha Nabami (Maha Homa)',
    targetDateTime: DateTime(2026, 10, 20, 11, 30, 0),
  ),
  PujaMilestoneEpoch(
    id: 'dashami',
    name: 'Vijaya Dashami (Visarjan)',
    targetDateTime: DateTime(2026, 10, 21, 10, 0, 0),
  ),
  PujaMilestoneEpoch(
    id: 'lakshmi_puja',
    name: 'Kojagari Lakshmi Puja',
    targetDateTime: DateTime(2026, 10, 25, 18, 0, 0),
  ),
];

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
