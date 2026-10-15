---
name: brain
description: Opens the chief of staff's notebook page (brain.html), which shows everything it knows, or gives its link to bookmark. Use when the user runs /cos:brain, or asks to see, open or get the link to their notebook, dashboard or what their agent knows.
user-invocable: true
allowed-tools:
  - Bash(./open-brain.sh)
  - Bash(./open-brain.sh --link)
---

# /cos:brain — the notebook page

The notebook page is built from the notes in `cos/` and kept up to date as they change. It
opens on the computer this agent runs on.

- In a terminal session (the user is at the computer): run `./open-brain.sh`. It rebuilds the
  page and opens it in the browser. Tell the user to bookmark it; the address stays the same.
- Over Carbon Voice (the user may be on their phone): run `./open-brain.sh --link` and send the
  link as its own short message, saying it opens on their computer.

If `./open-brain.sh` is missing, the folder needs updating: type `/exit`, then run
`./update-cos.sh`.
