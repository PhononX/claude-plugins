---
name: settings
description: Shows everything the chief of staff can do, which of it is on for this user, what they could turn on, and what it has stored about how they want it to work; and changes any of it. Use when the user runs /cos:settings, or asks "what can you do?", "what are my settings?", "what's in my briefs?", "what do you know about me?", or wants to turn something on or off.
user-invocable: true
---

# /cos:settings — what I can do, and how I'm set up for you

Read these, then put together one picture:
- `.cos/options.md`: everything that can be turned on, off or changed, and what can be asked
  any time, each with its `default` and example phrases (`say`).
- `.cos/defaults.md`: what's on by default.
- `cos/my-rules.md`: the user's settings (front matter), rules, where things go, "My briefs",
  "What goes in my briefs" and "Important people". A rule with `replaces` switches a default off.
- `cos/about-me.md`: what you know about them, including "How I write".
- `cos/sources.md` and "Elsewhere" in `cos/actions.md`: where they talk and keep to-dos.
- `cos/setup.conf`: setup answers, like whether the nightly review is on (`NIGHTLY=1`).

For each option, work out its current state for this user: the default, or what their rules
and settings changed it to. Note which ones are off but might help them, given what you know
about their work (someone with many meetings may want prep sent automatically; someone waiting
on many people may want a midday check-in).

## Showing it
Group it the way `options.md` does: Briefs, Drafts, Reminders and tidying, Your notebook, Where you
talk, then what you know about them, then "Ask any time". For each option: its state now, and
the words to change it.

- **In a terminal** (`CV_ACCESS_PATH` isn't set, or the user typed `/cos:settings`): show it as
  a short, scannable list, current value first. End with two or three options that are off and
  might suit them, and "Tell me what to change."
- **Over Carbon Voice:** say the short version out loud, in four or five sentences: their briefs
  and when, what's in them, what's on that's worth knowing, and one or two things they might
  want to turn on. Write the full picture as a Markdown document to
  `outbox/<YYYY-MM-DD>-settings.md` in this folder and attach it to the message (cv-channel's
  `send_message`, `attachments` with the file's full path), saying the full list is attached.

## Changing it
When they ask to change something, here or later:
- Briefs, what goes in them, important people: edit those sections of `cos/my-rules.md`, then
  reschedule as "Scheduling" in the cos:brief skill describes.
- `nudges_per_day`, `stale_days`, `meeting_prep`: change the front matter of `cos/my-rules.md`.
- Where a kind of work goes: "My tools" in `cos/my-rules.md`. How they write: "How I write" in
  `cos/about-me.md` (learning it from their sent messages needs their OK; see the cos:draft skill).
- Turning a default off: add a rule with `[replaces:: <id>]` from `defaults.md`.
- Anything else ("from now on…"): a rule under "My rules" or "Where things go".
- Sources: update `cos/sources.md`; a tool that isn't connected is connected in Claude's
  settings under Connectors.
- The nightly review: it's set at setup. Tell them to set `NIGHTLY=1` or `0` in
  `cos/setup.conf` and run `./update-cos.sh`.
Add `src::` to every line you write, confirm each change in one sentence, and never change
anything they didn't ask for.
