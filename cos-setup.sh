#!/usr/bin/env bash
# Chief of Staff for Carbon Voice — setup
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"
#
# The older `curl -fsSL .../cos-setup.sh | bash` form still works, but then this script's input
# isn't the terminal, so at the end it tells you how to open Claude instead of opening it.
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
# >>> Carbon Voice page where Agent Accounts are created. Fill in the real URL; while it's
# >>> empty, setup just says where to go instead of offering to open the page.
CV_AGENT_URL=""
CV_API="https://api.carbonvoice.app"

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
# Checked without ANTHROPIC_API_KEY, the way the agent's start script runs Claude.
# Leaves the output in AUTH_FILE (see WORK in main() for why it goes to a file).
signed_in() {
  local rc=0
  AUTH_FILE="$WORK/auth.json"
  env -u ANTHROPIC_API_KEY claude auth status </dev/null >"$AUTH_FILE" 2>/dev/null || rc=$?
  if have jq && [[ -s $AUTH_FILE ]] && jq empty "$AUTH_FILE" >/dev/null 2>&1; then
    jq -e '.loggedIn == true' "$AUTH_FILE" >/dev/null 2>&1
  else
    return $rc
  fi
}
auth_field() {  # auth_field <name>: a text field from AUTH_FILE, e.g. email, orgName
  local re="\"$1\": *\"([^\"]*)\""
  [[ -f ${AUTH_FILE:-} ]] || return 0
  if have jq; then jq -r --arg k "$1" '.[$k] // empty' "$AUTH_FILE" 2>/dev/null || true
  elif [[ "$(<"$AUTH_FILE")" =~ $re ]]; then printf '%s' "${BASH_REMATCH[1]}"; fi
}
# Signed in with an Anthropic API (Console) account rather than a Claude plan? A saved Claude
# sign-in token (oauth_token, from CLAUDE_CODE_OAUTH_TOKEN) isn't one.
api_account() { case "$(auth_field authMethod)" in ""|claude.ai|oauth_token) return 1 ;; *) return 0 ;; esac; }
account_name() {  # "<email> — <orgName>", leaving out what's unknown
  local email org
  email=$(auth_field email); org=$(auth_field orgName)
  printf '%s%s%s' "$email" "${email:+${org:+ — }}" "$org"
}
account_desc() {  # "Signed in as <email> — <orgName> (<plan> plan)", leaving out what's unknown
  local email org plan
  email=$(auth_field email); org=$(auth_field orgName); plan=$(auth_field subscriptionType)
  printf 'Signed in%s%s%s' "${email:+ as $email}" "${org:+ — $org}" "${plan:+ ($plan plan)}"
}

# Cleans up a folder name typed by the user: trims spaces, drops a trailing "/", and turns
# inner spaces into "-". A path such as "~/agent" is left as is, so it gets refused below
# rather than quietly created somewhere else.
clean_name() {
  local n=$1
  n="${n#"${n%%[![:space:]]*}"}"; n="${n%"${n##*[![:space:]]}"}"
  n=${n%/}
  n="${n#"${n%%[![:space:]]*}"}"; n="${n%"${n##*[![:space:]]}"}"
  printf '%s' "${n// /-}"
}
shown() { case "$1" in "$HOME") printf '~' ;; "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }   # path with ~ for home
place() { if [[ "$1" == "$HOME" ]]; then printf 'your home folder'; else shown "$1"; fi; }   # where, in words

# Checks a Carbon Voice token the way the cv-channel plugin does (GET /whoami, the token's own
# user) and prints the HTTP status ("000" if Carbon Voice couldn't be reached). The response
# goes to $WORK/whoami.json. The token reaches curl through its standard input, never its
# arguments, so it can't show up in the process list; it's never printed or logged.
cv_whoami() {
  printf 'header = "Authorization: Bearer %s"\n' "$1" \
    | curl -sS -K - -o "$WORK/whoami.json" -w '%{http_code}' --max-time 20 "$CV_API/whoami" 2>>"$LOG" || true
}
cv_user() {  # cv_user <field>: id, name or type of the user in $WORK/whoami.json
  case "$1" in
    id)   jq -r '.user.user_guid // empty' "$WORK/whoami.json" 2>/dev/null || true ;;
    name) jq -r '[.user.first_name, .user.last_name] | map(select(. != null and . != "")) | join(" ")' "$WORK/whoami.json" 2>/dev/null || true ;;
    type) jq -r '.user.user_type // empty' "$WORK/whoami.json" 2>/dev/null || true ;;
  esac
}
open_url() { if have open; then open "$1" </dev/null >/dev/null 2>&1; elif have xdg-open; then xdg-open "$1" </dev/null >/dev/null 2>&1; fi; }

# Where the "carbonvoice" plugin marketplace comes from, as "<kind> <location>", e.g.
# "github PhononX/claude-plugins", "git https://github.com/...", "directory /Users/me/...".
# Prints nothing when it isn't added. Uses jq when it's installed; before that (first run on
# a Mac without jq) it falls back to pattern matching, which works because the entries are
# flat objects.
cv_marketplace() {
  have claude || return 0
  local json kind="" loc="" re list="$WORK/marketplaces.json"
  local file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/known_marketplaces.json"
  if claude plugin marketplace list --json </dev/null >"$list" 2>/dev/null; then
    # [{"name": "carbonvoice", "source": "github", "repo": "PhononX/claude-plugins", ...}]
    if have jq; then
      jq -r '.[] | select(.name == "carbonvoice") | "\(.source) \(.repo // .url // .path // "")"' "$list" 2>/dev/null || true
      return 0
    fi
    json=$(<"$list")
    re='\{[^{}]*"name": *"carbonvoice"[^{}]*\}'
  elif [[ -f $file ]]; then
    # Older Claude Code without --json: read the file it records added marketplaces in.
    # {"carbonvoice": {"source": {"source": "github", "repo": "PhononX/claude-plugins"}, ...}}
    if have jq; then
      jq -r '.carbonvoice.source // empty | "\(.source) \(.repo // .url // .path // "")"' "$file" 2>/dev/null || true
      return 0
    fi
    json=$(<"$file")
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

# Installed plugins, from `claude plugin list --json` (written to a file, see WORK in main()).
# Each entry is a flat object: {"id": "cos@carbonvoice", "version": "0.1.1", "scope": "user",
# "enabled": true, ...}. Run again after anything changes what's installed.
refresh_plugins() {
  if ! have claude || ! claude plugin list --json </dev/null >"$WORK/plugins.json" 2>/dev/null; then
    printf '[]' >"$WORK/plugins.json"
  fi
}
# plugin_state <name>: "enabled", "disabled" or "missing" for <name>@carbonvoice installed for
# this user (scope user or managed; a project-only install doesn't reach the agent's folder).
# Uses jq when it's installed; before that, pattern matching on the flat entries.
plugin_state() {
  local id="$1@carbonvoice" json re s=""
  if have jq; then
    s=$(jq -r --arg id "$id" '[.[]? | select(.id == $id and (.scope == "user" or .scope == "managed"))][0]
      | if . == null then empty elif .enabled == false then "disabled" else "enabled" end' "$WORK/plugins.json" 2>/dev/null || true)
  else
    json=$(<"$WORK/plugins.json"); json=${json//$'\n'/ }
    re="\{[^{}]*\"id\": *\"$id\"[^{}]*\}"
    if [[ $json =~ $re ]]; then
      json=${BASH_REMATCH[0]}
      re='"scope": *"(user|managed)"'
      if [[ $json =~ $re ]]; then
        re='"enabled": *false'
        if [[ $json =~ $re ]]; then s=disabled; else s=enabled; fi
      fi
    fi
  fi
  printf '%s' "${s:-missing}"
}
plugin_version() {  # plugin_version <name>: installed version of <name>@carbonvoice. Needs jq.
  jq -r --arg id "$1@carbonvoice" '[.[]? | select(.id == $id and (.scope == "user" or .scope == "managed"))][0].version // empty' "$WORK/plugins.json" 2>/dev/null || true
}

# The carbonvoice marketplace's local copy of its catalog (.claude-plugin/marketplace.json),
# or nothing if it can't be found. Its folder comes from `claude plugin marketplace list`, or
# the usual place under ~/.claude/plugins/marketplaces/. Needs jq.
cv_catalog() {
  local list="$WORK/marketplaces.json" dir=""
  if claude plugin marketplace list --json </dev/null >"$list" 2>/dev/null; then
    dir=$(jq -r '.[] | select(.name == "carbonvoice") | .installLocation // empty' "$list" 2>/dev/null || true)
  fi
  [[ -n $dir ]] || dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/marketplaces/carbonvoice"
  if [[ -f "$dir/.claude-plugin/marketplace.json" ]]; then printf '%s' "$dir/.claude-plugin/marketplace.json"; fi
}

label() {  # status → coloured label
  case "$1" in
    have)       printf '%salready installed%s' "$green" "$reset" ;;
    update)     printf '%sinstalled — will check for updates%s' "$green" "$reset" ;;
    install)    printf '%swill install%s' "$yellow" "$reset" ;;
    create)     printf '%swill create%s%s' "$yellow" "${2:+ in $2}" "$reset" ;;
    replace)    printf '%swill replace an older Carbon Voice plugin source%s' "$yellow" "$reset" ;;
    token)      printf '%swill ask for its token%s' "$yellow" "$reset" ;;
    signedin)   printf '%s%s%s' "$green" "$2" "$reset" ;;
    api)        printf '%ssigned in with an API account — will ask you to sign in with your Claude plan%s' "$yellow" "$reset" ;;
    signin)     printf '%swill open your browser to sign in%s' "$yellow" "$reset" ;;
    needs-brew) printf '%soptional — needs Homebrew (asked next)%s' "$yellow" "$reset" ;;
  esac
}
where() { have brew && echo "with Homebrew" || echo "into ~/.local (no password needed)"; }

main() {
# Scratch folder, removed on exit. `claude ... --json` output is written to a file here and
# read back, never piped or captured: on macOS, output to a pipe can be cut off at the pipe
# buffer (about 64 KB) when Claude exits.
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

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
# The agent's folder goes in the directory this was run from. Inside an existing agent's
# folder, it goes next to it instead; when the directory can't be used (the filesystem root,
# or not writable), it goes in the home folder.
BASE=$PWD; BASE_NOTE=""
if [[ -f "$BASE/cos/.version" ]]; then BASE=$(dirname "$BASE"); BASE_NOTE="You're inside an agent's folder, so the new one goes next to it."; fi
if [[ "$BASE" == / || ! -w "$BASE" ]]; then BASE=$HOME; BASE_NOTE="The current folder can't be used, so it goes in your home folder."; fi
have claude && S_CLAUDE=update || S_CLAUDE=install
have jq     && S_JQ=have       || S_JQ=install
node_ok     && S_NODE=have     || S_NODE=install
if have tmux; then S_TMUX=have
elif have brew || [[ "$PLATFORM" == linux ]]; then S_TMUX=install
else S_TMUX=needs-brew; fi

# Signed in? Show which account and organization, so a computer signed in to the wrong one is
# easy to spot.
AUTH_DESC=""
if have claude && signed_in; then
  if api_account; then S_AUTH=api; else S_AUTH=signedin; AUTH_DESC=$(account_desc); fi
else S_AUTH=signin; fi

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
# Are both plugins already installed? Then setup only checks them for updates. Replacing the
# plugin source reinstalls them, and anything missing gets installed.
refresh_plugins
if [[ $S_MKT == replace ]]; then S_PLUGINS=replace
elif [[ "$(plugin_state cv-channel)" != missing && "$(plugin_state cos)" != missing ]]; then S_PLUGINS=update
else S_PLUGINS=install; fi

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
printf '  %sCarbon Voice plugins%s — %s\n' "$bold" "$reset" "$(label $S_PLUGINS)"
info "  The Carbon Voice connection, plus the chief-of-staff skills and memory."
if [[ $S_MKT == replace ]]; then info "  The Carbon Voice plugins now come from $MARKETPLACE."; fi
printf '  %sA folder for your agent%s — %s\n' "$bold" "$reset" "$(label create "$(place "$BASE")")"
info "  Your agent's notes are plain text files you can open anytime.${BASE_NOTE:+ $BASE_NOTE}"
printf '  %sYour Carbon Voice agent%s — %s\n' "$bold" "$reset" "$(label token)"
info "  Create an Agent Account in Carbon Voice; it's who you'll talk to."
echo
info "Then Claude opens. You type /cos:setup there, and it asks a few short questions to finish."
echo
yes "Continue? [Y/n]" || { echo "No changes made."; exit 0; }

mkdir -p "${LOG%/*}"
printf '\n=== cos-setup %s ===\n' "$(date)" >>"$LOG"

# ---------- which Claude account ----------
# One email can belong to several Claude organizations (say, personal and work), and Claude
# Code is signed in to one at a time, so check it's the one the agent should use.
# The question names the Claude account so it isn't mistaken for the Carbon Voice one.
# No step heading here: "Claude account" prints once, in the sign-in step below.
ACCOUNT_NAME=$(account_name)
if [[ $S_AUTH == signedin ]] && ! yes "Use this Claude account${ACCOUNT_NAME:+ ($ACCOUNT_NAME)} for your agent? [Y/n]"; then
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
  TMP=$(mktemp -d "$WORK/download.XXXXXX")
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
if api_account; then
  # The agent can't run on an API account: its start script drops ANTHROPIC_API_KEY, and the
  # Carbon Voice and Claude app connections need a Claude plan sign-in. So this isn't optional.
  printf '  %s!%s This computer is signed in with an Anthropic API account, not a Claude plan.\n' "$yellow" "$reset"
  echo "    Your agent needs a Claude plan sign-in for the Carbon Voice and Claude app connections."
  echo "    Signing in with your Claude plan doesn't delete or change your API account."
  yes "  Sign in with your Claude plan now? [Y/n]" \
    || die "Your agent needs a Claude plan sign-in. Run this again when you're ready."
  claude auth logout </dev/null >/dev/null 2>&1 || true
  claude auth login </dev/tty || true
  signed_in || die "Not signed in. Run this setup again to retry."
  api_account && die "Still signed in with an API account. When your browser opens, choose your Claude account (not the Anthropic Console), then run this again."
elif [[ "$(auth_field authMethod)" == oauth_token ]]; then
  # A saved token (CLAUDE_CODE_OAUTH_TOKEN, e.g. from `claude setup-token`). Claude Code keeps
  # using it while it's set, so signing out and in again wouldn't change anything.
  printf '  %s!%s This computer signs in to Claude with a saved token (CLAUDE_CODE_OAUTH_TOKEN).\n' "$yellow" "$reset"
  echo "    If the Claude app connection doesn't work, remove that setting and run this again."
fi
ok "$(account_desc)"
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
  TMP=$(mktemp -d "$WORK/download.XXXXXX")
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
# Make sure the catalog we now have really lists the chief-of-staff plugin before installing.
# Read the marketplace's own copy of its catalog. If it can't be found, skip the check and
# let the install step report any problem.
CATALOG=$(cv_catalog)
if [[ -n "$CATALOG" ]] && jq empty "$CATALOG" >/dev/null 2>&1; then
  jq -e 'any(.plugins[]?; .name == "cos")' "$CATALOG" >/dev/null 2>&1 \
    || die "The Carbon Voice plugin list on this computer doesn't include the Chief of Staff plugin.
  To fix it, $FIX"
else
  echo "Skipped the Chief of Staff plugin check: couldn't read the carbonvoice catalog${CATALOG:+ ($CATALOG)}." >>"$LOG"
fi
# Install what's missing. For what's already installed, `plugin install` does nothing, not even
# pick up a newer version, so run `plugin update` instead (and turn it back on if it was off).
refresh_plugins
for p in cv-channel cos; do
  state=$(plugin_state "$p")
  if [[ $state == missing ]]; then
    if quiet claude plugin install "$p@carbonvoice" --scope user \
       || quiet claude plugin install "$p@carbonvoice"; then
      refresh_plugins; v=$(plugin_version "$p"); ok "$p — installed${v:+ ($v)}"
    else
      die "Couldn't install the $p plugin. The details are in $LOG_SHOWN. Run this again, or in Claude type: /plugin install $p@carbonvoice"
    fi
    continue
  fi
  if [[ $state == disabled ]]; then
    quiet claude plugin enable "$p@carbonvoice" && info "Turned $p back on." \
      || info "Couldn't turn $p back on. In Claude, type: /plugin enable $p@carbonvoice"
  fi
  before=$(plugin_version "$p")
  if quiet claude plugin update "$p@carbonvoice"; then
    refresh_plugins; after=$(plugin_version "$p")
    if [[ -n "$after" && "$after" != "$before" ]]; then ok "$p — updated to $after"; else ok "$p — up to date${after:+ ($after)}"; fi
  else
    info "Couldn't check $p for updates; keeping ${before:-the installed version}. The details are in $LOG_SHOWN."
  fi
done

# ---------- workspace ----------
step "Your agent's folder"
info "Each agent gets its own folder in $(place "$BASE"). Use a different name for each agent you create."
NAME=""; REUSE=""
for try in 1 2 3 4; do   # the first ask, then up to 3 more
  RAW=$(ask "  Folder name [chief-of-staff]:")
  if [[ -z "${RAW//[[:space:]]/}" ]]; then NAME=chief-of-staff; else NAME=$(clean_name "$RAW"); fi
  case "$NAME" in
    "")  info "Type a name, or press Return for chief-of-staff."; NAME=""; continue ;;
    */*|"~"*) info "Use just a name, like chief-of-staff. The folder goes in $(place "$BASE")."; NAME=""; continue ;;
    .*)  info "The name can't start with a dot."; NAME=""; continue ;;
  esac
  # A folder that already has an agent: reuse it only if the same name is typed again.
  if [[ -f "$BASE/$NAME/cos/.version" && "$NAME" != "$REUSE" ]]; then
    info "$(shown "$BASE/$NAME") already has an agent. Type a different name, or type $NAME again to reuse it."
    REUSE=$NAME; NAME=""; continue
  fi
  break
done
[[ -n "$NAME" ]] || die "No folder name chosen. Run this again when you're ready; everything installed so far stays installed."
DIR="$BASE/$NAME"
mkdir -p "$DIR" || die "Couldn't create $(shown "$DIR"). Run this again from a folder you can write to, such as your home folder."
ok "$(shown "$DIR")"

# ---------- Carbon Voice agent ----------
# Done here, before Claude starts, so the token never enters a Claude session. It's saved where
# start-cos.sh and the cv-channel plugin read it: <folder>/.cv/.env, as CV_PAT=...
step "Your Carbon Voice agent"
CV_DIR="$DIR/.cv"; PAT=""; AGENT_NAME=""
if [[ -s "$CV_DIR/.env" ]]; then
  info "This folder already has a Carbon Voice token saved."
  if yes "  Keep it? [Y/n]"; then
    PAT=$(sed -n 's/^[[:space:]]*CV_PAT[[:space:]]*=[[:space:]]*//p' "$CV_DIR/.env" | head -1)
    case "$(cv_whoami "$PAT")" in
      200) AGENT_NAME=$(cv_user name); ok "Keeping the saved token${AGENT_NAME:+ for $AGENT_NAME}" ;;
      401|403) info "The saved token doesn't work any more, so you'll need a new one."; PAT="" ;;
      *) ok "Keeping the saved token (couldn't reach Carbon Voice to check it)"
         AGENT_NAME=$(cat "$CV_DIR/agent-name" 2>/dev/null || true) ;;
    esac
  fi
fi
if [[ -z "$PAT" ]]; then
  echo "  In Carbon Voice, create an Agent Account for your chief of staff."
  echo "  Then copy its Personal Access Token. You'll paste it here, and it stays hidden."
  if [[ -n "$CV_AGENT_URL" ]] && yes "  Open the Carbon Voice page for this now? [Y/n]"; then open_url "$CV_AGENT_URL"; fi
  for try in 1 2 3 4; do   # the first ask, then up to 3 more
    read -rsp "  Token (hidden): " PAT </dev/tty || true; echo
    PAT="${PAT#"${PAT%%[![:space:]]*}"}"; PAT="${PAT%"${PAT##*[![:space:]]}"}"
    if [[ -z "$PAT" ]]; then info "Nothing was pasted. Copy the token in Carbon Voice, then paste it here."; continue; fi
    if [[ "$PAT" == *[[:space:]\"\\]* ]]; then info "That doesn't look like a token. Copy just the token and paste it again."; PAT=""; continue; fi
    case "$(cv_whoami "$PAT")" in
      200) ;;
      401|403) info "That token didn't work. Copy the Agent Account's Personal Access Token again and paste it."; PAT=""; continue ;;
      *) die "Couldn't reach Carbon Voice to check the token. Check your internet connection and run this again." ;;
    esac
    if [[ -z "$(cv_user id)" ]]; then info "That token didn't work. Copy the Agent Account's Personal Access Token again and paste it."; PAT=""; continue; fi
    AGENT_NAME=$(cv_user name)
    if [[ "$(cv_user type)" == user ]]; then
      printf '  %s!%s That token belongs to a person%s, not an Agent Account.\n' "$yellow" "$reset" "${AGENT_NAME:+ ($AGENT_NAME)}"
      echo "    Your agent would send messages as that person."
      if no "  Use it anyway? [y/N]"; then PAT=""; AGENT_NAME=""; continue; fi
    fi
    break
  done
  [[ -n "$PAT" ]] || die "No working token. Run this again when you have your Agent Account's token; everything installed so far stays installed."
  mkdir -p "$CV_DIR"; chmod 700 "$CV_DIR"
  (umask 077; printf 'CV_PAT=%s\n' "$PAT" > "$CV_DIR/.env"); chmod 600 "$CV_DIR/.env"
  ok "Token saved for ${AGENT_NAME:-your agent}"
fi
PAT=""; unset PAT
# /cos:setup reads the agent's name from here instead of asking for it.
if [[ -n "$AGENT_NAME" ]]; then printf '%s\n' "$AGENT_NAME" > "$CV_DIR/agent-name"; fi
# TODO(owner allowlist): /whoami says what kind of account the token is for (user_type "bot" or
# "user") and has a created_by user ID, but created_by isn't documented as the Agent Account's
# owner. Once Carbon Voice confirms /whoami (or another call) returns the owning user, write
# {"dmPolicy": "allowlist", "allowFrom": ["<owner user ID>"], "blockedFrom": []} to
# $CV_DIR/access.json here (mode 600) and drop the pairing step. Until then the owner pairs once.

# ---------- hand off ----------
# What to do once Claude opens, shown just before it does: the user finishes setup there.
next_steps() {
  printf '  • Your agent will use %s%s.\n' "${ORG:-your Claude account}" "${PLAN:+ ($PLAN plan)}"
  echo '  • Claude will ask whether you trust this folder. Choose "Yes, I trust this folder".'
  printf '  • Then type  %s/cos:setup%s  and press Return.\n' "$bold" "$reset"
}
if [[ -t 0 ]]; then
  step "Everything's installed. Opening Claude to finish setup."
  next_steps
  echo
  ask "  Press Return to open Claude." >/dev/null
  cd "$DIR"
  rm -rf "$WORK"; trap - EXIT   # exec replaces this script, so the exit trap won't run
  # Plain `claude`, with no first message, on purpose. In a folder that isn't trusted yet,
  # `claude "/cos:setup"` shows the folder-trust prompt but then ignores every key (Enter,
  # arrows, Ctrl+C), so the user is stuck. Plain `claude` handles the prompt fine, and the
  # user types /cos:setup after trusting the folder. Don't pass a first message here.
  exec claude </dev/tty
else
  # Our input isn't the terminal (run as `curl ... | bash`), so don't open Claude from here:
  # tell the user how to open it, and what to do once it's open.
  CD_PATH=$(shown "$DIR")
  if [[ "$DIR" == *[[:space:]]* ]]; then CD_PATH="\"$DIR\""; fi
  step "Everything's installed. One last step: open Claude to finish setup."
  echo "  Run these two lines in Terminal:"
  printf '      %scd %s%s\n' "$bold" "$CD_PATH" "$reset"
  printf '      %sclaude%s\n' "$bold" "$reset"
  next_steps
  echo
fi
}

main "$@"
