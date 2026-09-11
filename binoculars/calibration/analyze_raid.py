"""Report RAID scores per generator and test the HC3-derived threshold against them.

Usage: python3 analyze_raid.py WORKDIR
Expects WORKDIR/raid/manifest.json and WORKDIR/raid_scores.txt (binoculars --verbose).
"""
import json, re, sys, pathlib, statistics as st
from collections import defaultdict

SCRATCH = pathlib.Path(sys.argv[1])
# Refit by analyze.py on the corrected statistic; see CALIBRATION.md.
HC3_THRESHOLD = float(__import__("os").environ.get("HC3_THRESHOLD", "0.9015310749276843"))
manifest = {m["path"]: m for m in json.loads((SCRATCH / "raid" / "manifest.json").read_text())}

recs, cur = [], None
for line in (SCRATCH / "raid_scores.txt").read_text().splitlines():
    if line.startswith("==> "):
        cur = line[4:].strip()
    elif (m := re.search(r"score=([\d.]+)", line)) and cur:
        recs.append(dict(manifest[cur], score=float(m.group(1))))
    elif (m := re.search(r"(?:logPPL_performer|PPL_observer)=([\d.]+)\s+(?:logX-PPL|X-PPL)=([\d.]+)", line)) and recs:
        recs[-1]["log_ppl"], recs[-1]["log_xppl"] = float(m.group(1)), float(m.group(2))

human = [r["score"] for r in recs if r["label"] == "human"]
ai = [r["score"] for r in recs if r["label"] == "ai"]
bymodel = defaultdict(list)
for r in recs:
    bymodel[r["model"]].append(r["score"])


def auroc(pos, neg):
    w = sum((p > n) + 0.5 * (p == n) for p in pos for n in neg)
    return w / (len(pos) * len(neg))


def sweep(pos, neg):
    """Best-accuracy cutoff over midpoints between adjacent observed scores."""
    xs = sorted(set(pos + neg))
    best = None
    for t in [(a + b) / 2 for a, b in zip(xs, xs[1:])]:
        tp, tn = sum(p >= t for p in pos), sum(n < t for n in neg)
        acc = (tp + tn) / (len(pos) + len(neg))
        if best is None or acc > best[0]:
            best = (acc, t, tp / len(pos), 1 - tn / len(neg))
    return best


print(f"PER-GENERATOR SCORES  (higher = more human-like; thr={HC3_THRESHOLD:.4f})")
hdr = f"  {'model':14s} {'n':>3s} {'mean':>7s} {'sd':>6s} {'med':>7s} {'min':>7s} {'max':>7s} {'AUROC':>6s} {'caught@thr':>11s}"
print(hdr)
for model in ("human", "gpt4", "chatgpt", "llama-chat", "mistral-chat", "cohere-chat"):
    v = bymodel.get(model)
    if not v:
        continue
    if model == "human":
        tail = f" {'-':>6s} {sum(x >= HC3_THRESHOLD for x in v)/len(v):>10.0%}*"
    else:
        tail = f" {auroc(human, v):>6.4f} {sum(x < HC3_THRESHOLD for x in v)/len(v):>10.0%} "
    print(f"  {model:14s} {len(v):3d} {st.mean(v):7.4f} {st.pstdev(v):6.3f} "
          f"{st.median(v):7.4f} {min(v):7.4f} {max(v):7.4f}{tail}")
print("  * for human rows this column is correctly-kept-as-human, not caught")

print(f"\nHUMAN         n={len(human):3d}  mean={st.mean(human):.4f}  sd={st.pstdev(human):.4f}")
print(f"ALL AI POOLED n={len(ai):3d}  mean={st.mean(ai):.4f}  sd={st.pstdev(ai):.4f}")
print(f"gap = {st.mean(human)-st.mean(ai):+.4f}   AUROC = {auroc(human, ai):.4f}")

acc = (sum(h >= HC3_THRESHOLD for h in human) + sum(a < HC3_THRESHOLD for a in ai)) / (len(human)+len(ai))
print(f"\nHC3 threshold {HC3_THRESHOLD} applied to RAID -> acc={acc:.1%}")
b = sweep(human, ai)
print(f"RAID-refit threshold = {b[1]:.4f}  acc={b[0]:.1%}  human-recall={b[2]:.1%}  ai-misflagged={b[3]:.1%}")
if (g := bymodel.get("gpt4")):
    bg = sweep(human, g)
    print(f"human vs gpt4 only:  threshold={bg[1]:.4f}  acc={bg[0]:.1%}  AUROC={auroc(human,g):.4f}")

print("\nPER-DOMAIN (human vs all AI)")
dom = defaultdict(lambda: defaultdict(list))
for r in recs:
    dom[r["domain"]][r["label"]].append(r["score"])
for d, v in sorted(dom.items()):
    if v["human"] and v["ai"]:
        print(f"  {d:10s} human={st.mean(v['human']):.4f} (n={len(v['human']):2d})  "
              f"ai={st.mean(v['ai']):.4f} (n={len(v['ai']):2d})  "
              f"gap={st.mean(v['human'])-st.mean(v['ai']):+.4f}")
