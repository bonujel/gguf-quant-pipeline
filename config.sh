# config.sh — pipeline configuration. Every value can be overridden via environment variables.

# Target model (HuggingFace repo id).
MODEL_ID="${MODEL_ID:-Qwen/Qwen3-4B}"

# Working directory for downloads, the bf16 master and quantized outputs.
# Point this at a disk with enough free space; a large model needs hundreds of GB in flight.
WORK_DIR="${WORK_DIR:-$HOME/quant-workspace}"
LLAMA_CPP="${LLAMA_CPP:-$WORK_DIR/llama.cpp}"

# Which llama.cpp build to use: "build" (CPU) or "build-cuda" (GPU, pair with NGL=99).
BUILD_DIR="${BUILD_DIR:-build}"

# Quantization tiers to produce (high to low quality).
QUANT_TIERS=(Q8_0 Q6_K Q5_K_M Q4_K_M IQ4_XS IQ3_M Q2_K)

# Abort a stage when free space on WORK_DIR's filesystem drops below this many GB.
# A safety valve on shared hosts; raise it for very large models.
MIN_FREE_GB="${MIN_FREE_GB:-80}"

# Delete the raw safetensors after producing the bf16 master to save disk (1=delete, 0=keep).
CLEAN_RAW="${CLEAN_RAW:-1}"

# Number of tiers quantized in parallel. Lower it for large models.
PARALLEL="${PARALLEL:-4}"

# GPU layers offloaded for imatrix/verification. Empty for CPU-only builds; set 99 with a CUDA build.
NGL="${NGL:-}"

# --- Abliteration (uncensored variant) ---
# Enable to insert a refusal-removal (abliteration) step before GGUF conversion (1=on, 0=off).
ABLITERATE="${ABLITERATE:-0}"
# Tool used for abliteration: "heretic" (default, automatic, MoE-capable).
ABLITERATE_TOOL="${ABLITERATE_TOOL:-heretic}"
# Extra args passed through to the abliteration tool.
ABLITERATE_ARGS="${ABLITERATE_ARGS:-}"
# Keep the abliterated safetensors after the GGUF master is built (1=keep, 0=delete to save disk).
KEEP_ABLIT_SAFETENSORS="${KEEP_ABLIT_SAFETENSORS:-0}"

# --- Publishing (HuggingFace) ---
# Default owner used when a publish target is given without an explicit "owner/name".
HF_OWNER="${HF_OWNER:-}"
# Repo id suffix for GGUF repositories (community convention).
HF_REPO_SUFFIX="${HF_REPO_SUFFIX:--GGUF}"
