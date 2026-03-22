#!/usr/bin/env bash

set -euo pipefail

install_npm_cli() {
  local binary="$1"
  local package="$2"

  if command -v "$binary" >/dev/null 2>&1; then
    return
  fi

  echo "Installing ${package}..."
  npm install -g "$package"
}

install_npm_cli codex @openai/codex
install_npm_cli claude @anthropic-ai/claude-code

echo "citycast dev environment ready!"
