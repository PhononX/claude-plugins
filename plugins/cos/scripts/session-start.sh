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

# The morning brief runs as a scheduled task inside this live session. Scheduled tasks end
# with the session (and repeating ones after 7 days), so check on every start.
if [[ -n "$LIVE" && ! -f "$COS/.onboarding-pending" ]]; then
  BRIEF_TIME=$(setting brief_time 07:00); BRIEF_DAYS=$(setting brief_days weekdays)
  if [[ "$BRIEF_TIME" =~ ^([0-9]{1,2}):([0-9]{2})$ && "$BRIEF_DAYS" != off ]]; then
    H=$((10#${BASH_REMATCH[1]})); M=$((10#${BASH_REMATCH[2]}))
    if [[ "$BRIEF_DAYS" == daily ]]; then DOW='*'; else DOW='1-5'; fi
    echo
    echo "### Morning brief"
    echo "Make sure the morning brief is scheduled: check your scheduled tasks (CronList). If none"
    echo "has the prompt \"Use the cos:brief skill now.\", create a repeating one (CronCreate) with"
    echo "cron \"$M $H * * $DOW\" and that prompt. Don't mention this unless it fails."
    NOW_MIN=$((10#$(date '+%H') * 60 + 10#$(date '+%M'))); DUE_MIN=$((H * 60 + M))
    WEEKDAY=$(date '+%u')
    if [[ "$BRIEF_DATE" != "$TODAY" && $NOW_MIN -ge $DUE_MIN && $NOW_MIN -lt 720 \
          && ( "$BRIEF_DAYS" == daily || $WEEKDAY -le 5 ) ]]; then
      echo "Today's brief hasn't gone out yet (it was due at $BRIEF_TIME). Once Carbon Voice is"
      echo "connected, use the cos:brief skill to send it now."
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
