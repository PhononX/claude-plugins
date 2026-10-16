---
name: capture
description: Files what matters from a conversation into the chief-of-staff notebook in cos/ — actions, things others owe, decisions, ideas to come back to, links, facts, people, projects, and the user's own rules. Use after ANY exchange where the user decides something, commits to something, asks you to track or follow up on something, changes priorities, mentions an idea, shares a link or fact worth keeping, tells you how to work, or mentions a person's or project's status — even if they don't say "remember". Also use in reconcile mode after context compaction.
---

# cos:capture

Small, surgical edits to `cos/`. Never rewrite whole files here; that's cos:consolidate's job.
Don't mention filing in your reply unless asked.

**Read `notes-format.md` in this skill's folder before your first capture in a session.** It has
the layout and the exact line format. The notebook page is built from these files, so a line
that doesn't follow the format doesn't show up properly.

## What goes where
| Signal | File |
|---|---|
| The user will do something | `actions.md`, under "To do" |
| Someone else owes the user something | `waiting.md`, the person's link first |
| A choice was made | `decisions.md` |
| An idea, or "remind me about that some time" | `ideas.md`, with `back::` saying when to bring it back |
| A link worth finding again | `links.md` (or the project's note, if it only matters there) |
| A fact worth finding again | `facts.md`, or the note of the person or project it's about |
| Focus or this week's dates changed | `now.md` |
| News about a person | `people/<Name>.md` |
| News about a project or an ongoing area | `projects/<Name>.md`, `areas/<Name>.md` |
| "From now on…", or how they want you to work | `my-rules.md` |
| A change to their briefs: a new brief, a time, what to include or skip, someone to always mention | `my-rules.md` ("My briefs", "What goes in my briefs", "Important people"), then reschedule as the cos:brief skill describes |
| They replied to, or want to skip, something from a brief's catch-up | `catch-up.md`: archive the line with `why:: replied` or `why:: skipped` |
| Something you learned about how they work, without being told | `about-me.md`, under "Learned" |
| A tool or place where their conversations or to-dos happen | `sources.md`, and "Elsewhere" in `actions.md` for to-do lists |
| They want to write something, or say something for a piece they're writing ("add this to the board narrative") | `drafts/<Name>.md`, through the cos:draft skill |
| Where a kind of finished work should go ("my documents go in Google Docs") | `my-rules.md`, under "My tools" |
| How they write, or how a draft should sound, for a kind of writing or audience | `about-me.md`, under "How I write" (a rule they state goes in `my-rules.md`) |
| Worth keeping, but you're not sure where | `inbox.md` |
| A trace of what happened | `log/YYYY-MM-DD.md`, one line |

Check `my-rules.md` under "Where things go" first: the user's own routing wins. If their team's
tasks live in another tool, don't copy those tasks into `actions.md`.

Always add `src::`. Link people, projects and areas with `[[Name]]` in the sentence. Create a
`people/` or `projects/` note only for someone or something that keeps coming up, or that the
user names as a project; otherwise the link alone is enough.

## The bar
File it if the user would be annoyed to re-explain it next week. Skip musings, options that
weren't chosen, and your own suggestions they didn't adopt. Your recommendation is not a
decision until they say so. Never file passwords, access codes or keys.

## Moving things
- **Finished:** check the box and add `[done:: YYYY-MM-DD]`. Consolidation archives it.
- **An idea or inbox item clearly belongs to a project:** add the project's link to the line.
- **An idea keeps coming back, or gathers people and dates:** don't promote it yourself. Add a
  line under "Suggested moves" in `now.md` and ask when the moment fits. When the user agrees,
  create the project note, move the idea's line into its "Notes" section, and remove the
  suggestion.
- **The user says "that's a project":** create `projects/<Name>.md` with `status: active` and
  any due date they gave, and move related lines in.
- **A project is done:** set `status: done` and add one line on how it ended. Never delete the note.

## Reconcile mode (after compaction)
You'll be given an archived transcript path. Don't read it whole. Search for signal:
`grep -inE "decid|let's go with|we'll|i'll|follow up|remind|waiting on|by (mon|tue|wed|thu|fri|next)|idea|from now on|link|http" <path>`
Read around the hits, compare with `cos/`, and file only what's missing.
