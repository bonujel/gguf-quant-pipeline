#!/usr/bin/env bash
# setup.sh — one-time environment setup (no sudo required).
# Creates the working directory and a venv, installs dependencies, and builds llama.cpp (CPU).
# For GPU-accelerated imatrix, run setup_cuda.sh afterwards.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "==> workdir: $WORK_DIR"
mkdir -p "$WORK_DIR"/{models_raw,gguf_master,imatrix,gguf_quant}

echo "==> python venv"
[ -d "$WORK_DIR/venv" ] || python3 -m venv "$WORK_DIR/venv"
# shellcheck disable=SC1091
source "$WORK_DIR/venv/bin/activate"
pip install -q -U pip
# huggingface_hub is pinned <1.0: the 1.x line breaks transformers' dependency check, which
# makes `import transformers` fail inside convert_hf_to_gguf.py.
# tiktoken/blobfile are needed to convert models that use a tiktoken tokenizer (e.g. Kimi).
pip install -q -U "huggingface_hub>=0.34,<1.0" hf_transfer cmake ninja tiktoken blobfile

echo "==> clone and build llama.cpp (CPU, -j 32)"
[ -d "$LLAMA_CPP" ] || git clone --depth 1 https://github.com/ggml-org/llama.cpp "$LLAMA_CPP"
cd "$LLAMA_CPP"
pip install -q -r requirements.txt
# requirements.txt may pull huggingface_hub back to 1.x; re-pin for reproducibility.
pip install -q "huggingface_hub>=0.34,<1.0" hf_transfer
cmake -B build -DGGML_NATIVE=ON
cmake --build build --config Release -j 32

echo "==> verify tools"
for b in convert_hf_to_gguf.py build/bin/llama-imatrix build/bin/llama-quantize build/bin/llama-cli; do
  [ -e "$LLAMA_CPP/$b" ] && echo "  ok  $b" || { echo "  missing $b"; exit 1; }
done
echo "==> ready. next: bash run.sh <MODEL_ID>"
