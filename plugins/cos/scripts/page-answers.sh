#!/usr/bin/env bash
# What the user did on the notebook page that the agent hasn't acted on yet: lines in cos/ with
# [answer:: …], and items they added to cos/inbox.md there. Run at session start and before every
# prompt (including Carbon Voice messages and scheduled briefs), so a session that's been running
# for hours still sees them. Prints nothing when there's nothing, or outside a cos workspace.
set -uo pipefail
COS="${CLAUDE_PROJECT_DIR:-$PWD}/cos"
[[ -d "$COS" && -f "$COS/.version" ]] || exit 0
answers=$(grep -rn --include='*.md' --exclude-dir=archive --exclude-dir=log --exclude-dir=.history \
  -F '[answer::' "$COS" 2>/dev/null | head -20)
added=$(grep -n -F '[src:: page' "$COS/inbox.md" 2>/dev/null | head -20)
[[ -n "$answers$added" ]] || exit 0
echo "From the notebook page, not acted on yet (see \"answers on the page\" in CLAUDE.md):"
while IFS= read -r l; do [[ -n "$l" ]] && printf '  answered: cos/%s\n' "${l#"$COS/"}"; done <<< "$answers"
while IFS= read -r l; do [[ -n "$l" ]] && printf '  added to the inbox: cos/inbox.md:%s\n' "$l"; done <<< "$added"
exit 0
