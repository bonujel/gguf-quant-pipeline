# config.sh —— 量化流水线配置（可用环境变量覆盖）
# 目标模型（先用小模型跑通；大盘挂载后再换 30B-A3B）
MODEL_ID="${MODEL_ID:-Qwen/Qwen3-4B}"

# 工作区（放模型/母版/量化产物）。大盘挂载后改成 /data/quant-pipeline
WORK_DIR="${WORK_DIR:-$HOME/quant-pipeline}"
LLAMA_CPP="${LLAMA_CPP:-$WORK_DIR/llama.cpp}"

# 量化档位（对标 bartowski，覆盖高/中/低质量）
QUANT_TIERS=(Q8_0 Q6_K Q5_K_M Q4_K_M IQ4_XS IQ3_M Q2_K)

# —— 磁盘安全（共享根盘，务必守住）——
# 工作区所在文件系统可用空间低于此值(GB)即中止，避免撑爆共享盘
MIN_FREE_GB="${MIN_FREE_GB:-80}"

# 转出 GGUF 母版后删除原始 safetensors 以省盘（1=删，0=留）
CLEAN_RAW="${CLEAN_RAW:-1}"

# 并行量化的进程数（小模型可并行；大模型请调小并配合逐档清理）
PARALLEL="${PARALLEL:-4}"

# GPU 层数：CPU-only 构建时留空；装了 CUDA 后设 NGL=99 提速 imatrix/验证
NGL="${NGL:-}"
