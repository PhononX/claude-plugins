#!/usr/bin/env bash
# Builds the notebook page, brain.html, from the notes in cos/. No AI and no network: it copies
# the Markdown files, as they are, into brain-template.html, and the page reads them when it
# opens. Installed at <workspace>/.cos/build-brain.sh; run it from anywhere.
# Silent when it works. Does nothing if the workspace isn't set up (no cos/.version).
# Runs on macOS's bash 3.2 and BSD tools as well as Linux.
set -u
umask 077

HERE=$(cd "$(dirname "$0")" && pwd -P) || exit 1
WS=$(dirname "$HERE")
COS="$WS/cos"
TEMPLATE="$HERE/brain-template.html"
OUT="$WS/brain.html"

[ -f "$COS/.version" ] || exit 0
if [ ! -f "$TEMPLATE" ]; then
  echo "build-brain: the page template is missing ($TEMPLATE). Run ./update-cos.sh to restore it." >&2
  exit 1
fi

BLOCK=$(mktemp "${TMPDIR:-/tmp}/cos-brain.XXXXXX") || exit 1
TMP_OUT=$(mktemp "$WS/.brain.html.XXXXXX") || { rm -f "$BLOCK"; exit 1; }
trap 'rm -f "$BLOCK" "$TMP_OUT"' EXIT
trap 'exit 1' HUP INT TERM

# Escapes a note so the browser can't end the <script> element early or switch into comment
# parsing: "</script" (any case) becomes "<\/script" and "<!--" becomes "<\!--". The page
# undoes both. Byte-wise (LC_ALL=C), so UTF-8 passes through untouched.
escape_body() {
  LC_ALL=C awk '
    function esc(s, pat, ins,   out) {
      out = ""
      while (match(s, pat)) {
        out = out substr(s, 1, RSTART) ins substr(s, RSTART + 1, RLENGTH - 1)
        s = substr(s, RSTART + RLENGTH)
      }
      return out s
    }
    { line = esc($0, "<\\/[Ss][Cc][Rr][Ii][Pp][Tt]", "\\"); print esc(line, "<!--", "\\") }
  ' "$1"
}

# One note: <script type="text/markdown" data-path="cos/people/Dana Whitfield.md">...</script>
emit() {
  local rel=$1 file=$2 attr
  attr=$(printf '%s' "$rel" | LC_ALL=C sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')
  printf '<script type="text/markdown" data-path="%s">' "$attr"
  escape_body "$file"
  printf '</script>\n'
}

conf() {
  [ -f "$COS/setup.conf" ] || return 0
  LC_ALL=C sed -n "s/^[[:space:]]*$1=//p" "$COS/setup.conf" | tail -n 1 \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}

{
  cd "$WS" || exit 1

  # Every note in cos/, except chat transcripts, hidden folders (like Obsidian's .trash), and
  # the daily log files, which come next.
  find cos \( -path cos/log/transcripts -o \( -type d -name '.*' \) \) -prune -o -type f -name '*.md' -print0 \
    | LC_ALL=C sort -z \
    | while IFS= read -r -d '' f; do
        case "$f" in
          cos/log/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md) continue ;;
        esac
        emit "$f" "$f"
      done

  # The daily log: the newest 45 days that have a file.
  set -- cos/log/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md
  if [ -f "$1" ]; then
    [ $# -gt 45 ] && shift $(($# - 45))
    for f in "$@"; do emit "$f" "$f"; done
  fi

  [ -f .cos/defaults.md ] && emit ".cos/defaults.md" ".cos/defaults.md"

  AGENT=$(conf AGENT_NAME); [ -n "$AGENT" ] || AGENT="Your agent"
  OWNER=$(conf OWNER_NAME)
  VERSION=$(head -n 1 cos/.version 2>/dev/null | tr -d '[:space:]')
  BUILT=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null | sed 's/\([+-][0-9][0-9]\)\([0-9][0-9]\)$/\1:\2/')
  case "$BUILT" in
    ????-??-??T??:??:??[+-]??:??) ;;
    *) BUILT=$(date '+%Y-%m-%dT%H:%M:%S') ;;
  esac
  OBSIDIAN=false
  if [ -d /Applications/Obsidian.app ] || [ -d "${HOME:-/nonexistent}/Applications/Obsidian.app" ] \
     || command -v obsidian >/dev/null 2>&1; then
    OBSIDIAN=true
  fi
  printf '<script type="application/json" id="cos-meta">'
  # "<" becomes <, so nothing in a name can close the script element.
  jq -n -c --arg agent "$AGENT" --arg owner "$OWNER" --arg version "$VERSION" --arg built "$BUILT" \
    --arg workspace "$WS" --argjson obsidian "$OBSIDIAN" \
    '{agent: $agent, owner: $owner, version: $version, built: $built, workspace: $workspace, obsidian: $obsidian}' \
    | LC_ALL=C sed 's/</\\u003c/g'
  printf '</script>\n'
} > "$BLOCK" || exit 1

# The template with the notes inserted at its <!--COS-NOTES--> line.
BLOCK="$BLOCK" LC_ALL=C awk '
  /^[[:space:]]*<!--COS-NOTES-->[[:space:]]*$/ {
    f = ENVIRON["BLOCK"]
    while ((getline line < f) > 0) print line
    close(f)
    next
  }
  { print }
' "$TEMPLATE" > "$TMP_OUT" || exit 1

chmod 600 "$TMP_OUT" && mv -f "$TMP_OUT" "$OUT" || exit 1
exit 0
