#!/usr/bin/env bash
# Opens {{AGENT_NAME}}'s notebook page: everything your chief of staff knows, built from the
# notes in cos/. It's served on this computer by the notebook server, so you can check things off
# and edit notes on it; the server starts at login, and this starts it if it isn't running. The
# address stays the same, so bookmark it.
#   ./open-brain.sh          open your notebook in your browser
#   ./open-brain.sh --link   print its address, without opening it
set -euo pipefail
cd "$(dirname "$0")"
LINK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --link) LINK_ONLY=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done
export PATH="$HOME/.local/bin:$PATH"
[[ -x .cos/build-brain.sh ]] || { echo "The notebook page's files are missing. Run ./update-cos.sh to restore them."; exit 1; }
.cos/build-brain.sh || { echo "Couldn't build the notebook page."; exit 1; }

# The notebook server, if this folder has one: its port (cos/setup.conf) and key (.cv/notebook.key).
PORT=$(sed -n 's/^NOTEBOOK_PORT=//p' cos/setup.conf 2>/dev/null | head -1)
KEY=$(tr -d '\n' < .cv/notebook.key 2>/dev/null || true)
notebook_up() { curl -fs --max-time 1 "http://localhost:$PORT/health" >/dev/null 2>&1 </dev/null; }
start_notebook() {
  local i
  notebook_up && return 0
  command -v node >/dev/null 2>&1 && [[ -f .cos/notebook-server.mjs ]] || return 1
  nohup node "$PWD/.cos/notebook-server.mjs" >> .cv/notebook-server.log 2>&1 </dev/null &
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do sleep 0.2; notebook_up && return 0; done
  return 1
}

# The page's address, with anything unusual in the folder path (like spaces) encoded.
url_path() {
  printf '%s' "$1" | od -An -tx1 -v | awk '{
    for (i = 1; i <= NF; i++) {
      h = toupper($i); n = index("0123456789ABCDEF", substr(h, 1, 1)) * 16 + index("0123456789ABCDEF", substr(h, 2, 1)) - 17
      if ((n >= 48 && n <= 57) || (n >= 65 && n <= 90) || (n >= 97 && n <= 122) || n == 47 || n == 46 || n == 95 || n == 126 || n == 45)
        printf "%c", n
      else
        printf "%%%s", h
    }
  }'
}
LIVE=""
if [[ -n "$PORT" && ${#KEY} -ge 32 ]] && start_notebook; then LIVE="http://localhost:$PORT/?k=$KEY"; fi
LINK=${LIVE:-"file://$(url_path "$PWD/brain.html")"}

if [[ $LINK_ONLY == 1 ]]; then echo "$LINK"; exit 0; fi
echo "Your notebook: $LINK"
if [[ -n "$LIVE" ]]; then
  echo "Bookmark it: it stays at this address, updates as {{AGENT_NAME}} works, and you can check things"
  echo "off and edit notes on it. The address includes its key, so don't share it."
else
  echo "This is a read-only copy (the notebook server isn't running; ./update-cos.sh sets it up)."
  echo "It holds all your notes, so don't email it or post it anywhere."
fi
if command -v open >/dev/null 2>&1 && [[ "$(uname)" == Darwin ]]; then open "$LINK"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$LINK" >/dev/null 2>&1 &
fi
