# CLAUDE.md — Studio Portal

## Overview
Internal admin web UI for citycast. Manages content, reviews ad submissions, and monitors pipeline output. Deployed to serverless cloud.

## Tech Stack
- Python 3.12, FastAPI, Jinja2 (server-side templates)
- SQLAlchemy (async), asyncpg
- PostgreSQL 16

## Commands
- **Run**: `uvicorn portal.app:app --reload --port 8010`
- **Test**: `pytest --tb=short`
- **Docker**: `docker compose up`

## Code Rules
- Every new function must have a local test written alongside it
- Keep solutions simple and minimal — avoid over-engineering
- CAPTCHA + email verification on ad submissions
- Password-protected admin access (PORTAL_PASSWORD)
- IP allowlisting support (PORTAL_ALLOWED_IPS)
- Store ad approval paper trail (timestamp + exact audio version accepted)

## Project Structure
```
studio/portal/
├── portal/        # FastAPI app + Jinja2 templates
├── tests/         # pytest + httpx tests
├── Dockerfile
├── pyproject.toml
└── .env.example
```
