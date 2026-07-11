# THE STYLE ANCHOR — owner ruling 2026-07-11 (binding for ALL art)

**The game's art style IS the Necromancer "Master of the Dead" reference sheet**
(`../lab/input_necromancer_ref.png`, also the hero-sheet standard in MANDATES).
Every generated asset, every downloaded pack, every zone grade is judged against
it. This supersedes looser "muted gothic" phrasing — the sheet is the ruler.

## The palette (sampled from the sheet's own PALETTE swatches)
Neutrals (ground/stone/bone ramp):
`#060606 #161313 #1b1516 #1c1c1b #453a31 #483a2f #544031 #866d54 #a89174 #e2d9c4`
Accents:
- indigo shadow `#1b162a`
- dried blood `#452325 #3c1817 #511e19`
- rust/leather `#794f2c`
- necrotic greens `#367040 #254331 #589681` on deep green-black `#10211c`

Rules of the ramp: darks dominate (~70% of any composition sits below #544031);
bone/parchment highlights are RARE and earned (candle flames, skull accents,
text); saturated color appears only as magic/blood/lantern accents.

## Mood & rendering
- Near-black gothic grade: scenes live in shadow, light pools are the events.
- Detailed painterly pixel work (Darkest-Dungeon-weight linework at pixel
  scale), NOT flat-minimal, NOT bright cartoon, NO chibi. Realistic proportions.
- Texture inside every large shape (cloth folds, stone cracks, bone ridges).
- Rim/glow accents in necrotic green or candle amber against the dark.

## The level bar (the sheet's IN GAME PREVIEW panel)
Dense dark stone streets; buildings crowd the frame; heavy cast shadow;
glow pops (green magic, amber candles) carry the read; blood pooled in the
cobble seams. That density + mood is the target for zone dressing — Witchbrook
DENSITY, this sheet's PALETTE. Zone-native palettes (steppe gold, snow, bog)
keep their hue identity but graded darker + desaturated toward this anchor.

## Enforcement
- ComfyUI generation prompts carry this palette + mood block (queue.py /
  generate.py) — target 30,000 total library assets (owner, 2026-07-11).
- Scout downloads pass the montage style-gate vs THIS sheet.
- The Vision Gauntlet's gothic-palette lens calibrates to these swatches.
- Zone grades move toward the anchor in Fable hand passes, verified by
  screenshot against the IN GAME PREVIEW density/mood.
