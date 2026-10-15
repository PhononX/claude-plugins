#!/usr/bin/env bash
# SessionStart: inject chief-of-staff state. Anything on stdout is added to Claude's context.
# The plugin is usually installed at user scope, so this MUST do nothing outside a cos workspace.
set -uo pipefail
COS="${CLAUDE_PROJECT_DIR:-$PWD}/cos"
[[ -d "$COS" && -f "$COS/.version" ]] || exit 0
command -v jq >/dev/null 2>&1 || { echo "cos: jq is not installed; run /cos:doctor" >&2; exit 0; }

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')

echo "## Chief-of-staff state (loaded $(date '+%a %Y-%m-%d %H:%M'))"
for f in now.md open-loops.md; do
  echo; echo "### $f"; cat "$COS/$f" 2>/dev/null || echo "(missing)"
done
if [[ -s "$COS/nudges.md" ]]; then
  echo; echo "### nudges.md (from the last nightly review)"; cat "$COS/nudges.md"
fi

if [[ -f "$COS/.onboarding-pending" ]]; then
  echo
  echo "### Onboarding not finished"
  echo "The next message from an allowed Carbon Voice sender starts (or resumes) onboarding."
  echo "Use the cos:onboard skill. Progress so far, if any, is in cos/.onboarding-pending."
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
