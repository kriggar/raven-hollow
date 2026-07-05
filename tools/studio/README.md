# RAVEN HOLLOW LOCAL STUDIO — free, offline, on the 5070 Ti (BACKLOG #95)

The studio's four pillars, all local, all $0 per token:

| Pillar | Engine | Status |
|--------|--------|--------|
| ART    | ComfyUI + SDXL + Pixel Art XL LoRA | ALREADY RUNNING (this box) |
| VOICE  | Maya1 TTS (C:\Users\vstef\tts)     | ALREADY RUNNING (173 lines shipped) |
| TEXT   | Ollama + Qwen2.5-Coder-14B (16GB card) | THIS TOOL |
| JUDGMENT | Fable 5 (review gates only)      | metered — spend on review, not production |

## Honest capability statement (owner asked for "Fable level" — read this)

A 16GB card runs 7B–14B models (32B quantized, slowly). **No local model
matches Fable's general intelligence, and no fine-tune on consumer hardware
can close that gap** — frontier models cost datacenter-scale training. Also,
training a model on Claude's outputs to replicate Claude is against
Anthropic's terms — we don't do that.

What IS achievable — and what this tool does — is **Fable-grade OUTPUT on
narrow roles** through three multipliers that don't need a big model:

1. **Scaffolding**: every role gets our committed style bibles + few-shot
   exemplars harvested from the repo. The model never writes "from taste" —
   it imitates canon-approved patterns.
2. **Validators**: nothing leaves the studio unchecked. JSON schemas, zone
   coordinate/type checks, the travel-seam validator, style lint. Fail →
   automatic retry with the error fed back. The validator, not the model,
   holds the quality bar.
3. **Specialization (optional)**: `finetune/` builds a QLoRA dataset from
   OUR OWN project corpus (defs, docs, quests, VO lines — your data) so a
   7B/14B speaks this project's conventions natively. That's "professional
   on OUR narrow roles", which is the honest version of "Fable level".

Division of labor (amends TASK_DIVISION.md): **LOCAL STUDIO does the bulk
production** (quests, barks, def data, item/loot tables, doc drafts).
**Fable reviews and integrates** (cheap: reading is cheaper than writing).
Billed Opus 4.8 only where local output repeatedly fails the QA gate, and
only after the credit reset.

## Setup (one time, ~10 min)

```powershell
winget install Ollama.Ollama          # or https://ollama.com/download
ollama pull qwen2.5-coder:14b         # ~9GB, fits 16GB VRAM w/ room
ollama pull qwen2.5:7b                # fast prose fallback
```

## Use

```powershell
# one task
python tools/studio/studio.py quest_writer "A daily quest in the Salt Fens about a drowned fence line" -o _downloads/_studio/quest1.json
# batch (JSONL of {"role": ..., "task": ...})
python tools/studio/studio.py --batch tasks.jsonl -o _downloads/_studio/
```

Roles: `quest_writer`, `bark_writer`, `def_author`, `item_smith`, `qa_triage`.
Output lands as validated JSON; Fable integrates on the next pass.
