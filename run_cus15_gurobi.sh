#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  exec "$SCRIPT_DIR/run_gurobi_range.sh" --help
fi

if [[ $# -gt 0 && "${1:0:1}" == "-" ]]; then
  exec "$SCRIPT_DIR/run_gurobi_range.sh" --cus 15 "$@"
fi

exec "$SCRIPT_DIR/run_gurobi_range.sh" \
  --cus 15 \
  --start "${1:-0}" \
  --end "${2:-100}" \
  --workers "${3:-24}"
