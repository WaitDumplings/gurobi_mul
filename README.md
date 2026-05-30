# gurobi_mul

Standalone multiprocessing Gurobi runner for EVRPTW dataset shards.

The code is copied from `EVRPTW-DB/EVRPTW_Benchmark/Exact/Gurobi_Solver`, with the small runtime `evrptw_core` package vendored into this repository. By default it expects this directory layout:

```text
<workdir>/
  gurobi_mul/
  dataset_v1/
    dataset/
      train/
      val/
      eval/
```

The default dataset path is `../dataset_v1/dataset/<split>` relative to `gurobi_mul`. The runner imports the bundled `evrptw_core` package from this repository, so a separate `EVRPTW-DB` checkout is not required. `--evrptw_root` remains available only as a legacy override.

## Run A Range

Example: run `Cus15` train instances `train_Cus15_000100` through `train_Cus15_000199` with 16 workers:

```bash
cd /data/Maojie/Github2/gurobi_mul
conda activate maojie

./run_gurobi_range.sh --cus 15 --start 100 --end 200 --workers 16
```

The script keeps a timestamped log under `logs/`. To detach it from the terminal, add `--detach`.

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
