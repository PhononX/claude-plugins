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
trap 'rm -rf "$TMP"' EXIT

FAILS=0
fail() { echo "  FAIL: $*"; FAILS=$((FAILS + 1)); }
ok() { echo "  ok: $*"; }

setup_ws() { # $1: directory to create
  mkdir -p "$1/.cos"
  cp -R "$TESTS/sample-workspace/cos" "$1/cos"
  cp "$DOTCOS/build-brain.sh" "$DOTCOS/brain-template.html" "$DOTCOS/defaults.md" "$1/.cos/"
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
  case "$rel" in cos/log/transcripts/*) continue ;; esac
  grep -qF "data-path=\"$(html_attr "$rel")\"" "$B" || { fail "not embedded: $rel"; MISSING=1; }
done < <(find "$WS/cos" -type f -name '*.md' -print0)
grep -qF 'data-path=".cos/defaults.md"' "$B" || { fail "defaults.md not embedded"; MISSING=1; }
[ $MISSING -eq 0 ] && ok "every note embedded"
grep -q 'TRANSCRIPT-SHOULD-NOT-BE-EMBEDDED' "$B" && fail "a transcript was embedded" || ok "transcripts left out"
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
cp "$DOTCOS/build-brain.sh" "$DOTCOS/brain-template.html" "$DOTCOS/defaults.md" "$WS4/.cos/"
if [ -d "$PLUGIN/templates/cos" ]; then
  for f in "$PLUGIN/templates/cos"/*.md; do
    sed -e 's/{{AGENT_NAME}}/Ada/g' -e 's/{{OWNER_NAME}}/Alex/g' "$f" > "$WS4/cos/$(basename "$f")"
  done
fi
printf '0.2.0\n' > "$WS4/cos/.version"
"$WS4/.cos/build-brain.sh" && [ -f "$WS4/brain.html" ] && ok "builds a brand-new notebook" || fail "brand-new notebook build"

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
const [pwPath, pagePath, freshPath, shots] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(pwPath).href);
const CANARY = `</script> and <!-- not a comment --> with $HOME & "quotes" 'single' C:\\temp\\new 🚀 café`;
let fails = 0;
const fail = m => { console.log("  FAIL: " + m); fails++; };
const ok = m => console.log("  ok: " + m);
const url = (p, today = "2026-10-15", hash = "") => pathToFileURL(p).href + "?today=" + today + hash;

const browser = await chromium.launch();
async function open(p, opts = {}) {
  const ctx = await browser.newContext({ viewport: { width: opts.width || 1280, height: 900 }, colorScheme: opts.dark ? "dark" : "light" });
  // Fonts come from Google when online; block them so the run is offline and deterministic.
  await ctx.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  const page = await ctx.newPage();
  const errors = [];
  page.on("pageerror", e => errors.push("page error: " + e.message));
  page.on("console", m => { if (m.type() === "error" && !/fonts\.(googleapis|gstatic)|ERR_FAILED|net::/.test(m.text() + (m.location().url || ""))) errors.push("console: " + m.text()); });
  await page.goto(url(p, opts.today, opts.hash || ""));
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
  const n = await page.locator("#nav button").count();
  for (let i = 0; i < n; i++) {
    const b = page.locator("#nav button").nth(i);
    const name = (await b.locator("span").first().innerText()).trim();
    await b.click();
    const h2 = (await page.locator("#main h2").first().innerText()).trim();
    if (!h2) fail(`${label} ${name}: no heading`);
    if ((await b.getAttribute("aria-current")) !== "page") fail(`${label} ${name}: not marked current`);
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
  const t = await mainText(page);
  for (const s of ["Thursday, October 15", "Needs your answer", "Follow-ups Ada can send", "do 1 and 3", "9:30am", "Prep ready", "Prep at 12:45pm", "Due elsewhere", "This week", "Due today"])
    if (!has(t, s)) fail("Today is missing: " + s);
  if (!has(t, "Due yesterday")) fail("Today: overdue action not shown");
  if (!(await page.locator('#nav [data-view="actions"] .n.hot').count())) fail("actions count isn't marked overdue");
  ok("Today page");
  await clickAllSections(page, "sample");

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

  await page.click('#nav [data-view="links"]');
  const none = page.locator("#main .wl-none", { hasText: "Mei Chen" });
  if (!(await none.count()) || (await none.first().getAttribute("title")) !== "No note yet") fail("unlinked name isn't marked"); else ok("names with no note");

  await page.click('#nav [data-view="about"]');
  pt = await mainText(page);
  for (const s of ["You changed this", "Always on", "At 6:45am", "Moved from my-instructions.md", "Family and time off", "Learned", "Send the morning brief at 6:45"])
    if (!has(pt, s)) fail("How Ada works is missing: " + s);
  if ((await page.locator("#main .overridden").count()) !== 3) fail("expected 3 struck-through defaults");
  if ((await page.locator("#main section.block > h3", { hasText: /^Notes$/i }).count())) fail("a nested heading shows as its own section");
  ok("How Ada works page");

  await page.fill("#q", "v3-beta");
  pt = await mainText(page);
  if (!has(pt, "forms.northwind.example/v3-beta") || !(await page.locator("#main mark").count())) fail("search for a URL fragment");
  await page.fill("#q", "uptime");
  pt = await mainText(page);
  if (!/\d+ results for “uptime”/.test(pt)) fail("search heading: " + pt.slice(0, 80));
  await page.locator("#main .grouplink", { hasText: "My actions" }).click();
  if ((await page.inputValue("#q")) !== "" || !(await page.locator("#main h2").innerText()).includes("My actions")) fail("search group header didn't open the section");
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
// The day after the brief: no brief today.
{
  const { ctx, page, errors } = await open(pagePath, { today: "2026-10-16" });
  const t = await mainText(page);
  if (!has(t, "No brief yet today. The last one was Thu, Oct 15.")) fail("stale brief line missing");
  else ok("no-brief-today state");
  errors.forEach(e => fail(e));
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
  const list = [["today", "today"], ["person", "people/Dana%20Whitfield"], ["about", "about"]];
  await shotsOf(1280, false, list);
  await shotsOf(400, false, list);
  await shotsOf(1280, true, [["today", "today"]]);
  ok("screenshots in " + shots);
}
await browser.close();
process.exit(fails ? 1 : 0);
JS
  node "$TMP/check.mjs" "$PW" "$B" "$WS4/brain.html" "${BRAIN_SHOTS:-}" || FAILS=$((FAILS + 1))
fi

echo
if [ $FAILS -eq 0 ]; then echo "PASS"; exit 0; else echo "FAIL ($FAILS)"; exit 1; fi
