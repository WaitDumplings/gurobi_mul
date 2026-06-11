from __future__ import annotations

import argparse
from pathlib import Path

SCRIPT_ROOT = Path(__file__).resolve().parent
DEFAULT_DATASET_ROOT = SCRIPT_ROOT.parents[1] / "classical_dataset_v1" / "cvrp" / "dataset"


def default_output_path(split: str, scale: str) -> Path:
    return SCRIPT_ROOT / "results" / split / scale


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a multiprocessing Gurobi shard for Geo-CVRP-v1.")
    parser.add_argument("--dataset_path", default="")
    parser.add_argument("--dataset_root", default=str(DEFAULT_DATASET_ROOT))
    parser.add_argument("--split", default="train", choices=["train", "val", "eval"])
    parser.add_argument("--scale", default="Cus15")
    parser.add_argument("--start_index", type=int, required=True)
    parser.add_argument("--end_index", type=int, required=True)
    parser.add_argument("--output_path", default="")
    parser.add_argument("--workers", type=int, default=16)
    parser.add_argument("--threads", type=int, default=1)
    parser.add_argument("--time_limit_s", type=float, default=7200.0)
    parser.add_argument("--checkpoints_s", default="60,300,900,3600,7200")
    parser.add_argument("--mip_gap", type=float, default=0.0)
    parser.add_argument("--no_skip_completed", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    from run_gurobi import main as run_gurobi_main

    dataset_root = Path(args.dataset_root).resolve()
    dataset_path = Path(args.dataset_path).resolve() if args.dataset_path else dataset_root / args.split / args.scale
    output_path = Path(args.output_path).resolve() if args.output_path else default_output_path(args.split, args.scale)
    cmd = [
        "--dataset_path", str(dataset_path),
        "--save_path", str(output_path),
        "--start_index", str(args.start_index),
        "--end_index", str(args.end_index),
        "--workers", str(args.workers),
        "--threads", str(args.threads),
        "--time_limit_s", str(args.time_limit_s),
        "--checkpoints_s", args.checkpoints_s,
        "--mip_gap", str(args.mip_gap),
    ]
    if not args.no_skip_completed:
        cmd.append("--skip_completed")
    if args.verbose:
        cmd.append("--verbose")
    print(f"Dataset path: {dataset_path}")
    print(f"Output path: {output_path}")
    print(f"Shard: split={args.split} scale={args.scale} index=[{args.start_index}, {args.end_index}) workers={args.workers} threads={args.threads}")
    run_gurobi_main(cmd)


if __name__ == "__main__":
    main()
