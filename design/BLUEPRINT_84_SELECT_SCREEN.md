# BLUEPRINT #84 — D2-STYLE CLASS/RACE SELECT SCREEN
Fable design, Opus builds (after animated class sprites land). Canon:
lore races (Humans/Angel Wings, Strigoi, Varcolaci, Iele, Szadi...),
7 classes (warrior/rogue/mage/druid/...), TALENTS_SPELLS + STARTING_ZONES.

## The D2 feel (reference: Diablo 2 char select)
- Dark atmospheric backdrop (our gothic palette), torch/brazier light.
- Central PEDESTAL: chosen class stands, IDLE-ANIMATED (uses the animated
  char sheets from the video-gen pipeline), slow torch flicker on it.
- Row of class silhouettes/portraits along bottom or side; hover = that
  class walks forward / lights up (D2 hovered-hero-animates).
- Selecting a class: its hero animates a signature move (rogue = dagger
  flourish, mage = cast spark), name + title fades in.
- PANEL (right): class fantasy blurb (2-3 lines, NARRATIVE_VOICE register),
  playstyle tags, starting kit, 3 signature abilities w/ icons + concrete
  tooltips (owner tooltip law), primary-stat bias bars.

## Race layer (owner: "showcasing what the class AND race does")
Two-step or combined: RACE pick modifies portrait + adds a racial trait
line + a passive (e.g. Varcolac: +move at night; Strigoi: sees live
stones; Iele: undead-adjacent resist). Race blurb from lore. Show the
racial passive concretely. Not all class/race combos need unique art v1:
race = tint/accessory swap on the class sprite + trait text (WYSIWYG-safe,
no transmog).

## Data (data/classes/*.json, data/races/*.json)
class: {id, name, title, blurb, playstyle:[], start_kit:[item_ids],
  signatures:[{ability_id, icon, tooltip}], stat_bias:{str,agi,int,vit,spr},
  idle_sheet, signature_sheet}
race: {id, name, blurb, passive:{name, effect, tooltip}, tint, accessory}

## Engine (scripts/select_screen.gd, replaces/precedes ClassSelect)
- CanvasLayer scene: backdrop + pedestal AnimatedSprite2D (plays idle/
  signature from the class sheet) + class row (TextureButtons) + info panel
  (RichTextLabel gothic) + race sub-row + CONFIRM.
- On confirm: writes chosen class+race into the New Game bootstrap
  (main._bootstrap_world takes class_id already; add race_id) → applies
  racial passive + stat bias at character init.
- Reuse ornate_ui kit (gold bezel) for panels; Alagard font.
- Music: menu theme; torch SFX loop.

## Build order (Opus, after animated sprites exist)
1. data schemas + 7 class JSONs + N race JSONs (studio drafts blurbs;
   Fable/owner voice-gate).
2. select_screen.gd static layout + info panel (no anim) — screenshot.
3. animated pedestal (idle) + hover-walk. 4. signature-move on select.
5. race sub-panel + passive wiring. 6. confirm -> bootstrap w/ race.
Acceptance: video of hovering each class (hero animates), reading its
blurb+abilities, picking a race (passive shows), confirm -> spawns in
the right starting pocket with the racial passive active. AAA-grade
screenshot the owner approves.

## Dependency
Needs animated class char sheets (video-gen pipeline) + ability icons
(have 54) + item art. Blocked until sprite library delivers class heroes.
