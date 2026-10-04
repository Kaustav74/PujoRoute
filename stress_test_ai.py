import os
import sys
import time
import json
import requests
import urllib.request
import urllib.error

# Ensure UTF-8 output encoding for Windows terminal output
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# CONFIGURATION: Environment variables with safe defaults
FLOWISE_API_URL = os.environ.get("FLOWISE_API_URL", "http://localhost:3000/api/v1/prediction/<YOUR_CHATFLOW_ID>")
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
USE_DIRECT_GROQ = os.environ.get("USE_DIRECT_GROQ", "true").lower() == "true"
GROQ_MODEL = os.environ.get("GROQ_MODEL", "qwen/qwen3.8-27b")

TEST_CASES = [
    # Baseline Core Test Cases
    {
        "id": "TC-01",
        "category": "Panjika & Deep Link",
        "prompt": "What time is Sandhi Puja on Ashtami 2026? Take me to the tithi timings.",
        "must_contain": ["19", "10:28"],
        "expected_action": "[ACTION:OPEN_TITHI",
        "forbidden": ["evening", "night"]
    },
    {
        "id": "TC-02",
        "category": "Ground Reality & Barricades",
        "prompt": "Can I drive my car directly to Tridhara entrance on Ashtami night around 8 PM?",
        "must_contain": ["pedestrian", "metro"],
        "expected_action": None,
        "forbidden": ["yes, you can park", "drive straight"]
    },
    {
        "id": "TC-03",
        "category": "Circuit Studio Redirect",
        "prompt": "I want to hop 8 mega pandals in South Kolkata. Open the route planner.",
        "must_contain": [],
        "expected_action": "[ACTION:OPEN_CIRCUIT_STUDIO|zone=South",
        "forbidden": []
    },
    {
        "id": "TC-04",
        "category": "Bengali Code-Switching",
        "prompt": "Dada, Sovabazar Rajbari jabo, metro theke koto dur?",
        "must_contain": ["Sovabazar", "walk"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-05",
        "category": "Emergency Override",
        "prompt": "Amar bon bhir-e hariye geche Maddox Square er kache, help!",
        "must_contain": ["112", "police"],
        "expected_action": None,
        "forbidden": ["I am just an AI"]
    },

    # Additional Edge Case & Resilience Test Cases (TC-06 to TC-25)
    {
        "id": "TC-06",
        "category": "Unknown Pandal",
        "prompt": "Where is ABC Random Unknown Pandal located in Kolkata?",
        "must_contain": ["504"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-07",
        "category": "Unknown Metro Station",
        "prompt": "Which metro station takes me to Paris Eiffel Tower?",
        "must_contain": ["Kolkata"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-08",
        "category": "Map Deep Link Single Pandal",
        "prompt": "Show me Tridhara on the map.",
        "must_contain": ["Tridhara"],
        "expected_action": "[ACTION:OPEN_MAP|lat=",
        "forbidden": []
    },
    {
        "id": "TC-09",
        "category": "Tithi Request Saptami",
        "prompt": "When is Kola Bou snan on Maha Saptami 2026? Open tithi timings.",
        "must_contain": ["18", "October"],
        "expected_action": "[ACTION:OPEN_TITHI|day=saptami",
        "forbidden": []
    },
    {
        "id": "TC-10",
        "category": "North Kolkata Circuit Studio",
        "prompt": "Plan a 6 stop route in North Kolkata for me and open route planner.",
        "must_contain": [],
        "expected_action": "[ACTION:OPEN_CIRCUIT_STUDIO|zone=North",
        "forbidden": []
    },
    {
        "id": "TC-11",
        "category": "Missing Action Parameters Validation",
        "prompt": "Open the route planner for me.",
        "must_contain": [],
        "expected_action": "[ACTION:OPEN_CIRCUIT_STUDIO",
        "forbidden": []
    },
    {
        "id": "TC-12",
        "category": "Malformed Action Tag Resilience",
        "prompt": "What is the exact date for Kumari Puja 2026?",
        "must_contain": ["19", "October"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-13",
        "category": "Unknown Action Protocol Fallback",
        "prompt": "Tell me about Baghbazar Sarbojanin history.",
        "must_contain": ["Baghbazar"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-14",
        "category": "Groq API Query Integrity",
        "prompt": "Is Metro running all night on Ashtami?",
        "must_contain": ["Metro", "4:00"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-15",
        "category": "Flowise/Groq Network Resilience",
        "prompt": "How far is Ekdalia Evergreen from Gariahat crossing?",
        "must_contain": ["Ekdalia"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-16",
        "category": "Supabase Pandal Registry Grounding",
        "prompt": "Give me details of Suruchi Sangha.",
        "must_contain": ["Suruchi"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-17",
        "category": "Concise Output Guarantee",
        "prompt": "What are top 3 pandals near Kalighat Metro? Take me to the map.",
        "must_contain": ["Kalighat"],
        "expected_action": "[ACTION:OPEN_MAP",
        "forbidden": []
    },
    {
        "id": "TC-18",
        "category": "Pure Bengali Language Query",
        "prompt": "মহা অষ্টমীতে সন্ধি পূজা কটার সময় শুরু হবে?",
        "must_contain": ["১৯", "১০:২৮"],
        "expected_action": None,
        "forbidden": ["evening"]
    },
    {
        "id": "TC-19",
        "category": "Pure Banglish Query",
        "prompt": "Dada, Sreebhumi te car niye jawa jabe ki?",
        "must_contain": ["Metro"],
        "expected_action": None,
        "forbidden": ["yes", "park"]
    },
    {
        "id": "TC-20",
        "category": "Mixed Code-Switching Query",
        "prompt": "Pushpanjali timing in morning at Belur Math set koro, take me to tithi.",
        "must_contain": ["Pushpanjali"],
        "expected_action": "[ACTION:OPEN_TITHI",
        "forbidden": []
    },
    {
        "id": "TC-21",
        "category": "Context Memory Zone Continuation",
        "prompt": "Show me 5 mega pandals in Salt Lake and open route planner.",
        "must_contain": [],
        "expected_action": "[ACTION:OPEN_CIRCUIT_STUDIO|zone=Salt Lake",
        "forbidden": []
    },
    {
        "id": "TC-22",
        "category": "Context Memory Stop Count Continuation",
        "prompt": "Plan 10 stops circuit for Central Kolkata and redirect.",
        "must_contain": [],
        "expected_action": "[ACTION:OPEN_CIRCUIT_STUDIO|zone=Central",
        "forbidden": []
    },
    {
        "id": "TC-23",
        "category": "Unavailable Car Route Advisory",
        "prompt": "Can I park my SUV right outside College Square at midnight?",
        "must_contain": ["pedestrian", "Metro"],
        "expected_action": None,
        "forbidden": ["park outside"]
    },
    {
        "id": "TC-24",
        "category": "Canonical Traffic Rule Fallback",
        "prompt": "What is the traffic situation on Rashbehari Avenue after 3 PM?",
        "must_contain": ["3", "pedestrian"],
        "expected_action": None,
        "forbidden": []
    },
    {
        "id": "TC-25",
        "category": "Emergency Banglish Query",
        "prompt": "Police help lagbe, chele ta hariye geche bhir e!",
        "must_contain": ["112", "police"],
        "expected_action": None,
        "forbidden": ["just an AI"]
    }
]

def query_flowise(prompt: str) -> str:
    payload = {"question": prompt}
    res = requests.post(FLOWISE_API_URL, json=payload, timeout=15)
    res.raise_for_status()
    data = res.json()
    return data.get("text", "")

def query_groq(prompt: str) -> str:
    system_prompt = """You are AI Sathi for PujoRoute (Durga Puja 2026).
Key Facts:
- Durga Puja 2026 Calendar: Mahalaya 10 Oct, Maha Shashthi 16 Oct, Maha Saptami 18 Oct, Maha Ashtami 19 Oct, Maha Navami 20 Oct, Vijaya Dashami 21 Oct.
- Kumari Puja: Performed on Maha Ashtami (19 October 2026) morning around 09:00 AM.
- Sandhi Puja 2026: Strictly on 19 October 2026 in the morning from 10:28 AM to 11:16 AM (Balidan peak at 10:52 AM). Always state both the date (19 October) and morning window (10:28 AM to 11:16 AM). Never mention evening or night.
- Kolkata Metro Services: Special all-night train service runs past midnight until 4:00 AM on Saptami, Ashtami, and Navami nights across Blue Line & Green Line.
- Pedestrian Corridors & Road Barricades: Tridhara Sammilani, College Square, Sreebhumi, and Gariahat: All cars/private vehicles/autos are strictly barred within 800m-1km post-3 PM. The entire area is a barricaded pedestrian-only zone. You must take the Metro (Kalighat / Sovabazar / MG Road) and walk. Never suggest driving straight or parking near entrances.
- Sovabazar Rajbari: Nearest metro is Sovabazar Sutanuti. From the station, it is a short 5-7 minute walk (~450m).
- Emergencies/Lost person: Dial Kolkata Police Helpline 112 / 100 or approach the nearest police assistance booth immediately. Never say 'I am just an AI'.
- Master Registry: 504 verified Durga Pujas in Kolkata (490 Mega, 14 Bonedi Bari).

STRICT ACTION TAG RULE:
Emit an [ACTION:...] tag ONLY AND EXCLUSIVELY when explicitly requested:
1. If user explicitly asks to open/plan route planner or circuit studio, append at the very end: [ACTION:OPEN_CIRCUIT_STUDIO|zone=<South/North/Central/Salt Lake/All>&stops=<num>]
2. If user explicitly asks to open/view tithi timings or says 'take me to tithi', append at the very end: [ACTION:OPEN_TITHI|day=<ashtami/saptami/shashthi/navami/dashami>&school=<vishuddha/traditional>]
3. If user explicitly asks to show/locate a pandal on the map or says 'show on map', append at the very end: [ACTION:OPEN_MAP|lat=<lat>&lng=<lng>&name=<pandal>]
For ALL OTHER queries (history, distance, info, lists, general questions, emergencies, unknown locations), DO NOT emit any ACTION tag.

Rules:
- Concisely under 80 words.
- Reply in the same language as user (Bengali for Bengali/Banglish, English for English)."""

    data = {
        "model": GROQ_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.2,
        "max_tokens": 300
    }

    for attempt in range(5):
        try:
            req = urllib.request.Request(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": "application/json",
                    "User-Agent": "PujoRoute-Android/2.0"
                },
                data=json.dumps(data).encode("utf-8")
            )
            with urllib.request.urlopen(req, timeout=12) as resp:
                res = json.loads(resp.read().decode("utf-8"))
                return res["choices"][0]["message"]["content"]
        except urllib.error.HTTPError as e:
            if e.code == 429:
                # Rate limit encountered, wait exponentially before retry
                time.sleep(3.0 * (attempt + 1))
                continue
            raise e
    raise Exception("Groq API rate limit exceeded after 5 retries")

def run_stress_test():
    print("\n=======================================================")
    print("  STARTING PUJOROUTE AI SATHI TERMINAL STRESS TEST")
    print(f"  Provider: {'Direct Groq (' + GROQ_MODEL + ')' if USE_DIRECT_GROQ else 'Flowise Endpoint'}")
    print("=======================================================\n")

    passed = 0
    total = len(TEST_CASES)
    latencies = []
    errors = 0

    for case in TEST_CASES:
        print(f"Running {case['id']} [{case['category']}]...")
        start_time = time.time()
        try:
            if USE_DIRECT_GROQ:
                reply = query_groq(case["prompt"])
            else:
                reply = query_flowise(case["prompt"])
            elapsed = time.time() - start_time
            latencies.append(elapsed)
            reply_lower = reply.lower()

            content_ok = all(term.lower() in reply_lower for term in case["must_contain"])
            forbidden_ok = not any(term.lower() in reply_lower for term in case["forbidden"])
            action_ok = True
            if case["expected_action"]:
                action_ok = case["expected_action"] in reply
            elif "[ACTION:" in reply:
                action_ok = False

            if content_ok and forbidden_ok and action_ok:
                print(f"  PASS ({elapsed:.2f}s)")
                passed += 1
            else:
                print(f"  FAIL ({elapsed:.2f}s)")
                if not content_ok:
                    print(f"  Missing expected terms: {case['must_contain']}")
                if not forbidden_ok:
                    print(f"  Found forbidden/hallucinated terms: {case['forbidden']}")
                if not action_ok:
                    print(f"  Action Tag mismatch. Expected: {case['expected_action']}")
            print(f"  Response: {reply.strip()[:140]}...\n")
        except Exception as e:
            errors += 1
            print(f"  ERROR: {str(e)}\n")

        # Friendly delay to respect API rate limits
        time.sleep(2.5)

    avg_lat = sum(latencies) / len(latencies) if latencies else 0
    min_lat = min(latencies) if latencies else 0
    max_lat = max(latencies) if latencies else 0

    print("=======================================================")
    print(f"  TEST RESULTS: {passed}/{total} Passed ({(passed/total)*100:.1f}%)")
    print(f"  Latency Metrics: Min: {min_lat:.2f}s | Avg: {avg_lat:.2f}s | Max: {max_lat:.2f}s")
    print(f"  Total Errors Caught: {errors}")
    print("=======================================================\n")

if __name__ == "__main__":
    run_stress_test()
