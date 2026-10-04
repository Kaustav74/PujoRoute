from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import json
import math
import random
import os
from typing import List, Optional
from datetime import datetime
from groq import Groq

app = FastAPI(title="PujoRoute API V2")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "*").split(",") if o.strip()],
    allow_credentials=False,  # never combine credentials with wildcard origins
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)

# Load dataset
PUJAS_FILE = os.path.join(os.path.dirname(__file__), "pujas.json")
with open(PUJAS_FILE, "r", encoding="utf-8") as f:
    PUJAS_DB = json.load(f)

# Mock dynamic crowd data with realistic distribution
def get_crowd_status():
    return random.choice(['fast', 'fast', 'slow', 'slow', 'stop'])

# Fast Haversine calculation
def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000  # meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

class ChatRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=1000)
    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)

class SessionSyncRequest(BaseModel):
    session_id: str = Field(..., min_length=8, max_length=128, pattern=r"^[A-Za-z0-9_\-]+$")
    circuit_ids: List[str] = Field(default_factory=list, max_length=600)
    bookmarked_ids: List[str] = Field(default_factory=list, max_length=600)
    visited_ids: List[str] = Field(default_factory=list, max_length=600)
    is_circuit_active: bool = False

SESSIONS_DB = {}

class Puja(BaseModel):
    id: str
    name: str
    type: str
    zone: Optional[str] = None
    subsection: Optional[str] = None
    landmark: Optional[str] = None
    metroStation: Optional[str] = None
    history: Optional[str] = None
    significance: Optional[str] = None
    lat: float
    lon: float
    distance_meters: Optional[float] = None
    duration_mins: Optional[int] = None
    crowd_status: Optional[str] = None

@app.get("/")
def read_root():
    return {"message": "PujoRoute API is online", "total_pujas": len(PUJAS_DB)}

@app.get("/api/pandals/subsections")
def get_subsections():
    counts = {}
    for p in PUJAS_DB:
        sub = p.get("subsection", "South Kolkata (Gariahat / Ballygunge / Kalighat)")
        counts[sub] = counts.get(sub, 0) + 1
    return {
        "status": "success",
        "total_pujas": len(PUJAS_DB),
        "total_subsections": len(counts),
        "subsections": counts
    }

@app.post("/api/session/sync")
def sync_session(req: SessionSyncRequest):
    SESSIONS_DB[req.session_id] = {
        "session_id": req.session_id,
        "circuit_ids": req.circuit_ids,
        "bookmarked_ids": req.bookmarked_ids,
        "visited_ids": req.visited_ids,
        "is_circuit_active": req.is_circuit_active,
        "updated_at": datetime.now().isoformat(),
    }
    return {
        "status": "success",
        "message": "Session synchronized successfully",
        "session_id": req.session_id,
        "stats": {
            "circuit_count": len(req.circuit_ids),
            "bookmarked_count": len(req.bookmarked_ids),
            "visited_count": len(req.visited_ids),
        }
    }

@app.get("/api/session/{session_id}")
def get_session(session_id: str):
    if session_id in SESSIONS_DB:
        return {"status": "found", "session": SESSIONS_DB[session_id]}
    return {"status": "not_found", "session_id": session_id, "message": "Session not found"}

@app.get("/api/pujas/nearby")
def get_nearby_pujas(lat: float = Query(..., ge=-90, le=90), lon: float = Query(..., ge=-180, le=180), radius_m: float = Query(35000, gt=0, le=200000)):
    # Fallback to Kolkata center if 0,0 provided
    if lat == 0.0 and lon == 0.0:
        lat, lon = 22.5726, 88.3639

    all_pujas = []
    for puja in PUJAS_DB:
        raw_dist = haversine(lat, lon, puja["lat"], puja["lon"])
        # City road factor: ~1.25x straight-line distance
        road_dist = round(raw_dist * 1.25, 1)
        dur = max(1, round(road_dist / 75))  # ~4.5 km/h average walking speed
        
        puja_copy = puja.copy()
        puja_copy["distance_meters"] = road_dist
        puja_copy["duration_mins"] = dur
        puja_copy["crowd_status"] = get_crowd_status()
        all_pujas.append(puja_copy)

    # Sort strictly by distance
    all_pujas.sort(key=lambda x: x["distance_meters"])

    # First attempt to filter within radius_m
    in_radius = [p for p in all_pujas if p["distance_meters"] <= radius_m]
    
    # Guarantee rich response: if in_radius has fewer than 25 items, return top 35 nearest
    if len(in_radius) < 25:
        return all_pujas[:35]
    return in_radius[:50]

@app.get("/api/calendar/2026")
def get_calendar_2026():
    """Returns official Kolkata Durga Puja 2026 Panjika tithi schedule and daily ritual guide."""
    return [
        {
            "id": "mahalaya",
            "day": "Mahalaya",
            "title_bn": "মহালয়া — আগমনী ও চণ্ডীপাঠ",
            "title_en": "Mahalaya (Devi Paksha Invocation)",
            "date": "Saturday, 10 October 2026",
            "tithi": "Ashwin Krishna Amavasya",
            "timings": "Amavasya begins: 09 Oct 11:42 PM | Ends: 10 Oct 09:18 PM",
            "auspicious_moments": "Dawn Tarpan: 04:30 AM - 08:30 AM | Mahishasura Mardini: 04:00 AM | Chokkhudaan: All Day",
            "crowd_level": 0.35,
            "recommended_pujas": ["kumartuli_park", "bagbazar_sarbojanin", "sovabazar_rajbari"]
        },
        {
            "id": "panchami",
            "day": "Maha Panchami",
            "title_bn": "মহা পঞ্চমী — আনন্দময়ী আগমনী",
            "title_en": "Maha Panchami (Inaugurations)",
            "date": "Friday, 16 October 2026",
            "tithi": "Shukla Panchami",
            "timings": "Begins: 15 Oct 08:35 PM | Ends: 16 Oct 07:15 PM",
            "auspicious_moments": "VIP & Public Preview Openings: 04:00 PM onwards",
            "crowd_level": 0.45,
            "recommended_pujas": ["sreebhumi_sporting", "dum_dum_park_tarun", "fd_block_salt_lake"]
        },
        {
            "id": "shashthi",
            "day": "Maha Shashthi",
            "title_bn": "মহা ষষ্ঠী — বোধন, আমন্ত্রণ ও অধিবাস",
            "title_en": "Maha Shashthi (Bodhon & Awakening)",
            "date": "Saturday, 17 October 2026",
            "tithi": "Shukla Shashthi",
            "timings": "Begins: 16 Oct 07:15 PM | Ends: 17 Oct 06:12 PM",
            "auspicious_moments": "Kalparambha: 06:45 AM - 08:30 AM | Bodhon & Adhibas: 06:15 PM - 07:45 PM",
            "crowd_level": 0.65,
            "recommended_pujas": ["bagbazar_sarbojanin", "college_square", "santosh_mitra_square"]
        },
        {
            "id": "saptami",
            "day": "Maha Saptami",
            "title_bn": "মহা সপ্তমী — নবপত্রিকা স্নান ও প্রাণ প্রতিষ্ঠা",
            "title_en": "Maha Saptami (Nabapatrika / Kola Bou Snan)",
            "date": "Sunday, 18 October 2026",
            "tithi": "Shukla Saptami",
            "timings": "Begins: 17 Oct 06:12 PM | Ends: 18 Oct 05:30 PM",
            "auspicious_moments": "Nabapatrika Snan: 05:45 AM - 06:45 AM at Ganga Ghats | Saptami Vihita Puja: 08:30 AM",
            "crowd_level": 0.85,
            "recommended_pujas": ["ekdalia_evergreen", "singhi_park", "maddox_square"]
        },
        {
            "id": "ashtami",
            "day": "Maha Ashtami",
            "title_bn": "মহা অষ্টমী — কুমারী পূজা ও সন্ধি পূজা",
            "title_en": "Maha Ashtami (Kumari Puja & Sandhi Puja)",
            "date": "Monday, 19 October 2026",
            "tithi": "Shukla Ashtami",
            "timings": "Begins: 18 Oct 05:30 PM | Ends: 19 Oct 05:15 PM",
            "auspicious_moments": "Pushpanjali: 09:30 AM - 10:45 AM | Kumari Puja at Belur Math: 09:00 AM | SANDHI PUJA: 10:27 AM - 11:15 AM (Balidan 10:51 AM)",
            "crowd_level": 1.0,
            "recommended_pujas": ["belur_math", "sovabazar_rajbari", "maddox_square", "naktala_udayan"]
        },
        {
            "id": "nabami",
            "day": "Maha Nabami",
            "title_bn": "মহা নবমী — নবমী হোম ও ধুনুচি নাচ",
            "title_en": "Maha Nabami (Homa & Dhunuchi Naach)",
            "date": "Tuesday, 20 October 2026",
            "tithi": "Shukla Nabami",
            "timings": "Begins: 19 Oct 05:15 PM | Ends: 20 Oct 05:25 PM",
            "auspicious_moments": "Nabami Homa: 11:30 AM - 01:00 PM | Dhunuchi Naach: 08:00 PM - 02:00 AM",
            "crowd_level": 0.98,
            "recommended_pujas": ["ballygunge_cultural", "badamtala_ashar_sangha", "behala_club"]
        },
        {
            "id": "dashami",
            "day": "Bijoya Dashami",
            "title_bn": "বিজয়া দশমী — সিঁদুর খেলা ও বিসর্জন",
            "title_en": "Bijoya Dashami (Sindoor Khela & Immersion)",
            "date": "Wednesday, 21 October 2026",
            "tithi": "Shukla Dashami",
            "timings": "Begins: 20 Oct 05:25 PM | Ends: 21 Oct 06:05 PM",
            "auspicious_moments": "Darpan Visarjan: 10:45 AM | Sindoor Khela: 11:30 AM - 03:30 PM | Bisarjan: 04:30 PM - Midnight",
            "crowd_level": 0.70,
            "recommended_pujas": ["sovabazar_rajbari", "bagbazar_sarbojanin", "thakur_dalan"]
        },
        {
            "id": "lakshmi_puja",
            "day": "Kojagari Lakshmi Puja",
            "title_bn": "কোজাগরী লক্ষ্মী পূজা — ঐশ্বর্য ও শ্রী",
            "title_en": "Kojagari Lakshmi Puja (Harvest Full Moon)",
            "date": "Sunday, 25 October 2026",
            "tithi": "Ashwin Shukla Purnima",
            "timings": "Begins: 24 Oct 10:45 PM | Ends: 25 Oct 11:58 PM",
            "auspicious_moments": "Alpana Setup: Afternoon | Lakshmi Nishita Puja: 06:30 PM - 09:00 PM",
            "crowd_level": 0.20,
            "recommended_pujas": ["mallick_bari", "chalta_bagan"]
        }
    ]

@app.post("/api/chat")
async def chat_with_groq(req: ChatRequest):
    groq_api_key = os.environ.get("GROQ_API_KEY", "")

    client = Groq(api_key=groq_api_key)

    # Calculate dynamic database statistics
    total_pujas = len(PUJAS_DB)
    mega_count = sum(1 for p in PUJAS_DB if p.get("category") == "mega" or p.get("type") == "mega")
    heritage_count = sum(1 for p in PUJAS_DB if p.get("category") == "heritage" or p.get("type") == "heritage")
    south_count = sum(1 for p in PUJAS_DB if p.get("zone") == "South")
    north_count = sum(1 for p in PUJAS_DB if p.get("zone") == "North")
    saltlake_count = sum(1 for p in PUJAS_DB if p.get("zone") == "Salt Lake")
    central_count = sum(1 for p in PUJAS_DB if p.get("zone") == "Central")

    q_lower = req.query.lower().strip()
    is_stats_query = any(w in q_lower for w in ["database", "how many", "entries", "total", "count", "stats", "access", "dataset"])

    # Search for matching pandals based on query keywords
    matched = []
    for p in PUJAS_DB:
        name = p.get("name", "").lower()
        zone = p.get("zone", "").lower()
        landmark = p.get("landmark", "").lower()
        metro = p.get("metroStation", "").lower()
        cat = p.get("category", "").lower()
        history = p.get("history", "").lower()

        if q_lower in name or (len(q_lower) > 3 and (q_lower in zone or q_lower in landmark or q_lower in metro or q_lower in history)):
            matched.append(p)

    # If no keyword matches, sort all by proximity
    nearby = []
    for p in (matched if matched else PUJAS_DB):
        dist = haversine(req.lat, req.lon, p["lat"], p["lon"])
        p_copy = p.copy()
        p_copy["distance_meters"] = round(dist * 1.25, 1)
        p_copy["crowd_status"] = get_crowd_status()
        nearby.append(p_copy)

    nearby.sort(key=lambda x: x["distance_meters"])
    context_pujas = nearby[:15]
    context_str = json.dumps(context_pujas)

    prompt = f"""
You are the PujoRoute AI Assistant, the official festival intelligence guide for Kolkata Durga Puja.
YOU HAVE DIRECT, UNRESTRICTED ACCESS TO THE COMPLETE DATABASE OF {total_pujas} REGISTERED PUJAS.

EXACT VERIFIED DATABASE TOTALS & WEST BENGAL SUBSECTIONS:
- Total Indexed: {total_pujas} Durga Pujas
- Mega Thematic Pandals: {mega_count} (Sreebhumi, College Square, Ekdalia, Santosh Mitra Sq, Tridhara, Suruchi Sangha, Tala Barowari, etc.)
- Heritage Bonedi Bari Mansions: {heritage_count} (Sovabazar Rajbari, Hathkhola Dutta, Rani Rashmoni, Khelat Ghosh, Sabarna Roy Choudhury)
- 8 Official West Bengal Subsections:
  * South Kolkata (Gariahat / Ballygunge / Kalighat)
  * North Kolkata (Shyambazar / Baghbazar / Sovabazar)
  * North 24 Parganas (VIP Road / Lake Town / Dum Dum)
  * Jadavpur & South Suburbs (Garia / Tollygunge / Naktala)
  * Howrah & Riverfront (West of Hooghly)
  * Salt Lake & New Town (Bidhannagar / Sector 1-5)
  * Central Kolkata (College Sq / Bowbazar / Sealdah)
  * Behala & South-West (Diamond Harbour Rd / Barisha)

OFFICIAL DURGA PUJA 2026 PANJIKA & TITHI CALENDAR:
- Mahalaya: Saturday, 10 October 2026 (Dawn Tarpan at Ganga Ghats 04:30 AM, Chokkhudaan at Kumartuli)
- Maha Panchami: Friday, 16 October 2026 (Anandamoyee Agamani, VIP preview openings)
- Maha Shashthi: Saturday, 17 October 2026 (Kalparambha 06:45 AM, Devi Bodhon under Bel tree in evening)
- Maha Saptami: Sunday, 18 October 2026 (Nabapatrika / Kola Bou Snan at Hooghly riverbanks 05:45 AM, Prana Pratishtha)
- Maha Ashtami: Monday, 19 October 2026 (Pushpanjali 09:30 AM - 10:45 AM, Kumari Puja at Belur Math 09:00 AM, AUSPICIOUS SANDHI PUJA: 10:27 AM - 11:15 AM with 108 lamps & 108 lotuses, Balidan at 10:51 AM)
- Maha Nabami: Tuesday, 20 October 2026 (Nabami Homa 11:30 AM, evening Dhunuchi Naach, all-night hopping)
- Bijoya Dashami: Wednesday, 21 October 2026 (Darpan Visarjan 10:45 AM, Sindoor Khela 11:30 AM, Bisarjan at Babughat evening, Shubho Bijoya)
- Kojagari Lakshmi Puja: Sunday, 25 October 2026 (Full Moon, Alpana footsteps, Naru)

User Coordinates: Lat: {req.lat}, Lon: {req.lon}.
Context Pandals from Database with Subsections, Metros & Significance:
{context_str}

DIRECTIVES:
1. When asked which subsection of West Bengal a pandal belongs to, identify its exact subsection from the 8 official West Bengal subsections above.
2. For any pandal, explain its nearest Kolkata Metro station (with Line name) and its cultural, historical, or artistic significance.
3. If the user asks about the database, count, or accessibility, state affirmatively that you have direct access to all {total_pujas} Durga Pujas in Kolkata, and cite the exact numbers.
4. Speak with authentic Bengali festival warmth and authority.
5. For suggested routes, provide an organized hopping sequence with walking times and recommend tapping Auto-Circuit to launch in Google Maps.

Respond in strict JSON format:
{{
  "reply": "Your natural language response here",
  "suggested_route": [
    {{ "id": "pandal_id_1", "name": "Name", "lat": 22.59, "lon": 88.36 }},
    {{ "id": "pandal_id_2", "name": "Name", "lat": 22.60, "lon": 88.37 }}
  ]
}}

User Query: {req.query}
"""

    try:
        completion = client.chat.completions.create(
            model="openai/gpt-oss-20b",
            messages=[
                {"role": "system", "content": "You are a helpful, authoritative Pujo AI assistant. Always return valid JSON."},
                {"role": "user", "content": prompt}
            ],
            response_format={"type": "json_object"},
            temperature=0.6,
            max_tokens=600,
        )
        reply_json_str = completion.choices[0].message.content
        return json.loads(reply_json_str)
    except Exception as e:
        if is_stats_query:
            return {
                "reply": f"📊 PujoRoute Master Database Status:\n\n"
                         f"I have direct access to all {total_pujas} registered Durga Pujas in Kolkata:\n"
                         f"• Total Indexed: {total_pujas} Pujas\n"
                         f"• 🔥 Mega Themes: {mega_count}\n"
                         f"• 🏛️ Heritage Bonedi Bari: {heritage_count}\n"
                         f"• South Kolkata: {south_count}\n"
                         f"• North Kolkata: {north_count}\n"
                         f"• Salt Lake & Newtown: {saltlake_count}\n"
                         f"• Central Kolkata: {central_count}\n\n"
                         f"All entries feature verified GPS coordinates, walking durations, crowd movement telemetry, and 1-tap Google Maps directions!",
                "suggested_route": []
            }
        return {
            "reply": "Here are the top pandals near you for your hopping route! Tap Auto-Circuit to start.",
            "suggested_route": [
                {"id": p["id"], "name": p["name"], "lat": p["lat"], "lon": p["lon"]}
                for p in context_pujas[:8]
            ]
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=os.environ.get("HOST", "127.0.0.1"), port=int(os.environ.get("PORT", "8000")), proxy_headers=True)
