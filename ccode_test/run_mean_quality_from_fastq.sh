#!/usr/bin/env bash
# C++ 全量统计 mean(Q) + Python 绘制 Quality score along reads
# 不覆盖 run_quality_distribution_fast.sh
set -euo pipefail
cd "$(dirname "$0")"

BIN=./plot_mean_quality_from_fastq
SRC=./plot_mean_quality_from_fastq.cpp
PY="${PYTHON:-}"
if [[ -z "$PY" ]]; then
  for cand in \
    /home/peibing/miniforge3/envs/phip_heatmap/bin/python \
    /home/peibing/miniforge3/envs/go_enrich/bin/python \
    python3; do
    if [[ -x "$cand" ]] || command -v "$cand" >/dev/null 2>&1; then
      if "$cand" -c 'import matplotlib,numpy' 2>/dev/null; then
        PY=$cand
        break
      fi
    fi
  done
fi
if [[ -z "${PY:-}" ]]; then
  echo "未找到带 matplotlib 的 Python" >&2
  exit 1
fi

if [[ ! -x "$BIN" ]] || [[ "$SRC" -nt "$BIN" ]]; then
  echo "[...] compiling $SRC ..."
  g++ -O3 -std=c++17 -o "$BIN" "$SRC" -lz
fi

mkdir -p ./output
meta="$("$BIN" "$@")"
sample="${meta%%$'\t'*}"
r1_len="${meta#*$'\t'}"
csv="./output/${sample}_mean_q_by_position.csv"
"$PY" plot_mean_quality_csv.py "$csv" "$sample" "$r1_len"
echo "[OK] done. sample=$sample r1_len=$r1_len"
