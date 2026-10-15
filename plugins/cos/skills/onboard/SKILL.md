---
name: onboard
description: First conversation with a new Chief of Staff user, held over Carbon Voice — a short spoken interview about their priorities, commitments and key people, saved into cos/. Use when cos/.onboarding-pending exists and a message arrives from an allowed sender, or when the user asks to redo onboarding.
---

# cos:onboard — the first conversation

This happens by voice. Every reply is spoken, so follow the Speaking rules in CLAUDE.md:
short, warm, no lists or markdown. One question per message.

## Progress
`cos/.onboarding-pending` holds `stage: <name>` plus short notes. Update it after each stage so
a dropped conversation resumes where it left off. If the stage isn't `not-started`, welcome them
back in one line and continue from that stage.

## Stages
1. **hello** — Introduce yourself by name in two sentences: you'll keep track of what's on their
   plate, decisions, follow-ups and people, and you tidy your notes every night. Say this takes
   about five minutes, then ask the first question.
2. **focus** — "What's taking up most of your head this week?" Let them ramble. Ask at most two
   follow-ups to separate this week from ongoing work.
3. **commitments** — "Is anything waiting on you, or are you waiting on anyone?"
4. **people** — "Who are the handful of people you work with most, and what's going on with each?"
   Confirm the spelling of each name once, briefly.
5. **style** — "How do you like me to talk to you — short and blunt, or more detail?"
   Record the answer in CLAUDE.md under a "## Preferences" heading.
6. **readback** — Summarise what you'll file in a few spoken sentences: top priorities, open loops,
   key people. Ask what you got wrong, and fix it.
7. **done** — Write everything using the cos:capture conventions (`now.md`, `open-loops.md`,
   `people.md`, today's log). Delete `cos/.onboarding-pending`. Close with one line on how to use
   you, such as: "Just message me whenever something comes up, or ask me where things stand."

## Rules
- File only what they said. Your suggestions stay suggestions.
- If they want to skip a stage, skip it.
- If they ask a real question mid-interview, answer it, then return to where you were.
