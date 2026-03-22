# citycast — Full Project Roadmap

## Context

citycast is an AI-powered location-based app that turns walking through a city into a live, personalized podcast experience. Tourists wear headphones and walk — the app uses accurate GPS to play short, pre-generated podcast segments matched to their exact location. Content is generated **in advance** by the studio on your Mac (Ollama + Piper TTS), compressed, and uploaded to a serverless cloud. The frontend handles all localization (GPS, region detection, playback triggering) and intelligently pre-downloads upcoming segments to minimize bandwidth needs.

**Business model**: Businesses pay to place audio ads and clickable links inside the app and companion website — location-targeted sponsorship woven into the walking experience.

---

## Legal Awareness

> **CLAUDE.md rule**: Always stay away from possible legal problems and inform the user.

Key areas to watch:
- **Map data licensing**: Use OpenStreetMap (ODbL license — free, requires attribution). **Must show "© OpenStreetMap contributors"** in app and website. Avoid scraping Google Maps.
- **Map rendering**: MapLibre (MIT license) + OpenFreeMap (free, no API key) — fully open, no restrictions.
- **Audio content**: AI-generated scripts must not copy copyrighted tour guide content. Generate original storytelling only.
- **Location privacy**: GDPR/KVKK compliance — never store raw GPS trails. Only store anonymized region-level analytics.
- **Ad disclosures**: Sponsored audio segments must be clearly labeled as ads (FTC/EU transparency rules).
- **TTS voice rights**: Piper TTS (MIT) — engine is free. Voice models: check per model (most are permissive, never use NC/non-commercial voices).
- **LLM model**: Mistral (Apache 2.0) — fully free for commercial use, no restrictions.
- **App store compliance**: Both Apple and Google require clear privacy policies and location permission justification.
- **Ad approval paper trail**: Store acceptance timestamp + exact audio version the business approved — protects against ad disputes.

---

## Security

### Threats & Mitigations

#### API Abuse (most likely attack)
- **Rate limiting**: Apply per-IP rate limits on all public endpoints (e.g., 60 req/min for reads, 10 req/min for writes)
- **Ad submission spam**: CAPTCHA on ad portal form + email verification before ad request is created
- **Analytics flooding**: Rate limit `POST /analytics/events` aggressively (max 1 per 10s per session_id)

#### Data Protection
- **No raw GPS storage**: Only store region-level anonymized playback events — even if DB is breached, no user tracking possible
- **Input sanitization**: Validate and sanitize all user inputs (ad text, business info) — prevent XSS and SQL injection
- **Audio URLs**: Use signed/expiring URLs for audio files — prevent hotlinking and unauthorized bulk downloads
- **Environment variables**: Never commit `.env` files. Use `.env.example` with placeholders only

#### Infrastructure Security
- **HTTPS everywhere**: All API endpoints and portal must use TLS (serverless providers handle this)
- **Studio portal auth**: Password-protected + IP allowlist if possible. Only you should access it
- **CORS policy**: Backend only accepts requests from known origins (your mobile app, website domain)
- **Dependency scanning**: Run `pip audit` and `npm audit` in CI to catch vulnerable packages
- **Docker images**: Use minimal base images (python:3.12-slim), don't run as root

#### DDoS / Cost Attacks
- **Serverless scales-to-zero protects idle cost**, but a DDoS can scale UP your bill
- **Set spending limits / alerts** on your cloud provider — get notified before costs spike
- **Cloudflare free tier** in front of your API: free DDoS protection + CDN for audio files
- **Audio file caching**: Serve audio through CDN — attackers hit the CDN, not your backend

#### Ad System Abuse
- **Email verification** before businesses can submit ads
- **Approval workflow** (admin review) prevents malicious/spam ads from going live
- **Content moderation**: Ollama script polisher should refuse to generate ads with harmful content
- **Rate limit ad submissions**: Max 3 per email per day

### Implementation — Libraries & How

#### 1. Rate Limiting — `slowapi`
```python
# backend/app/middleware/rate_limiter.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

# Usage in routers:
@router.get("/cities")
@limiter.limit("60/minute")
async def get_cities(request: Request): ...

@router.post("/ads")
@limiter.limit("10/minute")
async def submit_ad(request: Request): ...

@router.post("/analytics/events")
@limiter.limit("6/minute")
async def log_event(request: Request): ...
```

#### 2. Signed Audio URLs — `itsdangerous`
```python
# backend/app/services/broadcast.py
from itsdangerous import URLSafeTimedSerializer

signer = URLSafeTimedSerializer(settings.S3_SIGNING_SECRET)

def make_signed_url(audio_path: str, max_age: int = 86400) -> str:
    """Generate a URL that expires in 24h."""
    token = signer.dumps(audio_path)
    return f"{settings.API_BASE_URL}/audio/{token}"

def verify_signed_url(token: str) -> str:
    """Returns audio_path or raises SignatureExpired."""
    return signer.loads(token, max_age=86400)
```

#### 3. CAPTCHA — hCaptcha (free, privacy-friendly)
```typescript
// frontend/web — AdPortal.tsx
import HCaptcha from "@hcaptcha/react-hcaptcha";
// Renders CAPTCHA widget on ad submission form
// On submit: sends captcha token to backend
```
```python
# backend/app/routers/ads.py
import httpx

async def verify_captcha(token: str) -> bool:
    resp = await httpx.post("https://api.hcaptcha.com/siteverify", data={
        "secret": settings.HCAPTCHA_SECRET,
        "response": token,
    })
    return resp.json().get("success", False)
```

#### 4. Email Verification — simple code flow
```python
# backend/app/routers/ads.py
# Step 1: Business submits ad → we send 6-digit code to their email
# Step 2: Business enters code → we verify → ad request created in DB
# Code expires in 15 minutes, stored in-memory (dict) or DB
```

#### 5. CORS — FastAPI built-in
```python
# backend/app/main.py
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS.split(","),
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
```

#### 6. Input Sanitization — `bleach` + Pydantic
```python
# backend/app/schemas/ad_request.py
import bleach
from pydantic import BaseModel, field_validator

class AdSubmission(BaseModel):
    business_name: str
    business_email: str
    submitted_text: str

    @field_validator("business_name", "submitted_text")
    @classmethod
    def strip_html(cls, v: str) -> str:
        return bleach.clean(v, tags=[], strip=True)
```
SQLAlchemy parameterized queries prevent SQL injection by default.

#### 7. Dependency Scanning — CI step
```yaml
# .github/workflows/ci.yml
- name: Audit Python deps
  run: pip audit
- name: Audit Node deps
  run: npm audit --audit-level=moderate
  working-directory: frontend/web
```

#### 8. DDoS Protection — Cloudflare free tier (optional)
- Point your domain DNS to Cloudflare (free plan)
- Cloudflare proxies all traffic → absorbs DDoS
- Caches audio files at edge → faster for users, cheaper for you
- Free SSL certificate included

#### 9. Spending Limits
- Set max monthly budget alert on cloud provider dashboard
- If using VPS: fixed cost, no surprise scaling
- If using serverless: configure hard spending cap if provider supports it

---

## Tech Stack

### Frontend (Mobile + Web)
- **React Native + Expo** — iOS + Android from one codebase
- **React (Vite)** — companion website (ad placement portal + web player)
- **MapLibre GL** + **OpenFreeMap** — map rendering (MIT, free, no API key, no usage limits)
- **Expo Location** — high-accuracy GPS tracking (all localization runs on device)
- **Expo AV** — audio playback with queue management
- **Zustand** — lightweight state management
- **Vitest** — unit tests

### Backend (Python)
- **FastAPI** — map/audio broadcast service
- **PostgreSQL** — cities, regions, podcasts, ads
- **Docker Compose** — local dev orchestration
- **pytest + httpx** — tests

### Studio (Python — Content Generation + Internal Portal)
- **Ollama** (local LLM, Mistral — Apache 2.0) — podcast script generation (runs on your Mac)
- **Piper TTS** (MIT, open-source, offline) — audio synthesis on CPU (runs on your Mac)
- **FFmpeg** (LGPL) — audio compression (opus/mp3, small file sizes)
- **Overpass API (OpenStreetMap)** — free POI/map data for seeding regions
- **FastAPI + Jinja2** — internal admin portal (web UI, deployed to cloud)
- **SMTP / Resend** — email ad previews to businesses for approval

### Deployment — Serverless Cloud (credits-only, no credit card)

> **Requirement**: Only use cloud providers that accept prepaid credits without requiring a credit card on file.
> The specific provider will be chosen at deploy time. The codebase is provider-agnostic — standard Docker containers + S3-compatible storage.

| Service | What | Notes |
|---|---|---|
| Backend (FastAPI) | Serverless container | Scales to zero, pay per use |
| Studio Portal | Serverless container | Password-protected, scales to zero |
| Website | Static hosting or serverless container | Scales to zero |
| PostgreSQL | Managed or container DB | Included with provider or self-hosted |
| Audio files | S3-compatible object storage | Any provider (Tigris, B2, MinIO, etc.) |
| Studio pipeline | **Your Mac** (local) | $0 — Ollama + Piper + FFmpeg |
| Mobile app | Expo EAS | TestFlight + Android APK |

**Candidates** (to evaluate at deploy time based on credit card policy):
- Fly.io ($5/mo credit, but requires CC)
- Railway ($5/mo credit, may require CC)
- Render (free tier, may not require CC)
- Koyeb (free nano instance, no CC for free tier)
- Self-hosted VPS with prepaid credits (Hetzner, DigitalOcean with prepaid)

**Fallback**: If no provider accepts credits-only, deploy backend + portal + website on a cheap VPS (~$5/mo prepaid, Hetzner) running Docker Compose. Same containers, same code.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│          STUDIO PIPELINE (runs on your Mac)           │
│                                                      │
│  Map Data (OSM) → Region Splitter → Script Gen       │
│                    (grid zones)    (Ollama/Mistral)   │
│                                        │             │
│                                   TTS (Piper)        │
│                                        │             │
│                                  FFmpeg compress      │
│                                        │             │
│                              Upload to Cloud         │
│                              (S3 storage + Postgres) │
└──────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│      SERVERLESS CLOUD (scales to zero, credits-only)  │
│                                                      │
│  ┌─ Backend (FastAPI) ────────────────────────────┐  │
│  │  GET /cities              — list cities         │  │
│  │  GET /cities/{id}/map     — region grid + POIs  │  │
│  │  GET /regions/{id}/podcasts — audio URLs        │  │
│  │  GET /regions/nearby?lat&lon — near coords      │  │
│  │  GET /paths/{city_id}     — walking paths       │  │
│  │  POST /ads                — submit ad request   │  │
│  │  GET /ads/for-region/{id} — ads for region      │  │
│  │  POST /analytics/events   — anonymized playback │  │
│  │  [Rate limiting on all endpoints]               │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌─ Studio Portal (FastAPI + Jinja2) ─────────────┐  │
│  │  Dashboard, map view, podcast manager,          │  │
│  │  ad request queue, ad approval workflow          │  │
│  │  [Password-protected + IP allowlist]             │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌─ Website (React/Vite) ─────────────────────────┐  │
│  │  City browser, web player, ad portal            │  │
│  │  [CAPTCHA on ad submission form]                 │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  Postgres ─── S3 Storage (audio files, signed URLs)  │
└──────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────┐
│              FRONTEND (Mobile App)                    │
│                                                      │
│  All localization runs on device:                    │
│  - MapLibre + OpenFreeMap (base map tiles)           │
│  - Region grid overlay from backend (GeoJSON)        │
│  - High-accuracy GPS tracking (Expo Location)        │
│  - Region detection = local math (no API calls)      │
│  - Pre-downloads ~5 upcoming podcast segments        │
│  - Audio queue: region podcast → ad → next           │
│  - Tourist path mode: follow suggested route         │
│  - Ad banner + sponsored audio segments              │
│  - Works offline once regions are downloaded          │
└──────────────────────────────────────────────────────┘
```

### How It Works — User Walking Flow

1. User opens app, selects a city
2. App downloads the **region map grid** for that city (lightweight JSON)
3. App **pre-downloads podcast segments** for nearby regions (buffer of ~5 ahead)
4. GPS tracks user position with high accuracy
5. When user enters a new region → play that region's podcast segment
6. As user walks, app continuously pre-downloads next segments in walking direction
7. If a region has a sponsor → play ad audio segment before/after the podcast
8. All playback feels seamless and real-time, like a live podcast

### How Content Is Created (Studio Pipeline — Your Mac)

1. Take a city center point + radius
2. Divide the area into a **grid of regions** (e.g., 200m x 200m squares)
3. For each region, pull POI data from OpenStreetMap (landmarks, streets, buildings)
4. Feed POI data to **Ollama (Mistral)** → generate a short podcast script (60–120s, storytelling style)
5. Feed script to **Piper TTS** → generate audio
6. **FFmpeg** → compress to opus (small size, good quality)
7. Upload to cloud S3 storage, write metadata to Postgres
8. Repeat for each language

### Ad Approval Workflow (Studio Internal Portal)

1. **Business** submits ad text + picks a location via the **website ad portal** (CAPTCHA + email verification)
2. Ad request lands in DB with status `new`
3. **Studio pipeline** (your Mac) auto-generates voice ad: Ollama polishes the text → Piper TTS → FFmpeg compress
4. Status moves to `generated`
5. **Admin** opens internal portal, sees the new ad request:
   - Previews the generated voice ad
   - Sees target location on the map
   - Can edit the text and regenerate if needed
6. **Admin clicks "Send for approval"** → portal sends an email to the business with:
   - Audio preview link (signed URL, expires in 7 days)
   - Target location details
   - Accept / Reject buttons
7. Status moves to `sent`
8. **Business clicks "Accept"** → status moves to `accepted` → ad goes live
9. **Business clicks "Reject"** → status moves to `rejected` → admin can revise and resend
10. System stores: acceptance timestamp, exact audio version approved, business email confirmation

---

## Database Schema

### `cities`
- id, name, country, center_lat, center_lon, radius_km, grid_size_m (default 200), created_at

### `regions`
- id, city_id (FK), grid_row, grid_col, center_lat, center_lon, bounds_geojson, poi_data (JSONB), created_at

### `podcasts`
- id, region_id (FK), language, script_text, audio_url, duration_s, file_size_bytes, status (pending/ready/failed), created_at
- **Unique constraint: (region_id, language)**

### `tourist_paths`
- id, city_id (FK), name, description, region_ids (JSONB array — ordered list of region IDs), language, total_duration_s, created_at

### `ad_requests`
- id, business_name, business_email (verified), business_url, submitted_text, target_city_id, target_region_id (nullable), price_paid, status (new/generated/sent/accepted/rejected), created_at, updated_at

### `ad_audio_versions`
- id, ad_request_id (FK), polished_text, audio_url, duration_s, version_number, created_at

### `ad_approvals`
- id, ad_request_id (FK), ad_audio_version_id (FK), sent_at, responded_at, response (accepted/rejected), business_ip, created_at
- **Paper trail**: links exact audio version to business acceptance

### `ad_placements` (only created after acceptance)
- id, ad_request_id (FK), ad_audio_version_id (FK), target_city_id, target_region_id (nullable), active, starts_at, expires_at, created_at

### `playback_events` (anonymized analytics)
- id, session_id (random, not user-linked), region_id, ad_id (nullable), played_at, duration_played_s

---

## Directory Structure

```
citycast/
├── CLAUDE.md
├── plan.md
├── docker-compose.yml          # Local dev: all services together
├── .devcontainer/
│   └── devcontainer.json       # VS Code Dev Container config
├── .gitignore
│
├── frontend/
│   ├── mobile/                     # React Native + Expo
│   │   ├── package.json
│   │   ├── app.json
│   │   └── src/
│   │       ├── api/
│   │       │   └── client.ts              # Module M1: API client
│   │       ├── components/
│   │       │   ├── Map.tsx                 # Module M2: MapLibre + region overlay
│   │       │   ├── AudioPlayer.tsx         # Module M3: Audio playback queue
│   │       │   ├── CitySelector.tsx        # Module M4: City picker
│   │       │   ├── PathView.tsx            # Module M5: Tourist path mode
│   │       │   └── AdBanner.tsx            # Module M6: Ad display
│   │       ├── hooks/
│   │       │   ├── useGeolocation.ts       # Module M7: High-accuracy GPS
│   │       │   ├── useRegionTracker.ts     # Module M8: Detect current region
│   │       │   ├── usePodcastBuffer.ts     # Module M9: Pre-download manager
│   │       │   └── useAudioQueue.ts        # Module M10: Playback sequencing
│   │       ├── store/
│   │       │   └── appStore.ts
│   │       └── tests/
│   │
│   └── web/                        # React (Vite) — website
│       ├── package.json
│       └── src/
│           ├── pages/
│           │   ├── Home.tsx                # Module W1: Landing page
│           │   ├── CityBrowser.tsx         # Module W2: Browse cities
│           │   ├── WebPlayer.tsx           # Module W3: Listen on web
│           │   └── AdPortal.tsx            # Module W4: Buy ad placements
│           ├── components/
│           └── tests/
│
├── backend/
│   ├── pyproject.toml
│   ├── Dockerfile
│   ├── alembic.ini
│   ├── alembic/versions/
│   ├── app/
│   │   ├── main.py                        # Module B1: FastAPI app + config
│   │   ├── database.py                    # Module B2: DB engine + session
│   │   ├── middleware/                     # Module B7: Security middleware
│   │   │   ├── rate_limiter.py            # slowapi per-IP rate limiting
│   │   │   └── cors.py                    # Strict CORS policy
│   │   ├── security/                      # Module B8: Security utilities
│   │   │   ├── signed_urls.py             # itsdangerous signed/expiring audio URLs
│   │   │   ├── captcha.py                 # hCaptcha server-side verification
│   │   │   ├── email_verify.py            # 6-digit code verification flow
│   │   │   └── sanitize.py               # bleach HTML stripping for user inputs
│   │   ├── models/                        # Module B3: SQLAlchemy models
│   │   │   ├── city.py
│   │   │   ├── region.py
│   │   │   ├── podcast.py
│   │   │   ├── tourist_path.py
│   │   │   ├── ad_request.py
│   │   │   ├── ad_audio_version.py
│   │   │   ├── ad_approval.py
│   │   │   └── ad_placement.py
│   │   ├── routers/                       # Module B4: API endpoints
│   │   │   ├── cities.py
│   │   │   ├── regions.py
│   │   │   ├── podcasts.py
│   │   │   ├── paths.py
│   │   │   └── ads.py
│   │   ├── services/                      # Module B5: Business logic
│   │   │   ├── broadcast.py               # Serve region podcasts (signed URLs)
│   │   │   ├── nearby.py                  # Find regions near coords
│   │   │   └── ad_targeting.py            # Match ads to regions
│   │   └── analytics/                     # Module B6: Event ingestion
│   │       └── events.py
│   └── tests/
│       ├── test_cities.py
│       ├── test_regions.py
│       ├── test_podcasts.py
│       ├── test_nearby.py
│       ├── test_ads.py
│       └── test_rate_limiter.py
│
└── studio/
    ├── pyproject.toml
    ├── Dockerfile                         # For portal deployment
    │
    ├── pipeline/                          # Runs locally on your Mac
    │   ├── run.py                         # Module S1: CLI entrypoint (generate city)
    │   ├── region_splitter.py             # Module S2: Divide city into grid
    │   ├── poi_fetcher.py                 # Module S3: Pull OSM data per region
    │   ├── script_generator.py            # Module S4: Ollama/Mistral podcast script
    │   ├── tts_synthesizer.py             # Module S5: Piper TTS → audio
    │   ├── audio_compressor.py            # Module S6: FFmpeg → opus
    │   ├── uploader.py                    # Module S7: Upload to S3 storage + DB
    │   └── path_generator.py              # Module S8: Generate tourist paths
    │
    ├── ad_pipeline/                       # Ad voice generation (runs locally)
    │   ├── ad_text_polisher.py            # Module S9: Ollama polishes business text
    │   ├── ad_tts.py                      # Module S10: Piper TTS for ad audio
    │   └── ad_emailer.py                  # Module S11: Send approval email to business
    │
    ├── portal/                            # Internal admin web UI (deployed to cloud)
    │   ├── app.py                         # Module S12: FastAPI portal app
    │   ├── templates/                     # Jinja2 HTML templates
    │   │   ├── layout.html
    │   │   ├── dashboard.html             # Module S13: Overview dashboard
    │   │   ├── cities.html                # Module S14: City + region map view
    │   │   ├── podcasts.html              # Module S15: Browse/preview/edit podcasts
    │   │   ├── ad_requests.html           # Module S16: Ad request queue
    │   │   ├── ad_detail.html             # Module S17: Single ad — preview + actions
    │   │   └── ad_approval_email.html     # Email template sent to businesses
    │   └── static/
    │       └── portal.css
    │
    └── tests/
        ├── test_region_splitter.py
        ├── test_poi_fetcher.py
        ├── test_script_generator.py
        ├── test_tts_synthesizer.py
        ├── test_audio_compressor.py
        ├── test_ad_text_polisher.py
        └── test_ad_emailer.py
```

---

## Module Quick Reference

Use these tags to request specific modules (e.g., "build B4", "build S4"):

| Tag | Module | Location | Runs On |
|-----|--------|----------|---------|
| M1 | API Client | `frontend/mobile/src/api/client.ts` | Device |
| M2 | Map | `frontend/mobile/src/components/Map.tsx` | Device |
| M3 | AudioPlayer | `frontend/mobile/src/components/AudioPlayer.tsx` | Device |
| M4 | CitySelector | `frontend/mobile/src/components/CitySelector.tsx` | Device |
| M5 | PathView | `frontend/mobile/src/components/PathView.tsx` | Device |
| M6 | AdBanner | `frontend/mobile/src/components/AdBanner.tsx` | Device |
| M7 | useGeolocation | `frontend/mobile/src/hooks/useGeolocation.ts` | Device |
| M8 | useRegionTracker | `frontend/mobile/src/hooks/useRegionTracker.ts` | Device |
| M9 | usePodcastBuffer | `frontend/mobile/src/hooks/usePodcastBuffer.ts` | Device |
| M10 | useAudioQueue | `frontend/mobile/src/hooks/useAudioQueue.ts` | Device |
| W1 | Landing Page | `frontend/web/src/pages/Home.tsx` | Cloud |
| W2 | City Browser | `frontend/web/src/pages/CityBrowser.tsx` | Cloud |
| W3 | Web Player | `frontend/web/src/pages/WebPlayer.tsx` | Cloud |
| W4 | Ad Portal | `frontend/web/src/pages/AdPortal.tsx` | Cloud |
| B1 | App + Config | `backend/app/main.py` | Cloud |
| B2 | Database | `backend/app/database.py` | Cloud |
| B3 | Models | `backend/app/models/` | Cloud |
| B4 | Routers | `backend/app/routers/` | Cloud |
| B5 | Services | `backend/app/services/` | Cloud |
| B6 | Analytics | `backend/app/analytics/events.py` | Cloud |
| B7 | Middleware | `backend/app/middleware/` | Cloud |
| B8 | Security | `backend/app/security/` | Cloud |
| S1 | CLI Entry | `studio/pipeline/run.py` | Mac |
| S2 | Region Splitter | `studio/pipeline/region_splitter.py` | Mac |
| S3 | POI Fetcher | `studio/pipeline/poi_fetcher.py` | Mac |
| S4 | Script Generator | `studio/pipeline/script_generator.py` | Mac |
| S5 | TTS Synthesizer | `studio/pipeline/tts_synthesizer.py` | Mac |
| S6 | Audio Compressor | `studio/pipeline/audio_compressor.py` | Mac |
| S7 | Uploader | `studio/pipeline/uploader.py` | Mac |
| S8 | Path Generator | `studio/pipeline/path_generator.py` | Mac |
| S9 | Ad Text Polisher | `studio/ad_pipeline/ad_text_polisher.py` | Mac |
| S10 | Ad TTS | `studio/ad_pipeline/ad_tts.py` | Mac |
| S11 | Ad Emailer | `studio/ad_pipeline/ad_emailer.py` | Mac |
| S12 | Portal App | `studio/portal/app.py` | Cloud |
| S13–S17 | Portal Templates | `studio/portal/templates/` | Cloud |

---

## Build Order — Phase by Phase

### Phase 0: Dev Environment Setup (Days 1–2)

#### Step 0.1 — Unified Dev Environment (Docker Compose + VS Code Dev Container)
- [ ] `docker-compose.yml` — unified local dev: Postgres + backend + studio portal + website (all services hot-reload)
- [ ] `.devcontainer/devcontainer.json` — VS Code Dev Container config (opens project inside Docker, all tools pre-installed)
- [ ] `.gitignore` (Python, Node, .env, audio files, __pycache__, node_modules)
- [ ] `.env.example` for all packages

> **Dev environment = one `docker compose up`** → Postgres, backend, studio portal, and website all running with hot-reload.
> Each service has its own Dockerfile (for later individual microservice deployment), but locally they all run together via docker-compose.
> Frontend mobile (Expo) runs on host Mac (needs device/simulator access).

#### Step 0.2 — Project Scaffolding
- [ ] Backend: `pyproject.toml`, FastAPI scaffold, DB connection, Alembic
- [ ] Frontend mobile: Expo scaffold (runs on host, not in Docker)
- [ ] Frontend web: Vite + React scaffold
- [ ] Studio: `pyproject.toml`, pipeline CLI scaffold, portal scaffold

#### Step 0.3 — Local AI Tools (on your Mac)
- [ ] Install Ollama + pull Mistral model
- [ ] Install Piper TTS + download voice model
- [ ] Install FFmpeg

### Phase 1: Frontend Mobile — Module by Module (Week 1)
- [ ] **M1 — API Client**: typed fetch wrapper for all backend endpoints
- [ ] **M2 — Map**: MapLibre + OpenFreeMap, region grid overlay, city center focus
- [ ] **M3 — AudioPlayer**: wraps Expo AV, play/pause/skip, progress bar
- [ ] **M4 — CitySelector**: pick a city, load its region grid
- [ ] **M7 — useGeolocation**: high-accuracy GPS polling (every 5s)
- [ ] **M8 — useRegionTracker**: determine which region the user is in (local math, no API)
- [ ] **M9 — usePodcastBuffer**: pre-download next ~5 regions' audio files
- [ ] **M10 — useAudioQueue**: sequence playback: region podcast → ad → next
- [ ] **M5 — PathView**: show suggested tourist path on map, follow it
- [ ] **M6 — AdBanner**: clickable ad link at bottom of screen

### Phase 2: Frontend Web — Module by Module (Week 2)
- [ ] **W1 — Landing page**: hero, app download links, city showcase
- [ ] **W2 — City browser**: browse cities, see regions on MapLibre map
- [ ] **W3 — Web player**: listen to city podcasts in browser
- [ ] **W4 — Ad portal**: businesses register, select city/region, submit ad text, pay (CAPTCHA + email verification)

### Phase 3: Backend — Module by Module (Week 2–3)
- [ ] **B1 — App + config**: FastAPI app factory, pydantic-settings
- [ ] **B2 — Database**: async SQLAlchemy engine, session factory
- [ ] **B3 — Models**: all SQLAlchemy models + Alembic migrations
- [ ] **B4 — Routers**: all REST endpoints (cities, regions, podcasts, paths, ads)
- [ ] **B5 — Services**: broadcast logic (signed audio URLs), nearby region lookup (Haversine), ad targeting
- [ ] **B6 — Analytics**: event ingestion endpoint, anonymized storage
- [ ] **B7 — Security middleware**: rate limiting, CORS, input validation, signed URLs

### Phase 4: Studio — Module by Module (Week 3–4)

#### Content Pipeline (runs on your Mac)
- [ ] **S1 — CLI entrypoint**: `python run.py --city "Paris" --radius 3 --lang en,fr,tr`
- [ ] **S2 — Region splitter**: take city center + radius → generate grid of regions
- [ ] **S3 — POI fetcher**: query Overpass API for each region's landmarks
- [ ] **S4 — Script generator**: feed POI data to Ollama/Mistral → podcast script
- [ ] **S5 — TTS synthesizer**: Piper TTS → WAV audio from script
- [ ] **S6 — Audio compressor**: FFmpeg WAV → opus (small, efficient)
- [ ] **S7 — Uploader**: upload compressed audio to S3 storage + write DB records
- [ ] **S8 — Path generator**: analyze regions + POIs → suggest tourist walking paths

#### Ad Pipeline (runs on your Mac)
- [ ] **S9 — Ad text polisher**: Ollama cleans up business ad text into broadcast-ready script
- [ ] **S10 — Ad TTS**: Piper TTS → generate voice ad audio
- [ ] **S11 — Ad emailer**: send approval email with audio preview (signed URL) + accept/reject links

#### Internal Portal (deployed to cloud)
- [ ] **S12 — Portal app**: FastAPI + Jinja2 scaffold, auth (password + IP allowlist)
- [ ] **S13 — Dashboard**: overview stats (cities, regions, podcasts, pending ads)
- [ ] **S14 — City/region map view**: browse cities, see region grid on MapLibre, click regions
- [ ] **S15 — Podcast manager**: list/preview/edit/regenerate podcasts per region
- [ ] **S16 — Ad request queue**: list all ad requests with status filters (new/generated/sent/accepted/rejected)
- [ ] **S17 — Ad detail view**: preview audio, see target on map, edit text, regenerate, send approval email

### Phase 5: Security Hardening (Week 4)
- [ ] **`slowapi` rate limiter**: install, configure per-endpoint limits (60/min reads, 10/min writes, 6/min analytics)
- [ ] **hCaptcha**: add widget to ad portal form (frontend), verify token server-side (backend)
- [ ] **Email verification flow**: 6-digit code sent to business email before ad request is created
- [ ] **`itsdangerous` signed URLs**: all audio file URLs expire after 24h, prevent hotlinking
- [ ] **CORS middleware**: whitelist only your app + website domains in `CORSMiddleware`
- [ ] **`bleach` input sanitization**: strip HTML/script tags from all user-submitted text via Pydantic validators
- [ ] **Portal auth**: password + IP allowlist on studio portal
- [ ] **Docker hardening**: `python:3.12-slim` base image, non-root user in Dockerfile
- [ ] **CI security**: add `pip audit` + `npm audit` steps to GitHub Actions workflow
- [ ] **Spending alerts**: configure max budget / alert on cloud provider
- [ ] **Optional: Cloudflare free tier**: DNS proxy for DDoS protection + CDN caching for audio files

### Phase 6: Integration + Polish (Week 4–5)
- [ ] Wire frontend ↔ backend end-to-end
- [ ] Generate content for 3 seed cities (Paris, Istanbul, Barcelona)
- [ ] Ad flow end-to-end: business submits → studio generates → admin reviews → email sent → business accepts → ad live
- [ ] Error handling: no GPS, no network, missing audio
- [ ] Podcast prompt tuning: storytelling tone, not Wikipedia

### Phase 7: Deploy (Week 5)
- [ ] Choose serverless provider (credits-only, no credit card required)
- [ ] Dockerize backend + studio portal + website
- [ ] Deploy containers to chosen provider
- [ ] Set up Postgres (managed or containerized)
- [ ] Set up S3-compatible storage for audio
- [ ] Set spending alerts / limits
- [ ] Mobile → Expo EAS build (TestFlight + Android APK)
- [ ] Run studio pipeline on Mac → upload content to cloud

### Phase 8: Post-MVP (Future)
- [ ] ElevenLabs / OpenAI TTS upgrade for premium voice quality
- [ ] User accounts + favorites + history
- [ ] Offline mode: pre-cache entire city audio pack on Wi-Fi
- [ ] Payment integration (Stripe) for ad portal
- [ ] Multi-language auto-detection from device locale
- [ ] Studio analytics dashboard: playback heatmaps, revenue tracking
- [ ] Real-time podcast generation for custom user routes (on-demand, uses cloud LLM)

---

## Environment Variables

```
# backend/.env
DATABASE_URL=postgresql+asyncpg://citycast:citycast@localhost:5432/citycast
S3_ACCESS_KEY_ID=...
S3_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=citycast-audio
S3_ENDPOINT_URL=...
S3_SIGNING_SECRET=...            # For signed audio URLs
ALLOWED_ORIGINS=http://localhost:5173,http://localhost:19006

# studio/.env
DATABASE_URL=postgresql+asyncpg://citycast:citycast@localhost:5432/citycast
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=mistral
PIPER_MODEL_PATH=./models/en_US-lessac-medium.onnx
S3_ACCESS_KEY_ID=...
S3_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=citycast-audio
S3_ENDPOINT_URL=...
PORTAL_PASSWORD=...
PORTAL_ALLOWED_IPS=127.0.0.1     # Comma-separated
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_USER=resend
SMTP_PASSWORD=re_...
EMAIL_FROM=studio@citycast.app

# frontend/mobile/.env
EXPO_PUBLIC_API_BASE_URL=http://localhost:8000

# frontend/web/.env
VITE_API_BASE_URL=http://localhost:8000
VITE_CAPTCHA_SITE_KEY=...
```

No Mapbox tokens needed — MapLibre + OpenFreeMap requires no API keys.

---

## Verification / Testing Strategy

- Every function has a co-located test (per CLAUDE.local.md)
- Backend: `pytest` + `httpx.AsyncClient`, mock external APIs
- Frontend: `Vitest` for hooks and pure logic
- Studio pipeline: `pytest`, mock Ollama and Piper calls, verify audio pipeline output
- Studio portal: `pytest` + `httpx`, test each page renders + ad status transitions
- Ad workflow: test full state machine (new → generated → sent → accepted → placement created)
- Security: test rate limiter blocks excess requests, test signed URL expiration, test CORS rejects unknown origins
- Integration: Docker Compose brings up real Postgres
- E2E smoke test: seed Paris → generate 3 region podcasts → hit `/regions/nearby?lat=48.858&lon=2.294` → verify audio URL works
