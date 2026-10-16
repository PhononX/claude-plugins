# Chief of Staff for Claude Code

A chief of staff you talk to through Carbon Voice. It keeps a notebook of what you're focused
on, what you owe and what you're waiting on, your projects, people, decisions, ideas, links and
facts. You can see everything it knows on one page in your browser, or open the notebook in
Obsidian. It sends you briefs when you want them, catches you up on what needs your reply,
reviews its notes every night, and remembers across weeks of conversation instead of starting
fresh each time.

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
Setup also offers to add your agent to your Applications (and Desktop), so you can start it
from Spotlight, Launchpad or the Dock instead: it opens Terminal and starts your agent, or brings
Terminal forward if it's already running. It won't start a second copy.

**5. Say hello in Carbon Voice.** Message your agent from your own account, the one that
created the Agent Account. The installer asks whether to let that account in without a pairing
code; if you said yes, your agent starts a short voice conversation to learn about your work.

If your agent replies with a pairing code instead (for example, you messaged from a different
account), type `/cv-channel:access pair <code>` in your agent's Terminal window, then message it
again. Only add people you'd trust to approve your agent's actions.

## Day to day
Just talk to your agent in Carbon Voice. Ask where things stand, tell it what changed, mention
an idea or a link you'll want later, or have it keep track of something.

- **Briefs.** On weekdays at 7:00 it sends you a short brief in Carbon Voice: your focus,
  today's meetings (with prep if you want it), a catch-up on your email, chat and Carbon Voice
  (what needs your reply, what you may have missed, what changed), what's due in your other
  tools, and numbered follow-ups it has drafted. Reply with the numbers, like "do 1 and 3", and
  it sends those; it never sends anything you didn't ask for. It reads the tools connected to
  your Claude account to put this together.
- **Your briefs, your way.** Tell it what you want: "add a midday check-in at 12:30 that covers
  what came in since the morning", "add a Friday wrap-up at 4:30", "always tell me about
  anything from Jordan", "leave out GitHub notifications". It keeps these under "My briefs",
  "What goes in my briefs" and "Important people" in `cos/my-rules.md`. After your first week
  it asks what you'd want more or less of, and it suggests changes based on what you use.
  Back from time off? Ask it to "catch me up since Friday".
- **Details attached.** When there's more than a few sentences can carry, like a brief, a
  catch-up or meeting prep, it says the short version and attaches the details as a document
  you can read in Carbon Voice, with links to the emails and threads.
- **What it can do, and your settings.** Ask "what can you do?", or run `/cos:settings` in
  Claude. It shows everything you can turn on or change, what's on for you now, and a few
  things that might suit you, and changes any of it when you ask.
- **Drafts.** "Start a draft email to Dana about pricing", "add this to the board narrative",
  "turn my notes into an outline", "make it shorter". Your agent shapes emails, documents, decks
  and messages with you as you talk, keeping every version and the notes behind them. When one
  is ready, it asks whether to keep it or move it to the tool you use for that kind of work
  (a Gmail draft, a Google Doc…), remembers your answer under "My tools", and links to where it
  went. Once moved, the copy in your tool is the real one: your agent can read it and start a new
  version, but doesn't change it there without asking.
- **Your voice.** With your OK, it learns how you write from your sent messages, separately for
  each kind of writing and audience (work email, client email, Slack, texts to friends), and
  keeps that under "How I write" in your notebook, where you can see and correct it.
- **Your notebook page.** Everything it knows, on one page: today, your actions, what you're
  waiting on, projects, people, ideas to come back to, links and facts, decisions, a daily log,
  the archive, and how it works for you. Run `./open-brain.sh` to open it (your agent also
  sends you the link at the end of onboarding). Bookmark it; it keeps itself up to date. It
  opens on the computer your agent runs on, and it holds all your notes, so don't share it.
- **Obsidian.** The `cos` folder is an Obsidian vault as it is: open it with **Open folder as
  vault**. Notes link to each other with `[[Name]]`, so every person and project shows what
  links to it.
- **Nightly review.** It tidies its notes every night, archives what's finished or gone stale
  (nothing is ever deleted), and suggests moves, like turning an idea that keeps coming up into
  a project. It asks before reorganizing anything.

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
- `./open-brain.sh` — open your notebook page; `./open-brain.sh --link` prints its link.
- `/cos:doctor` (in Claude) — check that everything is healthy.

Want your agent to work differently? Tell it: "from now on, brief me at 6:45", "my team's tasks
live in Linear". It keeps your rules in `cos/my-rules.md`, which you can also edit yourself.
They work in three layers: the defaults that come with your agent (`.cos/defaults.md`), what it
knows about you (`cos/about-me.md`), and your rules, which win over both. Updates only ever
change the defaults.

## More than one agent
Each folder is its own agent with its own token, memory and allowlist. Create another Agent
Account in Carbon Voice and run the installer again with a new folder name.

## What's in the workspace
| Path | What it is |
|---|---|
| `CLAUDE.md` | Your agent's role and how it should talk to you (replaced by updates) |
| `start-cos.sh`, `update-cos.sh`, `nightly.sh`, `open-brain.sh` | Start it, update it, its nightly review, and your notebook page |
| `brain.html` | Your notebook page, rebuilt from `cos/` whenever a note changes |
| `.cos/` | The defaults, everything your agent can do (`options.md`), and the notebook page's builder (replaced by updates) |
| `outbox/` | Documents your agent attached to its messages (kept 30 days) |
| `cos/` | The notebook: an Obsidian-compatible folder of plain Markdown |
| `cos/my-rules.md`, `cos/about-me.md` | Your rules, and what your agent knows about you (updates never change them) |
| `cos/now.md`, `cos/brief.md`, `cos/nudges.md` | Today: focus, today's briefs, reminders |
| `cos/inbox.md`, `actions.md`, `waiting.md`, `ideas.md`, `links.md`, `facts.md`, `decisions.md` | What you owe, what you're waiting on, and what to find again |
| `cos/catch-up.md` | What needs your reply or attention in your email, chat and Carbon Voice |
| `cos/projects/`, `cos/areas/`, `cos/people/` | One note per project, ongoing area, and person |
| `cos/drafts/` | Drafts being shaped, with their notes; earlier versions in `drafts/.history/` |
| `cos/log/`, `cos/archive/` | Daily notes and archived transcripts (30 days); finished and stale items |
| `cos/sources.md` | Where your conversations and to-do lists live, and what your agent reads |
| `cos/setup.conf` | Your answers to setup, reused by updates |
| `.cv/` | Carbon Voice token and channel state for this agent — never commit |

The layout and the line format are described in
[`skills/capture/notes-format.md`](skills/capture/notes-format.md).

Updating from 0.1: `./update-cos.sh` adds the new files and moves anything you wrote in
`my-instructions.md` into `cos/my-rules.md`. The next time your agent starts, it moves your
notes into the new layout itself and keeps copies of the old files in `cos/archive/old-layout/`.
