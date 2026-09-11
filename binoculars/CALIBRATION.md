# Calibration

Calibration runs for the default Qwen2.5-7B / Qwen2.5-7B-Instruct pair against
known-provenance benchmarks. Date: 2026-09-03.

## Verdict

**Keep the naive `1.0` default. Do not ship a calibrated threshold.**

Two runs and one direct test say the same thing from three directions. On bland
explanatory prose with a 2022-era generator the score works well, AUROC 0.85, and a fitted
cutoff of 1.1881 reaches 89% accuracy. That number then fails to transfer anywhere it
matters. Against GPT-4 news it collapses to an AUROC of 0.6798, barely above chance, and
against dense technical prose it misfires so badly that it called this very file
human-written.

What the detector actually recognizes is a bland, predictable explanatory register. That
register is a property of older chat models on generic questions, not of machine authorship
as such. Any single global threshold shipped as a default would carry a false air of
validation.

| Run | Human vs | AUROC | Fitted cutoff | Verdict |
|---|---|---|---|---|
| HC3, 5 domains | ChatGPT-3.5 | 0.8522 | 1.1881 (89%) | works |
| RAID, news | ChatGPT-3.5 | 0.9620 | - | works, replicates HC3 |
| RAID, news | GPT-4 | 0.6798 | none useful | fails |
| This repo's docs | machine-written | - | - | fails, false negatives |

## Reproducing

Both samplers are seeded (`20260903`), so each returns the same documents. `WORK` is any
scratch directory.

```sh
# Run 1: HC3
mkdir -p "$WORK/hc3"
for f in wiki_csai open_qa medicine finance reddit_eli5; do
  curl -sL -o "$WORK/hc3/$f.jsonl" \
    "https://huggingface.co/datasets/Hello-SimpleAI/HC3/resolve/main/$f.jsonl"
done
python3 calibration/sample_hc3.py "$WORK"            # writes cal/{human,ai}/ + manifest.json
binoculars --verbose "$WORK"/cal/human/*.txt "$WORK"/cal/ai/*.txt > "$WORK/scores.txt"
python3 calibration/analyze.py "$WORK"               # reads manifest.json + scores.txt

# Run 2: RAID (downloads ~592MB of byte ranges, caches the parsed pool)
python3 calibration/sample_raid.py "$WORK"           # writes raid/<model>/ + manifest.json
binoculars --verbose "$WORK"/raid/human/*.txt "$WORK"/raid/gpt4/*.txt > "$WORK/raid_a.txt"
binoculars --verbose "$WORK"/raid/{chatgpt,llama-chat,mistral-chat,cohere-chat}/*.txt \
  > "$WORK/raid_b.txt"
cat "$WORK"/raid_a.txt "$WORK"/raid_b.txt > "$WORK/raid_scores.txt"
python3 calibration/analyze_raid.py "$WORK"
```

Score the RAID set in two batches. All 140 documents in one invocation takes about eleven
minutes, which overruns some task timeouts; the split is roughly eight plus three.

Archived raw output lives in `calibration/`: `hc3-50pairs-scores.txt`,
`raid-news-140-scores.txt`, and the matching manifests. Their absolute paths point at
scratch directories that no longer exist, which matters only if you feed them back to an
analyze script directly rather than regenerating.

## Run 1: HC3, 50 pairs

### Dataset

[HC3](https://huggingface.co/datasets/Hello-SimpleAI/HC3) (Human ChatGPT Comparison
Corpus), chosen because it is *paired*: each record is one question answered both by a
human and by ChatGPT. Sampling pairs rather than two independent pools holds topic and
genre constant so only authorship varies.

50 pairs (50 human + 50 AI documents), seeded and reproducible:

- Both sides of a pair required to be 150-700 words, so the two classes have aligned
  length distributions and no score gap can be a length artifact.
- Domain mix: wiki_csai 13, medicine 12, finance 12, reddit_eli5 12, open_qa 1.
  open_qa contributes almost nothing because its answers are nearly all too short.
- Reddit `URL_n` placeholders and `[removed]` markers stripped.

### Results

```
             n     mean      sd      min      q1     med      q3     max
  human     50   1.4380   0.327   0.8173  1.2323  1.4638  1.7546  1.9568
  ai        50   1.0287   0.108   0.7081  0.9670  1.0435  1.1044  1.2548

  AUROC                      0.8522
  default threshold 1.0      60.0% accuracy
  calibrated     1.1881      89.0% accuracy  (human-recall 82%, AI-misflagged 4%)
  conservative   1.2599      human-recall 68%, AI-misflagged 1%
  paired ordering            44/50 (88%) human outscored its own AI twin
```

The score direction is correct, higher meaning more human-like, and AUROC of 0.85 is a
clear signal. The `1.0` default scores 60% on balanced data, close to useless; moving the
cutoff to 1.19 reaches 89%. The README's existing warning about the unvalidated default
was justified.

### What the distributions actually show

The shape matters more than the headline accuracy. AI scores cluster tightly, sd 0.108
with a maximum of 1.2548, while human scores sprawl from 0.82 to 1.96 with three times the
spread. The detector does not recognize human writing, it recognizes that machine text
lands in a narrow band just above 1.0. That asymmetry explains why the conservative
threshold costs so much human recall: the only way to stop misflagging AI is to push the
cutoff up into the crowded middle of the human distribution.

### Per-domain gaps, and a confound

```
  medicine       human=1.6587  ai=1.0543  gap=+0.6044
  reddit_eli5    human=1.5408  ai=0.9842  gap=+0.5566
  finance        human=1.5498  ai=1.1126  gap=+0.4372
  wiki_csai      human=1.0839  ai=0.9737  gap=+0.1102
  open_qa        human=0.8173  ai=0.9649  gap=-0.1476  (n=1, ignore)
```

HC3's human answers in wiki_csai are lifted from Wikipedia, which sits heavily in
Qwen2.5's pretraining data, so the observer finds that human text almost as unsurprising
as generated text and the gap nearly vanishes. Genuinely human writing the model has
memorized scores like a machine wrote it. Messier, less canonical prose (Reddit, medical)
separates two to five times better. Any per-genre threshold has to account for how
familiar the observer model is with that genre.

## Run 2: RAID news, 140 documents

### Dataset

[RAID](https://huggingface.co/datasets/liamdugan/raid) (Dugan et al., 2024), the reference
AI-detection benchmark: 11 generators, 11 domains, 12 adversarial attacks. Chosen to answer
one question the HC3 run could not, namely how far the 1.1881 cutoff falls against modern
generators rather than ChatGPT-3.5.

RAID-test ships unlabeled, so the sample comes from RAID-train. Getting at it took some
work, recorded here because two obvious routes fail:

- The datasets-server `filter` index never finishes building for an 11.8GB dataset.
- The `rows` endpoint rate-limits (HTTP 429) long before enough rows can be probed
  anonymously.
- What works is ranged byte reads of `train.csv` off the CDN, resynced to record
  boundaries. `train.csv` is ordered by **domain**, with human rows at the head of each
  domain block and the model-by-attack variants filling the rest, so evenly spaced windows
  miss human rows entirely. The sampler unions windows at each block head with an even
  spread. 592MB of windows yields 34,768 eligible rows.

The sample is 50 human, 50 gpt4, and 10 each of chatgpt, llama-chat, mistral-chat and
cohere-chat. All rows are non-adversarial and all are **news**, the only domain where human
and every target generator had coverage in the same windows. One matched genre is a
stricter comparison than mixing genres unevenly across classes. Same 150-700 word window as
Run 1; median lengths land within 7% across classes, so nothing here is a length artifact.

### Results

```
  model            n    mean     sd     med     min     max   AUROC  caught@1.1881
  human           50  1.2753  0.132  1.2776  1.0080  1.5675       -          72%*
  gpt4            50  1.1544  0.197  1.1418  0.8378  1.4968  0.6798          56%
  mistral-chat    10  1.0479  0.276  0.9420  0.7968  1.6061  0.7560          70%
  cohere-chat     10  1.0349  0.132  0.9844  0.8469  1.2843  0.8940          80%
  llama-chat      10  1.0257  0.124  0.9677  0.8986  1.3173  0.9040          90%
  chatgpt         10  1.0075  0.101  1.0202  0.8330  1.1288  0.9620         100%
  * for human rows this column is correctly-kept-as-human, not caught

  pooled AUROC                  0.7683   (HC3 was 0.8522)
  HC3 threshold 1.1881 on RAID  70.0% accuracy
  RAID-refit 1.1186             72.1% accuracy, but 38.9% of AI misflagged as human
  human vs gpt4 only            AUROC 0.6798, best cutoff 1.0813 at 70.0%
```

### Detectability tracks generator quality

The per-generator ordering is the whole result. ChatGPT is caught every time at an AUROC of
0.962, the open chat models sit between 0.76 and 0.90, and GPT-4 falls to 0.6798 with only
56% caught. Refitting to RAID does not rescue it: the best available cutoff of 1.1186 buys
72% accuracy only by waving through 39% of the AI text. No operating point on this data is
both useful and honest for GPT-4 output.

One cross-dataset check says the pipeline is sound rather than broken. ChatGPT scored a mean
of 1.0075 here against 1.0287 on HC3, essentially identical across two independently built
datasets and two different sampling paths. The same generator lands in the same place, so
the collapse against GPT-4 is a property of the generator and not of the sampling.

The human side moved for a separate reason. Human mean fell from 1.4380 on HC3 to 1.2753 on
RAID news, because HC3's human text is casual Reddit and forum prose while RAID's is
professionally edited Reuters and BBC copy. Edited news is more predictable to the observer
model, so it scores closer to machine text, and the HC3 threshold misflags 28% of genuine
human news as machine-written.

## Known failure mode: dense technical prose

The calibrated threshold applies to flowing explanatory prose and nothing else. Pointed at
technical documentation it fails completely, in the permissive direction.

Tested on two documents with certain rather than assumed provenance: this repo's
`README.md` and this very file, both machine-written.

```
                          score   PPL_observer   X-PPL   verdict @ 1.1881
  README.md              1.3628         8.9496  6.5672   likely human-written
  CALIBRATION.md         1.3424         9.2946  6.9237   likely human-written
  README.md, prose only  1.7159        15.2697  8.8992   likely human-written
  CALIBRATION.md, ditto  1.7917        24.2048 13.5091   likely human-written
```

Both are false negatives. Stripping the markdown and fenced code blocks made the scores
*worse*, 1.36 to 1.72 and 1.34 to 1.79, because code blocks are highly predictable text
whose removal takes out the low-perplexity ballast and leaves only dense technical prose.
`PPL_observer` climbs to five or ten times the HC3 range (2-3).

That is the underlying problem. The score measures surprisal, so it reads specificity as
humanness. Content like `mlx-community` repo ids, the 0.9015 figure, or an AUROC of 0.8522
is unguessable, which drives the numerator up. HC3's ChatGPT answers score low because
2022-era chat output is bland and generic, sitting close to the model's expected next
token. Machine text that is dense, numeric and specific passes straight through the cutoff.

Two consequences. The threshold is not merely miscalibrated for markdown, it is measuring
the wrong property for this class of document, so never point it at technical writing.
And "AI-generated" is not one class: what the detector actually picks up is a bland
explanatory register that current models drop whenever the content is information-dense.

## Caveats

- HC3's AI side is ChatGPT-3.5 from December 2022, which the RAID run confirms is the easy
  case. **1.1881 is an optimistic ceiling, not a shippable number.**
- 50 documents per class carries a few points of noise; the 10-document per-generator
  groups in Run 2 are indicative only, and `mistral-chat`'s sd of 0.276 shows it.
- Run 2 covers one genre (news) and one domain of RAID's eleven. Run 1 covers five HC3
  domains. Nothing here validates any threshold beyond those.
- Neither run touches RAID's 12 adversarial attacks. Everything above is the
  non-adversarial, un-evaded case, so treat these figures as the detector's best showing.
- RAID's newest generator is GPT-4. Nothing here measures models more recent than that,
  and the trend across generator quality gives no reason for optimism.

## Next steps

- Score RAID's adversarial rows. The non-adversarial numbers are already weak against
  GPT-4, so this mostly establishes how much worse evasion makes it.
- Re-slice the cached pool (`raid_pool.jsonl`) to RAID's other domains. Human rows only
  survive at domain block heads, so reaching abstracts, books, reviews and wiki needs
  head windows for those blocks, which the sampler already fetches.
- Build a technical-writing calibration set (docs, READMEs, commit messages) with known
  authorship on both sides. The failure mode above means one global threshold cannot serve
  both registers, so this genre needs its own number or an explicit refusal to score.
- Leave the `1.0` default in `binoculars.py` alone. If a threshold is ever shipped it
  should be a per-genre value the caller picks, with the GPT-4 result stated plainly.
