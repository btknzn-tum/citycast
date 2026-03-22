# CLAUDE.md — Studio Pipeline

## Overview
Content generation pipeline for citycast. Generates podcast scripts with local LLM (Ollama/Mistral), converts to speech with Piper TTS, and processes audio with FFmpeg.

## Tech Stack
- Python 3.12
- Ollama + Mistral (local LLM, Apache 2.0)
- Piper TTS (MIT — check individual voice model licenses, never use NC voices)
- FFmpeg (audio processing)

## Commands
- **Run**: `python -m pipeline.main`
- **Test**: `pytest --tb=short`

## Environment
- Runs **strictly on local Mac** — has access to Ollama, Piper TTS, FFmpeg binaries
- Never assume these binaries exist in cloud
- Ollama typically at `http://localhost:11434`

## Code Rules
- Every new function must have a local test written alongside it
- Keep solutions simple and minimal — avoid over-engineering
- Generate original podcast scripts only — no copying copyrighted tour content
- Sponsored audio must be clearly labeled as ads (FTC/EU transparency)
- Store ad approval paper trail (timestamp + exact audio version accepted)

## Legal
- Ollama/Mistral (Apache 2.0) — fully free for commercial use
- Piper TTS (MIT) — check individual voice model licenses
- Never use NC (non-commercial) voices

## Project Structure
```
studio/pipeline/
├── pipeline/      # Generation scripts
├── tests/         # pytest tests
└── .env.example
```
