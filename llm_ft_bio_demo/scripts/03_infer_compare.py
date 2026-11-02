#!/usr/bin/env python3
"""对比：底座模型 vs LoRA 微调后，在 eval.jsonl 上的回答。"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer


def load_jsonl(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def prompt_of(ex: dict) -> str:
    return (
        f"### Instruction:\n{ex['instruction']}\n\n"
        f"### Input:\n{ex['input']}\n\n"
        f"### Response:\n"
    )


@torch.inference_mode()
def generate(model, tok, text: str, max_new_tokens: int = 128) -> str:
    inputs = tok(text, return_tensors="pt").to(model.device)
    out = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False,
        pad_token_id=tok.eos_token_id,
    )
    full = tok.decode(out[0], skip_special_tokens=True)
    if "### Response:" in full:
        return full.split("### Response:")[-1].strip()
    return full[len(text) :].strip()


def load_model(base: str, adapter: str | None):
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    tok = AutoTokenizer.from_pretrained(adapter or base, trust_remote_code=True)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    model = AutoModelForCausalLM.from_pretrained(
        base,
        torch_dtype=dtype,
        device_map="auto" if device == "cuda" else None,
        trust_remote_code=True,
    )
    if device == "cpu":
        model = model.to(device)
    if adapter:
        model = PeftModel.from_pretrained(model, adapter)
    model.eval()
    return model, tok


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="Qwen/Qwen2.5-0.5B-Instruct")
    ap.add_argument("--adapter", default="outputs/qwen05b-lora")
    ap.add_argument("--eval", default="data/eval.jsonl")
    ap.add_argument("--limit", type=int, default=5, help="只跑前 N 题，便于快速看")
    args = ap.parse_args()

    rows = load_jsonl(Path(args.eval))[: args.limit]
    print("[info] 加载底座…")
    base_model, base_tok = load_model(args.base, None)
    print("[info] 加载 LoRA…")
    ft_model, ft_tok = load_model(args.base, args.adapter)

    for i, ex in enumerate(rows, 1):
        p = prompt_of(ex)
        print("\n" + "=" * 60)
        print(f"[{i}] Q: {ex['input']}")
        print(f"期望: {ex['output']}")
        print(f"底座: {generate(base_model, base_tok, p)}")
        print(f"微调: {generate(ft_model, ft_tok, p)}")


if __name__ == "__main__":
    main()
