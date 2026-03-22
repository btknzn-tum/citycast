#!/usr/bin/env bash

set -euo pipefail

find_code_cli() {
  for candidate in code code-insiders codium; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      echo "${candidate}"
      return 0
    fi
  done

  for candidate in \
    /vscode/vscode-server/bin/*/bin/code \
    "${HOME}/.vscode-server/bin"/*/bin/code \
    "${HOME}/.cursor-server/bin"/*/bin/code
  do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  return 1
}

install_vscode_extension() {
  local code_cli="$1"
  local extension_id="$2"

  if "${code_cli}" --list-extensions | grep -qx "${extension_id}"; then
    echo "Extension already installed: ${extension_id}"
    return 0
  fi

  echo "Installing extension: ${extension_id}"
  "${code_cli}" --install-extension "${extension_id}" --force
}

main() {
  local code_cli
  if ! code_cli="$(find_code_cli)"; then
    echo "VS Code CLI not found in container; skipping extension install."
    return 0
  fi

  install_vscode_extension "${code_cli}" "anthropic.claude-code"
  install_vscode_extension "${code_cli}" "openai.chatgpt"
}

main "$@"
