---
name: setup
description: Set up a Chief of Staff workspace in the current folder — checks the system, writes CLAUDE.md, permissions, state files and start script, installs the nightly review, and verifies everything. Use when the user runs /cos:setup or asks to set up, install, or create a chief of staff.
user-invocable: true
allowed-tools:
  - Bash(uname -s)
  - Bash(node --version)
  - Bash(command -v *)
  - Bash(claude --version)
  - Bash(claude auth status)
  - Bash(claude plugin list --json)
  - Bash(test -s .cv/.env)
---

# /cos:setup — Chief of Staff setup

You are setting up a workspace where the user's chief of staff will live. This runs at the
terminal. Work through the phases in order, tell the user what you are doing in one line per
step, and stop at any failure with a clear fix. Finish with the checklist in Phase 7.

**Start by telling the user what will happen**, before running anything, in about these words:
> Here's what happens next:
> 1. A quick check that this computer has what your agent needs. These commands only look;
>    they don't change anything.
> 2. A few short questions.
> 3. I create your agent's files in this folder: its instructions, its notes and its start
>    script. Claude Code asks before each change, so you'll see some approval prompts. That's
>    expected; each one says what it's for.
> 4. With your OK, a nightly review: a scheduled job that tidies your agent's notes at 2:15.
> 5. A final check, then how to start your agent.

## Ground rules
- **Be transparent.** Before each phase, say in one line what you're about to do and why.
  Give every command a plain description of why it's needed (it's shown in the approval
  prompt), and say before running anything that changes files outside this folder.
- **Never accept a Carbon Voice token in this conversation.** If the user pastes one, do not
  save or repeat it. Say it is now in this session's transcript, suggest regenerating it in
  Carbon Voice, and explain that `./start-cos.sh` will ask for it privately.
- Do not overwrite an existing `CLAUDE.md`, `.claude/settings.json` or `cos/` without asking.
  If `cos/.version` already exists, this folder is already set up: offer `/cos:doctor` instead.
- Locate the plugin's templates relative to this skill: `<this skill's base directory>/../../templates`.
  Call that `TEMPLATES` below, and the folder two levels above this skill `PLUGIN_ROOT`.
  Confirm `TEMPLATES` exists with `ls` before continuing.

## Phase 1 — Where are we?
Show the current directory. If it's a folder the installer just created (empty apart from
`.cv/`, which holds the saved Carbon Voice token), continue. If it is the home directory, a code repository, or a folder with
unrelated files, recommend a dedicated folder (`mkdir ~/chief-of-staff && cd ~/chief-of-staff`,
then relaunch `claude` there) and stop unless the user confirms.

## Phase 2 — System check
Users normally arrive here from the installer, which has already installed everything, so this
should be a quick confirmation. If anything required (Node.js 18+, `jq`, the channel plugin) is
missing, offer to fix it by re-running the installer:
`/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"`
Tell the user these commands only read. Run each one as its own command (not chained with `&&`)
and report each:
- OS: `uname -s` (Darwin → launchd; Linux → cron).
- Node.js 18 or later: `node --version`.
- `jq`: `command -v jq`.
- Claude binary: `command -v claude`. Record the absolute path as `CLAUDE_BIN`.
- Signed in: `claude auth status` prints JSON with `loggedIn`, `authMethod`, `email`, `orgName`
  and `subscriptionType`. `loggedIn` should be `true` and `authMethod` should be `claude.ai`. If
  not signed in, or signed in with an API account, tell the user to run `claude auth login`
  with their Claude plan account, or re-run the setup script. Record `orgName` as `ORG_NAME`
  (it may be missing). One email can belong to several Claude organizations, and the agent's
  session only appears in the Claude app's Code tab when the app is switched to the same one.
- Claude Code version: `claude --version`. Note whether it is 2.1.51 or later (needed for
  Remote Control in Phase 3).
- `tmux` (optional, only needed for `--background`): `command -v tmux`.
- Channel plugin: run `claude plugin list --json` and check it lists `cv-channel@carbonvoice`
  with `"enabled": true`. Don't look through `~/.claude/plugins/` directly. If it's missing, tell
  the user to run `/plugin install cv-channel@carbonvoice` and rerun setup; if it's turned off,
  `/plugin enable cv-channel@carbonvoice`.
- Carbon Voice token: check that `.cv/.env` exists (`test -s .cv/.env`). Never read or print it.
  If it's missing, setup was run without the installer: tell the user to run the installer
  (above), or that `./start-cos.sh` will ask for the token privately the first time it runs.

## Phase 3 — Questions
Ask these together, briefly:
1. **Your name**, as the agent should address you. → `OWNER_NAME`
2. **Your agent's name:** read `.cv/agent-name`, which the installer wrote from the Agent
   Account's name in Carbon Voice. Don't ask for it; confirm it in the same message ("Your agent
   is <name>, from its Carbon Voice account"), and use what they say if they correct it.
   → `AGENT_NAME`. Only if the file is missing, ask for the agent's name.
3. **Your Claude plan:** first run `claude auth status` and read `subscriptionType`. If it's
   `pro` or `max`, or `team` or `enterprise`, use it and don't ask. Only ask if it's missing.
   - Pro/Max → `CHANNEL_ARGS` = `--dangerously-load-development-channels plugin:cv-channel@carbonvoice`
   - Team/Enterprise → `CHANNEL_ARGS` = `--channels plugin:cv-channel@carbonvoice`. Tell them an
     admin must turn on `channelsEnabled` and allow the plugin in `allowedChannelPlugins` first.
   Explain once, in one sentence, that the "dangerously" flag only allows a channel plugin that
   isn't on Anthropic's approved list yet; it does not skip permission prompts.
4. **Also show this session in the Claude app?** (recommended) It lets them watch what their
   chief of staff is doing, approve prompts, or type instead of talk, from the Claude app's Code
   tab or claude.ai/code. Mention in one sentence that while connected, the session transcript is
   kept on Anthropic's servers.
   - Yes → `REMOTE_ARGS` = `--remote-control`. Ask whether they already have the Claude app on
     their phone. If not, tell them to run `/mobile` now, which shows a QR code to download it
     for iOS or Android, and to sign in with the email they use for Claude Code. Either way, say:
     "In the Claude app, make sure you're in <ORG_NAME>, or your agent won't appear under Code."
     If `ORG_NAME` is missing, say "make sure the app is signed in to the same account" instead.
   - No, or Claude Code older than 2.1.51 → `REMOTE_ARGS` empty. If the version is too old, say
     they can update Claude Code and rerun `/cos:doctor` to turn it on later.
   - On Team/Enterprise, an Owner must enable Remote Control in Claude Code admin settings.

## Phase 4 — Build the workspace
Tell the user you're now creating the agent's files in this folder, and that Claude Code will
ask before each change. Let `WORKSPACE` be the absolute path of the current directory.
1. `mkdir -p cos/log/transcripts .claude .cv && chmod 700 .cv`
2. Copy `TEMPLATES/cos/` contents (including `log/consolidation.md`) into `cos/`.
3. Copy `TEMPLATES/CLAUDE.md` to `./CLAUDE.md`, replacing `{{AGENT_NAME}}` and `{{OWNER_NAME}}`.
4. Copy `TEMPLATES/settings.json` to `./.claude/settings.json`. If one exists, merge the
   `permissions.allow` and `permissions.deny` arrays instead of overwriting.
5. Copy `TEMPLATES/gitignore` to `./.gitignore` (append if one exists).
6. Copy `TEMPLATES/start-cos.sh` and `TEMPLATES/nightly.sh` to the workspace root, replacing
   `{{AGENT_NAME}}`, `{{CLAUDE_BIN}}`, `{{CHANNEL_ARGS}}` and `{{REMOTE_ARGS}}` (which may be
   empty), then `chmod +x` both.
7. Write the version from `PLUGIN_ROOT/.claude-plugin/plugin.json` to `cos/.version`.
8. Write `cos/.onboarding-pending` containing `stage: not-started`.
Confirm no placeholders remain:
`grep -n '{{' CLAUDE.md start-cos.sh nightly.sh .claude/settings.json` should print nothing.

## Phase 5 — Verify the hooks
Tell the user you're checking that the agent's automatic note-keeping works, using test data
that you remove afterwards. Run each hook script from `PLUGIN_ROOT/scripts/` with `CLAUDE_PROJECT_DIR="$WORKSPACE"`:
- `echo '{"source":"startup"}' | CLAUDE_PROJECT_DIR="$WORKSPACE" "$PLUGIN_ROOT/scripts/session-start.sh"`
  must print a "Chief-of-staff state" block that includes "Onboarding not finished".
- Make a temp transcript containing `/cv-channel:configure abc123secret`, run `pre-compact.sh`
  with `{"transcript_path":"<temp file>","session_id":"test1234"}`, and confirm the archived
  copy contains `[REDACTED]` and not `abc123secret`. Then remove the test archive,
  `cos/.pending-reconcile`, and the test line in today's `cos/log/` file.

## Phase 6 — Nightly review (needs the user's approval)
Explain in one or two sentences: every night at 2:15 the agent reviews its notes, tidies them,
and flags anything stale, in a run separate from the live session. Say that this adds a
scheduled job to their computer (outside this folder; on a Mac, a file in
`~/Library/LaunchAgents/`) and that they can remove it later. Ask before installing.
- **macOS:** label `com.phononx.cos.<folder-name>`. Fill `TEMPLATES/launchd.plist`
  (`{{JOB_LABEL}}`, `{{WORKSPACE}}`, and `{{PATH}}` = the directory of `CLAUDE_BIN` followed by
  `:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin`), write it to
  `~/Library/LaunchAgents/<label>.plist`, then run
  `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist`.
- **Linux:** add `15 2 * * * cd "<WORKSPACE>" && /bin/bash ./nightly.sh` to the user's crontab,
  keeping existing entries.
Then run `./nightly.sh` once and read `cos/log/nightly-run.log`. If it shows an authentication
error, tell the user scheduled runs need Claude Code to be logged in, and that `/cos:doctor`
will recheck. On a fresh workspace the review should report nothing to consolidate.

## Phase 7 — Hand-off
Print a short checklist with ✓ or ✗ for: system check, workspace files, hooks, nightly review.
Then give exactly these next steps:
1. Type `/exit`.
2. Run `./start-cos.sh`. (If the token wasn't saved during install, it asks for it first.)
3. In Carbon Voice, message your agent from your own account. You'll get a pairing code back.
4. In this terminal, run `/cv-channel:access pair <code>`, then message your agent again.
   It will start a short voice conversation to get to know your work.
If Remote Control is on, add: "You can also watch it in the Claude app under Code. No app yet?
Run `/mobile` for a download QR code. In the Claude app, make sure you're in <ORG_NAME>, or your
agent won't appear under Code." If `ORG_NAME` is missing, end with "sign in with the same
account" instead of naming the organization.
