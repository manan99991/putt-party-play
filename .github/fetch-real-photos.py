#!/usr/bin/env python3
"""Downloads public, labelled real-world photos for the accuracy job (never committed to the repo):

  sroie/      ICDAR 2019 SROIE shop receipts + official shop/date/total          (GitHub)
  cord/       CORD v2 receipts (Indonesian shops) + every item, price and total   (Hugging Face)
  hand/       IAM handwritten lines + their exact text                            (Hugging Face)
  web/        hand-picked hard photos (menus, posters, cards, boards) listed in
              ios/RealPhotos/web.json, with their right answers in the same file

Usage: fetch-real-photos.py <out dir> [per-set limit]
"""
import io, json, os, subprocess, sys, urllib.request

out = sys.argv[1]
limit = int(sys.argv[2]) if len(sys.argv) > 2 else 100
os.makedirs(out, exist_ok=True)
UA = {"User-Agent": "TenzyAccuracyCI/1.0 (github.com/manan99991/putt-party-play)"}


def get(url, timeout=120):
    return urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout).read()


def parquet_rows(dataset, config, split, max_rows):
    import pyarrow.parquet as pq
    urls = json.loads(get(f"https://huggingface.co/api/datasets/{dataset}/parquet/{config}/{split}"))
    rows = []
    for u in urls:
        t = pq.read_table(io.BytesIO(get(u, 600)))
        rows += t.slice(0, max_rows - len(rows)).to_pylist()
        if len(rows) >= max_rows:
            break
    return rows


def step(name, fn):
    try:
        fn(); print(f"{name}: ok")
    except Exception as e:  # one set failing never stops the others
        print(f"{name}: FAILED {e}")


def sroie():
    d = os.path.join(out, "sroie")
    if not os.path.isdir(d):
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse",
                        "https://github.com/zzzDavid/ICDAR-2019-SROIE.git", d], check=True)
    picks = []
    for i in range(0, 626, max(1, 626 // limit)):
        picks += [f"data/img/{i:03d}.jpg", f"data/key/{i:03d}.json"]
    subprocess.run(["git", "-C", d, "sparse-checkout", "set", "--no-cone"] + picks, check=True)


def cord():
    d = os.path.join(out, "cord"); os.makedirs(d, exist_ok=True)
    for i, r in enumerate(parquet_rows("naver-clova-ix/cord-v2", "default", "test", limit)):
        img = r["image"]["bytes"]
        open(os.path.join(d, f"{i:03d}.png"), "wb").write(img)
        gt = json.loads(r["ground_truth"])["gt_parse"]
        json.dump(gt, open(os.path.join(d, f"{i:03d}.json"), "w"), ensure_ascii=False)


def hand():
    d = os.path.join(out, "hand"); os.makedirs(d, exist_ok=True)
    for i, r in enumerate(parquet_rows("Teklia/IAM-line", "default", "test", limit)):
        open(os.path.join(d, f"{i:03d}.png"), "wb").write(r["image"]["bytes"])
        open(os.path.join(d, f"{i:03d}.txt"), "w").write(r["text"])


def web():
    here = os.path.dirname(os.path.abspath(__file__))
    listing = os.path.join(here, "..", "ios", "RealPhotos", "web.json")
    if not os.path.exists(listing):
        return
    d = os.path.join(out, "web"); os.makedirs(d, exist_ok=True)
    for e in json.load(open(listing)).get("photos", []):
        p = os.path.join(d, e["file"])
        if not os.path.exists(p):
            try:
                open(p, "wb").write(get(e["url"]))
            except Exception as ex:
                print("  web miss", e["file"], ex)


step("sroie", sroie)
step("cord", cord)
step("hand", hand)
step("web", web)
for s in ["sroie/data/img", "cord", "hand", "web"]:
    p = os.path.join(out, s)
    print(s, len(os.listdir(p)) if os.path.isdir(p) else 0)
