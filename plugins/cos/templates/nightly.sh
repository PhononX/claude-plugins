#!/usr/bin/env bash
# Nightly review for {{AGENT_NAME}}. Scheduled by the Chief of Staff installer (cos-setup.sh).
# Runs headless, without the Carbon Voice channel, so it never competes with the live session.
set -uo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
# Use the Claude plan sign-in, never an API key that happens to be set in the shell.
unset ANTHROPIC_API_KEY
mkdir -p cos/log
LOG=cos/log/nightly-run.log
echo "=== $(date '+%Y-%m-%d %H:%M') start" >> "$LOG"

# VERIFY: confirm this keeps the cv-channel MCP server from starting in the headless run.
NO_CHANNEL='{"enabledPlugins":{"cv-channel@carbonvoice":false}}'

"{{CLAUDE_BIN}}" -p "Use the cos:consolidate skill now." \
  --settings "$NO_CHANNEL" \
  --allowedTools "Read,Edit,Write,Glob,Grep,Bash(grep:*),Bash(date:*),Bash(ls:*),Bash(mkdir:*)" \
  >> "$LOG" 2>&1
STATUS=$?
# newer_setup: prints the newest published Chief of Staff version if it's newer than this
# folder's, or nothing. Asks GitHub at most once a day, with a 2-second limit, and stays quiet
# when offline.
newer_setup() {
  local mine latest
  mine=$(cat cos/.version 2>/dev/null || true)
  if [[ -z "$mine" ]] || ! command -v jq >/dev/null 2>&1; then return 0; fi
  if [[ -z "$(find cos/.update-check -mtime -1 2>/dev/null)" ]]; then
    latest=$(curl -fsS --max-time 2 https://raw.githubusercontent.com/PhononX/claude-plugins/main/.claude-plugin/marketplace.json 2>/dev/null \
      | jq -r '.plugins[]? | select(.name == "cos") | .version // empty' 2>/dev/null || true)
    if [[ -n "$latest" ]]; then printf '%s\n' "$latest" > cos/.update-check; fi
  fi
  latest=$(cat cos/.update-check 2>/dev/null || true)
  if [[ -n "$latest" && "$latest" != "$mine" \
        && "$(printf '%s\n%s\n' "$mine" "$latest" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)" == "$latest" ]]; then
    printf '%s' "$latest"
  fi
}
# The review above rewrites nudges.md, so add the update note after it; the agent mentions it.
NEWER=$(newer_setup)
if [[ -n "$NEWER" ]] && ! grep -qs 'update-cos.sh' cos/nudges.md; then
  echo "- There's an update for my setup. To install it, run ./update-cos.sh in my folder on your computer." >> cos/nudges.md
fi
# Rebuild the notebook page from tonight's notes (the review's edits also rebuild it as they go).
if [[ -x .cos/build-brain.sh ]]; then .cos/build-brain.sh >> "$LOG" 2>&1 || true; fi
# Keep 30 days of archived transcripts, and of documents attached to messages.
find cos/log/transcripts -name '*.jsonl' -mtime +30 -delete 2>/dev/null
find outbox -name '*.md' -mtime +30 -delete 2>/dev/null
echo "=== $(date '+%Y-%m-%d %H:%M') exit $STATUS" >> "$LOG"
