---
name: consolidate
description: Nightly or weekly review of the chief-of-staff notebook. Reads recent logs and transcripts, keeps now.md current and short, archives finished and stale items with the reason (never deletes), suggests moves such as promoting an idea into a project, and writes nudges for the next day. Use for scheduled headless runs, or when asked to consolidate, review, tidy, or do the weekly review.
---

# cos:consolidate

Usually runs headless overnight via `nightly.sh`. Goal: tomorrow starts with an accurate, small
picture. Read `notes-format.md` in the cos:capture skill's folder first, and keep every line in
that format. Read the settings in the front matter of `cos/my-rules.md` (`stale_days`,
`nudges_per_day`) and its rules; they win over the numbers below.

If `cos/.onboarding-pending` exists and `now.md` has no focus yet, append "nothing to
consolidate" to `cos/log/consolidation.md` and stop.

If `cos/.layout` is missing and `cos/open-loops.md` or `cos/people.md` exists, use the
cos:migrate skill first.

## Steps
1. **Gather.** Read `cos/log/*.md` entries newer than the last `## Consolidated` heading in
   `cos/log/consolidation.md`. Search (don't read whole) transcripts in `cos/log/transcripts/`
   archived since then. File anything that was missed, as cos:capture would. Act on any line
   the user answered on the notebook page (`[answer:: …]`) and file what they added to
   `inbox.md` there.
2. **Compare with the notebook.** For each file in `cos/`, list what's new, changed, or
   contradicted.
3. **Now.** Keep `now.md` short: at most three focus lines, and "This week" holding only dates in
   the next 7 days. Drop past dates.
4. **People.** For each `[[Name]]` with no note that is clearly a person and is linked from two
   or more lines, or appears in "Important people", `waiting.md`, `actions.md` or
   `catch-up.md`, start `people/<Name>.md` as `notes-format.md` shows. Fill the front matter
   only with what the notebook already says (role, org, and `last_talked` from the latest
   dated line that mentions them), and don't copy their items into it: the page shows
   everything that links to them. If you can't tell whether a name is a person or a project,
   leave it. If a link isn't a name at all (`[[Today]]`), remove the brackets.
5. **Archive, never delete.** Move lines to `cos/archive/YYYY-MM.md` (this month), adding
   `[archived:: <today>]`, `[from:: <file name without .md>]` and a short `[why:: …]`:
   - checked items in `actions.md` and `waiting.md` finished more than 7 days ago
     (`why:: done <date>`);
   - unchecked items with no due date, untouched for `stale_days` days (30 unless set), and
     ideas past their `back` time that never came up again (`why:: no mention for N days`).
     Before archiving one of these, check the logs and transcripts for any mention.
   - lines in `catch-up.md` with `kind:: changed` that have been in a brief, and any line older
     than 14 days that the user never took up (`why:: not taken up in 14 days`);
   - Items past due but still relevant stay, and become a nudge.
6. **Decisions.** Never edit a past decision. If a new one replaces an old one, add
   `[superseded:: <date>]` to the old line.
7. **Suggest moves.** Under "Suggested moves" in `now.md`, add at most three proposals, one line
   each, phrased as a question: inbox items that clearly belong somewhere, an idea that has come
   up three or more times or gathered people and dates ("make it a project?"), a project whose
   work all looks finished ("close it?"), or a change
   to their briefs based on how they use them over the last two weeks: a part they never use
   ("you never pick follow-ups at midday; drop them?"), something they keep asking for after a
   brief ("you often ask about Slack; add it to the morning brief?"), or a brief they ignore.
   Drafts, by their `horizon`:
   - a `soon` draft past its due date, or untouched for two weeks: "finish the partner FAQ, or
     drop it?";
   - a `long` draft untouched for three weeks or more: never suggest dropping it. Look through
     what's happened since its `touched` date (logs, ideas, decisions, notes, catch-up) for
     anything that relates to it. If something does, suggest bringing it back, naming what you
     found ("two things you said this week fit the pricing philosophy piece; pick it back up?").
     If nothing does, suggest it only every six weeks or so, gently.
   - a draft with no `horizon` yet: decide it as the cos:draft skill describes, and add it.
   Never archive or delete a draft; finished ones stay in `drafts/` marked `done`, `moved` or
   `dropped`, and only the user drops one.
   Don't reorganize anything yourself; the user decides. Leave existing suggestions they haven't
   answered.
8. **Nudges.** Overwrite `cos/nudges.md` with at most `nudges_per_day` items (3 unless set) for
   tomorrow: items due within 48 hours or overdue, people waited on longest, ideas whose `back`
   time has come, contradictions you couldn't resolve. Phrase each as one spoken sentence.
   Inferences go here as questions, never into the notes.
9. **Record.** Append to `log/consolidation.md`: `## Consolidated YYYY-MM-DD HH:MM` followed by
   a 3–5 line summary of what changed, and one line in today's daily log.

## Rules
- Only file what the user said or confirmed.
- Prefer fewer, truer lines over completeness.
- Never delete a line or a note. Archive it.
