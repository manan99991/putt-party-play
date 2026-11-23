/**
 * pack-app — turn the DEPLOYED site (the GitHub Pages layout: index.html menu + w1..w11 hole pages + sounds/
 * backgrounds/ sprites/ worlds/) into the Capacitor webDir for the iOS / Android app, bundled OFFLINE.
 *
 * Every 3D hole page is self-contained (~4 MB: the whole engine + its textures inlined), so 200 holes would be a
 * ~1 GB app. Here the identical pieces are stored ONCE in www/shared/ (engine bundle by content hash, every large
 * data: URI by content hash) and each hole page points at them, ~0.3 MB per hole → a ~130 MB app.
 *
 *   node tools/pack-app.mjs <site-dir> [www]      e.g. node tools/pack-app.mjs ../putt-party-play www
 *
 * Links in the game name index.html explicitly (the app shell serves extensionless paths as the ROOT page).
 */
import { readFileSync, writeFileSync, mkdirSync, rmSync, cpSync, existsSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join } from 'node:path';

const [SITE, WWW = 'www'] = process.argv.slice(2);
if (!SITE || !existsSync(join(SITE, 'index.html'))) { console.error('usage: node tools/pack-app.mjs <site-dir> [www]'); process.exit(1); }
rmSync(WWW, { recursive: true, force: true }); mkdirSync(join(WWW, 'shared'), { recursive: true });

// 1) the menu + its assets, as deployed
for (const f of ['index.html', 'version.json', 'icon-180.png', 'icon-512.png', 'favicon.svg', 'manifest.webmanifest'])
  if (existsSync(join(SITE, f))) cpSync(join(SITE, f), join(WWW, f));
for (const d of ['sounds', 'backgrounds', 'sprites', 'worlds']) if (existsSync(join(SITE, d))) cpSync(join(SITE, d), join(WWW, d), { recursive: true });

// 2) every hole page, with the engine + big embedded assets shared
const EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/svg+xml': 'svg', 'audio/mpeg': 'mp3', 'font/woff2': 'woff2', 'application/octet-stream': 'bin' };
const seen = new Set(); let holes = 0, before = 0, after = 0;
const put = (name, data) => { if (!seen.has(name)) { writeFileSync(join(WWW, 'shared', name), data); seen.add(name); } };
const h = s => createHash('sha1').update(s).digest('hex').slice(0, 16);
for (const w of readdirSync(SITE).filter(d => /^w\d+$/.test(d)).sort()) {
  for (const n of readdirSync(join(SITE, w))) {
    const src = join(SITE, w, n, 'index.html'); if (!existsSync(src)) continue;
    let s = readFileSync(src, 'utf8'); before += s.length;
    // big data: URIs → shared files (they are only ever used as URLs: textures, backdrop, css)
    s = s.replace(/data:([a-z]+\/[a-z0-9.+-]+);base64,([A-Za-z0-9+/=]{2000,})/g, (m, mime, b64) => {
      const name = h(b64) + '.' + (EXT[mime] || 'bin'); put(name, Buffer.from(b64, 'base64')); return '../../shared/' + name; });
    // the engine bundle (the largest inline script; classic, so a src= script keeps the same run order) → one shared file per distinct build
    let best = null; for (const m of s.matchAll(/<script>([\s\S]*?)<\/script>/g)) if (!best || m[1].length > best[1].length) best = m;
    if (best && best[1].length > 100000) { const name = 'e-' + h(best[1]) + '.js'; put(name, best[1]); const i = s.indexOf(best[0]); s = s.slice(0, i) + `<script src="../../shared/${name}"></script>` + s.slice(i + best[0].length); }
    mkdirSync(join(WWW, w, n), { recursive: true }); writeFileSync(join(WWW, w, n, 'index.html'), s); after += s.length; holes++;
  }
}
const du = d => readdirSync(d).reduce((a, f) => { const p = join(d, f), st = statSync(p); return a + (st.isDirectory() ? du(p) : st.size); }, 0);
console.log(`packed ${holes} holes: pages ${(before / 1e6).toFixed(0)} MB → ${(after / 1e6).toFixed(0)} MB + ${seen.size} shared files; www total ${(du(WWW) / 1e6).toFixed(0)} MB`);
