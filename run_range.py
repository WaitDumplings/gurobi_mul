from __future__ import annotations

import argparse
import os
from pathlib import Path


DEFAULT_EVRPTW_ROOT = Path("/data/Maojie/EVRPTW-DB")


def default_output_path(split: str, scale: str, start_index: int, end_index: int) -> Path:
    return Path("/data/Maojie/gurobi_mul/results") / split / f"{scale}_{start_index}_{end_index}"


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Run a multiprocessing Gurobi shard for EVRPTW dataset_v1. "
            "Example: Cus15 train instances with numeric suffixes [100, 200)."
        )
    )
    parser.add_argument("--evrptw_root", default=str(DEFAULT_EVRPTW_ROOT), help="EVRPTW-DB root used for dataset defaults and EVRPTW_Core imports.")
    parser.add_argument("--dataset_path", default="", help="Split dataset directory or a single pickle file. Overrides --dataset_root/--split.")
    parser.add_argument("--dataset_root", default="", help="Dataset root containing train/val/eval. Defaults to <evrptw_root>/EVRPTW_Dataset/dataset_v1/dataset.")
    parser.add_argument("--split", default="val", choices=["train", "val", "eval"], help="Dataset split when --dataset_path is not provided.")
    parser.add_argument("--scale", default="Cus15", help="Scale to run, e.g. Cus5, Cus15, Cus50.")
    parser.add_argument("--start_index", type=int, required=True, help="Inclusive numeric instance suffix start.")
    parser.add_argument("--end_index", type=int, required=True, help="Exclusive numeric instance suffix end.")
    parser.add_argument("--output_path", default="", help="Output directory for gurobi_summary.csv, time trace, and solution pickles.")
    parser.add_argument("--reference_output_path", default="", help="Optional reference_solutions root for split/solutions.csv and routes/*.json.")
    parser.add_argument("--workers", type=int, default=16, help="Number of parallel worker processes.")
    parser.add_argument("--threads", type=int, default=1, help="Gurobi threads per worker.")
    parser.add_argument("--cs_copies", type=int, default=2, help="Charging-station dummy copies per station.")
    parser.add_argument("--time_limit_s", type=float, default=7200.0, help="Per-instance Gurobi time limit in seconds.")
    parser.add_argument("--checkpoints_s", default="60,300,900,3600,7200", help="Comma-separated incumbent checkpoint seconds.")
    parser.add_argument("--mip_gap", type=float, default=0.0)
    parser.add_argument("--no_skip_completed", action="store_true", help="Re-solve completed rows instead of resuming.")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    evrptw_root = Path(args.evrptw_root).resolve()
    os.environ["EVRPTW_DB_ROOT"] = str(evrptw_root)

    from run_gurobi import main as run_gurobi_main

    dataset_root = Path(args.dataset_root).resolve() if args.dataset_root else evrptw_root / "EVRPTW_Dataset/dataset_v1/dataset"
    dataset_path = Path(args.dataset_path).resolve() if args.dataset_path else dataset_root / args.split
    output_path = Path(args.output_path).resolve() if args.output_path else default_output_path(
        args.split,
        args.scale,
        args.start_index,
        args.end_index,
    )

    gurobi_args = [
        "--dataset_path", str(dataset_path),
        "--save_path", str(output_path),
        "--reference_split", args.split,
        "--scales", args.scale,
        "--start_index", str(args.start_index),
        "--end_index", str(args.end_index),
        "--workers", str(args.workers),
        "--threads", str(args.threads),
        "--cs_copies", str(args.cs_copies),
        "--time_limit_s", str(args.time_limit_s),
        "--checkpoints_s", args.checkpoints_s,
        "--mip_gap", str(args.mip_gap),
    ]
    if args.reference_output_path:
        gurobi_args.extend(["--reference_save_path", str(Path(args.reference_output_path).resolve())])
    if not args.no_skip_completed:
        gurobi_args.append("--skip_completed")
    if args.verbose:
        gurobi_args.append("--verbose")

    print(f"EVRPTW root: {evrptw_root}")
    print(f"Dataset path: {dataset_path}")
    print(f"Output path: {output_path}")
    print(f"Shard: split={args.split} scale={args.scale} index=[{args.start_index}, {args.end_index}) workers={args.workers}")
    run_gurobi_main(gurobi_args)


if __name__ == "__main__":
    main()
