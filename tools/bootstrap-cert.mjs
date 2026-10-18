// One-time: mint a SINGLE shared Apple Distribution certificate for the whole account, revoking the
// old tangled ones, and create the App Store profile(s) that reference it. Outputs out/dist.p12 and
// out/profiles.json. Pure App Store Connect API — no Apple ID login, no Keychain.
import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';
import { createSign } from 'node:crypto';

const KEY_ID = process.env.ASC_KEY_ID;
const ISSUER = process.env.ASC_ISSUER_ID;
const P8 = process.env.ASC_KEY_P8;
const P12_PASS = process.env.P12_PASSWORD || 'tenzyshared';
const BUNDLES = (process.env.BUNDLE_IDS || '').split(',').map((s) => s.trim()).filter(Boolean);
const OUT = 'out', WORK = 'work';
mkdirSync(OUT, { recursive: true }); mkdirSync(WORK, { recursive: true });

const b64url = (b) => Buffer.from(b).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' }));
  const body = b64url(JSON.stringify({ iss: ISSUER, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }));
  const sig = createSign('SHA256').update(`${head}.${body}`).sign({ key: P8, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${b64url(sig)}`;
}
const TOKEN = jwt();
const BASE = 'https://api.appstoreconnect.apple.com';
async function api(method, path, body) {
  const r = await fetch(BASE + path, { method, headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const text = await r.text();
  let json; try { json = JSON.parse(text); } catch { json = text; }
  if (r.status >= 400) throw new Error(`${method} ${path} -> ${r.status} ${text}`);
  return json;
}
async function all(path) { let out = [], next = path; while (next) { const d = await api('GET', next); out = out.concat(d.data || []); next = d.links?.next?.replace(BASE, '') || null; } return out; }

// 1. Revoke every existing distribution certificate — clean slate.
const certs = await all('/v1/certificates?limit=200');
for (const c of certs) {
  const t = c.attributes.certificateType || '';
  if (t.includes('DISTRIBUTION')) { await api('DELETE', `/v1/certificates/${c.id}`); console.log('revoked', c.id, t); }
}

// 2. Private key + CSR + ONE new Apple Distribution certificate.
execFileSync('openssl', ['genrsa', '-out', `${WORK}/key.pem`, '2048']);
const csr = execFileSync('openssl', ['req', '-new', '-key', `${WORK}/key.pem`, '-subj', '/CN=Tenzy Reckato Shared Distribution/O=Manan Shah/C=US']).toString();
const csrBody = csr.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
const made = await api('POST', '/v1/certificates', { data: { type: 'certificates', attributes: { certificateType: 'DISTRIBUTION', csrContent: csrBody } } });
const certId = made.data.id;
writeFileSync(`${WORK}/cert.der`, Buffer.from(made.data.attributes.certificateContent, 'base64'));
execFileSync('openssl', ['x509', '-inform', 'DER', '-in', `${WORK}/cert.der`, '-out', `${WORK}/cert.pem`]);
execFileSync('openssl', ['pkcs12', '-export', '-inkey', `${WORK}/key.pem`, '-in', `${WORK}/cert.pem`, '-out', `${OUT}/dist.p12`, '-passout', `pass:${P12_PASS}`, '-legacy', '-name', 'Tenzy Reckato Shared Distribution']);
console.log('created cert', certId, 'expires', made.data.attributes.expirationDate);

// 3. One App Store provisioning profile per bundle id, referencing the new cert.
const profiles = {};
for (const bid of BUNDLES) {
  const bres = await api('GET', `/v1/bundleIds?filter[identifier]=${encodeURIComponent(bid)}&limit=1`);
  const bundle = (bres.data || [])[0];
  if (!bundle) { console.log('MISSING bundle id', bid); continue; }
  const name = `Shared AppStore ${bid}`;
  const existing = await all('/v1/profiles?filter[profileType]=IOS_APP_STORE&limit=200');
  for (const p of existing.filter((p) => p.attributes.name === name)) { await api('DELETE', `/v1/profiles/${p.id}`); }
  const prof = await api('POST', '/v1/profiles', { data: { type: 'profiles', attributes: { name, profileType: 'IOS_APP_STORE' },
    relationships: { bundleId: { data: { type: 'bundleIds', id: bundle.id } }, certificates: { data: [{ type: 'certificates', id: certId }] } } } });
  profiles[bid] = { uuid: prof.data.attributes.uuid, name, content: prof.data.attributes.profileContent };
  console.log('profile', bid, prof.data.attributes.uuid);
}
writeFileSync(`${OUT}/profiles.json`, JSON.stringify(profiles, null, 2));
console.log('DONE');
