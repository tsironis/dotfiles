#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["mlx-lm"]
# ///
#
# Binoculars AI-text detector (Hans et al., 2024), run locally via MLX on Apple Silicon.
# Scores text as log-PPL_performer(text) / log-X-PPL(text): the performer model's mean
# next-token NLL on the actual text, divided by the cross-entropy between the observer's
# and the performer's predicted distributions. Both terms are mean NLLs (log
# perplexities), and the score is their ratio -- see score_text() for why that detail
# matters. Lower scores tend to mean more machine-like text, higher scores more
# human-like — but there is no built-in threshold (see README.md for why and how to
# calibrate one for your model pair). Apple Silicon only: mlx/mlx-lm don't run under x86.
#
#   binoculars essay.md
#   binoculars essay.md other.md
#   binoculars --threshold 0.92 essay.md
#   binoculars --verbose essay.md
#   binoculars --performer mlx-community/Meta-Llama-3.1-8B-Instruct-4bit \
#              --observer mlx-community/Meta-Llama-3.1-8B-4bit essay.md
#   cat essay.md | binoculars
"""Score text for likely AI generation using the Binoculars method."""

import argparse
import pathlib
import sys

import mlx.core as mx
import mlx.nn as nn
from mlx_lm import load

DEFAULT_PERFORMER = "mlx-community/Qwen2.5-7B-Instruct-4bit"
DEFAULT_OBSERVER = "mlx-community/Qwen2.5-7B-4bit"
# Published thresholds from Hans et al., calibrated on their exact Falcon-7B /
# Falcon-7B-Instruct checkpoints. Now that the score matches the paper's statistic these
# are on the right scale, but they are still model-pair specific: treat them as a starting
# point for a different pair, not a validated cutoff. See CALIBRATION.md.
PAPER_ACCURACY_THRESHOLD = 0.9015310749276843
PAPER_LOW_FPR_THRESHOLD = 0.8536432310785527
DEFAULT_THRESHOLD = PAPER_ACCURACY_THRESHOLD


def sequence_logprobs(model, tokens):
    logits = model(tokens).astype(mx.float32)
    return nn.log_softmax(logits, axis=-1)


def score_text(text, performer_model, observer_model, tokenizer):
    ids = tokenizer.encode(text)
    if len(ids) < 2:
        print("error: text is too short to score (need at least 2 tokens)", file=sys.stderr)
        sys.exit(1)
    tokens = mx.array(ids)[None, :]

    observer_logp = sequence_logprobs(observer_model, tokens)
    performer_logp = sequence_logprobs(performer_model, tokens)

    # Exclude the first token: there's no preceding context to have predicted it.
    shifted_observer_logp = observer_logp[:, :-1, :]
    shifted_performer_logp = performer_logp[:, :-1, :]
    targets = tokens[:, 1:]

    # Numerator: the PERFORMER's mean next-token NLL against the actual continuation.
    # (Reference implementation: ppl = perplexity(encodings, performer_logits).)
    performer_token_logp = mx.take_along_axis(shifted_performer_logp, targets[..., None], axis=-1)[..., 0]
    performer_nll = -performer_token_logp.mean()

    # Denominator: cross-entropy H(observer, performer) -- probabilities come from the
    # OBSERVER, log-probabilities from the performer. Cross-entropy is not symmetric, so
    # the order matters. (Reference: entropy(observer_logits, performer_logits, ...).)
    observer_p = mx.exp(shifted_observer_logp)
    cross_nll = -(observer_p * shifted_performer_logp).sum(axis=-1).mean()

    # The score is the ratio of the two mean NLLs, i.e. of the two LOG perplexities. Do
    # not exponentiate first: exp(a)/exp(b) is exp(a-b), a different statistic on a
    # different scale, and the paper's published thresholds would not apply to it.
    log_ppl = performer_nll.item()
    log_x_ppl = cross_nll.item()
    return log_ppl, log_x_ppl, log_ppl / log_x_ppl


def main():
    parser = argparse.ArgumentParser(
        description="Score text for likely AI generation using the Binoculars method (local, via MLX)."
    )
    parser.add_argument("files", nargs="*", help="text file(s) to score (reads stdin if omitted)")
    parser.add_argument(
        "--performer", default=DEFAULT_PERFORMER, help="performer model (HF repo id)"
    )
    parser.add_argument(
        "--observer", default=DEFAULT_OBSERVER, help="observer model (HF repo id)"
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=None,
        help=f"verdict cutoff, score>=threshold is human-like (default: {DEFAULT_THRESHOLD:.4f}, "
        "the paper's Falcon-calibrated value -- unvalidated for any other model pair, "
        "see CALIBRATION.md for how to calibrate your own)",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="also print the raw log-PPL/log-X-PPL numbers behind the score",
    )
    args = parser.parse_args()
    is_default_threshold = args.threshold is None
    threshold = args.threshold if args.threshold is not None else DEFAULT_THRESHOLD

    if sys.platform != "darwin" or mx.default_device().type != mx.DeviceType.gpu:
        print(
            "warning: MLX runs best on Apple Silicon with GPU acceleration; "
            "this may be slow or unsupported on this machine",
            file=sys.stderr,
        )

    print(f"loading performer ({args.performer}) and observer ({args.observer})...", file=sys.stderr)
    performer_model, _ = load(args.performer)
    observer_model, tokenizer = load(args.observer)

    if args.files:
        inputs = [(path, pathlib.Path(path).read_text()) for path in args.files]
    else:
        inputs = [("<stdin>", sys.stdin.read())]

    multi = len(inputs) > 1
    for path, text in inputs:
        if multi:
            print(f"==> {path}")
        log_ppl, log_x_ppl, score = score_text(text, performer_model, observer_model, tokenizer)
        verdict = "likely human-written" if score >= threshold else "likely machine-generated"
        line = f"{verdict} (score={score:.4f}, threshold={threshold})"
        if is_default_threshold:
            line += " -- paper's Falcon threshold, unvalidated for this pair (see CALIBRATION.md)"
        print(line)
        if args.verbose:
            print(f"  logPPL_performer={log_ppl:.4f}  logX-PPL={log_x_ppl:.4f}")


if __name__ == "__main__":
    main()
