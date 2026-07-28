---
license: apache-2.0
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

本仓库是 [{{BASE_MODEL}}](https://huggingface.co/{{BASE_MODEL}}) 的 GGUF 量化版本，供 llama.cpp / Ollama / LM Studio 等本地推理工具使用。所有量化均使用 **importance matrix（imatrix）** 生成，校准语料为中英文加代码混合，以提升低比特档位的中文与代码质量。

## 量化档位

| 档位 | 体积 | 说明 |
|---|---|---|
| Q8_0 | {{SIZE_Q8_0}} | 近无损，质量上限 |
| Q6_K | {{SIZE_Q6_K}} | 高质量 |
| Q5_K_M | {{SIZE_Q5_K_M}} | 中高质量 |
| Q4_K_M | {{SIZE_Q4_K_M}} | **推荐**，体积与质量平衡点 |
| IQ4_XS | {{SIZE_IQ4_XS}} | 低比特高质量 |
| IQ3_M | {{SIZE_IQ3_M}} | 更小，质量略降 |
| Q2_K | {{SIZE_Q2_K}} | 极限压缩，质量下限 |

## 用法

```bash
llama-cli -m {{MODEL_NAME}}-Q4_K_M.gguf -p "你好"
# 或用 Ollama / LM Studio 直接加载对应 .gguf 文件
```

## 说明

- 量化流程：`convert_hf_to_gguf.py --outtype bf16` → `llama-imatrix` → `llama-quantize --imatrix`。
- 许可证继承基座模型（Apache-2.0）。
- 本量化由自建流水线产出，方法与校准公开透明。
