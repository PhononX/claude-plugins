#!/usr/bin/env bash
# SessionStart: inject chief-of-staff state. Anything on stdout is added to Claude's context.
# The plugin is usually installed at user scope, so this MUST do nothing outside a cos workspace.
set -uo pipefail
COS="${CLAUDE_PROJECT_DIR:-$PWD}/cos"
[[ -d "$COS" && -f "$COS/.version" ]] || exit 0
command -v jq >/dev/null 2>&1 || { echo "cos: jq is not installed; run /cos:doctor" >&2; exit 0; }

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')
# Only the live session, started by ./start-cos.sh, is connected to Carbon Voice. The nightly
# review runs headless without it, and must not schedule briefs or send anything.
LIVE=""; [[ -n "${CV_ACCESS_PATH:-}" ]] && LIVE=1

# setting <key> <default>: a setting from the front matter of cos/my-rules.md.
setting() {
  local v
  v=$(awk -v k="$1" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
        NR > 1 { i = index($0, ":"); if (i && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); gsub(/^[ \t"]+|[ \t"]+$/, "", v); print v; exit } }' \
      "$COS/my-rules.md" 2>/dev/null)
  printf '%s' "${v:-$2}"
}
# show <file> [max lines]: a notes file, trimmed so a long one can't crowd the context.
show() {
  local f=$1 max=${2:-80} n
  echo; echo "### cos/$f"
  if [[ ! -f "$COS/$f" ]]; then echo "(missing)"; return; fi
  n=$(wc -l < "$COS/$f" | tr -d ' ')
  head -n "$max" "$COS/$f"
  if [[ $n -gt $max ]]; then echo "(… $((n - max)) more lines in cos/$f)"; fi
}

echo "## Chief-of-staff state (loaded $(date '+%a %Y-%m-%d %H:%M'))"
show now.md 60
TODAY=$(date '+%Y-%m-%d')
BRIEF_DATE=$(awk 'NR > 1 && /^---/ { exit } /^date:/ { gsub(/^date:[ \t"]*|[ \t"]+$/, ""); print; exit }' "$COS/brief.md" 2>/dev/null)
if [[ "$BRIEF_DATE" == "$TODAY" ]]; then show brief.md 60; fi
show actions.md 60
show waiting.md 40
if [[ -s "$COS/nudges.md" ]]; then
  echo; echo "### cos/nudges.md (from the last nightly review)"; cat "$COS/nudges.md"
fi
# Drafts in progress, one line each, so "the board narrative" means something straight away.
DRAFTS=""
for f in "$COS"/drafts/*.md; do
  [[ -f "$f" ]] || continue
  line=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
      NR > 1 { i = index($0, ":"); if (i) { k = substr($0, 1, i - 1); v = substr($0, i + 1); gsub(/^[ \t"]+|[ \t"]+$/, "", v); m[k] = v } }
      END { if (m["status"] != "moved" && m["status"] != "done" && m["status"] != "dropped")
              printf "%s, %s%s", (m["kind"] ? m["kind"] : "draft"), (m["status"] ? m["status"] : "notes"), (m["due"] ? ", due " m["due"] : "") }' "$f")
  if [[ -n "$line" ]]; then DRAFTS="$DRAFTS- $(basename "$f" .md) ($line)"$'\n'; fi
done
if [[ -n "$DRAFTS" ]]; then echo; echo "### Drafts in progress (cos/drafts/)"; printf '%s' "$DRAFTS"; fi
INBOX=$(grep -c '^- ' "$COS/inbox.md" 2>/dev/null || true)
if [[ "${INBOX:-0}" -gt 0 ]]; then echo; echo "cos/inbox.md has $INBOX unsorted item(s)."; fi

# Notes from before the current layout (0.1.x) are moved over by the cos:migrate skill.
if [[ ! -f "$COS/.layout" && ( -f "$COS/open-loops.md" || -f "$COS/people.md" ) ]]; then
  echo
  echo "### Notes need moving to the new layout"
  echo "cos/ still has notes in the old layout (open-loops.md, people.md). Before anything else,"
  echo "quietly use the cos:migrate skill."
fi

if [[ -f "$COS/.onboarding-pending" ]]; then
  echo
  echo "### Onboarding not finished"
  echo "The next message from an allowed Carbon Voice sender starts (or resumes) onboarding."
  echo "Use the cos:onboard skill. Progress so far, if any, is in cos/.onboarding-pending."
fi

# Briefs run as scheduled tasks inside this live session: only the next one is scheduled, as a
# one-time task, and scheduled tasks end with the session, so check on every start. If the most
# recent brief due today (in the last 6 hours) hasn't gone out, send it now.
if [[ -n "$LIVE" && ! -f "$COS/.onboarding-pending" ]]; then
  # One line per brief, "HH:MM|days|name", from "## My briefs" in my-rules.md, or the older
  # brief_time and brief_days settings.
  BRIEFS=$(awk '/^## / { inb = ($0 == "## My briefs"); next }
      inb && /^- / {
        line = substr($0, 3); name = line; sub(/[ \t]*\[.*$/, "", name)
        at = ""; days = "weekdays"
        if (match(line, /\[at::[^]]*\]/)) { at = substr(line, RSTART + 5, RLENGTH - 6) }
        if (match(line, /\[days::[^]]*\]/)) { days = substr(line, RSTART + 7, RLENGTH - 8) }
        gsub(/^[ \t]+|[ \t]+$/, "", at); gsub(/^[ \t]+|[ \t]+$/, "", days)
        if (name != "" && at != "") print at "|" days "|" name
      }' "$COS/my-rules.md" 2>/dev/null)
  if [[ -z "$BRIEFS" ]] && ! grep -q '^## My briefs' "$COS/my-rules.md" 2>/dev/null; then
    BRIEFS="$(setting brief_time 07:00)|$(setting brief_days weekdays)|Morning brief"
  fi
  # runs_today <days>: does a brief with these days run today?
  runs_today() {
    local d u names
    d=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]'); u=$(date '+%u')
    case "$d" in
      off|never|"") return 1 ;;
      daily|"every day"|everyday) return 0 ;;
      weekdays) [[ $u -le 5 ]]; return ;;
      weekends) [[ $u -ge 6 ]]; return ;;
    esac
    names=(mon tue wed thu fri sat sun)
    [[ ",$(printf '%s' "$d" | tr -d ' ')," == *",${names[u-1]}"* ]]
  }
  if [[ -n "$BRIEFS" ]]; then
    echo
    echo "### Briefs"
    echo "From cos/my-rules.md:"
    printf '%s\n' "$BRIEFS" | while IFS='|' read -r at days name; do echo "- $name at $at ($days)"; done
    echo "Make sure the next one is scheduled, as \"Scheduling\" in the cos:brief skill describes."
    echo "Don't mention this unless it fails."
    NOW_MIN=$((10#$(date '+%H') * 60 + 10#$(date '+%M')))
    LATEST=""; LATEST_MIN=-1
    while IFS='|' read -r at days name; do
      [[ "$at" =~ ^([0-9]{1,2}):([0-9]{2})$ ]] || continue
      m=$((10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]}))
      if runs_today "$days" && [[ $m -le $NOW_MIN && $((NOW_MIN - m)) -le 360 && $m -gt $LATEST_MIN ]]; then
        LATEST=$name; LATEST_AT=$at; LATEST_MIN=$m
      fi
    done <<< "$BRIEFS"
    if [[ -n "$LATEST" ]] && ! { [[ "$BRIEF_DATE" == "$TODAY" ]] && grep -qF "## $LATEST [sent::" "$COS/brief.md"; }; then
      echo "The $LATEST (due at $LATEST_AT) hasn't gone out today. Once Carbon Voice is connected,"
      echo "use the cos:brief skill to send it now."
    fi
  fi
fi

if [[ "$SOURCE" == "compact" && -f "$COS/.pending-reconcile" ]]; then
  ARCHIVE=$(cat "$COS/.pending-reconcile")
  echo
  echo "### Post-compaction reconcile"
  echo "Context was just compacted. The pre-compaction transcript is archived at: $ARCHIVE"
  echo "Before your next reply, use the cos:capture skill in reconcile mode on that file."
  rm -f "$COS/.pending-reconcile"
fi
exit 0
