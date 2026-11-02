# Colab 快速上手（约 30–60 分钟）

你本机没有 NVIDIA 独显时，用这个流程。

## 1. 打开 Colab

1. 打开 [Google Colab](https://colab.research.google.com/)
2. 菜单 **运行时 → 更改运行时类型 → T4 GPU**
3. 新建笔记本，按下面单元格依次执行

## 2. 检查 GPU

```python
!nvidia-smi
```

应能看到 Tesla T4 之类。

## 3. 准备代码与数据

**方式 A：从你的电脑上传 zip**

把本地 `llm_ft_bio_demo` 打成 zip，上传后：

```python
!unzip -q llm_ft_bio_demo.zip -d /content/
%cd /content/llm_ft_bio_demo
```

**方式 B：若已放到可访问的 git 仓库**

```python
# !git clone <你的仓库地址>
# %cd <仓库>/llm_ft_bio_demo
```

## 4. 安装依赖

```python
!pip -q install -U transformers datasets peft accelerate bitsandbytes
# Colab 常自带旧版 torchao，会与新 peft 冲突，二选一：
!pip -q install -U "torchao>=0.16.0"
# 若仍报错，可改用卸载（本入门 demo 不依赖 torchao）：
# !pip -q uninstall -y torchao
```

### 若出现 `Found an incompatible version of torchao ... only versions above 0.16.0`

说明 Colab 预装了旧 `torchao`（如 0.10.0），而新版 `peft` 要求 ≥0.16。在**新单元格**执行后，再重新跑训练：

```python
!pip -q install -U "torchao>=0.16.0"
# 或：
# !pip -q uninstall -y torchao
```

装完**不必重启也能试**；若还报同样错，再执行 **运行时 → 重新启动运行时**，重装依赖后重跑训练（模型权重一般还在缓存里，不会重新下满 1GB）。

## 5. 预览数据（Step 1）

```python
!python scripts/01_preview_data.py
```

## 6. 训练 LoRA（Step 2）

```python
!python scripts/02_train_lora.py \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --data data/train.jsonl \
  --out outputs/qwen05b-lora \
  --epochs 3 \
  --batch_size 2
```

首次会从 Hugging Face 拉模型，需能访问外网；若失败可换镜像或改用国内可下的同系模型名。

## 7. 对比效果（Step 3）

```python
!python scripts/03_infer_compare.py \
  --base Qwen/Qwen2.5-0.5B-Instruct \
  --adapter outputs/qwen05b-lora \
  --eval data/eval.jsonl \
  --limit 5
```

## 8. 把结果带回家（可选）

```python
!zip -r qwen05b-lora.zip outputs/qwen05b-lora
# 然后从 Colab 文件面板下载 zip
```

## 常见问题

| 现象 | 处理 |
|------|------|
| 找不到 CUDA | 运行时未选 GPU，改类型后重连 |
| 下载模型超时 | 换网络 / HF 镜像，或先 `huggingface-cli login` |
| OOM | 把 `--batch_size` 改为 1，或换 0.5B |
| 微调后仍胡说 | 正常：样本太少；先加到 100+ 条再训 |

## 今天学懂这三件事就够了

1. **数据**：`instruction/input/output` 才是微调的「教材」  
2. **LoRA**：只训很小一块适配器，省显存  
3. **对比推理**：用同一题看底座 vs 适配器，才叫验证
