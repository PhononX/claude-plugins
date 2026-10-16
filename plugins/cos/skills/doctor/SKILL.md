---
name: doctor
description: Health check for a Chief of Staff workspace — system, files, notebook layout and page, hooks, channel token and access, the briefs and the nightly review. Use when the user runs /cos:doctor, or says the chief of staff isn't responding, forgot something, or seems broken.
user-invocable: true
---

# /cos:doctor — Chief of Staff health check

Read-only unless the user approves a fix. Report each check as ✅, ⚠️ or ❌ with a one-line fix:
❌ when it stops the agent from working (nobody can message it, no token, the channel isn't
connected), ⚠️ when it works but something needs attention, ✅ when it's fine.

Lay the report out so a problem can't be missed:
1. If anything is ❌, start with `## ❌ Needs fixing`: one line per problem, in bold, followed by
   the exact fix (the command to type, or the setting to change). Put the most important first.
2. Then `## ⚠️ Worth a look`, if anything is ⚠️.
3. Then `## ✅ Working`, one short line per check.
4. End with the one next step, in bold.
If nothing is ❌ or ⚠️, say so in the first line.
Locate the plugin root as two levels above this skill's base directory (`PLUGIN_ROOT`).

1. **Workspace:** `cos/.version` exists; `CLAUDE.md`, `cos/my-rules.md`, `cos/about-me.md`,
   `.claude/settings.json`, `start-cos.sh`, `nightly.sh`, `update-cos.sh`, `open-brain.sh`,
   `.cos/defaults.md`, `.cos/options.md`, `.cos/build-brain.sh` and `.cos/brain-template.html`
   exist; no `{{`
   placeholders remain. Compare `cos/.version` with the version in
   `PLUGIN_ROOT/.claude-plugin/plugin.json`. If they differ, or `update-cos.sh` is missing, the
   fix is: type `/exit`, then run `./update-cos.sh` (or, without it, re-run the installer for
   this folder).
2. **System:** `jq` is installed; the Claude path inside `start-cos.sh` still exists.
3. **Hooks:** run `PLUGIN_ROOT/scripts/session-start.sh` with `{"source":"startup"}` and
   `CLAUDE_PROJECT_DIR` set to this folder; confirm it prints state.
4. **Channel token:** `.cv/.env` exists, has mode 600, and contains a `CV_PAT=` line.
   Never print the token. If missing: "Run ./start-cos.sh — it will ask for the token."
5. **Channel access:** read `.cv/access.json`. Its fields are exactly `dmPolicy`, `allowFrom`
   (IDs) and `blockedFrom`; don't guess other names. Report the policy and how many people are
   allowed. No file means `pairing`. A file with no `dmPolicy` means `allowlist`: the channel treats such
   files as older than pairing.
   - Policy `allowlist` with nobody allowed: ❌ "Nobody can message <agent>, and messages from
     anyone else are dropped without a pairing code." Fix: type
     `/cv-channel:access policy pairing`, message the agent in Carbon Voice to get a code, then
     `/cv-channel:access pair <code>`.
   - Policy `pairing` with nobody allowed: ⚠️ "Nobody is paired yet": message the agent to get a
     code, then `/cv-channel:access pair <code>`.
   - Someone allowed and the policy still `pairing`: ⚠️, suggest
     `/cv-channel:access policy allowlist`.
   Access commands only see this folder's allowlist in a session started by `./start-cos.sh`.
   If the user says messages aren't arriving and someone is allowed, the allowed ID may not be
   the account they message from: under `allowlist`, other accounts are dropped without a
   reply. Ask them to check the channel log (below) for "dropped" lines with a sender ID.
   **Channel log:** if `.cv/channel.log` exists, show its last 30 lines (they hold IDs and
   events, never the token or message contents) and say what they show: whether the channel
   connected ("authenticated as", "first run, starting from"), messages dropped from unknown
   senders ("dropped message from unknown sender <ID>": compare the ID with `allowFrom`), pairing
   codes, or errors. "waiting for confirm_channels" with no "authenticated as" after it means
   Claude Code didn't load it as a channel: ❌, the fix is to restart with `./start-cos.sh` and
   choose "I am using this for local development" when Claude warns about the channel. If messages aren't getting through and
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
   briefs in `cos/my-rules.md` parse: each line under "My briefs" has `at:: HH:MM` and `days::`
   (`weekdays`, `daily`, `weekends`, `off`, or days like `mon, wed, fri`). An older file with
   only `brief_time` and `brief_days` in its front matter still works as one morning brief.
   **Notebook page:** run `./open-brain.sh --link`. It should print a `http://localhost:` link
   (a `file://` link means the notebook server isn't running, see 11); report it, and how old
   `brain.html` was before the rebuild. If the build fails, show the error.
10. **Briefs:** list the briefs from "My briefs". Only in a session started by `./start-cos.sh`
   (`CV_ACCESS_PATH` is set): list your scheduled tasks (CronList) and report the one whose
   prompt starts with "Use the cos:brief skill now", and when it runs. It should be the next
   brief due; if it's missing or wrong, offer to fix it as "Scheduling" in the cos:brief skill
   describes. Report the briefs sent today from `cos/brief.md`, and how many lines
   `cos/catch-up.md` holds. Briefs go to the conversation in `cos/.cv-thread`, which is written
   the first time the agent replies in Carbon Voice; if it's missing, say briefs start once the
   user has messaged the agent.
11. **Notebook server:** `NOTEBOOK_PORT` in `cos/setup.conf` and `.cv/notebook.key` exist (never
   print the key). `curl -s http://localhost:<port>/health` answers `{"ok":true,…}`. Check the
   service: on a Mac, `launchctl print gui/$(id -u)/com.phononx.cos.<folder name>.notebook`; on
   Linux, `systemctl --user status cos-<folder name>-notebook.service` (or the `@reboot` crontab
   line). Show the last 15 lines of `.cv/notebook-server.log`. If it isn't running, `./open-brain.sh`
   starts it for now and `./update-cos.sh` sets the service up again. On a Mac, if the log shows
   it can't read the folder ("Operation not permitted"), macOS is keeping background jobs out of
   it: allow it in System Settings → Privacy & Security, or move the agent's folder out of
   Documents/Desktop.
12. **Launcher:** if `cos/setup.conf` has `APP=1`: on a Mac, check `~/Applications/<agent
   name>.app` exists and `osadecompile` on it mentions this folder; on Linux, check
   `~/.local/share/applications/cos-<folder name>.desktop` points at this folder's
   `start-cos.sh`. If it's missing or points elsewhere, the fix is `./update-cos.sh`.
13. **Size:** warn if `cos/now.md` is over 60 lines or `cos/log/transcripts/` is over 200 MB.
14. **Onboarding:** if `cos/.onboarding-pending` exists, say onboarding isn't finished and show its stage.
