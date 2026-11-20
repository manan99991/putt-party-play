#!/usr/bin/env python3
"""Fetch TestFlight crash reports for Tenzy from the App Store Connect API.

Writes into OUT_DIR:
  feedback/<id>.json + <id>.crash  — crashes a tester shared (the "Share" button on the crash alert)
  signatures.json                  — Apple's collected crash signatures for the newest builds
  summary.txt                      — counts and dates only (safe to publish in the clear)
"""
import base64, json, os, sys, time
import jwt, requests

BUNDLE = "com.tenzy.toolkit"
API = "https://api.appstoreconnect.apple.com"
out = sys.argv[1]
os.makedirs(os.path.join(out, "feedback"), exist_ok=True)

key = base64.b64decode(os.environ["ASC_KEY_P8_B64"]).decode()
token = jwt.encode(
    {"iss": os.environ["ASC_ISSUER_ID"], "iat": int(time.time()), "exp": int(time.time()) + 1100,
     "aud": "appstoreconnect-v1"},
    key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})
H = {"Authorization": f"Bearer {token}"}


def get(path, **params):
    r = requests.get(API + path, headers=H, params=params, timeout=60)
    if r.status_code >= 400:
        print(f"{path} -> {r.status_code}: {r.text[:300]}")
        return None
    return r.json()


summary = []
apps = get("/v1/apps", **{"filter[bundleId]": BUNDLE})
if not apps or not apps["data"]:
    print("app not found"); sys.exit(1)
app_id = apps["data"][0]["id"]

# 1. Crashes testers shared, newest first.
fb = get(f"/v1/apps/{app_id}/betaFeedbackCrashSubmissions", sort="-createdDate", limit=20) or {"data": []}
for item in fb["data"]:
    a = item["attributes"]
    fid = item["id"]
    meta = {k: a.get(k) for k in ("createdDate", "comment", "deviceModel", "osVersion", "appPlatform",
                                   "deviceFamily", "buildBundleId", "locale", "batteryPercentage",
                                   "connectionType", "appUptimeInMilliseconds")}
    build = get(f"/v1/betaFeedbackCrashSubmissions/{fid}/build")
    if build and build.get("data"):
        meta["build"] = build["data"]["attributes"].get("version")
    log = get(f"/v1/betaFeedbackCrashSubmissions/{fid}/crashLog")
    text = (log or {}).get("data", {}).get("attributes", {}).get("logText") or ""
    json.dump(meta, open(os.path.join(out, "feedback", f"{fid}.json"), "w"), indent=1)
    open(os.path.join(out, "feedback", f"{fid}.crash"), "w").write(text)
    summary.append(f"shared crash {meta['createdDate']} build {meta.get('build')} log {len(text)} chars")

# 2. Crash signatures Apple collected from the newest builds (no tester action needed).
sigs = []
builds = get("/v1/builds", **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": 3}) or {"data": []}
for b in builds["data"]:
    ver = b["attributes"].get("version")
    ds = get(f"/v1/builds/{b['id']}/diagnosticSignatures", **{"filter[diagnosticType]": "CRASHES"}) or {"data": []}
    for s in ds["data"]:
        entry = {"build": ver, "id": s["id"], **s["attributes"]}
        logs = get(f"/v1/diagnosticSignatures/{s['id']}/logs")
        if logs:
            entry["logs"] = logs
        sigs.append(entry)
    summary.append(f"build {ver}: {len(ds['data'])} crash signatures")
json.dump(sigs, open(os.path.join(out, "signatures.json"), "w"), indent=1)

summary.insert(0, f"fetched {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}: {len(fb['data'])} shared crashes")
open(os.path.join(out, "summary.txt"), "w").write("\n".join(summary) + "\n")
print("\n".join(summary))
