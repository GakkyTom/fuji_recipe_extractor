#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./run-scan.sh INPUT_DIR OUTPUT_DIR [--copy-by recipe|film] [--dry-run] [--verbose]

Example:
  ./run-scan.sh ./samples ./output --copy-by recipe --verbose
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"
shift 2
EXTRA_ARGS=("$@")

if ! command -v python3 >/dev/null 2>&1; then
  echo "Required command not found: python3" >&2
  exit 1
fi

if [[ ! -x /usr/local/bin/exiftool ]]; then
  echo "exiftool not found or not executable: /usr/local/bin/exiftool" >&2
  exit 1
fi

python3 -m fuji_recipe_extractor \
  scan \
  --input "$INPUT_DIR" \
  --output "$OUTPUT_DIR" \
  "${EXTRA_ARGS[@]}"
