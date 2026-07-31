#!/usr/bin/env bash
# run.sh — orchestrate the pipeline for one model: quantize, then optionally publish.
# Usage:
#   bash run.sh <MODEL_ID> [--publish <hf_repo_or_name>] [--gated] [--private]
# Examples:
#   bash run.sh Qwen/Qwen3-4B
#   bash run.sh Qwen/Qwen3-4B --publish myorg/Qwen3-4B-GGUF
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ $# -ge 1 ] || { echo "usage: bash run.sh <MODEL_ID> [--publish <repo>] [--gated] [--private]"; exit 1; }
export MODEL_ID="$1"; shift

PUBLISH=""
PUB_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH="$2"; shift 2 ;;
    --gated|--private|--dry-run) PUB_ARGS+=("$1"); shift ;;
    *) echo "[error] unknown argument: $1"; exit 1 ;;
  esac
done

source "$SCRIPT_DIR/config.sh"
if [ ! -x "$LLAMA_CPP/$BUILD_DIR/bin/llama-quantize" ]; then
  echo "[error] llama.cpp build not found at $LLAMA_CPP/$BUILD_DIR — run: bash setup.sh"; exit 1
fi

echo "==> quantize $MODEL_ID"
bash "$SCRIPT_DIR/quantize.sh"

if [ -n "$PUBLISH" ]; then
  echo "==> publish to $PUBLISH"
  bash "$SCRIPT_DIR/publish.sh" "$PUBLISH" "${PUB_ARGS[@]}"
fi

echo "==> done"
