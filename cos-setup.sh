#!/usr/bin/env bash
# Chief of Staff for Carbon Voice — setup
#
#   curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh | bash
#
# Shows what it will install and why, waits for your OK, then installs what's missing,
# installs the Carbon Voice plugins, creates your agent's folder, and starts Claude to finish.
# Safe to run again: anything already installed is left alone.
set -euo pipefail

MARKETPLACE="PhononX/claude-plugins"
BIN="$HOME/.local/bin"
NODE_HOME="$HOME/.local/node"
JQ_VERSION="1.7.1"
NODE_MAJOR_MIN=18

# ---------- helpers ----------
bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; reset=$'\033[0m'
step() { printf '\n%s▸ %s%s\n' "$bold" "$1" "$reset"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$1"; }
info() { printf '  %s%s%s\n' "$dim" "$1" "$reset"; }
die()  { printf '\n%s✗ %s%s\n' "$red" "$1" "$reset" >&2; exit 1; }
# When piped from curl, stdin is this script, so questions read from the terminal.
ask()  { local reply; read -r -p "$1 " reply </dev/tty || true; printf '%s' "$reply"; }
yes()  { case "$(ask "$1")" in [nN]*) return 1 ;; *) return 0 ;; esac; }          # default yes
no()   { case "$(ask "$1")" in [yY]*) return 1 ;; *) return 0 ;; esac; }           # default no
have() { command -v "$1" >/dev/null 2>&1; }
sha256() { if have shasum; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }

# ---------- platform ----------
OS=$(uname -s); ARCH=$(uname -m)
case "$OS" in
  Darwin) PLATFORM=mac ;;
  Linux)  PLATFORM=linux ;;
  *) die "This setup supports macOS and Linux. On Windows, use WSL." ;;
esac
case "$ARCH" in
  arm64|aarch64) ARCH_NODE=arm64; ARCH_JQ=arm64 ;;
  x86_64|amd64)  ARCH_NODE=x64;   ARCH_JQ=amd64 ;;
  *) die "Unsupported processor: $ARCH" ;;
esac
mkdir -p "$BIN"
export PATH="$BIN:$PATH"

# ---------- look before touching anything ----------
node_ok() { have node && [[ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge $NODE_MAJOR_MIN ]]; }
have claude && S_CLAUDE=update || S_CLAUDE=install
have jq     && S_JQ=have       || S_JQ=install
node_ok     && S_NODE=have     || S_NODE=install
if have tmux; then S_TMUX=have
elif have brew || [[ "$PLATFORM" == linux ]]; then S_TMUX=install
else S_TMUX=needs-brew; fi

# Signed in to a Claude account? (`claude auth status` exits 0 when signed in.)
if have claude && claude auth status >/dev/null 2>&1; then S_AUTH=have; else S_AUTH=signin; fi

label() {  # status → coloured label
  case "$1" in
    have)       printf '%salready installed%s' "$green" "$reset" ;;
    update)     printf '%sinstalled — will check for updates%s' "$green" "$reset" ;;
    install)    printf '%swill install%s' "$yellow" "$reset" ;;
    create)     printf '%swill create%s' "$yellow" "$reset" ;;
    signin)     printf '%swill open your browser to sign in%s' "$yellow" "$reset" ;;
    needs-brew) printf '%soptional — needs Homebrew (asked next)%s' "$yellow" "$reset" ;;
  esac
}
where() { have brew && echo "with Homebrew" || echo "into ~/.local (no password needed)"; }

clear 2>/dev/null || true
printf '%sChief of Staff for Carbon Voice — setup%s\n\n' "$bold" "$reset"
echo "This sets up a chief of staff you talk to through Carbon Voice."
echo "Here's what will happen on this computer:"
echo
printf '  %sClaude Code%s — %s\n'  "$bold" "$reset" "$(label $S_CLAUDE)"
info "  The AI agent itself. Your chief of staff runs inside it."
printf '  %sSign in to Claude%s — %s\n' "$bold" "$reset" "$(label $S_AUTH | sed 's/already installed/already signed in/')"
info "  Uses your Claude Pro, Max, Team or Enterprise plan."
printf '  %sNode.js%s — %s\n'      "$bold" "$reset" "$(label $S_NODE)"
info "  Runs the connection between Carbon Voice and Claude.$([ $S_NODE = install ] && echo " Installed $(where).")"
printf '  %sjq%s — %s\n'           "$bold" "$reset" "$(label $S_JQ)"
info "  A small tool your agent uses to manage its memory.$([ $S_JQ = install ] && echo " Installed $(where).")"
printf '  %stmux%s — %s\n'         "$bold" "$reset" "$(label $S_TMUX)"
info "  Lets your agent keep running after you close the Terminal window."
printf '  %sCarbon Voice plugins%s — %s\n' "$bold" "$reset" "$(label install)"
info "  The Carbon Voice connection, plus the chief-of-staff skills and memory."
printf '  %sA folder for your agent%s — %s\n' "$bold" "$reset" "$(label create)"
info "  In your home folder. Your agent's notes are plain text files you can open anytime."
echo
info "Then Claude starts and asks a few short questions to finish."
echo
yes "Continue? [Y/n]" || { echo "No changes made."; exit 0; }

# ---------- optional Homebrew (only asked when it would add something) ----------
if [[ $S_TMUX == needs-brew ]]; then
  echo
  echo "tmux comes from Homebrew, the standard tool for installing software on a Mac."
  echo "Installing Homebrew asks for your Mac password and can take several minutes."
  echo "Without it, everything still works; your agent just runs while its Terminal window is open."
  if ! no "Install Homebrew and tmux? [y/N]"; then
    step "Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $b ]] && eval "$($b shellenv)" && break; done
    have brew && ok "Installed" && S_TMUX=install || { info "Homebrew didn't install; skipping tmux."; S_TMUX=skip; }
  else
    S_TMUX=skip
  fi
fi

# ---------- Claude Code ----------
step "Claude Code"
if [[ $S_CLAUDE == update ]]; then
  claude update >/dev/null 2>&1 && ok "Up to date ($(claude --version 2>/dev/null | head -1))" \
    || info "Couldn't check for updates; continuing with $(claude --version 2>/dev/null | head -1)."
else
  curl -fsSL https://claude.ai/install.sh | bash
  have claude || die "Claude Code didn't install. Check your internet connection and run this again."
  ok "Installed"
fi

# ---------- jq ----------
step "jq"
if [[ $S_JQ == have ]]; then ok "Already installed"
elif have brew; then brew install jq >/dev/null && ok "Installed with Homebrew"
else
  JQ_ASSET="jq-$([ "$PLATFORM" = mac ] && echo macos || echo linux)-$ARCH_JQ"
  JQ_BASE="https://github.com/jqlang/jq/releases/download/jq-$JQ_VERSION"
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/jq" "$JQ_BASE/$JQ_ASSET"
  curl -fsSL -o "$TMP/sums" "$JQ_BASE/sha256sum.txt"
  EXPECTED=$(grep " $JQ_ASSET\$" "$TMP/sums" | cut -d' ' -f1)
  [[ -n "$EXPECTED" && "$(sha256 "$TMP/jq")" == "$EXPECTED" ]] || die "jq download failed its checksum. Run this again."
  install -m 755 "$TMP/jq" "$BIN/jq"; rm -rf "$TMP"
  ok "Installed to ~/.local/bin"
fi

# ---------- Claude sign-in ----------
step "Claude account"
auth_json() { claude auth status 2>/dev/null || true; }   # prints JSON; exit code 1 when signed out
if ! claude auth status >/dev/null 2>&1; then
  echo "  Your browser will open so you can sign in with your Claude account."
  echo "  If it doesn't open, copy the link shown below into your browser."
  claude auth login </dev/tty || true
  claude auth status >/dev/null 2>&1 || die "Not signed in. Run this setup again to retry."
fi
AUTH=$(auth_json)
METHOD=$(printf '%s' "$AUTH" | jq -r '.authMethod // empty' 2>/dev/null || true)
PLAN=$(printf '%s' "$AUTH" | jq -r '.subscriptionType // empty' 2>/dev/null || true)
EMAIL=$(printf '%s' "$AUTH" | jq -r '.email // empty' 2>/dev/null || true)
ok "Signed in${EMAIL:+ as $EMAIL}${PLAN:+ ($PLAN plan)}"
if [[ -n "$METHOD" && "$METHOD" != "claude.ai" ]]; then
  printf '  %s!%s This computer is signed in with an Anthropic API account, not a Claude plan.\n' "$yellow" "$reset"
  echo "    The Carbon Voice connection and the Claude app connection need a Claude plan sign-in."
  if yes "  Sign in with your Claude plan instead? [Y/n]"; then
    claude auth logout >/dev/null 2>&1 || true
    claude auth login </dev/tty || true
    claude auth status >/dev/null 2>&1 || die "Not signed in. Run this setup again to retry."
    ok "Signed in"
  fi
fi
[[ "$PLAN" == "free" ]] && die "Claude Code needs a paid Claude plan (Pro, Max, Team or Enterprise). Upgrade at claude.ai, then run this again."
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  info "Note: ANTHROPIC_API_KEY is set in your shell. Your agent's start script ignores it so it uses your Claude plan."
fi

# ---------- Node.js ----------
step "Node.js"
if [[ $S_NODE == have ]]; then ok "Already installed ($(node --version))"
elif have brew; then brew install node >/dev/null && ok "Installed with Homebrew"
else
  NODE_OS=$([ "$PLATFORM" = mac ] && echo darwin || echo linux)
  NODE_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r '[.[] | select(.lts != false)][0].version')
  [[ "$NODE_VERSION" == v* ]] || die "Couldn't find the current Node.js release. Run this again."
  NODE_PKG="node-$NODE_VERSION-$NODE_OS-$ARCH_NODE"
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/node.tar.gz" "https://nodejs.org/dist/$NODE_VERSION/$NODE_PKG.tar.gz"
  curl -fsSL -o "$TMP/sums" "https://nodejs.org/dist/$NODE_VERSION/SHASUMS256.txt"
  EXPECTED=$(grep " $NODE_PKG.tar.gz\$" "$TMP/sums" | cut -d' ' -f1)
  [[ -n "$EXPECTED" && "$(sha256 "$TMP/node.tar.gz")" == "$EXPECTED" ]] || die "Node.js download failed its checksum. Run this again."
  rm -rf "$NODE_HOME"; mkdir -p "$NODE_HOME"
  tar -xzf "$TMP/node.tar.gz" -C "$NODE_HOME" --strip-components=1; rm -rf "$TMP"
  for b in node npm npx; do ln -sf "$NODE_HOME/bin/$b" "$BIN/$b"; done
  node_ok || die "Node.js didn't install correctly."
  ok "Installed $NODE_VERSION to ~/.local/node"
fi

# ---------- tmux ----------
step "tmux"
case $S_TMUX in
  have) ok "Already installed" ;;
  skip) info "Skipped. You can add it later by running this setup again." ;;
  install)
    if have brew; then brew install tmux >/dev/null && ok "Installed with Homebrew"
    elif have apt-get; then info "Installing with apt (may ask for your password)..."; sudo apt-get install -y tmux >/dev/null </dev/tty && ok "Installed"
    elif have dnf; then info "Installing with dnf (may ask for your password)..."; sudo dnf install -y tmux >/dev/null </dev/tty && ok "Installed"
    else info "Couldn't find a package manager; skipped."; fi ;;
esac

# ---------- make sure new Terminal windows find everything ----------
RC=$([ "$PLATFORM" = mac ] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc")
grep -qs '.local/bin' "$RC" || printf '\n# Added by Chief of Staff setup\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC"

# ---------- plugins ----------
step "Carbon Voice plugins"
claude plugin marketplace add "$MARKETPLACE" >/dev/null 2>&1 \
  || claude plugin marketplace update carbonvoice >/dev/null 2>&1 || true
for p in cv-channel cos; do
  if claude plugin install "$p@carbonvoice" --scope user >/dev/null 2>&1 \
     || claude plugin install "$p@carbonvoice" >/dev/null 2>&1; then
    ok "$p"
  else
    die "Couldn't install the $p plugin. Run this again, or in Claude type: /plugin install $p@carbonvoice"
  fi
done

# ---------- workspace ----------
step "Your agent's folder"
info "Each agent gets its own folder. Use a different name for each agent you create."
NAME=$(ask "  Folder name [chief-of-staff]:")
NAME=${NAME:-chief-of-staff}; NAME=${NAME// /-}
DIR="$HOME/$NAME"
mkdir -p "$DIR"
ok "~/$NAME"

# ---------- hand off ----------
step "Everything's installed. Starting Claude to finish setup."
cat <<EOF
  ${dim}• Approve the prompt asking to trust this folder.
  • Then answer a few short questions.${reset}

EOF
ask "  Press Return to continue." >/dev/null
cd "$DIR"
exec claude "/cos:setup" </dev/tty
