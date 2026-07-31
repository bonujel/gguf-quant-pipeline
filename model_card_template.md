---
license: {{LICENSE}}
base_model: {{BASE_MODEL}}
tags:
  - gguf
  - quantized
  - llama.cpp
language:
  - en
  - zh
---

# {{MODEL_NAME}} GGUF

GGUF quantizations of [{{BASE_MODEL}}](https://huggingface.co/{{BASE_MODEL}}) for local inference
with llama.cpp, Ollama, and LM Studio. All quants are produced with an importance matrix
(imatrix) calibrated on a mixed English / Chinese / code corpus to improve low-bit quality.

## Quantizations

| Tier | Size | Notes |
|---|---|---|
| Q8_0 | {{SIZE_Q8_0}} | Near lossless |
| Q6_K | {{SIZE_Q6_K}} | Very high quality |
| Q5_K_M | {{SIZE_Q5_K_M}} | High quality |
| Q4_K_M | {{SIZE_Q4_K_M}} | Recommended balance of size and quality |
| IQ4_XS | {{SIZE_IQ4_XS}} | Compact, good quality |
| IQ3_M | {{SIZE_IQ3_M}} | Smaller, some quality loss |
| Q2_K | {{SIZE_Q2_K}} | Smallest, largest quality loss |

## Usage

```bash
llama-cli -m {{MODEL_NAME}}-Q4_K_M.gguf -p "Hello"
```

Or load the `.gguf` file directly in Ollama or LM Studio.

## Details

- Pipeline: `convert_hf_to_gguf.py --outtype bf16` → `llama-imatrix` → `llama-quantize --imatrix`.
- License inherited from the base model.
