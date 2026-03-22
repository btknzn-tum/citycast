# CLAUDE.md — Frontend Web

## Overview
Companion website and ad portal for citycast. Built with React + Vite.

## Tech Stack
- React 19, Vite 6, Vitest 3
- Node 20

## Commands
- **Dev**: `npm run dev`
- **Build**: `npm run build`
- **Test**: `npm run test`
- **Docker**: `docker compose up`

## Code Rules
- Every new function must have a local test written alongside it
- Keep solutions simple and minimal — avoid over-engineering
- CAPTCHA + email verification on ad submissions
- Strict CORS policy, input sanitization
- Must show "© OpenStreetMap contributors" attribution on any map

## Project Structure
```
frontend/web/
├── src/           # React components and pages
├── public/        # Static assets
├── Dockerfile
├── package.json
└── .env.example
```
