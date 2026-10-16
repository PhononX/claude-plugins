#!/usr/bin/env node
// The notebook server: serves this agent's notebook page at http://localhost:<port>/?k=<key>, on
// this computer only, and saves edits made on the page back into the Markdown files in cos/.
// Started at login (launchd on a Mac, systemd on Linux), and by ./start-cos.sh and
// ./open-brain.sh when it isn't running. No dependencies beyond Node.js.
//
// Every request but /health needs the key from .cv/notebook.key: in the address (?k=) for pages,
// and in the X-Notebook-Key header for the API, which also needs a JSON body, so other websites
// can't send it changes. The Host header must be localhost or 127.0.0.1 (no DNS rebinding).
import http from 'node:http'
import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import { execFile } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const DOTCOS = path.dirname(fileURLToPath(import.meta.url))
const ROOT = path.dirname(DOTCOS)
const COS = path.join(ROOT, 'cos')
const KEY_FILE = path.join(ROOT, '.cv', 'notebook.key')
const MAX_BODY = 2 * 1024 * 1024
const LOG_DAYS = 45

const setup = readSetup()
const PORT = Number(process.env.COS_NOTEBOOK_PORT || setup.NOTEBOOK_PORT || 0)
if (!PORT) fail('No NOTEBOOK_PORT in cos/setup.conf. Run ./update-cos.sh.')
if (!fs.existsSync(path.join(COS, '.version'))) fail(`${ROOT} isn't a Chief of Staff folder.`)
const KEY = fs.readFileSync(KEY_FILE, 'utf8').trim()
if (KEY.length < 32) fail('The notebook key in .cv/notebook.key is missing or too short. Run ./update-cos.sh.')
const ID = crypto.createHash('sha256').update(ROOT).digest('hex').slice(0, 16)

function fail(msg) { console.error(`notebook-server: ${msg}`); process.exit(1) }
function log(msg) { console.log(`${new Date().toISOString()} ${msg}`) }

function readSetup() {
  const out = {}
  try {
    for (const line of fs.readFileSync(path.join(ROOT, 'cos', 'setup.conf'), 'utf8').split('\n')) {
      const i = line.indexOf('=')
      if (i > 0 && !line.startsWith('#')) out[line.slice(0, i)] = line.slice(i + 1)
    }
  } catch {}
  return out
}

// ---------- the notes, chosen as build-brain.sh chooses them ----------
function collect() {
  const files = []
  const logs = []
  const walk = (dir, rel) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name.startsWith('.')) continue
      const r = rel ? `${rel}/${e.name}` : e.name
      if (e.isDirectory()) {
        if (r === 'log/transcripts') continue
        walk(path.join(dir, e.name), r)
      } else if (e.isFile() && e.name.endsWith('.md')) {
        if (/^log\/\d{4}-\d{2}-\d{2}\.md$/.test(r)) logs.push(r)
        else files.push(r)
      }
    }
  }
  walk(COS, '')
  logs.sort().reverse()
  return [...files, ...logs.slice(0, LOG_DAYS)].map(r => `cos/${r}`)
    .concat(['.cos/defaults.md', '.cos/options.md'].filter(p => fs.existsSync(path.join(ROOT, p))))
}
function version() {
  const h = crypto.createHash('sha1')
  for (const p of collect()) {
    try { const s = fs.statSync(path.join(ROOT, p)); h.update(`${p}:${s.mtimeMs}:${s.size}\n`) } catch {}
  }
  return h.digest('hex').slice(0, 16)
}
function notes() {
  const files = {}
  for (const p of collect()) { try { files[p] = fs.readFileSync(path.join(ROOT, p), 'utf8') } catch {} }
  return { files, version: version(), built: new Date().toISOString() }
}

// ---------- building the page ----------
let building = Promise.resolve()
function build() {
  building = building.then(() => new Promise(resolve => {
    execFile('/bin/bash', [path.join(DOTCOS, 'build-brain.sh')], { timeout: 30000 }, err => {
      if (err) log(`build failed: ${err.message}`)
      resolve()
    })
  }))
  return building
}
async function page() {
  await build()
  const html = fs.readFileSync(path.join(ROOT, 'brain.html'), 'utf8')
  const cfg = JSON.stringify({ editable: true, key: KEY, port: PORT }).replace(/</g, '\\u003c')
  const tag = `<script type="application/json" id="cos-server">${cfg}</script>`
  return html.includes('</head>') ? html.replace('</head>', `${tag}\n</head>`) : tag + html
}

// ---------- edits ----------
const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` }
const now = () => { const d = new Date(); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}` }
const sha = s => crypto.createHash('sha1').update(s).digest('hex')

class HttpError extends Error { constructor(status, msg, extra) { super(msg); this.status = status; this.extra = extra } }

// A notebook file the page may change: under cos/, a .md file, no hidden folders, no "..".
function notePath(p) {
  if (typeof p !== 'string' || !/^cos\/[^\0]+\.md$/.test(p)) throw new HttpError(400, 'Not a notebook file.')
  const parts = p.split('/')
  if (parts.some(s => s === '' || s === '..' || s.startsWith('.'))) throw new HttpError(400, 'Not a notebook file.')
  if (p.startsWith('cos/log/transcripts/')) throw new HttpError(400, 'Transcripts are read-only.')
  const full = path.join(ROOT, p)
  const realCos = fs.realpathSync(COS)
  const dir = fs.realpathSync(fs.existsSync(path.dirname(full)) ? path.dirname(full) : COS)
  if (dir !== realCos && !dir.startsWith(realCos + path.sep)) throw new HttpError(400, 'Not a notebook file.')
  return full
}
function readNote(full) { try { return fs.readFileSync(full, 'utf8') } catch { return null } }
function writeNote(full, text) {
  fs.mkdirSync(path.dirname(full), { recursive: true })
  const tmp = `${full}.${process.pid}.tmp`
  fs.writeFileSync(tmp, text)
  fs.renameSync(tmp, full)
}
function oneLine(s, what) {
  if (typeof s !== 'string' || !s.trim()) throw new HttpError(400, `${what} is empty.`)
  if (/[\r\n]/.test(s)) throw new HttpError(400, `${what} must be one line.`)
  return s.replace(/\s+$/, '')
}
// Finds the line exactly as the page saw it. If it isn't there exactly once, the file changed
// since the page loaded (the agent, or Obsidian, edited it): refuse, so nothing is overwritten.
function findLine(lines, line) {
  const hits = lines.reduce((a, l, i) => (l === line ? [...a, i] : a), [])
  if (hits.length !== 1) throw new HttpError(409, 'That changed since the page loaded. The page will refresh; try again.')
  return hits[0]
}
// Notes the edit in today's daily log, so the agent knows what the user changed, and that the
// user did it.
function logEdit(what) {
  const file = path.join(COS, 'log', `${today()}.md`)
  let text = readNote(file) ?? `# ${today()}\n\n`
  if (!text.endsWith('\n')) text += '\n'
  writeNote(file, `${text}- ${now()} On the notebook page: ${what} [src:: page ${today()}]\n`)
}
const short = s => {
  const t = s.replace(/^\s*(?:[-*]|\d+\.)\s+(?:\[[ xX]\]\s+)?/, '').replace(/\s*\[[a-z_]+::(?:[^\[\]]|\[\[[^\]]*\]\])*\]/g, '').trim()
  return `"${t.length > 80 ? t.slice(0, 77) + '…' : t}"`
}

const ops = {
  toggle({ path: p, line, checked }) {
    const full = notePath(p); const text = readNote(full)
    if (text === null) throw new HttpError(404, 'That note is gone.')
    const lines = text.split('\n'); const i = findLine(lines, oneLine(line, 'The line'))
    const m = lines[i].match(/^(\s*[-*]\s+)\[([ xX])\](\s+.*)$/)
    if (!m) throw new HttpError(400, "That line isn't a checkbox item.")
    let rest = m[3].replace(/\s*\[done::[^\]]*\]/g, '')
    if (checked) {
      const at = rest.search(/\s\[src::/)
      rest = at >= 0 ? `${rest.slice(0, at)} [done:: ${today()}]${rest.slice(at)}` : `${rest} [done:: ${today()}]`
    }
    lines[i] = `${m[1]}[${checked ? 'x' : ' '}]${rest}`
    writeNote(full, lines.join('\n'))
    logEdit(`${checked ? 'checked off' : 'unchecked'} ${short(lines[i])} in ${p}`)
    return { line: lines[i] }
  },
  replace({ path: p, line, newLine }) {
    const full = notePath(p); const text = readNote(full)
    if (text === null) throw new HttpError(404, 'That note is gone.')
    const lines = text.split('\n'); const i = findLine(lines, oneLine(line, 'The line'))
    const before = lines[i]
    lines[i] = oneLine(newLine, 'The new line')
    writeNote(full, lines.join('\n'))
    logEdit(`changed ${short(before)} to ${short(lines[i])} in ${p}`)
    return { line: lines[i] }
  },
  add({ path: p, section, text: t }) {
    const full = notePath(p)
    const item = oneLine(t, 'The item').replace(/^\s*[-*]\s+(\[[ xX]\]\s+)?/, '')
    const box = /^cos\/(actions|waiting)\.md$/.test(p) ? '[ ] ' : ''
    const line = `- ${box}${item}${/\[src::/.test(item) ? '' : ` [src:: page ${today()}]`}`
    let text = readNote(full) ?? `# ${path.basename(p, '.md')}\n`
    const lines = text.replace(/\n+$/, '').split('\n')
    let at = lines.length
    if (section) {
      const h = lines.findIndex(l => l.trim() === `## ${String(section).replace(/^#+\s*/, '')}`)
      if (h >= 0) {
        let end = lines.findIndex((l, j) => j > h && /^#{1,2}\s/.test(l)); if (end < 0) end = lines.length
        at = end
        while (at > h + 1 && lines[at - 1].trim() === '') at--
      }
    }
    lines.splice(at, 0, line)
    writeNote(full, lines.join('\n') + '\n')
    logEdit(`added ${short(line)} to ${p}`)
    return { line }
  },
  file({ path: p }) {
    const full = notePath(p); const text = readNote(full)
    return { content: text ?? '', hash: text === null ? null : sha(text) }
  },
  write({ path: p, content, hash }) {
    const full = notePath(p)
    if (typeof content !== 'string') throw new HttpError(400, 'Nothing to save.')
    const cur = readNote(full)
    if ((cur === null ? null : sha(cur)) !== (hash ?? null)) {
      throw new HttpError(409, 'This note changed while you were editing it.', { content: cur ?? '', hash: cur === null ? null : sha(cur) })
    }
    writeNote(full, content.endsWith('\n') ? content : `${content}\n`)
    logEdit(`edited ${p}`)
    return { hash: sha(readNote(full)) }
  },
}

// ---------- HTTP ----------
function sameKey(k) {
  const a = Buffer.from(String(k ?? '')); const b = Buffer.from(KEY)
  return a.length === b.length && crypto.timingSafeEqual(a, b)
}
function send(res, status, body, type = 'application/json; charset=utf-8') {
  const data = typeof body === 'string' ? body : JSON.stringify(body)
  res.writeHead(status, {
    'Content-Type': type, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer', 'X-Frame-Options': 'DENY',
  })
  res.end(data)
}
function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0; const chunks = []
    req.on('data', c => { size += c.length; if (size > MAX_BODY) { reject(new HttpError(413, 'Too big.')); req.destroy() } else chunks.push(c) })
    req.on('end', () => { try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')) } catch { reject(new HttpError(400, 'Not JSON.')) } })
    req.on('error', reject)
  })
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://localhost:${PORT}`)
    const host = String(req.headers.host || '')
    if (host !== `localhost:${PORT}` && host !== `127.0.0.1:${PORT}`) return send(res, 403, { error: 'Wrong host.' })
    if (url.pathname === '/health') return send(res, 200, { ok: true, id: ID })
    if (req.method === 'GET' && url.pathname === '/') {
      if (!sameKey(url.searchParams.get('k'))) return send(res, 403, 'This notebook needs its key. Open it with ./open-brain.sh in your agent\'s folder.', 'text/plain; charset=utf-8')
      return send(res, 200, await page(), 'text/html; charset=utf-8')
    }
    if (!url.pathname.startsWith('/api/')) return send(res, 404, { error: 'Not found.' })
    if (!sameKey(req.headers['x-notebook-key'])) return send(res, 403, { error: 'Wrong key.' })
    const origin = req.headers.origin
    if (origin && origin !== `http://localhost:${PORT}` && origin !== `http://127.0.0.1:${PORT}`) return send(res, 403, { error: 'Wrong origin.' })
    const name = url.pathname.slice(5)
    if (req.method === 'GET' && name === 'version') return send(res, 200, { version: version() })
    if (req.method === 'GET' && name === 'notes') return send(res, 200, notes())
    if (req.method === 'POST' && ops[name]) {
      if (!String(req.headers['content-type'] || '').startsWith('application/json')) return send(res, 415, { error: 'Send JSON.' })
      const result = ops[name](await readBody(req))
      if (name !== 'file') build()   // keep brain.html, the copy that opens without the server, current
      return send(res, 200, { ok: true, ...result, version: version() })
    }
    return send(res, 404, { error: 'Not found.' })
  } catch (e) {
    if (e instanceof HttpError) return send(res, e.status, { error: e.message, ...(e.extra || {}) })
    log(`error: ${e.stack || e}`)
    return send(res, 500, { error: 'Something went wrong saving that. The details are in .cv/notebook-server.log.' })
  }
})
// Node.js resets inherited signal handling, so nohup can't protect it: ignore the hang-up a
// closing Terminal window sends, or a copy started from ./start-cos.sh would stop with it.
process.on('SIGHUP', () => {})
server.on('error', e => fail(e.code === 'EADDRINUSE' ? `port ${PORT} is already in use` : e.message))
server.listen(PORT, '127.0.0.1', () => log(`serving ${ROOT} at http://localhost:${PORT}/`))
