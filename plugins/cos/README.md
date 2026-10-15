# Chief of Staff for Claude Code

A chief of staff you talk to through Carbon Voice. It keeps durable notes on your priorities,
decisions, open loops and people, reviews them every night, and remembers across weeks of
conversation instead of starting fresh each time.

## Set up

**You'll need:** a Mac (or Linux computer) and a Claude Pro, Max, Team or Enterprise plan.
On Team and Enterprise plans, an admin must first enable channels and allow the Carbon Voice
channel plugin.

**1. In Carbon Voice:** create an Agent Account for your chief of staff and give it a name.
Copy its Personal Access Token and keep it handy. Don't paste it into Claude.

**2. Open Terminal and run the installer.** On a Mac, press **⌘ Space**, type **Terminal**,
and press Return. Paste this line and press Return:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/PhononX/claude-plugins/main/cos-setup.sh)"
```
It shows what it will install and why, and waits for your OK. Then it sets up everything this
needs (Claude Code, Node.js, and a couple of small tools), opens your browser so you can sign in
to your Claude account if you aren't already, installs the Carbon Voice plugins, and creates a
folder for your agent. Anything you already
have is left alone, and it's safe to run again.

**3. Finish setup in Claude.** The installer finishes by opening Claude in your agent's folder.
When Claude asks whether you trust the folder, choose **Yes, I trust this folder**. Then type
`/cos:setup` and press Return. Claude asks a few short questions: your name, your agent's name,
whether to also show the session in the Claude app, and approval for the nightly review.

**4. Start your Chief of Staff.** When setup finishes, type `/exit`, then run:
```
./start-cos.sh
```
The first time, it asks for your agent's token. The token is saved privately in the folder and
never enters a Claude conversation. Keep this window open: you can watch messages arrive and
see what your chief of staff does.

**5. Say hello in Carbon Voice.** Message your agent from your own account. You'll get a
pairing code back. In Terminal, type `/cv-channel:access pair <code>`, then message your agent
again. It starts a short voice conversation to learn about your work.

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
- `/cos:doctor` (in Claude) — check that everything is healthy.

## More than one agent
Each folder is its own agent with its own token, memory and allowlist. Create another Agent
Account in Carbon Voice and run the installer again with a new folder name.

## What's in the workspace
| Path | What it is |
|---|---|
| `CLAUDE.md` | Your agent's role and how it should talk to you |
| `cos/now.md`, `open-loops.md`, `decisions.md`, `people.md` | The curated picture, kept short |
| `cos/nudges.md` | What the nightly review wants you to know |
| `cos/log/` | Daily notes, nightly review history, archived transcripts (30 days) |
| `.cv/` | Carbon Voice token and channel state for this agent — never commit |

Everything in `cos/` is plain markdown, so the folder works fine inside an Obsidian vault.
