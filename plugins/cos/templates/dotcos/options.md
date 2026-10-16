# What your agent can do

Everything you can turn on, turn off or change, and what you can ask for any time. This list
comes with the Chief of Staff and grows with updates. Ask your agent "what can you do?" or run
/cos:settings to see which of these are on for you.

## Briefs
- Morning brief: focus, meetings, catch up, what's due and follow-ups, on weekdays at 7:00 [id:: brief] [default:: on] [say:: "move my morning brief to 6:45", "no brief on Mondays"]
- More briefs during the day or week, each with its own time and contents [id:: more-briefs] [default:: off] [say:: "add a midday check-in at 12:30 that covers what came in since the morning", "add a Friday wrap-up at 4:30"]
- Catch-up on email, chat and Carbon Voice in each brief: what needs your reply, what you may have missed, what changed [id:: catchup] [default:: on] [say:: "leave catch-up out of my midday check-in"]
- Meeting prep: offered in the brief, sent before meetings on its own, or off [id:: prep] [default:: offer] [say:: "send me prep before every meeting", "stop offering meeting prep"]
- Important people, who always make it into a brief [id:: important] [default:: the people you work with most] [say:: "always tell me about anything from Lena"]
- Things to leave out of briefs [id:: skip] [default:: newsletters, notifications and bulk mail] [say:: "leave out GitHub notifications"]
- How long briefs are [id:: length] [default:: under a minute] [say:: "keep briefs to three sentences"]
- Details attached to briefs as a document you can read in Carbon Voice [id:: attach] [default:: on] [say:: "stop attaching files to my briefs"]
- A check-in about your briefs after the first week, then monthly [id:: checkin] [default:: on] [say:: "stop asking about my briefs"]

## Drafts
- Drafts of emails, documents, decks and messages, shaped by talking: start one, add to it any time, turn notes into an outline, revise [id:: drafts] [default:: on] [say:: "start a draft email to Dana about pricing", "add this to the board narrative: …", "turn my notes into an outline"]
- Where finished work goes, for each kind: kept here, or moved to the tool you use [id:: tools] [default:: asked when a draft is ready] [say:: "my documents go in Google Docs", "keep decks here as outlines"]
- Your writing styles, by kind and audience: work email, client email, Slack, texts to friends… Learned from your sent messages only with your OK, and shown in your notebook to correct [id:: voice] [default:: asked in onboarding] [say:: "learn how I write from my sent email", "my Slack messages are more casual than that", "to clients I always start with Hi"]
- Drafts in progress mentioned in your briefs when they're due soon or haven't moved [id:: drafts-brief] [default:: on] [say:: "don't mention drafts in my briefs"]

## Reminders and tidying
- Nudges: short reminders of what's due or stuck, at most three a day [id:: nudges] [default:: 3 a day] [say:: "only one nudge a day", "no nudges"]
- Archiving items nobody has mentioned for 30 days [id:: archive] [default:: 30 days] [say:: "archive things after two weeks"]
- Suggested moves: turning ideas into projects, closing finished ones, changes to your briefs [id:: moves] [default:: on] [say:: "stop suggesting projects"]
- The nightly review at 2:15, which tidies your notes [id:: nightly] [default:: chosen at setup] [say:: change it in cos/setup.conf (NIGHTLY=1 or 0), then run ./update-cos.sh]

## Your notebook
- Your notebook page, with everything your agent knows, always on at an address you can bookmark [id:: page] [default:: on] [say:: "send me the link to my notebook", or run ./open-brain.sh]
- Check things off, add items and edit notes right on the notebook page; your agent sees every change [id:: page-edit] [default:: on] [say:: click a checkbox, the pencil next to an item, or "Edit the file"]
- Rules for where things go, like "team tasks live in Linear" [id:: where] [default:: none] [say:: "my team's tasks live in Jira; don't copy them"]
- Your own rules for how your agent works [id:: rules] [default:: none] [say:: "from now on, keep drafts under three sentences"]
- What your agent knows about you, which you can correct [id:: about] [default:: what you said in onboarding] [say:: "that's wrong: I don't run hiring any more"]

## Where you talk
- The tools your agent reads: email, calendar, Slack, Carbon Voice, task trackers, documents. Connect more in Claude's settings under Connectors [id:: sources] [default:: chosen in onboarding] [say:: "also read my Slack DMs", "stop reading my email"]
- To-do lists you keep in other tools, which your agent points to but never copies [id:: elsewhere] [default:: none] [say:: "my to-dos are also in Asana"]
- Reading your tools without asking each time, so briefs can run while you're away [id:: read-freely] [default:: chosen in onboarding] [say:: "you can read my calendar without asking"]

## Ask any time
- "Where do things stand?", "What am I waiting on from Priya?" [id:: ask-status]
- "Catch me up since Friday" [id:: ask-catchup]
- "Prep me for my 2pm" [id:: ask-prep]
- "Do 1 and 3" after a brief, to send those follow-ups [id:: ask-followups]
- "Where was that signup link?", "How many seats does Acme have?" [id:: ask-find]
- "Remind me about this when pricing is done" [id:: ask-idea]
- "That's a project", "Close the Acme project" [id:: ask-projects]
- "Read me the board narrative", "Where did the pricing email end up?" [id:: ask-drafts]
- "What can you do?" or "What are my settings?" [id:: ask-settings]
