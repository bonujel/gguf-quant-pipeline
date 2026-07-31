#!/usr/bin/env python3
"""Build the imatrix calibration corpus (mixed English / Chinese / code).
Usage: python prepare_calibration.py <output_path> [target_kb]
Shuffles the bundled seed blocks up to the target size. Replace the seed with a larger
real corpus for production use.
"""
import sys, os, random

SEED = os.path.join(os.path.dirname(__file__), "calibration_seed.txt")

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "calibration.txt"
    target_kb = int(sys.argv[2]) if len(sys.argv) > 2 else 600
    with open(SEED, "r", encoding="utf-8") as f:
        blocks = [b.strip() for b in f.read().split("\n\n") if b.strip()]
    rng = random.Random(42)  # fixed seed for reproducibility
    buf, size = [], 0
    target = target_kb * 1024
    while size < target:
        rng.shuffle(blocks)
        for b in blocks:
            buf.append(b)
            size += len(b.encode("utf-8")) + 2
            if size >= target:
                break
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n\n".join(buf))
    print(f"wrote {out}  ~{size//1024} KB  {len(buf)} blocks")

if __name__ == "__main__":
    main()
