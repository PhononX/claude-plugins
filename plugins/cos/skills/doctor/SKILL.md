---
name: doctor
description: Health check for a Chief of Staff workspace — system, files, hooks, channel token and access, and the nightly review. Use when the user runs /cos:doctor, or says the chief of staff isn't responding, forgot something, or seems broken.
user-invocable: true
---

# /cos:doctor — Chief of Staff health check

Read-only unless the user approves a fix. Report each check as ✓, ⚠ or ✗ with a one-line fix.
Locate the plugin root as two levels above this skill's base directory (`PLUGIN_ROOT`).

1. **Workspace:** `cos/.version` exists; `CLAUDE.md`, `.claude/settings.json`, `start-cos.sh` and
   `nightly.sh` exist; no `{{` placeholders remain. Compare `cos/.version` with the version in
   `PLUGIN_ROOT/.claude-plugin/plugin.json` and mention any difference.
2. **System:** `jq` is installed; the Claude path inside `start-cos.sh` still exists.
3. **Hooks:** run `PLUGIN_ROOT/scripts/session-start.sh` with `{"source":"startup"}` and
   `CLAUDE_PROJECT_DIR` set to this folder; confirm it prints state.
4. **Channel token:** `.cv/.env` exists, has mode 600, and contains a `CV_PAT=` line.
   Never print the token. If missing: "Run ./start-cos.sh — it will ask for the token."
5. **Channel access:** read `.cv/access.json`. Report the policy and how many people are allowed.
   If someone is allowed and the policy is still `pairing`, suggest
   `/cv-channel:access policy allowlist`. Note that access commands only see this folder's
   allowlist in a session started by `./start-cos.sh`.
6. **This session:** check whether `CV_ACCESS_PATH` is set in the environment. If not, this session
   wasn't started by `./start-cos.sh` and isn't connected to Carbon Voice.
7. **Nightly review:** macOS — `launchctl print gui/$(id -u)/com.phononx.cos.<folder-name>`;
   Linux — `crontab -l | grep nightly.sh`. Show the last 15 lines of `cos/log/nightly-run.log`
   and flag authentication errors, or a last run more than 2 days ago.
8. **Remote Control:** report whether `start-cos.sh` launches with `--remote-control`. If it
   doesn't and `claude --version` is 2.1.51 or later, offer to turn it on by setting the
   `REMOTE=(...)` line in `start-cos.sh` to `REMOTE=(--remote-control)`.
9. **Size:** warn if `cos/now.md` is over 60 lines or `cos/log/transcripts/` is over 200 MB.
10. **Onboarding:** if `cos/.onboarding-pending` exists, say onboarding isn't finished and show its stage.
