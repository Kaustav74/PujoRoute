/// Local Offline Quick Reply Response Store (Durga Puja 2026).
/// Operates 100% offline with 0 network calls and consumes 0 AI surge tokens.
class QuickReplyItem {
  final String id;
  final String label;
  final String query;
  final String response;
  final String? actionTag;

  const QuickReplyItem({
    required this.id,
    required this.label,
    required this.query,
    required this.response,
    this.actionTag,
  });
}

class QuickReplyService {
  /// Singleton instance
  static final QuickReplyService _instance = QuickReplyService._internal();
  factory QuickReplyService() => _instance;
  QuickReplyService._internal();

  /// Canonical quick reply chips displayed in UI
  static const List<QuickReplyItem> defaultChips = [
    QuickReplyItem(
      id: 'sandhi_puja',
      label: '🪔 Sandhi Puja 2026',
      query: 'When is Sandhi Puja 2026?',
      response:
          '🪔 **Sandhi Puja 2026 Timing** (Vishuddha Siddhanta Panjika):\n'
          '• **Date**: Monday, 19 October 2026 (Maha Ashtami / Navami Sandhi)\n'
          '• **Exact Muhurta**: 10:28 AM – 11:16 AM\n'
          '• **Balidan / Sacrifice Time**: 10:52 AM\n'
          '• **Benchmark**: Belur Math & Kalighat Temple rituals.',
      actionTag: '[ACTION:OPEN_TITHI]',
    ),
    QuickReplyItem(
      id: 'metro_hours',
      label: '🚆 Metro Hours',
      query: 'What are the Metro running hours during Durga Puja 2026?',
      response:
          '🚆 **Kolkata Metro during Durga Puja 2026**:\n'
          '• Metro Railway Kolkata announces special Puja timings each year; this offline app does not have the 2026 timetable. Check mtp.indianrailways.gov.in or station notices before planning a late return.\n'
          '• **Interchanges**: Esplanade (Blue/Green), Noapara (Blue/Yellow). The Orange Line has no open interchange while the Blue Line platforms at Kavi Subhash are closed; Shahid Khudiram (Blue) is about 900 m away by road.',
    ),
    QuickReplyItem(
      id: 'rashbehari_traffic',
      label: '🚨 Traffic & Barricades',
      query: 'What is the traffic situation at Rashbehari Crossing?',
      response:
          '🚨 **Traffic & barricades**:\n'
          '• Kolkata Police publish Puja traffic arrangements each year; this offline app has no 2026 plan or live traffic data.\n'
          '• Follow police barricades and volunteers on site. Kolkata Police traffic helpline: 1073.\n'
          '• Around Rashbehari and Gariahat, the Metro (Kalighat, Rabindra Sarobar) is usually easier than a car.',
      actionTag: '[ACTION:OPEN_MAP]',
    ),
    QuickReplyItem(
      id: 'mahalaya_2026',
      label: '🌅 Mahalaya 2026',
      query: 'When is Mahalaya 2026?',
      response:
          '🌅 **Mahalaya 2026**:\n'
          '• **Date**: Saturday, 10 October 2026\n'
          '• **Tarpan**: Early morning Ganga ghat rituals start from 4:00 AM.\n'
          '• **Mahishasuramardini**: Akashvani AIR broadcast at 4:00 AM.',
    ),
    QuickReplyItem(
      id: 'emergency_sos',
      label: '🆘 Helpline / SOS',
      query: 'Emergency SOS Police Helpline',
      response:
          '🆘 **Emergency Helpline Kolkata Durga Puja 2026**:\n'
          '• **Kolkata Police Control Room**: 100 / 112\n'
          '• **Medical Emergency / Ambulance**: 102\n'
          '• **Women Helpline**: 1091\n'
          '• **Puja Control Room (Lalbazar)**: 033-2214-3024',
    ),
  ];

  /// Find matching offline answer for user input query if present.
  /// Supports English, Bengali, and Banglish keyword matching.
  QuickReplyItem? matchQuery(String query) {
    final lower = query.trim().toLowerCase();
    if (lower.isEmpty) return null;

    if (lower.contains('sandhi') ||
        lower.contains('সন্ধি') ||
        lower.contains('sandhi pujo') ||
        lower.contains('ashtami timing')) {
      return defaultChips[0];
    }

    if (lower.contains('metro') ||
        lower.contains('মেট্রো') ||
        lower.contains('train time') ||
        lower.contains('metro timing') ||
        lower.contains('metro hours')) {
      return defaultChips[1];
    }

    if (lower.contains('traffic') ||
        lower.contains('barricade') ||
        lower.contains('rashbehari') ||
        lower.contains('garahat') ||
        lower.contains('ট্রাফিক')) {
      return defaultChips[2];
    }

    if (lower.contains('mahalaya') ||
        lower.contains('মহালয়া') ||
        lower.contains('mohalaya') ||
        lower.contains('tarpan')) {
      return defaultChips[3];
    }

    if (lower.contains('sos') ||
        lower.contains('emergency') ||
        lower.contains('police') ||
        lower.contains('helpline') ||
        lower.contains('জরুরী')) {
      return defaultChips[4];
    }

    return null;
  }
}
