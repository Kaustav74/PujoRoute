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
    this.notes = '24x7 Emergency & Trauma Care Active',
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
      name: 'SSKM Hospital (IPGMER) - Main Trauma Care',
      zone: 'South / Central',
      phone: '033-2223-1589',
      lat: 22.5385,
      lon: 88.3444,
      address: '244 AJC Bose Road, Bhowanipore, Kolkata',
      notes: 'Premier 24x7 Level-1 Government Trauma Care Centre',
    ),
    HospitalCasualty(
      name: 'Calcutta Medical College & Hospital',
      zone: 'Central',
      phone: '033-2255-1621',
      lat: 22.5739,
      lon: 88.3619,
      address: '88 College Street, Bowbazar, Kolkata',
      notes: 'Central Kolkata Emergency Casualty & ICU',
    ),
    HospitalCasualty(
      name: 'R.G. Kar Medical College & Hospital',
      zone: 'North',
      phone: '033-2555-7656',
      lat: 22.6041,
      lon: 88.3752,
      address: '1 Khudiram Bose Sarani, Belgachia / Shyambazar, Kolkata',
      notes: 'North Kolkata Primary 24x7 Emergency Casualty Ward',
    ),
    HospitalCasualty(
      name: 'Calcutta National Medical College (CNMC)',
      zone: 'South-East',
      phone: '033-2284-4834',
      lat: 22.5401,
      lon: 88.3718,
      address: '32 Gorachand Road, Beniapukur, Kolkata',
      notes: 'South-East Corridor 24x7 Emergency & Trauma',
    ),
    HospitalCasualty(
      name: 'N.R.S. Medical College & Hospital',
      zone: 'Central / Sealdah',
      phone: '033-2286-0033',
      lat: 22.5645,
      lon: 88.3698,
      address: '138 AJC Bose Road, Sealdah, Kolkata',
      notes: 'Sealdah Railway Hub 24x7 Emergency Casualty',
    ),
    HospitalCasualty(
      name: 'AMRI Hospital Dhakuria (24x7 Emergency)',
      zone: 'South',
      phone: '033-6680-0000',
      lat: 22.5117,
      lon: 88.3639,
      address: 'Block A, Scheme LII, Gariahat / Dhakuria, Kolkata',
      notes: 'South Kolkata Advanced Cardiac & Emergency Care',
    ),
    HospitalCasualty(
      name: 'Ruby General Hospital (24x7 Trauma)',
      zone: 'EM Bypass / South-East',
      phone: '033-3987-1800',
      lat: 22.5135,
      lon: 88.4025,
      address: 'Kasba Golpark, EM Bypass, Kolkata',
      notes: 'EM Bypass 24x7 Emergency & Critical Care',
    ),
    HospitalCasualty(
      name: 'Apollo Multispeciality Hospitals',
      zone: 'Salt Lake / EM Bypass',
      phone: '033-2320-3040',
      lat: 22.5699,
      lon: 88.4042,
      address: '58 Canal Circular Road, Kadapara, Kolkata',
      notes: 'Salt Lake & EM Bypass North 24x7 Emergency Care',
    ),
  ];

  static const List<PoliceAssistanceBooth> kPoliceBooths = [
    PoliceAssistanceBooth(
      division: 'Lalbazar Central Control Room',
      landmark: 'Lalbazar Headquarters, Central Kolkata',
      contact: '100 / 033-2214-3230',
      lat: 22.5714,
      lon: 88.3533,
    ),
    PoliceAssistanceBooth(
      division: 'South Division Police Help Booth',
      landmark: 'Gariahat Crossing & Kalighat Temple Gate',
      contact: '033-2475-1212',
      lat: 22.5190,
      lon: 88.3650,
    ),
    PoliceAssistanceBooth(
      division: 'North Division Police Help Booth',
      landmark: 'Shyambazar Five-Point & Hatibagan',
      contact: '033-2555-5555',
      lat: 22.6000,
      lon: 88.3700,
    ),
    PoliceAssistanceBooth(
      division: 'Bidhannagar Police Commissionerate',
      landmark: 'Salt Lake Karunamoyee & Central Park',
      contact: '033-2335-8788',
      lat: 22.5867,
      lon: 88.4178,
    ),
    PoliceAssistanceBooth(
      division: 'South Suburban / Jadavpur Booth',
      landmark: 'Jadavpur 8B Bus Stand / Tollygunge',
      contact: '033-2414-2222',
      lat: 22.4989,
      lon: 88.3712,
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
      'lost my friend',
      'lost friend',
      'lost family',
      'lost child',
      'lost my brother',
      'missing',
      'medical emergency',
      'first aid',
      'ambulance',
      'casualty',
      'hospital near me',
      'accident',
      'police help',
      'police booth',
      'chest pain',
      'fainted',
      'stampede',
      'help me emergency',
      'danger',
      'bipod',
      'bachan',
      'churi',
      'pocketmaar',
      'doctor',
    ];
    return triggers.any((t) => q.contains(t));
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
      return "🚨 **EMERGENCY: LOST PERSON / FAMILY SEPARATION ALERT**\n\n"
          "Stay calm. Kolkata Police has active Lost & Found Enclosures at all major puja precincts.\n\n"
          "**Immediate Steps:**\n"
          "1. Report immediately to the nearest **Kolkata Police Help Booth**:\n"
          "   • **${police.division}** (~${distPolice > 1000 ? (distPolice / 1000).toStringAsFixed(1) : distPolice}${distPolice > 1000 ? 'km' : 'm'} away at ${police.landmark})\n"
          "   • **Direct Helpline:** `${police.contact}`\n"
          "2. Request the volunteer desk to make an immediate PA announcement with description and last known landmark.\n"
          "3. Dial **Lalbazar Central Control:** `100` or **Women & Child Helpline:** `1090` / `1091`.\n"
          "4. Instruct separated members to head to the nearest Metro Station concourse or police kiosk.";
    }

    return "🚨 **IMMEDIATE EMERGENCY ASSISTANCE & FIRST AID**\n\n"
        "**Nearest 24x7 Hospital Casualty Ward:**\n"
        "🏥 **${hospital.name}**\n"
        "• **Distance:** ~${distHosp > 1000 ? (distHosp / 1000).toStringAsFixed(1) : distHosp}${distHosp > 1000 ? 'km' : 'm'} from your current location\n"
        "• **Address:** ${hospital.address}\n"
        "• **Emergency Hotline:** `${hospital.phone}`\n"
        "• **Facility Status:** ${hospital.notes}\n\n"
        "**Closest Kolkata Police Booth:**\n"
        "👮 **${police.division}**\n"
        "• **Landmark:** ${police.landmark} (~${distPolice > 1000 ? (distPolice / 1000).toStringAsFixed(1) : distPolice}${distPolice > 1000 ? 'km' : 'm'})\n"
        "• **Phone:** `${police.contact}`\n\n"
        "**Official Kolkata Emergency Helplines:**\n"
        "• 🚑 **Ambulance / Medical:** `102` / `108`\n"
        "• 👮 **Police Control Room:** `100` / `112`\n"
        "• 🛡️ **Women Helpline:** `1090` / `1091`\n"
        "• 🚇 **Kolkata Metro Helpline:** `139`";
  }
}
