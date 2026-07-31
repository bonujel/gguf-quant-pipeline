#!/usr/bin/env bash
# setup_cuda.sh — install the CUDA toolkit and build a GPU llama.cpp in build-cuda.
# Enables GPU-accelerated imatrix/verification (-ngl 99). Quantization itself stays on CPU.
# Installs the toolkit only (not the driver) and builds into a separate directory so the CPU
# build remains usable as a fallback. Requires sudo for the apt install.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

CUDA_VER="${CUDA_VER:-12-6}"          # apt package version (cuda-toolkit-12-6)
CUDA_ARCH="${CUDA_ARCH:-90}"          # GPU arch: 90 = Hopper (H100), 80 = A100, 89 = 4090
CUDA_HOME_GLOB="/usr/local/cuda-${CUDA_VER/-/.}"

echo "==> 1. install CUDA toolkit (toolkit only, driver untouched)"
if ! command -v nvcc >/dev/null 2>&1 && [ ! -x "$CUDA_HOME_GLOB/bin/nvcc" ]; then
  . /etc/os-release
  REPO="ubuntu${VERSION_ID//./}"     # 24.04 -> ubuntu2404
  echo "    distro repo: $REPO"
  TMP=$(mktemp -d)
  wget -q -O "$TMP/cuda-keyring.deb" \
    "https://developer.download.nvidia.com/compute/cuda/repos/$REPO/x86_64/cuda-keyring_1.1-1_all.deb"
  sudo dpkg -i "$TMP/cuda-keyring.deb"
  sudo apt-get -q update
  sudo apt-get -q -y install "cuda-toolkit-${CUDA_VER}"
  rm -rf "$TMP"
else
  echo "    nvcc/toolkit already present, skipping install"
fi

CUDA_HOME="$CUDA_HOME_GLOB"
[ -d "$CUDA_HOME" ] || CUDA_HOME="$(ls -d /usr/local/cuda-* 2>/dev/null | sort -V | tail -1)"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
export CUDACXX="$CUDA_HOME/bin/nvcc"
echo "==> CUDA_HOME=$CUDA_HOME"
nvcc --version | tail -2

# Write an env file to source when running the pipeline on GPU.
cat > "$WORK_DIR/cuda_env.sh" <<EOF
export PATH="$CUDA_HOME/bin:\$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:\${LD_LIBRARY_PATH:-}"
EOF
echo "==> wrote $WORK_DIR/cuda_env.sh"

echo "==> 2. build llama.cpp with CUDA into build-cuda (arch sm_${CUDA_ARCH})"
[ -f "$WORK_DIR/venv/bin/activate" ] && source "$WORK_DIR/venv/bin/activate"
cd "$LLAMA_CPP"
cmake -B build-cuda -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCH" -DGGML_NATIVE=ON
cmake --build build-cuda --config Release -j 32 --target llama-imatrix llama-quantize llama-cli

echo "==> 3. verify"
for b in build-cuda/bin/llama-imatrix build-cuda/bin/llama-quantize build-cuda/bin/llama-cli; do
  [ -x "$LLAMA_CPP/$b" ] && echo "  ok  $b" || { echo "  missing $b"; exit 1; }
done
echo "==> CUDA build ready. Run with:"
echo "    source \$WORK_DIR/cuda_env.sh"
echo "    BUILD_DIR=build-cuda NGL=99 bash run.sh <MODEL_ID>"
