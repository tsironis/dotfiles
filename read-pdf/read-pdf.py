#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pymupdf"]
# ///
#
# Extract plain text (and, on request, annotations/comments) from a PDF, so it can be
# read directly instead of parsed page-by-page as images (which costs far more tokens
# for text-based PDFs). uv installs pymupdf into an ephemeral venv on first run.
#
#   read-pdf paper.pdf
#   read-pdf paper.pdf report.pdf
#   read-pdf --pages 1-5 paper.pdf
#   read-pdf --pages 3 paper.pdf
#   read-pdf --annots reviewed-draft.pdf
"""Extract text and annotations from PDFs."""

import argparse
import pathlib
import sys

import pymupdf


def parse_pages(spec):
    if "-" in spec:
        start, end = spec.split("-", 1)
        return int(start), int(end)
    page = int(spec)
    return page, page


def read_pdf(path, first_page, last_page, want_annots):
    if not pathlib.Path(path).is_file():
        print(f"error: no such file: {path}", file=sys.stderr)
        sys.exit(1)
    doc = pymupdf.open(path)
    start = (first_page - 1) if first_page else 0
    end = last_page if last_page else doc.page_count
    if start < 0 or end > doc.page_count or start >= end:
        print(
            f"error: page range {first_page}-{last_page} is out of bounds "
            f"for {path} ({doc.page_count} pages)",
            file=sys.stderr,
        )
        sys.exit(1)

    for index in range(start, end):
        page = doc[index]
        print(page.get_text().rstrip())
        if want_annots:
            for annot in page.annots() or []:
                content = (annot.info.get("content") or "").strip()
                if not content:
                    continue
                author = annot.info.get("title") or "unknown"
                print(f"[annotation p{index + 1}, {annot.type[1]}, {author}]: {content}")


def main():
    parser = argparse.ArgumentParser(
        description="Extract text (and optionally annotations) from PDFs, printed to stdout."
    )
    parser.add_argument("files", nargs="+", help="PDF file(s) to read")
    parser.add_argument(
        "--pages", metavar="N|START-END", help="only extract this page (or page range)"
    )
    parser.add_argument(
        "--annots",
        action="store_true",
        help="also print annotation/comment text (sticky notes, highlights, etc.)",
    )
    args = parser.parse_args()

    first_page, last_page = parse_pages(args.pages) if args.pages else (None, None)

    multi = len(args.files) > 1
    for path in args.files:
        if multi:
            print(f"==> {path}")
        read_pdf(path, first_page, last_page, args.annots)


if __name__ == "__main__":
    main()
