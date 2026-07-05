# BLUEPRINT #33 — COMBAT RETUNE (archetypes, telegraphs, TTK law, XP-to-60)
Fable design, Opus executes. Canon: COMBAT_PACING.md (TTK 8-15s law, the
INVULN blocker we already fixed, zone level bands).

## The five enemy archetypes (enemy.gd additive fields, data-driven)
Add to creature_table entries: "archetype": one of
1. RUSHER  — high speed, low hp, no telegraph, flanks (wolves, rogues)
2. BRUISER — slow, high hp, TELEGRAPHED heavy swing (skeleton_warrior, boars)
3. CASTER  — stationary-ish, CAST BAR projectile, interruptible (mages, shamans)
4. LURKER  — stealth-adjacent: idles disguised (still), aggro at 90px,
             burst opener then RUSHER pattern (Listeners, the Walled!)
5. SWARM   — pack ≥3, individually weak, pack-bonus speed when 3+ alive
Existing types map: wolf→RUSHER/SWARM, skeleton→BRUISER-lite,
skeleton_warrior→BRUISER, mages/shamans→CASTER, rogues→RUSHER,
"standing" units (Entranced Pilgrim, The Walled)→LURKER.

## Telegraph system (the feel core — enemy.gd)
- BRUISER: 0.55s windup — sprite leans (rotation -0.12), red-tint pulse
  modulate lerp, ground arc decal (Polygon2D 90° wedge, alpha 0.35) showing
  the hit area; dodge = walk out of wedge. Hit applies 2.2x damage.
- CASTER: cast bar above head (ColorRect pair, 0.9s), interrupted by any
  hit ≥ N damage (N = level scaled) → 1.5s stagger. Projectile reuses the
  existing spell VFX pipeline (per-creature unique VFX per mandate #56).
- LURKER: disguise = no name/healthbar until aggro; opener does 1.6x.
- Timing law: every avoidable hit has ≥0.45s visible warning. NEVER
  instant-damage from off-screen (spawn aggro radius ≤ screen width).

## TTK law wiring (numbers, not code)
Player TTK vs even-level single: 8-15s → per-zone creature_table hp/damage
recompute: hp = base_hp(archetype) * band_scalar(zone_band),
dmg = base_dmg * band_scalar. Bands per ZONE_QUEST_MATRIX (border 1-10,
west 8-18, north 16-30, east 26-40, south 36-50, coast 45-60, caves +3).
Opus writes tools/retune_tables.py: reads bands table (in this file, below),
rewrites every creature_table numerically, prints diff for review.
BAND_SCALARS (hp,dmg): 1-10 (1.0,1.0) · 8-18 (1.7,1.4) · 16-30 (3.0,2.1)
· 26-40 (5.2,3.0) · 36-50 (8.8,4.2) · 45-60 (14.0,5.6) · elite ×2.6 hp ×1.5 dmg.
Player-side: XP-to-60 curve already specced (~2.54M, slow-classic — Quests
give ~62%, kills ~30%, discovery ~8%). Kill XP: 45 * band_mid * (enemy_level
- player_level clamp ±5 penalty curve, WoW-style grey-out at -8).

## AI improvements (enemy.gd, small + safe)
- Leashing: reset + full heal beyond 1400px from spawn (stops kiting-to-town).
- Pack cohesion: SWARM members share aggro within 400px.
- CASTER kiting: keeps 240-340px, backs away at <180px (nav-safe: reuse
  existing wander/separation steering from the farm-pen work).
- De-clump: separation force already exists for animals — apply to all packs.

## Build order for Opus
1. retune_tables.py + numeric pass (review diff, commit). No behavior change.
2. Archetype field + BRUISER telegraph (wedge + windup) on skeleton_warrior;
   test in wilderness via RH_CAST harness + video.
3. CASTER cast bar + interrupt + stagger. 4. LURKER disguise/opener.
5. SWARM pack bonus + shared aggro + leashing for all.
6. XP curve hookup + grey-out. 7. Full-zone sweep: TTK probe script
   (tools/ttk_probe.py: RH_CAST auto-attack dummy per zone, log kill times)
   — acceptance: median TTK in 8-15s band per zone, no zone off by >20%.
POTHOLE: INVULN_TIME is 0.18 now — telegraphed 2.2x hits must NOT double-tick
through it (single damage event). POTHOLE: frozen-file law — enemy.gd is NOT
frozen (verify header) but Quests/DayNight are; touch nothing frozen.
Effort: 2 Opus sessions + 1 review pass.
