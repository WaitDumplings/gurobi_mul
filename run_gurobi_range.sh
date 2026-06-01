#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./run_gurobi_range.sh --workers 24 --start 100 --end 200 --cus 15

Main options:
  -w, --workers N       Number of worker processes. Default: 24
  -s, --start N         Inclusive start index. Default: 0
  -e, --end N           Exclusive end index. Default: 100
  -c, --cus N|CusN      Customer scale, for example 15 or Cus15. Default: Cus15

Other options:
  --split NAME          Dataset split. Default: train
  --cs-copies N         Charging-station dummy copies. Default: 2
  --time-limit N        Gurobi optimize-call time limit seconds. Default: 7200; hard cap: 7200
  --mip-gap X           Gurobi relative MIP gap. Default: 0.0
  --dataset-path PATH   Dataset path. Default: ../dataset_v1/dataset/<split>/<CusN>
  --output-path PATH    Output path. Default: results/<split>/<CusN>
  --log-dir PATH        Log directory. Default: logs
  --log-file PATH       Log file. Default: timestamped file under logs/
  --conda-env NAME      Conda env. Default: maojie
  --detach              Run in background and keep logs.
  -h, --help            Show this help.

Examples:
  ./run_gurobi_range.sh --workers 24 --start 0 --end 100 --cus 15
  ./run_gurobi_range.sh -w 24 -s 100 -e 200 -c Cus15
  ./run_gurobi_range.sh --detach -w 32 -s 850 -e 1000 -c 15

Resume behavior:
  The Python runner uses --skip_completed by default. Restarting the same
  command with the same output path skips completed rows in gurobi_summary.csv.
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

ORIGINAL_ARGS=("$@")

START_INDEX="${START_INDEX:-0}"
END_INDEX="${END_INDEX:-100}"
WORKERS="${WORKERS:-24}"
CUS="${CUS:-${SCALE:-Cus15}}"
SPLIT="${SPLIT:-train}"
CS_COPIES="${CS_COPIES:-2}"
TIME_LIMIT_S="${TIME_LIMIT_S:-7200}"
MIP_GAP="${MIP_GAP:-0.0}"
CONDA_ENV="${CONDA_ENV:-maojie}"
LOG_DIR="${LOG_DIR:-logs}"
DETACH="${DETACH:-0}"
DATASET_PATH="${DATASET_PATH:-}"
OUTPUT_PATH="${OUTPUT_PATH:-}"
LOG_FILE="${LOG_FILE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workers)
      need_value "$1" "${2:-}"
      WORKERS="$2"
      shift 2
      ;;
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
    --mip-gap|--mip_gap)
      need_value "$1" "${2:-}"
      MIP_GAP="$2"
      shift 2
      ;;
    --dataset-path)
      need_value "$1" "${2:-}"
      DATASET_PATH="$2"
      shift 2
      ;;
    --output-path)
      need_value "$1" "${2:-}"
      OUTPUT_PATH="$2"
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
    --conda-env)
      need_value "$1" "${2:-}"
      CONDA_ENV="$2"
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

[[ "$START_INDEX" =~ ^[0-9]+$ ]] || die "--start must be a non-negative integer"
[[ "$END_INDEX" =~ ^[0-9]+$ ]] || die "--end must be a non-negative integer"
[[ "$WORKERS" =~ ^[0-9]+$ ]] || die "--workers must be a positive integer"
[[ "$CS_COPIES" =~ ^[0-9]+$ ]] || die "--cs-copies must be a non-negative integer"

(( START_INDEX < END_INDEX )) || die "--start must be less than --end"
(( WORKERS >= 1 )) || die "--workers must be at least 1"

SCALE="$(normalize_scale "$CUS")"
DATASET_PATH="${DATASET_PATH:-../dataset_v1/dataset/${SPLIT}/${SCALE}}"
OUTPUT_PATH="${OUTPUT_PATH:-results/${SPLIT}/${SCALE}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_FILE:-${LOG_DIR}/gurobi_${SCALE}_${SPLIT}_${START_INDEX}_${END_INDEX}_w${WORKERS}_${TIMESTAMP}.log}"
mkdir -p "$(dirname "$LOG_FILE")"

if [[ "$DETACH" == "1" && "${_GUROBI_DETACHED:-0}" != "1" ]]; then
  export _GUROBI_DETACHED=1
  export LOG_FILE
  nohup bash "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "${ORIGINAL_ARGS[@]}" > "${LOG_FILE}.launcher" 2>&1 &
  pid=$!
  echo "Started detached Gurobi run: PID=${pid}"
  echo "Main log: ${SCRIPT_DIR}/${LOG_FILE}"
  echo "Launcher log: ${SCRIPT_DIR}/${LOG_FILE}.launcher"
  exit 0
fi

exec > >(tee -a "$LOG_FILE") 2>&1

echo "Started at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Host: $(hostname)"
echo "Workdir: $SCRIPT_DIR"
echo "Conda env: $CONDA_ENV"
echo "Split: $SPLIT"
echo "Scale: $SCALE"
echo "Dataset path: $DATASET_PATH"
echo "Output path: $OUTPUT_PATH"
echo "Summary CSV: $OUTPUT_PATH/gurobi_summary.csv"
echo "Range: [$START_INDEX, $END_INDEX)"
echo "Workers: $WORKERS"
echo "CS copies: $CS_COPIES"
echo "Time limit seconds: $TIME_LIMIT_S"
echo "MIP gap: $MIP_GAP"
echo "Skip completed: enabled by run_range.py default"
echo "Log file: $SCRIPT_DIR/$LOG_FILE"

[[ -e "$DATASET_PATH" ]] || die "dataset path does not exist: $DATASET_PATH"

if command -v conda >/dev/null 2>&1; then
  eval "$(conda shell.bash hook)"
elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/anaconda3/etc/profile.d/conda.sh"
else
  echo "ERROR: conda was not found. Load conda first or set PATH to include it." >&2
  exit 127
fi

conda activate "$CONDA_ENV"

python --version
python -c "import gurobipy as gp; print('Gurobi:', '.'.join(map(str, gp.gurobi.version())))"

echo "Command:"
printf '  %q' python -u run_range.py \
  --dataset_path "$DATASET_PATH" \
  --split "$SPLIT" \
  --scale "$SCALE" \
  --start_index "$START_INDEX" \
  --end_index "$END_INDEX" \
  --workers "$WORKERS" \
  --cs_copies "$CS_COPIES" \
  --time_limit_s "$TIME_LIMIT_S" \
  --mip_gap "$MIP_GAP" \
  --output_path "$OUTPUT_PATH" \
  --verbose
printf '\n'

python -u run_range.py \
  --dataset_path "$DATASET_PATH" \
  --split "$SPLIT" \
  --scale "$SCALE" \
  --start_index "$START_INDEX" \
  --end_index "$END_INDEX" \
  --workers "$WORKERS" \
  --cs_copies "$CS_COPIES" \
  --time_limit_s "$TIME_LIMIT_S" \
  --mip_gap "$MIP_GAP" \
  --output_path "$OUTPUT_PATH" \
  --verbose

echo "Finished at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
