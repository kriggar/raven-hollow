# RAVEN HOLLOW — LEGENDARY WEAPON QUESTLINES & THE NO-TRANSMOG VISUAL GEAR SYSTEM
**7 class legendaries, Thunderfury-style multi-stage epics · what you wear IS what you see · cap 60 · Draconia canon.**

> *"The stone doesn't need to possess you — it just needs your ambition to point the right way."* — Valrom, Part V.
> A legendary weapon is the most pointed ambition in the game. Every questline below knows it.

**Composes with (law):** `design/QUEST_ARCHITECTURE.md` (schema v2, villain grammar, tone law),
`design/ITEM_PROGRESSION.md` (budget math §2, extension keys §2.1, "legendary is never a random
roll" §1), `design/COMBAT_PACING.md` (player ref curves, elite/rare ranks), `design/ZONE_QUEST_MATRIX.md`
(brackets, hubs, the 1,000-quest budget).
**Grounded in (code):** `scripts/player.gd` (weapon Sprite2D + ANCHORS + `_refresh_weapon`/`_refresh_shield`/
`_refresh_chest_tint` + legendary glints/blood-drip — the visual-gear system v1 already ships),
`scripts/items.gd` (item shape, 5 demo legendaries + `effect` hook precedent), `scripts/class_defs.gd`
(7 classes + kits), `scripts/crafting.gd` (extension-key layering, materials/recipes), `scripts/sheet_anim.gd`
(Szadi 32×48 rig), `scripts/quest_defs.gd`/`quests.gd` (quest engine v1), `WORLD_PLAN.md`,
`c:/Users/vstef/Desktop/rpg/_lore_extract.txt` (Part IX artifacts: GORESCREAM, the bloody dagger,
Lilith's throne, Marta's stick, Kriggar's kit; Part V factions).

---

## 0. THE TWO MANDATES

1. **Legendary weapons are questlines, not drops.** One per class. Multi-stage epics in the
   Thunderfury/Benediction mold: a rare **starter** drops from a mighty boss (orange text in the
   loot window — the tavern will hear about it), then a long chain across zones, then craft/ritual
   stages at a canon site, then the weapon. Finishing one is a **Feat of Strength** — and because
   of mandate 2, the feat is *visible on the character forever*.
2. **No transmog. Ever.** What you wear is what you see; what you see is what they earned. The
   equipped main-hand already renders on the body (player.gd, Phase B.2.1) — this doc extends
   that honesty to armor (tier tints + trim, §2) and gives every legendary a bespoke sprite +
   subtle HDR glow (§3). Prestige in Raven Hollow is *legible at a glance across the plaza*,
   exactly like a Classic realm: you cannot buy the look, you cannot hide the look, the look is
   the résumé.

Tone law applies to items as to quests: **no legendary is a clean win.** Every chain below has a
price that is not gold, and the stone notices every one of them (each chain carries exactly one
`villain_beat` — a legendary ambition is the stone's favorite handle).

---

## 1. WHAT ALREADY SHIPS (engine ground truth — do not re-invent)

| Shipped fact | Where | What we build on |
|---|---|---|
| Visible main-hand: Sprite2D child of the body sprite, crop from `pc_wood.png` via `WEAPON_SHAPES` (sword/dagger/staff/bow), grip-pivot, per-frame hand/shoulder ANCHORS, sheathed-on-back vs drawn, brandish on cast | `player.gd` §B.2.1 (`_refresh_weapon`, `_weapon_pose`, ANCHORS) | Legendary sprites are new SHAPE entries on a new sheet, selected **data-driven** (§3.2) instead of by name keywords |
| Off-hand shield renders at the off-arm anchor | `player.gd` `_refresh_shield` | Off-hand visual tiering rides the same path |
| Chest piece tints the whole body sprite (`self_modulate`): leather=warm, iron=cool, legendary=gold + glints | `player.gd` `_refresh_chest_tint` | This is armor-visuals v1 — §2 turns it into the full material-tier system |
| Legendary rarity ⇒ looping gold glints on weapon/shield/chest; Bloody Dagger ⇒ blood drip | `player.gd` `_make_gold_glints`, `_make_blood_drip` | Per-legendary identity FX replace the one-size gold glint (§3.3) |
| Attachment FX hide when the weapon tucks behind the body | `player.gd` `_apply_pose_flags` | Keep; §3.4 adds the "dim, don't kill" rule for the up-facing sheathed view |
| Legendary `effect` ids handled in player.gd (emberfall, rooks_talon, gravekeepers_band, bulwark, bloody_dagger) | `items.gd` header, `player.gd` `_slot_effect` | The 7 new effect ids follow the same hook pattern |
| Item extension keys ignored by core (`type`, `count`; `ilvl/req_level/set_id/value` per ITEM_PROGRESSION) | `crafting.gd` layering precedent | New `visual` key (§3.2) rides the same rule |

The five demo legendaries (Emberfall, Rook's Talon, Gravekeeper's Band, Bulwark, Bloody Dagger)
stay what they are: **Act I keepsakes** at demo-cap ilvl. The seven weapons below are the
endgame line (ilvl 58) — a fresh 60 wearing Emberfall next to a veteran carrying Cindervow is
the point of the system.

---

## 2. NO-TRANSMOG ARMOR VISUALS — material tiers on the Szadi rig

**Not a paperdoll.** The Szadi sheets are 32×48, 8 frames × 3 facings; hand-drawing armor
overlays per sheet × per slot × per tier is a full art team we don't have. The pixel-feasible
system is **palette, rim and trim** — three cheap layers that together read unmistakably at
gameplay zoom:

### 2.1 Layer 1 — body tint by chest material (extends the shipped `_refresh_chest_tint`)

The chest piece drives a whole-sprite `self_modulate` tint keyed on the ITEM_PROGRESSION §5.1
material lexicon. Data-driven via the item's `visual.material` key (§3.2), with the shipped
keyword fallback kept for old items.

```gdscript
# player.gd — MATERIAL_TINTS (self_modulate; rides UNDER the red hit-flash on modulate)
const MATERIAL_TINTS := {
	"cloth":         Color(1.00, 0.96, 0.90),  # undyed warmth (default/common)
	"leather":       Color(1.00, 0.93, 0.85),  # shipped warm brown — keep
	"bog_iron":      Color(0.90, 0.88, 0.86),  # rust-grey, honest
	"iron":          Color(0.88, 0.92, 1.00),  # shipped cool steel — keep
	"grave_silver":  Color(0.86, 0.88, 0.94),  # pale, tarnish-dark trim (§2.3)
	"lead_lined":    Color(0.82, 0.83, 0.88),  # heavy, matte, slightly dead
	"thread_silver": Color(0.86, 0.92, 1.00),  # cold blue-white cast
	"blackglass":    Color(0.80, 0.78, 0.84),  # dark violet-smoke sheen
	"lichen_steel":  Color(0.88, 0.96, 0.88),  # pale luminous green cast
	"emberforged":   Color(1.00, 0.90, 0.80),  # forge-warm, faint orange
	"ledger_brass":  Color(0.96, 0.93, 0.82),  # stamped brass-yellow
}
```

Tints are deliberately ±10% off white — the character must still read as *themselves* (the class
sprite identity from class_defs.gd is sacred), but a Sangeroasa-geared warrior is visibly warmer
than a Black-Night-geared one across the plaza.

### 2.2 Layer 2 — rarity rim-light (1 px outline shader)

A tiny `canvas_item` shader on the body AnimatedSprite2D draws a 1-px outline sampled off the
frame alpha, colored by the **highest-rarity worn armor piece** (head/chest/legs/boots), at low
alpha. This is the "gear score at a glance" channel and it costs one cheap shader:

```glsl
// armor_rim.gdshader — 1px alpha-edge outline, uniform-driven
shader_type canvas_item;
uniform vec4 rim_color : source_color = vec4(0.0);   // a=0 -> off
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.05 && rim_color.a > 0.0) {
		float e = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
				+ texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a
				+ texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
		if (e > 0.0) { COLOR = rim_color; } else { COLOR = c; }
	} else { COLOR = c; }
}
```

| Worn armor majority | rim_color | Read |
|---|---|---|
| common/uncommon | off (a=0) | a leveler — most of the world, most of the time |
| rare (2+ pieces) | `Items.rarity_color("rare")`, a=0.22 | faint blue edge — "dungeon-geared" |
| epic (2+ pieces) | epic purple, a=0.25 | the screenshot tier |
| any legendary armor / full lore-set | gold `CRIT_GOLD`, a=0.28 | reserved; sets from ITEM_PROGRESSION §5.3 earn it at 3/3 |

Rule: **rim never animates, never pulses.** It is a badge, not a VFX. (The muted-palette law —
GK-palette, never neon — governs; alpha caps at 0.30.)

### 2.3 Layer 3 — head trim overlay (one tiny sprite, the only new "paperdoll" pixel)

The head slot is the one silhouette change worth paying for (WoW learned this: helms carry
identity). One 8×5-px **helm band** Sprite2D anchored at the `shoulder` anchor − (0, 4) —
i.e. the hairline — with per-facing visibility like the shield. Art: a single generated band
texture per material family (flat cap-line for cloth/leather, ridged band for metals),
tinted by MATERIAL_TINTS at full saturation. Six generated 8×5 textures total, no sheet edits,
verified the same way the weapon crops were (screenshot pass at 4×).

Explicitly **not** doing: chest/leg/boot overlays (unreadable under the tint at 32×48), cloaks,
shoulders (slots don't exist — inventory.gd law).

### 2.4 Engine deltas for §2 (all in player.gd, ~80 lines total)

1. Rename `_refresh_chest_tint` → `_refresh_armor_visuals()`; keep the legendary-chest gold
   glints; add MATERIAL_TINTS lookup: `visual.material` first, shipped keyword sniff second.
2. Add the rim ShaderMaterial to `_sprite` at create; `_refresh_armor_visuals()` sets
   `rim_color` per the §2.2 table (read rarities off `inventory.equipped`).
3. Add `_helm: Sprite2D` beside `_weapon`/`_shield`; `_refresh_helm()` + a line in
   `_update_weapon_pose` for facing visibility (hidden facing up — occluded by hair/hood art).
4. `equipment_changed` already funnels through `_apply_equipment()` → nothing else to wire.
   Saves untouched (visuals derive from equipped items; `visual` keys ride item dicts through
   save_system like every extension key).

---

## 3. LEGENDARY WEAPON VISUALS — bespoke sprites + hdr_2d glow

### 3.1 The glow stack (engine-level, one-time)

Godot 4 gives pixel-cheap 2D bloom once HDR 2D is on. This is the **only** rendering-settings
change in the doc, flag-gated per the gpu_render staging precedent:

1. `project.godot`: `rendering/viewport/hdr_2d = true` (RGBA16F canvas — GPU-side; the game is
   CPU-bound per the perf work, so this is nearly free frame-time. Verify with
   `tests/profile_run.py` town scene before/after; fallback flag `raven/hdr_glow=false` reverts
   to the shipped CPUParticles-only dressing).
2. One `WorldEnvironment` added by `main.gd` at world build:
   `glow_enabled = true`, `glow_hdr_threshold = 1.05`, `glow_intensity = 0.45`,
   `glow_bloom = 0.0`, levels 2+3 only. Threshold 1.05 means **nothing in the shipped art
   blooms** — only pixels we deliberately push over 1.0.
3. Overbright accents: a legendary weapon's glow is a small child Sprite2D ("ember core",
   `VFX.radial_tex`-style, 4–6 px) whose `modulate` is an over-unity color (e.g.
   `Color(1.8, 1.2, 0.6)`). Only that core blooms. The weapon sprite itself stays in gamut —
   pixel art must stay crisp; the bloom is a breath around it, never a smear over it.

**Subtlety law:** glow pulse period ≥ 2.5 s, amplitude ≤ ±25% alpha, radius ≤ 8 px on screen.
At night (day_night.gd) glow reads stronger for free — do not compensate. A legendary in the
plaza at dusk should look like a coal, not a torch.

### 3.2 Data-driven weapon looks — the `visual` extension key

Today `_weapon_shape_for()` sniffs name keywords ("dagger", "bow"...) — fine for 4 generic
shapes, wrong for bespoke art. Add one extension key (crafting.gd layering rule: core ignores
it; only player.gd rendering reads it):

```gdscript
# items.gd item dict — NEW optional key, after "value":
"visual": {
	"sheet": "res://assets/art/weapons/legendary_arms.png",  # default: pc_wood.png
	"region": Rect2(0, 0, 12, 42),   # crop (px, PIL-verified like WEAPON_SHAPES)
	"grip": 6.0,                     # px above crop bottom = hand pivot
	"scale": 0.34,                   # vs the ~30 px body
	"carry": "sword",                # pose family: sword|dagger|staff|bow|hammer
	"sheath_shift": 0.0,
	"material": "",                  # §2.1 tint key (armor pieces use this too)
	"glow": {"color": Color(1.8, 1.2, 0.6), "size": 5, "at": Vector2(0, -14)},  # {} = none
	"fx": "",                        # optional bespoke attachment id (§3.3)
}
```

`_refresh_weapon()` change: if `item.visual` exists, build the AtlasTexture from
`visual.sheet/region/grip/scale` and take the pose family from `visual.carry`; else fall through
to the shipped keyword path (zero migration). New pose family **"hammer"**: DRAWN_ROT as sword,
SHEATHED across the back like the staff (head-up, `sheath_shift` 3) — one dict entry per table,
no new code path.

**The art asset:** `assets/art/weapons/legendary_arms.png` — one 128×64 sheet, 7 bespoke
sprites (10–13 px wide × 26–42 px tall, matching pc_wood.png proportions), pixel-authored via
the ComfyUI pipeline + hand cleanup, contact-sheet PIL-verified like every crop before it
(repo law). Seven sprites, listed with their looks in §5.

### 3.3 Per-legendary attachment FX (replaces one-size gold glints)

`_refresh_weapon()` currently adds `_make_gold_glints()` for any legendary. New rule: a
legendary with `visual.fx` set gets its bespoke attachment instead; glints remain the fallback.
Each FX is a ≤20-line factory in player.gd next to `_make_blood_drip()` (that function is the
template — it proves the pattern):

| fx id | What it does (all: low-rate, muted, GK palette) |
|---|---|
| `ember_seam` | 2 slow ember motes/s drift off the blade seam + the hdr core breathes (2.8 s) |
| `honest_gleam` | NO loop. One clean white glint plays on draw/unsheathe only (audio-visual "shing", no particles) |
| `caged_flame` | violet hdr core flickers candle-like inside the cage; 1 violet mote/4 s escapes upward |
| `ivy_breath` | soft green-gold halo; a single leaf particle falls every ~12 s and fades on the ground |
| `thread_pull` | a 1-px blue-silver line from pommel to the wielder's wrist anchor (drawn in `_update_weapon_pose`); glints when minions are alive |
| `rook_pinion` | faint teal-black sheen; on crit (hook in `_crit_number`) one black feather flutters down |
| `blossom_clock` | a 2-px white blossom at the crook: open in day, closed at night (poll `day_night` group; the plaza reads the hour off your staff) |

### 3.4 Visibility rule (the feat must be visible in town)

Legendaries render **sheathed too** (shipped: the back-slung weapon shows facing up, peeks
otherwise). One change to `_apply_pose_flags`: when the item is legendary, attachment FX and the
hdr core are **dimmed to 35% alpha instead of hidden** while the weapon is tucked behind the
body — the coal glows through the crowd. (Shipped code hides children entirely; keep that for
non-legendary drips/glints.)

---

## 4. THE LEGENDARY FRAMEWORK (rules all 7 chains obey)

### 4.1 Acquisition law
- **The weapon is never a drop.** (ITEM_PROGRESSION §1 law.) The **starter** is: a rare drop
  (3%) from 2–3 named sources in the class's thematic arc (listed per chain), all rank
  `elite`/`rare`/boss per COMBAT_PACING §5.7. Orange name in the loot window; right-clicking it
  auto-starts the chain (quest `giver: ""`, `auto_trigger` on item examine — engine already
  supports auto-trigger starts).
- Class-locked: the starter only *rolls* for the matching class (loot hook checks
  `player.class_def.id`) — no dead drops, no market for it, Classic-server folklore preserved
  ("a Whetstone dropped and the rogue screamed").
- Droppable from level ~40 sources; chain completable no earlier than **L58** (`min_level`
  gates on the ritual stage). Target: the weapon is earned in the 58–60 push or at cap.

### 4.2 Quest-budget composition (keeps the 1,000 exact)
QUEST_ARCHITECTURE budgets 70 class quests (7 × 10 at L10–50 milestones). **Amendment, not
addition:** per class the 10 slots re-allocate as — L10 ×2, L20 ×2, L30 ×1 (kit quests, as
planned) + **the legendary line ×5** (starter-examine quest ~L40 + 4 chain steps ending L58).
World total stays 1,000; the class-quest row's purpose sharpens: the back half of every class's
personal story *is* its legendary.

### 4.3 Chain grammar (the Thunderfury shape, in schema v2)
Every chain = 5 quest defs, `qtype: "class"`, `class_lock: [<class>]`, `chain: "leg_<class>"`,
`chain_step: 1..5`, `prereq` on the class's L30 quest, cross-zone per the interconnection rules
(2-hop locality honored — long hauls are steps, not objectives):

| Step | Shape | Objective kinds (v2) | Rule |
|---|---|---|---|
| 1 — The Starter | examine the dropped thing; a class-anchor NPC names what it could be | `use_item → talk` | The NPC *warns* as much as invites — wanting this is a door the stone can knock on |
| 2 — The Gathering | cross-zone materials/deeds (crafting.gd `material` items; elite/rare kills; a leverage or mercy) | `collect / kill / talk` | Materials enter the bag via `Crafting.grant`; every gather list has one item gold can't buy |
| 3 — The Proof | a trial of the class's verb (COMBAT_PACING teaching loop turned exam) | `kill (elite/rare) / vigil / scan` | Soloable at 55+ by playing the kit; kills the facetanker |
| 4 — The Ritual | craft/consecrate/bind at a canon site; **the price is paid here** | `reach → choice → vigil` | The choice never trades stats — it trades *meaning* (flags, aftermath, an Act III Archive file) |
| 5 — The Weapon | finale beat + grant; the stone's `villain_beat` fires | `talk / reach`, finale_pages | Reward `xp: 0` (derive, chain-finale mult), gold 0 — the weapon is the pay |

### 4.4 Feat of Strength
Completing step 5 sets `fos_leg_<class>` (VillainLedger flag block — Archive-referenceable),
writes a gold **Feats** line in the journal + character sheet ("Cindervow, quenched — winter of
year 3"), and — the real feat — the weapon on the back in every town forever (§3.4). At least
one Act III `address` beat per class references it ("the one who carries the quenched blade" —
QUEST_ARCHITECTURE hard rule 3 satisfied by construction).

### 4.5 Budget math (ITEM_PROGRESSION §2, exact)
All seven: `slot: "main_hand"`, `rarity: "legendary"`, `ilvl: 58`, `req_level: 58`,
`value: 41` (formula; and none are sellable in spirit — vendor confirm-dialog warns).
BP(58, main_hand, legendary) = (2.4 + 0.62·58) × 1.0 × 2.0 = **76.7** → spend 76 ±1.
Sits deliberately under the campaign capstone Ledger of Final Account (i60, BP 79) — the
campaign's last word outranks any class's.

---

## 5. THE SEVEN — questlines, weapons, looks

Stat lines follow the class-affinity table (ITEM_PROGRESSION §4, ≥60% primary). Effects are new
`player.gd` effect-id hooks (emberfall precedent). Every "Price" is a permanent flag with a
registered later reference (rule 6). Zones/brackets per ZONE_QUEST_MATRIX.

---

### 5.1 WARRIOR — **CINDERVOW** *(the blade that refused the scream)*

Valrom's forge line, claimed. Fidor forged GORESCREAM on the Anvil of Hatred at Mount Tilamar —
and the canon offers "a lineage of lesser Fidor-forged blades" (Part IX). Cindervow is the last
of the lineage: forged on the same anvil, by the player's arm, and quenched *wrong on purpose* —
no blood, no volcanic salts, no scream. A Sangeroasan masterwork that refuses the sermon.

- **Starter (3%):** *Scream-Notched Billet* — a forge-rejected GORESCREAM-lineage blank, still
  warm. Drops: Debt Pit end boss · Basaltfang forge-thrall rare · Vosk-tier South rares (40+).
- **Chain (leg_warrior, Sangeroasa arc 40→58):**
  1. **The Billet** — Forge-quarter smiths refuse to touch it ("Fidor's iron argues back").
     Only the exiled smith **Fidra**, Fidor's granddaughter *(new — files no ledger, keeps no
     apprentices)*, will speak: bring her proof you can carry weight that argues.
  2. **What the Forge Eats** — collect: basaltfang steel ×8 (Ashvents elites), ember dust ×20
     (crafting.gd line), *a bucket of water from Raven Hollow's plaza well* (walk it back
     across the world unspilt — `deliver`, temptation prompts at every hub offer to "just use
     local water"; local water is coppered).
  3. **The Count of Three** — `vigil` at the Killing Floors when all the hammers stop (canon
     South whisper medium). In the three-beat silence the billet **hums the note back**. The
     zone's forge-thralls aggro the vigil — hold the anvil line (guarded/swarm exam).
  4. **The Quench** — Mount Tilamar, the Anvil of Hatred. Forge-minigame-as-quest: strike
     rhythm via timed `use_item` beats. Then the `choice`: quench in the vent-blood trough
     (the old way — the stone-approved way; Fidra walks out) or in the carried hearth-water.
     **Price:** hearth-quench cracks the edge — Cindervow keeps a visible notch (it's in the
     sprite) and the flag `cindervow_notched` is set; the vent-quench completes the blade
     flawless and sets `cindervow_screamed` — and Fidra's forge is cold when you return.
     Stats identical. Meaning isn't.
  5. **A Blade With a No In It** — present it at the Bent Oar (hub-return rule; Goran of Raven
     Hollow is drinking there and goes quiet). `villain_beat: arrangement` — a work-ledger at
     the Pit rim lists the billet as "issued", dated the day you first entered Sangeroasa.
- **Weapon:** dmg 55 · armor 8 · hp 40 · crit 5% (BP 76). `effect: "cindervow"` — *the quench
  holds*: melee hits have 15% to burst a 24-px ember nova (20% of the hit as AoE + 20% slow
  1.5 s). Procs while Iron Bulwark is active also refund 5 absorb.
- **Look:** forge-black one-hand blade, an orange **ember seam** down the fuller (hdr core,
  2.8 s breath), the §4 notch visible near the tip if `cindervow_notched`. fx `ember_seam`;
  carry `sword`; material `emberforged`. Sprint leaves two fading motes.

---

### 5.2 ROGUE — **THE GOOD KNIFE** *(not magic; not named by anyone who owned it; just good)*

Kriggar's kit, canon verbatim: "correctly steeled, correctly ground, correctly cared for … its
whole character is that it is not GORESCREAM: no curse, no scream, no sermon … it never turns on
you, in a world where everything else does." The rogue's legendary is the anti-artifact — and in
Blestem, where everything is priced, a thing with no price is the rarest object on the continent.

- **Starter (3%):** *A Whetstone, Worn True* — a dead man's whetstone, dished by decades of
  correct angles. Drops: Blestem act boss · Riddler's Quarter dungeon boss · Lichenreach
  cave-strigoi lord rare (36+).
- **Chain (leg_rogue, Blestem → Collector's Coast 40→58):**
  1. **Provenance** — Blestem's lower market appraises the whetstone at *nothing* — and that
     terrifies them (an unpriced thing breaks the civic religion). Sabira's network points
     east-then-over-the-water: the stone's owner "ground edges for the ferry crews. Never
     charged for edge-work. We watched him for years. No angle."
  2. **The Blank File** — leverage-trade shape *inverted*: acquire the informant file Cazimir's
     office keeps on the dead grinder (steal/`collect`), and the three buyers appear on
     schedule (the office, a rival, the Archive). The step completes only by **burning it**
     (choice) — the knife cannot be begun by a purchase. Price flag: `good_knife_burned_score`
     (the payout you walked from is gone; Blestem rep −, and an Act III Archive file is
     permanently *thinner* because of you — referenced at the §51–54 tour).
  3. **Steel That Owes Nothing** — collect: unmarked billet steel (the ONLY unstamped ingot in
     the South — won by out-dueling the Bloodroad convoy rare, `duelist` exam), salt-oak for
     the grip (Dead Timber), and *nothing else* — the gather list is short on purpose and the
     journal says so.
  4. **The Grind** — the Last Hearth's knife-grinder *(new — she fixes things for the ferry
     folk and asks after your boots)* teaches the angle over three `vigil` sessions at her
     wheel — real-time patience, leaving pauses. No minigame flash: the quest is literally
     standing still and doing one thing correctly. Final `choice`: she offers to engrave your
     name. Refusing is the completion ("named knives get stories; good knives get work").
  5. **Just Good** — no ceremony. She hands it over mid-sentence and turns back to the wheel.
     `villain_beat: whisper` — that night, an entranced dockhand stops beside you, says one
     Underlanguage sentence *to the knife*, and — nothing. It does not answer. First object in
     the game the stone addresses that has no handle to grab. The dockhand walks on, released.
- **Weapon:** dmg 48 · crit 10% · speed 8% · hp 50 (BP 76). `effect: "good_knife"` — *it never
  turns on you*: the wielder is immune to compulsion/entrancement-class status effects
  (STATUS_EFFECTS doc's `listening`/`compulsion` family) and to legendary-curse hooks; +20%
  damage to any enemy currently casting or entranced (the clean cut through the borrowed voice).
- **Look:** plain bright steel, correct proportions, **no particles, no color**. fx
  `honest_gleam` — one white glint on draw, nothing else; its hdr accent is a single 1-px
  edge pixel at `Color(1.3,1.3,1.3)`. Among six glowing legendaries, the seventh reads
  loudest by being silent — every veteran will know exactly what that plain knife is.
  Carry `dagger`; material bog_iron (honest).

---

### 5.3 MAGE — **LEADLIGHT** *(the answered candle, caged)*

Her lore: "she copied forbidden ember-script by candlelight until the candle answered back."
Leadlight is that candle — the first flame the Underlanguage ever spoke through to her —
carried ever since, and finally caged in Lead Vault lead so it can burn without being read.
Angel Wings' lead-lined craft (the room built around *not using* power) turned into a weapon:
power, worn openly, refused constantly.

- **Starter (3%):** *A Warded Casing, Cracked* — a lead reliquary the size of a fist, humming
  faintly through the crack. Drops: the Archive dungeon boss · Coldharbor Deep boss · Famine
  Prophet-line elite reprises in the West (40+; the West is her arc's home — hub-return rule).
- **Chain (leg_mage, Angel Wings → Blestem → C2, 40→58):**
  1. **What Cracked It** — Fielderine's Lead Vault clerks identify the casing as Vault-work,
     decommissioned. The Queen (resisting instinct, canon) grants an audience: she will
     license a mage to *carry* caged signal-fire — because the alternative is mages who read.
  2. **Vault-Grade** — collect: virgin lead from the Vault's own seam (escort the ore cart —
     T2 shape, the escort stops to *listen* once), blackglass for the cage lens (Blestem —
     bought at a price that isn't money: one true sighting sold to Cazimir's office, flag
     `leadlight_told_cazimir`, resurfaces per rule 6), wax from Vetka's chandler (the small
     warm thing; he remembers her).
  3. **The Flame Itself** — return to her tower: the candle stub she copied ember-script by
     is still there, unburnt in twenty years, waiting (`scan`: shifting orange). Carrying
     it (deliver, 3 hops) is the temptation gauntlet: every rest point offers "read by its
     light, just once" — reading yields a real lore page + seeds a transmission point.
  4. **The Caging** — at the Lead Vault, `vigil` while the smiths seal it: the flame speaks
     her copied glyphs *back* through the crack as it closes (whisper — never subtitled).
     `choice`: leave one seam-gap so the light gets out (the weapon glows; the signal breathes
     in pinholes) or seal it blind (dark staff, and the glow instead lives in her hands —
     cosmetic-only choice, both legal per no-stat-trade law; flag `leadlight_sealed_blind`).
     **Price:** the caging permanently forfeits the chain's accumulated lore pages — the
     journal *redacts them before your eyes* ("licensed carriage requires surrender of
     transcripts"). What you learned, you un-learn. On purpose.
  5. **Licensed to Burn** — Fielderine marks her one of the few with the resisting instinct
     (composes with the Act I finale beat). `villain_beat: address` — the Vault's inert
     fragment hums once as she passes with the caged flame: recognition between prisoners.
- **Weapon:** dmg 30 · mana 150 · mana_regen 2.0 · crit 8% (BP 76). `effect: "leadlight"` —
  *restraint is a mechanic*: after 3 s of casting nothing, your next spell costs 0 mana and its
  projectile blooms (hdr flare). The weapon literally pays you to hold your fire.
- **Look:** dull lead-grey staff, blackglass cage at the head, **violet candleflame hdr core**
  flickering inside (fx `caged_flame`); pinhole seams leak light if the seam-gap was chosen.
  Carry `staff`; material `lead_lined`. Casting makes the cage seams flash-bloom for one frame.

---

### 5.4 PALADIN — **GREENMERCY** *(the reconsecrated hammer)*

His lore: "he carries the last consecrated hammer left in the Hollow." Transcub — the ivy-eaten
old god of the East who punished cruelty turned inward — is the only faith on the continent
whose churches stayed *quiet* (canon: "the ivy-eaten Transcub churches now the only quiet
places"). The questline is the hammer he already carries, re-consecrated altar by altar until
the ivy takes the haft: the Hollow's last consecration renewed by the East's dead god.
Living green over cold stone — it reads clean under detection, like the cedar throne.

- **Starter (3%):** *An Ivy-Grown Altar-Nail* — a consecration nail from a collapsed Transcub
  church, green wood grown through cold iron. Drops: Transcub Vale chain rare · Blestem act
  boss · Whisper Passes listener-post elites (32+; earliest starter — paladins walk far).
- **Chain (leg_paladin, Transcub Vale → the four arms, 40→58):**
  1. **The Nail** — Brother Ansel, Ivy-Priest of Transcub (canon cast), reads the nail and
     laughs softly: "Your hammer is tired, Lantern. Transcub does not mind tired. Bring it."
  2. **Four Altars** — reconsecrate at four ivy-altars, one per arm (cross-zone by
     construction; each is a `reach + vigil` and each altar demands a **mercy performed in
     that kingdom first**: spare a marked deserter (South), carry a thread-shell's body to
     its row unprompted (North), un-file a name (East — Blestem rep −), give the granary
     tithe back (West). Four flags, four aftermaths.
  3. **The Confession Altar** — the canon altar carved *"I only wanted to know what it said"*
     (Transcub Vale). `vigil` at night; the confessor's ghost-echo kneels beside the player
     — and the altar demands the paladin's own line. The `choice` lists **the player's
     logged campaign flags** (VillainLedger-driven, like an address beat inverted — confession
     as mechanic): pick the choice you regret. It is *carved into the altar*, permanently,
     readable on every future visit. Price paid in public.
  4. **The Reconsecration** — Ansel performs it: the nail is driven into the old haft, and the
     ivy takes the hammer overnight (`vigil` till dawn, day_night-gated). Transcub's blessing
     is characteristically backhanded: the hammer will not glow for its wielder — only for
     others (see effect).
  5. **Lantern, Lit** — walking back into Raven Hollow's chapel with it (hub return; the
     ashen chapel he swore at). `villain_beat: symptom` — the chapel's warm lane... isn't.
     For once the ground near the altar is honestly cold, and the paladin knows enough now
     to find that *restful*. The quietest villain beat in the game: absence.
- **Weapon:** dmg 38 · armor 12 · hp 90 · mana 40 (BP 76). `effect: "greenmercy"` — *mercy
  compounds*: hits on enemies under your root/Consecration heal you 2% max hp (cap 6%/s);
  Lay on Hands overheal becomes an absorb shell (the Vigil line made literal).
- **Look:** grey stone-headed maul wound in **living ivy**, soft green-gold halo (fx
  `ivy_breath`; hdr core `Color(0.9,1.5,0.8)` at the head); a leaf falls and fades every ~12 s.
  Carry `hammer` (new pose family); material `lichen_steel`. The carved-confession altar text
  is echoed in the tooltip flavor, personalized per save.

---

### 5.5 NECROMANCER — **THE SEVERED STRAND** *(one thread, held with a living hand)*

The Thread is Lilith's will and the stone's cage at once (canon). Canon also gives the counter:
**"a living touch receives; a dead touch transmits."** The necromancer's legendary is a single
strand of the Thread, deliberately thinned and cut loose by the Queen herself (she thins the
Thread in canon), bound into a grave-iron scepter — held forever in a *living* hand so it can
never become an antenna. The class fantasy sharpened: the polite gravekeeper carrying one
percent of a god's leash, gently.

- **Starter (3%):** *A Thread, Still Humming* — a blue-silver filament coiled in a kerb-stone
  crack, cold and alive. Drops: Gravemark warband rares · Black Night dungeon boss · thread-
  shell elite packs on the Listening Steppe (42+).
- **Chain (leg_necromancer, Black Night arc 42→58):**
  1. **What You're Holding** — Vasile of the Council of Six (loudest, canon) goes pale:
     "That is not yours. That is not *ours*. Put it— no. Too late. Hold it in your *hand*,
     boy. Skin. Always skin." First rule established: the strand rides bare-handed
     (mechanic: while in the bag, a slow `listening` tick; the quest teaches you to keep it
     equipped in the trinket slot until bound — restraint inverted).
  2. **The Council Divides** — two-sided T4: Vasile (bind it, held, living) vs Radovan
     (surrender it for study — his private reading, per his kingmaker file). `excludes`
     mirror-quests; both grant the next step, both are right about the other. Siding with
     Radovan doesn't end the chain — it ends with *his clerk* dead of comprehension and the
     strand back in your hand (arrangement flavor), one level later.
  3. **Grave-Iron** — collect: grave-silver from Gravemark (tarnishes black the week someone
     lies — the material lexicon made quest text), a scepter haft from the Chamber Depths
     revisit (mutable dungeon remembers your Act I transcribe/deface choice — the walls
     greet you accordingly), and **a bell that has rung for a funeral done kindly** (Vetka;
     Gren the gravedigger's — the man who dug the unasked grave; he gives it freely and
     that matters).
  4. **The Binding** — at a kerb-stone row under the Pit's skyline, `vigil`: the necromancer
     holds the strand bare-handed while it is wound into the scepter — and for its length
     the player's own **minions all turn their heads toward the player** and hold still
     (rows-of-twelve grammar aimed at *you*). `choice` — the strand offers, once, to show
     what it's connected to (read = a true Lilith lore page + `strand_looked` flag + the
     Orange Fog creeps a hair closer on the C2 map; refuse = `strand_refused`).
     **Price either way:** binding takes warmth — the necromancer's hp_regen drops by 0.2
     permanently (stated in-fiction: "the hand that holds it is always a little cold").
     The only stat price in the seven, because necromancy's law is that everything costs
     the body something.
  5. **One Thread, Held** — a thread-shell in the still market turns its head as you pass —
     and *nods*. `villain_beat: courier` — a sealed note arrives via dead courier, addressed
     "to the one holding my hem." Unsigned. Two words if opened: "Grip. Please." (Lilith —
     never named. The player holds a piece of the cage now; the jailer noticed.)
- **Weapon:** dmg 34 · hp 60 · mana 110 · mana_regen 2.0 (BP 76). `effect: "severed_strand"` —
  *the strand tugs*: Raise Dead minions gain +50% hp and step to the strand (obey a
  re-position click); a minion's death returns 15 mana up the thread. The pet class's
  legendary is a better leash, of course it is.
- **Look:** black grave-iron scepter; a **single blue-silver thread** runs from its tip to the
  wielder's wrist (fx `thread_pull` — the 1-px drawn line; hdr glints `Color(0.8,1.1,1.7)` run
  along it when minions are alive, toward them). Carry `staff`; material `thread_silver`.
  Unmistakable across a battlefield: the necromancer is *wired to* their dead.

---

### 5.6 ROOKWARDEN (HUNTER) — **GALLOWSBOUGH** *(the limb the rooks chose)*

His lore: "the rooks chose one warden a generation, and they chose him at the gallows-tree."
The legendary bow is cut from that tree — but the tree is not his to cut; it is the rooks'.
The whole chain is Petra's line made playable: the rooks are never wrong, the rooks are never
*owned*, and the bow is granted, not taken.

- **Starter (3%):** *A Pinion, Black-Bright* — a single rook feather, iridescent, left ON the
  boss corpse (the only starter the class doesn't loot from the enemy — the rooks drop it on
  the kill; loot-window line reads "left for you"). Sources: any zone rare in the North arc ·
  Basaltfang Range rare · the Marches Alpha reprise (40+).
- **Chain (leg_rookwarden, follow-the-rook world tour 40→58):**
  1. **Ask Petra** — Old Petra (Raven Hollow, canon cast; her line rook-flavored per the
     class-quest mandate): "They don't give feathers. They *lend* them. Something wants
     paying, warden. Go where they look." A rook alights and faces a compass point.
  2. **Where They Look** — follow-the-rook: 4 `reach` beats across 4 zones (each: a rook
     visibly perched at the objective — trivially cheap NPC prop + the world's best quest
     marker, diegetic and no UI). At each perch, a thing to witness (`scan`/`talk`): a
     wolf-line survey, a listener mid-listen, a false grave, a full granary. The rooks are
     teaching him to *notice* — the Kriggar verb, feathered.
  3. **The Debt** — the payment the rooks want: `kill` the poacher-lord who has been netting
     rooks for Blestem's listening-walls experiments (Eastern Ridges elite camp — casters +
     nets, the hunter's full curriculum), and open every cage *without keeping one bird*
     (`choice` per cage; keeping one = the chain pauses until released — the rooks simply
     stop appearing. Ownership is the one wrong answer.)
  4. **The Cutting** — return to the gallows-tree at Raven Hollow (level-58 player back in
     the level-1 field — Classic homecoming). `vigil` at dusk: the flock settles the whole
     tree, then rises at once — and ONE limb cracks and falls. The tree gives it; nobody
     cuts anything. String it with wind-cured sinew (step-3 camp's stores), fletch-nock
     capped with the starter pinion. **Price:** while the flock rises, it takes something —
     the warden's name for a season. Until level 60, town NPCs address him only as "Warden"
     (dialogue-layer flag `rooks_hold_name`; names return at the cap, and one rook says it
     first. Petra finds this very funny.)
  5. **Never Wrong** — Petra inspects it, tests the balance, hands it back: "Now you're
     borrowed too." `villain_beat: arrangement` — the poacher-lord's netting contract
     surfaces: commissioned through three shells by a Blestem office *the day after* the
     player first spoke to Petra. The stone wanted the listening-walls fed; either outcome
     served — except the rooks knew, which is why they started paying attention to you.
- **Weapon:** dmg 50 · speed 8% · crit 8% · hp 50 (BP 76). `effect: "gallowsbough"` — *the
  rooks are never wrong*: every 5th arrow, a rook dives the target (+30% of the hit, 30% slow
  1 s); Hunter's Mark gains +10% damage (they point, you loose).
- **Look:** near-black bow of gallows-yew, pinion tufts at both nocks, faint **teal-black
  sheen** (hdr accent `Color(0.7,1.2,1.3)` at the grip, dimmest of the six glows). fx
  `rook_pinion` — a black feather flutters down on crits. Carry `bow`; material grave_silver.

---

### 5.7 DRUID — **THE UNGIVEN** *(grown in bought ground, never entered in any ledger)*

The Gift is the South's horror: fertile soil from war dead, a good harvest growing out of a
child's shoe (canon vignette). The druid's legendary begins as one red-shelled seed from that
soil — and the questline is the search for ground that *owes nothing*, in a world where every
acre is filed. The answer is the thesis of the whole game: Old Marta's garden plot in Vetka,
kept unpriced by kindness, the small warm imperfect thing.

- **Starter (3%):** *A Seed, Red-Shelled* — warm to the touch, found in a field-warden's
  pouch. Drops: the Gift field-warden rare · Ashvents elite circuit · Sangeroasa act boss (40+).
- **Chain (leg_druid, the Gift → Vetka → seasons, 40→58):**
  1. **What Grows From This** — the wildwood answers her directly (her lore: the forest names
     its price): *"Not here. Everything here is owed."* The quest journal literally lists and
     strikes through candidate ground: the Gift (owed), a Blestem park (priced), consecrated
     chapel earth (spoken for)…
  2. **Unowed Ground** — the search: `talk` beats with the land's keepers across three zones,
     each explaining, kindly or not, what their soil costs. Gren the gravedigger (Vetka)
     finally shrugs: "Marta's plot. She never charged for the herbs. Nobody ever dared bill
     *her*." (Composes with canon: her stick is enshrined in the Archive for exactly this.)
  3. **The Planting** — plant it in Marta's garden (`use_item`), and **wait**: the sapling
     grows across real in-game calendar windows (CALENDAR_EVENTS integration — 3 stages,
     ~2 sessions apart; the journal entry just says "It is growing. So are you", and the
     step also requires the druid to gain 2 levels — time and growth, honestly coupled).
     Each return visit: tend it (`vigil`, short) and once, defend it — a Hungering swarm
     event drawn to the one warm thing (swarm exam at the sapling, no AoE-ing the garden
     beds: precision teaching beat).
  4. **The Cutting That Isn't** — the sapling at bearing height. The `choice` the whole
     chain aims at: **cut the staff** (a clean, straight, perfect crook — and the sapling
     dies; flag `ungiven_cut`) or **wait for the drop** (`vigil` one more window: the tree
     sheds a branch on its own — smaller, crooked, imperfect, alive; the tree stays;
     flag `ungiven_given`). Stats identical. The sprite is not: the given branch's crook is
     visibly bent. Vetka's aftermath dialogue knows which staff you carry. Forever.
  5. **The Ungiven** — Marta's porch, closing beat: whoever keeps the garden now sums it —
     "Everything else in the world got taken or paid for. Not this." `villain_beat:
     false_victory` — that season, the Gift's harvest posts its best yield in a decade;
     the ledgers credit "improved stock." Your seed's siblings. The stone farms hope too.
- **Weapon:** dmg 40 · hp 80 · mana 60 · armor 8 (BP 76). `effect: "ungiven"` — *the soil
  answers*: kills sprout a flower at the corpse for 10 s; walking over it heals 3% max hp
  (once each, max 3 live flowers). The only legendary whose proc helps you by asking you to
  *move somewhere*, which is the druid curriculum in one line.
- **Look:** living green crook (bent, if given; straight, if cut), a 2-px **white blossom** at
  the head — open by day, closed at night (fx `blossom_clock`, day_night-polled; the plaza
  tells time by the druid). Warm green hdr breath `Color(0.9,1.4,0.9)`. Carry `staff`;
  material lichen_steel (tint) — but flavor insists: it isn't steel, it isn't anything mined.

---

## 6. THE ITEM DICTS (paste-shape, items.gd; §2.1 extension keys + §3.2 `visual`)

One shown in full; the other six follow identically with the §5 stats/fx/regions.

```gdscript
	"cindervow": {
		"id": "cindervow", "name": "Cindervow", "slot": "main_hand",
		"rarity": "legendary", "icon": "pixel:cindervow",
		"stats": {"damage": 55.0, "armor": 8.0, "hp": 40.0, "mana": 0.0, "speed_pct": 0.0, "crit_pct": 5.0},
		"flavor": "Forged on the Anvil of Hatred. Quenched somewhere kinder.",
		"stackable": false, "effect": "cindervow",
		"ilvl": 58, "req_level": 58, "set_id": "", "value": 41,
		"visual": {
			"sheet": "res://assets/art/weapons/legendary_arms.png",
			"region": Rect2(2.0, 4.0, 11.0, 40.0), "grip": 5.0, "scale": 0.33,
			"carry": "sword", "sheath_shift": 0.0, "material": "emberforged",
			"glow": {"color": Color(1.8, 1.2, 0.6), "size": 5, "at": Vector2(0.0, -14.0)},
			"fx": "ember_seam",
		},
		# source: leg_warrior chain finale ONLY. Never drops, never sold.
	},
```

| id | carry | glow color (hdr) | fx | statline (BP 76) |
|---|---|---|---|---|
| `cindervow` | sword | 1.8, 1.2, 0.6 | ember_seam | 55 dmg / 8 armor / 40 hp / 5 crit |
| `good_knife` | dagger | 1.3, 1.3, 1.3 (edge px only) | honest_gleam | 48 dmg / 10 crit / 8 spd / 50 hp |
| `leadlight` | staff | 1.4, 0.9, 1.8 | caged_flame | 30 dmg / 150 mana / 2 regen / 8 crit |
| `greenmercy` | hammer (new) | 0.9, 1.5, 0.8 | ivy_breath | 38 dmg / 12 armor / 90 hp / 40 mana |
| `severed_strand` | staff | 0.8, 1.1, 1.7 | thread_pull | 34 dmg / 60 hp / 110 mana / 2 regen |
| `gallowsbough` | bow | 0.7, 1.2, 1.3 | rook_pinion | 50 dmg / 8 spd / 8 crit / 50 hp |
| `ungiven` | staff | 0.9, 1.4, 0.9 | blossom_clock | 40 dmg / 80 hp / 60 mana / 8 armor |

Starters are `slot: "none"`, `rarity: "epic"`, stackable false, statless quest items
(weeping_dagger precedent) with an `auto_trigger`-examine hook; icons per the icon-id==item-id
law (7 weapon cells + 7 starter cells in `IconsPixel.REGISTRY`, PIL-verified).

---

## 7. INTEGRATION CHECKLIST (implementation order)

1. **hdr_2d flag-gated** (§3.1): project.godot + WorldEnvironment in main.gd behind
   `raven/hdr_glow`; profile town scene (tests/profile_run.py) before enabling by default.
2. **player.gd — visual plumbing** (§2.4, §3.2–3.4): `visual` key path in `_refresh_weapon`
   (+`hammer` pose family), MATERIAL_TINTS + rim shader + helm band in
   `_refresh_armor_visuals`, 7 attachment-FX factories, dim-not-hide for legendary FX.
3. **items.gd**: 7 weapons + 7 starters + `visual` key docs in the header; `icons_pixel.gd`
   14 cells; `legendary_arms.png` authored + PIL contact-sheet verified.
4. **player.gd — 7 effect hooks** (§5): each ≤30 lines on the existing funnels
   (`_deal_player_damage` / `_check_kill_effects` / buff paths); `good_knife` needs the
   STATUS_EFFECTS immunity check exposed as `is_curse_immune()`.
5. **Quest defs**: 35 defs (7 chains × 5) as `scripts/quests/defs/class_<id>.gd` per the
   registry split; class-quest budget amendment (§4.2) noted in ZONE_QUEST_MATRIX at next
   edit; loot hooks for starters (class-gated 3% rolls on the listed sources).
6. **Feats**: `fos_leg_*` flags in VillainLedger; journal Feats tab line; character-sheet
   caption; one `address` reference per class registered for Act III.

## 8. ACCEPTANCE CHECKLIST (per chain, extends QUEST_ARCHITECTURE §7)
- [ ] Starter: 3%, ≥2 sources, class-gated, orange loot-window line, auto-start on examine.
- [ ] 5 steps, `qtype:"class"`, `class_lock`, cross-zone, 2-hop locality, hub-return once.
- [ ] Exactly one `villain_beat`; kind fits the act cadence; logged to VillainLedger.
- [ ] The Price: no stat trade (necromancer's −0.2 regen is the flagged sole exception);
      ≥1 permanent flag with a registered later reference; aftermath dialogue updated.
- [ ] Weapon: BP 76 ±1 @ i58; effect id hooked; `visual` complete; glow within §3.1 subtlety
      caps; sprite verified at 4× in all six carry poses (3 facings × drawn/sheathed).
- [ ] The feat is visible: weapon renders sheathed in town, FX dimmed not hidden.
- [ ] No clean win: the reward is real, and something in the finale re-prices it.
