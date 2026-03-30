#!/usr/bin/env bash
set -euo pipefail

# Usage: setup_codex.sh <base_url> <api_key> [model]
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <base_url> <api_key> [model]"
    echo "  base_url  - The OpenAI-compatible API base URL"
    echo "  api_key   - The API key"
    echo "  model     - Model name (default: gpt-5.4)"
    exit 1
fi

BASE_URL="$1"
API_KEY="$2"
MODEL="${3:-gpt-5.4}"

CODEX_DIR="$HOME/.codex"

# ---------------------------------------------------------------------------
# Install codex if not present
# ---------------------------------------------------------------------------

install_codex() {
    echo "Installing @openai/codex via npm..."
    npm i -g @openai/codex
}

install_nvm_and_node() {
    echo "npm not found. Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

    # Source the appropriate rc file
    if [[ -f "$HOME/.zshrc" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.zshrc" 2>/dev/null || true
    elif [[ -f "$HOME/.bashrc" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.bashrc" 2>/dev/null || true
    elif [[ -f "$HOME/.bash_profile" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/.bash_profile" 2>/dev/null || true
    fi

    # Also load nvm directly in case the rc sourcing didn't expose it
    export NVM_DIR="$HOME/.nvm"
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        # shellcheck disable=SC1091
        source "$NVM_DIR/nvm.sh"
    fi

    echo "Installing Node.js 24 via nvm..."
    nvm install 24
    nvm use 24

    install_codex
}

if ! command -v codex &>/dev/null; then
    echo "codex is not installed."
    if command -v npm &>/dev/null; then
        install_codex
    else
        install_nvm_and_node
    fi
else
    echo "codex is already installed: $(command -v codex)"
fi

# ---------------------------------------------------------------------------
# Backup existing .codex directory if it exists
# ---------------------------------------------------------------------------

if [[ -d "$CODEX_DIR" ]]; then
    BACKUP_DIR="${CODEX_DIR}-$(date '+%Y%m%d%H%M%S')"
    echo "Backing up existing $CODEX_DIR to $BACKUP_DIR"
    mv "$CODEX_DIR" "$BACKUP_DIR"
fi

mkdir -p "$CODEX_DIR"

# ---------------------------------------------------------------------------
# Write auth.json
# ---------------------------------------------------------------------------

cat > "$CODEX_DIR/auth.json" <<EOF
{
  "OPENAI_API_KEY": "$API_KEY"
}
EOF

echo "Written: $CODEX_DIR/auth.json"

# ---------------------------------------------------------------------------
# Write config.toml
# ---------------------------------------------------------------------------

cat > "$CODEX_DIR/config.toml" <<EOF
model_provider = "crs"
model = "$MODEL"
model_reasoning_effort = "medium"
disable_response_storage = true
preferred_auth_method = "apikey"
personality = "pragmatic"

[model_providers.crs]
name = "crs"
base_url = "$BASE_URL"
wire_api = "responses"
requires_openai_auth = true
EOF

echo "Written: $CODEX_DIR/config.toml"
echo "codex setup complete."
