# Project-corpus fine-tune (QLoRA on the 5070 Ti) — optional specialization

Goal (honest): make a 7B/14B local model speak THIS project's conventions
natively — zone-def schema, narrative registers, item budget math, bark tone —
so the studio's narrow roles need fewer retries and read like the house style.
This does NOT make the model "Fable"; the general-intelligence gap cannot be
trained away on 16GB. It makes it a specialist. We do not train on Claude
transcripts (Anthropic ToS); the dataset is the project's own shipped work:
committed defs, design docs, quest exemplars, VO lines — the owner's corpus.

## Recipe

1. `python tools/studio/finetune/build_dataset.py` → `_downloads/_studio/train.jsonl`
   (instruction pairs harvested from the repo; ~1-3k samples expected).
2. Train with Unsloth (fits 16GB):
   - base: `Qwen/Qwen2.5-Coder-7B-Instruct` (or 14B with 4-bit base, slower)
   - QLoRA 4-bit, r=16, alpha=32, lr 2e-4, 3 epochs, seq 4096, bs 1 + grad-accum 8
   - ~1-3h on the 5070 Ti for 7B
3. Export GGUF (`llama.cpp convert` → q4_K_M), `ollama create ravenhollow-7b -f Modelfile`,
   then `STUDIO_MODEL=ravenhollow-7b python tools/studio/studio.py ...`
4. Eval: run the studio validators over a held-out task list; adopt the tune
   only if first-try pass-rate beats the base model.
