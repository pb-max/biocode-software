# 生物信息 · 抗体/药物向：大模型微调入门 Demo

面向：**已经会调 API**，想第一次真正做一次「微调」的生物信息从业者。  
本机若无 NVIDIA 独显：在 **Google Colab / AutoDL** 上训练；本仓库负责数据与脚本。

---

## 你将完成什么

做一个极小任务：**抗体 / 表位 / 药物靶点相关的简短问答**（教学用假数据，勿用于临床决策）。

| 步骤 | 内容 | 要不要 GPU |
|------|------|------------|
| 0 | 搞清：微调 vs RAG，什么时候该微调 | 否 |
| 1 | 准备 JSONL 训练数据并预览 | 否 |
| 2 | 用 LoRA 微调小模型（推荐 Colab T4） | 云端 GPU |
| 3 | 对比「微调前 / 微调后」同题回答 | 云端即可 |

推荐底座（入门够用）：**Qwen2.5-0.5B-Instruct**（显存友好，免费 Colab 也能跑）。

---

## 目录

```
llm_ft_bio_demo/
├── README.md                 # 本说明
├── data/
│   ├── train.jsonl           # 训练集（instruction / input / output）
│   └── eval.jsonl            # 评测题
├── scripts/
│   ├── 01_preview_data.py    # 本地预览数据
│   ├── 02_train_lora.py      # LoRA 监督微调
│   └── 03_infer_compare.py   # 对比推理
└── notebooks/
    └── colab_quickstart.md   # Colab 一键步骤
```

---

## Step 0：先想清楚（2 分钟）

| 需求 | 更合适的做法 |
|------|----------------|
| 知识常更新、要查文献/数据库 | **RAG**（检索增强），不必先微调 |
| 固定短答格式、术语口径、公司内部话术 | **微调（SFT + LoRA）** 很合适 |
| 要学会「什么叫微调」 | 做完本 demo 即可，数据量故意很小 |

本 demo 教你 **SFT（监督微调）+ LoRA（只训少量适配参数）**，不是全参训练，也不是 RLHF。

---

## Step 1：看懂数据格式（本机，无 GPU）

每行一个 JSON，字段：

```json
{"instruction":"任务说明","input":"具体问题","output":"期望回答"}
```

预览：

```bash
cd /media/ubuntu/b_disk/peibing/rscript_test/llm_ft_bio_demo
python3 scripts/01_preview_data.py
```

**作业**：在 `data/train.jsonl` 里自己加 5～10 条真实业务问法（抗体命名、ELISA、靶点别名等），再跑一遍预览。

---

## Step 2：云端微调（推荐 Colab）

打开 `notebooks/colab_quickstart.md`，按里面的顺序：

1. 上传本文件夹或 `git clone`  
2. 安装依赖  
3. 运行 `02_train_lora.py`  
4. 得到 `outputs/qwen05b-lora/`

本地有 NVIDIA 时也可直接：

```bash
pip install -U transformers datasets peft accelerate bitsandbytes torch
python scripts/02_train_lora.py --data data/train.jsonl --out outputs/qwen05b-lora
```

---

## Step 3：对比效果

```bash
python scripts/03_infer_compare.py \
  --base Qwen/Qwen2.5-0.5B-Instruct \
  --adapter outputs/qwen05b-lora \
  --eval data/eval.jsonl
```

看同一道题：底座是否胡编、微调后是否更贴你的 `output` 口径。

---

## 安全与科研诚信

- 数据为**教学合成**，回答不能当诊断/用药依据。  
- 真实项目请用内部脱敏数据，并遵守序列/临床数据合规。  
- 生物事实务必人工抽检；微调不能消灭幻觉，只能「更像你的标注」。

---

## 学完后的下一跳（按兴趣选）

1. 把任务改成：**从摘要抽靶点 / 抗体种属 / 适应症**（结构化输出）  
2. 数据扩到 200～1000 条，换 **1.5B / 3B**  
3. 同一批文档先做 **RAG**，再和微调对比  
4. 了解 **QLoRA**（4bit）以便更大模型

有问题就带着报错日志继续问；建议严格按 Step 1 → 2 → 3 顺序做。
