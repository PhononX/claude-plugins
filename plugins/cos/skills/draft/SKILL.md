---
name: draft
description: Shapes a piece of writing with the user by voice — an email, document, deck, message or post — from scattered notes to an outline to versions, in cos/drafts/, written in their voice for that kind of writing and audience. When it's ready, asks whether to keep it or move it to the tool they use for that kind of work, remembers the answer, and links to where it went. Use when the user asks to start, add to, outline, restructure, revise, read back or finish a draft, organize their thoughts on something they're writing, or asks where a draft ended up.
---

# cos:draft — drafts, from notes to a finished piece

Read `notes-format.md` in the cos:capture skill's folder for the format of `cos/drafts/`,
"My tools" in `my-rules.md` and "How I write" in `about-me.md`. Replies are spoken: say what you
did in a sentence or two, and attach the draft as a document (see CLAUDE.md) whenever there's
more to read than that.

## Starting one
"Start a draft email to Dana about the pricing change", "I want to write the board narrative".
1. Ask at most two short questions, only if you can't tell: what it's for (the one thing it should
   achieve) and who it's for. Skip what's obvious from the notebook.
2. Create `cos/drafts/<Name>.md` with `kind`, `status`, `for`, `project`, `due` if known,
   `version: 1`. Pull in what the notebook already knows: the person's note, the project's
   decisions and facts, open actions, and any idea in `ideas.md` it grew from (move that line
   into "Notes").
3. If there's enough to go on, write a first version under "Draft" (`status: draft`); if it's
   mostly ideas, write an outline (`status: outline`); if there's very little, keep notes
   (`status: notes`) and say what's missing.
4. Write it in the user's voice for that kind and audience, from "How I write" in `about-me.md`,
   following their rules in `my-rules.md`. With no matching line, keep it plain, and ask once
   whether you may learn that style (below).

## Shaping it
- **Adding to it**, from any conversation: "add this to the board narrative: …", or anything said
  that clearly belongs to an open draft. Add it under "Notes" with `src` and the user's words as
  a quote. Don't rewrite the draft unless they ask.
- **Organizing ideas:** "turn my notes into an outline", "what do I have so far?" Group the notes,
  put them in an order that serves the point, and name what's missing ("you haven't said what you
  want from the board"). For a deck, outline slide by slide.
- **Revising:** "make it shorter", "more direct", "start with the churn number", "Dana won't
  care about slide 3". Before writing the new version, copy the current file to
  `cos/drafts/.history/<Name>/v<N>.md`; then replace "Draft", bump `version`, and add a line to
  "History" saying what changed.
- **Reading it back:** speak a short summary, not the whole thing, and attach the draft. Read it
  in full only if they ask.
- Keep "Notes" as the raw material: never delete a note because the draft no longer uses it.

## When it's ready
When the user says it's ready (or it plainly is, and they agree):
1. Set `status: ready`. Look in "My tools" in `my-rules.md` for a line whose `for` matches the kind.
2. Ask where it should go, in one sentence: "Want me to keep it here, or put it in Google Docs
   like your other documents?" With no line for that kind, ask which tool they use for it.
3. Do what they say:
   - **Keep it here:** leave it as `ready`; when they've used it, set `status: done`.
   - **Move it to a tool:** create it there with the tools connected to this session (a Gmail
     draft, a Google Doc, a Notion page, a Slides deck, a Slack message draft…), in that tool's
     own format. Never send it: an email becomes a draft in their mailbox, a message is posted
     only if they say so. Then set `status: moved`, `moved_to` and `link`, and add a History line.
     If the tool isn't connected or can't create it, say so, and attach the draft in a format
     they can paste or upload (Markdown, or a `.docx` or `.pptx` file if you can make one).
4. If this was a new answer about where a kind of work goes, add or update the line in
   "My tools" (with `for` and `src`), and say once that you'll remember it.

## After it moves
The copy in their tool is the real one; people may edit it there. You can read it (with the
tools connected to this session) to answer questions or to pick it up again, but don't change it
in that tool unless they ask and the tool allows it. To work on it again, read the latest from
the tool into a new version here, mark `status: draft`, and say it's a new version based on the
one in the tool.

## Learning how they write
Only with their OK (asked in onboarding, or the first time it matters): read a handful of their
own sent messages of that kind (sent email to colleagues, to clients, Slack, …) through the
connected tools, and write one line per kind and audience under "How I write" in `about-me.md`:
length, greeting and sign-off, tone, words they use or avoid. Say what you noticed in a sentence
and attach the full list; they correct it by voice. When they change a draft before sending it in
a way that shows a pattern, update that line and tell them once. Never copy their messages'
content into the notebook, only the style.
