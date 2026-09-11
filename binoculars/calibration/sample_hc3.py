"""Draw a paired, length-matched calibration sample from HC3."""
import json, random, pathlib, re, sys

SCRATCH = pathlib.Path(sys.argv[1])
DOMAINS = ["wiki_csai", "open_qa", "medicine", "finance", "reddit_eli5"]
TARGET = 50
MIN_WORDS, MAX_WORDS = 150, 700
random.seed(20260903)

def clean(t):
    t = re.sub(r"URL_\d+", "", t)          # HC3 reddit URL placeholders
    t = re.sub(r"\[\s*removed\s*\]", "", t, flags=re.I)
    t = re.sub(r"\s+", " ", t).strip()
    return t

pools = {}
for dom in DOMAINS:
    rows = []
    for line in (SCRATCH / "hc3" / f"{dom}.jsonl").read_text(errors="ignore").splitlines():
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue                        # truncated tail of a ranged download
        if not d.get("human_answers") or not d.get("chatgpt_answers"):
            continue
        h, a = clean(d["human_answers"][0]), clean(d["chatgpt_answers"][0])
        # Keep only pairs where BOTH sides clear the length bar, so the human/AI
        # score gap can't be an artifact of one class being systematically shorter.
        if all(MIN_WORDS <= len(t.split()) <= MAX_WORDS for t in (h, a)):
            rows.append((d["question"], h, a))
    random.shuffle(rows)
    pools[dom] = rows
    print(f"{dom:14s} eligible={len(rows):5d}")

# Round-robin across domains so a domain with few eligible pairs (open_qa) doesn't
# cap the sample, and the remaining slots spread evenly rather than piling on one domain.
manifest = []
picked, i = [], 0
while len(picked) < TARGET and any(len(pools[d]) > i for d in DOMAINS):
    for dom in DOMAINS:
        if len(pools[dom]) > i and len(picked) < TARGET:
            picked.append((dom, i, pools[dom][i]))
    i += 1

for dom, i, (q, h, a) in picked:
    for label, text in (("human", h), ("ai", a)):
        p = SCRATCH / "cal" / label / f"{dom}_{i:02d}.txt"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text + "\n")
        manifest.append({"path": str(p), "label": label, "domain": dom,
                         "pair": f"{dom}_{i:02d}", "words": len(text.split())})

from collections import Counter
print("\nper-domain:", dict(Counter(d for d, _, _ in picked)))

(SCRATCH / "cal" / "manifest.json").write_text(json.dumps(manifest, indent=2))
n_h = sum(1 for m in manifest if m["label"] == "human")
print(f"\ntotal: {n_h} human + {len(manifest)-n_h} ai")
