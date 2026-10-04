import re, math

NOISE = {'durga', 'puja', 'pujo', 'club', 'clubs', 'sangha', 'samity', 'samiti', 'association', 'sarbojanin', 'committee', 'youth', 'utsav', 'the', 'and', 'o', 'ground', 'grounds', 's'}

def extract_core_tokens(name):
    clean = re.sub(r'[^a-zA-Z0-9\s]', ' ', name.lower())
    tokens = {t for t in clean.split() if t and t not in NOISE}
    return tokens

def haversine(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))

pandals = []
with open('Android App/lib/data/pujas_data.dart', 'r', encoding='utf-8') as f:
    content = f.read()

matches = re.findall(rPandal\(\s*id:\s*'([^']+)',\s*name:\s*'([^']+)',.*?lat:\s*([0-9.]+),\s*lon:\s*([0-9.]+), content, re.DOTALL)
print(f'Total parsed pandals: {len(matches)}')

for p_id, name, lat, lon in matches:
    clean_name = name.replace(\', ')
    pandals.append({
        'id': p_id,
        'name': clean_name,
        'lat': float(lat),
        'lon': float(lon),
        'tokens': extract_core_tokens(clean_name)
    })

pairs = []
for i in range(len(pandals)):
    for j in range(i + 1, len(pandals)):
        p1, p2 = pandals[i], pandals[j]
        d = haversine(p1['lat'], p1['lon'], p2['lat'], p2['lon'])
        if d <= 300:
            t1, t2 = p1['tokens'], p2['tokens']
            is_subset = (bool(t1) and bool(t2)) and (t1.issubset(t2) or t2.issubset(t1))
            overlap = t1.intersection(t2)
            if is_subset or len(overlap) > 0 or d <= 70:
                pairs.append((d, p1['name'], p2['name'], t1, t2, is_subset, overlap))

pairs.sort(key=lambda x: x[0])
print(f'Interesting pairs within 300m: {len(pairs)}')
for d, n1, n2, t1, t2, is_sub, ov in pairs[:40]:
    print(f'{d:.1f}m: "{n1}" vs "{n2}" -> subset={is_sub}, overlap={ov}')
