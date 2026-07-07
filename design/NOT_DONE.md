# NOT DONE — honest, line-by-line list of every BACKLOG item NOT completed this session

Owner asked (2026-07-07) to verify the claim "everything is wired except art" and to
produce a super-detailed list of what was NOT done. Verified line-by-line against
the actual repo. **The claim was NOT fully accurate:** there are non-art, non-Ollama
items that were NOT done (#93, #94, part of #96). Full honest accounting below.

Each entry: item, WHY not done, and which exclusion category it falls in.
Categories: 🎨 ART (owner "except art" rule) · 🖥 OLLAMA/MACHINE (owner "no Ollama" rule)
· 🏗 ENGINE-REWRITE (barred by CLAUDE.md "no engine rewrites" — owner/Fable-only)
· 🆕 NOT-STARTED (in-lane and buildable, but I did not build it) · 🧩 PARTIAL (core done,
a remainder left).

---

## ❗ NON-ART / NON-OLLAMA items I did NOT do (the honest gaps)

### #93 — C++/native engine layer (level-design + studio-pipeline automation)
🏗 ENGINE-REWRITE. Not done. No `.cpp` / `.gdextension` / `SConstruct` exists.
WHY: CLAUDE.md "What the driver must NOT do" explicitly bars **engine rewrites** —
this is owner/Fable architecture, not the driver's lane. Building it would cross a
stated owner law. NEEDS: owner decision to authorize an engine-layer project.

### #94 — PROMPT-TO-GAME engine ("make me a 2D RPG about autumn" → builds on our engine)
🆕 NOT-STARTED (but genuinely in-lane and buildable). Not done. No generator exists.
WHY: it is a large, separate product (a text-prompt → assembled-scenario generator on
top of the existing engine). It is NOT art and NOT Ollama, so it does NOT fall under
the owner's exclusions — I simply did not build it. This is the ONE clearly-buildable
in-lane item still open. When asked to pick next work, the owner chose "polish shipped
systems" over this, so it remains open by choice, not by exclusion.

### #96 — Corporation-of-bots (partial: the non-art slice)
🖥 OLLAMA/MACHINE for most of it. Not done. The described pieces — godot-optimization
horde, 2D-pixel-design + audio study hordes, **playtest agents start-to-finish**, bots
with perfect navmesh + class rotations, race-vs-bots world-firsts — mostly need a local
model horde / Ollama and/or are art-study hordes. The one arguably-in-lane sliver
(scripted playtest/navmesh bots as pure GDScript) was NOT built. NEEDS: scoping — most
of it is machine-gated; the playtest-bot sliver is buildable but was not requested.

---

## 🎨 ART items NOT done (excluded by owner "except art" rule) — CORRECT to skip

- #56 VFX AAA plan (per-spell unique VFX art / ComfyUI generation)
- #57 Crafting ANIMATIONS from packs (station + character craft-bob sprites)
- #66 Prime-Mandate polish loop (zone visual composition — Fable-only visual law)
- #89 Replace sword sprites w/ real pack art + hand animation
- #90 Sprite×item full animation test matrix (every item on every character — art)
- #91 Scout assets fitting characters w/ animations (art sourcing, gauntlet-gated)
- #100 Witchbrook polish loop (zone painting — Fable-only visual law)
- #101 Grand asset scout (medieval asset sourcing for painting)
- #103 Capital-unique architecture KITS (distinct civic building sprites)
- #104 Creature pack integration + werewolf sprites (enemy art)
- #106 Sitting-#3 completion (visual inspector verifiers over zone screenshots)
- #109 The Painter Program (level-painting AI)
- #110 The Painter Program v2 (Fable pattern library / painter)
- #111 FULL ANIMATION STATES LAW (every sprite every anim — sprite art/animation)
- #112 Per-sprite animation verification + interpreter horde (sprite art QA)
- #113 The Opus vision-loop painter (level painting)
- #114 The 150k asset library (asset generation)
- #115 The Vision Gauntlet + generation council (asset-gen QA)
- #116 The static library marathon (asset generation, weeks of GPU)
- #117 Character img2img pipeline (sprite generation)
- #121 Model verdicts (image-gen model evaluation)
- #122 C: drive relief (moving AI/asset models off C: — asset-infra)

## 🖥 OLLAMA / MACHINE items NOT done (excluded by owner "no Ollama" rule) — CORRECT to skip

- #95 Local studio operations v1 (Ollama + qwen2.5-coder worker) — needs owner install
- #105 Local studio operations (owner installs Ollama, runs first batches)
- (#96 mostly — see above)

## 🧩 PARTIALS on otherwise-✅ items (small remainders, mostly art)

- #23 Asset Gauntlet — framework ✅ (roster_gen.py exists); "round 1 on 22 packs" is an
  asset-review RUN not executed (asset/art review → excluded).
- #24 Map masterpiece — Continent-1 map ✅; "draw Continent 2" is 🎨 art (map drawing).
- #85 Voice-per-NPC — assignment DATA ✅ + loader wired; the actual AUDIO BAKING of 384
  voices is a separate local-TTS (Maya1) run, NOT done here (not Ollama, but needs the
  TTS environment; the assignment system ships, the clips do not).

---

## ✅ What the "except art" claim GOT RIGHT

Every SYSTEMS / DATA / TEXT / UI-CODE / WIRING item is done and verified:
all foundation + governance (1–26), all systems (27–55, 58–75, 82–84, 86–88, 92,
97–99, 102, 107–108), and this session's content + wiring: #77 (1,161 quests total
after #78/#80/#81), #78 romance, #79 pipeline, #80/#81 mysteries+discoveries, #85 voice
data, plus the combat/loot integration, central Menu, boot-bug fixes, and the polish
pass (legendary procs, narrator beats, shop-on-greet, quest-marker dedup).

## THE HONEST BOTTOM LINE
"Everything except art is wired" is **~95% true, not 100%.** The exceptions that are
NOT art and NOT Ollama: **#93 (engine rewrite — barred by owner law), #94 (prompt-to-
game — buildable, not requested), the playtest-bot sliver of #96, and the audio-baking
tail of #85.** Everything else not done is correctly excluded as art or Ollama.
