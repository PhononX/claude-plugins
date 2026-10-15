---
name: migrate
description: Moves a chief-of-staff notebook from the old layout (open-loops.md, people.md, the old now.md sections, log/closed-loops.md) to the current one, without losing anything. Use when cos/.layout is missing and cos/open-loops.md or cos/people.md exists, which the start-up notes and the nightly review point out.
---

# cos:migrate — move notes to the current layout

Do this quietly, in one pass, before other work. Read `notes-format.md` in the cos:capture
skill's folder first. Nothing is lost: every old line ends up in a new file or in the archive,
and the old files themselves are kept in `cos/archive/old-layout/`.

1. **open-loops.md.** Each open line `- [ ] <who> → <what> (since <date>, due <date>)`:
   - if the user owes it, it goes to `actions.md` under "To do":
     `- [ ] <what> [due:: <date>] [src:: cv <since>]`, linking any person or project named;
   - if someone else owes it, it goes to `waiting.md`:
     `- [ ] [[<who>]]: <what> [since:: <since>] [src:: cv <since>]`.
   Closed lines (`[x]`) go to `archive/<YYYY-MM of today>.md` with
   `[archived:: <today>] [why:: done <closed date>] [from:: open-loops]`.
2. **people.md.** For each person with more than a line or two of context, create
   `people/<Name>.md` with front matter (`role`, `org` if known) and their context as lines.
   People with a single line of context stay a link and get no note; keep their line in
   `facts.md` if it's worth keeping.
3. **now.md.** The old sections were *This week*, *In flight*, *Parked*. Rewrite it with the new
   ones: *Focus* (the top of "This week", at most three), *This week* (dated items), *Suggested
   moves* (empty). Items "In flight" that are really projects become `projects/<Name>.md`
   (`status: active`), other in-flight work becomes actions, and *Parked* items go to `ideas.md`
   with `[back:: when it comes up again]`.
4. **decisions.md.** Rewrite each `- YYYY-MM-DD — <decision> — why: <reason>` as
   `- YYYY-MM-DD <decision> [why:: <reason>] [src:: cv YYYY-MM-DD]`, keeping any superseded note
   as `[superseded:: <date>]`.
5. **log/closed-loops.md**, if present: its lines go to the archive, as in step 1.
6. **Keep the old files.** Copy `open-loops.md`, `people.md` and `log/closed-loops.md`, and the
   old `now.md` and `decisions.md` as they were before you rewrote them, into
   `cos/archive/old-layout/` (use Write; read each one before changing anything).
7. **Mark it done:** write `2` to `cos/.layout`. This stops the reminder to migrate.
8. In a live session (not the nightly review), offer once to delete the old originals with
   `rm cos/open-loops.md cos/people.md cos/log/closed-loops.md`, which the user approves at the
   computer. Otherwise leave them; nothing reads them any more.
9. Add one line to today's log, and tell the user once, briefly, that their notes moved to the
   new layout and they can see everything on their notebook page (`./open-brain.sh`).
