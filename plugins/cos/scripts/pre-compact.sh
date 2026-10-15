#!/usr/bin/env bash
# PreCompact: archive the full transcript (with tokens redacted) before compaction,
# and leave a marker so the post-compaction SessionStart triggers a reconcile.
set -uo pipefail
COS="${CLAUDE_PROJECT_DIR:-$PWD}/cos"
[[ -d "$COS" && -f "$COS/.version" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' | cut -c1-8)
[[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]] || exit 0

DEST="$COS/log/transcripts/$(date '+%Y-%m-%d_%H%M')_${SESSION}.jsonl"
mkdir -p "$(dirname "$DEST")"
# Redact anything that looks like a Carbon Voice token before it lands in the workspace.
sed -E \
  -e 's#(cv-channel:configure[[:space:]]+)[^"[:space:]\\]+#\1[REDACTED]#g' \
  -e 's#(CV_PAT=)[^"[:space:]\\]+#\1[REDACTED]#g' \
  "$TRANSCRIPT" > "$DEST"
chmod 600 "$DEST"

echo "$DEST" > "$COS/.pending-reconcile"
mkdir -p "$COS/log"
echo "- $(date '+%H:%M') compaction; transcript archived to $(basename "$DEST")" >> "$COS/log/$(date '+%Y-%m-%d').md"
exit 0
