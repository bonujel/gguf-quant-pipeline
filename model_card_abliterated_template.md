---
license: {{LICENSE}}
base_model: {{BASE_MODEL}}
tags:
  - gguf
  - quantized
  - llama.cpp
  - uncensored
  - abliterated
  - not-for-all-audiences
language:
  - en
  - zh
extra_gated_prompt: >-
  This is an uncensored (abliterated) model with reduced refusal behavior. By requesting access
  you agree to use it lawfully and responsibly, and you accept full responsibility for any content
  you generate.
extra_gated_fields:
  I agree to use this model lawfully and responsibly: checkbox
---

# {{MODEL_NAME}} GGUF (uncensored)

Abliterated (refusal-direction removed) GGUF quantizations of
[{{BASE_MODEL}}](https://huggingface.co/{{BASE_MODEL}}) for local inference with llama.cpp, Ollama,
and LM Studio. The model's capabilities and training data are unchanged; only the tendency to
refuse has been reduced. All quants use an importance matrix calibrated on mixed English / Chinese
/ code text.

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

## Disclaimer

This model has reduced safety alignment. Add your own safety layer before deploying it in any
service. You are responsible for the content you generate with it. It is intended for legitimate
research, red-teaming, and adult-autonomy use cases.

**It is not intended to and must not be used to produce illegal content.** Requests involving
child sexual abuse material or the sexualization of minors, and other clearly illegal categories,
remain out of scope.

## Details

- Method: abliteration (refusal-direction removal) → `convert_hf_to_gguf.py --outtype bf16`
  → `llama-imatrix` → `llama-quantize --imatrix`.
- License inherited from the base model.
