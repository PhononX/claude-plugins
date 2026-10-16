#!/usr/bin/env bash
# Tests the notebook page: builds brain.html from the sample workspace and checks it in a browser.
#   bash plugins/cos/tests/test-brain.sh
# Needs jq. The browser part needs Playwright (npm install -g playwright) with Chromium; it's
# skipped, with a message, when Playwright isn't installed.
set -u
TESTS=$(cd "$(dirname "$0")" && pwd -P)
PLUGIN=$(dirname "$TESTS")
DOTCOS="$PLUGIN/templates/dotcos"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/cos-brain-test.XXXXXX")
SERVER_PID=""
trap '[ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; rm -rf "$TMP"' EXIT

FAILS=0
fail() { echo "  FAIL: $*"; FAILS=$((FAILS + 1)); }
ok() { echo "  ok: $*"; }

setup_ws() { # $1: directory to create
  mkdir -p "$1/.cos"
  cp -R "$TESTS/sample-workspace/cos" "$1/cos"
  cp "$DOTCOS/build-brain.sh" "$DOTCOS/brain-template.html" "$DOTCOS/defaults.md" "$DOTCOS/options.md" "$1/.cos/"
  chmod +x "$1/.cos/build-brain.sh"
}

echo "Builder"
bash -n "$DOTCOS/build-brain.sh" && ok "bash -n" || fail "bash -n build-brain.sh"

# The workspace path has a space and an ampersand, to catch quoting mistakes.
WS="$TMP/my work & notes"
setup_ws "$WS"
# A note whose name needs escaping in an HTML attribute.
printf -- '---\nrole: Lab\n---\n# R&D "lab" <x>\n\n- Odd file name [src:: cv 2026-10-14]\n' > "$WS/cos/people/R&D \"lab\" <x>.md"

OUT=$( (cd / && "$WS/.cos/build-brain.sh") 2>&1 ); RC=$?
[ $RC -eq 0 ] && ok "builder exits 0" || fail "builder exited $RC"
[ -z "$OUT" ] && ok "builder is silent" || fail "builder printed: $OUT"
B="$WS/brain.html"
if [ -f "$B" ]; then
  ok "brain.html written"
  MODE=$(ls -l "$B" | cut -c1-10)
  [ "$MODE" = "-rw-------" ] && ok "mode 600" || fail "brain.html mode is $MODE"
else
  fail "brain.html missing"
fi
ls "$WS"/.brain.html.* >/dev/null 2>&1 && fail "temp file left behind" || ok "no temp files left"

html_attr() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/"/\&quot;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
MISSING=0
while IFS= read -r -d '' f; do
  rel=${f#"$WS/"}
  case "$rel" in cos/log/transcripts/*|*/.*/*) continue ;; esac
  grep -qF "data-path=\"$(html_attr "$rel")\"" "$B" || { fail "not embedded: $rel"; MISSING=1; }
done < <(find "$WS/cos" -type f -name '*.md' -print0)
grep -qF 'data-path=".cos/defaults.md"' "$B" || { fail "defaults.md not embedded"; MISSING=1; }
grep -qF 'data-path=".cos/options.md"' "$B" || { fail "options.md not embedded"; MISSING=1; }
[ $MISSING -eq 0 ] && ok "every note embedded"
grep -q 'TRANSCRIPT-SHOULD-NOT-BE-EMBEDDED' "$B" && fail "a transcript was embedded" || ok "transcripts left out"
grep -q 'data-path="cos/drafts/.history' "$B" && fail "a draft's old version was embedded" || ok "drafts/.history left out"
grep -c '<script type="text/markdown"' "$B" | grep -q . || fail "no notes"
grep -q '<!--COS-NOTES-->' "$B" && fail "marker left in the page" || ok "marker replaced"
# Only the real closing tags may appear: every "</script" in the page must close a script element.
N_OPEN=$(grep -o '<script' "$B" | wc -l | tr -d ' ')
N_CLOSE=$(grep -oi '</script' "$B" | wc -l | tr -d ' ')
[ "$N_OPEN" = "$N_CLOSE" ] && ok "no stray </script in notes" || fail "$N_OPEN <script vs $N_CLOSE </script"
grep -qF '<\/script> and <\!-- not a comment -->' "$B" && ok "canary escaped in the file" || fail "canary not escaped as expected"
grep -q '"agent":"Ada"' "$B" && grep -q '"owner":"Alex"' "$B" && grep -q '"version":"0.2.0"' "$B" && ok "meta JSON" || fail "meta JSON wrong"

# Only the newest 45 daily logs go in.
WS2="$TMP/logs"
setup_ws "$WS2"
for m in 07 08; do for d in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
  printf '# 2026-%s-%s\n\n- 09:00 Old day\n' "$m" "$d" > "$WS2/cos/log/2026-$m-$d.md"
done; done
"$WS2/.cos/build-brain.sh"
NLOG=$(grep -c 'data-path="cos/log/[0-9-]*\.md"' "$WS2/brain.html")
[ "$NLOG" = 45 ] && ok "45 newest log days" || fail "embedded $NLOG log days, wanted 45"
grep -q 'data-path="cos/log/2026-10-15.md"' "$WS2/brain.html" && ! grep -q 'data-path="cos/log/2026-07-01.md"' "$WS2/brain.html" \
  && ok "kept the newest, dropped the oldest" || fail "wrong log days kept"
grep -q 'data-path="cos/log/consolidation.md"' "$WS2/brain.html" && ok "other log files kept" || fail "cos/log/consolidation.md missing"

# Not set up: no output, no page.
WS3="$TMP/fresh"
setup_ws "$WS3"; rm "$WS3/cos/.version"
OUT=$("$WS3/.cos/build-brain.sh" 2>&1); RC=$?
[ $RC -eq 0 ] && [ -z "$OUT" ] && [ ! -f "$WS3/brain.html" ] && ok "quiet no-op without cos/.version" || fail "ran without cos/.version"

# A brand-new notebook: only the files a fresh install has (placeholders filled in).
WS4="$TMP/new"
mkdir -p "$WS4/.cos" "$WS4/cos/log"
cp "$DOTCOS/build-brain.sh" "$DOTCOS/brain-template.html" "$DOTCOS/defaults.md" "$DOTCOS/options.md" "$WS4/.cos/"
if [ -d "$PLUGIN/templates/cos" ]; then
  for f in "$PLUGIN/templates/cos"/*.md; do
    sed -e 's/{{AGENT_NAME}}/Ada/g' -e 's/{{OWNER_NAME}}/Alex/g' "$f" > "$WS4/cos/$(basename "$f")"
  done
fi
printf '0.2.0\n' > "$WS4/cos/.version"
printf 'OWNER_NAME=Alex\nAGENT_NAME=Ada\n' > "$WS4/cos/setup.conf"
"$WS4/.cos/build-brain.sh" && [ -f "$WS4/brain.html" ] && ok "builds a brand-new notebook" || fail "brand-new notebook build"

# An older notebook: one brief in brief.md with "sent" in its front matter, and brief_time /
# brief_days in my-rules.md instead of a "My briefs" section.
WS5="$TMP/legacy"
setup_ws "$WS5"
cat > "$WS5/cos/brief.md" <<'EOF'
---
date: 2026-10-15
sent: "07:02"
---
# Brief for Thursday, October 15

## Focus
- Lock v3 pricing before Friday's [[Q4 Launch]] review

## Meetings
- 09:30 Pricing review with [[Dana Whitfield]] and [[Priya Natarajan]] [prep:: ready]
  > The three open questions on the Team tier.

## Follow-ups
1. Send the v3 pricing deck to [[Dana Whitfield]] [src:: cv 2026-10-13]
   > Dana, here's the v3 deck.
2. Answer [[Jordan Kim]]'s question on Q3 churn [src:: gmail 2026-10-12]
   > Jordan, Q3 logo churn was 2.1%.

## Due elsewhere
- PRD-398 Sign off on SSO release notes [due:: 2026-10-15] [src:: linear 2026-10-15]
EOF
cat > "$WS5/cos/my-rules.md" <<'EOF'
---
brief_time: "07:30"
brief_days: weekdays
nudges_per_day: 3
stale_days: 30
meeting_prep: offer
---
# My rules for Ada

## My rules
- Drafts should sound like me [src:: cv 2026-10-04]

## Where things go
EOF
"$WS5/.cos/build-brain.sh" || fail "legacy notebook build"

echo "Page"
PW=""
if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  PW="$(npm root -g 2>/dev/null)/playwright/index.mjs"
  [ -f "$PW" ] || PW=""
fi
if [ -z "$PW" ]; then
  echo "  skipped: Playwright isn't installed (npm install -g playwright), so the page wasn't opened."
else
  cat > "$TMP/check.mjs" <<'JS'
// Opens brain.html in Chromium and walks through it. Args: playwright module, page, brand-new page, screenshot dir, older-format page, options.md.
import { pathToFileURL } from "node:url";
import fs from "node:fs";
const [pwPath, pagePath, freshPath, shots, legacyPath, optionsPath] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(pwPath).href);
const CANARY = `</script> and <!-- not a comment --> with $HOME & "quotes" 'single' C:\\temp\\new 🚀 café`;
let fails = 0;
const fail = m => { console.log("  FAIL: " + m); fails++; };
const ok = m => console.log("  ok: " + m);
const url = (p, today = "2026-10-15", hash = "", now = "10:00") => pathToFileURL(p).href + "?today=" + today + (now ? "&now=" + now : "") + hash;

const browser = await chromium.launch();
async function open(p, opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: opts.width || 1280, height: 900 }, colorScheme: opts.dark ? "dark" : "light" });
  // Fonts come from Google when online; block them so the run is offline and deterministic.
  await ctx.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", e => errors.push("page error: " + e.message));
  page.on("console", m => { if (m.type() === "error" && !/fonts\.(googleapis|gstatic)|ERR_FAILED|net::/.test(m.text() + (m.location().url || ""))) errors.push("console: " + m.text()); });
  await page.goto(url(p, opts.today, opts.hash || "", opts.now === undefined ? "10:00" : opts.now));
  return { ctx, page, errors };
}
const mainText = page => page.locator("#main").innerText();
// Section labels are upper-cased by CSS, and innerText reports what's shown, so compare without case.
const has = (text, s) => text.toLowerCase().includes(s.toLowerCase());
const go = async (page, h) => { await page.evaluate(x => { location.hash = x; }, h); await page.waitForTimeout(60); };
const need = (text, list, where) => { for (const s of list) if (!has(text, s)) fail(`${where} is missing: ${s}`); };
async function noJunk(page, where) {
  const t = await mainText(page);
  const bad = ["undefined", "[object", "NaN", "null"].filter(w => t.includes(w));
  if (bad.length) fail(`${where}: page shows ${bad.join(", ")}`);
  const sw = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  if (sw > 0) fail(`${where}: page scrolls sideways by ${sw}px`);
}
async function walk(page, label) {
  const views = ["today", "loops", "notebook", "history", "how"];
  for (const v of views) {
    const link = v === "how" ? page.locator("#nav .howlink") : page.locator(`#nav a.nv[href="#${v}"]`);
    if (await link.isVisible()) await link.click(); else await go(page, v);
    const h1 = (await page.locator("#main h1").first().innerText()).trim();
    if (!h1) fail(`${label} ${v}: no heading`);
    const cur = await (v === "how" ? page.locator("#nav .howlink") : page.locator(`#nav a.nv[href="#${v}"]`)).getAttribute("aria-current");
    if (cur !== "page") fail(`${label} ${v}: not marked current`);
    await noJunk(page, `${label} ${v}`);
    const raw = page.locator("#main [data-raw]").first();
    if (await raw.count()) {
      await raw.click();
      if (!(await page.locator("#main pre.raw").count())) fail(`${label} ${v}: Show the file shows nothing`);
      await page.locator("#main [data-raw]").first().click();
      if (await page.locator("#main pre.raw").count()) fail(`${label} ${v}: Show the file didn't toggle off`);
    }
  }
  ok(`${label}: opened all ${views.length} views`);
}

// ---------- the sample notebook ----------
{
  const { ctx, page, errors } = await open(pagePath);
  if ((await page.title()) !== "Ada's notebook") fail("title is " + (await page.title()));
  if ((await page.locator("#byline").innerText()) !== "Chief of staff for Alex") fail("byline: " + (await page.locator("#byline").innerText()));
  if ((await page.locator("#q").getAttribute("placeholder")) !== "Tell Ada something, or search everything Ada knows…") fail("omnibox placeholder: " + (await page.locator("#q").getAttribute("placeholder")));
  if (!(await page.locator("#top-r .next").innerText()).includes("Next brief 12:30pm")) fail("next brief: " + (await page.locator("#top-r").innerText()));
  if ((await page.locator('#top-r a[href="#how"]').getAttribute("aria-label")) !== "How Ada works") fail("gear button label");
  const navs = await page.locator("#nav a.nv").allInnerTexts();
  if (navs.map(s => s.split("\n")[0].trim()).join() !== "Today,Open loops,Notebook,History") fail("nav: " + navs.join(" | "));
  if (!(await page.locator('#nav a.nv[href="#loops"] .n.hot').count())) fail("Open loops count isn't red with overdue loops");

  // Today
  let t = await mainText(page);
  need(t, ["Thursday, October 15", "Midday check-in sent 12:31pm", "Focus: Lock v3 pricing before Friday's Q4 Launch review", "Catch up 4", "To sort 3", "Due today or tomorrow 3", "Nudges 3",
    "Ada needs your answer", "The referral idea has come up three times. Make it a project?", "Project?", "Jordan Kim asked for the Q3 churn numbers", "3 days waiting", "raised in 2 briefs",
    "9:30am", "Prep ready", "Prep at 12:45pm", "Rest of the week", "Mon 19", "Catch up", "Raised 3 times · now a nudge", "Open loops", "1d late", "In play this week", "Dana Whitfield",
    "Ada today", "Morning brief: 3 meetings", "Full history"], "Today");
  if ((await page.locator("#ask .ask-row").count()) !== 5) fail("needs your answer rows: " + (await page.locator("#ask .ask-row").count()));
  if (await page.locator("#ask [data-answer]").count()) fail("answer buttons on the read-only copy");
  await page.locator('#ask [data-ui="askFilter"][data-v="replies"]').click();
  if ((await page.locator("#ask .ask-row").count()) !== 2) fail("Replies filter: " + (await page.locator("#ask .ask-row").count()));
  await page.locator('#ask [data-ui="askFilter"][data-v="all"]').click();
  if (!(await mainText(page)).includes(CANARY)) fail("canary text didn't render literally on Today"); else ok("canary renders literally");
  const bs = page.locator("#briefs details.brief");
  if ((await bs.count()) !== 2) fail("briefs: " + (await bs.count()));
  else {
    const sum0 = (await bs.nth(0).locator("summary").innerText()).replace(/\s+/g, " ").trim();
    if (!/^Midday check-in · sent 12:31pm latest · 2 follow-ups$/.test(sum0)) fail("latest brief first: " + sum0);
    if (await bs.nth(0).evaluate(d => d.open) || await bs.nth(1).evaluate(d => d.open)) fail("briefs should start collapsed");
    await bs.nth(0).locator("summary").click(); await bs.nth(1).locator("summary").click();
    t = await mainText(page);
    need(t, ["Follow-ups Ada can send", "Tell Priya Natarajan SSO can ship Thursday", "Send the v3 pricing deck to Dana Whitfield before the 9:30 review", "Due elsewhere", "You may have missed"], "briefs");
    if ((t.match(/The numbers mean this brief/g) || []).length !== 1) fail("the numbers hint should be on the latest brief only");
  }
  await page.locator('#loops-summary [data-ui="todayTab"][data-v="owed"]').click();
  if (!has(await page.locator("#loops-summary").innerText(), "Acme's Q1 seat forecast")) fail("Open loops summary: Owed to you tab");
  await page.click("#main [data-raw]");
  if (!(await page.locator("#main pre.raw").allInnerTexts()).join("\n").includes("Escaping canary: " + CANARY)) fail("canary wrong in Show the files"); else ok("canary literal in Show the files");
  await page.click("#main [data-raw]");
  ok("Today");

  // Open loops
  await go(page, "loops");
  t = await mainText(page);
  need(t, ["Open loops", "14 promises in flight", "You owe", "Owed to you", "Drafting", "Overdue", "Done this week", "Reply to Jordan Kim with Q3 churn numbers", "16 days waiting",
    "Acme's Q1 seat forecast", "Pricing philosophy essay", "Long-term", "Lists in other tools", "Linear", "Open Linear"], "Open loops");
  if ((await page.locator("#main .cols3 > .card").count()) !== 3) fail("Open loops: three columns");
  await page.locator('[data-ui="loopsGroup"][data-v="person"]').click();
  t = await mainText(page);
  if (!(await page.locator("#main table.gt").count()) || !has(t, "Dana Whitfield") || !has(t, "overdue")) fail("Open loops by person");
  await page.reload();
  if ((await page.locator('[data-ui="loopsGroup"][data-v="person"]').getAttribute("aria-pressed")) !== "true") fail("grouping isn't kept across reload");
  await page.locator('[data-ui="loopsGroup"][data-v="project"]').click();
  if (!has(await mainText(page), "Q4 Launch")) fail("Open loops by project");
  await page.locator('[data-ui="loopsFilter"][data-v="late"]').click();
  if ((await page.locator("#main table.gt tbody tr[data-il]").count()) !== 3) fail("Overdue filter rows: " + (await page.locator("#main table.gt tbody tr[data-il]").count()));
  await page.locator('[data-ui="loopsFilter"][data-v="all"]').click();
  await page.locator('[data-ui="loopsGroup"][data-v="status"]').click();
  ok("Open loops");
  // Drafts open from Drafting
  await page.click('#main a[href="#drafts/Q4%20launch%20deck"]');
  t = await mainText(page);
  if ((await page.locator("#main .slide").count()) !== 4) fail("deck should show 4 slides, got " + (await page.locator("#main .slide").count()));
  if ((await page.locator("#main .slide-notes").count()) !== 4 || !has(t, "Open with the pricing decision")) fail("speaker notes missing");
  if (has(t, "Speaker notes: Open")) fail("speaker notes prefix not stripped");
  if ((await page.locator('#nav a.nv[href="#loops"]').getAttribute("aria-current")) !== "page") fail("a draft belongs to Open loops");
  await go(page, "drafts/Acme%20uptime%20credit%20offer");
  if (!has(await mainText(page), "This moved to Google Docs on Thu, Oct 15. The copy there is the real one.")) fail("moved banner");
  if (!(await page.locator('#main .moved-banner a[href="https://docs.google.com/document/d/sample"]').count())) fail("moved banner link");
  ok("drafts");

  // Notebook
  await go(page, "notebook");
  t = await mainText(page);
  need(t, ["Notebook", "People", "Projects & areas", "Ideas", "Links & facts", "Decisions", "Dana Whitfield", "Q4 Launch", "Key customers", "Team tier drops to $18"], "Notebook");
  await page.click('#main a.pill[href="#notebook/people"]');
  need(await page.locator("#main .ix").innerText(), ["Mei Chen", "no note", "2 mentions", "Sam Okafor"], "Notebook · People");
  await page.click('#main .ixr[href="#people/Dana%20Whitfield"]');
  t = await page.locator("#main .dtcard").innerText();
  need(t, ["Dana Whitfield", "Head of Sales, Northwind", "You owe them", "They owe you", "Mentions", "Open loops", "Everything that mentions Dana", "cos/actions.md".replace("cos/actions.md", "Open loops · You owe"), "Weekly pricing sync, Thursdays", "Linked"], "Person detail");
  if ((await page.locator('#main .ixr[aria-current="true"]').getAttribute("href")) !== "#people/Dana%20Whitfield") fail("picked person isn't marked in the index");
  await page.locator("#main .dtcard [data-raw]").click();
  if (!(await page.locator("#main .dtcard pre.raw").innerText()).includes("rhythm: Weekly pricing sync")) fail("person Show the file");
  await page.locator("#main .dtcard [data-raw]").click();
  await go(page, "name/Mei%20Chen");
  t = await page.locator("#main .dtcard").innerText();
  need(t, ["Mei Chen", "no note yet", "No note yet. Ada starts one once Mei Chen comes up again", "2 mentions", "confirmed the new Stripe invoice format"], "Name with no note");
  if (await page.locator("#main [data-start-note]").count()) fail("Start a note shown on the read-only copy");
  if ((await page.locator('#main .ixr[aria-current="true"]').getAttribute("href")) !== "#name/Mei%20Chen") fail("Mei Chen isn't marked in the index");
  await page.click('#main a.pill[href="#notebook/projects"]');
  await page.click('#main .ixr[href="#projects/Q4%20Launch"]');
  t = await page.locator("#main .dtcard").innerText();
  need(t, ["Q4 Launch", "Active", "Open loops", "Decisions", "People", "Links & facts", "v3 pricing and the new onboarding", "Pricing email to Dana"], "Project detail");
  await go(page, "areas/Hiring");
  if (!has(await page.locator("#main .dtcard").innerText(), "Projects in this area") || !has(await page.locator("#main .dtcard").innerText(), "Senior PM hiring")) fail("area detail");
  await go(page, "notebook/links");
  await page.locator("#main .ixr", { hasText: "Customer beta signup form" }).click();
  t = await page.locator("#main .dtcard").innerText();
  if (!has(t, "forms.northwind.example/v3-beta") || !(await page.locator("#main .dtcard [data-copy]").count())) fail("link detail");
  const none = page.locator("#main .dtcard a.wl-none", { hasText: "Mei Chen" });
  await go(page, "notebook/links");
  await page.locator("#main .ixr", { hasText: "Billing and Stripe questions" }).click();
  if (!(await none.count()) || (await none.first().getAttribute("title")) !== "No note yet: 2 mentions") fail("unlinked name isn't marked");
  await page.fill("#ix-q", "acme");
  if ((await page.locator("#main .ixr").count()) < 1 || has(await page.locator("#main .ix").innerText(), "Board portal")) fail("index filter");
  await page.fill("#ix-q", "");
  // old addresses land in the Notebook
  await go(page, "people");
  if ((await page.locator('#main a.pill[href="#notebook/people"]').getAttribute("aria-pressed")) !== "true") fail("#people doesn't open Notebook · People");
  await go(page, "ideas");
  if ((await page.locator('#main a.pill[href="#notebook/ideas"]').getAttribute("aria-pressed")) !== "true") fail("#ideas doesn't open Notebook · Ideas");
  ok("Notebook");

  // History
  await go(page, "history");
  t = await mainText(page);
  need(t, ["History", "Wednesday, Oct 14", "Captured", "Decision", "Brief", "Archived", "Mei Chen confirmed the new Stripe invoice format is cosmetic", "Activity", "6 weeks ago", "This week", "Daily notes", "cos/log/"], "History");
  if ((await page.locator("#main .heat i").count()) !== 42) fail("activity cells: " + (await page.locator("#main .heat i").count()));
  if (!(await page.locator("#main .heat i.l1, #main .heat i.l2, #main .heat i.l3").count())) fail("activity shows nothing");
  await page.locator('#main [data-ui="histFilter"][data-v="archived"]').first().click();
  t = await mainText(page);
  if (!has(t, "Look into the conference sponsorship for March") || has(t, "Mei Chen confirmed")) fail("Archived filter");
  await page.locator('#main [data-ui="histFilter"][data-v="all"]').click();
  await page.fill("#hist-q", "stripe");
  t = await page.locator("#main .hist").innerText();
  if (!has(t, "Mei Chen confirmed") || has(t, "Linear: PRD-398")) fail("history search");
  if ((await page.evaluate(() => document.activeElement && document.activeElement.id)) !== "hist-q") fail("history search box loses focus while typing");
  await page.fill("#hist-q", "");
  await go(page, "archive");
  if ((await page.locator('#main [data-ui="histFilter"][data-v="archived"]').first().getAttribute("aria-pressed")) !== "true") fail("#archive doesn't open History · Archived");
  await page.locator('#main [data-ui="histFilter"][data-v="all"]').click();
  ok("History");

  // How Ada works
  await page.click('#top-r a[href="#how"]');
  t = await mainText(page);
  need(t, ["How Ada works", "Where Ada listens", "Carbon Voice", "not connected", "Briefs", "Midday check-in", "Fridays 4:30pm", "Weekdays 6:45am", "Always include these people", "Jordan Kim",
    "Rules", "At most 2 a day", "Nudge me at most twice a day", "Where things go", "Moved from my-instructions.md", "Tools & voice", "Google Slides", "How you write", "Executives",
    "What Ada knows about you", "VP of Product", "Learned", "Family and time off", "Defaults & everything Ada can do", "Morning brief · changed", "Ask before sending · always", "1 thing to finish setting up"], "How Ada works");
  if (!(await page.locator("#top-r .backbtn").count())) fail("How Ada works: no Back to Today");
  if ((await page.locator("#main table.t tbody tr").count()) !== 5) fail("How you write rows: " + (await page.locator("#main table.t tbody tr").count()));
  await page.click("#main details.more summary");
  t = await mainText(page);
  need(t, ["You changed this", "Now: 3 briefs", "Always on", "Everything Ada can do", "what can you do?", "/cos:settings", "Default: on"], "Show all defaults");
  if ((await page.locator("#main .overridden").count()) !== 3) fail("expected 3 struck-through defaults, got " + (await page.locator("#main .overridden").count()));
  if (!/Say: "move my morning brief to 6:45"/.test(t)) fail("Say: hint missing");
  const groups = [...fs.readFileSync(optionsPath, "utf8").matchAll(/^## (.+)$/gm)].map(m => m[1].trim());
  for (const g of groups) if (!(await page.locator("#main section.block > h4", { hasText: new RegExp("^" + g.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$", "i") }).count())) fail("options group missing: " + g);
  for (const [old, sec] of [["how/briefs", "how-briefs"], ["how/knows", "how-about"], ["about", null], ["sources", "how-listening"], ["how/can", "how-defaults"]]) {
    await go(page, old);
    if ((await page.locator("#nav .howlink").getAttribute("aria-current")) !== "page") fail(`#${old} doesn't open How Ada works`);
    if (sec && !(await page.locator("#" + sec).count())) fail(`#${old}: no section ${sec}`);
  }
  ok("How Ada works (" + groups.length + " option groups)");

  // Search from the omnibox
  await page.fill("#q", "v3-beta");
  t = await mainText(page);
  if (!has(t, "forms.northwind.example/v3-beta") || !(await page.locator("#main mark").count())) fail("search for a URL fragment");
  await page.locator("#main .grouplink", { hasText: "Notebook" }).click();
  if ((await page.inputValue("#q")) !== "" || !(await page.locator("#main h1").innerText()).includes("Notebook")) fail("search group header didn't open its view");
  await page.fill("#q", "Skip newsletters");
  if (!(await page.locator("#main .grouplink", { hasText: "How Ada works" }).count())) fail("search groups my-rules lines under How Ada works");
  await page.fill("#q", "stopped losing small teams");
  if (!(await page.locator("#main .grouplink", { hasText: "Open loops" }).count())) fail("search doesn't find draft text");
  await page.fill("#q", "canary");
  if (!(await mainText(page)).includes(CANARY)) fail("canary wrong in search results");
  await page.keyboard.press("Escape");
  if ((await page.inputValue("#q")) !== "") fail("Esc doesn't clear the search");
  await page.keyboard.press(process.platform === "darwin" ? "Meta+k" : "Control+k");
  if ((await page.evaluate(() => document.activeElement && document.activeElement.id)) !== "q") fail("Ctrl+K doesn't focus the omnibox");
  ok("search");
  if (!(await page.locator(".notice.ro").count()) || !has(await page.locator(".notice.ro").innerText(), "Read-only copy")) fail("read-only notice missing");
  await walk(page, "sample");
  errors.forEach(e => fail(e)); if (!errors.length) ok("no page or console errors");
  await ctx.close();
}
// No brief yet today: the next one comes from "My briefs".
for (const [path, today, now, want] of [
  [pagePath, "2026-10-16", "10:00", "No brief yet today. Next: Midday check-in at 12:30pm."],
  [pagePath, "2026-10-16", "14:00", "No brief yet today. Next: Friday wrap-up at 4:30pm."],
  [pagePath, "2026-10-16", "06:00", "No brief yet today. Next: Morning brief at 6:45am."],
  [pagePath, "2026-10-17", "10:00", "No brief yet today. Next: Morning brief on Monday at 6:45am."],
  [pagePath, "2026-10-14", "20:00", "No brief yet today. Next: Morning brief tomorrow at 6:45am."],
  [legacyPath, "2026-10-16", "10:00", "No brief yet today. Next: Morning brief on Monday at 7:30am."],
  [legacyPath, "2026-10-19", "07:00", "No brief yet today. Next: Morning brief at 7:30am."]
]) {
  const { ctx, page, errors } = await open(path, { today, now });
  const t = await mainText(page);
  if (!has(t, want)) fail(`next brief for ${today} ${now}: wanted "${want}", page says "${(t.match(/No brief yet today\.[^\n·]*/) || ["nothing"])[0]}"`);
  errors.forEach(e => fail(e));
  await ctx.close();
}
{
  const { ctx, page } = await open(pagePath, { today: "2026-10-17", now: "10:00" });
  if (!(await page.locator("#top-r .next").innerText()).includes("Next brief Mon 6:45am")) fail("header next brief on Saturday: " + (await page.locator("#top-r .next").innerText()));
  await ctx.close();
}
ok("next brief");
// The older one-brief brief.md, and brief_time in my-rules.md.
{
  const { ctx, page, errors } = await open(legacyPath);
  let t = await mainText(page);
  need(t, ["Morning brief sent 7:02am", "9:30am", "Prep ready"], "legacy Today");
  const s = page.locator("#briefs details.brief");
  if ((await s.count()) !== 1 || !/^Morning brief · sent 7:02am/.test((await s.locator("summary").innerText()).replace(/\s+/g, " ").trim())) fail("legacy brief summary");
  else { await s.locator("summary").click(); need(await mainText(page), ["Follow-ups Ada can send", "The numbers mean this brief", "Jordan, Q3 logo churn was 2.1%."], "legacy brief"); }
  await go(page, "how");
  t = await mainText(page);
  need(t, ["Morning brief", "Weekdays 7:30am", "From your settings", "Morning brief · changed"], "legacy How Ada works");
  await walk(page, "legacy");
  errors.forEach(e => fail(e));
  ok("older brief.md and my-rules.md");
  await ctx.close();
}
// Phone width.
{
  const { ctx, page, errors } = await open(pagePath, { width: 400 });
  await walk(page, "400px");
  if (!(await page.locator("#nav a.nv").first().isVisible())) fail("phone: nav tabs hidden");
  await go(page, "people/Dana%20Whitfield");
  await noJunk(page, "400px person");
  await go(page, "drafts/Q4%20launch%20deck");
  await noJunk(page, "400px deck");
  errors.forEach(e => fail(e));
  await ctx.close();
}
// A brand-new notebook.
{
  const { ctx, page, errors } = await open(freshPath);
  await walk(page, "new notebook");
  await go(page, "today");
  need(await mainText(page), ["What’s taking most of your head this week?", "Catch up: all clear", "Nothing to sort", "No nudges today", "Nothing you owe right now."], "new Today");
  await go(page, "loops");
  need(await mainText(page), ["Nothing you owe.", "Nothing outstanding.", "No drafts."], "new Open loops");
  await go(page, "notebook");
  need(await mainText(page), ["Nothing here yet. Tell Ada about people"], "new Notebook");
  await go(page, "history");
  need(await mainText(page), ["Nothing yet. Each day Ada captures something"], "new History");
  await go(page, "how");
  need(await mainText(page), ["No rules of your own yet", "When a draft is ready, Ada asks where it should go", "Ada asks before learning how you write from your sent messages", "Morning brief · on"], "new How Ada works");
  errors.forEach(e => fail(e));
  await ctx.close();
}
// Screenshots, when asked for.
if (shots) {
  const shotsOf = async (p, prefix, width, dark, list) => {
    const { ctx, page } = await open(p, { width, dark });
    for (const [name, hash] of list) {
      await go(page, hash); await page.waitForTimeout(200);
      await page.screenshot({ path: `${shots}/${prefix}${name}-${width}${dark ? "-dark" : ""}.png`, fullPage: true });
    }
    await ctx.close();
  };
  const views = [["today", "today"], ["loops", "loops"], ["notebook", "people/Dana%20Whitfield"], ["history", "history"], ["how", "how"]];
  for (const dark of [false, true]) {
    await shotsOf(pagePath, "", 1280, dark, views.concat([["draft-deck", "drafts/Q4%20launch%20deck"], ["notebook-project", "projects/Q4%20Launch"]]));
    await shotsOf(freshPath, "new-", 1280, dark, views);
  }
  await shotsOf(pagePath, "", 400, false, views);
  await shotsOf(pagePath, "", 400, true, [["today", "today"]]);
  ok("screenshots in " + shots);
}
await browser.close();
process.exit(fails ? 1 : 0);
JS
  node "$TMP/check.mjs" "$PW" "$B" "$WS4/brain.html" "${BRAIN_SHOTS:-}" "$WS5/brain.html" "$DOTCOS/options.md" || FAILS=$((FAILS + 1))
fi

# The live notebook: the page served by notebook-server.mjs, where it can be edited.
echo "Live notebook"
if [ -z "$PW" ]; then
  echo "  skipped: needs Playwright."
elif [ ! -f "$DOTCOS/notebook-server.mjs" ]; then
  echo "  skipped: no notebook-server.mjs."
else
  WS6="$TMP/live ws"
  setup_ws "$WS6"
  cp "$DOTCOS/notebook-server.mjs" "$WS6/.cos/"
  PORT=$((41000 + RANDOM % 2000))
  KEY=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
  printf 'NOTEBOOK_PORT=%s\n' "$PORT" >> "$WS6/cos/setup.conf"
  mkdir -p "$WS6/.cv"; printf '%s\n' "$KEY" > "$WS6/.cv/notebook.key"
  node "$WS6/.cos/notebook-server.mjs" > "$TMP/server.log" 2>&1 &
  SERVER_PID=$!
  UP=0
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if node -e 'fetch(process.argv[1]).then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))' "http://127.0.0.1:$PORT/health"; then UP=1; break; fi
    node -e 'setTimeout(() => {}, 250)'
  done
  if [ $UP = 1 ]; then
    ok "notebook server started on port $PORT"
    "$WS6/.cos/build-brain.sh"
    grep -q "\"live\":\"http://localhost:$PORT/?k=$KEY\"" "$WS6/brain.html" && ok "brain.html links to the live notebook" || fail "meta.live missing from brain.html"
    cat > "$TMP/live.mjs" <<'JS'
// Drives the live notebook page. Args: playwright module, page URL, workspace, file copy of brain.html, screenshot dir.
import { pathToFileURL } from "node:url";
import fs from "node:fs";
import path from "node:path";
const [pwPath, liveUrl, ws, fileCopy, shots] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(pwPath).href);
let fails = 0;
const fail = m => { console.log("  FAIL: " + m); fails++; };
const ok = m => console.log("  ok: " + m);
const read = p => fs.readFileSync(path.join(ws, p), "utf8");
const write = (p, s) => fs.writeFileSync(path.join(ws, p), s);
const until = async (what, fn, ms = 6000) => { const t0 = Date.now(); while (Date.now() - t0 < ms) { try { if (await fn()) return true; } catch {} await new Promise(r => setTimeout(r, 100)); } fail("timed out: " + what); return false; };
const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
await ctx.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
const page = await ctx.newPage();
const errors = [];
page.on("pageerror", e => errors.push("page error: " + e.message));
page.on("console", m => { if (m.type() === "error" && !/fonts\.(googleapis|gstatic)|ERR_FAILED|net::|409|400|Conflict|Bad Request/.test(m.text() + (m.location().url || ""))) errors.push("console: " + m.text()); });
const toastSays = async (text, bad) => until(`toast "${text}"`, async () => {
  const t = page.locator("#toast");
  return (await t.isVisible()) && (await t.innerText()).includes(text) && (bad === undefined || (await t.getAttribute("class")) === (bad ? "bad" : ""));
});
const go = async h => { await page.evaluate(x => { location.hash = x; }, h); await page.waitForTimeout(100); };
const line = (p, s) => read(p).split("\n").find(l => l.includes(s));
const D = "2026-10-15";

await page.goto(liveUrl + "&today=" + D + "&now=10:00#loops");
await page.waitForLoadState("networkidle");
if (!(await page.locator("#cos-server").count())) fail("no #cos-server on the served page");
if (await page.locator(".notice.ro").count()) fail("read-only notice shown on the live page");
if (!(await page.locator("#foot").innerText()).includes("live")) fail("footer doesn't say live");

// 1. Check off a loop.
const marcus = page.locator("#main [data-il]", { hasText: "Book a design review" });
await marcus.locator("input.cb").check();
await toastSays("Checked off");
let l = line("cos/actions.md", "Book a design review");
if (!/^- \[x\] /.test(l) || !/\[done:: \d{4}-\d{2}-\d{2}\]/.test(l)) fail("check off didn't save: " + l); else ok("check off saves [x] and done");

// 2. Edit a line's text: the box and fields stay.
const narrative = page.locator("#main [data-il]", { hasText: "Write the board narrative" });
await narrative.hover();
await narrative.locator(".pen").click();
const input = page.locator("#main input.inline-edit");
if ((await input.inputValue()) !== "Write the board narrative for the Nov 6 meeting, for the [[Board deck]]") fail("inline edit value: " + (await input.inputValue()));
await input.fill("Write the board narrative for the Nov 6 board meeting, for the [[Board deck]]");
await input.press("Enter");
await toastSays("Saved");
l = line("cos/actions.md", "board narrative");
if (l !== "- [ ] Write the board narrative for the Nov 6 board meeting, for the [[Board deck]] [due:: 2026-10-30] [src:: onboarding 2026-10-01]") fail("edited line: " + l);
else ok("inline edit keeps the box and fields");
await page.locator("#main [data-il]", { hasText: "Reply to" }).locator(".lt").dblclick();
if (!(await page.locator("#main input.inline-edit").count())) fail("double-click didn't start an edit");
await page.keyboard.press("Escape");
if (await page.locator("#main input.inline-edit").count()) fail("Esc didn't cancel");

// 3. The Open loops box: something you owe, and something owed to you.
await page.fill("#loop-add", "Order new name badges");
await page.keyboard.press("Enter");
await toastSays("Added to You owe");
if (!/- \[ \] Order new name badges \[src:: page [\d-]+\]\n(?:[^\n]*\n)*?## Elsewhere/.test(read("cos/actions.md"))) fail("loop add didn't land in To do");
await page.fill("#loop-add", "Priya Natarajan owes me the revised SSO date");
await page.keyboard.press("Enter");
await toastSays("Added to Owed to you");
if (!/^- \[ \] \[\[Priya Natarajan\]\]: the revised SSO date \[src:: page [\d-]+\]$/m.test(read("cos/waiting.md"))) fail("owed add: " + read("cos/waiting.md").slice(-160));
else ok("Open loops box: You owe and Owed to you");

// 4. The omnibox: Enter adds to the inbox.
await page.fill("#q", "Call the bank about the wire, ask [[Mei Chen]]");
if (!(await page.locator("#main").innerText()).includes("Press Enter to add")) fail("omnibox doesn't offer to add");
await page.keyboard.press("Enter");
await toastSays("Added to Ada’s inbox");
if (!/^- Call the bank about the wire, ask \[\[Mei Chen\]\] \[src:: page \d{4}-\d{2}-\d{2}\]$/m.test(read("cos/inbox.md"))) fail("omnibox add: " + read("cos/inbox.md").slice(-200));
else ok("omnibox adds to the inbox");
if ((await page.inputValue("#q")) !== "") fail("omnibox not cleared after adding");

// 5. Answers on Today.
await go("today");
const move = page.locator("#ask .ask-row", { hasText: "Make it a project?" });
await move.locator('[data-answer="yes"]').click();
await toastSays("Answered: yes");
l = line("cos/now.md", "The referral idea");
if (l !== "- The referral idea has come up three times. Make it a project? [src:: cv 2026-10-14] [answer:: yes " + D + "]") fail("answer yes: " + l);
await until("row shows answered", async () => (await page.locator("#ask .ask-row", { hasText: "Make it a project?" }).innerText()).includes("Answered: yes"));
const reply = page.locator("#ask .ask-row", { hasText: "asked whether SSO can ship Thursday" });
await reply.locator('[data-answer="snooze"]').click();
await toastSays("Answered: not now");
if (!/asked whether SSO can ship Thursday .*\[answer:: snooze 2026-10-15\]$/.test(line("cos/catch-up.md", "asked whether SSO can ship"))) fail("answer snooze: " + line("cos/catch-up.md", "asked whether SSO can ship"));
await page.locator("#ask .ask-row", { hasText: "Jordan Kim asked for the Q3 churn numbers" }).locator('[data-answer="draft"]').click();
await toastSays("Answered: draft a reply");
if (!/\[answer:: draft 2026-10-15\]$/.test(line("cos/catch-up.md", "Q3 churn numbers"))) fail("answer draft");
// A line with no source gets one saying it came from the page.
write("cos/now.md", read("cos/now.md").replace("## Suggested moves\n", "## Suggested moves\n- Close the Partner API pilot project for good?\n"));
await until("new suggestion shows", async () => (await page.locator("#ask").innerText()).includes("Close the Partner API pilot"));
await page.locator("#ask .ask-row", { hasText: "Close the Partner API pilot" }).locator('[data-answer="no"]').click();
await toastSays("Answered: not now");
if (line("cos/now.md", "Partner API pilot") !== "- Close the Partner API pilot project for good? [answer:: no " + D + "] [src:: page " + D + "]") fail("answer no: " + line("cos/now.md", "Partner API pilot"));
ok("answers: yes, no, draft, snooze");
// Focus: the question shows when now.md has no focus, and the answer becomes a focus line.
write("cos/now.md", read("cos/now.md").replace(/## Focus\n(?:- [^\n]*\n)+/, "## Focus\n"));
await until("focus question shows", async () => (await page.locator("#ask").innerText()).includes("What’s taking most of your head this week?"));
await page.fill("#focus-answer", "Ship v3 pricing");
await page.keyboard.press("Enter");
await toastSays("Focus set");
if (!/## Focus\n- Ship v3 pricing \[src:: page [\d-]+\]\n/.test(read("cos/now.md"))) fail("focus answer: " + read("cos/now.md").slice(0, 200));
else ok("focus answer");

// 6. Edit the whole file (a person, from the Notebook).
await go("people/Dana%20Whitfield");
const editBtn = page.locator("#main .dtcard [data-edit]");
if ((await editBtn.getAttribute("aria-label")) !== "Edit the note" || !(await editBtn.getAttribute("title"))) fail("edit button label: " + (await editBtn.getAttribute("aria-label")));
await editBtn.click();
const ta = page.locator("#ed-text");
await until("editor loads", async () => (await ta.inputValue()).includes("rhythm:"));
await ta.fill((await ta.inputValue()).replace("Weekly pricing sync, Thursdays", "Weekly pricing sync, Fridays"));
await page.click("#ed-save");
await toastSays("Saved");
if (!read("cos/people/Dana Whitfield.md").includes("rhythm: Weekly pricing sync, Fridays")) fail("file edit not saved"); else ok("Edit the file saves");
await until("page shows the edit", async () => (await page.locator("#main").innerText()).includes("Weekly pricing sync, Fridays"));

// 7. The file changed while editing: see the choices, keep mine (Today's files, picking inbox.md).
await go("today");
await page.click("#main .ph [data-edit]");
await until("editor picker", async () => (await page.locator("#ed-pick").count()) > 0);
await page.selectOption("#ed-pick", "cos/inbox.md");
await until("editor loads inbox", async () => (await ta.inputValue()).includes("# Inbox"));
write("cos/inbox.md", read("cos/inbox.md") + "- Changed on disk meanwhile [src:: cv 2026-10-15]\n");
await ta.fill((await ta.inputValue()) + "- Mine from the editor\n");
await page.click("#ed-save");
await until("conflict shown", async () => (await page.locator("#ed-conflict").isVisible()) && (await page.locator("#ed-conflict").innerText()).includes("This note changed while you were editing it"));
await page.click('[data-conflict="keep"]');
await page.click('[data-conflict="replace"]');
await toastSays("Saved");
if (!read("cos/inbox.md").includes("- Mine from the editor") || read("cos/inbox.md").includes("Changed on disk meanwhile")) fail("keep mine didn't overwrite"); else ok("editor conflict: keep mine");

// 8. A change on disk shows up by itself.
await go("loops");
write("cos/actions.md", read("cos/actions.md").replace("## To do\n", "## To do\n- [ ] Renew the team's Figma seats [src:: cv 2026-10-15]\n"));
await until("page refreshes with the outside change", async () => (await page.locator("#main").innerText()).includes("Renew the team's Figma seats"), 6000) && ok("live refresh after an outside change");

// 9. A stale check-off: error, then the page catches up.
await page.evaluate(() => { window.cosPausePolling = true; });
write("cos/actions.md", read("cos/actions.md").replace("- [ ] Draft the uptime credit offer", "- [ ] Write the uptime credit offer"));
await page.locator("#main [data-il]", { hasText: "Draft the uptime credit offer" }).locator("input.cb").check();
await toastSays("changed since the page loaded", true);
await until("page refreshes after the stale edit", async () => (await page.locator("#main").innerText()).includes("Write the uptime credit offer"));
if (read("cos/actions.md").includes("[x] Write the uptime credit offer")) fail("stale toggle was applied");
if (await page.locator("#main [data-il]", { hasText: "Write the uptime credit offer" }).locator("input.cb").isChecked()) fail("stale checkbox stayed checked");
ok("stale toggle: error toast and refresh");
await page.evaluate(() => { window.cosPausePolling = false; });

// 10. Start a note for a name that has none.
await go("name/Mei%20Chen");
await page.click("#main [data-start-note]");
await toastSays("Note started");
if (read("cos/people/Mei Chen.md") !== "---\nrole:\norg:\n---\n# Mei Chen\n") fail("new note: " + JSON.stringify(read("cos/people/Mei Chen.md")));
await until("opens the new note", async () => page.url().endsWith("#people/Mei%20Chen") && !(await page.locator("#main .dtcard").innerText()).includes("no note yet"));
const again = await page.evaluate(async () => {
  const key = JSON.parse(document.getElementById("cos-server").textContent).key;
  const r = await fetch("/api/create", { method: "POST", headers: { "X-Notebook-Key": key, "Content-Type": "application/json" }, body: JSON.stringify({ path: "cos/people/Mei Chen.md", content: "x" }) });
  return r.status;
});
if (again !== 409) fail("create over an existing note: " + again);
ok("Start a note");

// 11. Quiet icon buttons are labelled.
for (const h of ["today", "loops", "people/Dana%20Whitfield", "history", "how"]) {
  await go(h);
  for (const b of await page.locator("#main .ibtn").all()) {
    if (!(await b.getAttribute("aria-label")) || !(await b.getAttribute("title"))) fail(`${h}: icon button without a label`);
  }
}
ok("icon buttons have labels");

// 12. Theme switch.
await go("today");
await page.click('#nav [data-theme-set="dark"]');
if ((await page.evaluate(() => document.documentElement.getAttribute("data-theme"))) !== "dark") fail("dark theme not set");
await page.reload(); await page.waitForLoadState("networkidle");
if ((await page.evaluate(() => document.documentElement.getAttribute("data-theme"))) !== "dark") fail("theme not kept across reload");
if ((await page.locator('#nav [data-theme-set="dark"]').getAttribute("aria-pressed")) !== "true") fail("dark not shown as chosen");
await page.click('#nav [data-theme-set="auto"]');
if (await page.evaluate(() => document.documentElement.hasAttribute("data-theme"))) fail("auto didn't clear the theme");
ok("theme switch");

if (shots) {
  for (const dark of [false, true]) {
    await page.evaluate(d => { if (d) document.documentElement.setAttribute("data-theme", "dark"); else document.documentElement.removeAttribute("data-theme"); }, dark);
    await go("loops");
    await page.locator("#main [data-il]", { hasText: "Reply to" }).hover();
    await page.screenshot({ path: `${shots}/live-loops${dark ? "-dark" : ""}.png`, fullPage: true });
    await go("today");
    await page.screenshot({ path: `${shots}/live-today${dark ? "-dark" : ""}.png`, fullPage: true });
    await go("loops");
    await page.click("#main .ph [data-edit]");
    await until("editor loads", async () => (await ta.inputValue()).length > 0);
    await page.screenshot({ path: `${shots}/live-editor${dark ? "-dark" : ""}.png` });
    await page.click("#ed-cancel");
  }
  ok("live screenshots");
}
errors.forEach(e => fail(e));
await ctx.close();

// The file copy says it's read-only and links to the live notebook.
{
  const c2 = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  await c2.route(/fonts\./, r => r.abort());
  const p2 = await c2.newPage();
  await p2.goto(pathToFileURL(fileCopy).href + "?today=" + D + "#loops");
  const n = p2.locator(".notice.ro");
  if (!(await n.count()) || !/^Read-only copy, updated .*\. To check things off and edit, open your live notebook\.$/.test((await n.innerText()).trim())) fail("read-only notice: " + (await n.innerText().catch(() => "")));
  if ((await n.locator("a").getAttribute("href")) !== liveUrl) fail("read-only notice link: " + (await n.locator("a").getAttribute("href")));
  if (await p2.locator("input.cb, .pen, .addrow, #loop-add, [data-edit], [data-answer]").count()) fail("file copy shows edit controls");
  if (shots) await p2.screenshot({ path: `${shots}/readonly-notice.png`, clip: { x: 0, y: 0, width: 1280, height: 320 } });
  ok("read-only file copy");
  await c2.close();
}
await browser.close();
process.exit(fails ? 1 : 0);
JS
    node "$TMP/live.mjs" "$PW" "http://localhost:$PORT/?k=$KEY" "$WS6" "$WS6/brain.html" "${BRAIN_SHOTS:-}" || FAILS=$((FAILS + 1))
  else
    fail "notebook server didn't start: $(cat "$TMP/server.log")"
  fi
  kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; SERVER_PID=""
fi

echo
if [ $FAILS -eq 0 ]; then echo "PASS"; exit 0; else echo "FAIL ($FAILS)"; exit 1; fi
