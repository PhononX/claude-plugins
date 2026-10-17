#!/usr/bin/env bash
# What the user did on the notebook page that the agent hasn't handled yet: lines in cos/ with
# [answer:: …] (removed once handled), and items they added to cos/inbox.md there.
#   page-answers.sh          plain text, for SessionStart and UserPromptSubmit (scheduled briefs
#                            and typed prompts)
#   page-answers.sh --tool   JSON additionalContext, for PostToolUse on reads of the notebook.
#                            Carbon Voice messages don't reliably fire UserPromptSubmit, but the
#                            agent reads cos/ before it answers one. Said once per session per
#                            change, so it doesn't repeat on every read.
# Prints nothing when there's nothing, or outside a cos workspace.
set -uo pipefail
COS="${CLAUDE_PROJECT_DIR:-$PWD}/cos"
[[ -d "$COS" && -f "$COS/.version" ]] || exit 0
INPUT=$(cat 2>/dev/null || true)
answers=$(grep -rn --include='*.md' --exclude-dir=archive --exclude-dir=log --exclude-dir=.history \
  -F '[answer::' "$COS" 2>/dev/null | head -20)
added=$(grep -n -F '[src:: page' "$COS/inbox.md" 2>/dev/null | head -20)
[[ -n "$answers$added" ]] || exit 0
text="From the notebook page, not handled yet (see \"Answers on the page\" in CLAUDE.md):"
while IFS= read -r l; do [[ -n "$l" ]] && text+=$'\n'"  answered: cos/${l#"$COS/"}"; done <<< "$answers"
while IFS= read -r l; do [[ -n "$l" ]] && text+=$'\n'"  added to the inbox: cos/inbox.md:$l"; done <<< "$added"

if [[ "${1:-}" != --tool ]]; then printf '%s\n' "$text"; exit 0; fi
command -v jq >/dev/null 2>&1 || exit 0
sid=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null | tr -cd 'A-Za-z0-9_-')
seen="${TMPDIR:-/tmp}/cos-page-answers-${sid:-unknown}"
sum=$(printf '%s' "$text" | cksum)
[[ -f "$seen" && "$(cat "$seen" 2>/dev/null)" == "$sum" ]] && exit 0
printf '%s' "$sum" > "$seen" 2>/dev/null || true
jq -n --arg t "$text" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'
