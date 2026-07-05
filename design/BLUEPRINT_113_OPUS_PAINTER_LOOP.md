# BLUEPRINT #113 — THE OPUS VISION-LOOP PAINTER (Fable-level towns, no Fable)
Owner directive: find a modality that paints at the Fable bar. Answer:
Opus 4.8 IS the painter — but in a render-see-fix loop, the way Fable
paints. Two tiers, pick per budget.

## Root diagnosis (proven by 2 failed exams)
Local 14B fails at COMPOSITION TASTE (what reads as a place, focal balance,
mood fit) — not vocabulary, not rendering. That taste is exactly what a
frontier model HAS and a 14B lacks. So: stop asking the 14B to have taste;
put the taste-holder (Opus) in the loop with EYES.

## TIER 1 — OPUS-AS-PAINTER (Fable-level, costs Opus tokens / Max plan)
The loop = how Fable actually paints:
  1. Opus drafts a layout JSON (it has real spatial+aesthetic judgment).
  2. render_draft.py -> studio_canvas -> boot -> OVERVIEW + CLOSE screenshots.
  3. Opus READS its own screenshots (native vision).
  4. Opus self-critiques vs LEVEL_PAINTING_BIBLE + the 5 owner laws
     (water-adjacency, real-art-not-colorrect, cluster coherence,
     no-partial-textures, mood fit) and REVISES the JSON.
  5. Loop 3-6 times until it passes the walls AND its own eye.
  6. Human (owner) approves final integration (visual law preserved).
This IS Fable's method; Opus can run it autonomously because it has both
the judgment and the vision to self-correct. Harness (tools/studio/
opus_paint_loop.py) just orchestrates draft->render->screenshot->feed-back;
the intelligence is the driving Opus agent. Cost: ~5-10 Opus vision turns
per town. Quality: Fable-adjacent (Opus taste + iteration + the walls).
USE FOR: capitals, hero towns, anything the player stares at. NOT the
1,000 filler pockets.

## TIER 2 — LOCAL, FREE, ASYMPTOTIC (already designed: #110)
Pattern Library (composes FABLE's placements, invents nothing) + fine-tune
+ flywheel + academy. Ceiling = the encoded doctrine, climbs nightly, $0.
USE FOR: bulk pockets, drafts Opus/owner then touches up. Never trusted
solo for hero content.

## THE ROUTING RULE (put in TASK_DIVISION)
Hero zone / capital / anything on a marketing shot  -> Tier 1 (Opus loop).
Filler pocket / bulk densification / first drafts   -> Tier 2 (local).
Final eye on BOTH  -> owner (visual law).
Fable, while alive: spot-reviews Tier-1 output, sets the Bible/laws Tier-2
trains on.

## Build order (Opus builder, running now)
1. opus_paint_loop.py: takes a brief + canvas size + biome, calls the
   DRIVING agent's own draft (the agent writes JSON to a path), renders,
   screenshots to _screens/painter_exams/opus/, returns the shot paths for
   the agent to view; agent revises; repeat until pass or N=6.
2. DEMONSTRATE: run the loop on (a) the bog fishing hamlet, (b) Raven
   Hollow from scratch. Deliver before/after screenshots to the owner —
   Tier 1 vs the horrendous Tier-2 attempts, side by side.
3. Wire the routing rule into TASK_DIVISION.md.
Acceptance: Tier-1 bog + RH read as real places at BOTH zoom levels, pass
all 5 owner laws, owner-gradeable as Fable-adjacent.
