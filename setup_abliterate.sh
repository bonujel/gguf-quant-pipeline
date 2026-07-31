#!/usr/bin/env bash
# setup_abliterate.sh — install the abliteration backend into a dedicated venv.
# Kept separate from the pipeline venv so its torch/transformers do not clash with the pinned
# huggingface_hub<1.0 used by GGUF conversion. Only needed for --abliterate. Requires a GPU.
#
# Installs the headless backend (torch/transformers/datasets/accelerate) used by abliterate.py.
# For the interactive Heretic tool (manual use only), also: pip install heretic-llm
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "==> abliteration venv: $ABLITERATE_VENV"
[ -d "$ABLITERATE_VENV" ] || python3 -m venv "$ABLITERATE_VENV"
# shellcheck disable=SC1091
source "$ABLITERATE_VENV/bin/activate"
pip install -q -U pip

echo "==> installing torch / transformers / datasets / accelerate"
pip install -q -U torch transformers datasets accelerate

echo "==> verify"
python -c "import torch, transformers, datasets; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())"
echo "==> ready. run with: bash run.sh <MODEL_ID> --abliterate"
