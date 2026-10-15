# Chief of Staff for Claude Code

A chief of staff you talk to through Carbon Voice. It keeps durable notes on your priorities,
decisions, open loops and people, reviews them every night, and remembers across weeks of
conversation instead of starting fresh each time.

## Set up

**You'll need:** a Mac (or Linux computer) and a Claude Pro, Max, Team or Enterprise plan.
On Team and Enterprise plans, an admin must first enable channels and allow the Carbon Voice
channel plugin.

**1. Open Terminal and run the installer.** On a Mac, press **⌘ Space**, type **Terminal**,
and press Return. Paste this line and press Return:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"
```
It shows what it will install and why, and waits for your OK. Then it sets up everything this
needs (Claude Code, Node.js, and a couple of small tools), opens your browser so you can sign in
to your Claude account if you aren't already, installs the Carbon Voice plugins, and creates a
folder for your agent inside the folder you ran it from. Anything you already have is left
alone, and it's safe to run again.

**2. Connect your Carbon Voice agent.** The installer asks you to create a Personal Agent
Account in Carbon Voice for your chief of staff (it's who you'll talk to), copy its Personal Access Token,
and paste it in Terminal. The token is hidden as you paste it, checked with Carbon Voice, and
saved only in your agent's folder. It never goes into a Claude conversation.

**3. Answer a few questions.** Your name, your agent's name (filled in from Carbon Voice),
whether to also show your agent in the Claude app, and whether to set up the nightly review.
The installer then builds your agent's folder and checks it.

**4. Start your Chief of Staff.** The installer ends by starting your agent. When Claude asks
whether you trust the folder, choose **Yes, I trust this folder**. On Pro and Max plans, Claude
then warns about loading a development channel, because the Carbon Voice connection isn't on
Anthropic's approved list yet: choose **I am using this for local development**. It asks this
each time your agent starts. Keep this window open: you
can watch messages arrive and see what your chief of staff does. Next time, start it from its
folder with:
```
./start-cos.sh
```

**5. Say hello in Carbon Voice.** Message your agent from your own account, the one that owns
the Agent Account. The installer already allowed that account, so your agent starts a short
voice conversation to learn about your work.

If your agent replies with a pairing code instead (for example, you messaged from a different
account), type `/cv-channel:access pair <code>` in your agent's Terminal window, then message it
again. Only add people you'd trust to approve your agent's actions.

## Day to day
Just talk to your agent in Carbon Voice. Ask where things stand, tell it what changed, or have
it keep track of something. It tidies its notes every night.

If you turned on the Claude app option, you can also watch the session from your phone: open
the Claude app and tap **Code**, or go to claude.ai/code. Don't have the app? Run `/mobile` in
Claude for a QR code to download it for iOS or Android, and sign in with the same account you
use for Claude Code. If your email has more than one Claude organization (for example personal
and work), switch the app to the one you chose during setup. It's the same session, so you can see
what it's doing, approve requests, or type instead of talk. While connected, the session
transcript is kept on Anthropic's servers. Your Carbon Voice token never appears in it.

- `./start-cos.sh` — start it again after a restart.
- `./start-cos.sh --background` — keep it running after you close the window (needs tmux).
  Run the same command to reconnect.
- `./start-cos.sh --reset-token` — replace the saved token.
- `./start-cos.sh --no-remote` — start without the Claude app connection this time.
- `./update-cos.sh` — update to the latest version. `./start-cos.sh` tells you when there's an
  update, and your agent mentions it too. Your notes, token and setup answers are kept, so it
  only asks about anything missing. Restart your agent afterwards.
- `./cv-channel-log.sh on` — keep a log of the Carbon Voice connection in `.cv/channel.log`, to
  see why messages aren't getting through; `./cv-channel-log.sh` shows it, `off` stops it.
  It records IDs and what happened, never your token or what was said.
- `/cos:doctor` (in Claude) — check that everything is healthy.

Want your agent to behave differently? Write it in `my-instructions.md` in its folder.
`CLAUDE.md` holds the standard instructions and is replaced by updates; `my-instructions.md`
is never changed.

## More than one agent
Each folder is its own agent with its own token, memory and allowlist. Create another Agent
Account in Carbon Voice and run the installer again with a new folder name.

## What's in the workspace
| Path | What it is |
|---|---|
| `CLAUDE.md` | Your agent's role and how it should talk to you (replaced by updates) |
| `my-instructions.md` | Your own instructions for your agent (updates never change it) |
| `start-cos.sh`, `update-cos.sh`, `nightly.sh` | Start it, update it, and its nightly review |
| `cos/setup.conf` | Your answers to setup, reused by updates |
| `cos/now.md`, `open-loops.md`, `decisions.md`, `people.md` | The curated picture, kept short |
| `cos/nudges.md` | What the nightly review wants you to know |
| `cos/log/` | Daily notes, nightly review history, archived transcripts (30 days) |
| `.cv/` | Carbon Voice token and channel state for this agent — never commit |

Everything in `cos/` is plain markdown, so the folder works fine inside an Obsidian vault.
