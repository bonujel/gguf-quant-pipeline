#!/usr/bin/env python3
"""生成 imatrix 校准语料（中英+代码混合）。
用法: python prepare_calibration.py <输出路径> [目标KB]
将内置多样化种子文本平铺/打散到目标大小。生产环境建议替换为更大的真实语料。
"""
import sys, os, random

SEED = os.path.join(os.path.dirname(__file__), "calibration_seed.txt")

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "calibration.txt"
    target_kb = int(sys.argv[2]) if len(sys.argv) > 2 else 600
    with open(SEED, "r", encoding="utf-8") as f:
        blocks = [b.strip() for b in f.read().split("\n\n") if b.strip()]
    rng = random.Random(42)  # 固定种子，可复现
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
    print(f"校准语料写入 {out}  约 {size//1024} KB  {len(buf)} 段")

if __name__ == "__main__":
    main()
