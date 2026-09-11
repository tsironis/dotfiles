"""Draw a length-matched RAID calibration sample without downloading the 11.8GB CSV.

Usage: python3 sample_raid.py WORKDIR

RAID-test ships unlabeled, so calibration has to come from RAID-train. Two obvious routes
do not work: the datasets-server `filter` index never finishes building for a dataset this
large, and the `rows` endpoint rate-limits (HTTP 429) long before enough rows can be
probed anonymously. So this reads targeted byte ranges of train.csv off the CDN and
resyncs each window to a record boundary.

train.csv is ordered by DOMAIN, with the human rows sitting at the head of each domain
block and the model x attack variants filling the rest. Evenly spaced windows therefore
miss human rows entirely, so two offset sets are unioned: windows at each domain block
head to reach human, and a plain even spread to reach model blocks the first set skips.

Only non-adversarial rows are kept. RAID carries 12 evasion attacks; how the threshold
survives those is a separate question. Poetry and code are excluded as non-prose, and the
same 150-700 word window as the HC3 run is used so the two calibrations are comparable.

The parsed pool is cached to WORKDIR/raid_pool.jsonl, so re-slicing to different domains
or quotas afterwards costs no further downloading.
"""
import csv, io, json, random, re, sys, pathlib, urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor

SCRATCH = pathlib.Path(sys.argv[1])
OUT = SCRATCH / "raid"
CACHE = SCRATCH / "raid_pool.jsonl"
URL = "https://huggingface.co/datasets/liamdugan/raid/resolve/main/train.csv"
SIZE = 11_779_500_000
COLUMNS = ["id", "adv_source_id", "source_id", "model", "decoding", "repetition_penalty",
           "attack", "domain", "title", "prompt", "generation"]

# Block boundaries as fractions of the file, read off a 120-probe layout scan.
DOMAIN_SPANS = {
    "abstracts": (0.000, 0.125), "books": (0.125, 0.267), "news": (0.267, 0.417),
    "recipes": (0.508, 0.633), "reddit": (0.633, 0.758), "reviews": (0.758, 0.817),
    "wiki": (0.817, 1.000),
}
MIN_WORDS, MAX_WORDS = 150, 700
# 50 human vs 50 gpt4 sets the primary threshold; the smaller groups test whether that
# number travels across model families.
QUOTAS = {"human": 50, "gpt4": 50, "chatgpt": 10,
          "llama-chat": 10, "mistral-chat": 10, "cohere-chat": 10}
WINDOW = 8 << 20
HEAD_WINDOWS, BODY_WINDOWS, EVEN_WINDOWS = 2, 3, 40
UUID = r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
BOUNDARY = re.compile(rf"\n(?={UUID},)".encode())
random.seed(20260903)


def window(start):
    req = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{start+WINDOW-1}"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except Exception:
            if attempt == 3:
                return b""
    return b""


def records(buf):
    """Yield dict rows from a mid-file byte window."""
    m = BOUNDARY.search(buf)
    if not m:
        return
    buf = buf[m.end():]
    cuts = list(BOUNDARY.finditer(buf))
    if cuts:
        buf = buf[:cuts[-1].start()]        # drop the half-record the window cut
    for row in csv.reader(io.StringIO(buf.decode("utf-8", errors="replace"))):
        if len(row) == len(COLUMNS):
            yield dict(zip(COLUMNS, row))


def build_pool():
    starts = []
    for lo, hi in DOMAIN_SPANS.values():
        base = int(lo * SIZE)
        starts += [base + i * WINDOW for i in range(HEAD_WINDOWS)]      # human lives here
        span = int((hi - lo) * SIZE)
        starts += [base + int((i + 1) * span / (BODY_WINDOWS + 1)) for i in range(BODY_WINDOWS)]
    starts += [int((i + 0.5) * SIZE / EVEN_WINDOWS) for i in range(EVEN_WINDOWS)]
    starts = sorted(set(starts))

    print(f"fetching {len(starts)} x {WINDOW>>20}MB windows...")
    with ThreadPoolExecutor(max_workers=6) as ex:
        bufs = list(ex.map(window, starts))
    print(f"got {sum(len(b) for b in bufs) >> 20}MB")

    pool, stats, seen = defaultdict(list), Counter(), set()
    with CACHE.open("w") as fh:
        for buf in bufs:
            for r in records(buf):
                stats["rows"] += 1
                if r["attack"] != "none" or r["domain"] not in DOMAIN_SPANS:
                    continue
                stats["non_adversarial_prose"] += 1
                text = r["generation"].strip()
                if not (MIN_WORDS <= len(text.split()) <= MAX_WORDS):
                    continue
                if r["id"] in seen:         # windows overlap at a block head
                    continue
                seen.add(r["id"])
                stats["eligible"] += 1
                r["generation"] = text
                pool[r["model"]].append(r)
                fh.write(json.dumps(r) + "\n")
    print("parsed:", dict(stats))
    return pool


if CACHE.exists():
    print(f"reusing cached pool at {CACHE}")
    pool = defaultdict(list)
    for line in CACHE.read_text().splitlines():
        d = json.loads(line)
        pool[d["model"]].append(d)
else:
    SCRATCH.mkdir(parents=True, exist_ok=True)
    pool = build_pool()

print("eligible by model:", {k: len(v) for k, v in sorted(pool.items())})

# Restrict to domains where human AND every target generator all have coverage, so the
# comparison is like-for-like instead of contrasting human abstracts against AI recipes.
human_doms = Counter(r["domain"] for r in pool.get("human", []))
matched = {d for d, n in human_doms.items() if n >= 20}
for model in QUOTAS:
    if model != "human":
        matched &= {r["domain"] for r in pool.get(model, [])}
print("human coverage by domain:", dict(human_doms))
print("matched domains used:", sorted(matched))
for model in list(pool):
    pool[model] = [r for r in pool[model] if r["domain"] in matched]

manifest = []
for model, quota in QUOTAS.items():
    cand = pool.get(model, [])[:]
    random.shuffle(cand)
    kept, dom_count = [], Counter()
    cap = -(-quota // max(1, len(matched))) + 3     # loose per-domain cap, keeps a spread
    for r in cand:
        if len(kept) >= quota:
            break
        if dom_count[r["domain"]] >= cap:
            continue
        dom_count[r["domain"]] += 1
        kept.append(r)

    subdir = OUT / model
    subdir.mkdir(parents=True, exist_ok=True)
    for i, r in enumerate(kept):
        p = subdir / f"{r['domain']}_{i:02d}.txt"
        p.write_text(r["generation"] + "\n")
        manifest.append({"path": str(p), "label": "human" if model == "human" else "ai",
                         "model": model, "domain": r["domain"],
                         "decoding": r["decoding"], "rep_penalty": r["repetition_penalty"],
                         "words": len(r["generation"].split())})
    print(f"{model:14s} kept={len(kept):3d}/{quota}  {dict(dom_count)}")

(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2))
print("\ntotal:", dict(Counter(m["label"] for m in manifest)))
