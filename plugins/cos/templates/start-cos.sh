#!/usr/bin/env bash
# Starts {{AGENT_NAME}}, your chief of staff, connected to Carbon Voice.
#   ./start-cos.sh               run in this window (closing the window stops it)
#   ./start-cos.sh --background  keep running after the window closes (needs tmux);
#                                run the same command again to reconnect
#   ./start-cos.sh --reset-token replace the saved Carbon Voice token
#   ./start-cos.sh --no-remote   don't show this session in the Claude app this time
# Options can be combined, e.g. ./start-cos.sh --background --no-remote
set -euo pipefail
BACKGROUND=0; RESET=0; REMOTE=({{REMOTE_ARGS}})
for arg in "$@"; do
  case "$arg" in
    --background) BACKGROUND=1 ;;
    --reset-token) RESET=1 ;;
    --no-remote) REMOTE=() ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
# Use the Claude plan sign-in, never an API key that happens to be set in the shell.
unset ANTHROPIC_API_KEY
CV_DIR="$PWD/.cv"
mkdir -p "$CV_DIR" && chmod 700 "$CV_DIR"

if [[ $RESET == 1 ]]; then rm -f "$CV_DIR/.env"; fi
if [[ ! -s "$CV_DIR/.env" ]]; then
  echo "Paste the Personal Access Token for your Carbon Voice Agent Account."
  echo "(It's hidden as you type and saved only in this folder.)"
  read -rsp "Token: " PAT; echo
  [[ -n "$PAT" ]] || { echo "No token entered."; exit 1; }
  umask 077; printf 'CV_PAT=%s\n' "$PAT" > "$CV_DIR/.env"; unset PAT
fi

set -a; source "$CV_DIR/.env"; set +a
# Per-folder channel state, so each workspace is its own agent with its own allowlist and cursor.
export CV_ENV_PATH="$CV_DIR/.env"
export CV_STATE_PATH="$CV_DIR/state.json"
export CV_ACCESS_PATH="$CV_DIR/access.json"
export CV_PENDING_PATH="$CV_DIR/pending.json"
export CV_ATTACHMENTS_DIR="$CV_DIR/attachments"
export CV_PROJECT_NAME="{{AGENT_NAME}}"

CMD=("{{CLAUDE_BIN}}" {{CHANNEL_ARGS}} ${REMOTE[@]+"${REMOTE[@]}"})

if [[ $BACKGROUND == 1 ]]; then
  command -v tmux >/dev/null || { echo "tmux is not installed. Run without --background."; exit 1; }
  exec tmux new-session -A -s "cos-$(basename "$PWD")" "${CMD[@]}"
else
  echo "Starting {{AGENT_NAME}}. Keep this window open."
  [[ ${#REMOTE[@]} -gt 0 ]] && echo "To watch from your phone: Claude app → Code → this session. (No app? Type /mobile once Claude starts.)"
  exec "${CMD[@]}"
fi
