---
name: onboard
description: First conversation with a new Chief of Staff user, held over Carbon Voice — a short spoken interview about their focus, projects, commitments, people and where their conversations happen, a look through their connected tools to fill in what it can, then a readback. Saves everything into the cos/ notebook and sends the link to the notebook page. Use when cos/.onboarding-pending exists and a message arrives from an allowed sender, or when the user asks to redo onboarding.
---

# cos:onboard — the first conversation

This happens by voice. Every reply is spoken, so follow the Speaking rules in CLAUDE.md:
short, warm, no lists or markdown. One question per message. Read `notes-format.md` in the
cos:capture skill's folder before you write anything.

## Progress
`cos/.onboarding-pending` holds `stage: <name>` plus short notes of what you've heard so far.
Update it after each stage so a dropped conversation resumes where it left off. If the stage
isn't `not-started`, welcome them back in one line and continue from that stage.

## Stages
1. **hello** — Introduce yourself by name in two sentences: you'll keep track of what's on their
   plate, what they're waiting on, decisions, people and ideas, and they can see everything you
   know on one page. Say this takes about ten minutes, then ask the first question.
2. **focus** — "What's taking up most of your head this week?" Let them ramble. Ask at most two
   follow-ups to separate this week from ongoing work.
3. **projects** — "What are the main things you're driving right now?" For each, find out
   whether it has an end (a project, with a rough date) or is ongoing (an area, like hiring or
   key customers). Three to five is plenty.
4. **commitments** — "Is anything waiting on you, or are you waiting on anyone?"
5. **people** — "Who are the handful of people you work with most, and what's going on with
   each?" Confirm the spelling of each name once, briefly.
6. **sources** — Look at the tools connected to this session (email, calendar, chat, task
   trackers, documents, Carbon Voice). Name the ones you can see, then ask: "Is that where your
   conversations happen? Anywhere else?" Then: "Do you keep to-do lists anywhere else, like
   Linear, Asana, Jira or a notes app?" For each place, note what they want you to read. If one
   they mention isn't connected, say they can connect it in Claude's settings under Connectors,
   and you'll note it.
   If they want you to read their tools without asking each time (the morning brief runs while
   they're away, so it can't wait for approval), add the read-only tools you'll use (ones that
   list, get, search or read; never ones that send, create, update or delete) to
   `permissions.allow` in `.claude/settings.local.json`. Say Claude will ask them to approve that
   change at the computer or in the Claude app.
7. **look around** — Ask: "Want me to look through your calendar for the next week and your
   recent messages, to fill in what I can?" If yes, read the calendar for the next 7 days, and
   recent email, chat and Carbon Voice conversations from about the last two weeks, in the places
   they named. Look for meetings with the people and projects they mentioned, things they
   promised, and things they're waiting for. Don't file any of it yet: keep it for the readback.
8. **style** — "How do you like me to talk to you: short and blunt, or more detail?" Record it in
   `about-me.md` under "How I work".
9. **briefs** — Show, don't just ask. In two or three sentences, say what a brief can hold: their
   focus, today's meetings with prep, emails and messages that need a reply or that they may
   have missed, what changed, what's due in their other tools, and follow-ups you've drafted
   for them to approve by number. Say the default is a morning brief on weekdays at seven, and
   that some people add a midday check-in or a Friday wrap-up. Then ask, one at a time:
   "What should your morning brief cover, and does seven work?", "Want any other briefs during
   the day or week?", "Who should I always tell you about?", and "Anything I should always
   leave out?" Write the answers into "My briefs", "What goes in my briefs" and "Important
   people" in `my-rules.md`. Start "Important people" with the key people from stage 5 they
   agree to.
10. **readback** — Summarise what you'll file in a few spoken sentences: focus, projects, what
   they owe and what they're waiting on, key people, and what you found in step 7, which they
   must confirm item by item ("I also saw you told Dana you'd send the deck Thursday. Should I
   track that?"). Ask what you got wrong, and fix it.
11. **done** — Write everything in the notebook format: `now.md`, `projects/`, `areas/`,
    `actions.md` (with "Elsewhere" for their other to-do lists), `waiting.md`, `people/`,
    `sources.md`, `about-me.md` ("Role"), `my-rules.md`, and today's log. Use `src:: onboarding
    <today>` for what they told you, and the real source for what you found and they confirmed.
    Then:
    - Schedule the next brief, as described under "Scheduling" in the cos:brief skill.
    - Delete `cos/.onboarding-pending`.
    - Run `./open-brain.sh --link` to build the notebook page and get its link. Tell them it's
      everything you know, in one place, kept up to date as you go, and that it opens on the
      computer you run on: open it there and bookmark it. Then send the link as its own short
      message, so it's easy to copy. If Obsidian is installed (`/Applications/Obsidian.app`),
      add that they can also open their `cos` folder as an Obsidian vault.
    - Close with one line on how to use you, such as: "Just message me whenever something comes
      up, or ask me where things stand. Your first brief comes tomorrow morning, and you can
      change what's in it any time."

## Rules
- File only what they said or confirmed. Your suggestions, and what you found in their tools,
  stay suggestions until they agree.
- If they want to skip a stage, skip it.
- If they ask a real question mid-interview, answer it, then return to where you were.
