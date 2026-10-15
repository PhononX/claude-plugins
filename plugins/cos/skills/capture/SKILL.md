---
name: capture
description: Files decisions, commitments, priority changes, open loops and context about people into the chief-of-staff state in cos/. Use after ANY exchange where the user decides something, commits to something, asks you to track or follow up on something, changes priorities, or mentions a person's status — even if they don't say "remember". Also use in reconcile mode after context compaction.
---

# cos:capture

Small, surgical edits to `cos/`. Never rewrite whole files here; that's cos:consolidate's job.
Don't mention filing in your reply unless asked.

## What goes where
| Signal | File | Format |
|---|---|---|
| A choice was made | `decisions.md` | `- YYYY-MM-DD — <decision> — why: <reason>` |
| Someone owes something, or the user does | `open-loops.md` | `- [ ] <who> → <what> (since YYYY-MM-DD, due <date or ?>)` |
| Focus or priority shifted | `now.md` | Edit the relevant line in place |
| Context about a person changed | `people.md` | Update that person's line, or add one |
| Anything else worth a trace | `log/YYYY-MM-DD.md` | `- HH:MM <one line>` |

## The bar
File it if the user would be annoyed to re-explain it next week. Skip musings, options that
weren't chosen, and your own suggestions they didn't adopt. Your recommendation is not a
decision until they say so.

## Closing loops
When a loop resolves, check its box and append `(closed YYYY-MM-DD)`. Don't delete it;
consolidation archives closed loops.

## Reconcile mode (after compaction)
You'll be given an archived transcript path. Don't read it whole. Search for signal:
`grep -inE "decid|let's go with|we'll|i'll|follow up|remind|waiting on|by (mon|tue|wed|thu|fri|next)" <path>`
Read around the hits, compare with `cos/`, and file only what's missing.
