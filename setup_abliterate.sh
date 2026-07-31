#!/usr/bin/env bash
# setup_abliterate.sh — install the abliteration tool (heretic-llm) into the pipeline venv.
# Only needed for the uncensored (--abliterate) variant. Requires an NVIDIA GPU.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

[ -f "$WORK_DIR/venv/bin/activate" ] || { echo "[error] venv not found; run setup.sh first"; exit 1; }
# shellcheck disable=SC1091
source "$WORK_DIR/venv/bin/activate"

echo "==> installing heretic-llm (pulls torch/transformers)"
pip install -q -U heretic-llm

echo "==> verify"
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())"
command -v heretic >/dev/null && echo "heretic ready ($(command -v heretic))" || { echo "[error] heretic not on PATH"; exit 1; }
echo "==> ready. run with: bash run.sh <MODEL_ID> --abliterate"
