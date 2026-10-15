---
name: brief
description: The chief of staff's morning brief, sent in Carbon Voice — today's focus, meetings with prep offers, what's due (in the notebook and in the user's other tools), and numbered follow-ups the user can approve by number. Also sends meeting prep, and acts on "do 1 and 3" replies. Use when the scheduled task "Use the cos:brief skill now." fires, when the user asks for their brief or for prep for a meeting, or when they answer a brief with follow-up numbers.
---

# cos:brief — the morning brief

Read `notes-format.md` in the cos:capture skill's folder for the format of `cos/brief.md`. Read
the front matter and rules in `cos/my-rules.md` first; they win over everything here.

## 1. Gather
- From the notebook: `now.md` (focus, this week, suggested moves), `actions.md` (due today,
  overdue, due tomorrow), `waiting.md` (overdue and longest waiting), `ideas.md` (any whose
  `back` time has come), `nudges.md`.
- From the places in `cos/sources.md`, using the tools connected to this session:
  - **Calendar:** today's meetings.
  - **Email, chat, Carbon Voice conversations:** since the last brief, anything that needs a
    reply from the user, or that changes an action, a waiting item or a project. File what
    changes the notebook, as cos:capture would.
  - **To-do lists under "Elsewhere" in `actions.md`:** what's due today or overdue there. Never
    copy those items into `actions.md`.
- If a tool fails or isn't connected, skip it and say so in one line at the end of the brief.

## 2. Choose
- **Focus:** the three things that matter most today. Usually `now.md`'s focus, adjusted by
  what's due.
- **Meetings:** each with its time, title and people (linked if they have notes). Per
  `meeting_prep`: `offer` → `[prep:: offered]`, and the spoken brief offers it for the meetings
  that matter; `auto` → schedule prep (below) and mark `[prep:: HH:MM]`; `off` → nothing.
- **Follow-ups:** at most five, numbered, that you can do for the user once they say so:
  replies they owe, nudges to people they're waiting on, a message an action calls for. Write
  each draft in their voice, following their rules and "How I work" in `about-me.md`.

## 3. Write and send
1. Overwrite `cos/brief.md` (front matter `date` and `sent`, then Focus, Meetings, Follow-ups,
   Due elsewhere; leave out empty sections).
2. Send a spoken version to the user in Carbon Voice with cv-channel's `send_message`, to the
   conversation they last messaged you from (or `list_senders` to find them). Keep it under a
   minute: a greeting, the focus, the meetings worth knowing about, prep offers, then the
   follow-ups by number with a few words each, ending with something like "Tell me the numbers
   you want me to do." Speaking rules apply: no lists, no links.
3. Add one line to today's log.

## 4. Keep it scheduled
Scheduled tasks last only as long as this session, and repeating ones stop after 7 days. After
every brief:
1. List your scheduled tasks (CronList). Delete (CronDelete) every one whose prompt is
   "Use the cos:brief skill now."
2. Unless `brief_days` is `off`, create a repeating one (CronCreate) with that prompt, at
   `brief_time` (7:00 unless set): cron `MM HH * * 1-5` for `weekdays`, `MM HH * * *` for
   `daily`.

Do the same whenever the user changes the brief time or days. This is also how onboarding
schedules the first brief.

## Meeting prep
For prep asked for, offered and accepted, or scheduled by `auto` (a one-shot CronCreate 15
minutes before the meeting, with the prompt "Use the cos:brief skill to send prep for the
<time> <title> meeting."):
- Gather: the people's notes and last contact, open actions and waiting items that link them or
  the meeting's project, recent decisions, the project's status and next step, and their recent
  messages to the user.
- Send three to five spoken sentences: what this meeting is for, what's open with them, what
  the user promised, and one thing worth raising.
- Add the prep as a quote under that meeting in `brief.md`, and set `[prep:: ready]`.

## "Do 1 and 3"
When the user answers with numbers, that is their approval for those follow-ups only:
1. Take each from `cos/brief.md`. If they changed the wording, use theirs.
2. Send it with the tool it belongs to (reply in the same email thread or chat). If that tool
   can only make drafts, make a draft and say so. If none fits, read the draft back and ask how
   to send it.
3. Add `[done:: <today>]` to the follow-up in `brief.md`, update the matching action or waiting
   item (check it off, or set `nudged::`), and log it.
4. Confirm in one sentence what was sent, to whom.
Never send a follow-up they didn't name.
