#!/usr/bin/env bash
# bootstrap.sh — guided onboarding for a fresh Mac in the fleet.
#
# Lives in the public repo doafilms/homelab-strip-bootstrap so it can be
# fetched without auth. The actual app lives in the private repo
# doafilms/homelab-strip and is cloned via `gh repo clone` after the user
# authenticates with `gh auth login` in step 5. Bootstrap is useless without
# (a) being signed into the right Tailscale tailnet and (b) having access to
# the private repo via your GitHub account.
#
# Walks through every prerequisite. Auto-installs what it can (Xcode CLT,
# Homebrew, gh, Tailscale, Übersicht). Stops with clear instructions when
# human action is required. Re-runnable — pasting the same one-liner picks
# up where it left off.
#
# One-liner usage on a fresh Mac:
#   curl -fsSL https://raw.githubusercontent.com/doafilms/homelab-strip-bootstrap/main/bootstrap.sh | bash
#
# Pass install.sh flags through after `--`, e.g. for the heartbeat host:
#   curl -fsSL .../bootstrap.sh | bash -s -- --server

set -euo pipefail

REPO_NWO="${HOMELAB_STRIP_REPO:-doafilms/homelab-strip}"
REPO_DIR="${HOMELAB_STRIP_DIR:-$HOME/Server/projects/homelab-strip}"
RERUN_CMD="curl -fsSL https://raw.githubusercontent.com/doafilms/homelab-strip-bootstrap/main/bootstrap.sh | bash"

log()  { printf '\033[1;36m▶\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; }
todo() { printf '\033[1;35m  →\033[0m %s\n' "$*"; }
hr()   { printf '\033[2m─────────────────────────────────────────────────────\033[0m\n'; }

# stop_here "headline" "step 1" "step 2" ...
# Prints headline + numbered steps, then how to rerun, then exits 1.
stop_here() {
  echo
  hr
  err "$1"
  shift
  echo
  echo "Do this, then re-run:"
  for step in "$@"; do todo "$step"; done
  echo
  echo "Re-run command:"
  echo "  $RERUN_CMD"
  hr
  exit 1
}

echo
log "homelab-strip bootstrap"
log "repo  : $REPO_URL"
log "target: $REPO_DIR"
echo

# --- Step 1: Xcode Command Line Tools (provides git, python3) ---
log "[1/7] Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  log "triggering CLT install dialog"
  xcode-select --install >/dev/null 2>&1 || true
  stop_here "Xcode Command Line Tools not installed yet." \
    "A 'Command Line Developer Tools' dialog should have opened — click Install." \
    "Wait for the install to finish (a few minutes; downloads ~1GB)." \
    "If no dialog opened, run: xcode-select --install"
fi
ok "CLT present ($(xcode-select -p))"

# --- Step 2: Homebrew ---
log "[2/7] Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  log "installing Homebrew (will prompt for your sudo password)"
  if ! NONINTERACTIVE=1 /bin/bash -c \
       "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    stop_here "Homebrew install failed." \
      "Scroll up for the brew installer's error message." \
      "Most common cause: sudo password timed out — just rerun."
  fi
  # Add brew to PATH for the rest of this session
  if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
ok "brew present ($(brew --prefix))"

# --- Step 3: brew packages (gh, tailscale, ubersicht) ---
log "[3/7] brew packages"
brew list gh                >/dev/null 2>&1 || brew install gh
brew list --cask tailscale  >/dev/null 2>&1 || brew install --cask tailscale
brew list --cask ubersicht  >/dev/null 2>&1 || brew install --cask ubersicht
ok "gh, tailscale, ubersicht installed"

# --- Step 4: Tailscale signed in ---
log "[4/7] Tailscale"
if ! command -v tailscale >/dev/null 2>&1; then
  # The cask app provides a CLI shim, but only after the app has run once.
  open -a Tailscale 2>/dev/null || true
  stop_here "Tailscale CLI isn't on PATH yet." \
    "Open /Applications/Tailscale.app (just opened it for you)." \
    "Sign in to your tailnet via the menu-bar icon." \
    "Open a fresh Terminal so PATH picks up the 'tailscale' shim."
fi
if ! tailscale status >/dev/null 2>&1; then
  open -a Tailscale 2>/dev/null || true
  stop_here "Tailscale is installed but not signed in." \
    "Click the Tailscale icon in the menu bar → Log In." \
    "Approve this device in https://login.tailscale.com/admin/machines if prompted." \
    "Verify: tailscale status (should list this device)."
fi
# Verify the heartbeat host is reachable via MagicDNS
if ! tailscale ip macmini >/dev/null 2>&1; then
  stop_here "Tailscale is up, but 'macmini' doesn't resolve via MagicDNS." \
    "Check the homelab mini is on your tailnet: tailscale status | grep macmini" \
    "Make sure MagicDNS is enabled: https://login.tailscale.com/admin/dns"
fi
ok "Tailscale signed in; 'macmini' reachable"

# --- Step 5: GitHub auth ---
log "[5/7] GitHub auth"
if ! gh auth status >/dev/null 2>&1; then
  stop_here "GitHub CLI is not authenticated (needed so this Mac can push to defaults.json)." \
    "Run: gh auth login" \
    "Choose: GitHub.com → HTTPS → Yes (authenticate Git) → Login with web browser." \
    "Follow the prompts; gh will store credentials and configure git."
fi
gh auth setup-git >/dev/null 2>&1 || true
ok "GitHub auth present ($(gh auth status 2>&1 | awk -F'as ' '/Logged in to/{print $2; exit}'))"

# --- Step 6: clone or pull (private repo, via gh-authed creds) ---
log "[6/7] repo"
mkdir -p "$(dirname "$REPO_DIR")"
if [[ -d "$REPO_DIR/.git" ]]; then
  log "repo already at $REPO_DIR — pulling"
  git -C "$REPO_DIR" pull --ff-only --quiet
else
  log "cloning $REPO_NWO → $REPO_DIR"
  if ! gh repo clone "$REPO_NWO" "$REPO_DIR" -- --quiet; then
    stop_here "gh repo clone failed." \
      "Confirm your GitHub account has access to $REPO_NWO." \
      "Try the clone manually: gh repo clone $REPO_NWO $REPO_DIR"
  fi
fi
ok "repo ready at $REPO_DIR"

# --- Step 7: hand off to install.sh ---
log "[7/7] install"
cd "$REPO_DIR"
exec ./scripts/install.sh "$@"
