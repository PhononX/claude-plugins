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
# Keep 30 days of archived transcripts.
find cos/log/transcripts -name '*.jsonl' -mtime +30 -delete 2>/dev/null
echo "=== $(date '+%Y-%m-%d %H:%M') exit $STATUS" >> "$LOG"
