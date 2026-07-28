#!/usr/bin/env bash
# run_batch.sh —— 后台批处理：依次量化 30B MoE 与 Kimi-VL，均走 GPU imatrix。
# 用法：setsid bash run_batch.sh > ~/batch.log 2>&1 &
# 不用 set -e：即便前一个模型失败也继续跑下一个。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CUDA 运行库 + GPU 版编译产物
source /data0/quant-pipeline/cuda_env.sh 2>/dev/null || true
export WORK_DIR=/data0/quant-pipeline
export BUILD_DIR=build-cuda
export NGL=99
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
export MIN_FREE_GB=300          # /data0 有 7T，300G 保护线足够安全
cd "$SCRIPT_DIR"

echo "########## [1/2] Qwen/Qwen3-30B-A3B (MoE) $(date '+%F %T') ##########"
MODEL_ID=Qwen/Qwen3-30B-A3B PARALLEL=2 bash quantize.sh
echo "__30B_EXIT_$?__"

echo "########## [2/2] moonshotai/Kimi-VL-A3B-Thinking-2506 $(date '+%F %T') ##########"
MODEL_ID=moonshotai/Kimi-VL-A3B-Thinking-2506 PARALLEL=3 bash quantize.sh
echo "__KIMI_EXIT_$?__"

echo "########## 批处理结束 $(date '+%F %T') ##########"
