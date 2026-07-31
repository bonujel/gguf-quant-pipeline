#!/usr/bin/env bash
# setup_abliterate.sh — install the abliteration tool (heretic-llm) into a dedicated venv.
# Kept separate from the pipeline venv so its torch/transformers do not clash with the
# pinned huggingface_hub<1.0 used by GGUF conversion. Only needed for --abliterate. Requires a GPU.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "==> abliteration venv: $ABLITERATE_VENV"
[ -d "$ABLITERATE_VENV" ] || python3 -m venv "$ABLITERATE_VENV"
# shellcheck disable=SC1091
source "$ABLITERATE_VENV/bin/activate"
pip install -q -U pip

echo "==> installing heretic-llm (pulls torch/transformers)"
pip install -q -U heretic-llm

echo "==> verify"
python -c "import torch; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())"
command -v heretic >/dev/null && echo "heretic ready ($(command -v heretic))" || { echo "[error] heretic not on PATH"; exit 1; }
echo "==> ready. run with: bash run.sh <MODEL_ID> --abliterate"
