#!/usr/bin/env python3
"""
LoRA 监督微调入门脚本（SFT）。
推荐在 Google Colab T4 / 云 GPU 上运行。
本机无 NVIDIA 时请不要硬跑全量训练。
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import torch
from datasets import Dataset
from peft import LoraConfig, TaskType, get_peft_model
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    DataCollatorForSeq2Seq,
    Trainer,
    TrainingArguments,
)


def load_jsonl(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def build_text(ex: dict) -> str:
    # 简单 chat 模板：够入门；正式项目可改用 tokenizer.apply_chat_template
    return (
        f"### Instruction:\n{ex['instruction']}\n\n"
        f"### Input:\n{ex['input']}\n\n"
        f"### Response:\n{ex['output']}"
    )


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="Qwen/Qwen2.5-0.5B-Instruct")
    ap.add_argument("--data", default="data/train.jsonl")
    ap.add_argument("--out", default="outputs/qwen05b-lora")
    ap.add_argument("--epochs", type=float, default=3.0)
    ap.add_argument("--batch_size", type=int, default=2)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--max_length", type=int, default=512)
    args = ap.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"[info] device={device}, model={args.model}")
    if device == "cpu":
        print("[warn] 未检测到 CUDA。入门微调请用 Colab/云 GPU；CPU 仅适合极小冒烟。")

    rows = load_jsonl(Path(args.data))
    texts = [build_text(r) for r in rows]
    ds = Dataset.from_dict({"text": texts})

    tok = AutoTokenizer.from_pretrained(args.model, trust_remote_code=True)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    def tokenize(batch):
        out = tok(
            batch["text"],
            truncation=True,
            max_length=args.max_length,
            padding=False,
        )
        out["labels"] = [ids[:] for ids in out["input_ids"]]
        return out

    tokenized = ds.map(tokenize, batched=True, remove_columns=["text"])

    model = AutoModelForCausalLM.from_pretrained(
        args.model,
        torch_dtype=torch.float16 if device == "cuda" else torch.float32,
        device_map="auto" if device == "cuda" else None,
        trust_remote_code=True,
    )
    if device == "cpu":
        model = model.to(device)

    lora = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        r=8,
        lora_alpha=16,
        lora_dropout=0.05,
        target_modules=["q_proj", "v_proj"],
    )
    model = get_peft_model(model, lora)
    model.print_trainable_parameters()

    train_args = TrainingArguments(
        output_dir=str(out_dir / "checkpoints"),
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        gradient_accumulation_steps=4,
        learning_rate=args.lr,
        logging_steps=5,
        save_steps=50,
        save_total_limit=1,
        fp16=device == "cuda",
        bf16=False,
        report_to=[],
        remove_unused_columns=False,
    )

    collator = DataCollatorForSeq2Seq(tokenizer=tok, model=model, padding=True)
    trainer = Trainer(
        model=model,
        args=train_args,
        train_dataset=tokenized,
        data_collator=collator,
    )
    trainer.train()

    model.save_pretrained(out_dir)
    tok.save_pretrained(out_dir)
    meta = {
        "base_model": args.model,
        "train_file": str(args.data),
        "n_samples": len(rows),
        "epochs": args.epochs,
    }
    (out_dir / "train_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"[done] LoRA adapter 已保存到 {out_dir}")


if __name__ == "__main__":
    # 避免 tokenizer 并行警告刷屏
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    main()
