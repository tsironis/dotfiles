# binoculars

Local AI-generated-text detector using the [Binoculars method](https://arxiv.org/abs/2401.12070)
(Hans et al., 2024), run via [MLX](https://github.com/ml-explore/mlx) on Apple Silicon.

## How it works

Binoculars scores text using two same-family language models: a "performer" and an
"observer". It computes:

- `PPL_observer`: the observer model's own perplexity on the text.
- `X-PPL`: the cross-perplexity between the observer's and performer's next-token
  distributions.
- `score = PPL_observer / X-PPL`

Lower scores tend to indicate more machine-like text, higher scores more human-like text.
Only a single forward pass per model is needed — no text generation.

## Default model pair

**Qwen2.5-7B / Qwen2.5-7B-Instruct** (via pre-quantized `mlx-community` 4-bit repos,
~4.5GB combined). The original paper used Falcon-7B/Falcon-7B-Instruct with a published,
empirically-calibrated threshold (~0.9015) — but that pair isn't usable here: `mlx-lm`
doesn't implement the original Falcon architecture, and no `mlx-community` quantized
Falcon-7B repos exist. Qwen2.5-7B is the closest well-supported same-scale substitute.

**There is no validated threshold.** The paper's ~0.9015 cutoff only applies to their exact
Falcon checkpoints; it would be meaningless applied to a different model pair. By default
the tool falls back to a naive `score >= 1.0` cutoff (the point where the two models
roughly agree) just to give a plain verdict out of the box, and always labels that verdict
as unvalidated. Calibrate your own cutoff (below) before trusting it for anything real.

## Calibrating a threshold

Score a handful of text samples you know are human-written and a handful you know are
AI-generated (similar length/genre to what you actually want to check). Look at the two
score clusters and pick a cutoff between them, e.g.:

```
binoculars --verbose known-human-1.md known-human-2.md known-ai-1.md known-ai-2.md
```

`--verbose` shows the raw `PPL_observer`/`X-PPL` numbers behind each score, useful while
you're picking a cutoff. Once you have a threshold you trust, pass it explicitly with
`--threshold` — the "unvalidated default" caveat only appears when relying on the built-in
`1.0` fallback.

## Usage

```
binoculars essay.md
binoculars essay.md other.md
binoculars --threshold 1.15 essay.md
binoculars --verbose essay.md
cat essay.md | binoculars
binoculars --performer mlx-community/Meta-Llama-3.1-8B-Instruct-4bit \
           --observer mlx-community/Meta-Llama-3.1-8B-4bit essay.md
```

`--performer`/`--observer` accept any HF repo id, so a different model family or size can
be tried without touching the code — just note that any pair other than the checked
default has no prior art on what a good threshold looks like.

## Requirements

- Apple Silicon only. `mlx`/`mlx-lm` don't run under x86 (including Rosetta emulation).
- First run downloads the model pair from Hugging Face (a few GB for the default pair)
  into `~/.cache/huggingface`; this is a one-time cost per model pair.
