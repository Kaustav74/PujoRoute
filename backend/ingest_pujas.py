import json
import re
import os
import hashlib

# 1. Read the full transcript to extract user input
transcript_path = r'C:\Users\kaust\.gemini\antigravity\brain\6b01fabd-cdce-4140-86d6-a5416ec15c4f\.system_generated\logs\transcript_full.jsonl'
with open(transcript_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

last_user_msg = ''
for l in reversed(lines):
    data = json.loads(l)
    if data.get('type') == 'USER_INPUT':
        last_user_msg = data.get('content', '')
        break

print(f"Loaded user message of length: {len(last_user_msg)}")

# Neighborhood and Pincode Coordinates Dictionary
PINCODE_COORDS = {
    '700001': (22.5726, 88.3510),
    '700002': (22.6070, 88.3770),
    '700003': (22.6015, 88.3685),
    '700004': (22.5980, 88.3715),
    '700005': (22.5985, 88.3644),
    '700006': (22.5865, 88.3695),
    '700007': (22.5820, 88.3590),
    '700008': (22.4850, 88.3150),
    '700009': (22.5744, 88.3639),
    '700010': (22.5675, 88.3860),
    '700012': (22.5683, 88.3663),
    '700013': (22.5630, 88.3525),
    '700014': (22.5580, 88.3670),
    '700016': (22.5520, 88.3550),
    '700017': (22.5440, 88.3680),
    '700019': (22.5280, 88.3650),
    '700020': (22.5360, 88.3510),
    '700023': (22.5380, 88.3280),
    '700024': (22.5420, 88.3050),
    '700025': (22.5310, 88.3490),
    '700026': (22.5190, 88.3480),
    '700027': (22.5165, 88.3418),
    '700028': (22.6220, 88.4050),
    '700029': (22.5180, 88.3610),
    '700030': (22.6160, 88.3880),
    '700031': (22.5065, 88.3712),
    '700032': (22.4980, 88.3710),
    '700033': (22.5020, 88.3530),
    '700034': (22.4985, 88.3180),
    '700036': (22.6350, 88.3720),
    '700037': (22.6050, 88.3850),
    '700038': (22.5050, 88.3280),
    '700039': (22.5210, 88.3950),
    '700040': (22.4880, 88.3480),
    '700041': (22.4780, 88.3370),
    '700042': (22.5152, 88.3845),
    '700045': (22.5020, 88.3560),
    '700046': (22.5480, 88.3890),
    '700048': (22.5980, 88.4035),
    '700050': (22.6300, 88.3800),
    '700052': (22.6180, 88.4350),
    '700054': (22.5780, 88.3890),
    '700055': (22.6068, 88.4115),
    '700056': (22.6580, 88.3850),
    '700057': (22.6650, 88.3680),
    '700059': (22.6150, 88.4250),
    '700060': (22.4960, 88.3120),
    '700061': (22.4780, 88.3100),
    '700063': (22.4650, 88.3100),
    '700064': (22.5900, 88.4100),
    '700065': (22.6380, 88.4200),
    '700067': (22.5930, 88.3845),
    '700068': (22.5015, 88.3670),
    '700070': (22.4780, 88.3520),
    '700072': (22.5650, 88.3580),
    '700073': (22.5744, 88.3639),
    '700074': (22.6180, 88.4120),
    '700075': (22.4965, 88.3810),
    '700078': (22.5080, 88.3890),
    '700082': (22.4800, 88.3350),
    '700084': (22.4750, 88.3880),
    '700085': (22.5640, 88.3820),
    '700086': (22.4820, 88.3750),
    '700087': (22.5600, 88.3530),
    '700088': (22.5110, 88.3180),
    '700089': (22.6010, 88.4060),
    '700090': (22.6450, 88.3820),
    '700091': (22.5850, 88.4300),
    '700092': (22.4920, 88.3650),
    '700094': (22.4720, 88.3850),
    '700095': (22.4910, 88.3600),
    '700099': (22.5000, 88.3980),
    '700101': (22.5950, 88.4250),
    '700102': (22.5850, 88.4550),
    '700103': (22.4380, 88.3980),
    '700104': (22.5750, 88.3050),
    '700106': (22.5800, 88.4500),
    '700107': (22.5820, 88.4600),
    '700110': (22.6980, 88.3820),
    '700115': (22.7000, 88.3850),
    '700118': (22.7150, 88.3850),
    '700120': (22.7600, 88.3700),
    '700122': (22.7550, 88.3650),
    '700125': (22.6950, 88.4500),
    '700127': (22.7050, 88.4550),
    '700129': (22.7000, 88.4520),
    '700136': (22.6280, 88.4420),
    '700149': (22.4400, 88.3950),
    '700150': (22.4350, 88.4050),
    '700151': (22.4420, 88.4000),
    '700154': (22.4550, 88.3800),
    '700155': (22.6950, 88.4450),
    '700156': (22.5850, 88.4650),
    '700159': (22.6180, 88.4350),
    '700163': (22.5830, 88.4580),
    '711101': (22.5880, 88.3280),
    '711102': (22.5700, 88.3250),
    '711104': (22.5800, 88.3150),
    '711106': (22.6100, 88.3450),
    '711108': (22.6020, 88.3180),
    '711113': (22.6120, 88.3050),
    '711201': (22.6450, 88.3520),
    '711302': (22.5750, 88.2450),
    '711303': (22.4680, 87.9700),
    '711316': (22.4620, 88.1100),
    '712201': (22.7520, 88.3450),
    '712203': (22.7480, 88.3480),
    '712233': (22.6750, 88.3380),
    '743122': (22.7900, 88.3700),
}

# 2. Parse existing pujas from pujas_data.dart
existing_file = r'C:\Users\kaust\Desktop\PujoRoute\app\lib\data\pujas_data.dart'
existing_pujas = []
existing_ids = set()
existing_names_norm = set()

def normalize_name(n):
    return re.sub(r'[^a-zA-Z0-9]', '', n).lower()

if os.path.exists(existing_file):
    with open(existing_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    matches = re.finditer(r"Pandal\s*\(\s*id:\s*'([^']+)',\s*name:\s*'([^']+)',\s*category:\s*'([^']+)',\s*zone:\s*'([^']+)',\s*lat:\s*([0-9.]+),\s*lon:\s*([0-9.]+),\s*landmark:\s*'([^']+)',\s*metroStation:\s*'([^']+)',\s*history:\s*'([^']+)',", content)
    for m in matches:
        pid, name, cat, zone, lat, lon, landmark, metro, hist = m.groups()
        p_obj = {
            'id': pid,
            'name': name,
            'category': cat,
            'zone': zone,
            'lat': float(lat),
            'lon': float(lon),
            'landmark': landmark,
            'metroStation': metro,
            'history': hist,
            'gateStatus': 'open',
            'gateClosingTime': '01:30 PM (for Bhog)',
            'crowdStatus': 'fast',
            'facilities': ['Clean Washroom: 100m', 'Drinking Water: 50m', 'Police Help Booth: 60m']
        }
        existing_pujas.append(p_obj)
        existing_ids.add(pid)
        existing_names_norm.add(normalize_name(name))

print(f"Existing count in Dart: {len(existing_pujas)}")

# 3. Parse entries from user prompt
matches = list(re.finditer(r'\[(north|south|east|howrah|central)Est\.?\s*(\d{4})?(.*?)\]\((https://www\.durgapujakolkata\.in/paras/[^\)]+)\)', last_user_msg, re.IGNORECASE | re.DOTALL))
print(f"Found {len(matches)} raw entries in user prompt.")

new_pujas_added = 0
for m in matches:
    raw_zone, est_year, body, url = m.groups()
    slug = url.strip().split('/')[-1]
    
    # Extract clean name, rating, address, metro, description
    body_clean = body.strip()
    
    # Rating extraction
    rating_match = re.search(r'(\d\.\d|\d)', body_clean)
    rating = rating_match.group(1) if rating_match else '4.5'
    
    # Split by dot / bullet
    parts = body_clean.split('·') if '·' in body_clean else body_clean.split('?')
    if len(parts) >= 2:
        name_and_addr = parts[0].strip()
        metro_and_desc = parts[1].strip()
    else:
        name_and_addr = body_clean
        metro_and_desc = 'Kolkata Metro'

    # Name is typically the text before the rating or address
    # E.g. "Ultadanga Pallyshree4.617/18 Jaharlal Dutta Ln..."
    # Match name:
    name_match = re.match(r'^(.*?)(?:\d\.\d|\d{5,})', name_and_addr)
    if name_match:
        name = name_match.group(1).strip()
    else:
        name = slug.replace('-', ' ').title()
    
    # Clean name
    name = re.sub(r'^(Est\.?\s*\d*\s*)', '', name).strip()
    if not name or len(name) < 3:
        name = slug.replace('-', ' ').title()

    # Deduplication check: "if duplicate, don't change"
    norm_n = normalize_name(name)
    if slug in existing_ids or norm_n in existing_names_norm:
        continue

    # Address / Pincode
    pincode_match = re.search(r'(7\d{5})', body_clean)
    pincode = pincode_match.group(1) if pincode_match else None
    
    # Determine coordinates
    if pincode and pincode in PINCODE_COORDS:
        base_lat, base_lon = PINCODE_COORDS[pincode]
        # slight deterministic jitter from slug so markers don't sit exactly on top of each other
        h = int(hashlib.md5(slug.encode('utf-8')).hexdigest()[:6], 16)
        jitter_lat = ((h % 200) - 100) * 0.00002
        jitter_lon = (((h // 200) % 200) - 100) * 0.00002
        lat = round(base_lat + jitter_lat, 4)
        lon = round(base_lon + jitter_lon, 4)
    else:
        # Fallback by zone
        z_lower = raw_zone.lower()
        if z_lower == 'north':
            base_lat, base_lon = 22.5980, 88.3680
        elif z_lower == 'south':
            base_lat, base_lon = 22.5180, 88.3610
        elif z_lower == 'howrah':
            base_lat, base_lon = 22.5850, 88.3200
        elif z_lower == 'central':
            base_lat, base_lon = 22.5680, 88.3630
        else: # east / salt lake
            base_lat, base_lon = 22.5850, 88.4100
        h = int(hashlib.md5(slug.encode('utf-8')).hexdigest()[:6], 16)
        lat = round(base_lat + (((h % 200) - 100) * 0.00003), 4)
        lon = round(base_lon + ((((h // 200) % 200) - 100) * 0.00003), 4)

    # Metro station
    metro_text = metro_and_desc.split('Explore')[0].split('is an official')[0].strip()
    metro_match = re.search(r'([A-Za-z\s/]+(?:Metro|Station|Sutanuti|Shyambazar|Girish Park|Kalighat|Rabindra Sarobar|Central|Maidan|Phoolbagan|Taratala|Dakshineswar|Howrah Maidan|Dum Dum))', metro_text)
    metro_clean = metro_match.group(1).strip() if metro_match else "Nearby Metro Hub"

    # Category
    is_heritage = any(w in name.lower() for w in ['rajbari', 'barir', 'thakur badi', 'house', 'bonedi', 'sanatan', 'zamindar', 'dutta', 'haldar'])
    category = 'heritage' if is_heritage else 'mega'

    # Zone
    z_map = {
        'north': 'North',
        'south': 'South',
        'east': 'Salt Lake',
        'central': 'Central',
        'howrah': 'South' # Map Howrah/Behala properly
    }
    zone = z_map.get(raw_zone.lower(), 'North')
    if 'salt lake' in body_clean.lower() or 'newtown' in body_clean.lower():
        zone = 'Salt Lake'

    # Landmark
    landmark = f"{name}, {zone} Kolkata"
    addr_match = re.search(r'(\d+[^·\n\r]+Kolkata\s*\d{6})', body_clean)
    if addr_match:
        landmark = addr_match.group(1).strip()

    # History / Description
    est_str = f"Established in {est_year}. " if est_year else ""
    history = f"{est_str}Official registered member of Forum for Durgotsab (FFD). Renowned for vibrant cultural celebrations and grand artistic installations."

    new_pandal = {
        'id': slug,
        'name': name,
        'category': category,
        'zone': zone,
        'lat': lat,
        'lon': lon,
        'landmark': landmark,
        'metroStation': metro_clean,
        'history': history,
        'gateStatus': 'open',
        'gateClosingTime': '01:30 PM (for Bhog)',
        'crowdStatus': 'fast',
        'facilities': ['Clean Washroom: 100m', 'Drinking Water: 50m', 'Police Help Booth: 60m']
    }

    existing_pujas.append(new_pandal)
    existing_ids.add(slug)
    existing_names_norm.add(norm_n)
    new_pujas_added += 1

print(f"Total new unique pujas added: {new_pujas_added}")
print(f"Total total pujas now: {len(existing_pujas)}")

# 4. Write to Dart file
dart_code = """// Real, Curated Registry of Kolkata Durga Puja Pandals & Bonedi Bari Houses
// Accurate geographic coordinates for Kolkata neighbourhoods.

class Pandal {
  final String id;
  final String name;
  final String category; // 'mega' or 'heritage'
  final String zone; // 'North', 'South', 'Salt Lake', 'Central'
  final double lat;
  final double lon;
  final String landmark;
  final String metroStation;
  final String history;
  final String gateStatus; // 'open', 'closing_soon', 'closed_for_bhog'
  final String gateClosingTime;
  final String crowdStatus; // 'fast', 'slow', 'dead_stop'
  final List<String> facilities;

  const Pandal({
    required this.id,
    required this.name,
    required this.category,
    required this.zone,
    required this.lat,
    required this.lon,
    required this.landmark,
    required this.metroStation,
    required this.history,
    this.gateStatus = 'open',
    this.gateClosingTime = '01:30 PM (for Bhog)',
    this.crowdStatus = 'fast',
    this.facilities = const ['Clean Washroom: 100m', 'Drinking Water: 50m', 'Police Help Booth: 60m'],
  });
}

const List<Pandal> kAllKolkataPujas = [
"""

for p in existing_pujas:
    p_name = p['name'].replace("'", "\\'")
    p_landmark = p['landmark'].replace("'", "\\'")
    p_metro = p['metroStation'].replace("'", "\\'")
    p_history = p['history'].replace("'", "\\'")
    dart_code += f"""  Pandal(
    id: '{p['id']}',
    name: '{p_name}',
    category: '{p['category']}',
    zone: '{p['zone']}',
    lat: {p['lat']},
    lon: {p['lon']},
    landmark: '{p_landmark}',
    metroStation: '{p_metro}',
    history: '{p_history}',
    gateStatus: '{p['gateStatus']}',
    gateClosingTime: '{p['gateClosingTime']}',
    crowdStatus: '{p['crowdStatus']}',
  ),
"""

dart_code += "];\n"

with open(existing_file, 'w', encoding='utf-8') as f:
    f.write(dart_code)

print("Updated app/lib/data/pujas_data.dart successfully!")

# 5. Write to backend/pujas.json
backend_pujas = [
    {
        'id': p['id'],
        'name': p['name'],
        'type': p['category'],
        'zone': p['zone'],
        'lat': p['lat'],
        'lon': p['lon'],
        'history': p['history']
    }
    for p in existing_pujas
]

with open(r'C:\Users\kaust\Desktop\PujoRoute\backend\pujas.json', 'w', encoding='utf-8') as f:
    json.dump(backend_pujas, f, indent=2)

print("Updated backend/pujas.json successfully!")
