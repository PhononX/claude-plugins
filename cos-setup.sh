#!/usr/bin/env bash
# Chief of Staff for Carbon Voice — setup
#
#   curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh | bash
#
# The older `curl -fsSL .../cos-setup.sh | bash` form still works, but then this script's input
# isn't the terminal, so at the end it tells you how to start your agent instead of starting it.
#
# Shows what it will install and why, waits for your OK, then installs what's missing,
# installs the Carbon Voice plugins, connects your Carbon Voice agent, asks a few questions,
# builds your agent's folder, and starts your agent. No Claude session is used for setup.
#
# Each agent's folder also gets ./update-cos.sh, which downloads this script and runs it as
#   cos-setup.sh --update <agent folder>
# to update that agent with the answers saved at setup (cos/setup.conf), asking only about
# anything missing.
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
bold=$'\033[1m'; dim=$'\033[2m'; green=$'\033[32m'; yellow=$'\033[33m'; red=$'\033[31m'; cyan=$'\033[36m'; reset=$'\033[0m'
hl()  { printf '%s%s%s' "$bold$cyan" "$1" "$reset"; }   # something to type or choose
val() { printf '%s%s%s' "$bold" "$1" "$reset"; }        # a value worth noticing
step() { printf '\n%s▸ %s%s\n' "$bold" "$1" "$reset"; }
ok()   { printf '  %s✓%s %s\n' "$green" "$reset" "$1"; }
info() { printf '  %s%s%s\n' "$dim" "$1" "$reset"; }
die()  { printf '\n%s✗ %s%s\n' "$red" "$1" "$reset" >&2; exit 1; }
# Questions stand out from the output around them: a blank line, a cyan marker, the question in
# bold and the choices in cyan. The prompt goes straight to the terminal, so $(ask ...) captures
# only the reply. When piped from curl, stdin is this script, so answers come from the terminal.
ask() {
  local q=$1 lead opts="" mark="?" reply re='^(.*[^ ]) +(\[[^]]*\]):?$'
  lead=${q%%[! ]*}; q=${q#"$lead"}
  if [[ $q =~ $re ]]; then q=${BASH_REMATCH[1]}; opts=${BASH_REMATCH[2]}; fi
  if [[ -z "$opts" && "$q" != *"?"* ]]; then mark="↵"; fi
  printf '\n%s%s%s%s %s%s%s%s %s›%s ' "$lead" "$bold$cyan" "$mark" "$reset" "$bold" "$q" "$reset" \
    "${opts:+ $cyan$opts$reset}" "$cyan" "$reset" >/dev/tty 2>/dev/null || true
  read -r reply </dev/tty || true; printf '%s' "$reply"
}
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
cv_user() {  # cv_user <field>: id, name or creator of the user in $WORK/whoami.json
  case "$1" in
    id)   jq -r '.user.user_guid // empty' "$WORK/whoami.json" 2>/dev/null || true ;;
    name) jq -r '[.user.first_name, .user.last_name] | map(select(. != null and . != "")) | join(" ")' "$WORK/whoami.json" 2>/dev/null || true ;;
    creator) jq -r '.user.created_by // empty' "$WORK/whoami.json" 2>/dev/null || true ;;   # who created an Agent Account
  esac
}
# Reads the token into PAT, one character at a time and hidden, printing a • for each so a
# paste visibly lands; Backspace removes one. The markers some terminals wrap around pasted
# text (ESC [200~ ... ESC [201~) are skipped. Works with macOS's bash 3.2: whole-second
# timeouts only.
read_token() {
  local c
  PAT=""
  printf '\n  %s?%s %sPaste the token%s %s(hidden)%s %s›%s ' "$bold$cyan" "$reset" "$bold" "$reset" "$dim" "$reset" "$cyan" "$reset"
  while IFS= read -rsn1 c </dev/tty; do
    case "$c" in
      "") break ;;                                                   # Return
      $'\177'|$'\b') if [[ -n "$PAT" ]]; then PAT=${PAT%?}; printf '\b \b'; fi ;;
      $'\033') read -rsn5 -t 1 c </dev/tty || true ;;                # a paste marker or arrow key
      *) PAT+=$c; printf '•' ;;
    esac
  done
  echo
}
# cv_contact_name <token> <user ID>: that user's name, from Carbon Voice's POST /contacts, or
# nothing if it can't be looked up. The token goes to curl on its input, as in cv_whoami.
cv_contact_name() {
  [[ "$2" =~ ^[A-Za-z0-9_-]+$ ]] || return 0
  printf 'header = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\n' "$1" \
    | curl -sS -K - -o "$WORK/contact.json" --max-time 20 -X POST --data "{\"user_guids\":[\"$2\"]}" \
        "$CV_API/contacts" 2>>"$LOG" || true
  jq -r '(if type == "array" then .[0] else ((.contacts // .data // [])[0]) end) // {}
         | [.first_name, .last_name] | map(select(. != null and . != "")) | join(" ")' \
    "$WORK/contact.json" 2>/dev/null || true
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

plugin_path() {  # plugin_path <name>: folder of <name>@carbonvoice's installed copy. Needs jq.
  jq -r --arg id "$1@carbonvoice" '[.[]? | select(.id == $id and (.scope == "user" or .scope == "managed"))][0].installPath // empty' "$WORK/plugins.json" 2>/dev/null || true
}
# fill <template> <dest> KEY=value...: copies a template, replacing each {{KEY}} with its value
# literally. Values go through the environment, so any character in them is safe.
fill() {
  local src=$1 dst=$2 keys="" kv
  shift 2
  local envs=()
  for kv in "$@"; do keys="$keys${kv%%=*} "; envs+=("FILL_$kv"); done
  env "${envs[@]}" FILL_KEYS="$keys" awk '
    BEGIN { n = split(ENVIRON["FILL_KEYS"], k, " ") }
    {
      for (i = 1; i <= n; i++) {
        p = "{{" k[i] "}}"; v = ENVIRON["FILL_" k[i]]; out = ""; s = $0
        while ((j = index(s, p)) > 0) { out = out substr(s, 1, j - 1) v; s = substr(s, j + length(p)) }
        $0 = out s
      }
      print
    }' "$src" > "$dst"
}
xml() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }   # text for a plist
version_ge() {  # version_ge <a> <b>: is version a (like 2.1.300) at least b?
  local IFS=. i
  local a=($1) b=($2)
  for i in 0 1 2; do
    if (( ${a[i]:-0} > ${b[i]:-0} )); then return 0; fi
    if (( ${a[i]:-0} < ${b[i]:-0} )); then return 1; fi
  done
  return 0
}
trim() { local s=$1; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
# ask_name <prompt> <default> <nudge>: asks until there's an answer (up to 4 times); prints it.
ask_name() {
  local v try
  for try in 1 2 3 4; do
    v=$(trim "$(ask "$1${2:+ [$2]}:")"); v=${v:-$2}
    if [[ -n "$v" ]]; then printf '%s' "$v"; return 0; fi
    info "$3" >&2
  done
  return 1
}
my_first_name() {  # the first name on this computer's user account, if there is one
  local n=""
  if [[ "$PLATFORM" == mac ]]; then n=$(id -F 2>/dev/null || true)
  elif have getent; then n=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f5 | cut -d, -f1 || true); fi
  printf '%s' "${n%% *}"
}
warn() { printf '  %s!%s %s\n' "$yellow" "$reset" "$1"; }
# saved <key>: an answer saved at setup, from $DIR/cos/setup.conf. Plain key=value lines, read
# as text and never run.
saved() {
  local k v
  if [[ -f "$DIR/cos/setup.conf" ]]; then
    while IFS='=' read -r k v; do
      if [[ "$k" == "$1" ]]; then printf '%s' "$v"; return 0; fi
    done < "$DIR/cos/setup.conf"
  fi
  return 0
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

# install_notebook_server: sets up and (re)starts the always-on notebook server for $DIR. Returns
# success once it answers on its port.
notebook_up() { curl -fs --max-time 1 "http://localhost:$NOTEBOOK_PORT/health" >/dev/null 2>&1 </dev/null; }
install_notebook_server() {
  local node_bin label unit svc i
  node_bin=$(command -v node 2>/dev/null) || return 1
  [[ -f "$DIR/.cos/notebook-server.mjs" ]] || return 1
  label=$(printf '%s' "$(basename "$DIR")" | tr -c 'A-Za-z0-9._-' '-')
  # Stop a copy started by hand (./open-brain.sh, ./start-cos.sh) so the service can take the port.
  pkill -f -- "$DIR/.cos/notebook-server.mjs" >/dev/null 2>&1 </dev/null || true
  if [[ "$PLATFORM" == mac ]]; then
    svc="com.phononx.cos.$label.notebook"
    mkdir -p "$HOME/Library/LaunchAgents"
    fill "$TEMPLATES/notebook.plist" "$HOME/Library/LaunchAgents/$svc.plist" JOB_LABEL="$(xml "$svc")" \
      NODE="$(xml "$node_bin")" WORKSPACE="$(xml "$DIR")" PORT="$NOTEBOOK_PORT" \
      PATH="$(xml "$(dirname "$node_bin"):$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin")"
    launchctl bootout "gui/$(id -u)/$svc" </dev/null >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$svc.plist" </dev/null >>"$LOG" 2>&1 || true
  elif have systemctl && systemctl --user show-environment </dev/null >/dev/null 2>&1; then
    svc="cos-$label-notebook.service"; unit="$HOME/.config/systemd/user/$svc"
    mkdir -p "$(dirname "$unit")"
    {
      echo "[Unit]"
      echo "Description=Notebook for $AGENT_NAME (Chief of Staff)"
      echo "[Service]"
      echo "WorkingDirectory=$DIR"
      echo "Environment=COS_NOTEBOOK_PORT=$NOTEBOOK_PORT"
      echo "ExecStart=\"$node_bin\" \"$DIR/.cos/notebook-server.mjs\""
      echo "Restart=always"
      echo "RestartSec=10"
      echo "StandardOutput=append:$DIR/.cv/notebook-server.log"
      echo "StandardError=append:$DIR/.cv/notebook-server.log"
      echo "[Install]"
      echo "WantedBy=default.target"
    } > "$unit"
    systemctl --user daemon-reload </dev/null >>"$LOG" 2>&1 || true
    systemctl --user enable "$svc" </dev/null >>"$LOG" 2>&1 || true
    systemctl --user restart "$svc" </dev/null >>"$LOG" 2>&1 || true
  else
    local cron_cmd="cd \"$DIR\" && \"$node_bin\" \"$DIR/.cos/notebook-server.mjs\" >> .cv/notebook-server.log 2>&1"
    if have crontab; then
      { crontab -l 2>/dev/null | grep -vF -- "$DIR/.cos/notebook-server.mjs" || true; echo "@reboot $cron_cmd"; } | crontab - 2>>"$LOG" || true
    fi
    (cd "$DIR" && nohup "$node_bin" "$DIR/.cos/notebook-server.mjs" >> .cv/notebook-server.log 2>&1 </dev/null &)
  fi
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
    notebook_up && return 0
    sleep 0.2
  done
  # The service didn't come up (on a Mac, macOS can keep background jobs out of some folders until
  # allowed): start it from here for now; ./start-cos.sh and ./open-brain.sh do the same.
  (cd "$DIR" && nohup "$node_bin" "$DIR/.cos/notebook-server.mjs" >> .cv/notebook-server.log 2>&1 </dev/null &)
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do notebook_up && return 0; sleep 0.2; done
  return 1
}
# make_launcher: builds the launchers for this agent (see "a launcher" in main): one that starts
# the agent, and one that opens its notebook page. Sets LAUNCHER (the agent's, its path),
# LAUNCHER_WHERE (where it is, in words) and NOTEBOOK_APP (the notebook's, if it was made).
applescript_str() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }
# our_app <path>: true if the app there is a launcher this setup made (or nothing is there).
our_app() { [[ ! -e "$1" ]] || osadecompile "$1" 2>/dev/null </dev/null | grep -q "Made by the Chief of Staff setup"; }
# install_app <name> <applescript file>: compiles it into <name>.app and prints where it went.
# The Applications folder Finder shows, when this account can write to it (admin accounts can);
# otherwise the one in the home folder, which Finder hides from its sidebar but Spotlight and
# Launchpad still find. Never replaces an app this setup didn't make.
install_app() {
  local app old="$HOME/Applications/$1.app"
  if [[ -w /Applications ]] && our_app "/Applications/$1.app"; then
    app="/Applications/$1.app"
  else
    our_app "$old" || return 1
    mkdir -p "$HOME/Applications"; app=$old
  fi
  rm -rf "$WORK/launcher.app"
  osacompile -o "$WORK/launcher.app" "$2" >>"$LOG" 2>&1 </dev/null || return 1
  rm -rf "$app"; mv "$WORK/launcher.app" "$app"
  # An earlier setup put it in ~/Applications; don't leave two.
  if [[ "$app" != "$old" && -e "$old" ]] && our_app "$old"; then rm -rf "$old"; fi
  printf '%s' "$app"
}
make_launcher() {
  local name dir_as name_as app desk entry node_dir
  name=$(printf '%s' "$AGENT_NAME" | tr -d '/:"\\$`' ); name=${name:-Chief of Staff}
  NOTEBOOK_APP=""; NOTEBOOK_NEW=""
  if [[ "$PLATFORM" == mac ]]; then
    have osacompile || return 1
    [[ -e "/Applications/$name Notebook.app" || -e "$HOME/Applications/$name Notebook.app" ]] || NOTEBOOK_NEW=1
    dir_as=$(applescript_str "$DIR"); name_as=$(applescript_str "$name")
    cat > "$WORK/launcher.applescript" <<APPLESCRIPT
-- Starts $name_as, your chief of staff, in Terminal; or brings Terminal forward if it's running.
-- Made by the Chief of Staff setup; ./update-cos.sh rebuilds it.
on run
	set agentDir to "$dir_as"
	try
		do shell script quoted form of (agentDir & "/start-cos.sh") & " --running"
		tell application "Terminal" to activate
		display notification "$name_as is already running in Terminal." with title "$name_as"
	on error
		tell application "Terminal"
			activate
			do script "cd " & quoted form of agentDir & " && ./start-cos.sh"
		end tell
	end try
end run
APPLESCRIPT
    # Apps start with a bare PATH, so the notebook's tools (jq, node) are added to it here,
    # including the folder of the node setup found (nvm, volta and the like put it elsewhere).
    node_dir=$(dirname "$(command -v node 2>/dev/null || echo /usr/local/bin/node)")
    node_dir=$(applescript_str "$node_dir")
    cat > "$WORK/notebook.applescript" <<APPLESCRIPT
-- Opens $name_as's notebook page in your browser, starting the notebook server if it isn't running.
-- Made by the Chief of Staff setup; ./update-cos.sh rebuilds it.
on run
	set agentDir to "$dir_as"
	try
		do shell script "export PATH=\"$node_dir:\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH\"; " & quoted form of (agentDir & "/open-brain.sh") & " >/dev/null 2>&1"
	on error
		display alert "Couldn't open $name_as's notebook" message "Run ./open-brain.sh in " & agentDir & " to see why."
	end try
end run
APPLESCRIPT
    app=$(install_app "$name" "$WORK/launcher.applescript") || return 1
    NOTEBOOK_APP=$(install_app "$name Notebook" "$WORK/notebook.applescript") || NOTEBOOK_APP=""
    LAUNCHER=$app
    if [[ "$app" == /Applications/* ]]; then LAUNCHER_WHERE="Applications (or Spotlight)"
    else LAUNCHER_WHERE="Applications in your home folder (or Spotlight)"; fi
    if [[ "$WANT_DESKTOP" == 1 && -d "$HOME/Desktop" ]]; then
      desk="$HOME/Desktop/$name.app"
      if [[ -L "$desk" || ! -e "$desk" ]]; then ln -sfn "$app" "$desk"; LAUNCHER_WHERE="your Desktop or $LAUNCHER_WHERE"; fi
    fi
  else
    mkdir -p "$HOME/.local/share/applications"
    app="$HOME/.local/share/applications/cos-$(basename "$DIR").desktop"
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=$name"
      echo "Comment=Your chief of staff, connected to Carbon Voice"
      echo "Exec=\"${DIR//\"/\\\"}/start-cos.sh\""
      echo "Path=$DIR"
      echo "Terminal=true"
      echo "Icon=utilities-terminal"
      echo "Categories=Office;"
    } > "$app"
    chmod +x "$app"
    entry="$HOME/.local/share/applications/cos-$(basename "$DIR")-notebook.desktop"
    [[ -e "$entry" ]] || NOTEBOOK_NEW=1
    {
      echo "[Desktop Entry]"
      echo "Type=Application"
      echo "Name=$name Notebook"
      echo "Comment=Everything $name knows, in your browser"
      echo "Exec=\"${DIR//\"/\\\"}/open-brain.sh\""
      echo "Path=$DIR"
      echo "Terminal=false"
      echo "Icon=accessories-text-editor"
      echo "Categories=Office;"
    } > "$entry" && chmod +x "$entry" && NOTEBOOK_APP=$entry
    LAUNCHER=$app; LAUNCHER_WHERE="your applications menu"
    if [[ "$WANT_DESKTOP" == 1 && -d "$HOME/Desktop" ]]; then
      cp "$app" "$HOME/Desktop/$name.desktop" && chmod +x "$HOME/Desktop/$name.desktop" && LAUNCHER_WHERE="your Desktop or applications menu"
    fi
  fi
}

# wrap <text> <indent> [<later lines' indent>]: prints text wrapped to fit an 80-column terminal.
wrap() { printf '%s\n' "$1" | fold -s -w $((80 - ${#2})) | sed -e 's/ *$//' -e "1s/^/$2/" -e "1!s/^/${3:-$2}/"; }
# show_notebook: what the notebook page is, its link, and an offer to open it now.
show_notebook() {
  [[ -n "$BRAIN_LINK" ]] || return 0
  printf '  %sYour notebook%s\n' "$bold" "$reset"
  wrap "Everything $AGENT_NAME knows, on one page in your browser: today's briefs, what you owe and what you're waiting on, people, projects, ideas, drafts, decisions, and how $AGENT_NAME works for you. $1 Check things off, add and edit right on the page, or just tell $AGENT_NAME. It's always on and updates as $AGENT_NAME works, so bookmark it (the address includes its key, so keep it to yourself):" "  "
  printf '    %s\n' "$(val "$BRAIN_LINK")"
  if [[ -n "$NOTEBOOK_APP" ]]; then echo "  Or open $AGENT_NAME Notebook, like any app."; fi
  if [[ -d /Applications/Obsidian.app || -d "$HOME/Applications/Obsidian.app" ]] || have obsidian; then
    echo "  You use Obsidian: you can also open $(shown "$DIR")/cos as a vault."
  fi
  if yes "  Open your notebook now? [Y/n]"; then
    open_url "$BRAIN_LINK"
    if [[ $MODE == setup ]]; then echo "  It opened in your browser. Come back to this window to start $AGENT_NAME."; fi
  fi
  echo
}
# whats_new: the highlights of each version newer than the one this folder had, from the plugin's
# whats-new.md ("## <version>" headings, then lines).
whats_new() {
  local f="$TEMPLATES/dotcos/whats-new.md" v show="" line
  [[ -n "$OLD_VERSION" && -f "$f" && "$OLD_VERSION" != "$COS_VERSION" ]] || return 0
  printf '  %sWhat'"'"'s new since %s%s\n' "$bold" "$OLD_VERSION" "$reset"
  while IFS= read -r line; do
    case "$line" in
      "## "*) v=${line#\#\# }; v=${v%% *}
              if version_ge "$v" "$OLD_VERSION" && [[ "$v" != "$OLD_VERSION" ]]; then show=1; else show=""; fi ;;
      "- "*) if [[ -n "$show" ]]; then wrap "$line" "  " "    "; fi ;;
    esac
  done < "$f"
  echo
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
    later)      printf '%soptional — asked later%s' "$yellow" "$reset" ;;
    refresh)    printf '%swill update%s' "$yellow" "$reset" ;;
  esac
}
where() { have brew && echo "with Homebrew" || echo "into ~/.local (no password needed)"; }

main() {
# Scratch folder, removed on exit. `claude ... --json` output is written to a file here and
# read back, never piped or captured: on macOS, output to a pipe can be cut off at the pipe
# buffer (about 64 KB) when Claude exits.
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# ./update-cos.sh runs this as `--update <agent folder>`: update that agent.
MODE=setup; DIR=""
if [[ "${1:-}" == --update ]]; then
  MODE=update
  [[ -n "${2:-}" && -f "${2:-}/cos/.version" ]] || die "${2:-That folder} isn't an agent's folder. Run ./update-cos.sh from inside your agent's folder."
  DIR=$(cd "$2" && pwd)
fi

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
if [[ $MODE == update ]]; then
  UPD_NAME=$(saved AGENT_NAME); [[ -n "$UPD_NAME" ]] || UPD_NAME=$(cat "$DIR/.cv/agent-name" 2>/dev/null || true)
  printf '%sChief of Staff for Carbon Voice — update%s\n\n' "$bold" "$reset"
  echo "This updates ${UPD_NAME:-your agent} in $(shown "$DIR") to the latest version."
  echo "Here's what will happen on this computer:"
else
  printf '%sChief of Staff for Carbon Voice — setup%s\n\n' "$bold" "$reset"
  echo "This sets up a chief of staff you talk to through Carbon Voice."
  echo "Here's what will happen on this computer:"
fi
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
if [[ $MODE == update ]]; then
  printf '  %sYour agent'"'"'s folder%s — %s\n' "$bold" "$reset" "$(label refresh)"
  info "  Rebuilds its instructions and scripts from the latest version. Keeps its notes, its"
  info "  token, your own rules (cos/my-rules.md) and your answers to setup."
  echo
else
  printf '  %sA folder for your agent%s — %s\n' "$bold" "$reset" "$(label create "$(place "$BASE")")"
  info "  Your agent's notes are plain text files, and a page in your browser shows everything"
  info "  it knows.${BASE_NOTE:+ $BASE_NOTE}"
  printf '  %sYour Carbon Voice agent%s — %s\n' "$bold" "$reset" "$(label token)"
  info "  Create a Personal Agent Account in Carbon Voice; it's who you'll talk to."
  printf '  %sNightly review%s — %s\n' "$bold" "$reset" "$(label later)"
  info "  A scheduled job that tidies your agent's notes at 2:15 each night."
  echo
  info "Along the way: a few questions about you and your agent. At the end, your agent starts."
  echo
fi
yes "Continue? [Y/n]" || { echo "No changes made."; exit 0; }

mkdir -p "${LOG%/*}"
printf '\n=== cos-setup %s ===\n' "$(date)" >>"$LOG"

# ---------- which Claude account ----------
# One email can belong to several Claude organizations (say, personal and work), and Claude
# Code is signed in to one at a time, so check it's the one the agent should use.
# The question names the Claude account so it isn't mistaken for the Carbon Voice one.
# No step heading here: "Claude account" prints once, in the sign-in step below.
ACCOUNT_NAME=$(account_name)
if [[ $MODE == setup && $S_AUTH == signedin ]] && ! yes "Use this Claude account${ACCOUNT_NAME:+ ($ACCOUNT_NAME)} for your agent? [Y/n]"; then
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
# (An update already knows its folder.)
if [[ $MODE == setup ]]; then
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
fi

# ---------- Carbon Voice agent ----------
# Done here, before Claude starts, so the token never enters a Claude session. It's saved where
# start-cos.sh and the cv-channel plugin read it: <folder>/.cv/.env, as CV_PAT=...
step "Your Carbon Voice agent"
CV_DIR="$DIR/.cv"; PAT=""; AGENT_NAME=""
if [[ -s "$CV_DIR/.env" ]]; then
  if [[ $MODE == setup ]]; then info "This folder already has a Carbon Voice token saved."; fi
  if [[ $MODE == update ]] || yes "  Keep it? [Y/n]"; then
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
  echo "  In Carbon Voice, create a Personal Agent Account for your chief of staff."
  echo "  Then copy its Personal Access Token. You'll paste it here, and it stays hidden."
  if [[ -n "$CV_AGENT_URL" ]] && yes "  Open the Carbon Voice page for this now? [Y/n]"; then open_url "$CV_AGENT_URL"; fi
  for try in 1 2 3 4; do   # the first ask, then up to 3 more
    read_token
    PAT="${PAT#"${PAT%%[![:space:]]*}"}"; PAT="${PAT%"${PAT##*[![:space:]]}"}"
    if [[ -z "$PAT" ]]; then info "Nothing was pasted. Copy the token in Carbon Voice, then paste it here."; continue; fi
    if [[ "$PAT" == *[[:space:]\"\\]* ]]; then info "That doesn't look like a token. Copy just the token and paste it again."; PAT=""; continue; fi
    info "Got ${#PAT} characters. Checking with Carbon Voice..."
    case "$(cv_whoami "$PAT")" in
      200) ;;
      401|403) info "That token didn't work. Copy the Agent Account's Personal Access Token again and paste it."; PAT=""; continue ;;
      *) die "Couldn't reach Carbon Voice to check the token. Check your internet connection and run this again." ;;
    esac
    if [[ -z "$(cv_user id)" ]]; then info "That token didn't work. Copy the Agent Account's Personal Access Token again and paste it."; PAT=""; continue; fi
    AGENT_NAME=$(cv_user name)
    break
  done
  [[ -n "$PAT" ]] || die "No working token. Run this again when you have your Agent Account's token; everything installed so far stays installed."
  mkdir -p "$CV_DIR"; chmod 700 "$CV_DIR"
  (umask 077; printf 'CV_PAT=%s\n' "$PAT" > "$CV_DIR/.env"); chmod 600 "$CV_DIR/.env"
  ok "Token saved for ${AGENT_NAME:-your agent}"
fi
# Who created this Agent Account, its owner: created_by in the /whoami response for the token
# just checked. /whoami can't tell an Agent Account from a person (user_type is "user" for
# both), and a person's account can have a created_by too (an admin who made it), so this asks
# by name before letting that account message the agent without pairing. An account already on
# the allowlist isn't asked about again, and a "no" is remembered for updates (ALLOW_CREATOR=0).
OWNER_ID=""; ALLOW_CREATOR=""
CREATOR=$(cv_user creator)
if [[ -n "$CREATOR" && "$CREATOR" != "$(cv_user id)" && -n "${PAT:-}" ]]; then
  if [[ -s "$CV_DIR/access.json" ]] \
     && jq -e --arg o "$CREATOR" '(.allowFrom // []) | index($o)' "$CV_DIR/access.json" >/dev/null 2>&1; then
    OWNER_ID=$CREATOR
  elif [[ $MODE == update && "$(saved ALLOW_CREATOR)" == 0 ]]; then
    ALLOW_CREATOR=0
  else
    CREATOR_NAME=$(cv_contact_name "$PAT" "$CREATOR")
    if [[ -n "$CREATOR_NAME" ]]; then
      if yes "  $CREATOR_NAME created this Agent Account. Let $CREATOR_NAME message ${AGENT_NAME:-it} without a pairing code? [Y/n]"; then
        OWNER_ID=$CREATOR
      fi
    else
      echo "  Carbon Voice says this Agent Account was created by the account with ID $CREATOR."
      if yes "  Is that your own Carbon Voice account? If so, it can skip pairing. [Y/n]"; then OWNER_ID=$CREATOR; fi
    fi
    if [[ -n "$OWNER_ID" ]]; then ALLOW_CREATOR=1; else ALLOW_CREATOR=0; fi
  fi
fi
PAT=""; unset PAT

# ---------- about you and your agent ----------
# Answers saved at an earlier setup are reused by an update, and offered as defaults by a
# setup that reuses a folder.
OWNER_NAME=$(saved OWNER_NAME); SAVED_AGENT=$(saved AGENT_NAME)
if [[ $MODE == update && -n "$OWNER_NAME" && -n "$SAVED_AGENT" ]]; then
  AGENT_NAME=$SAVED_AGENT
else
  step "About you and your agent"
  OWNER_NAME=$(ask_name "  Your name, as your agent should call you" "${OWNER_NAME:-$(my_first_name)}" \
    "Type your name, so your agent knows what to call you.") \
    || die "No name given. Run this again when you're ready; everything installed so far stays installed."
  AGENT_NAME=$(ask_name "  Your agent's name" "${SAVED_AGENT:-$AGENT_NAME}" "Type a name for your agent.") \
    || die "No agent name given. Run this again when you're ready; everything installed so far stays installed."
fi
printf '%s\n' "$AGENT_NAME" > "$CV_DIR/agent-name"   # used when the token can't be checked on a re-run

# How the agent connects to Carbon Voice depends on the Claude plan.
case "$PLAN" in
  team|enterprise) TEAM=1 ;;
  pro|max) TEAM="" ;;
  *) case "$(saved TEAM)" in
       1) TEAM=1 ;;
       0) TEAM="" ;;
       *) if no "  Is your Claude plan Team or Enterprise? [y/N]"; then TEAM=""; else TEAM=1; fi ;;
     esac ;;
esac
if [[ -n "$TEAM" ]]; then
  CHANNEL_ARGS="--channels plugin:cv-channel@carbonvoice"
  if [[ $MODE == setup ]]; then
    info "On Team and Enterprise plans, an admin must turn on channels (channelsEnabled) and"
    info "allow the Carbon Voice plugin (allowedChannelPlugins) before your agent can connect."
  fi
else
  CHANNEL_ARGS="--dangerously-load-development-channels plugin:cv-channel@carbonvoice"
fi

# Optionally show the agent's session in the Claude app (Remote Control, Claude Code 2.1.51+).
REMOTE_ARGS=""
CLAUDE_VER=$(claude --version </dev/null 2>/dev/null | head -1 || true); CLAUDE_VER=${CLAUDE_VER%% *}
SAVED_REMOTE=$(saved REMOTE)
if [[ $MODE == update && -n "$SAVED_REMOTE" ]]; then
  if [[ "$SAVED_REMOTE" == 1 ]]; then
    if [[ -n "$CLAUDE_VER" ]] && version_ge "$CLAUDE_VER" 2.1.51; then REMOTE_ARGS="--remote-control"
    else warn "This version of Claude Code can't show your agent in the Claude app, so that's off for now."; fi
  fi
elif [[ -n "$CLAUDE_VER" ]] && version_ge "$CLAUDE_VER" 2.1.51; then
  echo "  Your chats with the agent can also appear in the Claude app (Code tab) and at"
  echo "  claude.ai/code, so you can watch what it's doing and approve its requests."
  if yes "  Show your agent in the Claude app? [Y/n]"; then REMOTE_ARGS="--remote-control"; fi
  if [[ -n "$REMOTE_ARGS" && -n "$TEAM" ]]; then
    info "On Team and Enterprise plans, an Owner must turn on Remote Control in Claude Code's admin settings."
  fi
else
  info "This version of Claude Code can't show your agent in the Claude app. After updating it,"
  info "run /cos:doctor in your agent's folder to turn that on."
fi

# ---------- build the agent's folder ----------
# Everything the agent needs, from the installed cos plugin's templates. For a folder that
# already has an agent, its notes, CLAUDE.md and .gitignore are kept, its settings are merged,
# and its start and nightly scripts are rebuilt (the old ones saved as .bak if they differ).
step "Setting up your agent's folder"
refresh_plugins
PLUGIN_ROOT=$(plugin_path cos); TEMPLATES="$PLUGIN_ROOT/templates"
[[ -n "$PLUGIN_ROOT" && -d "$TEMPLATES" ]] \
  || die "Couldn't find the Chief of Staff plugin's files. Run this again; the details are in $LOG_SHOWN."
CLAUDE_BIN=$(command -v claude)
COS_VERSION=$(jq -r '.version // empty' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null || true)
if [[ -f "$DIR/cos/.version" ]]; then NEW_AGENT=""; else NEW_AGENT=1; fi
# The agent's name goes into its start and nightly scripts inside double quotes, so leave out
# the characters that would break them there.
SCRIPT_NAME=$(printf '%s' "$AGENT_NAME" | tr -d '"$`\\')

mkdir -p "$DIR/cos/log/transcripts" "$DIR/cos/projects" "$DIR/cos/areas" "$DIR/cos/people" \
  "$DIR/cos/archive" "$DIR/cos/drafts" "$DIR/.cos" "$DIR/outbox" "$DIR/.claude" "$CV_DIR"; chmod 700 "$CV_DIR"
# Let the Agent Account's owner message the agent straight away instead of pairing with a code:
# add them to the cv-channel allowlist (.cv/access.json, the format /cv-channel:access uses).
# A new file gets the "pairing" policy: if the creator turns out not to be the account the user
# messages from, they still get a pairing code back instead of silence. A code is only a
# request; nobody gets in until it's approved at the terminal, and /cv-channel:access offers to
# lock the policy down once someone is paired. An existing file keeps its policy and other
# entries; an owner the user deliberately blocked stays blocked.
OWNER_ALLOWED=""
if [[ -n "$OWNER_ID" ]]; then
  ACCESS="$CV_DIR/access.json"
  if [[ -s "$ACCESS" ]]; then
    if jq -e --arg o "$OWNER_ID" '(.blockedFrom // []) | index($o)' "$ACCESS" >/dev/null 2>&1; then
      warn "Your Carbon Voice account is blocked from messaging this agent, so it was left that way."
    elif jq --arg o "$OWNER_ID" '.allowFrom = ((.allowFrom // []) + [$o] | unique)' "$ACCESS" > "$WORK/access.json" 2>>"$LOG"; then
      cat "$WORK/access.json" > "$ACCESS"; OWNER_ALLOWED=1
    else
      warn "Couldn't read .cv/access.json, so who can message your agent was left as it was."
    fi
  else
    (umask 077; jq -n --arg o "$OWNER_ID" '{dmPolicy: "pairing", allowFrom: [$o], blockedFrom: []}' > "$ACCESS")
    OWNER_ALLOWED=1
  fi
  chmod 600 "$ACCESS" 2>/dev/null || true
fi
# With nobody allowed, the user pairs their account with a code, so turn pairing on. The
# channel reads an access file with no dmPolicy as "allowlist" (such files predate pairing),
# and an allowlist with nobody on it drops every message without a reply.
if [[ -z "$OWNER_ALLOWED" ]]; then
  ACCESS="$CV_DIR/access.json"
  if [[ ! -s "$ACCESS" ]]; then
    (umask 077; jq -n '{dmPolicy: "pairing", allowFrom: [], blockedFrom: []}' > "$ACCESS")
  elif jq -e '.dmPolicy == null and ((.allowFrom // []) | length == 0)' "$ACCESS" >/dev/null 2>&1 \
       && jq '.dmPolicy = "pairing"' "$ACCESS" > "$WORK/access.json" 2>>"$LOG"; then
    cat "$WORK/access.json" > "$ACCESS"
  fi
fi
# The notebook: a new agent gets every starting file; an existing one gets only the files it
# doesn't have yet, so its notes are never touched.
(cd "$TEMPLATES/cos" && find . -type f </dev/null) | while IFS= read -r f; do
  if [[ ! -e "$DIR/cos/$f" ]]; then
    mkdir -p "$(dirname "$DIR/cos/$f")"
    fill "$TEMPLATES/cos/$f" "$DIR/cos/$f" AGENT_NAME="$AGENT_NAME" OWNER_NAME="$OWNER_NAME"
  fi
done
# Notes in the layout from before 0.2 (open-loops.md, people.md) are moved over by the agent
# itself (the cos:migrate skill), which marks it done in cos/.layout. Anything else is current.
if [[ ! -f "$DIR/cos/.layout" && ! -f "$DIR/cos/open-loops.md" && ! -f "$DIR/cos/people.md" ]]; then
  printf '2\n' > "$DIR/cos/.layout"
fi
# Briefs used to be one setting (brief_time and brief_days in my-rules.md's front matter). Turn
# that into a "My briefs" list with one "Morning brief", and add the other brief sections.
RULES="$DIR/cos/my-rules.md"
if [[ -f "$RULES" ]] && ! grep -q '^## My briefs' "$RULES"; then
  front() {  # front <key> <default>: a value from the front matter of my-rules.md
    local v
    v=$(awk -v k="$1" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
          NR > 1 { i = index($0, ":"); if (i && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); gsub(/^[ \t"]+|[ \t"]+$/, "", v); print v; exit } }' "$RULES")
    printf '%s' "${v:-$2}"
  }
  B_AT=$(front brief_time 07:00); B_DAYS=$(front brief_days weekdays)
  awk 'NR == 1 && $0 == "---" { fm = 1; print; next }
       fm && $0 == "---" { fm = 0 }
       fm && (/^brief_time:/ || /^brief_days:/) { next }
       { print }' "$RULES" > "$WORK/my-rules" && cat "$WORK/my-rules" > "$RULES"
  printf '\n## My briefs\n- Morning brief [at:: %s] [days:: %s] [covers:: focus, meetings, catch up, follow-ups, due elsewhere]\n' \
    "$B_AT" "$B_DAYS" >> "$RULES"
  grep -q '^## What goes in my briefs' "$RULES" || printf '\n## What goes in my briefs\n' >> "$RULES"
  grep -q '^## Important people' "$RULES" || printf '\n## Important people\n' >> "$RULES"
fi
# Sections added in later versions, for notebooks made before them.
if [[ -f "$RULES" ]] && ! grep -q '^## My tools' "$RULES"; then printf '\n## My tools\n' >> "$RULES"; fi
ABOUT="$DIR/cos/about-me.md"
if [[ -f "$ABOUT" ]] && ! grep -q '^## How I write' "$ABOUT"; then printf '\n## How I write\n' >> "$ABOUT"; fi
# Before 0.2, the user's own instructions lived in my-instructions.md. Move anything they wrote
# there into cos/my-rules.md, and keep the old file as my-instructions.md.bak.
if [[ -f "$DIR/my-instructions.md" ]]; then
  awk 'started || !(/^# Your own instructions for / || /^Anything you write below is added to your agent/ \
         || /^Updates never change this file\. For example:/ || /^or topics to keep out of voice replies\./ || /^[[:space:]]*$/) \
       { started = 1; print }' "$DIR/my-instructions.md" > "$WORK/my-instructions" 2>>"$LOG" || true
  if [[ -s "$WORK/my-instructions" ]]; then
    { printf '\n## Moved from my-instructions.md\n'; cat "$WORK/my-instructions"; } >> "$DIR/cos/my-rules.md"
    ok "Your instructions from my-instructions.md are now in cos/my-rules.md"
  fi
  mv -f "$DIR/my-instructions.md" "$DIR/my-instructions.md.bak"
fi
# The notebook page's builder and template, the defaults, and the list of everything the agent
# can do (options.md, for /cos:settings): replaced on every update.
for f in build-brain.sh brain-template.html defaults.md options.md notebook-server.mjs whats-new.md; do
  if [[ -f "$TEMPLATES/dotcos/$f" ]]; then cp "$TEMPLATES/dotcos/$f" "$DIR/.cos/$f"; fi
done
chmod +x "$DIR/.cos/build-brain.sh" 2>/dev/null || true
# CLAUDE.md is generated and replaced on every update; the user's own instructions live in
# cos/my-rules.md, which CLAUDE.md pulls in and nothing here ever overwrites. A CLAUDE.md
# from before this split (no "Generated by" line) may hold the user's edits: keep a copy.
if [[ -e "$DIR/CLAUDE.md" ]] && ! grep -q 'Generated by the Chief of Staff installer' "$DIR/CLAUDE.md"; then
  cp "$DIR/CLAUDE.md" "$DIR/CLAUDE.md.bak"
  warn "Your previous CLAUDE.md is saved as CLAUDE.md.bak. If you added your own instructions"
  warn "to it, move them into cos/my-rules.md, where updates won't touch them."
fi
fill "$TEMPLATES/CLAUDE.md" "$DIR/CLAUDE.md" AGENT_NAME="$AGENT_NAME" OWNER_NAME="$OWNER_NAME"
if [[ -e "$DIR/.claude/settings.json" ]]; then
  if jq -s '.[0] as $t | .[1] | .permissions.allow = ((.permissions.allow // []) + ($t.permissions.allow // []) | unique)
              | .permissions.deny = ((.permissions.deny // []) + ($t.permissions.deny // []) | unique)' \
       "$TEMPLATES/settings.json" "$DIR/.claude/settings.json" > "$WORK/settings.json" 2>>"$LOG"; then
    mv "$WORK/settings.json" "$DIR/.claude/settings.json"
  else
    warn "Couldn't read the folder's .claude/settings.json, so it was left as it was."
  fi
else
  cp "$TEMPLATES/settings.json" "$DIR/.claude/settings.json"
fi
touch "$DIR/.gitignore"
while IFS= read -r line; do
  grep -qxF -- "$line" "$DIR/.gitignore" || printf '%s\n' "$line" >> "$DIR/.gitignore"
done < "$TEMPLATES/gitignore"
for s in start-cos.sh nightly.sh update-cos.sh cv-channel-log.sh open-brain.sh; do
  [[ -f "$TEMPLATES/$s" ]] || continue
  fill "$TEMPLATES/$s" "$WORK/$s" AGENT_NAME="$SCRIPT_NAME" CLAUDE_BIN="$CLAUDE_BIN" \
    CHANNEL_ARGS="$CHANNEL_ARGS" REMOTE_ARGS="$REMOTE_ARGS"
  if [[ -e "$DIR/$s" ]] && ! cmp -s "$WORK/$s" "$DIR/$s"; then cp "$DIR/$s" "$DIR/$s.bak"; fi
  mv "$WORK/$s" "$DIR/$s"; chmod +x "$DIR/$s"
done
OLD_VERSION=$(cat "$DIR/cos/.version" 2>/dev/null || true)   # for "What's new" after an update
printf '%s\n' "$COS_VERSION" > "$DIR/cos/.version"
if [[ -n "$NEW_AGENT" ]]; then printf 'stage: not-started\n' > "$DIR/cos/.onboarding-pending"; fi
LEFT=$(cd "$DIR" && grep -l '{{' CLAUDE.md start-cos.sh nightly.sh .claude/settings.json </dev/null 2>/dev/null || true)
rm -f "$DIR/cos/.update-check"   # the version just changed, so check again next start
[[ -z "$LEFT" ]] || die "Setting up the folder left blanks in: $LEFT. Run this again; the details are in $LOG_SHOWN."
ok "Instructions, notes, settings and start script in $(shown "$DIR")"
if [[ -n "$OWNER_ALLOWED" ]]; then ok "Your Carbon Voice account can message $AGENT_NAME, with no pairing code needed"; fi

# ---------- check the agent's note-keeping ----------
# Runs the cos plugin's two hooks the way Claude will: the start-up one must load the agent's
# notes, and the pre-compaction one must keep tokens out of saved transcripts. Test data only,
# removed afterwards.
step "Checking your agent's note-keeping"
HOOKS_OK=1
OUT=$(printf '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$DIR" bash "$PLUGIN_ROOT/scripts/session-start.sh" 2>>"$LOG" || true)
[[ "$OUT" == *"Chief-of-staff state"* ]] || HOOKS_OK=""
if [[ -n "$NEW_AGENT" && "$OUT" != *"Onboarding not finished"* ]]; then HOOKS_OK=""; fi
printf '{"text":"/cv-channel:configure abc123secret"}\n' > "$WORK/transcript.jsonl"
DAYLOG="$DIR/cos/log/$(date '+%Y-%m-%d').md"; HAD_DAYLOG=""; [[ -e "$DAYLOG" ]] && HAD_DAYLOG=1
printf '{"transcript_path":"%s","session_id":"setupchk"}' "$WORK/transcript.jsonl" \
  | CLAUDE_PROJECT_DIR="$DIR" bash "$PLUGIN_ROOT/scripts/pre-compact.sh" >>"$LOG" 2>&1 || true
ARCHIVE=$(cat "$DIR/cos/.pending-reconcile" 2>/dev/null || true)
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]] || ! grep -q '\[REDACTED\]' "$ARCHIVE" || grep -q abc123secret "$ARCHIVE"; then HOOKS_OK=""; fi
if [[ -n "$ARCHIVE" ]]; then
  rm -f "$ARCHIVE"
  if [[ -e "$DAYLOG" ]]; then
    grep -vF -- "$(basename "$ARCHIVE")" "$DAYLOG" > "$WORK/daylog" || true
    if [[ -z "$HAD_DAYLOG" && ! -s "$WORK/daylog" ]]; then rm -f "$DAYLOG"; else mv "$WORK/daylog" "$DAYLOG"; fi
  fi
fi
rm -f "$DIR/cos/.pending-reconcile"
if [[ -n "$HOOKS_OK" ]]; then ok "Notes load when your agent starts, and tokens stay out of saved transcripts"
else warn "The note-keeping check didn't pass. Your agent will still start; run /cos:doctor in its folder for details."; fi
# The notebook page: everything the agent knows, built from cos/. It's rebuilt whenever the agent
# changes a note; build it now so the link works straight away.
BRAIN_LINK=""
if (cd "$DIR" && .cos/build-brain.sh </dev/null 2>>"$LOG"); then ok "Notebook page built"
else warn "Couldn't build the notebook page. Your agent will still start; run /cos:doctor in its folder for details."; fi

# ---------- nightly review ----------
step "Nightly review"
NIGHTLY=""; WANT_NIGHTLY=$(saved NIGHTLY)
if [[ $MODE == setup || -z "$WANT_NIGHTLY" ]]; then
  echo "  Every night at 2:15 your agent reviews its notes, tidies them and flags anything stale,"
  echo "  in a run separate from the live session. This adds a scheduled job to your computer"
  if [[ "$PLATFORM" == mac ]]; then echo "  (a file in ~/Library/LaunchAgents/), which you can remove anytime."
  else echo "  (a line in your crontab), which you can remove anytime."; fi
  if yes "  Set up the nightly review? [Y/n]"; then WANT_NIGHTLY=1; else WANT_NIGHTLY=0; fi
fi
if [[ "$WANT_NIGHTLY" == 1 ]]; then
  JOB_PATH="$(dirname "$CLAUDE_BIN"):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
  if [[ "$PLATFORM" == mac ]]; then
    LABEL="com.phononx.cos.$(basename "$DIR")"; PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    fill "$TEMPLATES/launchd.plist" "$PLIST" JOB_LABEL="$(xml "$LABEL")" WORKSPACE="$(xml "$DIR")" PATH="$(xml "$JOB_PATH")"
    launchctl bootout "gui/$(id -u)/$LABEL" </dev/null >/dev/null 2>&1 || true   # a re-run replaces it
    if launchctl bootstrap "gui/$(id -u)" "$PLIST" </dev/null >>"$LOG" 2>&1; then NIGHTLY=1
    else warn "Couldn't schedule the nightly review. The details are in $LOG_SHOWN."; fi
  elif have crontab; then
    CRON_CMD="cd \"$DIR\" && /bin/bash ./nightly.sh"
    if { crontab -l 2>/dev/null | grep -vF -- "$CRON_CMD" || true; echo "15 2 * * * $CRON_CMD"; } | crontab - 2>>"$LOG"; then NIGHTLY=1
    else warn "Couldn't schedule the nightly review. The details are in $LOG_SHOWN."; fi
  else
    warn "This computer has no crontab, so the nightly review wasn't scheduled."
  fi
  if [[ -n "$NIGHTLY" ]]; then ok "Scheduled for 2:15 every night"; fi
elif [[ $MODE == update ]]; then
  info "Off, as chosen at setup. To turn it on, set NIGHTLY=1 in cos/setup.conf and run ./update-cos.sh."
else
  info "Skipped. Run this setup again to add it later."
fi

# ---------- a launcher ----------
# An app that opens Terminal and starts the agent, or, if it's already running, just brings
# Terminal forward, and "<agent> Notebook", which opens its notebook page: in Applications on a
# Mac (so Finder, Spotlight, Launchpad and the Dock find them), the agent optionally on the
# Desktop too; .desktop files on Linux. Rebuilt by every update, so they keep pointing at this
# folder.
WANT_APP=$(saved APP); WANT_DESKTOP=$(saved DESKTOP); LAUNCHER=""; LAUNCHER_WHERE=""; NOTEBOOK_APP=""; NOTEBOOK_NEW=""
if [[ -z "$WANT_APP" ]]; then
  step "Launcher"
  if [[ "$PLATFORM" == mac ]]; then
    echo "  You can start $AGENT_NAME like any app: from Spotlight, Launchpad or the Dock. It opens"
    echo "  Terminal and starts it, or brings it forward if it's already running. $AGENT_NAME Notebook"
    echo "  opens your notebook page the same way."
    if yes "  Add $AGENT_NAME and $AGENT_NAME Notebook to your Applications? [Y/n]"; then WANT_APP=1; else WANT_APP=0; fi
  else
    if yes "  Add $AGENT_NAME and $AGENT_NAME Notebook to your applications menu? [Y/n]"; then WANT_APP=1; else WANT_APP=0; fi
  fi
  if [[ $WANT_APP == 1 && -z "$WANT_DESKTOP" ]]; then
    if no "  Put it on your Desktop too? [y/N]"; then WANT_DESKTOP=0; else WANT_DESKTOP=1; fi
  fi
fi
if [[ "$WANT_APP" == 1 ]]; then
  if make_launcher; then
    if [[ $MODE == setup || -z "$(saved APP)" ]]; then ok "Added $AGENT_NAME to $LAUNCHER_WHERE: $(shown "$LAUNCHER")"; fi
    if [[ -n "$NOTEBOOK_APP" && ( $MODE == setup || -n "$NOTEBOOK_NEW" ) ]]; then
      ok "Added $AGENT_NAME Notebook, which opens your notebook page: $(shown "$NOTEBOOK_APP")"
    fi
  else
    warn "Couldn't add the launcher. You can still start $AGENT_NAME with ./start-cos.sh."; WANT_APP=0
  fi
fi

# ---------- the notebook server: its key and port ----------
# The key (in the notebook's address, and needed for every change) is made once and kept. The
# port is fixed per agent, so the address can be bookmarked: picked from the folder's path, and
# moved along if something else already uses it.
NB_KEY_FILE="$CV_DIR/notebook.key"
if [[ ! -s "$NB_KEY_FILE" ]]; then
  (umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$NB_KEY_FILE")
fi
chmod 600 "$NB_KEY_FILE" 2>/dev/null || true
NOTEBOOK_PORT=$(saved NOTEBOOK_PORT)
if [[ ! "$NOTEBOOK_PORT" =~ ^[0-9]+$ ]]; then
  NOTEBOOK_PORT=$(( 41000 + $(printf '%s' "$DIR" | cksum | cut -d' ' -f1) % 2000 ))
  for try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$NOTEBOOK_PORT") 2>/dev/null; then break; fi
    NOTEBOOK_PORT=$((NOTEBOOK_PORT + 1))
  done
fi

# Save the answers, so ./update-cos.sh can update this agent without asking again.
ALLOW_CREATOR=${ALLOW_CREATOR:-$(saved ALLOW_CREATOR)}   # read before the file is rewritten
{
  echo "# Your answers to setup. ./update-cos.sh reuses them; you can edit them (1 = yes, 0 = no)."
  echo "OWNER_NAME=$OWNER_NAME"
  echo "AGENT_NAME=$AGENT_NAME"
  echo "TEAM=$([ -n "$TEAM" ] && echo 1 || echo 0)"
  echo "REMOTE=$([ -n "$REMOTE_ARGS" ] && echo 1 || echo 0)"
  echo "NIGHTLY=$([ -n "$NIGHTLY" ] && echo 1 || echo 0)"
  echo "APP=${WANT_APP:-0}"
  echo "DESKTOP=${WANT_DESKTOP:-0}"
  echo "NOTEBOOK_PORT=$NOTEBOOK_PORT"
  if [[ -n "$ALLOW_CREATOR" ]]; then echo "ALLOW_CREATOR=$ALLOW_CREATOR"; fi
} > "$DIR/cos/setup.conf"

# ---------- the notebook server: always on ----------
# Serves the notebook page at http://localhost:<port>/?k=<key> and saves edits made on it. Runs
# at login and is restarted if it stops: a launchd job on a Mac, a systemd user service on Linux
# (or, without systemd, a crontab @reboot line). Restarted here so an update takes effect.
NOTEBOOK=""
if install_notebook_server; then
  NOTEBOOK=1
  ok "Your notebook is always on at http://localhost:$NOTEBOOK_PORT/ (the address with its key comes next)"
else
  warn "Couldn't start the notebook server, so your notebook opens read-only for now. Run /cos:doctor in"
  warn "your agent's folder for details."
fi
BRAIN_LINK=$(cd "$DIR" && ./open-brain.sh --link </dev/null 2>>"$LOG" || true)

# ---------- hand off ----------
# First what was set up (to read), then numbered steps (to do), then the line that starts it.
if [[ $MODE == update ]]; then
  step "$AGENT_NAME is up to date."
  printf '  %-20s %s\n' "Your agent's folder:" "$(shown "$DIR")"
  printf '  %-20s %s\n' "Version:" "${COS_VERSION:-unknown}"
  printf '  %-20s %s\n' "Claude app:" "$([ -n "$REMOTE_ARGS" ] && echo "on" || echo "off")"
  printf '  %-20s %s\n' "Nightly review:" "$([ -n "$NIGHTLY" ] && echo "2:15 every night" || echo "off")"
  echo
  whats_new
  show_notebook "Your notes were kept; anything new shows up there too."
  echo "  If $AGENT_NAME is running, restart it to use the update: in its window, type /exit,"
  echo "  then run ./start-cos.sh."
  printf '  To start it now:  %scd %s && ./start-cos.sh%s\n' "$bold" "$(shown "$DIR")" "$reset"
  echo
  return 0
fi
step "Your agent is ready."
ACCOUNT=$(account_name)
CD_PATH=$(shown "$DIR")
if [[ "$DIR" == *[[:space:]]* ]]; then CD_PATH="\"$DIR\""; fi
# Number the steps first, so the summary can point at the pairing step.
DEV_STEP=""; if [[ -z "$TEAM" ]]; then DEV_STEP=3; fi
MSG_STEP=$(( ${DEV_STEP:-2} + 1 ))
if [[ -n "$OWNER_ALLOWED" ]]; then WHO="$bold$green""your Carbon Voice account""$reset"
else WHO="$bold$yellow""nobody yet: you'll pair your account in step $((MSG_STEP + 1))""$reset"; fi
printf '  %-20s %s\n' "Your agent's folder:" "$(val "$(shown "$DIR")")"
printf '  %-20s %s\n' "Your agent:" "$(val "$AGENT_NAME")"
printf '  %-20s %s%s\n' "Claude account:" "$(val "${ACCOUNT:-your Claude account}")" "${PLAN:+ ($PLAN plan)}"
printf '  %-20s %s\n' "Who can message it:" "$WHO"
printf '  %-20s %s\n' "Claude app:" "$([ -n "$REMOTE_ARGS" ] && echo "on" || echo "off")"
printf '  %-20s %s\n' "Nightly review:" "$([ -n "$NIGHTLY" ] && echo "2:15 every night" || echo "off")"
echo
show_notebook "It's nearly empty now: it fills in as you talk to $AGENT_NAME, starting with the short conversation it has with you first."
printf '  %sTo start talking to %s:%s\n' "$bold" "$AGENT_NAME" "$reset"
echo "    1. Start $AGENT_NAME by running the line below. Keep that window open while you use it."
printf '    2. Claude asks whether you trust this folder. Choose %s.\n' "$(hl '"Yes, I trust this folder"')"
if [[ -n "$DEV_STEP" ]]; then
  # Pro/Max start with --dangerously-load-development-channels, because cv-channel isn't on
  # Anthropic's approved channels list yet; Claude Code asks to confirm that on every start.
  echo "    3. Claude warns about loading a development channel, because the Carbon Voice connection"
  printf "       isn't on Anthropic's approved list yet. Choose %s.\n" "$(hl '"I am using this for local development"')"
fi
if [[ -n "$OWNER_ALLOWED" ]]; then
  printf '    %s. In Carbon Voice, message %s from your own account. It starts a short voice\n' "$MSG_STEP" "$(val "$AGENT_NAME")"
  echo "       conversation to learn about your work."
else
  printf "    %s. In Carbon Voice, message %s from your own account. You'll get a pairing code back.\n" "$MSG_STEP" "$(val "$AGENT_NAME")"
  printf '    %s. In the Claude window, type  %s  and press Return.\n' "$((MSG_STEP + 1))" "$(hl '/cv-channel:access pair <code>')"
  echo "       Then message $AGENT_NAME again. It starts a short voice conversation to learn about your work."
fi
echo
if [[ -n "$REMOTE_ARGS" ]]; then
  echo "  To watch from your phone, open the Claude app and tap Code. Make sure the app is in"
  printf "  %s, or your agent won't appear there. No app yet? Type %s once Claude starts.\n" \
    "$(val "${ORG:-the same account as Claude Code}")" "$(hl /mobile)"
  echo
fi
# The user starts the agent themselves. Starting it from here (exec ./start-cos.sh </dev/tty)
# froze Claude under `curl ... | bash`.
printf '  Start %s now:  %s\n' "$AGENT_NAME" "$(hl "cd $CD_PATH && ./start-cos.sh")"
if [[ -n "$LAUNCHER" ]]; then printf '  Next time, you can also open it from %s.\n' "$LAUNCHER_WHERE"; fi
echo
}

main "$@"
