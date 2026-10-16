# The notebook: layout and line format

Everything the chief of staff knows lives in `cos/`, as plain Markdown. The folder opens as an
Obsidian vault as it is: notes link with `[[Name]]`, and extra details on a line use Dataview's
inline field syntax, `[key:: value]`. The notebook page (`brain.html`) is built from these files
with no AI in between, so it can only show what's written here, in this format.

Dates are always `YYYY-MM-DD`. Times are 24-hour `HH:MM`.

## Layout

| File | What it holds |
|---|---|
| `now.md` | Focus (at most 3), this week's key dates, and suggested moves for the user to approve |
| `brief.md` | Today's briefs, one section per brief; started fresh each day |
| `catch-up.md` | What needs the user's reply or attention in their email, chat and Carbon Voice |
| `nudges.md` | Short reminders to raise once, cleared after they're raised |
| `inbox.md` | Captured, not yet sorted |
| `actions.md` | What the user owes, plus pointers to to-do lists kept in other tools |
| `waiting.md` | What other people owe the user |
| `ideas.md` | Ideas and "that thing I mentioned once", with when to bring each back |
| `links.md` | Links worth finding again |
| `facts.md` | Loose facts worth finding again |
| `decisions.md` | What was decided, why, and with whom |
| `drafts/<Name>.md` | One note per piece of writing being shaped: an email, document, deck, message or post |
| `projects/<Name>.md` | One note per project: an outcome with an end |
| `areas/<Name>.md` | One note per ongoing responsibility, which never "finishes" |
| `people/<Name>.md` | One note per person |
| `log/YYYY-MM-DD.md` | One note per day: what was captured and changed |
| `archive/YYYY-MM.md` | Finished, dropped and stale items, each with the reason |
| `my-rules.md` | The user's own rules and settings. These win over the defaults |
| `about-me.md` | What the agent knows about the user, told and learned |
| `sources.md` | Where the user's conversations and to-dos happen, and what the agent reads in each |

Names of notes are the plain name, as people say it: `people/Dana Whitfield.md`,
`projects/Q4 Launch.md`. Links use that name exactly: `[[Dana Whitfield]]`. Don't create a note
for someone or something mentioned once; a link with no note yet is fine.

## Lines

Most files are lists. One item per line, starting `- `. Write the plain sentence first, then
the fields. Links to people, projects and areas go inside the sentence, where they read
naturally.

```
- [ ] Send the v3 pricing deck to [[Dana Whitfield]] for [[Q4 Launch]] [due:: 2026-10-16] [src:: cv 2026-10-13]
```

A line can carry an indented quote on the next line, for what the user actually said or for a
draft:

```
- A referral program: a free seat for each team a customer brings in [back:: when v3 pricing is set] [src:: cv 2026-10-02]
  > Remind me about the free-seat referral thing once pricing's done.
```

### Fields

| Field | Used in | Value |
|---|---|---|
| `due` | actions | `YYYY-MM-DD` |
| `since` | waiting | the date it started waiting |
| `nudged` | waiting | the last date the user was reminded |
| `back` | ideas | when to bring it back, in words ("when v3 pricing is set") or a date |
| `why` | decisions, archive | the reason, in one short phrase |
| `superseded` | decisions | the date a later decision replaced this one |
| `done` | actions, waiting | the date it was finished |
| `archived` | archive | the date it was archived |
| `from` | archive | the file it came from, like `actions` |
| `prep` | brief meetings | `ready`, `offered`, or `HH:MM` when prep will be sent |
| `sent` | brief headings | the time that brief was sent, `HH:MM` |
| `kind` | catch-up | `reply` (someone asked the user something), `missed` (unread or unanswered and worth seeing), or `changed` (news that moves a project, action or waiting item) |
| `raised` | catch-up | how many briefs have mentioned it |
| `at`, `days`, `covers` | my-rules briefs | a brief's time, its days, and what it covers |
| `src` | anything | where it came from: `<source> <YYYY-MM-DD>`, then a link if there is one |
| `replaces` | my-rules rules | the id of the default it replaces |
| `status`, `via`, `reads` | sources | connected or not, through what, and what the agent reads there |
| `for` | my-rules tools, about-me writing | the kind of work: `email`, `doc`, `deck`, `slack`, `text`, `post`, `notes`, or another word |
| `audience` | about-me writing | who it's written to: `colleagues`, `team`, `executives`, `clients`, `friends`, `family`, or another word |

`src` sources are short, lowercase names: `cv` (Carbon Voice), `gmail`, `cal`, `slack`,
`linear`, `asana`, `notion`, `jira`, `drive`, `file` (a file on this computer), `onboarding`, or
the name of another tool. Everything the user tells the agent directly comes in through
Carbon Voice, so it's `cv`. Add the link to the original message or email when you have one:
`[src:: gmail 2026-10-12 https://mail.google.com/...]`.

## Each file

**actions.md**
```
# My actions

## To do
- [ ] Reply to [[Jordan Kim]] with Q3 churn numbers [due:: 2026-10-14] [src:: gmail 2026-10-12]
- [x] Send Q3 roadmap recap to the team [done:: 2026-10-12] [src:: cv 2026-10-08]

## Elsewhere
- Linear: issues assigned to me [via:: claude.ai connector]
- Asana: Marketing launch board, my tasks [via:: claude.ai connector]
```
"Elsewhere" points to to-do lists the user keeps in other tools. Never copy those items here.

**waiting.md**: the person's link comes first.
```
- [ ] [[Priya Natarajan]]: engineering estimate for usage-based billing [since:: 2026-10-06] [nudged:: 2026-10-10] [src:: cv 2026-10-06]
```

**decisions.md**: the date comes first. Never edit a past decision; mark it superseded.
```
- 2026-10-09 Team tier drops to $18 per seat, with a 10-seat minimum, agreed with [[Dana Whitfield]] [why:: matches the two closest competitors] [src:: cv 2026-10-09]
```

**links.md**: a Markdown link, then context.
```
- [Customer beta signup form](https://forms.example.com/v3-beta) for [[Q4 Launch]] [src:: slack 2026-10-03]
```

**facts.md**
```
- Acme has 340 seats, and the renewal date is Dec 1, for [[Acme Logistics renewal]] [src:: gmail 2026-09-29]
```
A fact about one person goes in that person's note; one about one project goes in the project's
note. `facts.md` holds the rest. Never store passwords, access codes or keys anywhere in `cos/`.

**inbox.md**, **ideas.md**: plain lines with `src`, and `back` for ideas.

**archive/YYYY-MM.md**: lines move here with the reason. Nothing is ever deleted.
```
- [x] Look into the conference sponsorship for March [archived:: 2026-10-12] [why:: no mention for 30 days] [from:: actions] [src:: cv 2026-09-10]
```

**now.md**
```
# Now

## Focus
- Lock v3 pricing before Friday's [[Q4 Launch]] review

## This week
- 2026-10-16 Pricing review with [[Dana Whitfield]]

## Suggested moves
- The referral idea has come up three times. Make it a project? [src:: cv 2026-10-14]
```
"Suggested moves" are proposals the user hasn't agreed to yet: an inbox item to file, an idea to
promote into a project, a project to close. Remove each once the user answers.

**brief.md**: one section per brief sent today, under the brief's name and the time it was
sent. The first brief of the day starts the file again.
```
---
date: 2026-10-15
---
# Briefs for Thursday, October 15

## Morning brief [sent:: 07:02]

### Focus
- Lock v3 pricing before Friday's [[Q4 Launch]] review

### Meetings
- 09:30 Pricing review with [[Dana Whitfield]] and [[Priya Natarajan]] [prep:: ready]
  > The three open questions on the Team tier, and Dana's discount ask from Tuesday.
- 13:00 Acme renewal call with [[Lena Fischer]] [prep:: 12:45]

### Catch up
- [[Jordan Kim]] asked for the Q3 churn numbers [kind:: reply] [since:: 2026-10-12] [src:: gmail 2026-10-12 https://mail.google.com/...]
- Acme moved the renewal call to Dec 3 [kind:: changed] [src:: gmail 2026-10-14]

### Follow-ups
1. Send the v3 pricing deck to [[Dana Whitfield]] [src:: cv 2026-10-13]
   > Dana, here's the v3 deck. Slide 6 has the Team tier change we talked about.
2. Answer [[Jordan Kim]]'s question on Q3 churn [src:: gmail 2026-10-12]
   > Jordan, Q3 logo churn was 2.1%, down from 2.8%.

### Due elsewhere
- PRD-398 Sign off on SSO release notes [due:: 2026-10-15] [src:: linear 2026-10-15 https://linear.app/...]

## Midday check-in [sent:: 12:31]

### Catch up
- [[Priya Natarajan]] asked whether SSO can ship Thursday [kind:: reply] [since:: 2026-10-15] [src:: slack 2026-10-15]

### Follow-ups
1. Tell [[Priya Natarajan]] SSO can ship Thursday [src:: slack 2026-10-15]
   > Yes, ship it Thursday.
```
Section names inside a brief are free: use the ones its `covers` asks for (Focus, Meetings,
Catch up, Follow-ups, Due elsewhere, This week, Done this week, …), and leave out empty ones.
Follow-ups are numbered from 1 in each brief, so the user can answer "do 1 and 3"; the numbers
always mean the latest brief. The quote under each is the draft.

**catch-up.md**: what needs the user's reply or attention, kept between briefs so an item isn't
forgotten after one mention, and isn't repeated forever. One line per thread, linking to it.
```
# Catch up

## Needs your reply
- [[Jordan Kim]] asked for the Q3 churn numbers [kind:: reply] [since:: 2026-10-12] [raised:: 2] [src:: gmail 2026-10-12 https://mail.google.com/...]

## You may have missed
- Three unread emails from [[Lena Fischer]] about seat counts [kind:: missed] [since:: 2026-10-14] [raised:: 1] [src:: gmail 2026-10-14 https://mail.google.com/...]

## Changed
- Acme moved the renewal call to Dec 3, for [[Acme Logistics renewal]] [kind:: changed] [since:: 2026-10-14] [raised:: 1] [src:: gmail 2026-10-14]
```
When the user replies, says to skip it, or the thread is dealt with, the line moves to the
archive with the reason (`why:: replied`, `why:: skipped`). "Changed" lines move to the archive
once they've been in one brief and filed into the notebook.

**people/<Name>.md**, **projects/<Name>.md**, **areas/<Name>.md** start with front matter, then
free Markdown. Everything that links to the note shows up on its page, so don't repeat those
items in the note.
```
---
role: Head of Sales
org: Northwind
last_talked: 2026-10-13
rhythm: Weekly pricing sync, Thursdays
---
# Dana Whitfield

- Prefers a short written summary before any pricing meeting [src:: cv 2026-10-09]
```
```
---
status: active
due: 2026-11-18
area: Product
---
# Q4 Launch

## Outcome
v3 pricing and the new onboarding live for all customers.

## Next
- Lock v3 pricing at Thursday's review
```
Project `status` is `active`, `paused`, `done` or `dropped`. A finished project keeps its note
with `status: done` and a line saying how it ended; the notebook page lists it under Archive.
Areas have no status or due date.

**drafts/<Name>.md**: a piece of writing while it's being shaped by talking. Front matter, then
the draft, then the notes it was built from. The agent owns this file until the draft moves to
one of the user's tools.
```
---
kind: doc
status: draft
for: "[[Jordan Kim]]"
project: "[[Board deck]]"
due: 2026-11-06
version: 3
---
# Board narrative

## Draft
Q3 was the quarter we stopped losing small teams…

## Notes
- Lead with the churn number, then the two big losses [src:: cv 2026-10-14]
  > Start with churn, Jordan always asks about it first.
- Pricing story goes second; keep it to one slide [src:: cv 2026-10-15]

## History
- v3 2026-10-15 shorter opening, churn first [src:: cv 2026-10-15]
- v2 2026-10-14 first full draft
- v1 2026-10-12 outline
```
- `kind` is `email`, `doc`, `deck`, `message`, `post` or another word. `for` and `project` link
  the person and project it's for.
- `status` goes `notes` (only notes so far) → `outline` → `draft` → `ready` → `moved` (it now
  lives in one of the user's tools) or `done` (sent, or finished here) or `dropped`.
- Each new version replaces the "Draft" section; the version before it is kept as
  `drafts/.history/<Name>/v<N>.md`, and "History" gets one line saying what changed.
- For a deck, the draft is slide by slide: `### 1. Title` then the slide's points, with
  `> Speaker notes:` under each slide.
- When it moves, add `moved_to` (the tool) and `link` (the address of the copy there) to the front
  matter and set `status: moved`. The tool's copy is the real one from then on; the draft here
  keeps its notes and last version, and says where it went.
  ```
  status: moved
  moved_to: Google Docs
  link: https://docs.google.com/document/d/...
  ```
- A draft can be started from an idea in `ideas.md`; move that idea's line into "Notes".

**my-rules.md**: settings in the front matter, rules and preferences as lines. A rule that
changes a default names it with `replaces`; the default ids are in `.cos/defaults.md`.
```
---
nudges_per_day: 3
stale_days: 30
meeting_prep: offer
---
# My rules for Ada

## My rules
- Drafts should sound like me: plain, short, no exclamation marks [src:: cv 2026-10-04]

## Where things go
- Team tasks live in Linear. Point to them; don't copy them [replaces:: todos] [src:: cv 2026-10-13]

## My briefs
- Morning brief [at:: 06:45] [days:: weekdays] [covers:: focus, meetings, catch up, follow-ups, due elsewhere] [src:: cv 2026-10-05]
- Midday check-in [at:: 12:30] [days:: weekdays] [covers:: what came in since the morning, afternoon meetings, follow-ups] [src:: cv 2026-10-14]
- Friday wrap-up [at:: 16:30] [days:: fri] [covers:: what got done, what slipped, next week] [src:: cv 2026-10-09]

## What goes in my briefs
- Keep each brief under a minute [src:: onboarding 2026-10-01]
- Skip newsletters, GitHub notifications and anything from #random [src:: cv 2026-10-07]

## Important people
- [[Jordan Kim]]: anything from him, always [src:: onboarding 2026-10-01]
- Anything from the board [src:: cv 2026-10-06]

## My tools
- Emails: Gmail, as drafts [for:: email] [src:: cv 2026-10-15]
- Documents: Google Docs, in the "Northwind" folder [for:: doc] [src:: cv 2026-10-12]
- Presentations: Google Slides [for:: deck] [src:: onboarding 2026-10-01]
- Team updates: Slack, #product-leads [for:: message] [src:: cv 2026-10-09]
```
**My briefs** has one line per brief: its name, then `at` (`HH:MM`), `days` (`weekdays`, `daily`,
`weekends`, `off`, or days like `mon, wed, fri`) and `covers` (what it's for, in plain words).
**What goes in my briefs** holds preferences for every brief; a brief's own `covers` wins where
they differ. **Important people** always make it into a brief. **My tools** says where each kind of
finished work goes: one line per kind, naming the tool (and any folder or channel), with `for`.

`meeting_prep` is `offer` (offer it in the brief), `auto` (send prep before meetings with people
who have a note) or `off`. When a rule changes a setting, change the front matter too.

An older `my-rules.md` may still have `brief_time` and `brief_days` in its front matter and no
"My briefs" section. Treat that as a single "Morning brief" at that time on those days.

**about-me.md**
```
# About me

## Role
- VP of Product at Northwind [src:: onboarding 2026-10-01]

## How I write
- Short and direct, two to four sentences; first names, no greeting line; signs off "– Alex" [for:: email] [audience:: colleagues] [src:: gmail 2026-10-02]
- More formal: "Hi Lena," then the ask in the first sentence; ends "Best, Alex" [for:: email] [audience:: clients] [src:: gmail 2026-10-02]
- Numbers first, then the story; one page at most [for:: email] [audience:: executives] [src:: gmail 2026-10-02]
- Lowercase, quick, emoji reactions instead of "thanks" [for:: slack] [audience:: team] [src:: slack 2026-10-02]
- Casual, jokes, lots of exclamation marks [for:: text] [audience:: friends] [src:: onboarding 2026-10-01]

## Learned
- Talks through decisions on walks, usually 8 to 8:30am [src:: cv 2026-10-10]
```
"Learned" holds what the agent noticed rather than was told. Tell the user once when you add one.

"How I write" has one line per kind of writing and audience, saying what that writing sounds
like, with `for` and `audience`. Learn it only with the user's permission (asked in onboarding,
or when they ask), from a handful of their own sent messages of that kind; say what you noticed
and let them correct it. Update a line when they change a draft before sending it in a way that
shows a pattern, and tell them once. Rules they state outright ("no exclamation marks in work
email") go in `my-rules.md`, which wins over anything learned here. When writing anything for
the user, use the line that matches its kind and audience; with no line for it, ask or keep it
plain.

**sources.md**
```
# Where I talk

- Carbon Voice [status:: connected] [via:: cv-channel and the Carbon Voice connector] [reads:: messages to me, and conversations you chose]
- Gmail [status:: connected] [via:: claude.ai connector] [reads:: inbox, read-only]
- Notion [status:: not connected] [reads:: where your specs live]
```

**log/YYYY-MM-DD.md**
```
# 2026-10-14

- 09:12 Captured: Lena raised uptime credits again; draft an offer by Friday [src:: cv 2026-10-14]
- 02:15 Nightly review: archived 3 finished items and 1 stale one
```
