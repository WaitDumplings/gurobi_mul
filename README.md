# gurobi_mul

Standalone multiprocessing Gurobi runner for EVRPTW dataset shards.

The code is copied from `EVRPTW-DB/EVRPTW_Benchmark/Exact/Gurobi_Solver`. By default it expects this directory layout:

```text
<workdir>/
  gurobi_mul/
  dataset_v1/
    dataset/
      train/
      val/
      eval/
  EVRPTW-DB/
```

The default dataset path is `../dataset_v1/dataset/<split>` relative to `gurobi_mul`. `EVRPTW_Core` is imported from sibling `../EVRPTW-DB` by default; override it with `EVRPTW_DB_ROOT` or `--evrptw_root` if needed.

## Run A Range

Example: run `Cus15` train instances `train_Cus15_000100` through `train_Cus15_000199` with 16 workers:

```bash
cd /data/Maojie/gurobi_mul

GRB_LICENSE_FILE=/home/exx/anaconda3/envs/maojie/lib/gurobi.lic \
PYTHONPATH=/home/exx/anaconda3/envs/maojie/lib/python3.11/site-packages \
python run_range.py \
  --split train \
  --scale Cus15 \
  --start_index 100 \
  --end_index 200 \
  --workers 16 \
  --cs_copies 2 \
  --verbose
```

The index range is half-open: `--start_index 100 --end_index 200` means `100 <= idx < 200`.

## Main Arguments

- `--dataset_path`: direct path to a split directory or a single pickle file. If omitted, the runner uses `../dataset_v1/dataset/<split>`.
- `--dataset_root`: dataset root containing `train/val/eval`; default `../dataset_v1/dataset`.
- `--split`: `train`, `val`, or `eval`; default `val`.
- `--scale`: scale filter such as `Cus5`, `Cus15`, `Cus50`; default `Cus15`.
- `--start_index`, `--end_index`: numeric instance suffix range.
- `--workers`: multiprocessing worker count.
- `--output_path`: directory for `gurobi_summary.csv`, `gurobi_time_trace.csv`, and solution pickle files. If omitted, defaults to `results/<split>/<scale>_<start>_<end>` inside this repository.
- `--reference_output_path`: optional `reference_solutions` root. Leave this unset for eval-public runs.
- `--cs_copies`: charging-station dummy copies per active station.
- `--time_limit_s`: per-instance limit, default `7200`.

The runner uses `--skip_completed` by default, so restarting the same command resumes from the existing `gurobi_summary.csv`. Add `--no_skip_completed` only when you intentionally want to recompute existing rows.

## Outputs

Each finished instance is flushed incrementally:

- `gurobi_summary.csv`
- `gurobi_time_trace.csv`
- `solutions/*.pkl`
- optional `<reference_output_path>/<split>/solutions.csv`
- optional `<reference_output_path>/<split>/routes/<scale>/*.json`

For multi-server runs, prefer separate `--output_path` directories and merge later by `instance_id`.
