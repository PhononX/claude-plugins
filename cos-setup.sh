#!/usr/bin/env bash
# Chief of Staff for Carbon Voice — setup
#
#   curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh | bash
#
# Shows what it will install and why, waits for your OK, then installs what's missing,
# installs the Carbon Voice plugins, creates your agent's folder, and starts Claude to finish.
# Safe to run again: anything already installed is left alone.
#
# Everything runs inside main(), called on the last line, so bash has read the whole file
# before anything runs. Under `curl | bash` the script arrives on stdin, so a child command
# that reads stdin would otherwise swallow the rest of it. Child commands also get
# </dev/null (or </dev/tty when they need to ask you something) for the same reason.
set -euo pipefail

MARKETPLACE="PhononX/claude-plugins"
BIN="$HOME/.local/bin"
NODE_HOME="$HOME/.local/node"
LOG="$HOME/.local/state/cos-setup/install.log"
LOG_SHOWN="~/.local/state/cos-setup/install.log"
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
quiet() { "$@" </dev/null >>"$LOG" 2>&1; }   # run a command with its output in the log
brew_install() {
  info "Installing $1..."
  quiet brew install "$1" || die "Homebrew couldn't install $1. The details are in $LOG_SHOWN. Run this again to retry."
  ok "Installed with Homebrew"
}
node_ok() { have node && [[ "$(node -p 'process.versions.node.split(".")[0]' </dev/null 2>/dev/null || echo 0)" -ge $NODE_MAJOR_MIN ]]; }

# Signed in to a Claude account? `claude auth status` prints JSON ({"loggedIn": true,
# "authMethod": "claude.ai", "email": ..., "subscriptionType": ...}); go by loggedIn, and by
# its exit code (0 when signed in) only when jq isn't installed yet or the output isn't JSON.
# Leaves the output in AUTH_JSON.
signed_in() {
  local rc=0
  AUTH_JSON=$(claude auth status </dev/null 2>/dev/null) || rc=$?
  if have jq && printf '%s' "$AUTH_JSON" | jq empty >/dev/null 2>&1; then
    printf '%s' "$AUTH_JSON" | jq -e '.loggedIn == true' >/dev/null 2>&1
  else
    return $rc
  fi
}
auth_field() {  # auth_field <name>: a text field from AUTH_JSON, e.g. email, orgName
  local re="\"$1\": *\"([^\"]*)\""
  if have jq; then printf '%s' "$AUTH_JSON" | jq -r --arg k "$1" '.[$k] // empty' 2>/dev/null || true
  elif [[ $AUTH_JSON =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}
account_desc() {  # "Signed in as <email> — <orgName> (<plan> plan)", leaving out what's unknown
  local email org plan
  email=$(auth_field email); org=$(auth_field orgName); plan=$(auth_field subscriptionType)
  printf 'Signed in%s%s%s' "${email:+ as $email}" "${org:+ — $org}" "${plan:+ ($plan plan)}"
}

# Where the "carbonvoice" plugin marketplace comes from, as "<kind> <location>", e.g.
# "github PhononX/claude-plugins", "git https://github.com/...", "directory /Users/me/...".
# Prints nothing when it isn't added. Uses jq when it's installed; before that (first run on
# a Mac without jq) it falls back to pattern matching, which works because the entries are
# flat objects.
cv_marketplace() {
  have claude || return 0
  local json kind="" loc="" re
  local file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json"
  if json=$(claude plugin marketplace list --json </dev/null 2>/dev/null); then
    # [{"name": "carbonvoice", "source": "github", "repo": "PhononX/claude-plugins", ...}]
    if have jq; then
      printf '%s' "$json" | jq -r '.[] | select(.name == "carbonvoice") | "\(.source) \(.repo // .url // .path // "")"' 2>/dev/null || true
      return 0
    fi
    re='\{[^{}]*"name": *"carbonvoice"[^{}]*\}'
  elif [[ -f $file ]]; then
    # Older Claude Code without --json: read the file it records added marketplaces in.
    # {"carbonvoice": {"source": {"source": "github", "repo": "PhononX/claude-plugins"}, ...}}
    json=$(cat "$file")
    if have jq; then
      printf '%s' "$json" | jq -r '.carbonvoice.source // empty | "\(.source) \(.repo // .url // .path // "")"' 2>/dev/null || true
      return 0
    fi
    re='"carbonvoice": *\{ *"source": *\{[^{}]*\}'
  else
    return 0
  fi
  json=${json//$'\n'/ }
  [[ $json =~ $re ]] || return 0
  json=${BASH_REMATCH[0]#*\"carbonvoice\"}
  re='"source": *"([^"]*)"';             [[ $json =~ $re ]] && kind=${BASH_REMATCH[1]}
  re='"(repo|url|path)": *"([^"]*)"';    [[ $json =~ $re ]] && loc=${BASH_REMATCH[2]}
  echo "$kind $loc"
}

label() {  # status → coloured label
  case "$1" in
    have)       printf '%salready installed%s' "$green" "$reset" ;;
    update)     printf '%sinstalled — will check for updates%s' "$green" "$reset" ;;
    install)    printf '%swill install%s' "$yellow" "$reset" ;;
    create)     printf '%swill create%s' "$yellow" "$reset" ;;
    replace)    printf '%swill replace an older Carbon Voice plugin source%s' "$yellow" "$reset" ;;
    signedin)   printf '%s%s%s' "$green" "$2" "$reset" ;;
    signin)     printf '%swill open your browser to sign in%s' "$yellow" "$reset" ;;
    needs-brew) printf '%soptional — needs Homebrew (asked next)%s' "$yellow" "$reset" ;;
  esac
}
where() { have brew && echo "with Homebrew" || echo "into ~/.local (no password needed)"; }

main() {
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
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1

# ---------- look before touching anything ----------
have claude && S_CLAUDE=update || S_CLAUDE=install
have jq     && S_JQ=have       || S_JQ=install
node_ok     && S_NODE=have     || S_NODE=install
if have tmux; then S_TMUX=have
elif have brew || [[ "$PLATFORM" == linux ]]; then S_TMUX=install
else S_TMUX=needs-brew; fi

# Signed in? Show which account and organization, so a computer signed in to the wrong one is
# easy to spot.
AUTH_DESC=""
if have claude && signed_in; then S_AUTH=signedin; AUTH_DESC=$(account_desc); else S_AUTH=signin; fi

# Is a "carbonvoice" plugin marketplace already added, and from where? Claude Code allows only
# one marketplace per name, and early setups added it from PhononX/cv-claude-channels or a
# local folder. That catalog has no cos plugin, so it has to be replaced with this one.
CV_SOURCE=$(cv_marketplace)
case "$(printf '%s' "$CV_SOURCE" | tr '[:upper:]' '[:lower:]')" in
  "") S_MKT=add ;;
  "github phononx/claude-plugins" \
  | "git "*"github.com/phononx/claude-plugins" | "git "*"github.com/phononx/claude-plugins.git" \
  | "git "*"github.com:phononx/claude-plugins" | "git "*"github.com:phononx/claude-plugins.git") S_MKT=update ;;
  *) S_MKT=replace ;;
esac

clear 2>/dev/null || true
printf '%sChief of Staff for Carbon Voice — setup%s\n\n' "$bold" "$reset"
echo "This sets up a chief of staff you talk to through Carbon Voice."
echo "Here's what will happen on this computer:"
echo
printf '  %sClaude Code%s — %s\n'  "$bold" "$reset" "$(label $S_CLAUDE)"
info "  The AI agent itself. Your chief of staff runs inside it."
printf '  %sSign in to Claude%s — %s\n' "$bold" "$reset" "$(label $S_AUTH "$AUTH_DESC")"
info "  Uses your Claude Pro, Max, Team or Enterprise plan."
printf '  %sNode.js%s — %s\n'      "$bold" "$reset" "$(label $S_NODE)"
info "  Runs the connection between Carbon Voice and Claude.$([ $S_NODE = install ] && echo " Installed $(where).")"
printf '  %sjq%s — %s\n'           "$bold" "$reset" "$(label $S_JQ)"
info "  A small tool your agent uses to manage its memory.$([ $S_JQ = install ] && echo " Installed $(where).")"
printf '  %stmux%s — %s\n'         "$bold" "$reset" "$(label $S_TMUX)"
info "  Lets your agent keep running after you close the Terminal window."
printf '  %sCarbon Voice plugins%s — %s\n' "$bold" "$reset" "$(label $([ $S_MKT = replace ] && echo replace || echo install))"
info "  The Carbon Voice connection, plus the chief-of-staff skills and memory."
if [[ $S_MKT == replace ]]; then info "  The Carbon Voice plugins now come from $MARKETPLACE."; fi
printf '  %sA folder for your agent%s — %s\n' "$bold" "$reset" "$(label create)"
info "  In your home folder. Your agent's notes are plain text files you can open anytime."
echo
info "Then Claude starts and asks a few short questions to finish."
echo
yes "Continue? [Y/n]" || { echo "No changes made."; exit 0; }

mkdir -p "${LOG%/*}"
printf '\n=== cos-setup %s ===\n' "$(date)" >>"$LOG"

# ---------- which Claude account ----------
# One email can belong to several Claude organizations (say, personal and work), and Claude
# Code is signed in to one at a time, so check it's the one the agent should use.
if [[ $S_AUTH == signedin ]] && ! yes "Use this account for your agent? [Y/n]"; then
  step "Claude account"
  echo "  You'll be signed out, then your browser opens so you can sign in again."
  echo "  If your email belongs to more than one Claude organization, choose the one for your agent there."
  claude auth logout </dev/tty >/dev/null 2>&1 || true
  claude auth login </dev/tty || true
  signed_in || die "Not signed in. Run this setup again to retry."
  ok "$(account_desc)"
fi

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
  claude update </dev/null >/dev/null 2>&1 && ok "Up to date ($(claude --version </dev/null 2>/dev/null | head -1))" \
    || info "Couldn't check for updates; continuing with $(claude --version </dev/null 2>/dev/null | head -1)."
else
  bash -c "$(curl -fsSL https://claude.ai/install.sh)" </dev/null \
    || die "Claude Code didn't install. Check your internet connection and run this again."
  have claude || die "Claude Code didn't install. Check your internet connection and run this again."
  ok "Installed"
fi

# ---------- jq ----------
step "jq"
if [[ $S_JQ == have ]]; then ok "Already installed"
elif have brew; then brew_install jq
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
if ! signed_in; then
  echo "  Your browser will open so you can sign in with your Claude account."
  echo "  If it doesn't open, copy the link shown below into your browser."
  claude auth login </dev/tty || true
  signed_in || die "Not signed in. Run this setup again to retry."
fi
ok "$(account_desc)"
METHOD=$(auth_field authMethod)
if [[ -n "$METHOD" && "$METHOD" != "claude.ai" ]]; then
  printf '  %s!%s This computer is signed in with an Anthropic API account, not a Claude plan.\n' "$yellow" "$reset"
  echo "    The Carbon Voice connection and the Claude app connection need a Claude plan sign-in."
  if yes "  Sign in with your Claude plan instead? [Y/n]"; then
    claude auth logout </dev/null >/dev/null 2>&1 || true
    claude auth login </dev/tty || true
    signed_in || die "Not signed in. Run this setup again to retry."
    ok "$(account_desc)"
  fi
fi
ORG=$(auth_field orgName); PLAN=$(auth_field subscriptionType)   # the account the agent will use
[[ "$PLAN" == "free" ]] && die "Claude Code needs a paid Claude plan (Pro, Max, Team or Enterprise). Upgrade at claude.ai, then run this again."
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  info "Note: ANTHROPIC_API_KEY is set in your shell. Your agent's start script ignores it so it uses your Claude plan."
fi

# ---------- Node.js ----------
step "Node.js"
if [[ $S_NODE == have ]]; then ok "Already installed ($(node --version))"
elif have brew; then brew_install node
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
    if have brew; then brew_install tmux
    elif have apt-get; then info "Installing with apt (may ask for your password)..."; sudo apt-get install -y tmux >/dev/null </dev/tty && ok "Installed"
    elif have dnf; then info "Installing with dnf (may ask for your password)..."; sudo dnf install -y tmux >/dev/null </dev/tty && ok "Installed"
    else info "Couldn't find a package manager; skipped."; fi ;;
esac

# ---------- make sure new Terminal windows find everything ----------
RC=$([ "$PLATFORM" = mac ] && echo "$HOME/.zshrc" || echo "$HOME/.bashrc")
grep -qs '.local/bin' "$RC" || printf '\n# Added by Chief of Staff setup\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC"

# ---------- plugins ----------
step "Carbon Voice plugins"
FIX="run these two commands, then run this setup again:
    claude plugin marketplace remove carbonvoice
    claude plugin marketplace add $MARKETPLACE"
case $S_MKT in
  replace)
    # Removing the old marketplace also uninstalls the plugins that came from it; they're
    # reinstalled from the new source just below. It does not touch ~/.claude/channels/cv/,
    # where the Carbon Voice channel keeps your token and state, so you stay connected.
    info "Replacing the older Carbon Voice plugin source ($CV_SOURCE)..."
    quiet claude plugin marketplace remove carbonvoice \
      || die "Couldn't remove the older Carbon Voice plugin source. The details are in $LOG_SHOWN.
  To fix it, $FIX"
    quiet claude plugin marketplace add "$MARKETPLACE" \
      || die "Couldn't add the Carbon Voice plugin source ($MARKETPLACE). Check your internet connection and run this again. The details are in $LOG_SHOWN."
    ok "Carbon Voice plugins now come from $MARKETPLACE" ;;
  update)
    quiet claude plugin marketplace update carbonvoice \
      || die "Couldn't refresh the Carbon Voice plugin list. Check your internet connection and run this again. The details are in $LOG_SHOWN." ;;
  add)
    quiet claude plugin marketplace add "$MARKETPLACE" \
      || die "Couldn't add the Carbon Voice plugin source ($MARKETPLACE). Check your internet connection and run this again. The details are in $LOG_SHOWN.
  If it says a \"carbonvoice\" marketplace already exists, $FIX" ;;
esac
# Make sure the catalog we now have really offers the chief-of-staff plugin before installing.
# (--available lists only plugins not yet installed, so on a re-run cos shows as installed.)
claude plugin list --available --json </dev/null 2>>"$LOG" \
  | jq -e '[.installed[]?.id, .available[]?.pluginId] | index("cos@carbonvoice") != null' >/dev/null 2>&1 \
  || die "The Carbon Voice plugin list on this computer doesn't include the Chief of Staff plugin.
  To fix it, $FIX"
for p in cv-channel cos; do
  if quiet claude plugin install "$p@carbonvoice" --scope user \
     || quiet claude plugin install "$p@carbonvoice"; then
    ok "$p"
  else
    die "Couldn't install the $p plugin. The details are in $LOG_SHOWN. Run this again, or in Claude type: /plugin install $p@carbonvoice"
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
  ${dim}• Your agent will use ${ORG:-your Claude account}${PLAN:+ (${PLAN} plan)}.
  • Approve the prompt asking to trust this folder.
  • Then answer a few short questions.${reset}

EOF
ask "  Press Return to continue." >/dev/null
cd "$DIR"
exec claude "/cos:setup" </dev/tty
}

main "$@"
