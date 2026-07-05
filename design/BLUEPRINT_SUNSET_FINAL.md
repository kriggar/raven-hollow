# SUNSET FINAL BLUEPRINTS — #67 · #68 · #50 · #51 · #53 (compact, build-ready)

## #67 DROVA VISIBILITY FOG (2D line-of-sight)
Screen-space fog that hides what the player couldn't see: a CanvasLayer
(under HUD, over world) with a full-screen ColorRect + shader:
  uniform player_screen_pos, occluder_tex (viewport), fog_color per zone.
V1 (cheap, ships): RADIAL soft visibility — fog alpha 0 within r1(260px),
ramps to max_fog (zone-keyed 0.35-0.85) by r2(560px); NO raycasts. Night +
dread zones raise max_fog; town/last_hearth near 0. Data: def key
"vis_fog": 0.0-1.0 (default by biome: caves 0.85, deadforest 0.6, fields
0.35). V2 (true LOS): SubViewport renders LightOccluder2D shapes to a mask;
shader samples mask along the ray to player (16 steps) — occluded px get
max fog. The occluders ALREADY exist on buildings (sitting-1 work). Build
V1 -> ship -> V2 behind a flag. Acceptance: fog follows player smoothly
60fps; per-zone strengths; screenshots at cave/forest/town.

## #68 D2 BEHIND-TEXTURE TRANSPARENCY (occluding sprites fade)
When the player walks behind a tall sprite, it goes ~55% translucent, D2
style. Implementation: on tall world sprites (buildings, trees w/ canopy,
keeps — anything sorted with texture height > 90px), main creates one
shared Area2D per sprite at build time? NO — cheaper: a single check in
player._physics_process every 0.15s: query the y-sort parent's children
within 200px; for each Sprite2D whose rect CONTAINS player_pos AND whose
sort-y > player-y (sprite in front of player), tween modulate.a -> 0.55;
restore others -> 1.0. Cache the candidate list per zone build (only tall
sprites; the builder tags them: spr.set_meta("tall", true) in _sprite when
tex height > 90 — one line). Cap: 6 faded at once. Acceptance: walk behind
blestem keeps/trees — player silhouette readable; no flicker (hysteresis
0.2s); perf flat.

## #50 THE GREAT BATTLE — "The Second Cooperation" (GREAT_BATTLE.md canon)
Structure: a dedicated event ZONE (copy famine_fields def, "battle": true)
+ battle_director.gd (autoload, state machine): STAGING (allied NPCs form
lines — npc.gd shells with formation offsets; barks) -> WAVES 1-3 (Combat
spawns scripted packs at gates; allied AI = simplified enemy.gd on team 2
fighting team 1 — add "team" to enemy cfg + faction check in targeting)
-> LULL beats (dialogue + repositions) -> CHAMPION duel (boss w/ telegraphs)
-> RESOLUTION (state writes quest flag; zone reverts to normal def after).
Fable's staging notes: lines break THROUGH the granary vignette (bread
everywhere, hunger anyway — the fields' horror pays off); the twelve stand
on the hill UNMOVING the whole battle (dread anchor); victory is quiet, no
fanfare — soup is served (Witcher heavy-cheerful law).
Build order: team targeting -> ally shells -> wave scripting -> duel ->
beats. Acceptance: full battle video, 60fps with 40+ combatants (cap
per-frame spawns; reuse pack separation).

## #51 CINEMATICS — 6 D2-style films + in-world system (CINEMATICS.md)
In-world system v1 (ships first): cinematic_player.gd — letterbox bars
(two black ColorRects tween in), camera path (Path2D + tween along points,
zoom keys), actor scripting (move npc/enemy shells along paths, play
anims), timed captions (Alagard, bottom-center), VO via voice_client,
skip on [ESC]. Data: data/cinematics/<id>.json {shots:[{cam:[pts], zoom,
dur, captions:[], vo:[], actors:[]}]}. Quest engine hook already specced
(#27 step kind "cinematic").
The 6 films (act intros per CINEMATICS.md): produce as SLIDE FILMS v1 —
ComfyUI stills (local, free; house palette prompts per doc) + Ken-Burns
pan/zoom + Chronicler VO (Maya1) + score stem. film_player.gd: fullscreen
TextureRect sequence w/ crossfade; assets data/films/act1/*.png + vo.ogg.
Acceptance: film 1 (opening) plays start->menu->game; skippable; in-world
cinematic fires from a test quest.

## #53 ADAPTIVE SCORE — MusicDirector (SCORE_BIBLE.md: C–E♭–D motif)
music_director.gd (replaces the flat _music player in main): 4 layered
AudioStreamPlayers (bed / melody / tension / percussion), all playing the
same-length stems synced, volumes tweened by GAME STATE: exploration (bed+
melody), combat enter (tension+perc up 1.2s), boss (all + boss stem),
dread zones (bed only + detune v2), town (melody variant). Zone key:
REGION_MUSIC becomes REGION_STEMS {region: {bed, melody, tension, perc}}.
Stems: produced LOCALLY from existing themes: split via demucs? NO —
simpler: studio composes NEW 4-stem loops per region: v1 = existing theme
as "melody" + synthesized pads/percussion beds (owner has no DAW: generate
with local tools — musicgen-small runs on the 5070 Ti — or layer the
EXISTING themes at different volumes/filters via pydub lowpass for bed:
cheap, honest v1). Motif law: the C–E♭–D cell must open every melody stem
(SCORE_BIBLE). Crossfade on zone change (4s), never hard-cut (the ferry
gets its own crossing sting). Acceptance: combat in/out layers audibly
shift in a video; motif present in every region melody (audio_qa.py gains
a motif check: first 8 melody notes contain the cell — spectral peak check
on C/E♭/D bins; mark advisory not blocking).

ALL FIVE: registry statuses flip 📐 when this commits. S1 COMPLETE.
