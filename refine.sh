#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./refine.sh -s 0 -e 100 -c 50

Required options:
  -s, --start N         Inclusive start index.
  -e, --end N           Exclusive end index.
  -c, --cus N|CusN      Customer scale, for example 50 or Cus50.

Optional options:
  --split NAME          Dataset/expert split. Default: train
  --expert-path PATH    Expert root, split dir, scale dir, or gurobi_summary.csv. Default: results
  --dataset-root PATH   Dataset root. Default: ../dataset_v1/dataset
  --output-path PATH    Output dir. Default: directory containing resolved expert summary
  --workers N           Number of worker processes. Default: 8
  --threads N           Gurobi threads per worker. Default: 4
  --cs-copies N         Charging-station dummy copies. Default: 2
  --time-limit N        Additional refine time in seconds. Default: 1800
  --conda-env NAME      Conda env name/path. Default: maojie
  --log-dir PATH        Log directory. Default: logs
  --log-file PATH       Log file. Default: timestamped file under logs/
  --detach              Run in background and keep logs.
  -h, --help            Show this help.

Refine policy:
  OPTIMAL expert rows are skipped.
  TIME_LIMIT expert rows with incumbent routes are warm-started and refined.
  TIME_LIMIT expert rows without incumbent routes are skipped.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

need_value() {
  local opt="$1"
  local value="${2:-}"
  [[ -n "$value" && "$value" != -* ]] || die "$opt requires a value"
}

normalize_scale() {
  local raw="$1"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    echo "Cus${raw}"
  elif [[ "${raw,,}" =~ ^cus([0-9]+)$ ]]; then
    echo "Cus${BASH_REMATCH[1]}"
  else
    die "--cus must be a number or CusN, got: $raw"
  fi
}

resolve_expert_summary() {
  local expert_path="$1"
  local split="$2"
  local scale="$3"

  if [[ -f "$expert_path" ]]; then
    echo "$expert_path"
    return
  fi
  if [[ -f "$expert_path/$split/$scale/gurobi_summary.csv" ]]; then
    echo "$expert_path/$split/$scale/gurobi_summary.csv"
    return
  fi
  if [[ -f "$expert_path/$scale/gurobi_summary.csv" ]]; then
    echo "$expert_path/$scale/gurobi_summary.csv"
    return
  fi
  if [[ -f "$expert_path/gurobi_summary.csv" ]]; then
    echo "$expert_path/gurobi_summary.csv"
    return
  fi
  die "could not resolve expert summary from: $expert_path"
}

ORIGINAL_ARGS=("$@")

START_INDEX="${START_INDEX:-}"
END_INDEX="${END_INDEX:-}"
CUS="${CUS:-${SCALE:-}}"
SPLIT="${SPLIT:-train}"
EXPERT_PATH="${EXPERT_PATH:-results}"
DATASET_ROOT="${DATASET_ROOT:-../dataset_v1/dataset}"
OUTPUT_PATH="${OUTPUT_PATH:-}"
WORKERS="${WORKERS:-8}"
THREADS="${THREADS:-4}"
CS_COPIES="${CS_COPIES:-2}"
TIME_LIMIT_S="${TIME_LIMIT_S:-1800}"
CONDA_ENV="${CONDA_ENV:-maojie}"
LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-}"
DETACH="${DETACH:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--start|--start-index)
      need_value "$1" "${2:-}"
      START_INDEX="$2"
      shift 2
      ;;
    -e|--end|--end-index)
      need_value "$1" "${2:-}"
      END_INDEX="$2"
      shift 2
      ;;
    -c|--cus|--scale)
      need_value "$1" "${2:-}"
      CUS="$2"
      shift 2
      ;;
    --split)
      need_value "$1" "${2:-}"
      SPLIT="$2"
      shift 2
      ;;
    --expert-path|--expert-summary|--expert-summary-path)
      need_value "$1" "${2:-}"
      EXPERT_PATH="$2"
      shift 2
      ;;
    --dataset-root)
      need_value "$1" "${2:-}"
      DATASET_ROOT="$2"
      shift 2
      ;;
    --output-path)
      need_value "$1" "${2:-}"
      OUTPUT_PATH="$2"
      shift 2
      ;;
    --workers)
      need_value "$1" "${2:-}"
      WORKERS="$2"
      shift 2
      ;;
    --threads)
      need_value "$1" "${2:-}"
      THREADS="$2"
      shift 2
      ;;
    --cs-copies)
      need_value "$1" "${2:-}"
      CS_COPIES="$2"
      shift 2
      ;;
    --time-limit|--time-limit-s)
      need_value "$1" "${2:-}"
      TIME_LIMIT_S="$2"
      shift 2
      ;;
    --conda-env)
      need_value "$1" "${2:-}"
      CONDA_ENV="$2"
      shift 2
      ;;
    --log-dir)
      need_value "$1" "${2:-}"
      LOG_DIR="$2"
      shift 2
      ;;
    --log-file)
      need_value "$1" "${2:-}"
      LOG_FILE="$2"
      shift 2
      ;;
    --detach)
      DETACH=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$START_INDEX" ]] || die "--start is required"
[[ -n "$END_INDEX" ]] || die "--end is required"
[[ -n "$CUS" ]] || die "--cus is required"
[[ "$START_INDEX" =~ ^[0-9]+$ ]] || die "--start must be a non-negative integer"
[[ "$END_INDEX" =~ ^[0-9]+$ ]] || die "--end must be a non-negative integer"
[[ "$WORKERS" =~ ^[0-9]+$ ]] || die "--workers must be a positive integer"
[[ "$THREADS" =~ ^[0-9]+$ ]] || die "--threads must be a positive integer"
[[ "$CS_COPIES" =~ ^[0-9]+$ ]] || die "--cs-copies must be a non-negative integer"
(( START_INDEX < END_INDEX )) || die "--start must be less than --end"
(( WORKERS >= 1 )) || die "--workers must be at least 1"
(( THREADS >= 1 )) || die "--threads must be at least 1"

SCALE="$(normalize_scale "$CUS")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DATASET_PATH="${DATASET_ROOT}/${SPLIT}/${SCALE}"
EXPERT_SUMMARY="$(resolve_expert_summary "$EXPERT_PATH" "$SPLIT" "$SCALE")"
OUTPUT_PATH="${OUTPUT_PATH:-$(dirname "$EXPERT_SUMMARY")}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/gurobi_refine_${SCALE}_${SPLIT}_${START_INDEX}_${END_INDEX}_w${WORKERS}_t${THREADS}_${TIMESTAMP}.log}"
mkdir -p "$(dirname "$LOG_FILE")"
if [[ "$LOG_FILE" = /* ]]; then
  LOG_DISPLAY="$LOG_FILE"
else
  LOG_DISPLAY="$SCRIPT_DIR/$LOG_FILE"
fi

if [[ "$DETACH" == "1" && "${_GUROBI_REFINE_DETACHED:-0}" != "1" ]]; then
  export _GUROBI_REFINE_DETACHED=1
  export LOG_FILE
  nohup bash "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "${ORIGINAL_ARGS[@]}" > "${LOG_FILE}.launcher" 2>&1 &
  pid=$!
  echo "Started detached Gurobi refine: PID=${pid}"
  echo "Main log: ${LOG_DISPLAY}"
  echo "Launcher log: ${LOG_DISPLAY}.launcher"
  exit 0
fi

exec > >(tee -a "$LOG_FILE") 2>&1

echo "Started refine at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Host: $(hostname)"
echo "Workdir: $SCRIPT_DIR"
echo "Conda env: $CONDA_ENV"
echo "Split: $SPLIT"
echo "Scale: $SCALE"
echo "Dataset path: $DATASET_PATH"
echo "Expert summary: $EXPERT_SUMMARY"
echo "Output path: $OUTPUT_PATH"
echo "Range: [$START_INDEX, $END_INDEX)"
echo "Workers: $WORKERS"
echo "Threads per worker: $THREADS"
echo "CS copies: $CS_COPIES"
echo "Additional refine seconds: $TIME_LIMIT_S"
echo "Log file: $LOG_DISPLAY"

[[ -e "$DATASET_PATH" ]] || die "dataset path does not exist: $DATASET_PATH"
[[ -f "$EXPERT_SUMMARY" ]] || die "expert summary does not exist: $EXPERT_SUMMARY"

if [[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)"
else
  echo "ERROR: conda was not found. Load conda first or set PATH to include it." >&2
  exit 127
fi

set +u
conda activate "$CONDA_ENV"
set -u
hash -r 2>/dev/null || true

python --version
python -c "import gurobipy as gp; print('Gurobi:', '.'.join(map(str, gp.gurobi.version())))"

echo "Command:"
printf '  %q' python -u run_gurobi.py \
  --dataset_path "$DATASET_PATH" \
  --save_path "$OUTPUT_PATH" \
  --reference_split "$SPLIT" \
  --scales "$SCALE" \
  --start_index "$START_INDEX" \
  --end_index "$END_INDEX" \
  --workers "$WORKERS" \
  --threads "$THREADS" \
  --cs_copies "$CS_COPIES" \
  --time_limit_s "$TIME_LIMIT_S" \
  --checkpoints_s "$TIME_LIMIT_S" \
  --mip_gap 0 \
  --expert_summary_path "$EXPERT_SUMMARY" \
  --verbose
printf '\n'

python -u run_gurobi.py \
  --dataset_path "$DATASET_PATH" \
  --save_path "$OUTPUT_PATH" \
  --reference_split "$SPLIT" \
  --scales "$SCALE" \
  --start_index "$START_INDEX" \
  --end_index "$END_INDEX" \
  --workers "$WORKERS" \
  --threads "$THREADS" \
  --cs_copies "$CS_COPIES" \
  --time_limit_s "$TIME_LIMIT_S" \
  --checkpoints_s "$TIME_LIMIT_S" \
  --mip_gap 0 \
  --expert_summary_path "$EXPERT_SUMMARY" \
  --verbose

echo "Finished refine at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
