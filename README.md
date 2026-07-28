# gguf-quant-pipeline

对标 bartowski 的 GGUF 量化流水线：给一个 HuggingFace 模型出**多档位、带 imatrix**的 GGUF 量化，供 llama.cpp / Ollama / LM Studio 本地使用。

面向共享服务器设计，内置**磁盘硬保护**，避免撑爆共享根盘。

## 流程

```
下载基座(safetensors) → 转 GGUF 母版(bf16, 无损) → 算 imatrix(中英+代码校准)
   → 多档并行量化(Q8_0/Q6_K/Q5_K_M/Q4_K_M/IQ4_XS/IQ3_M/Q2_K) → 本地验证
```

## 快速开始

```bash
# 1. 拉取到服务器 ~ 目录
git clone https://github.com/bonujel/gguf-quant-pipeline ~/gguf-quant-pipeline
cd ~/gguf-quant-pipeline

# 2. 准备环境（建 venv、装 hf/cmake、编译 llama.cpp CPU-only）
bash setup_server.sh

# 3. 跑通（默认小模型 Qwen3-4B，安全）
bash quantize.sh

# 换模型 / 调档位 / 改工作区（大盘挂载后）：
MODEL_ID=Qwen/Qwen3-30B-A3B WORK_DIR=/data/quant-pipeline PARALLEL=2 bash quantize.sh
```

## 配置（config.sh，可用环境变量覆盖）

| 变量 | 默认 | 说明 |
|---|---|---|
| `MODEL_ID` | `Qwen/Qwen3-4B` | 目标模型 |
| `WORK_DIR` | `~/quant-pipeline` | 工作区；大盘挂载后改 `/data/...` |
| `MIN_FREE_GB` | `80` | **磁盘安全阈值**，低于即中止，护共享盘 |
| `CLEAN_RAW` | `1` | 转母版后删原始 safetensors 省盘 |
| `PARALLEL` | `4` | 并行量化进程数；大模型请调小 |
| `NGL` | 空 | CPU-only 留空；装 CUDA 后设 `99` 提速 |

## 安全约束（共享服务器）

- **磁盘硬保护**：每阶段检查可用空间，低于 `MIN_FREE_GB` 立即中止。
- **不发布**：本流水线只做本地产出与验证，不含上传。
- 大模型请：调小 `PARALLEL`、用挂载的大盘作 `WORK_DIR`、必要时逐档量化并上传后删除。

## 产物

- `gguf_quant/` 下各档 `.gguf`
- `timing-<model>.log`：逐阶段耗时与体积（关键交付物）
