#!/usr/bin/env bash
# Updates {{AGENT_NAME}} to the latest Chief of Staff setup: Claude Code, the Carbon Voice
# plugins, and this folder's generated files (CLAUDE.md, the start, nightly and update scripts,
# settings and the notebook page). Your notes, your Carbon Voice token, your rules
# (cos/my-rules.md) and your answers to setup (cos/setup.conf) are kept. It downloads the latest
# installer and runs it for this folder.
set -euo pipefail
cd "$(dirname "$0")"
INSTALLER="https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh"
SCRIPT=$(curl -fsSL "$INSTALLER") || { echo "Couldn't download the update. Check your internet connection and try again."; exit 1; }
exec /bin/bash -c "$SCRIPT" cos-setup --update "$PWD"
