#!/usr/bin/env bash
# quantize.sh — end-to-end GGUF quantization (download -> bf16 master -> imatrix -> tiers -> verify).
# Features: disk safety guard, per-stage timing, parallel quantization, clean GGUF metadata.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

RAW_DIR="$WORK_DIR/models_raw"; MASTER_DIR="$WORK_DIR/gguf_master"
IMATRIX_DIR="$WORK_DIR/imatrix"; QUANT_DIR="$WORK_DIR/gguf_quant"
mkdir -p "$RAW_DIR" "$MASTER_DIR" "$IMATRIX_DIR" "$QUANT_DIR"

DL_NAME="$(basename "$MODEL_ID")"           # name used for the download / raw weights
RAW_PATH="$RAW_DIR/$DL_NAME"
# Output name gets an -abliterated suffix when the uncensored variant is requested.
if [ "$ABLITERATE" = "1" ]; then MODEL_NAME="${DL_NAME}-abliterated"; else MODEL_NAME="$DL_NAME"; fi
ABLIT_PATH="$WORK_DIR/abliterated/$MODEL_NAME"
CONVERT_SRC="$RAW_PATH"                      # convert reads this; switched to ABLIT_PATH if abliterating
MASTER="$MASTER_DIR/${MODEL_NAME}-BF16.gguf"
IMATRIX_NAME="${MODEL_NAME}.imatrix"          # basename only — kept relative on the command line
IMATRIX="$IMATRIX_DIR/$IMATRIX_NAME"
CALIB="$WORK_DIR/calibration.txt"
LOG="$WORK_DIR/timing-${MODEL_NAME}.log"

CONVERT="$LLAMA_CPP/convert_hf_to_gguf.py"
IMATRIX_BIN="$LLAMA_CPP/$BUILD_DIR/bin/llama-imatrix"
QUANT_BIN="$LLAMA_CPP/$BUILD_DIR/bin/llama-quantize"
CLI_BIN="$LLAMA_CPP/$BUILD_DIR/bin/llama-cli"

[ -f "$WORK_DIR/venv/bin/activate" ] && source "$WORK_DIR/venv/bin/activate"
export HF_HUB_ENABLE_HF_TRANSFER=1

free_gb() { df --output=avail -BG "$WORK_DIR" | tail -1 | tr -dc '0-9'; }
guard_disk() {
  local f; f=$(free_gb)
  if [ "${f:-0}" -lt "$MIN_FREE_GB" ]; then
    echo "[abort] free disk ${f}GB < threshold ${MIN_FREE_GB}GB — stopping to protect the host." >&2
    exit 2
  fi
  echo "[disk] free ${f}GB (threshold ${MIN_FREE_GB}GB) ok"
}
stage()  { echo; echo "===== $* ====="; }
record() { printf '%-24s %6ss  free %sGB\n' "$1" "$2" "$(free_gb)" | tee -a "$LOG"; }

echo "model: $MODEL_ID" | tee "$LOG"
echo "workdir: $WORK_DIR" | tee -a "$LOG"
guard_disk

stage "1/6 download base model"
t0=$SECONDS
hf download "$MODEL_ID" --local-dir "$RAW_PATH"
record "download" $((SECONDS-t0)); guard_disk

if [ "$ABLITERATE" = "1" ]; then
  stage "1b abliterate (uncensored variant, tool=$ABLITERATE_TOOL)"
  t0=$SECONDS
  bash "$SCRIPT_DIR/abliterate.sh" "$RAW_PATH" "$ABLIT_PATH"
  record "abliterate" $((SECONDS-t0)); guard_disk
  CONVERT_SRC="$ABLIT_PATH"
  # Raw weights no longer needed once abliterated; drop them to save disk.
  if [ "$CLEAN_RAW" = "1" ]; then echo "[cleanup] removing raw safetensors: $RAW_PATH"; rm -rf "$RAW_PATH"; fi
fi

stage "2/6 convert to bf16 GGUF master (lossless)"
t0=$SECONDS
python "$CONVERT" "$CONVERT_SRC" --outtype bf16 --outfile "$MASTER"
record "convert_bf16" $((SECONDS-t0)); guard_disk

# Post-convert cleanup of the source safetensors.
if [ "$ABLITERATE" = "1" ]; then
  if [ "$KEEP_ABLIT_SAFETENSORS" != "1" ]; then
    echo "[cleanup] removing abliterated safetensors: $ABLIT_PATH"; rm -rf "$ABLIT_PATH"; guard_disk
  fi
elif [ "$CLEAN_RAW" = "1" ]; then
  echo "[cleanup] removing raw safetensors: $RAW_PATH"; rm -rf "$RAW_PATH"; guard_disk
fi

stage "3/6 prepare calibration corpus"
[ -f "$CALIB" ] || python "$SCRIPT_DIR/prepare_calibration.py" "$CALIB"
echo "calibration: $(du -h "$CALIB" | cut -f1)"

stage "4/6 compute imatrix"
t0=$SECONDS
# Run from WORK_DIR and pass the calibration file by basename so the imatrix records a
# relative dataset name ("calibration.txt") instead of an absolute host path.
# shellcheck disable=SC2086
( cd "$WORK_DIR" && "$IMATRIX_BIN" -m "$MASTER" -f "$(basename "$CALIB")" -o "$IMATRIX" ${NGL:+-ngl $NGL} )
record "imatrix" $((SECONDS-t0)); guard_disk

stage "5/6 quantize tiers (parallel $PARALLEL)"
export QUANT_BIN IMATRIX_DIR IMATRIX_NAME MASTER QUANT_DIR MODEL_NAME
quant_one() {
  local tier="$1"; local out="$QUANT_DIR/${MODEL_NAME}-${tier}.gguf"; local t=$SECONDS
  # Run from IMATRIX_DIR and reference the imatrix by basename so the GGUF metadata
  # (quantize.imatrix.file) stores a relative name, not an absolute host path.
  if ( cd "$IMATRIX_DIR" && "$QUANT_BIN" --imatrix "$IMATRIX_NAME" "$MASTER" "$out" "$tier" ) >/dev/null 2>&1; then
    printf 'quant %-10s %5ds  %s\n' "$tier" "$((SECONDS-t))" "$(du -h "$out" | cut -f1)"
  else
    printf 'quant %-10s failed\n' "$tier"
  fi
}
export -f quant_one
printf '%s\n' "${QUANT_TIERS[@]}" | xargs -P "$PARALLEL" -I{} bash -c 'quant_one "$@"' _ {} | tee -a "$LOG"
guard_disk

stage "6/6 local verification (Q4_K_M)"
VAL="$QUANT_DIR/${MODEL_NAME}-Q4_K_M.gguf"
if [ -f "$VAL" ]; then
  # shellcheck disable=SC2086
  timeout 240 "$CLI_BIN" -m "$VAL" -p "Explain model quantization in one sentence." -n 96 -st -t 32 --no-warmup ${NGL:+-ngl $NGL} 2>/dev/null | tail -15 | tee -a "$LOG" \
    || echo "[verify] timed out or errored (produced GGUFs are still valid)" | tee -a "$LOG"
else
  echo "[warn] Q4_K_M output not found, skipping verification"
fi

stage "summary: tier sizes"
du -h "$QUANT_DIR/${MODEL_NAME}"-*.gguf 2>/dev/null | tee -a "$LOG"
echo; echo "timing/size log: $LOG"
echo "output dir: $QUANT_DIR"
