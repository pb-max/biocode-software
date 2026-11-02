#!/usr/bin/env python3
"""预览训练/评测 JSONL，确认格式无误。"""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def load_jsonl(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            for k in ("instruction", "input", "output"):
                if k not in obj:
                    raise ValueError(f"{path}:{i} 缺少字段 {k}")
            rows.append(obj)
    return rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--data",
        nargs="+",
        default=["data/train.jsonl", "data/eval.jsonl"],
        help="一个或多个 jsonl 路径",
    )
    args = ap.parse_args()

    for p in args.data:
        path = Path(p)
        rows = load_jsonl(path)
        lens = [len(r["instruction"]) + len(r["input"]) + len(r["output"]) for r in rows]
        instr = Counter(r["instruction"][:20] for r in rows)
        print(f"\n=== {path} ===")
        print(f"样本数: {len(rows)}")
        print(f"字符长度: min={min(lens)}, median={sorted(lens)[len(lens)//2]}, max={max(lens)}")
        print("instruction 前缀分布(截断20字):")
        for k, v in instr.most_common(8):
            print(f"  {v:3d}  {k}...")
        print("示例[0]:")
        print(json.dumps(rows[0], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
