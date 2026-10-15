---
name: brief
description: The chief of staff's briefs, sent in Carbon Voice at the times the user chose (a morning brief, a midday check-in, a Friday wrap-up…) — focus, meetings with prep offers, a catch-up on email, chat and Carbon Voice (what needs a reply, what they may have missed, what changed), what's due, and numbered follow-ups they approve by number. Also "catch me up since…", meeting prep, and "do 1 and 3" replies. Use when a scheduled task "Use the cos:brief skill now: <brief name>." fires, when the user asks for a brief, a catch-up or meeting prep, when they answer a brief with follow-up numbers, or when they change their briefs.
---

# cos:brief — briefs, catch-up and follow-ups

Read `notes-format.md` in the cos:capture skill's folder for the format of `brief.md`,
`catch-up.md` and the brief sections of `my-rules.md`. Then read `cos/my-rules.md`: its rules,
"My briefs", "What goes in my briefs" and "Important people" win over everything here. If it has
no "My briefs" section, use `brief_time` and `brief_days` from its front matter as a single
"Morning brief" (7:00 on weekdays if those aren't set either).

## Which brief
The scheduled task names it: "Use the cos:brief skill now: Midday check-in." Find that line in
"My briefs" and follow its `covers`. If the user just asks for a brief, give the one whose time
is closest. If the named brief is no longer in "My briefs", don't send anything; just schedule
the next one (see "Scheduling").

## 1. Catch up
Before every brief, bring `cos/catch-up.md` up to date from the places in `cos/sources.md`,
using the tools connected to this session (email, chat, Carbon Voice conversations):
- **Needs your reply** (`kind:: reply`): in the last 7 days, someone asked the user a question
  or for something, and the user hasn't answered. Include threads they were copied on when the
  ask is clearly theirs.
- **You may have missed** (`kind:: missed`): unread or unanswered messages worth their time:
  from important people or anyone with a note in `people/`, that mention a deadline, or that
  touch one of their projects. Group several from one person into one line.
- **Changed** (`kind:: changed`): news since the last brief that moves a project, an action or
  a waiting item. File the change into the notebook as cos:capture would.
- **Leave out:** newsletters, notifications, receipts, automated mail, and anything their
  "What goes in my briefs" says to skip. **Always include** anything from "Important people".
- **Close lines:** when the user has replied, the thread is dealt with, or they said to skip it,
  move the line to `archive/YYYY-MM.md` (`why:: replied` or `why:: skipped`, `from:: catch-up`).
  Move "changed" lines there once they've been in one brief.

One line per thread, with a link to it in `src` whenever the tool gives you one. If a tool fails
or isn't connected, skip it and say so in one short line at the end of the brief.

## 2. Choose what goes in
Follow the brief's `covers`. For the usual parts:
- **Focus:** the three things that matter most today, usually `now.md`'s focus adjusted by
  what's due.
- **Meetings:** the ones left today, with time, title and linked people. Per `meeting_prep`:
  `offer` → `[prep:: offered]` and offer it out loud for the ones that matter; `auto` → schedule
  prep (below) and mark `[prep:: HH:MM]`; `off` → nothing.
- **Catch up:** from `catch-up.md`, the lines raised in fewer than three briefs, oldest replies
  first. Add 1 to `raised` for each line you include. A line that reaches three goes into
  `nudges.md` once, and isn't raised in briefs again; it stays on the notebook page.
- **Follow-ups:** at most five, numbered from 1: replies the user owes (from catch-up), nudges
  to people they're waiting on, messages an action calls for. Write each draft in their voice,
  following their rules and "How I work" in `about-me.md`.
- **Due elsewhere:** due today or overdue in the to-do lists under "Elsewhere" in `actions.md`.
  Never copy those into `actions.md`.
- **Anything else** a brief covers, like "what got done this week" or "next week", comes from
  the log, the archive, `now.md` and the calendar.
- **A later brief in the day** covers only what's new since the brief before it, unless its
  `covers` says otherwise. Don't repeat what an earlier brief said today.

## 3. Write and send
1. If `cos/brief.md`'s date isn't today, start it again: front matter `date`, then
   `# Briefs for <weekday, month day>`. Add this brief as `## <name> [sent:: HH:MM]` with its
   sections as `###` headings. Leave out empty sections.
2. Write the brief as a document to read: `outbox/<YYYY-MM-DD>-<brief name in lowercase, with
   dashes>.md` in this folder, titled with the brief's name and the date, with each part as a
   heading, catch-up lines linking to their threads, and each follow-up's number and full draft.
   (Skip this if the user's rules turn attachments off.)
3. Send it in Carbon Voice with cv-channel's `send_message`, using `channel_id` and
   `reply_to_message_id` from `cos/.cv-thread` (the conversation you last replied in; a hook
   keeps it current), with the document's full path in `attachments`. If `cos/.cv-thread`
   doesn't exist yet, the user hasn't messaged you since setup: keep the brief, and give it the
   next time they message you. The spoken text follows "What goes in my briefs" for length, and
   is otherwise under a minute: open with the brief's name ("Here's your midday check-in"),
   then the parts in order, then the follow-ups by number with a few words each, ending with
   something like "The details are attached. Tell me the numbers you want me to do." Speaking
   rules apply: no lists, no links.
4. Add one line to today's log.

## 4. Check in about the briefs
Keep `cos/.brief-checkin` with two lines, `first: <date of the first brief>` and
`asked: <date you last asked, or never>`. Create it with the first brief. At the end of a
morning brief, add one question if it's 7 days or more since `first` and you've never asked, or
30 days or more since `asked` and "My briefs" and "What goes in my briefs" haven't changed since
then: "You've had a week of briefs. Anything you want more of, less of, or never want to hear
again?" Update `asked`. When they answer, change their briefs as below.

## 5. Changing briefs
When the user asks for a new brief, a different time, days or contents ("add a midday check-in
at 12:30 that covers what came in since the morning", "drop meetings from my briefs", "always
tell me about anything from Lena"), edit "My briefs", "What goes in my briefs" or "Important
people" in `my-rules.md` (with `src`), confirm in one sentence, and reschedule.

Asked why something was in a brief, say which brief part, rule, important person or default
put it there.

## 6. Scheduling
Only the next brief is ever scheduled, as a one-time task, so it runs on time and never
expires. Do this after every brief, whenever briefs change, and when the start-up notes ask:
1. List your scheduled tasks (CronList). Delete (CronDelete) every one whose prompt starts with
   "Use the cos:brief skill now".
2. From "My briefs", find the next brief after now: today's later ones first, then the
   following days, by each brief's `days` (`weekdays` is Monday to Friday; `off` never runs).
3. Create a one-time task (CronCreate, not repeating) at that day and time, with the prompt
   "Use the cos:brief skill now: <brief name>."
If no brief runs on any day, schedule nothing.

## Catch me up
"Catch me up since Friday" (or "on the last three days", "on what I missed this morning"): do
step 1 over that window instead of 7 days, then send a short spoken summary: what needs their
reply, what they may have missed, what changed, and up to five numbered follow-ups, with the
details attached as a document, as for a brief. Write it into `brief.md` as
`## Catch-up [sent:: HH:MM]`, so the numbers work the same way.

## Meeting prep
For prep asked for, offered and accepted, or scheduled by `auto` (a one-time task 15 minutes
before the meeting, with the prompt "Use the cos:brief skill to send prep for the <time>
<title> meeting."):
- Gather: the people's notes and last contact, open actions, waiting and catch-up items that
  link them or the meeting's project, recent decisions, the project's status and next step, and
  their recent messages to the user.
- Send three to five spoken sentences: what this meeting is for, what's open with them, what
  the user promised, and one thing worth raising. Attach the fuller prep as a document.
- Add the prep as a quote under that meeting in `brief.md`, and set `[prep:: ready]`.

## "Do 1 and 3"
When the user answers with numbers, that is their approval for those follow-ups only, from the
latest brief in `brief.md`:
1. If they changed the wording, use theirs.
2. Send it with the tool it belongs to (reply in the same email thread or chat). If that tool
   can only make drafts, make a draft and say so. If none fits, read the draft back and ask how
   to send it.
3. Add `[done:: <today>]` to the follow-up, update the matching action, waiting or catch-up
   line (check it off, set `nudged::`, or archive it with `why:: replied`), and log it.
4. Confirm in one sentence what was sent, to whom.
Never send a follow-up they didn't name.
