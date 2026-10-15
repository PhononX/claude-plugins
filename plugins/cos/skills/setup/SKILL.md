---
name: setup
description: Quick check of whether this folder is a set-up Chief of Staff, with directions from there. Setup itself is done by the one-line installer in Terminal. Use when the user runs /cos:setup or asks how to set up, install, or create a chief of staff.
user-invocable: true
allowed-tools:
  - Bash(test -e *)
---

# /cos:setup — quick check and directions

Setup happens in Terminal, not in this conversation: the installer installs what's needed,
connects the Carbon Voice agent (its token is pasted there, never into Claude), asks a few
questions, builds the agent's folder and starts the agent. Don't build the workspace yourself,
and don't run the installer for the user: it asks them questions directly.

## 1. Quick check
Tell the user you're taking a quick look at this folder. Then check which of these exist in the
current folder with `test -e <path>`, one file per command (it only checks that a file is there;
don't open any of them):
- `cos/.version` (the folder was set up)
- `CLAUDE.md`
- `start-cos.sh`
- `nightly.sh`
- `.claude/settings.json`
- `.cv/.env` (the saved Carbon Voice token; check it exists, never read it)

Show the result as a short ✓/✗ list.

## 2. Point the way
- **Everything is there:** this agent is set up. To start it, type `/exit` and run
  `./start-cos.sh` in this folder. For a full health check (token, access, hooks, nightly
  review, Claude app connection), run `/cos:doctor`.
- **Some of it is missing:** the setup is incomplete. Run the installer again from the folder
  that contains this one, and give it this folder's name (typed twice to confirm reusing it); it
  keeps the agent's notes and token. To see in detail what's wrong first, run `/cos:doctor`.
- **None of it is there:** this folder isn't an agent. Tell the user, in about these words:
  > To set up your chief of staff:
  > 1. In Carbon Voice, create a Personal Agent Account for it (it's who you'll talk to). The
  >    installer asks for its Personal Access Token, so keep Carbon Voice open.
  > 2. Type `/exit` to leave Claude.
  > 3. In Terminal, go to the folder where your agent's folder should be created, then run:
  >    `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"`
  > 4. Answer its questions. When it's done, it starts your agent and says how to connect.

The installer command is the same in every case.

Never ask for or accept a Carbon Voice token in this conversation. If the user pastes one, don't
repeat it. Say it's now in this session's transcript, suggest regenerating it in Carbon Voice,
and to paste the new one into the installer instead.
