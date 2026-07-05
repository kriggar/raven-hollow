# BLUEPRINT #110 — THE PAINTER PROGRAM (local AI paints at the Fable bar)
Fable's final architecture for machine painting. Owner directive: remaining
budget goes here; Opus 4.8 executes; local GPU trains and runs everything.

## Why the exams failed — and the design answer
The 14B writes good STORY (quests ~90%) but cannot do SPATIAL REASONING
(global coordinates, footprints, density budgets). Big models are not the
fix (30B failed harder). THE FIX: never ask the model to do geometry.

    MODEL  = semantics only (what belongs together, which story, what mood)
    CODE   = all geometry (where things physically go, spacing, footprints)
    DATA   = Fable's 40 shipped zones teach the semantics (fine-tune)
    WALLS  = validators + render-probe reject anything substandard
    EYE    = owner/successor approves final integration (visual law)

## STAGE 0 — THE FABLE PATTERN LIBRARY (the quality guarantee)
OWNER LAW: towns must be FABLE QUALITY — so the machine never invents
geometry at all. Opus writes tools/studio/extract_patterns.py:
- Parse Fable's 40 shipped zone defs; group landmarks by proximity (<350px
  chain-linked) into ~150-250 NAMED CLUSTER TEMPLATES, each stored with:
  member types + EXACT relative offsets (Fable's hand, preserved to the
  pixel), biome, footprint radius, role tag (market|sacred|industry|
  dwelling|watch|grave|curiosity|dread), and source zone.
- Parametrization: count-scalable members (graves 6->12), jitter fields
  (+-12px), biome dressing swaps (same shape, native props), mirror/rotate
  where composition allows (never architecture rotation).
A generated town = Fable clusters, composed by the Stage C solver, dressed
by the model. The geometry floor is Fable-identical BY CONSTRUCTION.
The model's Stage A now SELECTS from the library (+ flavors + names +
vignette concepts); Stage B only fills gaps when no template fits, and
those fills face the hardest walls.

## Architecture: THE STAGED PAINTER (studio.py v3 — Opus builds)
Replace one-shot def_author with a 3-stage chain:

STAGE A — CONCEPT (model, tiny output, easy):
  input: zone brief + biome + Bible story rules
  output: {"clusters": [{"name": "the drowned chapel", "story": one line,
           "anchor_type": "manor", "mood": "grief", "size": "large",
           "placement_hint": "far-from-road|roadside|corner|center",
           "wants": ["graves","statue","lone_tree"]}] } — 4-8 clusters
  + {"vignettes": [{"kind","concept","attach_to": cluster_name}]}

STAGE B — CLUSTER FILL (model, per cluster, LOCAL coords 0-400 only):
  input: one cluster concept + allowed types + repetition law
  output: {"props": [{"type","dx","dy","count"?}]} — 3-9 props, offsets
  from cluster center. Small numbers, no global reasoning. One call per
  cluster (7 calls of ~200 tokens beats 1 call of 2,000 — faster AND better).

STAGE C — ASSEMBLY (pure python, zero model):
  1. Poisson-disc place cluster centers in zone bounds honoring:
     road polylines (roadside hint: 80-250px from road; far: >600px),
     seam gaps, other clusters (min 700px), zone margin 700px.
  2. Map local props -> global; resolve footprint collisions by radial
     relaxation (push apart along the offending axis, 5 iterations, using
     the type-aware radii ALREADY in the walls).
  3. Auto-place per-Bible extras code can own: lamps along roads every
     ~700px in settlements, chimney_smoke snapped to cottages/manors
     (+68,-285), edge decals — the mechanical Bible rules become code.
  4. Run the FULL walls; if a cluster fails, re-roll ITS placement (not
     the whole zone); if semantics fail, re-ask Stage B for that cluster.

STAGE D — RENDER PROBE (already built): render_draft.py -> studio_canvas
  boot -> screenshots -> (v2) local vision model (pull qwen2.5-vl or llava
  via ollama) answers a fixed checklist: buildings overlapping? big empty
  quadrants? props on roads? — auto-reject before any human looks.

## The fine-tune (teaches STAGE A/B taste from Fable's hand)
Dataset (Opus upgrades tools/studio/finetune/build_dataset.py):
- Decompose each of Fable's 40 zone defs into training pairs BOTH ways:
  * zone brief -> cluster concepts (reverse-engineer: group landmarks by
    proximity <350px = a cluster; name from composition; ~250 pairs)
  * cluster concept -> local prop offsets (per discovered cluster; ~250)
  * NEGATIVE pairs from sittings: "draft with defect X" -> critique text
    (the sitting findings JSONs are on disk: _screens/sitting2_findings.json)
- Target: 600-900 pairs. Train Qwen3-14B QLoRA (unsloth, 4-bit, r=16,
  lr 2e-4, 3 epochs, seq 4096) ~2-4h on the 5070 Ti. Export GGUF q4_K_M ->
  `ollama create ravenpainter`.
- EVAL GATE (adopt-if-better): 12 standard briefs (3 per continent arm,
  cave, capital, hamlet...) x base-model vs tuned: score = walls first-try
  pass-rate + probe pass-rate. Adopt only on strict improvement.

## Exam protocol (the owner's bar, repeatable)
The "Raven Hollow from scratch" exam + 3 more briefs, rendered and
screenshotted, judged against: (1) all four identity structures present,
(2) zero clipping (probe), (3) no dead quadrant, (4) story clusters
readable in the screenshot, (5) murder + curiosity sites present and
tonally right. Publish shots to _screens/painter_exams/ for the owner.

## Expectation (revised for the Pattern Library)
- Composition/geometry: FABLE-IDENTICAL by construction (the pieces are
  Fable's own placements, solver-composed under Bible rules).
- Zone-level read: at or near the bar (solver enforces Bible II/III/IV
  mechanically: anchors per quadrant, roads as spine, lamps, smoke, edges).
- Genuinely NEW set-pieces (a never-seen Black Spire): still need a mind —
  the model proposes, the owner/successor approves. The visual law stands.

## Build order for Opus 4.8 (authorized by owner, Max plan)
1. Stage C assembly solver (pure python, testable without any model).
2. Stage A/B prompts + chain in studio.py; exam with BASE qwen3:14b.
3. Dataset decomposer + training run + eval gate.
4. Vision-probe checklist (pull a local VL model).
5. Re-run the Raven Hollow exam; deliver screenshots to the owner.
Acceptance: exam screenshots pass walls+probe with zero clipping and no
empty quadrant, using ONLY local models at inference time.
