#!/usr/bin/env bash
# abliterate.sh <input_model_dir> <output_dir>
# Remove the refusal direction from an instruct model (uncensored variant), producing a
# HuggingFace-format model directory that feeds into the normal GGUF conversion.
# Requires the abliteration tool to be installed (see setup_abliterate.sh).
#
# COMPLIANCE: only abliterate Apache-2.0 base models. Even "uncensored" variants MUST keep
# refusals for illegal content (CSAM / minors first, plus CBRN, weapons, real violence, fraud,
# non-consensual imagery). Publish gated + NFAA + disclaimer; prefer a non-corporate account.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

IN="${1:?usage: abliterate.sh <input_model_dir> <output_dir>}"
OUT="${2:?usage: abliterate.sh <input_model_dir> <output_dir>}"
mkdir -p "$(dirname "$OUT")"

# Run inside the dedicated abliteration venv (isolated from the pipeline venv).
[ -f "$ABLITERATE_VENV/bin/activate" ] || { echo "[error] abliteration venv missing; run setup_abliterate.sh"; exit 1; }
# shellcheck disable=SC1091
source "$ABLITERATE_VENV/bin/activate"

case "$ABLITERATE_TOOL" in
  heretic)
    # Heretic auto-benchmarks the machine, searches ablation configs with Optuna, and saves the
    # decensored model. Needs a GPU. `--save` writes the result to OUT.
    # shellcheck disable=SC2086
    heretic "$IN" --save "$OUT" $ABLITERATE_ARGS
    ;;
  *)
    echo "[error] unknown ABLITERATE_TOOL: $ABLITERATE_TOOL" >&2; exit 1 ;;
esac

[ -f "$OUT/config.json" ] || { echo "[error] abliteration did not produce a model at $OUT" >&2; exit 1; }
echo "[abliterate] done -> $OUT"
