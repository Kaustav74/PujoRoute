// Curated, bundled festival advisories (fully offline; no network fetches).

class LivePandalAlert {
  final String pandalName;
  final String crowdStatus; // 'smooth', 'moderate', 'heavy'
  final int waitMinutes;
  final String advisory;

  const LivePandalAlert({
    required this.pandalName,
    required this.crowdStatus,
    required this.waitMinutes,
    required this.advisory,
  });
}

class RoadRestriction {
  final String road;
  final String status;
  final String detourAdvice;

  const RoadRestriction({
    required this.road,
    required this.status,
    required this.detourAdvice,
  });
}

class LiveFeedService {
  static final LiveFeedService _instance = LiveFeedService._internal();
  factory LiveFeedService() => _instance;
  static LiveFeedService get instance => _instance;

  LiveFeedService._internal();

  // Curated live Kolkata Police and festival transit advisories
  static const List<RoadRestriction> kActiveRoadRestrictions = [
    RoadRestriction(
      road: 'Rashbehari Avenue',
      status: 'No vehicular entry towards Chetla / Kalighat',
      detourAdvice: 'Take Blue Line Metro to Kalighat Station (Gate 1)',
    ),
    RoadRestriction(
      road: 'VIP Road (Lake Town)',
      status: 'Service lane converted into Sreebhumi pedestrian walkway',
      detourAdvice: 'Airport-bound vehicles use main flyover express lanes',
    ),
    RoadRestriction(
      road: 'Central Avenue (MG Road Crossing)',
      status: 'Pedestrian priority around College Square & Mohammad Ali Park',
      detourAdvice: 'Board Green Line Metro at Sealdah or Blue Line at Central',
    ),
    RoadRestriction(
      road: 'Southern Avenue & Lake Area',
      status: 'One-way entry from Menoka Cinema towards Mudiali',
      detourAdvice: 'Use Rabindra Sarobar Metro station for pedestrian access',
    ),
  ];

  static const List<LivePandalAlert> kPandalAlerts = [
    LivePandalAlert(
      pandalName: 'Sreebhumi Sporting Club',
      crowdStatus: 'heavy',
      waitMinutes: 75,
      advisory: 'Severe crowd pressure on VIP road pedestrian bridge.',
    ),
    LivePandalAlert(
      pandalName: 'Suruchi Sangha',
      crowdStatus: 'heavy',
      waitMinutes: 60,
      advisory: 'New Alipore approach barricaded for vehicle diversion.',
    ),
    LivePandalAlert(
      pandalName: 'Chetla Agrani Club',
      crowdStatus: 'moderate',
      waitMinutes: 35,
      advisory: 'Queue moving smoothly through Hazra Bridge corridor.',
    ),
    LivePandalAlert(
      pandalName: 'Ekdalia Evergreen Club',
      crowdStatus: 'smooth',
      waitMinutes: 15,
      advisory: 'Gariahat main road wide queue flow active.',
    ),
    LivePandalAlert(
      pandalName: 'Sovabazar Rajbari',
      crowdStatus: 'smooth',
      waitMinutes: 10,
      advisory: 'Thakur Dalan open courtyard entry operating normally.',
    ),
  ];

  /// Evaluates whether a pandal should be omitted when "Reroute around heavy traffic" is enabled
  bool shouldRerouteAround(String pandalName) {
    final pLower = pandalName.trim().toLowerCase();
    // Guard: an empty/very short name used to match every alert via contains().
    if (pLower.length < 4) return false;
    for (final alert in kPandalAlerts) {
      if (pLower.contains(alert.pandalName.toLowerCase()) || alert.pandalName.toLowerCase().contains(pLower)) {
        return alert.crowdStatus == 'heavy';
      }
    }
    for (final res in kActiveRoadRestrictions) {
      if (pLower.contains(res.road.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Gets the verified status indicator and advisory for a pandal
  Map<String, dynamic> getPandalLiveStatus(String pandalName) {
    final pLower = pandalName.trim().toLowerCase();
    for (final alert in kPandalAlerts) {
      if (pLower.length >= 4 && (pLower.contains(alert.pandalName.toLowerCase()) || alert.pandalName.toLowerCase().contains(pLower))) {
        return {
          'status': alert.crowdStatus,
          'wait': alert.waitMinutes,
          'advisory': alert.advisory,
        };
      }
    }
    return {
      'status': 'smooth',
      'wait': 15,
      'advisory': 'Standard pedestrian entry flow active.',
    };
  }
}

