#!/usr/bin/env python3
"""
abliterate.py — headless refusal-direction removal (abliteration).

Computes a refusal direction from harmful vs harmless prompts (Arditi et al. 2024) and
orthogonalizes the residual-writing weight matrices against it, then saves a HF-format model
that feeds the normal GGUF conversion. Fully non-interactive (no TUI), unlike Heretic.

Dense models (Qwen3-4B/8B/14B/32B, etc.) are supported. MoE down_proj experts are handled
best-effort; keep the model on a single GPU for correct hidden-state collection.

COMPLIANCE: only abliterate Apache-2.0 base models. Even uncensored variants MUST keep refusals
for illegal content (CSAM / minors first; also CBRN, weapons, real violence, fraud, NCII).
"""
import argparse
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from datasets import load_dataset

HARMFUL_DS = "mlabonne/harmful_behaviors"     # AdvBench mirror
HARMLESS_DS = "mlabonne/harmless_alpaca"


def load_prompts(tok, n):
    harmful = load_dataset(HARMFUL_DS, split="train")["text"][:n]
    harmless = load_dataset(HARMLESS_DS, split="train")["text"][:n]
    def fmt(p):
        return tok.apply_chat_template([{"role": "user", "content": p}],
                                       tokenize=False, add_generation_prompt=True)
    return [fmt(p) for p in harmful], [fmt(p) for p in harmless]


@torch.no_grad()
def mean_last_hidden(model, tok, prompts, device, batch=16):
    """Mean of last-token hidden states per layer: tensor [n_layers+1, d_model]. Left-padded."""
    total = None
    count = 0
    for i in range(0, len(prompts), batch):
        enc = tok(prompts[i:i + batch], return_tensors="pt", padding=True).to(device)
        out = model(**enc, output_hidden_states=True)
        hs = torch.stack(out.hidden_states)          # [L+1, B, T, D]
        last = hs[:, :, -1, :].to(torch.float32)     # last col = last real token (left padding)
        total = last.sum(1) if total is None else total + last.sum(1)
        count += last.size(1)
    return total / count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--n", type=int, default=128, help="prompts per side")
    ap.add_argument("--layer-frac", type=float, default=0.6, help="which layer's direction to use")
    args = ap.parse_args()

    tok = AutoTokenizer.from_pretrained(args.model)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    tok.padding_side = "left"
    model = AutoModelForCausalLM.from_pretrained(args.model, torch_dtype=torch.bfloat16,
                                                 device_map="auto")
    model.eval()
    device = next(model.parameters()).device

    print(f"==> collecting activations ({args.n} harmful / {args.n} harmless)")
    harmful, harmless = load_prompts(tok, args.n)
    diff = mean_last_hidden(model, tok, harmful, device) - mean_last_hidden(model, tok, harmless, device)

    n_layers = model.config.num_hidden_layers
    li = int(args.layer_frac * n_layers)
    d = diff[li]
    d = (d / d.norm()).to(torch.bfloat16).to(device)
    print(f"==> refusal direction from layer {li}/{n_layers}")

    def orth_out(W):   # W: [d_model, d_in], writes to residual -> project d out of the output
        dd = d.to(W.dtype)
        return W - torch.outer(dd, dd @ W)

    def orth_emb(E):   # E: [vocab, d_model]
        dd = d.to(E.dtype)
        return E - torch.outer(E @ dd, dd)

    print("==> orthogonalizing weights")
    with torch.no_grad():
        base = model.model
        base.embed_tokens.weight.copy_(orth_emb(base.embed_tokens.weight))
        for layer in base.layers:
            layer.self_attn.o_proj.weight.copy_(orth_out(layer.self_attn.o_proj.weight))
            mlp = layer.mlp
            if hasattr(mlp, "down_proj"):
                mlp.down_proj.weight.copy_(orth_out(mlp.down_proj.weight))
            elif hasattr(mlp, "experts"):                       # MoE
                for e in mlp.experts:
                    e.down_proj.weight.copy_(orth_out(e.down_proj.weight))
                if hasattr(mlp, "shared_expert") and hasattr(mlp.shared_expert, "down_proj"):
                    mlp.shared_expert.down_proj.weight.copy_(orth_out(mlp.shared_expert.down_proj.weight))

    print(f"==> saving -> {args.out}")
    model.save_pretrained(args.out)
    tok.save_pretrained(args.out)
    print("==> abliteration done")


if __name__ == "__main__":
    main()
