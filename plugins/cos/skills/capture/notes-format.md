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
| `brief.md` | The latest morning brief, rewritten each morning |
| `nudges.md` | Short reminders to raise once, cleared after they're raised |
| `inbox.md` | Captured, not yet sorted |
| `actions.md` | What the user owes, plus pointers to to-do lists kept in other tools |
| `waiting.md` | What other people owe the user |
| `ideas.md` | Ideas and "that thing I mentioned once", with when to bring each back |
| `links.md` | Links worth finding again |
| `facts.md` | Loose facts worth finding again |
| `decisions.md` | What was decided, why, and with whom |
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
| `src` | anything | where it came from: `<source> <YYYY-MM-DD>`, then a link if there is one |
| `replaces` | my-rules rules | the id of the default it replaces |
| `status`, `via`, `reads` | sources | connected or not, through what, and what the agent reads there |

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

**brief.md**: rewritten by each morning brief.
```
---
date: 2026-10-15
sent: "07:02"
---
# Brief for Thursday, October 15

## Focus
- Lock v3 pricing before Friday's [[Q4 Launch]] review

## Meetings
- 09:30 Pricing review with [[Dana Whitfield]] and [[Priya Natarajan]] [prep:: ready]
  > The three open questions on the Team tier, and Dana's discount ask from Tuesday.
- 13:00 Acme renewal call with [[Lena Fischer]] [prep:: 12:45]

## Follow-ups
1. Send the v3 pricing deck to [[Dana Whitfield]] [src:: cv 2026-10-13]
   > Dana, here's the v3 deck. Slide 6 has the Team tier change we talked about.
2. Answer [[Jordan Kim]]'s question on Q3 churn [src:: gmail 2026-10-12]
   > Jordan, Q3 logo churn was 2.1%, down from 2.8%.

## Due elsewhere
- PRD-398 Sign off on SSO release notes [due:: 2026-10-15] [src:: linear 2026-10-15 https://linear.app/...]
```
Follow-ups are numbered so the user can answer "do 1 and 3". The quote under each is the draft.

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

**my-rules.md**: settings in the front matter, rules as lines. A rule that changes a default
names it with `replaces`; the default ids are in `.cos/defaults.md`.
```
---
brief_time: "07:00"
brief_days: weekdays
nudges_per_day: 3
stale_days: 30
meeting_prep: offer
---
# My rules for Ada

## My rules
- Send the morning brief at 6:45 [replaces:: brief] [src:: cv 2026-10-05]
- Drafts should sound like me: plain, short, no exclamation marks [src:: cv 2026-10-04]

## Where things go
- Team tasks live in Linear. Point to them; don't copy them [replaces:: todos] [src:: cv 2026-10-13]
```
`brief_days` is `weekdays`, `daily` or `off`. `meeting_prep` is `offer` (offer it in the brief),
`auto` (send prep before meetings with people who have a note) or `off`. When a rule changes a
setting, change the front matter too.

**about-me.md**
```
# About me

## Role
- VP of Product at Northwind [src:: onboarding 2026-10-01]

## Learned
- Talks through decisions on walks, usually 8 to 8:30am [src:: cv 2026-10-10]
```
"Learned" holds what the agent noticed rather than was told. Tell the user once when you add one.

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
