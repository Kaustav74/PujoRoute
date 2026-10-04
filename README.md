# PujoRoute — Kolkata Durga Puja 2026 Companion

PujoRoute is an offline-first Flutter app for navigating Kolkata's Durga Puja pandals
(504 pandals, route planner "Circuit Studio", Panjika calendar, metro guide, emergency
directory) with an optional AI assistant ("AI Sathi").

## Repository layout

| Path | What it is |
|------|-----------|
| `Android App/` | **Main Flutter app** (tests pass: `flutter test`). |
| `app/` | Older Flutter copy — currently does **not compile** (missing services). Prefer `Android App/`. |
| `backend/` | FastAPI API (`main.py`): nearby pandals, calendar, session sync, AI chat proxy. |
| `server/cloudflare_worker/` | Cloudflare Worker AI gateway (HMAC-signed requests, rate limiting, KV cache). |
| `server/main.py` | Legacy FastAPI variant (expects `server/pujas.json`, which is absent). |
| `supabase/schema.sql` | Postgres/PostGIS schema with Row Level Security. |
| root `*.py` | Ad-hoc evaluation / stress-test scripts (read keys from env). |

## Configuration

All secrets come from environment variables — see [`.env.example`](.env.example).
Never commit `.env`, `key.properties` or `*.jks` (they are git-ignored).

## Run the backend

```bash
cd backend
pip install -r requirements.txt
export FREELLMAPI_API_KEY=...   # rotated key
uvicorn main:app --host 0.0.0.0 --port 8000 --proxy-headers
# or: docker build -t pujoroute-api . && docker run -p 8000:8000 -e FREELLMAPI_API_KEY=... pujoroute-api
```

Tests: `pip install -r requirements-dev.txt && python -m pytest -q tests`

## Cloudflare Worker

```bash
cd server/cloudflare_worker
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put GATEWAY_SEED   # must match the app's signing seed
npx wrangler deploy
```

## Flutter app

```bash
cd "Android App"
flutter pub get && flutter test
flutter build appbundle --release --dart-define=FREELLMAPI_API_KEY=...
```

Release signing reads `android/key.properties` (git-ignored). Anything passed with
`--dart-define` ships inside the APK and can be extracted — keep real provider keys on
the server (backend / worker) whenever possible.
