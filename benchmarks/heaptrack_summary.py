#!/usr/bin/env python3
"""Extract stable totals from heaptrack_print output."""

import argparse
import json
import re
from pathlib import Path


PATTERNS = {
    "allocations": re.compile(r"calls to allocation functions:\s+(\d+)"),
    "temporary": re.compile(r"temporary memory allocations:\s+(\S+)"),
    "peak": re.compile(r"peak heap memory consumption:\s+(\S+)"),
    "leaked": re.compile(r"total memory leaked:\s+(\S+)"),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    text = args.report.read_text()
    result = {}
    for name, pattern in PATTERNS.items():
        match = pattern.search(text)
        if match:
            result[name] = match.group(1)
    encoded = json.dumps(result, sort_keys=True, indent=2) + "\n"
    if args.output:
        args.output.write_text(encoded)
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
