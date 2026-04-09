from __future__ import annotations

import argparse
from pathlib import Path
import sys

from .exiftool import ExifToolClient, ExifToolError
from .models import build_photo_recipe
from .output import OutputWriter


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.command != "scan":
        parser.print_help()
        return 1

    try:
        return _run_scan(args)
    except (ValueError, ExifToolError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fuji-recipe-extractor")
    subparsers = parser.add_subparsers(dest="command")

    scan = subparsers.add_parser("scan", help="Scan JPEG files and extract Fujifilm recipes")
    scan.add_argument("--input", required=True, help="Input directory")
    scan.add_argument("--output", required=True, help="Output directory")
    scan.add_argument("--copy-by", choices=("recipe", "film"), default=None, help="Copy images by grouping")
    scan.add_argument("--dry-run", action="store_true", help="Show what would happen")
    scan.add_argument("--verbose", action="store_true", help="Verbose logging")
    return parser


def _run_scan(args: argparse.Namespace) -> int:
    input_dir = Path(args.input)
    output_dir = Path(args.output)

    if not input_dir.is_dir():
        raise ValueError(f"input directory does not exist: {input_dir}")

    files = sorted(
        [
            path
            for path in input_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg"}
        ],
        key=lambda item: str(item).lower(),
    )

    if not files:
        print(f"No JPEG files found in {input_dir}")
        return 0

    if args.verbose:
        print(f"[verbose] Found {len(files)} JPEG files")

    client = ExifToolClient()
    client.assert_available()
    records = client.extract(files, verbose=args.verbose)
    photos = [build_photo_recipe(record) for record in records]

    OutputWriter().write(
        photos=photos,
        output_dir=output_dir,
        copy_by=args.copy_by,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )

    prefix = "Dry run completed" if args.dry_run else "Scan completed"
    print(f"{prefix}: {len(photos)} file(s) processed")
    return 0
