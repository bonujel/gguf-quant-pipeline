# gguf-quant-pipeline

Produce multi-tier, imatrix-calibrated GGUF quantizations of any HuggingFace model for local
inference with llama.cpp, Ollama, and LM Studio, and optionally publish them to HuggingFace.

## Features

- End-to-end: download → bf16 GGUF master → imatrix → parallel multi-tier quantization → verify.
- Seven tiers by default: `Q8_0 Q6_K Q5_K_M Q4_K_M IQ4_XS IQ3_M Q2_K`.
- Importance matrix calibrated on a mixed English / Chinese / code corpus.
- Disk safety guard: aborts a stage when free space drops below a threshold.
- One-command publishing to HuggingFace with an auto-generated model card.
- Clean GGUF metadata: imatrix and dataset are referenced by relative name, so no host paths leak.

## Requirements

- Linux, Python 3.10+, git, a C/C++ toolchain and CMake.
- Disk space for the model in flight (raw weights + bf16 master + quantized tiers).
- Optional: an NVIDIA GPU + CUDA toolkit for faster imatrix computation.

## Install

```bash
git clone https://github.com/bonujel/gguf-quant-pipeline
cd gguf-quant-pipeline
bash setup.sh            # venv, dependencies, CPU build of llama.cpp
bash setup_cuda.sh       # optional: CUDA toolkit + GPU build (build-cuda)
```

## Usage

```bash
# Quantize a model (outputs under $WORK_DIR/gguf_quant/)
bash run.sh Qwen/Qwen3-4B

# Quantize and publish to HuggingFace (run `hf auth login` first)
bash run.sh Qwen/Qwen3-4B --publish myorg/Qwen3-4B-GGUF

# Publish previously produced GGUFs on their own
MODEL_ID=Qwen/Qwen3-4B bash publish.sh myorg/Qwen3-4B-GGUF --dry-run
```

Use a CUDA build for large models:

```bash
source "$WORK_DIR/cuda_env.sh"
BUILD_DIR=build-cuda NGL=99 WORK_DIR=/path/to/disk bash run.sh Qwen/Qwen3-30B-A3B
```

## Configuration

All settings live in `config.sh` and can be overridden via environment variables.

| Variable | Default | Description |
|---|---|---|
| `MODEL_ID` | `Qwen/Qwen3-4B` | Source model repo id |
| `WORK_DIR` | `$HOME/quant-workspace` | Working directory (point at a disk with enough space) |
| `QUANT_TIERS` | seven tiers | Tiers to produce |
| `MIN_FREE_GB` | `80` | Abort a stage below this much free space |
| `CLEAN_RAW` | `1` | Delete raw safetensors after the bf16 master is built |
| `PARALLEL` | `4` | Tiers quantized in parallel (lower for large models) |
| `BUILD_DIR` | `build` | `build` (CPU) or `build-cuda` (GPU) |
| `NGL` | empty | GPU layers for imatrix/verify (set `99` with a CUDA build) |
| `HF_OWNER` | empty | Default owner for `publish.sh` short names |

## Scripts

| Script | Purpose |
|---|---|
| `setup.sh` | Create the venv, install dependencies, build llama.cpp (CPU) |
| `setup_cuda.sh` | Install CUDA toolkit and build a GPU llama.cpp (optional) |
| `run.sh` | Orchestrate quantize (+ optional publish) for one model |
| `quantize.sh` | Download, convert, imatrix, quantize, verify |
| `publish.sh` / `publish.py` | Upload GGUFs and a generated model card to HuggingFace |
| `prepare_calibration.py` | Build the imatrix calibration corpus |

## Output

- `gguf_quant/<model>-<tier>.gguf` — the quantized models.
- `timing-<model>.log` — per-stage timing and tier sizes.
