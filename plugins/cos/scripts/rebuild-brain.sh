#!/usr/bin/env bash
# PostToolUse (Write/Edit): after the agent changes a note in cos/, rebuild the notebook page
# (brain.html), so it's current the next time it's opened or refreshes itself.
# The plugin is usually installed at user scope, so this MUST do nothing outside a cos workspace.
set -uo pipefail
DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -f "$DIR/cos/.version" && -x "$DIR/.cos/build-brain.sh" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in
  "$DIR"/cos/*|cos/*|./cos/*) ;;
  *) exit 0 ;;
esac
"$DIR/.cos/build-brain.sh" >/dev/null 2>&1 || true
exit 0
