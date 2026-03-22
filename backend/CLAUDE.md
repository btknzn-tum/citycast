# CLAUDE.md — Backend

## Overview
FastAPI broadcast service for citycast. Serves maps, regions, podcasts, and ads via REST API.

## Tech Stack
- Python 3.12, FastAPI, SQLAlchemy (async), Alembic, asyncpg, boto3
- PostgreSQL 16 for persistence
- S3-compatible storage for audio files

## Commands
- **Run**: `uvicorn app.main:app --reload --port 8000`
- **Test**: `pytest --tb=short`
- **Migrate**: `alembic upgrade head`
- **Docker**: `docker compose up`

## Code Rules
- Every new function must have a local test written alongside it
- Keep solutions simple and minimal — avoid over-engineering
- Rate limiting on all public API endpoints
- Signed/expiring URLs for audio files
- Never store raw GPS trails — only anonymized region-level analytics (GDPR/KVKK)

## Project Structure
```
backend/
├── app/           # FastAPI application
├── alembic/       # Database migrations
├── tests/         # pytest + httpx tests
├── Dockerfile
├── pyproject.toml
└── .env.example
```
