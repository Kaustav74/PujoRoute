/// Local Offline Quick Reply Response Store for AI Sathi (Durga Puja 2026).
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
          '🚆 **Kolkata Metro Puja Schedule 2026**:\n'
          '• **Blue Line (Dakshineswar – Kavi Subhash)**: Night-long service running continuously till 4:00 AM from Saptami to Navami.\n'
          '• **Green Line (Sealdah – Howrah Maidan & Sector V)**: Trains run till 12:00 AM Midnight.\n'
          '• **Interchange**: Esplanade Station serves as the single cross-platform interchange.',
    ),
    QuickReplyItem(
      id: 'rashbehari_traffic',
      label: '🚨 Traffic & Barricades',
      query: 'What is the traffic situation at Rashbehari Crossing?',
      response:
          '🚨 **Rashbehari & Gariahat Police Advisory**:\n'
          '• **One-Way Pedestrian Flow**: Entry strictly via Monoharpukur Rd to Tridhara, exit towards Rashbehari connector.\n'
          '• **Ekdalia Corridor**: Entry via Gariahat crossing barricade, exit onto Cornfield Road.\n'
          '• **Vehicular Restrictions**: No private cars permitted on Rashbehari Avenue between 4:00 PM and 4:00 AM.',
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
