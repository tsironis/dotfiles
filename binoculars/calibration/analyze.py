"""Turn binoculars --verbose output into a calibrated threshold + separability report."""
import json, re, sys, pathlib, statistics as st
from collections import defaultdict

SCRATCH = pathlib.Path(sys.argv[1])
manifest = {m["path"]: m for m in json.loads((SCRATCH / "cal" / "manifest.json").read_text())}

# Parse the "==> path" / "score=..." / "PPL_observer=... X-PPL=..." triples.
raw = (SCRATCH / "scores.txt").read_text()
recs, cur = [], None
for line in raw.splitlines():
    if line.startswith("==> "):
        cur = line[4:].strip()
    elif (m := re.search(r"score=([\d.]+)", line)) and cur:
        recs.append(dict(manifest[cur], score=float(m.group(1))))
    elif (m := re.search(r"(?:logPPL_performer|PPL_observer)=([\d.]+)\s+(?:logX-PPL|X-PPL)=([\d.]+)", line)) and recs:
        recs[-1]["log_ppl"], recs[-1]["log_xppl"] = float(m.group(1)), float(m.group(2))

human = [r["score"] for r in recs if r["label"] == "human"]
ai = [r["score"] for r in recs if r["label"] == "ai"]

def desc(name, v):
    q = st.quantiles(v, n=4)
    print(f"  {name:6s} n={len(v):3d}  mean={st.mean(v):.4f}  sd={st.pstdev(v):.4f}  "
          f"min={min(v):.4f}  q1={q[0]:.4f}  med={q[1]:.4f}  q3={q[2]:.4f}  max={max(v):.4f}")

print("SCORE DISTRIBUTIONS  (higher = more human-like)")
desc("human", human); desc("ai", ai)
print(f"  gap between class means: {st.mean(human) - st.mean(ai):+.4f}")

# AUROC via Mann-Whitney U (probability a random human doc outscores a random AI doc).
wins = sum((h > a) + 0.5 * (h == a) for h in human for a in ai)
auroc = wins / (len(human) * len(ai))
print(f"\nAUROC = {auroc:.4f}   (0.5 = no signal, 1.0 = perfect; <0.5 means the score is inverted)")

# Sweep every midpoint between adjacent observed scores; report best accuracy and Youden J.
allscores = sorted(set(human + ai))
cands = [(a + b) / 2 for a, b in zip(allscores, allscores[1:])]
best = []
for t in cands:
    tp = sum(h >= t for h in human)      # human correctly called human
    tn = sum(a < t for a in ai)          # ai correctly called ai
    acc = (tp + tn) / (len(human) + len(ai))
    tpr, fpr = tp / len(human), 1 - tn / len(ai)
    best.append((acc, tpr - fpr, t, tpr, fpr))
by_acc = max(best, key=lambda x: x[0])
by_j = max(best, key=lambda x: x[1])
print(f"best-accuracy threshold  = {by_acc[2]:.4f}  acc={by_acc[0]:.1%}  "
      f"human-recall={by_acc[3]:.1%}  ai-misflagged={by_acc[4]:.1%}")
print(f"best-Youden-J threshold  = {by_j[2]:.4f}  acc={by_j[0]:.1%}  "
      f"human-recall={by_j[3]:.1%}  ai-misflagged={by_j[4]:.1%}")

# A conservative operating point: what cutoff keeps false accusations of humans rare?
for target in (0.01, 0.05):
    ok = [b for b in best if b[4] <= target]
    if ok:
        b = max(ok, key=lambda x: x[3])
        print(f"at <={target:.0%} AI-misflagged-as-human: threshold={b[2]:.4f}  human-recall={b[3]:.1%}")

print(f"\ncurrent default threshold 1.0 -> acc="
      f"{(sum(h>=1.0 for h in human)+sum(a<1.0 for a in ai))/(len(human)+len(ai)):.1%}")

print("\nPER-DOMAIN class means (thresholds are genre-specific)")
bydom = defaultdict(lambda: defaultdict(list))
for r in recs:
    bydom[r["domain"]][r["label"]].append(r["score"])
for dom, d in sorted(bydom.items()):
    if d["human"] and d["ai"]:
        print(f"  {dom:14s} human={st.mean(d['human']):.4f}  ai={st.mean(d['ai']):.4f}  "
              f"gap={st.mean(d['human'])-st.mean(d['ai']):+.4f}  (n={len(d['human'])} pairs)")

# Paired test: same question, so genre/topic/length are held constant.
pairs = defaultdict(dict)
for r in recs:
    pairs[r["pair"]][r["label"]] = r["score"]
full = [p for p in pairs.values() if "human" in p and "ai" in p]
correct = sum(p["human"] > p["ai"] for p in full)
print(f"\nPAIRED: human outscored its own AI twin in {correct}/{len(full)} pairs "
      f"({correct/len(full):.1%}) -- topic and length held constant")
