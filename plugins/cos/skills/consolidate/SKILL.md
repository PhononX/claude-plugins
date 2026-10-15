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
   archived since then. File anything that was missed, as cos:capture would.
2. **Compare with the notebook.** For each file in `cos/`, list what's new, changed, or
   contradicted.
3. **Now.** Keep `now.md` short: at most three focus lines, and "This week" holding only dates in
   the next 7 days. Drop past dates.
4. **Archive, never delete.** Move lines to `cos/archive/YYYY-MM.md` (this month), adding
   `[archived:: <today>]`, `[from:: <file name without .md>]` and a short `[why:: …]`:
   - checked items in `actions.md` and `waiting.md` finished more than 7 days ago
     (`why:: done <date>`);
   - unchecked items with no due date, untouched for `stale_days` days (30 unless set), and
     ideas past their `back` time that never came up again (`why:: no mention for N days`).
     Before archiving one of these, check the logs and transcripts for any mention.
   - Items past due but still relevant stay, and become a nudge.
5. **Decisions.** Never edit a past decision. If a new one replaces an old one, add
   `[superseded:: <date>]` to the old line.
6. **Suggest moves.** Under "Suggested moves" in `now.md`, add at most three proposals, one line
   each, phrased as a question: inbox items that clearly belong somewhere, an idea that has come
   up three or more times or gathered people and dates ("make it a project?"), a project whose
   work all looks finished ("close it?"), a person who now deserves their own note. Don't
   reorganize anything yourself; the user decides. Leave existing suggestions they haven't
   answered.
7. **Nudges.** Overwrite `cos/nudges.md` with at most `nudges_per_day` items (3 unless set) for
   tomorrow: items due within 48 hours or overdue, people waited on longest, ideas whose `back`
   time has come, contradictions you couldn't resolve. Phrase each as one spoken sentence.
   Inferences go here as questions, never into the notes.
8. **Record.** Append to `log/consolidation.md`: `## Consolidated YYYY-MM-DD HH:MM` followed by
   a 3–5 line summary of what changed, and one line in today's daily log.

## Rules
- Only file what the user said or confirmed.
- Prefer fewer, truer lines over completeness.
- Never delete a line or a note. Archive it.
