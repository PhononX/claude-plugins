#!/usr/bin/env bash
# Opens {{AGENT_NAME}}'s notebook page: everything your chief of staff knows, built from the
# notes in cos/. The page is rebuilt whenever {{AGENT_NAME}} changes a note, and refreshes itself
# while it's open, so a bookmark to it stays current.
#   ./open-brain.sh          rebuild the page and open it in your browser
#   ./open-brain.sh --link   rebuild it and print its link, without opening it
set -euo pipefail
cd "$(dirname "$0")"
LINK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --link) LINK_ONLY=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done
[[ -x .cos/build-brain.sh ]] || { echo "The notebook page's files are missing. Run ./update-cos.sh to restore them."; exit 1; }
.cos/build-brain.sh || { echo "Couldn't build the notebook page."; exit 1; }

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
LINK="file://$(url_path "$PWD/brain.html")"

if [[ $LINK_ONLY == 1 ]]; then echo "$LINK"; exit 0; fi
echo "Your notebook page: $LINK"
echo "Bookmark it: the page stays at this address and keeps itself up to date."
echo "It holds all your notes, so don't email it or post it anywhere."
if command -v open >/dev/null 2>&1 && [[ "$(uname)" == Darwin ]]; then open brain.html
elif command -v xdg-open >/dev/null 2>&1; then xdg-open brain.html >/dev/null 2>&1 &
fi
