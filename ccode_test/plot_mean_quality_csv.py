#!/usr/bin/env python3
"""从 mean_q_by_position.csv 画 Quality score distribution along reads。"""
from __future__ import annotations

import os
import sys

import matplotlib.pyplot as plt
import numpy as np

TEAL = "#2EC4B6"


def load_csv(path: str):
    pos, q, ends = [], [], []
    with open(path, encoding="utf-8") as fh:
        next(fh)
        for line in fh:
            parts = line.strip().split(",")
            if len(parts) < 2:
                continue
            pos.append(int(float(parts[0])))
            q.append(float(parts[1]))
            ends.append(parts[2] if len(parts) >= 3 else "")
    return np.asarray(pos), np.asarray(q, dtype=np.float64), ends


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("用法: plot_mean_quality_csv.py <mean_q.csv> [sample] [r1_len]")

    csv_path = sys.argv[1]
    sample = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(csv_path).replace(
        "_mean_q_by_position.csv", ""
    )
    r1_len = int(sys.argv[3]) if len(sys.argv) > 3 else 0

    out_dir = os.path.dirname(os.path.abspath(csv_path)) or "."
    out_png = os.path.join(out_dir, f"{sample}_quality_score_along_reads.png")

    pos, y, ends = load_csv(csv_path)
    if r1_len <= 0 and ends and "R1" in ends:
        r1_len = sum(1 for e in ends if e == "R1")

    x = pos if pos.size else np.arange(1, y.size + 1)
    fig, ax = plt.subplots(figsize=(8.0, 5.5))
    ax.plot(x, y, color=TEAL, lw=2.2, solid_capstyle="round")
    ax.scatter(x, y, s=8, color=TEAL, zorder=3, linewidths=0)

    if r1_len > 0 and r1_len < y.size:
        ax.axvline(r1_len + 0.5, color="#4C78A8", linestyle="--", linewidth=1.2, zorder=2)

    ax.set_xlabel("Position along reads", fontsize=12)
    ax.set_ylabel("Quality score", fontsize=12)
    ax.set_title(f"Quality score distribution along reads\n( {sample} )", fontsize=13)
    ax.set_xlim(0.5, y.size + 0.5)
    ax.set_ylim(0, 42)
    ax.set_xticks([])
    ax.tick_params(axis="y", labelsize=10)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    fig.tight_layout()
    fig.savefig(out_png, dpi=180)
    fig.savefig(os.path.splitext(out_png)[0] + ".pdf")
    plt.close(fig)
    print(f"[OK] saved {out_png}")


if __name__ == "__main__":
    main()
