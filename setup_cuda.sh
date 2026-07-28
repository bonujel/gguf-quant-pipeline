#!/usr/bin/env bash
# setup_cuda.sh —— 安装 CUDA toolkit 并用 CUDA 重编译 llama.cpp 到 build-cuda
# 目的：让 imatrix / 验证 能用 H100（-ngl 99）。量化步骤仍是 CPU（无 GPU 路径）。
# 只装 toolkit、不动驱动；编到独立目录，保留现有 CPU 版可回退。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

CUDA_VER="${CUDA_VER:-12-6}"          # apt 包版本号（cuda-toolkit-12-6）
CUDA_HOME_GLOB="/usr/local/cuda-${CUDA_VER/-/.}"

echo "==> 1. 安装 CUDA toolkit（仅 toolkit，不碰驱动）"
if ! command -v nvcc >/dev/null 2>&1 && [ ! -x "$CUDA_HOME_GLOB/bin/nvcc" ]; then
  . /etc/os-release
  REPO="ubuntu${VERSION_ID//./}"     # 24.04 -> ubuntu2404
  echo "    发行版 repo: $REPO"
  TMP=$(mktemp -d)
  wget -q -O "$TMP/cuda-keyring.deb" \
    "https://developer.download.nvidia.com/compute/cuda/repos/$REPO/x86_64/cuda-keyring_1.1-1_all.deb"
  sudo dpkg -i "$TMP/cuda-keyring.deb"
  sudo apt-get -q update
  sudo apt-get -q -y install "cuda-toolkit-${CUDA_VER}"
  rm -rf "$TMP"
else
  echo "    已存在 nvcc/toolkit，跳过安装"
fi

# 定位 CUDA 目录
CUDA_HOME="$CUDA_HOME_GLOB"
[ -d "$CUDA_HOME" ] || CUDA_HOME="$(ls -d /usr/local/cuda-* 2>/dev/null | sort -V | tail -1)"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
export CUDACXX="$CUDA_HOME/bin/nvcc"
echo "==> CUDA_HOME=$CUDA_HOME"
nvcc --version | tail -2

# 写一个环境文件，供流水线走 GPU 时 source
cat > "$WORK_DIR/cuda_env.sh" <<EOF
export PATH="$CUDA_HOME/bin:\$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:\${LD_LIBRARY_PATH:-}"
EOF
echo "==> 已写 $WORK_DIR/cuda_env.sh"

echo "==> 2. 用 CUDA 重编译 llama.cpp 到 build-cuda（H100=sm_90）"
# cmake 装在 venv 里，激活以便使用
[ -f "$WORK_DIR/venv/bin/activate" ] && source "$WORK_DIR/venv/bin/activate"
cd "$LLAMA_CPP"
cmake -B build-cuda -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=90 -DGGML_NATIVE=ON
cmake --build build-cuda --config Release -j 32 --target llama-imatrix llama-quantize llama-cli

echo "==> 3. 校验"
for b in build-cuda/bin/llama-imatrix build-cuda/bin/llama-quantize build-cuda/bin/llama-cli; do
  [ -x "$LLAMA_CPP/$b" ] && echo "  OK  $b" || { echo "  缺失 $b"; exit 1; }
done
echo "==> CUDA 版就绪。用法示例："
echo "    source $WORK_DIR/cuda_env.sh"
echo "    CUDA_VISIBLE_DEVICES=0 BUILD_DIR=build-cuda NGL=99 WORK_DIR=$WORK_DIR bash quantize.sh"
