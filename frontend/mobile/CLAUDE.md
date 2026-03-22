# CLAUDE.md — Frontend Mobile

## Overview
React Native + Expo app for citycast. The main user-facing app — tourists wear headphones and walk while the app plays location-matched podcast segments.

## Tech Stack
- React Native, Expo
- MapLibre + OpenFreeMap
- Zustand (state management)

## Commands
- **Dev**: `npx expo start`
- **iOS**: `npx expo run:ios`
- **Android**: `npx expo run:android`
- **Test**: `npm run test`

## Environment
- Runs on **host Mac** — needs simulator/device access, NOT in Docker
- Requires Expo CLI installed globally

## Code Rules
- Every new function must have a local test written alongside it
- Keep solutions simple and minimal — avoid over-engineering
- Must show "© OpenStreetMap contributors" attribution on any map
- Never store raw GPS trails — only anonymized region-level analytics (GDPR/KVKK)
- App store submissions require privacy policy and location permission justification

## Project Structure
```
frontend/mobile/
├── src/           # React Native components and screens
├── assets/        # Images, fonts
├── app.json       # Expo config
├── package.json
└── .env.example
```
