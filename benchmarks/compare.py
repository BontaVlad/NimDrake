#!/usr/bin/env python3
"""Compare Criterion JSON output from two NimDrake benchmark runs."""

import argparse
import json
import math
import statistics
import sys
from pathlib import Path


def load(path: Path):
    with path.open() as stream:
        return json.load(stream)


def samples(entry):
    raw = entry["raw_data"]
    return [time / count for time, count in zip(raw["time"], raw["iterations"])]


def mean(values):
    return statistics.mean(values) if values else 0.0


def welch(left, right):
    if len(left) < 2 or len(right) < 2:
        return 0.0
    left_var = statistics.variance(left)
    right_var = statistics.variance(right)
    standard_error = left_var / len(left) + right_var / len(right)
    if standard_error == 0:
        return 0.0
    return abs(mean(left) - mean(right)) / math.sqrt(standard_error)


def compare_files(baseline_path, candidate_path, threshold):
    baseline = {entry["label"]: entry for entry in load(baseline_path)}
    candidate = {entry["label"]: entry for entry in load(candidate_path)}
    missing = sorted(set(baseline) - set(candidate))
    added = sorted(set(candidate) - set(baseline))
    if missing or added:
        if missing:
            print("missing candidate benchmarks: " + ", ".join(missing), file=sys.stderr)
        if added:
            print("new candidate benchmarks: " + ", ".join(added), file=sys.stderr)
        return 1

    rows = []
    for label in sorted(baseline):
        old = samples(baseline[label])
        new = samples(candidate[label])
        old_mean = mean(old)
        new_mean = mean(new)
        delta = ((new_mean - old_mean) / old_mean * 100) if old_mean else 0.0
        rows.append((abs(delta), label, old_mean, new_mean, delta, welch(old, new)))

    for _, label, old, new, delta, t_value in sorted(rows, reverse=True):
        if abs(delta) < threshold:
            continue
        print(f"{label:<48} {old / 1e3:>10.2f} us {new / 1e3:>10.2f} us "
              f"{delta:>+8.2f}% t={t_value:.2f}")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--threshold", type=float, default=0.0)
    args = parser.parse_args()
    if args.baseline.is_dir() != args.candidate.is_dir():
        parser.error("baseline and candidate must both be files or directories")
    if args.baseline.is_dir():
        names = sorted(path.name for path in args.baseline.glob("*.json"))
        result = 0
        for name in names:
            candidate = args.candidate / name
            if not candidate.exists():
                print(f"missing candidate file: {candidate}", file=sys.stderr)
                result = 1
                continue
            result |= compare_files(args.baseline / name, candidate, args.threshold)
        return result
    return compare_files(args.baseline, args.candidate, args.threshold)


if __name__ == "__main__":
    raise SystemExit(main())
