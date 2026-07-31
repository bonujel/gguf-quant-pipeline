#!/usr/bin/env bash
# publish.sh — upload the GGUFs for one model to HuggingFace.
# Usage: bash publish.sh <hf_repo_or_name> [--gated] [--private] [--dry-run]
#   <hf_repo_or_name> may be "owner/Name-GGUF" or just "Name" (owner taken from HF_OWNER,
#   suffix appended from HF_REPO_SUFFIX).
# Auth: run `hf auth login` first, or export HF_TOKEN.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

[ $# -ge 1 ] || { echo "usage: bash publish.sh <hf_repo_or_name> [--gated] [--private] [--dry-run]"; exit 1; }
TARGET="$1"; shift

# Resolve repo id: accept "owner/name" as-is, otherwise build from HF_OWNER + suffix.
if [[ "$TARGET" == */* ]]; then
  REPO="$TARGET"
else
  [ -n "$HF_OWNER" ] || { echo "[error] set HF_OWNER or pass a full owner/name repo id"; exit 1; }
  REPO="$HF_OWNER/${TARGET}${HF_REPO_SUFFIX}"
fi

MODEL_NAME="$(basename "$MODEL_ID")"
QUANT_DIR="$WORK_DIR/gguf_quant"
[ -f "$WORK_DIR/venv/bin/activate" ] && source "$WORK_DIR/venv/bin/activate"

exec python "$SCRIPT_DIR/publish.py" \
  --repo "$REPO" \
  --base-model "$MODEL_ID" \
  --quant-dir "$QUANT_DIR" \
  --model-name "$MODEL_NAME" \
  "$@"
