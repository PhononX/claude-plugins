---
name: consolidate
description: Nightly or weekly consolidation of the chief-of-staff state. Reads recent logs and transcripts, rewrites now.md to stay current and short, archives closed loops, flags stale ones, and writes nudges for the next day. Use for scheduled headless runs, or when asked to consolidate, review, tidy, or do the weekly review.
---

# cos:consolidate

Usually runs headless overnight via `nightly.sh`. Goal: tomorrow's session starts with an
accurate, small picture. Keep `now.md` under about 40 lines. If `cos/.onboarding-pending`
exists and `now.md` is still empty, append "nothing to consolidate" to
`cos/log/consolidation.md` and stop.

## Steps
1. **Gather.** Read `cos/log/*.md` entries newer than the last `## Consolidated` heading in
   `cos/log/consolidation.md`. Search (don't read whole) transcripts in `cos/log/transcripts/`
   archived since then.
2. **Compare with state.** For each file in `cos/`, list what's new, changed, or contradicted.
3. **Rewrite `now.md`.** Keep the sections *This week*, *In flight*, *Parked*. Move anything
   untouched for 14+ days to *Parked*. Move *Parked* items untouched for 45+ days into
   `log/consolidation.md` as "retired".
4. **Loops.** Move closed loops older than 7 days to `log/closed-loops.md`. Mark open loops that
   are past due, or older than 10 days with no due date, as **stale**.
5. **Decisions.** Never edit past decisions. If a new one supersedes an old one, append
   `(superseded YYYY-MM-DD → see <new>)` to the old line.
6. **Nudges.** Overwrite `cos/nudges.md` with at most 3 items for tomorrow: stale loops, things
   due within 48 hours, contradictions you couldn't resolve. Phrase each as one spoken sentence.
   Inferences go here as questions, never into the state files.
7. **Record.** Append to `log/consolidation.md`:
   `## Consolidated YYYY-MM-DD HH:MM` followed by a 3–5 line summary of what changed.

## Rules
- Only file what the user said or confirmed.
- Prefer fewer, truer lines over completeness.
