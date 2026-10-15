---
name: setup
description: How to set up a Chief of Staff. Points the user to the one-line installer, which does the whole setup in Terminal. Use when the user runs /cos:setup or asks how to set up, install, or create a chief of staff.
user-invocable: true
---

# /cos:setup — how to set up a Chief of Staff

Setup happens in Terminal, not in this conversation. The installer installs what's needed,
connects the Carbon Voice agent (its token is pasted there, never into Claude), asks a few
questions, builds the agent's folder and starts the agent. Don't build the workspace yourself,
and don't run the installer for the user: it asks them questions directly.

If the current folder has `cos/.version`, it's already set up. Say so, and tell the user to
type `/exit` and run `./start-cos.sh` here to start their agent, or to run `/cos:doctor` if
something isn't working.

Otherwise, tell the user, in about these words:
> To set up your chief of staff:
> 1. In Carbon Voice, create a Personal Agent Account for it (it's who you'll talk to). The
>    installer asks for its Personal Access Token, so keep Carbon Voice open.
> 2. Type `/exit` to leave Claude.
> 3. In Terminal, go to the folder where your agent's folder should be created, then run:
>    `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"`
> 4. Answer its questions. When it's done, it starts your agent and says how to connect.

Never ask for or accept a Carbon Voice token in this conversation. If the user pastes one, don't
repeat it. Say it's now in this session's transcript, suggest regenerating it in Carbon Voice,
and to paste the new one into the installer instead.
