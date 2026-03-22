# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

citycast is an AI-powered location-based app that turns walking through a city into a live, personalized podcast experience. Tourists wear headphones and walk — the app plays short, pre-generated podcast segments matched to their GPS location.

### Monorepo Structure

- `backend/` — FastAPI broadcast service (serves maps, regions, podcasts, ads)
- `frontend/mobile/` — React Native + Expo (iOS/Android app)
- `frontend/web/` — React + Vite (companion website + ad portal)
- `studio/pipeline/` — Content generation (Ollama + Piper TTS + FFmpeg, runs locally on Mac)
- `studio/portal/` — Internal admin web UI (deployed to serverless cloud)

### Tech Stack

- **Backend**: Python, FastAPI, PostgreSQL, SQLAlchemy, Alembic
- **Frontend**: React Native (Expo), React (Vite), MapLibre + OpenFreeMap, Zustand
- **Studio**: Python, Ollama/Mistral (local LLM), Piper TTS, FFmpeg, FastAPI + Jinja2 (portal)
- **Deployment**: Serverless cloud (credits-only, no credit card — provider TBD at deploy time)
- **Storage**: S3-compatible object storage (audio files), managed Postgres (database)
- **Testing**: pytest + httpx (backend/studio), Vitest (frontend)

### Security

- Rate limiting on all public API endpoints
- Signed/expiring URLs for audio files
- CAPTCHA + email verification on ad submissions
- Strict CORS policy, input sanitization
- Cloud spending limits/alerts to prevent cost attacks

## Legal Awareness

**Always stay away from possible legal problems and inform the user.**

- Use OpenStreetMap data (ODbL license) — must show "© OpenStreetMap contributors" attribution
- Never scrape Google Maps
- MapLibre (MIT) + OpenFreeMap — fully open, no restrictions
- Ollama/Mistral (Apache 2.0) — fully free for commercial use
- Piper TTS (MIT) — check individual voice model licenses, never use NC (non-commercial) voices
- Generate original podcast scripts only — no copying copyrighted tour content
- Never store raw GPS trails — only anonymized region-level analytics (GDPR/KVKK)
- Sponsored audio must be clearly labeled as ads (FTC/EU transparency)
- Store ad approval paper trail (timestamp + exact audio version accepted)
- App store submissions require privacy policy and location permission justification
- When in doubt about any legal concern, flag it to the user before proceeding

## Environment Boundaries

- **Studio Pipeline** (`studio/pipeline/`, `studio/ad_pipeline/`) runs **strictly on the local Mac** — has access to Ollama, Piper TTS, FFmpeg binaries. Never assume these exist in cloud.
- **Backend API** (`backend/`) runs in a **serverless cloud container** — only serves data/files, no heavy AI binaries.
- **Studio Portal** (`studio/portal/`) is deployed to **cloud** — lightweight FastAPI + Jinja2, no local binary dependencies.
- **Frontend Mobile** (`frontend/mobile/`) runs on **host Mac** via Expo (needs simulator/device access, not in Docker).
- **Frontend Web** (`frontend/web/`) runs in **Docker locally**, deployed as **static/serverless** in cloud.

## Code Rules

- Every new function must have a local test written alongside it
- Keep solutions simple and minimal — avoid over-engineering
- Prefer well-documented, popular libraries
