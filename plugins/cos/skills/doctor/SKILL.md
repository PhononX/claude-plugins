---
name: doctor
description: Health check for a Chief of Staff workspace — system, files, notebook layout and page, hooks, channel token and access, the morning brief and the nightly review. Use when the user runs /cos:doctor, or says the chief of staff isn't responding, forgot something, or seems broken.
user-invocable: true
---

# /cos:doctor — Chief of Staff health check

Read-only unless the user approves a fix. Report each check as ✓, ⚠ or ✗ with a one-line fix.
Locate the plugin root as two levels above this skill's base directory (`PLUGIN_ROOT`).

1. **Workspace:** `cos/.version` exists; `CLAUDE.md`, `cos/my-rules.md`, `cos/about-me.md`,
   `.claude/settings.json`, `start-cos.sh`, `nightly.sh`, `update-cos.sh`, `open-brain.sh`,
   `.cos/defaults.md`, `.cos/build-brain.sh` and `.cos/brain-template.html` exist; no `{{`
   placeholders remain. Compare `cos/.version` with the version in
   `PLUGIN_ROOT/.claude-plugin/plugin.json`. If they differ, or `update-cos.sh` is missing, the
   fix is: type `/exit`, then run `./update-cos.sh` (or, without it, re-run the installer for
   this folder).
2. **System:** `jq` is installed; the Claude path inside `start-cos.sh` still exists.
3. **Hooks:** run `PLUGIN_ROOT/scripts/session-start.sh` with `{"source":"startup"}` and
   `CLAUDE_PROJECT_DIR` set to this folder; confirm it prints state.
4. **Channel token:** `.cv/.env` exists, has mode 600, and contains a `CV_PAT=` line.
   Never print the token. If missing: "Run ./start-cos.sh — it will ask for the token."
5. **Channel access:** read `.cv/access.json`. Report the policy and how many people are allowed.
   If someone is allowed and the policy is still `pairing`, suggest
   `/cv-channel:access policy allowlist`. Note that access commands only see this folder's
   allowlist in a session started by `./start-cos.sh`.
   **Channel log:** if `.cv/channel.log` exists, show its last 30 lines (they hold IDs and
   events, never the token or message contents) and say what they show: whether the channel
   connected ("authenticated as", "first run, starting from"), messages dropped from unknown
   senders, pairing codes, or errors. If messages aren't getting through and
   `.cv/channel-log.on` doesn't exist, suggest `./cv-channel-log.sh on`, restarting the agent,
   and sending another message.
6. **This session:** check whether `CV_ACCESS_PATH` is set in the environment. If not, this session
   wasn't started by `./start-cos.sh` and isn't connected to Carbon Voice.
7. **Nightly review:** macOS — `launchctl print gui/$(id -u)/com.phononx.cos.<folder-name>`;
   Linux — `crontab -l | grep nightly.sh`. Show the last 15 lines of `cos/log/nightly-run.log`
   and flag authentication errors, or a last run more than 2 days ago.
8. **Remote Control:** report whether `start-cos.sh` launches with `--remote-control`. If it
   doesn't and `claude --version` is 2.1.51 or later, offer to turn it on by setting the
   `REMOTE=(...)` line in `start-cos.sh` to `REMOTE=(--remote-control)`. If it does, read
   `orgName` from `claude auth status` (JSON) and report it, with: "In the Claude app, make sure
   you're in <orgName>, or your agent won't appear under Code." If `orgName` is missing, say to
   make sure the app is signed in to the same account as Claude Code.
9. **Notebook:** if `cos/.layout` is missing and `cos/open-loops.md` or `cos/people.md` exists,
   the notes are still in the old layout: offer to run the cos:migrate skill. Check that the
   front matter of `cos/my-rules.md` parses (`brief_time` is `HH:MM`, `brief_days` is `weekdays`,
   `daily` or `off`).
   **Notebook page:** run `./open-brain.sh --link`. It should print a `file://` link; report it,
   and how old `brain.html` was before the rebuild. If the build fails, show the error.
10. **Morning brief:** only in a session started by `./start-cos.sh` (`CV_ACCESS_PATH` is set).
   List your scheduled tasks (CronList) and report whether one has the prompt "Use the cos:brief
   skill now." and its schedule. If it's missing and `brief_days` isn't `off`, offer to schedule
   it as the cos:brief skill describes. Report the date in `cos/brief.md`'s front matter as the
   last brief sent.
11. **Size:** warn if `cos/now.md` is over 60 lines or `cos/log/transcripts/` is over 200 MB.
12. **Onboarding:** if `cos/.onboarding-pending` exists, say onboarding isn't finished and show its stage.
