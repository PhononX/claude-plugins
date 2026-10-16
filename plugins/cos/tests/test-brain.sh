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
// Opens brain.html in Chromium and walks through it. Args: playwright module, page, brand-new page, screenshot dir.
import { pathToFileURL } from "node:url";
const [pwPath, pagePath, freshPath, shots, legacyPath, optionsPath] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(pwPath).href);
const CANARY = `</script> and <!-- not a comment --> with $HOME & "quotes" 'single' C:\\temp\\new 🚀 café`;
let fails = 0;
const fail = m => { console.log("  FAIL: " + m); fails++; };
const ok = m => console.log("  ok: " + m);
const url = (p, today = "2026-10-15", hash = "", now = "") => pathToFileURL(p).href + "?today=" + today + (now ? "&now=" + now : "") + hash;

const browser = await chromium.launch();
async function open(p, opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: opts.width || 1280, height: 900 }, colorScheme: opts.dark ? "dark" : "light" });
  // Fonts come from Google when online; block them so the run is offline and deterministic.
  await ctx.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", e => errors.push("page error: " + e.message));
  page.on("console", m => { if (m.type() === "error" && !/fonts\.(googleapis|gstatic)|ERR_FAILED|net::/.test(m.text() + (m.location().url || ""))) errors.push("console: " + m.text()); });
  await page.goto(url(p, opts.today, opts.hash || "", opts.now));
  return { ctx, page, errors };
}
const mainText = page => page.locator("#main").innerText();
// Headings are upper-cased by CSS, and innerText reports what's shown, so compare without case.
const has = (text, s) => text.toLowerCase().includes(s.toLowerCase());
async function noJunk(page, where) {
  const t = await mainText(page);
  const bad = ["undefined", "[object", "NaN", "null"].filter(w => t.includes(w));
  if (bad.length) fail(`${where}: page shows ${bad.join(", ")}`);
  const sw = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  if (sw > 0) fail(`${where}: page scrolls sideways by ${sw}px`);
}
async function clickAllSections(page, label) {
  let n = 0;
  for (let i = 0; i < (await page.locator("#nav button").count()); i++, n++) {
    const b = page.locator("#nav button").nth(i);
    if (!(await b.isVisible())) { n--; continue; } // nested sub-pages are tabs in the page on phones
    const name = (await b.locator("span").first().innerText()).trim();
    const view = await b.getAttribute("data-view");
    await b.click();
    const h2 = (await page.locator("#main h2").first().innerText()).trim();
    if (!h2) fail(`${label} ${name}: no heading`);
    const cur = await page.locator(`#nav [data-view="${view}"]`).getAttribute("aria-current");
    if (cur !== "page" && cur !== "true") fail(`${label} ${name}: not marked current`);
    await noJunk(page, `${label} ${name}`);
    const raw = page.locator("#main [data-raw]").first();
    if (await raw.count()) {
      await raw.click();
      if (!(await page.locator("#main pre.raw").count())) fail(`${label} ${name}: Show the file shows nothing`);
      await page.locator("#main [data-raw]").first().click();
      if (await page.locator("#main pre.raw").count()) fail(`${label} ${name}: Show the file didn't toggle off`);
    }
  }
  ok(`${label}: opened all ${n} sections`);
}

// The sample notebook.
{
  const { ctx, page, errors } = await open(pagePath);
  if ((await page.title()) !== "Ada's notebook") fail("title is " + (await page.title()));
  const byline = await page.locator("#byline").innerText();
  if (!/^Chief of staff for Alex · updated /.test(byline)) fail("byline: " + byline);
  let t = await mainText(page);
  for (const s of ["Thursday, October 15", "Needs your answer", "Follow-ups Ada can send", "do 1 and 3", "The numbers mean this brief", "This week", "Due today", "Tell Priya Natarajan SSO can ship Thursday", "Needs your reply"])
    if (!has(t, s)) fail("Today is missing: " + s);
  if (!has(t, "Due yesterday")) fail("Today: overdue action not shown");
  // Two briefs: the latest (Midday check-in) first and open, the morning one collapsed below it.
  const latestH = (await page.locator("#main .brief-latest .brief-h").innerText()).trim();
  if (!/^Midday check-in/.test(latestH) || !/sent 12:31pm/.test(latestH)) fail("latest brief heading: " + latestH);
  const old = page.locator("#main details.brief-old");
  if ((await old.count()) !== 1) fail("expected 1 earlier brief, got " + (await old.count()));
  else {
    if (!/^Morning brief · sent 7:02am/.test((await old.locator("summary").innerText()).trim())) fail("earlier brief summary: " + (await old.locator("summary").innerText()));
    if (await old.evaluate(d => d.open)) fail("earlier brief should start collapsed");
    if (has(t, "Prep ready")) fail("collapsed brief's content is showing");
    await old.locator("summary").click();
    t = await mainText(page);
    for (const s of ["9:30am", "Prep ready", "Prep at 12:45pm", "Due elsewhere", "Send the v3 pricing deck to Dana Whitfield before the 9:30 review", "You may have missed"])
      if (!has(t, s)) fail("Morning brief is missing: " + s);
    if ((t.match(/The numbers mean this brief/g) || []).length !== 1) fail("the numbers hint should be on the latest brief only");
  }
  if (!(await page.locator('#nav [data-view="actions"] .n.hot').count())) fail("actions count isn't marked overdue");
  ok("Today page");
  await clickAllSections(page, "sample");

  // Catch up.
  const cuBtn = page.locator('#nav [data-view="catchup"]');
  if ((await cuBtn.locator(".n").innerText()) !== "4") fail("catch-up count: " + (await cuBtn.locator(".n").innerText()));
  if (!(await cuBtn.locator(".n.hot").count())) fail("catch-up count isn't red with a 3-day-old reply");
  if ((await page.locator("#nav button").nth(1).getAttribute("data-view")) !== "catchup") fail("Catch up isn't right after Today");
  await cuBtn.click();
  let ct = await mainText(page);
  for (const s of ["Needs your reply", "You may have missed", "Changed", "Raised 3 times · now a nudge", "Raised in 2 briefs", "3 days", "7 days", "Acme moved the renewal call to Dec 3"])
    if (!has(ct, s)) fail("Catch up is missing: " + s);
  if (!(await page.locator('#main a.src[href*="FMfcgzQXJWDsKmbNlrqhGvq"]').count())) fail("catch-up source chip doesn't link to the thread");
  ok("Catch up page");

  // Phone width: the sub-pages are a second row of tabs under the page title.
  {
    await page.setViewportSize({ width: 400, height: 900 });
    await page.evaluate(() => { location.hash = "how/briefs"; });
    if (!(await page.locator("#main .subtabs").isVisible()) || (await page.locator("#nav .subnav").isVisible())) fail("phone: sub-tabs not shown in place of the nested index");
    await page.locator('#main .subtabs [data-view="how/knows"]').click();
    if (!page.url().endsWith("#how/knows") || (await page.locator('#main .subtabs [aria-current="page"]').getAttribute("data-view")) !== "how/knows") fail("phone sub-tab didn't switch");
    await page.setViewportSize({ width: 1280, height: 900 });
    if (await page.locator("#main .subtabs").isVisible()) fail("sub-tabs showing on a wide screen");
    await page.evaluate(() => { location.hash = "today"; });
    ok("How Ada works: phone sub-tabs");
  }
  // Drafts.
  const views = await page.locator("#nav button").evaluateAll(bs => bs.map(b => b.dataset.view));
  if (views.indexOf("drafts") !== views.indexOf("waiting") + 1) fail("Drafts isn't right after Waiting on others: " + views.join(","));
  const drBtn = page.locator('#nav [data-view="drafts"]');
  if ((await drBtn.locator(".n").innerText()) !== "4") fail("drafts count: " + (await drBtn.locator(".n").innerText()));
  if (await drBtn.locator(".n.hot").count()) fail("drafts count is red with nothing urgent");
  await drBtn.click();
  let dt = await mainText(page);
  for (const s of ["Soon", "Long-term", "Moved or finished", "Pricing philosophy essay", "Last worked on Sep 20", "Waiting to be picked up", "Board narrative", "v3 · shorter opening, churn first", "For Jordan Kim", "Pricing email to Dana", "Ready", "Outline", "Moved", "Done", "Deck", "Email", "Message", "Due tomorrow"])
    if (!has(dt, s)) fail("Drafts page is missing: " + s);
  const openIn = page.locator('#main a.obs[href="https://docs.google.com/document/d/sample"]');
  if (!(await openIn.count()) || !has(await openIn.first().innerText(), "Open in Google Docs") || (await openIn.first().getAttribute("target")) !== "_blank") fail("moved draft's Open in link");
  const longCards = page.locator("#main section.block", { has: page.locator("h3", { hasText: /^Long-term/i }) }).locator(".dcard");
  if ((await longCards.count()) !== 1 || !has(await longCards.first().innerText(), "Waiting to be picked up")) fail("Long-term group");
  if (await longCards.locator(".tag.late, .tag.due").count()) fail("long-term draft has a warning tone");
  const soonCards = page.locator("#main section.block", { has: page.locator("h3", { hasText: /^Soon/i }) }).locator(".dcard");
  if ((await soonCards.count()) !== 3 || has(await soonCards.allInnerTexts().then(t => t.join(" ")), "Waiting to be picked up")) fail("Soon group");
  ok("Drafts page");
  await page.click('#main a[href="#drafts/Q4%20launch%20deck"]');
  dt = await mainText(page);
  if ((await page.locator("#main .slide").count()) !== 4) fail("deck should show 4 slides, got " + (await page.locator("#main .slide").count()));
  if ((await page.locator("#main .slide-notes").count()) !== 4 || !has(dt, "Open with the pricing decision")) fail("speaker notes missing");
  if (has(dt, "Speaker notes: Open")) fail("speaker notes prefix not stripped");
  for (const s of ["Kind", "Deck", "Outline", "Project", "Q4 Launch", "History", "Linked from"]) if (!has(dt, s)) fail("deck page is missing: " + s);
  await page.click("#main [data-raw]");
  if (!(await page.locator("#main pre.raw").innerText()).includes("### 2. What launches on Nov 18")) fail("deck Show the file");
  await page.click("#main [data-raw]");
  ok("deck draft page");
  await page.evaluate(() => { location.hash = "drafts/Acme%20uptime%20credit%20offer"; });
  dt = await mainText(page);
  if (!has(dt, "This moved to Google Docs on Thu, Oct 15. The copy there is the real one.")) fail("moved banner: " + dt.slice(0, 300));
  if (!(await page.locator('#main .moved-banner a[href="https://docs.google.com/document/d/sample"]').count())) fail("moved banner link");
  ok("moved draft page");
  await page.evaluate(() => { location.hash = "people/Jordan%20Kim"; });
  if (!(await page.locator('#main .backlinks a.wl[href="#drafts/Board%20narrative"]').count())) fail("person page doesn't list drafts for them");
  await page.evaluate(() => { location.hash = "drafts/Pricing%20email%20to%20Dana"; });
  if (!has(await mainText(page), "cos/now.md")) fail("draft page doesn't show what links to it");
  await page.evaluate(() => { location.hash = "today"; });
  dt = await mainText(page);
  if (!has(dt, "Drafts due soon") || !(await page.locator('#main a.wl[href="#drafts/Pricing%20email%20to%20Dana"]').count())) fail("Drafts due soon on Today");
  await page.click('#nav [data-view="archive"]');
  ct = await mainText(page);
  if (!has(ct, "From catch-up") || !has(ct, "Why: replied") || !has(ct, "Why: skipped")) fail("archived catch-up lines");
  await page.click('#nav [data-view="inbox"]');
  if (!(await mainText(page)).includes(CANARY)) fail("canary text didn't render literally");
  else ok("canary renders literally");
  await page.click("#main [data-raw]");
  if (!(await page.locator("#main pre.raw").innerText()).includes("Escaping canary: " + CANARY)) fail("canary wrong in Show the file");
  else ok("canary literal in Show the file");
  await page.click("#main [data-raw]");

  await page.click('#nav [data-view="people"]');
  await page.click('#main [data-go="people/Dana%20Whitfield"]');
  if (!page.url().endsWith("#people/Dana%20Whitfield")) fail("person hash: " + page.url());
  let pt = await mainText(page);
  if (!has(pt, "Dana Whitfield") || !/Linked from \d+ places/i.test(pt) || !has(pt, "cos/actions.md") || !has(pt, "Head of Sales")) fail("person page incomplete");
  else ok("person page");
  await page.click("#main [data-raw]");
  if (!(await page.locator("#main pre.raw").innerText()).includes("rhythm: Weekly pricing sync")) fail("person Show the file");
  await page.click("#main [data-raw]");
  await page.reload();
  if (!has(await mainText(page), "Linked from")) fail("reload lost the open note");

  await page.click('#nav [data-view="projects"]');
  await page.click('#main [data-go="projects/Q4%20Launch"]');
  pt = await mainText(page);
  if (!has(pt, "Q4 Launch") || !/Linked from \d+ places/i.test(pt) || !has(pt, "v3 pricing and the new onboarding")) fail("project page incomplete");
  else ok("project page");
  await page.click("#main .back");
  await page.click('#main [data-go="areas/Hiring"]');
  pt = await mainText(page);
  if (!has(pt, "Hiring") || !/Linked from/i.test(pt)) fail("area page incomplete"); else ok("area page");
  // A link inside a note goes to that note.
  await page.click('#main a.wl[href="#people/Marcus%20Bell"]');
  if (!(await page.locator("#main h2").innerText()).includes("Marcus Bell")) fail("wikilink didn't open the note"); else ok("wikilinks open notes");

  await page.evaluate(() => { location.hash = "people/Jordan%20Kim"; });
  if (!has(await mainText(page), "cos/catch-up.md")) fail("person page doesn't list catch-up lines");
  await page.click('#nav [data-view="links"]');
  const none = page.locator("#main a.wl-none", { hasText: "Mei Chen" });
  if (!(await none.count()) || (await none.first().getAttribute("title")) !== "No note yet: 2 mentions") fail("unlinked name isn't marked: " + (await none.first().getAttribute("title")));
  await none.first().click();
  if (!page.url().endsWith("#name/Mei%20Chen")) fail("name with no note didn't open its page: " + page.url());
  pt = await mainText(page);
  for (const s of ["Mei Chen", "No note yet. Ada starts one once Mei Chen comes up again, or ask Ada to start one now.", "2 mentions", "cos/facts.md", "cos/log/2026-10-14.md", "confirmed the new Stripe invoice format"])
    if (!has(pt, s)) fail("name page is missing: " + s);
  if (await page.locator("#main [data-start-note]").count()) fail("Start a note shown on the read-only copy");
  ok("names with no note open a page");
  await page.click('#nav [data-view="people"]');
  pt = await mainText(page);
  const mentioned = page.locator("#main section.block", { has: page.locator("h3", { hasText: /^Mentioned, no note yet/i }) });
  if (!(await mentioned.count()) || !has(await mentioned.innerText(), "Mei Chen · 2 mentions")) fail("People: Mentioned, no note yet");
  for (const p of ["Q4 Launch", "Board deck", "Product"]) if (has(await mentioned.innerText().catch(() => ""), p)) fail("People lists a project as a name: " + p);
  ok("People: mentioned, no note yet");

  // How Ada works for you: nested sub-pages under its index entry.
  const howText = async (page, sub) => { await page.evaluate(h => { location.hash = h; }, "how/" + sub); return mainText(page); };
  await page.click('#nav [data-view="how"]');
  if (!page.url().endsWith("#how/rules")) fail("the parent should open its first sub-page: " + page.url());
  const subs = await page.locator("#nav .subnav button").evaluateAll(bs => bs.map(b => b.dataset.view));
  if (subs.join() !== "how/rules,how/briefs,how/tools,how/knows,how/defaults,how/can") fail("sub-pages: " + subs.join());
  if ((await page.locator('#nav [data-view="how"]').getAttribute("aria-expanded")) !== "true") fail("parent isn't marked expanded");
  pt = await howText(page, "rules");
  for (const s of ["Your rules", "Nudges", "At most 2 a day", "My rules", "Nudge me at most twice a day", "Where things go", "Moved from my-instructions.md"]) if (!has(pt, s)) fail("Your rules is missing: " + s);
  if (has(pt, "Brief days") || has(pt, "Your briefs")) fail("Your rules shows brief settings");
  if ((await page.locator("#main section.block > h3", { hasText: /^Notes$/i }).count())) fail("a nested heading shows as its own section");
  if ((await page.locator("#main .path").innerText()).trim() !== "cos/my-rules.md") fail("Your rules file: " + (await page.locator("#main .path").innerText()));
  pt = await howText(page, "briefs");
  for (const s of ["Your briefs", "Midday check-in", "12:30pm", "6:45am", "Fridays", "Weekdays", "What goes in my briefs", "Skip newsletters", "Important people"]) if (!has(pt, s)) fail("Briefs is missing: " + s);
  pt = await howText(page, "tools");
  for (const s of ["My tools", "Presentations: Google Slides", "Team updates: Slack, #product-leads", "How I write", "Executives", "Numbers first, then the story"]) if (!has(pt, s)) fail("Tools & voice is missing: " + s);
  const toolsRows = await page.locator("#main section.block", { has: page.locator("h3", { hasText: /^My tools/i }) }).locator("tbody tr").count();
  if (toolsRows !== 4) fail("My tools rows: " + toolsRows);
  const writeRows = await page.locator("#main section.block", { has: page.locator("h3", { hasText: /^How I write/i }) }).locator("tbody tr").count();
  if (writeRows !== 5) fail("How I write rows: " + writeRows);
  if (!has(await page.locator("#main .path").innerText(), "cos/my-rules.md · cos/about-me.md")) fail("Tools & voice files");
  pt = await howText(page, "knows");
  for (const s of ["What Ada knows about you", "VP of Product", "Learned", "Family and time off"]) if (!has(pt, s)) fail("What Ada knows is missing: " + s);
  if (has(pt, "Numbers first, then the story")) fail("How I write shows on What Ada knows");
  pt = await howText(page, "defaults");
  for (const s of ["You changed this", "Always on", "Now: 3 briefs"]) if (!has(pt, s)) fail("Defaults is missing: " + s);
  if ((await page.locator("#main .overridden").count()) !== 3) fail("expected 3 struck-through defaults");
  if (!has(await page.locator("#main .path").innerText(), ".cos/defaults.md")) fail("Defaults file");
  // Everything Ada can do, from .cos/options.md: one block per group.
  pt = await howText(page, "can");
  const groups = [...(await import("node:fs")).readFileSync(new URL("file://" + optionsPath)).toString().matchAll(/^## (.+)$/gm)].map(m => m[1].trim());
  if (!has(pt, "Everything Ada can do") || !has(pt, "what can you do?") || !has(pt, "/cos:settings")) fail("Everything Ada can do section missing");
  for (const g of groups) if (!(await page.locator("#main section.block > h4", { hasText: new RegExp("^" + g.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$", "i") }).count())) fail("options group missing: " + g);
  if (!/Say: "move my morning brief to 6:45"/.test(pt)) fail("Say: hint missing");
  if (!has(pt, "Default: on")) fail("Default chip missing");
  if (!has(pt, "\"Catch me up since Friday\"")) fail("Ask any time phrases missing");
  await page.click("#main [data-raw]");
  if (!(await page.locator("#main .rawfile .path", { hasText: ".cos/options.md" }).count())) fail("options.md not in Show the file");
  await page.click("#main [data-raw]");
  ok("Everything Ada can do (" + groups.length + " groups)");
  if ((await page.locator('#nav .subnav [aria-current="page"]').getAttribute("data-view")) !== "how/can") fail("current sub-page not marked");
  await page.click('#nav [data-view="sources"]');
  if (await page.locator("#nav .subnav").count()) fail("sub-pages stay open after leaving");
  ok("How Ada works page");

  await page.fill("#q", "v3-beta");
  pt = await mainText(page);
  if (!has(pt, "forms.northwind.example/v3-beta") || !(await page.locator("#main mark").count())) fail("search for a URL fragment");
  await page.fill("#q", "uptime");
  pt = await mainText(page);
  if (!/\d+ results for “uptime”/.test(pt)) fail("search heading: " + pt.slice(0, 80));
  await page.locator("#main .grouplink", { hasText: "My actions" }).click();
  if ((await page.inputValue("#q")) !== "" || !(await page.locator("#main h2").innerText()).includes("My actions")) fail("search group header didn't open the section");
  await page.fill("#q", "GitHub notifications");
  if (!(await page.locator("#main .grouplink", { hasText: "Everything Ada can do" }).count()) || !has(await mainText(page), ".cos/options.md")) fail("search doesn't cover options.md");
  await page.fill("#q", "Presentations: Google Slides");
  await page.locator("#main .grouplink", { hasText: "Tools & voice" }).click();
  if (!page.url().endsWith("#how/tools")) fail("search result didn't land on its sub-page: " + page.url());
  await page.fill("#q", "Skip newsletters");
  if (!(await page.locator("#main .grouplink", { hasText: "Briefs" }).count())) fail("search groups my-rules lines by sub-page: " + (await page.locator("#main .grouplink").allInnerTexts()).join(" | "));
  await page.fill("#q", "stopped losing small teams");
  if (!(await page.locator("#main .grouplink", { hasText: "Drafts" }).count())) fail("search doesn't find draft text");
  await page.fill("#q", "canary");
  if (!(await mainText(page)).includes(CANARY)) fail("canary wrong in search results");
  await page.fill("#q", "");
  ok("search");
  if (errors.length) { errors.forEach(e => fail(e)); } else ok("no page or console errors");
  await ctx.close();
}
// Obsidian buttons, when Obsidian is installed.
{
  const fs = await import("node:fs");
  const obsPath = pagePath.replace(/brain\.html$/, "brain-obsidian.html");
  fs.writeFileSync(obsPath, fs.readFileSync(pagePath, "utf8").replace('"obsidian":false', '"obsidian":true'));
  const { ctx, page, errors } = await open(obsPath, { hash: "#people/Dana%20Whitfield" });
  const top = page.locator("#obs-top a.obs");
  const href = (await top.count()) ? await top.getAttribute("href") : "";
  if (!href.startsWith("obsidian://open?path=") || !decodeURIComponent(href).endsWith("/my work & notes/cos/now.md")) fail("Obsidian header link: " + href);
  if (!((await top.getAttribute("title")) || "").includes("Open folder as vault")) fail("Obsidian first-time hint missing");
  const small = page.locator("#main a.obs.small");
  if (!(await small.count()) || !decodeURIComponent(await small.getAttribute("href")).endsWith("/cos/people/Dana Whitfield.md")) fail("per-page Obsidian link");
  else ok("Obsidian links");
  errors.forEach(e => fail(e));
  await ctx.close();
  fs.unlinkSync(obsPath);
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
  if (!has(t, want)) fail(`next brief for ${today} ${now}: wanted "${want}", page says "${(t.match(/No brief yet today\.[^\n]*/) || ["nothing"])[0]}"`);
  errors.forEach(e => fail(e));
  await ctx.close();
}
ok("next brief");
// The older one-brief brief.md, and brief_time in my-rules.md.
{
  const { ctx, page, errors } = await open(legacyPath);
  let t = await mainText(page);
  const h = (await page.locator("#main .brief-latest .brief-h").innerText()).trim();
  if (!/^Morning brief/.test(h) || !/sent 7:02am/.test(h)) fail("legacy brief heading: " + h);
  for (const s of ["Focus", "9:30am", "Prep ready", "Follow-ups Ada can send", "The numbers mean this brief", "Jordan, Q3 logo churn was 2.1%.", "Due elsewhere"])
    if (!has(t, s)) fail("legacy brief is missing: " + s);
  if (await page.locator("#main details.brief-old").count()) fail("legacy brief shows earlier briefs");
  await page.evaluate(() => { location.hash = "how/briefs"; });
  t = await mainText(page);
  await page.evaluate(() => { location.hash = "how/rules"; });
  t += await mainText(page);
  await page.evaluate(() => { location.hash = "how/defaults"; });
  t += await mainText(page);
  for (const s of ["Your briefs", "Morning brief", "At 7:30am", "7:30am", "Weekdays", "From your settings", "Now: 1 brief"])
    if (!has(t, s)) fail("legacy How Ada works is missing: " + s);
  await clickAllSections(page, "legacy");
  errors.forEach(e => fail(e));
  ok("older brief.md and my-rules.md");
  await ctx.close();
}
// Phone width.
{
  const { ctx, page, errors } = await open(pagePath, { width: 400 });
  await clickAllSections(page, "400px");
  await page.click('#nav [data-view="people"]');
  await page.click('#main [data-go="people/Dana%20Whitfield"]');
  await noJunk(page, "400px person");
  errors.forEach(e => fail(e));
  await ctx.close();
}
// A brand-new notebook.
{
  const { ctx, page, errors } = await open(freshPath);
  await clickAllSections(page, "new notebook");
  await page.click('#nav [data-view="people"]');
  if (!has(await mainText(page), "No people notes yet. Ada starts a note for someone once they keep coming up")) fail("new notebook: people empty state");
  await page.click('#nav [data-view="drafts"]');
  if (!has(await mainText(page), "No drafts yet. Tell Ada “start a draft email to …” and it shows up here.")) fail("new notebook: drafts empty state: " + (await mainText(page)).slice(0, 400));
  await page.evaluate(() => { location.hash = "how/tools"; });
  const nt = await mainText(page);
  if (!has(nt, "When a draft is ready, Ada asks where it should go")) fail("new notebook: My tools empty state");
  if (!has(nt, "Ada asks before learning how you write from your sent messages")) fail("new notebook: How I write empty state");
  if (!(await mainText(page)).length) fail("new notebook: empty page");
  errors.forEach(e => fail(e));
  await ctx.close();
}
// Screenshots, when asked for.
if (shots) {
  const shotsOf = async (width, dark, list) => {
    const { ctx, page } = await open(pagePath, { width, dark });
    for (const [name, hash] of list) {
      await page.evaluate(h => { location.hash = h; }, hash);
      await page.waitForTimeout(250);
      await page.screenshot({ path: `${shots}/${name}-${width}${dark ? "-dark" : ""}.png`, fullPage: true });
    }
    await ctx.close();
  };
  await shotsOf(1280, false, [["catchup", "catchup"], ["drafts", "drafts"], ["draft-deck", "drafts/Q4%20launch%20deck"], ["draft-moved", "drafts/Acme%20uptime%20credit%20offer"]]);
  await shotsOf(400, false, [["draft-deck", "drafts/Q4%20launch%20deck"], ["drafts", "drafts"]]);
  const list = [["today", "today"], ["person", "people/Dana%20Whitfield"], ["people", "people"], ["name-page", "name/Mei%20Chen"], ["about", "how/rules"], ["about-briefs", "how/briefs"], ["about-tools", "how/tools"], ["about-defaults", "how/defaults"], ["about-can", "how/can"]];
  await shotsOf(1280, false, list);
  await shotsOf(400, false, list);
  await shotsOf(1280, true, [["today", "today"], ["people", "people"], ["about", "how/rules"]]);
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

await page.goto(liveUrl + "&today=2026-10-15#actions");
await page.waitForLoadState("networkidle");
if (!(await page.locator("#cos-server").count())) fail("no #cos-server on the served page");
if (await page.locator(".notice.ro").count()) fail("read-only notice shown on the live page");
if (!(await page.locator("#byline").innerText()).includes("live")) fail("byline doesn't say live");

// 1. Check off an action.
const marcus = page.locator("#main li[data-il]", { hasText: "Book a design review" });
await marcus.locator("input.cb").check();
await toastSays("Checked off");
let line = read("cos/actions.md").split("\n").find(l => l.includes("Book a design review"));
if (!/^- \[x\] /.test(line) || !/\[done:: \d{4}-\d{2}-\d{2}\]/.test(line)) fail("check off didn't save: " + line); else ok("check off saves [x] and done");
await until("checked item moves to Done", async () => (await page.locator("#main details.done").innerText()).includes("Done (3)"));

// 2. Edit a line's text: the fields stay.
const narrative = page.locator("#main li[data-il]", { hasText: "Write the board narrative" });
await narrative.hover();
await narrative.locator(".pen").click();
const input = page.locator("#main input.inline-edit");
if ((await input.inputValue()) !== "Write the board narrative for the Nov 6 meeting, for the [[Board deck]]") fail("inline edit value: " + (await input.inputValue()));
await input.fill("Write the board narrative for the Nov 6 board meeting, for the [[Board deck]]");
await input.press("Enter");
await toastSays("Saved");
line = read("cos/actions.md").split("\n").find(l => l.includes("board narrative"));
if (line !== "- [ ] Write the board narrative for the Nov 6 board meeting, for the [[Board deck]] [due:: 2026-10-30] [src:: onboarding 2026-10-01]") fail("edited line: " + line);
else ok("inline edit keeps the box and fields");
// Esc cancels
await page.locator("#main li[data-il]", { hasText: "Reply to" }).dblclick({ position: { x: 200, y: 14 } });
if (!(await page.locator("#main input.inline-edit").count())) fail("double-click didn't start an edit");
await page.keyboard.press("Escape");
if (await page.locator("#main input.inline-edit").count()) fail("Esc didn't cancel");

// 3. Add to the inbox.
await go("inbox");
await page.locator('#main .addrow[data-add-path="cos/inbox.md"] input').fill("Call the bank about the wire, ask [[Mei Chen]]");
await page.keyboard.press("Enter");
await toastSays("Added");
if (!/^- Call the bank about the wire, ask \[\[Mei Chen\]\] \[src:: page \d{4}-\d{2}-\d{2}\]$/m.test(read("cos/inbox.md"))) fail("inbox add: " + read("cos/inbox.md").slice(-200));
else ok("add to inbox");
if (!(await page.locator("#main").innerText()).includes("Call the bank about the wire")) fail("added item not shown");
// Add an action lands under To do, with a box.
await go("actions");
await page.locator('#main .addrow[data-add-path="cos/actions.md"] input').fill("Order new name badges");
await page.keyboard.press("Enter");
await toastSays("Added");
const acts = read("cos/actions.md");
if (!/- \[ \] Order new name badges \[src:: page [\d-]+\]\n(?:[^\n]*\n)*?## Elsewhere/.test(acts)) fail("action add didn't land in To do"); else ok("add an action");

// 4. Edit the whole file.
await go("people/Dana%20Whitfield");
const editBtn = page.locator("#main [data-edit]");
if ((await editBtn.getAttribute("aria-label")) !== "Edit the file" || !(await editBtn.getAttribute("title"))) fail("edit button label");
await editBtn.click();
const ta = page.locator("#ed-text");
await until("editor loads", async () => (await ta.inputValue()).includes("rhythm:"));
await ta.fill((await ta.inputValue()).replace("Weekly pricing sync, Thursdays", "Weekly pricing sync, Fridays"));
await page.click("#ed-save");
await toastSays("Saved");
if (!read("cos/people/Dana Whitfield.md").includes("rhythm: Weekly pricing sync, Fridays")) fail("file edit not saved"); else ok("Edit the file saves");
if (!(await page.locator("#editor").isHidden())) fail("editor didn't close");
await until("page shows the edit", async () => (await page.locator("#main").innerText()).includes("Weekly pricing sync, Fridays"));

// 5. The file changed while editing: see the choices, keep mine.
await go("inbox");
await page.click("#main [data-edit]");
await until("editor loads inbox", async () => (await ta.inputValue()).includes("# Inbox"));
write("cos/inbox.md", read("cos/inbox.md") + "- Changed on disk meanwhile [src:: cv 2026-10-15]\n");
await ta.fill((await ta.inputValue()) + "- Mine from the editor\n");
await page.click("#ed-save");
await until("conflict shown", async () => (await page.locator("#ed-conflict").isVisible()) && (await page.locator("#ed-conflict").innerText()).includes("This note changed while you were editing it"));
await page.click('[data-conflict="keep"]');
await page.click('[data-conflict="replace"]');
await toastSays("Saved");
if (!read("cos/inbox.md").includes("- Mine from the editor") || read("cos/inbox.md").includes("Changed on disk meanwhile")) fail("keep mine didn't overwrite"); else ok("editor conflict: keep mine");

// 6. A change on disk shows up by itself.
await go("actions");
write("cos/actions.md", read("cos/actions.md").replace("## To do\n", "## To do\n- [ ] Renew the team's Figma seats [src:: cv 2026-10-15]\n"));
await until("page refreshes with the outside change", async () => (await page.locator("#main").innerText()).includes("Renew the team's Figma seats"), 6000) && ok("live refresh after an outside change");

// 7. A stale check-off: error, then the page catches up.
await page.evaluate(() => { window.cosPausePolling = true; });
write("cos/actions.md", read("cos/actions.md").replace("- [ ] Draft the uptime credit offer", "- [ ] Write the uptime credit offer"));
await page.locator("#main li[data-il]", { hasText: "Draft the uptime credit offer" }).locator("input.cb").check();
await toastSays("changed since the page loaded", true);
await until("page refreshes after the stale edit", async () => (await page.locator("#main").innerText()).includes("Write the uptime credit offer"));
if (read("cos/actions.md").includes("[x] Write the uptime credit offer")) fail("stale toggle was applied");
if (await page.locator("#main li[data-il]", { hasText: "Write the uptime credit offer" }).locator("input.cb").isChecked()) fail("stale checkbox stayed checked");
ok("stale toggle: error toast and refresh");
await page.evaluate(() => { window.cosPausePolling = false; });

// 8. Start a note for a name that has none.
await go("name/Mei%20Chen");
await page.click("#main [data-start-note]");
await toastSays("Note started");
if (read("cos/people/Mei Chen.md") !== "---\nrole:\norg:\n---\n# Mei Chen\n") fail("new note: " + JSON.stringify(read("cos/people/Mei Chen.md")));
await until("opens the new note", async () => page.url().endsWith("#people/Mei%20Chen") && (await page.locator("#main h2").innerText()).includes("Mei Chen"));
if (!/On the notebook page: started a note for Mei Chen/.test(fs.readdirSync(path.join(ws, "cos/log")).filter(f => /^\d{4}-\d{2}-\d{2}\.md$/.test(f)).sort().reverse().map(f => read("cos/log/" + f)).join("\n"))) fail("create isn't logged");
const again = await page.evaluate(async () => {
  const key = JSON.parse(document.getElementById("cos-server").textContent).key;
  const r = await fetch("/api/create", { method: "POST", headers: { "X-Notebook-Key": key, "Content-Type": "application/json" }, body: JSON.stringify({ path: "cos/people/Mei Chen.md", content: "x" }) });
  return r.status;
});
if (again !== 409) fail("create over an existing note: " + again);
const outside = await page.evaluate(async () => {
  const key = JSON.parse(document.getElementById("cos-server").textContent).key;
  const r = await fetch("/api/create", { method: "POST", headers: { "X-Notebook-Key": key, "Content-Type": "application/json" }, body: JSON.stringify({ path: "cos/../evil.md", content: "x" }) });
  return r.status;
});
if (outside !== 400) fail("create outside cos/: " + outside);
ok("Start a note");

// 9. Quiet icon buttons are labelled.
for (const h of ["actions", "people/Dana%20Whitfield", "how/rules"]) {
  await go(h);
  for (const b of await page.locator("#main .file .ibtn").all()) {
    if (!(await b.getAttribute("aria-label")) || !(await b.getAttribute("title"))) fail(`${h}: icon button without a label`);
  }
}
ok("icon buttons have labels");

// 9. Theme switch.
await page.click('[data-theme-set="dark"]');
if ((await page.evaluate(() => document.documentElement.getAttribute("data-theme"))) !== "dark") fail("dark theme not set");
await page.reload(); await page.waitForLoadState("networkidle");
if ((await page.evaluate(() => document.documentElement.getAttribute("data-theme"))) !== "dark") fail("theme not kept across reload");
if ((await page.locator('[data-theme-set="dark"]').getAttribute("aria-pressed")) !== "true") fail("dark not shown as chosen");
await page.click('[data-theme-set="auto"]');
if (await page.evaluate(() => document.documentElement.hasAttribute("data-theme"))) fail("auto didn't clear the theme");
ok("theme switch");

// Screenshots: edit mode, light and dark.
if (shots) {
  for (const dark of [false, true]) {
    await page.evaluate(d => { if (d) document.documentElement.setAttribute("data-theme", "dark"); else document.documentElement.removeAttribute("data-theme"); }, dark);
    await go("actions");
    await page.locator("#main li[data-il]", { hasText: "Reply to" }).hover();
    await page.screenshot({ path: `${shots}/live-actions${dark ? "-dark" : ""}.png`, fullPage: true });
    await page.click("#main [data-edit]");
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
  await p2.goto(pathToFileURL(fileCopy).href + "?today=2026-10-15#actions");
  const n = p2.locator(".notice.ro");
  if (!(await n.count()) || !(await n.innerText()).includes("Read-only copy. To check things off and edit, open your live notebook")) fail("read-only notice");
  if ((await n.locator("a").getAttribute("href")) !== liveUrl) fail("read-only notice link: " + (await n.locator("a").getAttribute("href")));
  if (await p2.locator("input.cb, .pen, .addrow, [data-edit]").count()) fail("file copy shows edit controls");
  if (shots) await p2.screenshot({ path: `${shots}/readonly-notice.png`, clip: { x: 0, y: 0, width: 1280, height: 260 } });
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
