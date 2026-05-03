#!/usr/bin/env bash
set -euo pipefail

# Usage: setup_codex.sh [-y] <base_url> <api_key> [model]
YES=0
if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
    YES=1
    shift
fi

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [-y] <base_url> <api_key> [model]"
    echo "  -y        - Skip confirmation prompts"
    echo "  base_url  - The OpenAI-compatible API base URL"
    echo "  api_key   - The API key"
    echo "  model     - Model name (default: gpt-5.5)"
    exit 1
fi

BASE_URL="$1"
API_KEY="$2"
MODEL="${3:-gpt-5.5}"

CODEX_DIR="$HOME/.codex"
CODEX_WAS_INSTALLED=0

# ---------------------------------------------------------------------------
# Install codex if not present
# ---------------------------------------------------------------------------

install_codex() {
    echo "Installing @openai/codex via npm..."
    npm i -g @openai/codex
}

prompt_yes_no() {
    local prompt="$1"
    local answer=""

    if [[ "$YES" -eq 1 ]]; then
        return 0
    fi

    # stdin may be a pipe (curl|bash), so read from the terminal directly.
    if [[ -r /dev/tty ]]; then
        read -r -p "$prompt" answer </dev/tty
    else
        echo "No terminal available for confirmation." >&2
        return 1
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}

backup_codex_dir() {
    local backup_dir="${CODEX_DIR}-backup-$(date '+%Y%m%d%H%M%S')"
    local index=1

    while [[ -e "$backup_dir" ]]; do
        backup_dir="${CODEX_DIR}-backup-$(date '+%Y%m%d%H%M%S')-$index"
        index=$((index + 1))
    done

    echo "Backing up existing $CODEX_DIR to $backup_dir"
    mv "$CODEX_DIR" "$backup_dir"
}

load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
}

ensure_node() {
    if ! command -v node &>/dev/null; then
        echo "Installing Node.js 24 via nvm..."
        nvm install 24
    fi
    nvm use 24
}

install_nvm_and_node() {
    echo "npm not found. Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    # Load nvm directly — do NOT source .zshrc/.bashrc since they may reference
    # undefined variables that cause bash to exit when set -u is active.
    load_nvm
    ensure_node
    install_codex
}

if ! command -v codex &>/dev/null; then
    echo "codex is not installed."
    if command -v npm &>/dev/null; then
        install_codex
    elif [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
        echo "nvm found but npm not active. Loading nvm..."
        load_nvm
        ensure_node
        install_codex
    else
        install_nvm_and_node
    fi
else
    CODEX_WAS_INSTALLED=1
    echo "codex is already installed: $(command -v codex)"
fi

# ---------------------------------------------------------------------------
# Confirm config overwrite if .codex already exists
# ---------------------------------------------------------------------------

if [[ -d "$CODEX_DIR" ]]; then
    if [[ "$CODEX_WAS_INSTALLED" -eq 1 ]]; then
        echo "Existing codex config detected at $CODEX_DIR."
    else
        echo "Existing $CODEX_DIR detected."
    fi

    if ! prompt_yes_no "Overwrite existing codex config with this setup? A backup will be created first. [y/N] "; then
        echo "Aborted. Existing config left unchanged."
        exit 0
    fi

    backup_codex_dir
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
model_reasoning_effort = "high"
disable_response_storage = true
preferred_auth_method = "apikey"
personality = "pragmatic"
approval_policy = "on-request"
sandbox_mode = "read-only"
suppress_unstable_features_warning = true
model_reasoning_summary = "detailed"

[model_providers.crs]
name = "crs"
base_url = "$BASE_URL"
wire_api = "responses"
requires_openai_auth = true

[features]
goals = true

[tui]
status_line = ["model-with-reasoning", "current-dir", "model", "project-name", "git-branch", "run-state", "context-remaining", "context-used", "five-hour-limit", "weekly-limit", "codex-version", "context-window-size", "used-tokens", "total-input-tokens", "total-output-tokens", "session-id", "fast-mode", "thread-title", "task-progress"]

[tui.model_availability_nux]
"gpt-5.5" = 2
EOF

echo "Written: $CODEX_DIR/config.toml"
echo "codex setup complete."
