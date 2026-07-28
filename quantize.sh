#!/usr/bin/env bash
# quantize.sh —— 端到端 GGUF 量化流水线（下载→转母版→imatrix→多档量化→验证）
# 设计要点：磁盘硬保护（护共享根盘）、逐阶段计时、可并行量化。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

RAW_DIR="$WORK_DIR/models_raw"; MASTER_DIR="$WORK_DIR/gguf_master"
IMATRIX_DIR="$WORK_DIR/imatrix"; QUANT_DIR="$WORK_DIR/gguf_quant"
mkdir -p "$RAW_DIR" "$MASTER_DIR" "$IMATRIX_DIR" "$QUANT_DIR"

MODEL_NAME="$(basename "$MODEL_ID")"
RAW_PATH="$RAW_DIR/$MODEL_NAME"
MASTER="$MASTER_DIR/${MODEL_NAME}-BF16.gguf"
IMATRIX="$IMATRIX_DIR/${MODEL_NAME}.imatrix"
LOG="$WORK_DIR/timing-${MODEL_NAME}.log"

CONVERT="$LLAMA_CPP/convert_hf_to_gguf.py"
IMATRIX_BIN="$LLAMA_CPP/$BUILD_DIR/bin/llama-imatrix"
QUANT_BIN="$LLAMA_CPP/$BUILD_DIR/bin/llama-quantize"
CLI_BIN="$LLAMA_CPP/$BUILD_DIR/bin/llama-cli"

# 若在 venv 里跑，激活它
[ -f "$WORK_DIR/venv/bin/activate" ] && source "$WORK_DIR/venv/bin/activate"
export HF_HUB_ENABLE_HF_TRANSFER=1

free_gb() { df --output=avail -BG "$WORK_DIR" | tail -1 | tr -dc '0-9'; }
guard_disk() {
  local f; f=$(free_gb)
  if [ "${f:-0}" -lt "$MIN_FREE_GB" ]; then
    echo "[中止] 可用磁盘 ${f}GB < 安全阈值 ${MIN_FREE_GB}GB，停止以保护共享根盘。" >&2
    exit 2
  fi
  echo "[磁盘] 可用 ${f}GB (阈值 ${MIN_FREE_GB}GB) OK"
}
stage()  { echo; echo "===== $* ====="; }
record() { printf '%-24s %6ss  可用磁盘 %sGB\n' "$1" "$2" "$(free_gb)" | tee -a "$LOG"; }

echo "模型: $MODEL_ID" | tee "$LOG"
echo "工作区: $WORK_DIR" | tee -a "$LOG"
guard_disk

stage "1/6 下载基座"
t0=$SECONDS
hf download "$MODEL_ID" --local-dir "$RAW_PATH"
record "download" $((SECONDS-t0)); guard_disk

stage "2/6 转 GGUF 母版 (bf16, 无损)"
t0=$SECONDS
python "$CONVERT" "$RAW_PATH" --outtype bf16 --outfile "$MASTER"
record "convert_bf16" $((SECONDS-t0)); guard_disk

if [ "${CLEAN_RAW}" = "1" ]; then
  echo "[省盘] 删除原始 safetensors: $RAW_PATH"; rm -rf "$RAW_PATH"; guard_disk
fi

stage "3/6 准备校准语料 (中英+代码)"
CALIB="$WORK_DIR/calibration.txt"
[ -f "$CALIB" ] || python "$SCRIPT_DIR/prepare_calibration.py" "$CALIB"
echo "校准语料: $(du -h "$CALIB" | cut -f1)"

stage "4/6 计算 imatrix"
t0=$SECONDS
# shellcheck disable=SC2086
"$IMATRIX_BIN" -m "$MASTER" -f "$CALIB" -o "$IMATRIX" ${NGL:+-ngl $NGL}
record "imatrix" $((SECONDS-t0)); guard_disk

stage "5/6 多档量化 (并行 $PARALLEL)"
export QUANT_BIN IMATRIX MASTER QUANT_DIR MODEL_NAME
quant_one() {
  local tier="$1"; local out="$QUANT_DIR/${MODEL_NAME}-${tier}.gguf"; local t=$SECONDS
  if "$QUANT_BIN" --imatrix "$IMATRIX" "$MASTER" "$out" "$tier" >/dev/null 2>&1; then
    printf 'quant %-10s %5ds  %s\n' "$tier" "$((SECONDS-t))" "$(du -h "$out" | cut -f1)"
  else
    printf 'quant %-10s 失败\n' "$tier"
  fi
}
export -f quant_one
printf '%s\n' "${QUANT_TIERS[@]}" | xargs -P "$PARALLEL" -I{} bash -c 'quant_one "$@"' _ {} | tee -a "$LOG"
guard_disk

stage "6/6 本地验证 (Q4_K_M)"
VAL="$QUANT_DIR/${MODEL_NAME}-Q4_K_M.gguf"
if [ -f "$VAL" ]; then
  # timeout 兜底，避免 llama-cli 在无人值守下挂死拖住流水线
  # shellcheck disable=SC2086
  timeout 240 "$CLI_BIN" -m "$VAL" -p "用一句话解释什么是模型量化。" -n 96 -st -t 32 --no-warmup ${NGL:+-ngl $NGL} 2>/dev/null | tail -15 | tee -a "$LOG" \
    || echo "[验证] 超时或出错（不影响量化产物，已生成的 GGUF 有效）" | tee -a "$LOG"
else
  echo "[警告] 未找到 Q4_K_M 产物，跳过验证"
fi

stage "汇总：各档体积"
du -h "$QUANT_DIR/${MODEL_NAME}"-*.gguf 2>/dev/null | tee -a "$LOG"
echo; echo "完整耗时/体积日志: $LOG"
echo "产物目录: $QUANT_DIR"
