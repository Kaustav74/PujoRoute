import 'dart:math';
import '../data/pujas_data.dart';

class SpatialFacility {
  final String name;
  final String category; // 'washroom', 'water', 'police'
  final double lat;
  final double lon;
  final String detail;

  const SpatialFacility({
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    this.detail = '',
  });
}

class FacilityProximityResult {
  final String washroomInfo;
  final String waterInfo;
  final String policeInfo;
  final List<String> chips;

  const FacilityProximityResult({
    required this.washroomInfo,
    required this.waterInfo,
    required this.policeInfo,
    required this.chips,
  });
}

class SpatialFacilityService {
  SpatialFacilityService._();
  static final SpatialFacilityService instance = SpatialFacilityService._();

  /// Verified coordinates for KMC Public Washrooms, Safe Drinking Water, & Police Booths
  static const List<SpatialFacility> verifiedFacilities = [
    // ----------------- SOUTH KOLKATA -----------------
    // Washrooms
    SpatialFacility(name: 'KMC Pay & Use Bio-Toilet', category: 'washroom', lat: 22.5182, lon: 88.3654, detail: 'Gariahat Crossing'),
    SpatialFacility(name: 'KMC Deluxe Restroom', category: 'washroom', lat: 22.5175, lon: 88.3472, detail: 'Kalighat Metro Gate 3'),
    SpatialFacility(name: 'Southern Avenue Public Washroom', category: 'washroom', lat: 22.5124, lon: 88.3510, detail: 'Near Mudiali Club'),
    SpatialFacility(name: 'Deshapriya Park Public Facilities', category: 'washroom', lat: 22.5208, lon: 88.3565, detail: 'Park North-West Gate'),
    SpatialFacility(name: 'Hazra Park KMC Washroom', category: 'washroom', lat: 22.5228, lon: 88.3478, detail: 'Jatin Das Park Gate 2'),
    SpatialFacility(name: 'Maddox Square Restroom Block', category: 'washroom', lat: 22.5338, lon: 88.3568, detail: 'Pritam Store lane'),
    SpatialFacility(name: 'Chetla Central Park Bio-Toilet', category: 'washroom', lat: 22.5158, lon: 88.3375, detail: 'Near Agrani Entry'),
    SpatialFacility(name: 'New Alipore Block G Washroom', category: 'washroom', lat: 22.5048, lon: 88.3294, detail: 'Near Suruchi Sangha ground'),
    SpatialFacility(name: 'Tollygunge Tram Depot Restroom', category: 'washroom', lat: 22.4978, lon: 88.3452, detail: 'Mahanayak Uttam Kumar'),
    SpatialFacility(name: 'Kasba New Market Bio-Toilet', category: 'washroom', lat: 22.5152, lon: 88.3854, detail: 'Bosepukur Connector'),
    SpatialFacility(name: 'Jadavpur 8B Bus Stand Washroom', category: 'washroom', lat: 22.4958, lon: 88.3714, detail: 'Near Sukanta Setu'),
    SpatialFacility(name: 'Behala Chowrasta Municipal Washroom', category: 'washroom', lat: 22.4862, lon: 88.3184, detail: 'Diamond Harbour Rd'),

    // Drinking Water
    SpatialFacility(name: 'KMC Filtered Water ATM', category: 'water', lat: 22.5185, lon: 88.3648, detail: 'Gate 2 Gariahat'),
    SpatialFacility(name: 'KMC Chilled Water Point', category: 'water', lat: 22.5172, lon: 88.3465, detail: 'Rashbehari Crossing'),
    SpatialFacility(name: 'Southern Avenue Drinking Kiosk', category: 'water', lat: 22.5129, lon: 88.3504, detail: 'Lakeside walk'),
    SpatialFacility(name: 'Deshapriya Park RO Water Station', category: 'water', lat: 22.5202, lon: 88.3562, detail: 'Main Pavillion Gate'),
    SpatialFacility(name: 'Hazra Crossing Water Station', category: 'water', lat: 22.5222, lon: 88.3480, detail: 'Near Hazra Pharmacy'),
    SpatialFacility(name: 'Maddox Square Safe Water Booth', category: 'water', lat: 22.5342, lon: 88.3572, detail: 'East Wing Lawn'),
    SpatialFacility(name: 'Chetla Road KMC Water Post', category: 'water', lat: 22.5162, lon: 88.3371, detail: 'Near Chetla Bridge'),
    SpatialFacility(name: 'New Alipore Petrol Pump Water Kiosk', category: 'water', lat: 22.5052, lon: 88.3298, detail: 'HP Petrol Pump'),
    SpatialFacility(name: 'Kavi Subhash Metro Water ATM', category: 'water', lat: 22.4638, lon: 88.3989, detail: 'Concourse Area'),

    // Police & Medical Help Booths
    SpatialFacility(name: 'Kolkata Police Help Booth #14', category: 'police', lat: 22.5180, lon: 88.3652, detail: 'Gariahat Flyover Junction'),
    SpatialFacility(name: 'Kolkata Police Assistance Booth #9', category: 'police', lat: 22.5176, lon: 88.3470, detail: 'Kalighat Temple Crossing'),
    SpatialFacility(name: 'KP Rapid Action Booth #22', category: 'police', lat: 22.5127, lon: 88.3502, detail: 'Southern Avenue Roundabout'),
    SpatialFacility(name: 'KP Traffic Control & Medical Aid Post', category: 'police', lat: 22.5206, lon: 88.3561, detail: 'Deshapriya Crossing'),
    SpatialFacility(name: 'Hazra Police Division Camp', category: 'police', lat: 22.5226, lon: 88.3476, detail: 'Ashutosh College Gate'),
    SpatialFacility(name: 'Ballygunge Police Assistance Post', category: 'police', lat: 22.5341, lon: 88.3569, detail: 'Maddox Square East'),
    SpatialFacility(name: 'Chetla Police Station Outpost', category: 'police', lat: 22.5161, lon: 88.3373, detail: 'Agrani Pedestrian Cordon'),
    SpatialFacility(name: 'New Alipore Police Help Desk', category: 'police', lat: 22.5051, lon: 88.3292, detail: 'Suruchi Sangha Corridor'),

    // ----------------- NORTH KOLKATA -----------------
    // Washrooms
    SpatialFacility(name: 'KMC Public Restroom Complex', category: 'washroom', lat: 22.6035, lon: 88.3722, detail: 'Shyambazar 5-Point'),
    SpatialFacility(name: 'Sovabazar Sutanuti KMC Toilet', category: 'washroom', lat: 22.5978, lon: 88.3692, detail: 'Sovabazar Metro Gate 2'),
    SpatialFacility(name: 'Bagbazar Ghat Pay & Use Toilet', category: 'washroom', lat: 22.6042, lon: 88.3654, detail: 'Near Bagbazar Pandal'),
    SpatialFacility(name: 'Kumartuli Artisan Lane Bio-Toilet', category: 'washroom', lat: 22.5992, lon: 88.3624, detail: 'Banamali Sarkar St'),
    SpatialFacility(name: 'Hatibagan Market Public Restroom', category: 'washroom', lat: 22.5982, lon: 88.3734, detail: 'Bidhan Sarani'),
    SpatialFacility(name: 'College Square KMC Toilet Complex', category: 'washroom', lat: 22.5742, lon: 88.3628, detail: 'University Lake Gate'),
    SpatialFacility(name: 'Girish Park Metro Concourse Washroom', category: 'washroom', lat: 22.5858, lon: 88.3604, detail: 'CR Avenue Gate 2'),
    SpatialFacility(name: 'Mohammad Ali Park Municipal Toilet', category: 'washroom', lat: 22.5698, lon: 88.3590, detail: 'Central Metro Gate 4'),
    SpatialFacility(name: 'Belgachia Milk Colony Restroom', category: 'washroom', lat: 22.6076, lon: 88.3845, detail: 'Belgachia Bridge'),
    SpatialFacility(name: 'Dum Dum Station Municipal Restroom', category: 'washroom', lat: 22.6221, lon: 88.3938, detail: 'Jessore Rd Gate'),

    // Drinking Water
    SpatialFacility(name: 'Shyambazar KMC Water Kiosk', category: 'water', lat: 22.6031, lon: 88.3716, detail: 'Netaji Statue side'),
    SpatialFacility(name: 'Sovabazar Sutanuti Water Point', category: 'water', lat: 22.5972, lon: 88.3685, detail: 'Metro Entry walkway'),
    SpatialFacility(name: 'Bagbazar Riverfront Water Kiosk', category: 'water', lat: 22.6045, lon: 88.3648, detail: 'Near Circular Rly'),
    SpatialFacility(name: 'Kumartuli Ghat Fresh Water Point', category: 'water', lat: 22.5988, lon: 88.3618, detail: 'Ghat approach lane'),
    SpatialFacility(name: 'College Square Pure Water Station', category: 'water', lat: 22.5746, lon: 88.3622, detail: 'College St Baptist Gate'),
    SpatialFacility(name: 'Girish Park Drinking Water Post', category: 'water', lat: 22.5852, lon: 88.3598, detail: 'Girish Mancha'),
    SpatialFacility(name: 'Central Metro Water ATM', category: 'water', lat: 22.5692, lon: 88.3582, detail: 'BB Ganguly St corner'),
    SpatialFacility(name: 'Dum Dum Metro Filtered Water', category: 'water', lat: 22.6217, lon: 88.3931, detail: 'Station Concourse'),

    // Police & Medical Help Booths
    SpatialFacility(name: 'Kolkata Police Help Booth #3', category: 'police', lat: 22.6036, lon: 88.3718, detail: 'Shyambazar 5-Point Crossing'),
    SpatialFacility(name: 'Shovabazar Police Assistance Booth #5', category: 'police', lat: 22.5976, lon: 88.3689, detail: 'Sovabazar Metro Gate 1'),
    SpatialFacility(name: 'Bagbazar Police Security Post', category: 'police', lat: 22.6039, lon: 88.3652, detail: 'Bagbazar Sarbojanin barricade'),
    SpatialFacility(name: 'Kumartuli Artisan Police Outpost', category: 'police', lat: 22.5991, lon: 88.3622, detail: 'Kumartuli Park Gate'),
    SpatialFacility(name: 'College Square Police Control Room', category: 'police', lat: 22.5741, lon: 88.3625, detail: 'Medical Drop-in Center'),
    SpatialFacility(name: 'Central Division Police Assistance', category: 'police', lat: 22.5695, lon: 88.3587, detail: 'Mohammad Ali Park Entry'),

    // ----------------- CENTRAL KOLKATA -----------------
    // Washrooms
    SpatialFacility(name: 'Esplanade Metro Subway Toilet', category: 'washroom', lat: 22.5649, lon: 88.3526, detail: 'Gate 5 Curzon Park'),
    SpatialFacility(name: 'Sealdah Railway & Metro Restroom', category: 'washroom', lat: 22.5672, lon: 88.3715, detail: 'Kole Market Entrance'),
    SpatialFacility(name: 'Park Street Metro Public Facility', category: 'washroom', lat: 22.5534, lon: 88.3515, detail: 'Park Street Corridor'),
    SpatialFacility(name: 'Rabindra Sadan SSKM Restroom', category: 'washroom', lat: 22.5400, lon: 88.3492, detail: 'Exide Crossing'),
    SpatialFacility(name: 'Chandni Chowk Municipal Washroom', category: 'washroom', lat: 22.5660, lon: 88.3564, detail: 'Ganesh Chandra Ave'),

    // Drinking Water
    SpatialFacility(name: 'Esplanade Tram Depot Water ATM', category: 'water', lat: 22.5645, lon: 88.3521, detail: 'Near SN Banerjee Rd'),
    SpatialFacility(name: 'Sealdah Green Line Water Station', category: 'water', lat: 22.5668, lon: 88.3710, detail: 'Concourse Level'),
    SpatialFacility(name: 'Park Street Water Kiosk', category: 'water', lat: 22.5530, lon: 88.3509, detail: 'Asiatic Society Corner'),
    SpatialFacility(name: 'Rabindra Sadan Fresh Water Post', category: 'water', lat: 22.5396, lon: 88.3488, detail: 'Academy of Fine Arts'),

    // Police & Medical
    SpatialFacility(name: 'Kolkata Police Traffic HQ Camp', category: 'police', lat: 22.5648, lon: 88.3525, detail: 'Esplanade Curzon Lawn'),
    SpatialFacility(name: 'Sealdah Police Division Booth', category: 'police', lat: 22.5671, lon: 88.3713, detail: 'Flyover approach'),
    SpatialFacility(name: 'Park Street Police Assistance Camp', category: 'police', lat: 22.5533, lon: 88.3513, detail: 'Chowringhee Junction'),

    // ----------------- SALT LAKE & EAST KOLKATA -----------------
    // Washrooms
    SpatialFacility(name: 'Lake Town Clock Tower Washroom', category: 'washroom', lat: 22.6052, lon: 88.4063, detail: 'VIP Road Connector / Sreebhumi'),
    SpatialFacility(name: 'Karunamoyee Bus Terminus Toilet', category: 'washroom', lat: 22.5857, lon: 88.4165, detail: 'Central Park Gate 1'),
    SpatialFacility(name: 'Salt Lake City Centre Washrooms', category: 'washroom', lat: 22.5901, lon: 88.4090, detail: 'FD Block walkway'),
    SpatialFacility(name: 'Sector V Ring Road Bio-Toilet', category: 'washroom', lat: 22.5806, lon: 88.4360, detail: 'Wipro Crossing Gate 3'),
    SpatialFacility(name: 'Ultadanga Telengabagan Washroom', category: 'washroom', lat: 22.5932, lon: 88.3884, detail: 'Near Hudco Bridge'),
    SpatialFacility(name: 'Dum Dum Park Public Facility', category: 'washroom', lat: 22.6105, lon: 88.4082, detail: 'Tarun Sangha Ground'),

    // Drinking Water
    SpatialFacility(name: 'Sreebhumi VIP Road Water ATM', category: 'water', lat: 22.6048, lon: 88.4058, detail: 'Footover Bridge side'),
    SpatialFacility(name: 'Karunamoyee Green Line Water Kiosk', category: 'water', lat: 22.5853, lon: 88.4159, detail: 'Station exit'),
    SpatialFacility(name: 'FD Block Community Water Point', category: 'water', lat: 22.5895, lon: 88.4084, detail: 'Park Pavilion Gate'),
    SpatialFacility(name: 'Sector V Metro Fresh Water ATM', category: 'water', lat: 22.5801, lon: 88.4354, detail: 'College More Junction'),
    SpatialFacility(name: 'Ultadanga Station Drinking Post', category: 'water', lat: 22.5928, lon: 88.3879, detail: 'Near Auto Stand'),

    // Police & Medical
    SpatialFacility(name: 'Bidhannagar Police Assistance Post', category: 'police', lat: 22.6051, lon: 88.4061, detail: 'Sreebhumi Main Pandal Entry'),
    SpatialFacility(name: 'Karunamoyee Police Assistance Desk', category: 'police', lat: 22.5856, lon: 88.4163, detail: 'Central Park Fairground'),
    SpatialFacility(name: 'Salt Lake City Centre Police Booth', category: 'police', lat: 22.5899, lon: 88.4088, detail: 'Block DC Roundabout'),
    SpatialFacility(name: 'Ultadanga Police Assistance Booth', category: 'police', lat: 22.5931, lon: 88.3882, detail: 'VIP Road Entry Point'),
  ];

  /// Geodesic Haversine Distance in meters
  /// d = 2R * asin(sqrt(sin^2(dPhi/2) + cos(phi1)*cos(phi2)*sin^2(dLambda/2)))
  static double calculateHaversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // Earth radius in meters
    final double phi1 = lat1 * pi / 180.0;
    final double phi2 = lat2 * pi / 180.0;
    final double deltaPhi = (lat2 - lat1) * pi / 180.0;
    final double deltaLambda = (lon2 - lon1) * pi / 180.0;

    final double sinDeltaPhi = sin(deltaPhi / 2.0);
    final double sinDeltaLambda = sin(deltaLambda / 2.0);

    final double a = sinDeltaPhi * sinDeltaPhi +
        cos(phi1) * cos(phi2) * sinDeltaLambda * sinDeltaLambda;

    final double c = 2.0 * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)));
    return r * c;
  }

  /// Calculates the nearest facilities for a given coordinate (lat, lon)
  FacilityProximityResult getNearestFacilitiesForCoords(double lat, double lon) {
    SpatialFacility? closestWashroom;
    double minWashroomDist = double.infinity;

    SpatialFacility? closestWater;
    double minWaterDist = double.infinity;

    SpatialFacility? closestPolice;
    double minPoliceDist = double.infinity;

    for (final f in verifiedFacilities) {
      final dist = calculateHaversineMeters(lat, lon, f.lat, f.lon);
      if (f.category == 'washroom' && dist < minWashroomDist) {
        minWashroomDist = dist;
        closestWashroom = f;
      } else if (f.category == 'water' && dist < minWaterDist) {
        minWaterDist = dist;
        closestWater = f;
      } else if (f.category == 'police' && dist < minPoliceDist) {
        minPoliceDist = dist;
        closestPolice = f;
      }
    }

    const double kMaxDistanceThreshold = 800.0; // 800 meters

    String washroomText;
    if (closestWashroom != null && minWashroomDist <= kMaxDistanceThreshold) {
      final roundDist = minWashroomDist.round();
      final walkMins = max(1, (roundDist / 65).round());
      washroomText = '🚻 ${closestWashroom.name} • ${roundDist}m away (~$walkMins min walk)';
    } else {
      washroomText = '🚻 Designated volunteer assistance desk inside pandal grounds';
    }

    String waterText;
    if (closestWater != null && minWaterDist <= kMaxDistanceThreshold) {
      final roundDist = minWaterDist.round();
      final detail = closestWater.detail.isNotEmpty ? ' (${closestWater.detail})' : '';
      waterText = '💧 ${closestWater.name} • ${roundDist}m away$detail';
    } else {
      waterText = '💧 Designated volunteer assistance desk inside pandal grounds';
    }

    String policeText;
    if (closestPolice != null && minPoliceDist <= kMaxDistanceThreshold) {
      final roundDist = minPoliceDist.round();
      final detail = closestPolice.detail.isNotEmpty ? ' (${closestPolice.detail})' : '';
      policeText = '👮 ${closestPolice.name} • ${roundDist}m away$detail';
    } else {
      policeText = '👮 Designated volunteer assistance desk inside pandal grounds';
    }

    return FacilityProximityResult(
      washroomInfo: washroomText,
      waterInfo: waterText,
      policeInfo: policeText,
      chips: [washroomText, waterText, policeText],
    );
  }

  /// Calculates the nearest facilities for a given Pandal
  FacilityProximityResult getNearestFacilities(Pandal pandal) {
    return getNearestFacilitiesForCoords(pandal.lat, pandal.lon);
  }
}
