#!/usr/bin/env python3
"""
publish.py — upload a set of GGUF files and a generated model card to a HuggingFace repo.

Renders model_card_template.md with the base model and per-tier sizes, then uploads the
GGUF files and the card. Uses hf_transfer for fast large-file uploads.

Auth: run `hf auth login` first, or set the HF_TOKEN environment variable.

Example:
  python publish.py --repo myorg/Qwen3-4B-GGUF --base-model Qwen/Qwen3-4B \
      --quant-dir ./workspace/gguf_quant --model-name Qwen3-4B
"""
import argparse
import os
import re
import sys
from pathlib import Path

os.environ.setdefault("HF_HUB_ENABLE_HF_TRANSFER", "1")


def human(n: float) -> str:
    for unit in ("B", "K", "M", "G"):
        if n < 1024:
            return f"{n:.0f}{unit}" if unit == "B" else f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}T"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True, help="Target repo id, e.g. owner/Model-GGUF")
    ap.add_argument("--base-model", required=True, help="Source model repo id")
    ap.add_argument("--quant-dir", required=True, help="Directory containing the *.gguf files")
    ap.add_argument("--model-name", required=True, help="Basename prefix of the gguf files")
    ap.add_argument("--template", default=None, help="Model card template path")
    ap.add_argument("--license", default="apache-2.0")
    ap.add_argument("--gated", action="store_true", help="Gate the repo (request access)")
    ap.add_argument("--private", action="store_true", help="Create the repo as private")
    ap.add_argument("--dry-run", action="store_true", help="Render the card and list files, upload nothing")
    args = ap.parse_args()

    quant_dir = Path(args.quant_dir)
    ggufs = sorted(quant_dir.glob(f"{args.model_name}-*.gguf"))
    if not ggufs:
        print(f"[error] no GGUF files matching {args.model_name}-*.gguf in {quant_dir}", file=sys.stderr)
        return 1

    # Map tier -> human size for the card table.
    sizes = {}
    for f in ggufs:
        m = re.match(rf"{re.escape(args.model_name)}-(.+)\.gguf$", f.name)
        if m:
            sizes[m.group(1)] = human(f.stat().st_size)

    template = args.template or str(Path(__file__).parent / "model_card_template.md")
    card = Path(template).read_text(encoding="utf-8")
    card = card.replace("{{BASE_MODEL}}", args.base_model)
    card = card.replace("{{MODEL_NAME}}", args.model_name)
    card = card.replace("{{LICENSE}}", args.license)
    for tier, size in sizes.items():
        card = card.replace(f"{{{{SIZE_{tier}}}}}", size)
    # Blank out any tier placeholders that were not produced.
    card = re.sub(r"\{\{SIZE_[^}]+\}\}", "-", card)

    print(f"repo:        {args.repo}")
    print(f"base model:  {args.base_model}")
    print(f"gguf files:  {len(ggufs)} ({', '.join(sorted(sizes))})")
    print(f"gated:       {args.gated}   private: {args.private}")

    if args.dry_run:
        print("\n--- rendered model card (dry run) ---\n")
        print(card)
        print("\n--- files that would be uploaded ---")
        for f in ggufs:
            print(f"  {f.name}  ({human(f.stat().st_size)})")
        return 0

    from huggingface_hub import HfApi
    api = HfApi()
    api.create_repo(args.repo, repo_type="model", private=args.private, exist_ok=True)

    readme = quant_dir / "README.md"
    readme.write_text(card, encoding="utf-8")
    api.upload_file(path_or_fileobj=str(readme), path_in_repo="README.md",
                    repo_id=args.repo, commit_message="Add model card")

    for f in ggufs:
        print(f"[upload] {f.name} ({human(f.stat().st_size)}) ...")
        api.upload_file(path_or_fileobj=str(f), path_in_repo=f.name,
                        repo_id=args.repo, commit_message=f"Add {f.name}")

    if args.gated:
        api.update_repo_settings(repo_id=args.repo, gated="auto")

    print(f"\nDone: https://huggingface.co/{args.repo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
