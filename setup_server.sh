#!/usr/bin/env bash
# setup_server.sh —— 在目标服务器上准备环境（免 sudo）
# 建独立工作区 + venv，安装 hf/cmake，编译 llama.cpp（CPU-only）
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "==> 工作区: $WORK_DIR"
mkdir -p "$WORK_DIR"/{models_raw,gguf_master,imatrix,gguf_quant}

echo "==> Python venv"
if [ ! -d "$WORK_DIR/venv" ]; then python3 -m venv "$WORK_DIR/venv"; fi
# shellcheck disable=SC1091
source "$WORK_DIR/venv/bin/activate"
pip install -q -U pip
pip install -q -U "huggingface_hub[hf_transfer]" cmake ninja

echo "==> 拉取并编译 llama.cpp（CPU-only；-j 32 不抢满共享机）"
if [ ! -d "$LLAMA_CPP" ]; then
  git clone --depth 1 https://github.com/ggml-org/llama.cpp "$LLAMA_CPP"
fi
cd "$LLAMA_CPP"
pip install -q -r requirements.txt
cmake -B build -DGGML_NATIVE=ON
cmake --build build --config Release -j 32

echo "==> 校验工具"
for b in convert_hf_to_gguf.py build/bin/llama-imatrix build/bin/llama-quantize build/bin/llama-cli; do
  [ -e "$LLAMA_CPP/$b" ] && echo "  OK  $b" || { echo "  缺失 $b"; exit 1; }
done
echo "==> 环境就绪。下一步: bash quantize.sh"
