#!/usr/bin/env bash
# PostToolUse (cv-channel's send_message): remember the Carbon Voice conversation and message the
# agent last replied in, in cos/.cv-thread. Scheduled briefs have no incoming message to answer,
# and cv-channel needs both to send one, so they go there.
# The plugin is usually installed at user scope, so this MUST do nothing outside a cos workspace.
set -uo pipefail
DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -f "$DIR/cos/.version" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
CHANNEL=$(printf '%s' "$INPUT" | jq -r '.tool_input.channel_id // empty' 2>/dev/null)
REPLY_TO=$(printf '%s' "$INPUT" | jq -r '.tool_input.reply_to_message_id // empty' 2>/dev/null)
[[ -n "$CHANNEL" && -n "$REPLY_TO" ]] || exit 0
printf 'channel_id: %s\nreply_to_message_id: %s\nupdated: %s\n' "$CHANNEL" "$REPLY_TO" "$(date '+%Y-%m-%d %H:%M')" \
  > "$DIR/cos/.cv-thread.tmp" && mv -f "$DIR/cos/.cv-thread.tmp" "$DIR/cos/.cv-thread"
exit 0
