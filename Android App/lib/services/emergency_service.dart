import 'dart:math';

class HospitalCasualty {
  final String name;
  final String zone;
  final String phone;
  final double lat;
  final double lon;
  final String address;
  final String notes;

  const HospitalCasualty({
    required this.name,
    required this.zone,
    required this.phone,
    required this.lat,
    required this.lon,
    required this.address,
    this.notes = '',
  });
}

class PoliceAssistanceBooth {
  final String division;
  final String landmark;
  final String contact;
  final double lat;
  final double lon;

  const PoliceAssistanceBooth({
    required this.division,
    required this.landmark,
    required this.contact,
    required this.lat,
    required this.lon,
  });
}

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  static EmergencyService get instance => _instance;

  EmergencyService._internal();

  static const List<HospitalCasualty> kKolkataCasualtyHospitals = [
    HospitalCasualty(
      name: 'SSKM Hospital (IPGMER)',
      zone: 'South / Central',
      phone: '033-2204-1100',
      lat: 22.5385,
      lon: 88.3444,
      address: '244 AJC Bose Road, Bhowanipore, Kolkata',
      notes: 'Government hospital (IPGMER); emergency and trauma care',
    ),
    HospitalCasualty(
      name: 'Calcutta Medical College & Hospital',
      zone: 'Central',
      phone: '033-2255-1612',
      lat: 22.5739,
      lon: 88.3619,
      address: '88 College Street, Bowbazar, Kolkata',
      notes: 'Government medical college hospital; emergency department',
    ),
    HospitalCasualty(
      name: 'R.G. Kar Medical College & Hospital',
      zone: 'North',
      phone: '033-2555-7656',
      lat: 22.6041,
      lon: 88.3752,
      address: '1 Khudiram Bose Sarani, Belgachia / Shyambazar, Kolkata',
      notes: 'Government medical college hospital; emergency department',
    ),
    HospitalCasualty(
      name: 'Calcutta National Medical College (CNMC)',
      zone: 'South-East',
      phone: '033-2284-4834',
      lat: 22.5401,
      lon: 88.3718,
      address: '32 Gorachand Road, Beniapukur, Kolkata',
      notes: 'Government medical college hospital; emergency department',
    ),
    HospitalCasualty(
      name: 'N.R.S. Medical College & Hospital',
      zone: 'Central / Sealdah',
      phone: '033-2265-3215',
      lat: 22.5645,
      lon: 88.3698,
      address: '138 AJC Bose Road, Sealdah, Kolkata',
      notes: 'Government medical college hospital; emergency department',
    ),
    HospitalCasualty(
      name: 'AMRI Hospital Dhakuria',
      zone: 'South',
      phone: '033-6680-0000',
      lat: 22.5117,
      lon: 88.3639,
      address: 'Block A, Scheme LII, Gariahat / Dhakuria, Kolkata',
      notes: 'Private hospital; emergency department',
    ),
    HospitalCasualty(
      name: 'Ruby General Hospital',
      zone: 'EM Bypass / South-East',
      phone: '033-3987-1800',
      lat: 22.5135,
      lon: 88.4025,
      address: 'Kasba Golpark, EM Bypass, Kolkata',
      notes: 'Private hospital; emergency department',
    ),
    HospitalCasualty(
      name: 'Apollo Multispeciality Hospitals',
      zone: 'Salt Lake / EM Bypass',
      phone: '033-2320-3040',
      lat: 22.5699,
      lon: 88.4042,
      address: '58 Canal Circular Road, Kadapara, Kolkata',
      notes: 'Private hospital; emergency department',
    ),
  ];

  // Only the Lalbazar control room is listed: the earlier division booth
  // numbers (033-2475-1212, 033-2555-5555, 033-2335-8788, 033-2414-2222)
  // could not be matched to any official Kolkata Police directory.
  static const List<PoliceAssistanceBooth> kPoliceBooths = [
    PoliceAssistanceBooth(
      division: 'Lalbazar Central Control Room',
      landmark: 'Lalbazar Headquarters, Central Kolkata',
      contact: '100 / 033-2214-3230',
      lat: 22.5714,
      lon: 88.3533,
    ),
  ];

  static double getDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
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

  HospitalCasualty findNearestCasualtyHospital(double userLat, double userLon) {
    HospitalCasualty nearest = kKolkataCasualtyHospitals.first;
    double minDistance = double.infinity;

    for (final h in kKolkataCasualtyHospitals) {
      final d = getDistanceMeters(userLat, userLon, h.lat, h.lon);
      if (d < minDistance) {
        minDistance = d;
        nearest = h;
      }
    }
    return nearest;
  }

  PoliceAssistanceBooth findNearestPoliceBooth(double userLat, double userLon) {
    PoliceAssistanceBooth nearest = kPoliceBooths.first;
    double minDistance = double.infinity;

    for (final b in kPoliceBooths) {
      final d = getDistanceMeters(userLat, userLon, b.lat, b.lon);
      if (d < minDistance) {
        minDistance = d;
        nearest = b;
      }
    }
    return nearest;
  }

  HospitalCasualty findNearestHospital(double userLat, double userLon) => findNearestCasualtyHospital(userLat, userLon);

  bool isEmergencyQuery(String query) {
    final q = query.toLowerCase();
    final triggers = [
      'lost',
      'lost child',
      'lost my friend',
      'lost friend',
      'lost family',
      'lost my brother',
      'missing',
      'emergency',
      'police',
      'ambulance',
      'churi',
      'pocketmaar',
      'hospital',
      'stampede',
      'casualty',
      'first aid',
      'accident',
      'chest pain',
      'fainted',
      'danger',
      'bipod',
      'bachan',
      'doctor',
    ];
    return triggers.any((t) {
      if (t == 'lost' || t == 'police' || t == 'churi') {
        // match word boundary to avoid false positives
        return RegExp('\\b$t\\b').hasMatch(q);
      }
      return q.contains(t);
    });
  }

  bool isEmergencyIntent(String query) => isEmergencyQuery(query);

  String generateEmergencyGuidance(String query, double userLat, double userLon) {
    final hospital = findNearestCasualtyHospital(userLat, userLon);
    final police = findNearestPoliceBooth(userLat, userLon);
    final distHosp = getDistanceMeters(userLat, userLon, hospital.lat, hospital.lon).round();
    final distPolice = getDistanceMeters(userLat, userLon, police.lat, police.lon).round();

    final qLower = query.toLowerCase();
    final isLostCase = qLower.contains('lost') || qLower.contains('missing');

    if (isLostCase) {
      return "🚨 EMERGENCY: LOST PERSON / FAMILY SEPARATION ALERT\n\n"
          "Stay calm. Large pandals usually have a puja committee or Kolkata Police help desk.\n\n"
          "Immediate Steps:\n"
          "1. Tell the nearest police officer or help desk, or call Kolkata Police:\n"
          "   • ${police.division} (~${distPolice > 1000 ? (distPolice / 1000).toStringAsFixed(1) : distPolice}${distPolice > 1000 ? 'km' : 'm'} away at ${police.landmark})\n"
          "   • Direct Helpline: ${police.contact}\n"
          "2. Request the volunteer desk for an immediate PA system announcement.\n"
          "3. Instruct separated members to head to the nearest Metro Station concourse or police kiosk.\n\n"
          "Official Kolkata Emergency Numbers:\n"
          "• Kolkata Police Emergency: 112 / 100\n"
          "• Traffic Helpline: 1073\n"
          "• Women Helpline: 1091\n"
          "• Child Helpline: 1098\n"
          "• Ambulance: 102\n"
          "• Fire Brigade: 101";
    }

    return "🚨 IMMEDIATE EMERGENCY ASSISTANCE & FIRST AID\n\n"
        "Nearest listed hospital:\n"
        "🏥 ${hospital.name}\n"
        "• Distance: ~${distHosp > 1000 ? (distHosp / 1000).toStringAsFixed(1) : distHosp}${distHosp > 1000 ? 'km' : 'm'} from current location\n"
        "• Address: ${hospital.address}\n"
        "• Emergency Hotline: ${hospital.phone}\n"
        "• Call ahead to confirm emergency services are available.\n\n"
        "Kolkata Police control room:\n"
        "👮 ${police.division}\n"
        "• Landmark: ${police.landmark} (~${distPolice > 1000 ? (distPolice / 1000).toStringAsFixed(1) : distPolice}${distPolice > 1000 ? 'km' : 'm'})\n"
        "• Phone: ${police.contact}\n\n"
        "Official Kolkata Emergency Helplines:\n"
        "• Kolkata Police Emergency: 112 / 100\n"
        "• Traffic Helpline: 1073\n"
        "• Women Helpline: 1091\n"
        "• Ambulance: 102\n"
        "• Fire Brigade: 101\n"
        "• Rail / Metro Helpline (RailMadad): 139";
  }
}
