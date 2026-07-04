# CINEMATICS — Diablo-2 Chapter Films + The In-World Cinematic System
**Raven Hollow / Draconia canon · mandate: "FULL CINEMATICS: 6 act-chapter cinematics, DIABLO 2 STYLE (painted stills, slow pans, weary narrator) — ComfyUI painted stills from the lore bible's own art prompts + Ken Burns + Maya1 narrator" + "TONS of in-game world cinematics (in-engine: camera rails, letterbox, scripted scenes)" (MANDATES.md, Narrative & Cinematics)**

Canon sources: `c:/Users/vstef/Desktop/rpg/_lore_extract.txt` (the 12 embedded ART PROMPTs, cited below by line number as **L#**), `design/VILLAIN_ARC.md` (touch-points cited as **TP-#**), `WORLD_PLAN.md` (zones as **Z#**), `design/QUEST_ARCHITECTURE.md` (tone law).
Engine sources: `scripts/quests.gd` (`cinematic_beat` signal, line 119), `scripts/quest_defs.gd` (data-as-GDScript pattern; `finale_beat`/`finale_pages` schema), `scripts/voice_client.gd` + `scripts/voice_registry.gd` (baked-first Maya1 VO, FNV-1a line hashing), `scripts/npc.gd` (follow/facing/bark API), `scripts/travel_system.gd`, `scripts/save_system.gd`.

Register note: MANDATES lists the STORYTELLING VOICE guide as 🔄 (in design). No `NARRATIVE_VOICE.md` exists yet, so all narration below is drafted in the mandated fallback register — **Tolkien wonder braided with Draconia dread** — and must be re-audited against the voice guide when it ships.

---

## PART A — THE SIX CHAPTER FILMS (Diablo-2 style)

### A.0 The form (pin this)

Diablo 2's act cinematics work because of four disciplines, all adopted as law here:

1. **A witness, not a hero.** D2's narrator (Marius) is a broken man retracing a road someone stronger walked. Ours is the same shape: a **weary traveler one season behind the player**, finding what the player's road left behind. He describes aftermaths, never battles. The player is always "the one who ___" — the villain arc's Tier-2 grammar (TP-11) leaking into the framing device itself, so the cinematics *address the player the way the stone does*, and nobody notices until the second playthrough.
2. **Stills, not motion.** Painted dark-fantasy plates with slow Ken Burns pans/zooms and crossfades. No animation beyond camera, grain, and one or two cheap composited layers (fog scroll, ember drift, a light-flicker mask). This is deliberately achievable *and* deliberately D2: the stillness reads as dread.
3. **The voice carries everything.** Music and ambience sit low; the narrator is mixed dry and close, like he's at your shoulder at the inn.
4. **Never show the villain.** The Design Law (VILLAIN_ARC §1) applies to film exactly as to gameplay: the Bloodstone appears only as consequence — warm ground, aligned dust, the emblem plate (L35) — never as an actor. The whisper-language is **never translated**, including in subtitles.

**Chapter map onto the campaign** (3-act spine per VILLAIN_ARC, levels per its band table):

| # | Film | Plays when | Campaign slot |
|---|---|---|---|
| C1 | **"The Pause"** | New game, after class select, before Raven Hollow | Opening |
| C2 | **"Four Appetites"** | Leaving the Border ring for the first kingdom arm (~lv 12, after TP-05) | Act I → Act II |
| C3 | **"The Quieting"** | The TP-10 false-victory reversal (~lv 33) | Mid-Act II (the mandated false victory — it earns a film) |
| C4 | **"The Drowned Ledger"** | Boarding the Grey Ferry at Riverfork (lv ~40) | Act II → Act III |
| C5 | **"The Only Option"** | Passing the thread-gate after TP-15 (lv ~58) | Pre-finale |
| C6 | **"A Bookmark, Not an Ending"** | After the TP-16 choice; three narration variants | Epilogue |

Target runtimes: C1 ≈ 2:40; C2–C5 ≈ 1:50–2:20; C6 ≈ 1:30 per variant. D2 pacing: ~15–25 s per still.

---

### A.1 Casting the narrator (Maya1)

**Role: THE CHRONICLER** — a grey traveler who walks the player's road a season late, pays for stew he does not eat, and writes down what he finds. He is, on the page, the same never-named Stranger of VILLAIN_ARC §3 — and the same rule binds the films: **the cinematics never name him, never show his face fully lit, and never resolve whether the telling is a man's memory or the stone's record.** The Kriggar portrait prompt (L2375) may be used only cropped, from behind, or in deep chiaroscuro; the ember glow at the sternum may appear in exactly one late shot (C5-S6) and is never remarked on.

**Maya1 voice design string** (goes in the TTS server's `voices.json` as speaker **`chronicler`** — a NEW key; do not reuse `narrator`, which is already the townsfolk bark bank per `voice_registry.gd`):

> `Male voice, late 50s, low gravelly timbre, quiet and close-miked, slow storyteller's cadence with long deliberate pauses, faint Romanian accent, weary but precise, grief kept under the words, never theatrical, occasional dry gravedigger humor, trails off at the ends of hard sentences.`

**Direction per emotion, using Maya1 inline tags:** default read is flat-tired; `<sigh>` before admissions; `<breath>` at still-transitions (doubles as an edit point); `<whisper>` ONLY for lines about the stone's attention — the mix drops music 3 dB under every `<whisper>`; never `<laugh>` except the single dry huff scripted in C4. Rule: **the Chronicler never raises his voice in six films.** The one moment he almost does (C5, "Don't—") is cut off by the edit, on purpose.

**Bake pipeline** (reuses the shipped VO system wholesale):
1. Narration lines live in `scripts/cinematic_defs.gd` (see A.5) as plain strings.
2. The existing bake tool renders each via the local FastAPI TTS server (`http://127.0.0.1:8123/tts`, Maya1 backend) with speaker `chronicler`, writing `res://assets/vo/chronicler/<fnv1a(speaker|text)>.ogg` — identical hashing to `voice_client.gd::line_hash()` so runtime lookup is free.
3. Shipped builds are baked-only (Voice autoload law: missing clip = silent no-op, never a crash). A headless QA script asserts every narration line in `cinematic_defs.gd` has its baked file (Engineering Law: everything auto-QA-testable).

**Music + ambience beds** (two-layer: one music stem, one ambience loop, both ducked −6 dB under VO, −9 dB under `<whisper>`):

| Film | Music stem | Ambience bed |
|---|---|---|
| C1 | new: solo cello + drone, D minor, sparse ("The Pause" theme — 3 descending notes, the melody motif) | `wind.ogg` + distant crow (`crow_caw.wav`, sparse one-shots) |
| C2 | new: the Pause theme restated on 4 instruments (one per kingdom: choir/anvil-perc/low strings/hurdy-gurdy) | `life_mystical_village.mp3` (low) crossfading to `dark_city.wav` |
| C3 | new: the theme in MAJOR for 40 s (the festival) then hollowed to 2 notes | festival crowd (new, short) → dead silence → `wind.ogg` |
| C4 | new: water-logged variation, tape-warble, bells | new: creaking hull, canal water, gulls-gone-wrong |
| C5 | the theme at 2 notes converging toward 1; sub-bass pulse at heartbeat tempo, slowing | `frost_northern_winter.flac` (low) + `eyes_in_the_shadows_loop.flac` |
| C6 | variant-dependent (see C6); TRANSMIT ends on the full 3-note theme, imperfect, slightly out of tune — on purpose | hearth crackle OR aligned-dust silence |

The 3-note melody IS the score's spine: canon says "The old songs had three notes. Ours have two" (lore ~683). The soundtrack literally loses a note across the six films and buys it back (out of tune) only in the TRANSMIT epilogue.

---

### A.2 Still production pipeline (ComfyUI, local)

**Machine reality** (per repo memory, `project_local_image_gen.md`): ComfyUI runs locally on the 5070 Ti with SDXL + the Pixel Art XL LoRA, driven by comfyui-mcp with a direct-API fallback. For these plates: **SDXL base, NO pixel LoRA** — the films are painted concept-art plates (D2 precedent: painterly FMV over a sprite game; our lore prompts are already written for this style). The pixel LoRA stays reserved for sprites.

**The STYLE SUFFIX.** All 12 lore-bible prompts share one closing formula. It is the film look-bible; every derived shot MUST end with it verbatim:

> `dark fantasy concept art, Witcher 3 Velen atmosphere, grimdark, muted desaturated palette, volumetric fog, painterly, cinematic lighting, highly detailed, no text, no watermark, ~3:2 landscape`

Shared negative prompt: `text, watermark, signature, logo, frame, border, bright saturated colors, anime, photo, modern objects, extra limbs`.

**Resolution & pan headroom.** Ken Burns needs oversize plates or pans blur. Recipe:
1. Generate at SDXL-native 3:2 — **1216×832**.
2. Upscale ×2 → **2432×1664** (mcp `upscale_image`, 4x-UltraSharp or similar, then light 0.25-denoise img2img pass to re-paint upscale artifacts).
3. Play back on a 1920×1080 canvas ⇒ ~2.2× linear headroom for zooms, comfortable 20–30% pans.

**Workflow per shot** (mcp tool names; direct `/prompt` API fallback if MCP is down, per memory notes):
1. `start_comfyui` (if cold) → `health_check`.
2. `generate_image` — checkpoint: SDXL base; prompt = shot prompt + STYLE SUFFIX; negative as above; 1216×832; ~30 steps, CFG 6.5; **batch 8 seeds**.
3. Contact-sheet review (repo law: PIL contact sheet, human pick) → pick 1–2 per shot.
4. Optional fix pass: inpaint hands/faces/anatomy; the digging-creature and Lilith plates will need it.
5. `upscale_image` ×2 → img2img polish → export PNG to `assets/art/cinematics/c<chapter>/s<shot>.png`.
6. Optional cheap layers per shot: a tileable fog PNG (scrolled in-engine), an ember-particle overlay (existing vfx), a luminance flicker mask for firelight. Max 2 layers/shot.
7. Grade pass: one shared LUT-ish `CanvasItem` shader (grain + vignette + slight desat) applied by the player scene, so all 40 plates read as one film even across gen batches.

**Budget:** 6 films × ~7 shots × 8 seeds ≈ 340 generations ≈ one afternoon on the 5070 Ti. Cheap enough to iterate; the MAP-MASTERPIECE law ("iterate forever") applies in spirit — plates are replaceable one PNG at a time without touching data or code.

**Lore ART PROMPT registry → shot assignments** (grep `ART PROMPT` in `_lore_extract.txt`):

| ID | Line | Subject | Serves |
|---|---|---|---|
| L35 | 35 | Bloodstone emblem over black ledger | C1-S1 (title), C6-S1 |
| L378 | 378 | Grey dead man walking fog-drowned village road | C1-S7 + the Chronicler's recurring signature shot (re-seeded per film: C2-S7, C4-S1) |
| L533 | 533 | The crystal writing runes inside itself, underground | C1-S5, C5-S7 |
| L912 | 912 | Crowned queen crawling from a shallow grave, eclipse | C1-S4, C5-S4 |
| L1174 | 1174 | Aged parchment map of Draconia | C1-S2, C2-S1 (re-seeded closer crop) |
| L1537 | 1537 | Four banners/thrones in shadow | C2-S2 |
| L2041 | 2041 | Alchemist workbench, blue paste, thread of light | C3-S5 |
| L2375 | 2375 | Kriggar portrait (USE CROPPED/BACKLIT ONLY — never full face) | C4-S8, C5-S6 |
| L2842 | 2842 | Gallery of border-town commoners, candlelit | C1-S3, C3-S2 |
| L3128 | 3128 | The digging creature erupting through a cellar floor | C3-S3 |
| L3517 | 3517 | Cursed relics on dark cloth | C4-S6 |
| L3880 | 3880 | The vast underground Pit, molten glow + veil-light | C5-S5, C6 (TRANSMIT/RECEIVE variants) |

All other shots are **derived prompts** (written below inline), each = subject line + STYLE SUFFIX.

---

### A.3 The six films — shot lists + narration drafts

Subtitle rule: subtitles on by default (Options suite accessibility law), gold-on-black in the ornate UI kit face, bottom-center inside the letterbox. `[tags]` are Maya1 emotion tags; `((L#))` = lore prompt; `((D))` = derived prompt given inline. Whisper-language lines are subtitled in the untranslated original only.

---

#### C1 — "THE PAUSE" (opening · ~2:40 · 8 stills)

The world, the war, the stone, the Pause — and one village where the water has started tasting of coin. Ends exactly where the player begins.

| Shot | Plate | Camera |
|---|---|---|
| S1 | ((L35)) the emblem: amber-red crystal over the black ledger | Slow zoom IN from wide; hold on the runes; title card fades over |
| S2 | ((L1174)) the parchment map of Draconia | Pan W→E across all four capitals; slight rotation, candlelight flicker layer |
| S3 | ((L2842)) commoners: herb-woman, blacksmith, baker, hooded seer | Lateral dolly across the faces, ending on the seer's red flicker |
| S4 | ((L912)) the crowned queen crawling from the grave, eclipse | Zoom OUT from her hand in the dirt to the burning kingdom |
| S5 | ((L533)) the crystal writing runes inside itself, underground | Very slow zoom IN; rune-glow flicker layer; the ONLY warm light in the film |
| S6 | ((D)) *A weathered standing stone at a muddy crossroads at dusk, carved angular marks half-faded, dead grass lying combed in parallel lines around its base, a dead man's handprint on the stone* | Tilt DOWN the stone, from the fading marks to the handprint |
| S7 | ((L378)) the grey traveler walking the fog-drowned village road | Locked-off; only the fog layer moves. Longest hold in the film |
| S8 | ((D)) *A small fogged village at first light seen from a hilltop, thatched roofs, a stone well at its heart, a graveyard at its edge, one lit window* | Slow crane-feel zoom IN toward the lit window; hard cut to gameplay in Raven Hollow |

**Narration draft:**

> [calm] There was a war. There is always a war, in the old stories — but this one you would not have sung about. Four peoples came out of it wearing crowns, and none of them came out of it alive. Not in the way that matters. `<breath>`
>
> The dead queen of the north. The wolf-king at his forges. The vampire in his maze of a city, and the last human throne — poor, crowded, and stubborn — praying no one notices it. `<sigh>` Four kingdoms. Four appetites. A cold war balanced on a held breath.
>
> And under all of it — under the roads, under the wells, under the graves they never dug deep enough — something that was here before any of them. It does not march. It does not burn. It **writes**. `<whisper>` And everything it writes comes true.
>
> [flat] They stopped it once. Cost them more than the war did. They called what was left the Pause — as if naming a thing "paused" could make it permanent. `<breath>` A bookmark is not an ending. Something put its thumb in the page.
>
> I have been walking a long time, and I will tell you what I told no one: the marks on the boundary-stones are getting shorter. The wells are turning the taste of coin. And in a village called Raven Hollow — `<whisper>` the ground is warm where it should not be.
>
> [quiet] That is where you come in. It is where everyone comes in, sooner or later. It arranges that.

---

#### C2 — "FOUR APPETITES" (Act I → II · ~2:00 · 7 stills)

Plays when the player first leaves the Border ring (crossing the Stonepath into any kingdom arm). The Border taught symptoms; the kingdoms will teach arrangements.

| Shot | Plate | Camera |
|---|---|---|
| S1 | ((L1174 re-seed)) map, tight crop on the Border ring, roads radiating to the four capitals | Zoom OUT from the crossroads to the whole continent |
| S2 | ((L1537)) four banners and thrones in shadow | Slow pan across all four; hold a half-beat longer on the black maze-spire |
| S3 | ((D)) *A poor crowded human river-capital at dawn, thatch sprawl, grain barges, an orphanage wall painted with children's chalk handprints* | Crane-feel drift down toward the chalk wall; end near ONE faintly copper-stained handprint (do not center it) |
| S4 | ((D)) *A volcanic forge-city under red haze at night, hundreds of chimneys, rivers of molten channels between black towers, tiny laborers on iron walkways* | Slow lateral pan; ember drift layer |
| S5 | ((D)) *A black labyrinthine city built into a ridge-cleft at perpetual dusk, oil lamps and pale bioluminescent lichen, a single windowless violet-black spire above it all* | Tilt UP the spire; a faint orange bleed at its base, barely readable |
| S6 | ((D)) *A blue-black stone city under unnaturally clear night air, no fog, streets lit by thin blue threads of light, rows of motionless figures standing in a market square* | Very slow zoom IN on the rows; nothing moves; no fog layer — its absence is the effect |
| S7 | ((L378 re-seed)) the grey traveler, now on a kingdom road, capitals on the horizon | Locked-off, fog layer; he is smaller in frame than in C1 |

**Narration draft:**

> [dry] The Border will lie to you, in its kind way. It will let you think the sickness is a village matter — a bad well, a flat loaf, a neighbor who stands too still. `<breath>` Then the roads open, and you learn what the villages are between.
>
> Four capitals. I have slept in all of them, and I can tell you there is no safe one — only four different appetites wearing four different crowns.
>
> The West is hungry and human and full of bread it cannot eat. The South eats labor — the forges of Sangeroasa do not stop, and the ledger at the Debt Pit is longer every spring. `<sigh>` The East eats **secrets**. In Blestem they will buy the shape of your fear at market rates and sell it back to you with interest. And the North… [pause] the North does not eat at all anymore. That is what is wrong with it.
>
> [flat] You will be useful to all of them. That is not a compliment. Kings and councils will hand you errands with clean edges and good pay, and the errands will be true, and the pay will be honest. `<whisper>` And every single one of them will move something an inch that wanted moving.
>
> [quiet] Do the work. Take the coin. But count the inches.

---

#### C3 — "THE QUIETING" (mid-Act II false victory · ~2:10 · 7 stills)

Plays at the TP-10 reversal: the stones are shattered, the world's brightest week ends, and the alchemists find shifting orange at every break-face. The film is the tonal hinge of the whole game — it must be warm for a full minute before it turns. (Tone law: warmth that earns its dread.)

| Shot | Plate | Camera |
|---|---|---|
| S1 | ((D)) *A jubilant village harvest festival at golden hour, long supper tables, lanterns strung between houses, real bread risen high, villagers laughing* | Warm slow pan; the ONLY golden-lit plate in all six films |
| S2 | ((L2842 re-seed)) the commoners again — but smiling, candlelit, at a supper table | Gentle zoom IN on the herb-woman's face |
| S3 | ((L3128)) the digging creature erupting through the cellar floor | Fast-for-us zoom (still slow); held under the narration of its death — the trophy shot |
| S4 | ((D)) *Villagers and soldiers of four rival liveries toppling a carved standing stone with ropes, dust in the air, cheering, a bonfire of rubbings* | Pan along the rope-line, all four liveries pulling together |
| S5 | ((L2041)) the alchemist's workbench, blue paste, the thread of light | Slow zoom IN on the copper bowl |
| S6 | ((D)) *A shattered standing stone in wet grass at dawn, every broken face glowing a faint shifting orange, cart-tracks leading away in all directions* | Tilt from the break-faces UP along the cart-tracks to the horizon |
| S7 | ((D)) *A crossroads inscription stone now perfectly blank, smooth as an egg, a dead man's handprint the only mark left, a raven watching* | Locked-off. Hold. Hold longer than is comfortable |

**Narration draft:**

> [warm, almost smiling] I want you to remember the week the bread rose. `<breath>` Write it down somewhere the way I did. The wells ran clean. The dust lay any way it pleased. Old men asked what year it was and laughed at the answer. Four kingdoms that had spent a century sharpening knives for each other pulled on the same ropes, and the stones came down, and we **won**.
>
> [pause] We won. `<sigh>` Say it out loud. It even sounds true.
>
> [flat] The beast that dug the ground out from under our floors — dead at the crossroads, and by your hand, mostly. The stones — broken, all along every road you ever cleared. And for seven days the world remembered what it was for.
>
> `<breath>` Then the alchemists went back with their blue light, the good ones, the ones who check. And every broken face of every broken stone was shining that color that is not fire. [quiet] Shifting. Orange. **Alive.**
>
> `<whisper>` It didn't go quiet because we hurt it. It went quiet because it was finished. A thousand stones became ten thousand seeds, and we carted them ourselves — as ballast, as rubble, as hearthstones — down every road we were so proud of opening.
>
> [tired] The old songs had three notes. Ours have two. `<breath>` I counted again last night, at the inn with the good stew. `<whisper>` It is very nearly one.

---

#### C4 — "THE DROWNED LEDGER" (Act II → III · ~2:20 · 8 stills)

Plays on boarding the Grey Ferry at Riverfork (Z11 → Z30). The era-crossing voyage: the player sails into the future the map grows into. The film's job is to make Continent 2 feel like *consequence*, not like a new zone.

| Shot | Plate | Camera |
|---|---|---|
| S1 | ((L378 re-seed)) the grey traveler at a rotting dock at dusk, a grey ferry waiting | Locked-off; lantern flicker layer |
| S2 | ((D)) *A grey wooden ferry on black glass-flat water in thick fog, no wake, passengers as silhouettes who do not speak* | Barely-perceptible drift forward; the fog layer does the work |
| S3 | ((D)) *A drowned city rising out of fog: gaslight that does not reach the ground, brackish canals between leaning tenements, rooftop walkways* | Crane-feel drift DOWN from gaslight level toward the black water |
| S4 | ((D)) *A vast bureaucratic hall of ledger-desks stretching into darkness, grey-skinned clerks filing stone tablets, one tablet glowing faintly warm* | Pan along the desks; end on the warm tablet, off-center |
| S5 | ((D)) *Grave-rows to the horizon on a grey plain, each grave marked with a small stone tablet, perfectly aligned, morning fog* | Slow zoom OUT — the rows never end |
| S6 | ((L3517)) the cursed relics on dark cloth | Tilt across: axe → dagger → heart-stone → glowing scroll |
| S7 | ((D)) *An enshrined museum alcove holding one old woman's plain walking stick behind glass, votive candles, an engraved caption plaque* | Slow zoom IN on the stick; the plaque stays unreadable (no-text law works FOR us here) |
| S8 | ((L2375, from behind / silhouette crop)) the coated figure at the ferry rail, fog, a faint ember-glow at the chest barely visible | Locked-off. He is looking where we are going |

**Narration draft:**

> [flat] There is a boat at Riverfork that does not advertise. It costs what you'd expect and it goes where you wouldn't. `<breath>` The sailors call the run the drowned ledger route. They do not call it anything else, and they do not say it twice.
>
> I am going to tell you where it goes, and you will not believe me, and that is fine. It goes **forward**. `<sigh>` A thousand years, give or take a bookkeeping error.
>
> [quiet] This is Greyhollow. This is what won. Not the wolves, not the vampires, not the dead queen — the **ledger** won. Somebody found a cure for the whispering stone, and the cure learned to whisper. Now every soul on this coast carries a little tablet that says what they owe and when they stop. They call dying "being collected." They call it that because it is accurate. `<breath>`
>
> There's a museum here. [a dry huff — almost a laugh] `<laugh>` A museum. They have an old woman's walking stick in a case with candles around it, and the little plaque underneath gets her wrong. I knew— [pause] `<sigh>` I knew of her. She'd have hit them with it.
>
> `<whisper>` Here is what matters, traveler. Everything on this coast is the world's oldest record keeping itself. It knows every name that ever mattered. `<breath>` And somewhere in that hall of desks, in an era you should never have lived to see — a file with your name on it is already open.

---

#### C5 — "THE ONLY OPTION" (pre-finale · ~2:20 · 7 stills)

Plays at the thread-gate after TP-15, as the player steps from the Archive into Black Night to descend after the walker. It restages Lilith's burial as the player's own — the arrangement, named at last.

| Shot | Plate | Camera |
|---|---|---|
| S1 | ((D)) *A single warm hearth-lit refuge at the edge of a grey waste, chalk handprints on the wall, supper laid, one chair pushed back and empty* | Slow zoom IN on the empty chair |
| S2 | ((D)) *A lone figure walking away down a road of blue thread-light into darkness, seen from behind, small, not turning around* | Locked-off; the figure was composited smaller than feels right |
| S3 | ((D)) *An ancient gate of woven blue threads standing in a ruined archive hall, and through it, impossibly, a blue-black city under a clear night sky* | Drift THROUGH the gate (zoom in until the far city fills frame) |
| S4 | ((L912 re-seed)) the crowned queen — this time at rest in a shallow grave, hands folded, the eclipse setting | Tilt UP from her folded hands to the crater's rim, where tiny figures stand |
| S5 | ((L3880)) the Pit: molten glow, veil-light, iron walkways, runes on every surface | The film's longest, slowest zoom OUT — scale as dread |
| S6 | ((L2375, chiaroscuro crop: coat, jaw, the ember at the sternum — no eyes)) | Very slow zoom IN toward the ember. One shot, one time, per the rule |
| S7 | ((L533 re-seed)) the crystal writing runes inside itself — closer now, almost tender | Zoom IN until the rune-light fills the frame; cut to black ON a heartbeat |

**Narration draft:**

> [quiet] Six hundred years ago it needed a queen. So it took everything from one — her war, her kingdom, her death, even her grave — and when there was nothing left of her but rage and a door only she could hold shut, it let her find the pit. `<breath>` Her people say she chose it. `<sigh>` She did. That is the terrible part. Choosing was the trap.
>
> [flat] It has never forced a hand. Not once, in all the ages I have counted. It **arranges**. It starves the field so the bargain looks like bread. It empties the road so there is one way left to walk. And when it wants you — [pause] it does not come for you. `<whisper>` It comes for someone you saved.
>
> [tired] So. Someone you love is walking north tonight, and every soul at the Last Hearth begged you to go after them, and going after them means going **down**. And it feels like your idea. `<breath>` I know. It felt like hers.
>
> [quiet, urgent-under-flat] Listen to me now, because I will not be there, and the dark below Black Night does not repeat itself. The stone reads the living. A living hand at its surface **receives** — and the record becomes the world. But a dead hand… `<whisper>` a dead hand can write.
>
> `<breath>` Whatever you do at the bottom of that pit — whatever it offers, however sweet the voice, however much it sounds like rest — [the words come slowly] don't do it alive. Don't—
>
> *(cut to black; the heartbeat continues two beats into the gameplay load)*

---

#### C6 — "A BOOKMARK, NOT AN ENDING" (epilogue · ~1:30 each · 3 variants × 5 stills)

Dispatches on the TP-16 stage-4 outcome. All three variants share S1 and S5 framing; the middle differs. The Chronicler's final lines are the game's last spoken words after Vasile's closing beat.

**Shared shots:** S1 = ((L35 re-seed)) the emblem, but the ledger now shows one line disturbed (derived variant per ending). S5 = ((L378, final re-seed)) *the grey traveler walking away down the Raven Hollow road at first light, seen from the village gate, going, not coming* — the C1-S7 composition mirrored.

**TRANSMIT variant (the earned ending):**
- S2 ((D)) *the Pit dark and still, the crystal's inner fire dimmed to a coal, one small handprint glowing faintly on its surface* — zoom out.
- S3 ((D)) *Vetka at spring: bread risen on a sill, dust lying anyhow, a child's tuneless humming implied by an open window* — warm pan.
- S4 ((L1174 re-seed)) the map, whole, both continents, dawn-lit parchment.

> [quiet] It is not dead. I would not lie to you, of all people, at the end of all this. `<breath>` The record is perfect and the record is patient and one line of it — one — is wrong now. Small. Warm. Somebody's stew; somebody's stick; a tune nobody taught her. `<sigh>` Wrong the way people are wrong. It cannot abide that. It will be reading that one line for a very long time.
>
> [almost warm] The bread rises. The dust lies where it falls. The songs have three notes again — a little out of tune. `<breath>` Leave them that way.
>
> `<whisper>` The Pause is a bookmark. But tonight, the thumb in the page is ours.

**REFUSE variant (the deferral):** S2 = the walker carried out (derived); S3 = ((L1537 re-seed)) the four thrones, now with two seats empty; S4 = the blank crossroads stone from C3-S7, re-seeded with ONE new mark on it.

> [flat] You carried them out. They have not woken. `<breath>` Perhaps they will. I have been wrong about worse. `<sigh>` The notes are still converging — slower, I think, or I tell myself I think it. And in the East and the North, clever hands are already reaching for what you would not touch. [quiet] You bought the world a season. `<whisper>` Somebody always has to buy the next one. Sleep while you can, traveler. The page is still open.

**RECEIVE variant (the villain's win — cold, short):** S2 = ((L3880 re-seed)) the Pit lit cold blue, orderly; S3 = ((D)) *a village street where every villager stands facing the same direction, dust in perfect parallel lines, no fog, no birds*; S4 = the emblem, the ledger now full.

> [very quiet] You touched it with a beating heart, and it said thank you the only way it knows. `<breath>` Everything is very calm now. The wells are clean. The dust is straight. Nobody is hungry, because nobody is anything. `<sigh>` It never wanted a war, you understand. It wanted the record to be **right**. `<whisper>` And a world that holds still is so much easier to write down. [pause] It was your idea. It will tell you so, in your own voice, forever.

---

### A.4 Godot playback scene — `ChapterCinematic`

One scene, `scenes/chapter_cinematic.tscn`, data-driven from `cinematic_defs.gd` (§A.5). Structure:

```
ChapterCinematic (CanvasLayer, layer 90)
├─ Black (ColorRect, full-rect, z below)     # base + crossfade target
├─ PlateA / PlateB (TextureRect ×2)          # double-buffer; crossfade via modulate
│    (each with optional FogLayer/EmberLayer TextureRect children, scrolled in _process)
├─ Grade (ColorRect + grain/vignette/desat shader)   # the shared film-look pass
├─ Letterbox (2 ColorRects, always on for chapter films)
├─ Subtitle (Label, ornate UI kit face, bottom-center)
└─ SkipHint (Label, fades in after 2 s: "Hold [Esc] to skip")
```

Playback logic (`scripts/chapter_cinematic.gd`):
- **Ken Burns** = one Tween per shot animating the active plate's `position` + `scale` between `from`/`to` rects (plates are 2432×1664 textures on a 1920×1080 canvas; the def speaks in normalized center+zoom so plates can be re-rendered at any size).
- **Crossfade** 0.8 s between shots (modulate on the incoming plate); hard cuts where the def says `cut: true`.
- **VO**: `Voice.speak("chronicler_film", line)` — add `"chronicler_film": {"speaker": "chronicler", "pitch": 1.0}` to `VoiceRegistry.VOICES`. Shot advance is time-based, not VO-gated (baked lines have known durations; a `min_dur` guard covers the silent-no-op case).
- **Subtitles**: timed `{t, text}` events per shot; respects the Options subtitle toggle + size.
- **Skip**: hold Esc/Start 1.2 s → fade to black 0.4 s → `finished` signal. Chapter films are always skippable (Steam-polish law); C1 auto-marks itself seen so replays skip-prompt immediately.
- **Music/ambience**: two `AudioStreamPlayer`s driven by the def's `music`/`amb` fields with the duck rules from A.1.
- Emits `finished(chapter_id)`; `main.gd` connects it exactly like the existing `cinematic_beat` plumbing (`main.gd` ~699) and hands control back (zone load / ending screen).
- Persisted: `SaveSystem` set `seen_chapters: Array[String]` — travel/quest code checks it before firing (chapter films fire once; replay from the main menu's "Chronicle" submenu, which lists seen chapters — free content shelf).

**QA (Engineering Law):** `tools/qa_cinematics.py` headless-asserts per def: every plate PNG exists at ≥2432×1664, every VO line has its baked ogg (hash-check via the same FNV-1a), every shot `dur ≥ 4 s`, pan rects stay inside the plate at both endpoints, total runtime within ±15% of target. Screenshot QA: the existing RH_* windowed harness plays each chapter with `RH_CINE_FAST=1` (4× speed) and captures one frame per shot for the contact sheet.

### A.5 Data format (editor-less, like everything else)

`scripts/cinematic_defs.gd` — same pattern as `quest_defs.gd`: const Dictionaries, no scenes hand-authored per film.

```gdscript
const CHAPTERS := {
    "c1_the_pause": {
        "title": "The Pause",
        "music": "res://assets/audio/cine/c1_theme.ogg",
        "amb": "res://wind.ogg",
        "shots": [
            {
                "img": "res://assets/art/cinematics/c1/s1_emblem.png",
                "dur": 18.0,
                "from": {"center": Vector2(0.5, 0.5), "zoom": 1.0},
                "to":   {"center": Vector2(0.5, 0.42), "zoom": 1.35},
                "layers": [{"tex": "fog_a", "scroll": Vector2(4, 0)}],
                "vo":   [{"t": 2.0, "line": "There was a war. There is always a war..."}],
                "subs": [{"t": 2.0, "d": 6.5, "text": "There was a war. There is always a war..."}],
                "cut": false,
            },
            # ... s2..s8
        ],
    },
    # c2..c5, plus c6_transmit / c6_refuse / c6_receive
}
```

`from`/`to` are normalized plate-space (center 0–1, zoom = canvas-heights of plate shown), so re-rendered plates never require data edits. Epilogue selection: `main.gd` picks `"c6_" + Quests.get_flag("ending")`.

---

## PART B — THE IN-WORLD CINEMATIC SYSTEM

### B.1 Shape

A single autoload **`Cinematics`** (after Quests/Voice in `project.godot` order) that plays **sequences**: flat GDScript data (steps) that drive the live world — the real camera, real NPC nodes, real weather/audio — under letterbox. No editor tooling, no AnimationPlayer authoring: sequences are data in `scripts/world_cinematic_defs.gd`, exactly as quests are data in `quest_defs.gd` (repo law).

Design laws for world-cinematics (inherit the tone + villain laws):
1. **Short.** 8–25 s. These are punctuation, not paragraphs. Anything longer belongs to a chapter film.
2. **The world performs; the camera notices.** Prefer sequences where the scripted thing would *almost* read in normal play (hammers stopping, a crane-down) — the letterbox is the game saying *look*.
3. **The stone never performs.** V-STONE beats (NPC_CAST rule: all inscription dialogue routes through the `bloodstone` pseudo-NPC) may dim lights and hold the camera — never move a monster.
4. **Skippable by default** (`skippable: true` unless a def opts out; first-entry crane shots are the only sanctioned non-skippables, and only ≤ 10 s).
5. **Player-safe:** input locked, player invulnerable, aggro cleared in a radius before start; on skip/finish, every actor and the camera restore state (positions are restored ONLY for spawned temp actors; persistent NPCs finish their walks instantly instead, so the world never visibly teleports).

### B.2 Runtime pieces

- **Camera rail:** the existing gameplay `Camera2D` is commandeered (`CINEMATIC` mode flag on it, or reparent a dedicated `CineCam` and swap `enabled`). A rail = array of `{pos, zoom, t, ease}` keys; `Cinematics` tweens through them. `cam_shake(amp, dur)` and `cam_follow(actor)` are ops, not modes.
- **Letterbox:** CanvasLayer (layer 85) with two ColorRects tweening to a 2.39:1 crop (≈13.5% of viewport height each, resolution-independent), 0.35 s in/out. Also exposed standalone as `Cinematics.letterbox(on)` for quest beats that want weight without a full sequence (retro-fit: the shipped `listener_whisper` dim in `main.gd` gains bars for free).
- **Actor layer:** ops resolve `actor` ids to live NPCs (via the NPC registry / group `npcs`, matching `npc_data.gd` ids) or to **temp actors** spawned for the sequence with `NPC.create(def)` and freed after. Required small additions to `scripts/npc.gd` (all fit the existing movement machinery):
  - `walk_to(pos: Vector2, speed := 1.0)` → uses the `_pick_new_target/_set_move_facing` path with an explicit destination; emits `arrived`.
  - `face(dir: String)` → thin public wrapper over `_apply_facing_name()`.
  - `set_scripted(on: bool)` → suspends wander/bark/aggro ticks while owned by a sequence.
- **Speech:** `actor_say` = `Voice.speak(npc_id, text)` (existing baked-first pipeline + VoiceRegistry casting) + the cinematic Subtitle label (NOT the dialogue_ui box — cinematics never open interactive UI). Bark bubbles via the existing bark path for `actor_emote("!")`-style beats.
- **World ops:** `weather(id)`, `music_duck(db, dur)`, `sfx(path)`, `lights_dim(amount, dur)` (the `listener_whisper` effect, promoted to an op), `fade(in/out, dur)`, `flag(name, value)` (writes through `Quests.set_flag` so sequences and quests share memory).

### B.3 Step format

A sequence is an Array of steps executed in order; a step runs its op and waits for it unless `"async": true` (fire-and-forget, for overlapping walk+pan). `wait` is an explicit op.

```gdscript
const WORLD_CINEMATICS := {
    "wc_sangeroasa_hammers": {
        "skippable": true,
        "once": true,                       # SaveSystem seen_cinematics
        "trigger": {"kind": "area", "zone": "sangeroasa", "rect": Rect2(4800, 3200, 640, 480)},
        "steps": [
            {"op": "letterbox", "on": true},
            {"op": "cam_rail", "keys": [
                {"pos": Vector2(5100, 3600), "zoom": 0.8, "t": 0.0},
                {"pos": Vector2(5100, 3100), "zoom": 0.65, "t": 4.0, "ease": "in_out"}]},
            {"op": "sfx", "path": "res://forging_flames.mp3", "async": true},
            {"op": "wait", "t": 2.0},
            {"op": "world_call", "group": "forge_anims", "method": "pause_anim"},   # every hammer stops
            {"op": "music_duck", "db": -80.0, "dur": 0.2},                          # dead silence
            {"op": "wait", "t": 3.0},                                               # a count of three
            {"op": "world_call", "group": "forge_anims", "method": "resume_anim"},
            {"op": "music_duck", "db": 0.0, "dur": 1.0},
            {"op": "actor_say", "actor": "pit_caller_drego", "text": "...Back to it! Nobody heard nothing!"},
            {"op": "letterbox", "on": false},
        ],
    },
}
```

**Triggers** (all data, no editor):
- `{"kind": "zone_entry", "zone": id}` — first entry, hooked where `zone_builder`/`travel_system` finish a zone load; checks `SaveSystem.seen_cinematics`.
- `{"kind": "area", ...}` — `zone_builder` reads defs at build time and drops an Area2D per trigger (same pattern as travel_points).
- `{"kind": "beat", "beat": id}` — subscribes to the existing `Quests.cinematic_beat` signal (line 119); quest defs keep using `finale_beat` strings, which may now name a full sequence. The shipped `listener_whisper` becomes the degenerate case (a 2-step sequence), unifying the beat family (`whisper_2`, `whisper_name`, `whisper_pit` from VILLAIN_ARC §5) under one system.
- `{"kind": "call"}` — explicit `Cinematics.play(id)` from quest/boss code.

**QA:** headless validator asserts every def's actor ids exist in `npc_data`, rails stay inside zone bounds, VO lines are baked, `once` sequences have triggers, and total step time ≤ 30 s; the RH_* harness plays each sequence in a loaded zone and screenshots the final frame.

### B.4 Ten exemplar world-cinematics

| id | Trigger | ~s | The shot |
|---|---|---|---|
| **wc_angel_wings_arrival** | zone_entry Z7 (via the river gate) | 10 | **Crane-down over the grain market** (mandated exemplar): cam starts high/zoomed-out over the docks, rail drifts down the thatch sprawl into market bustle; 3 temp porter-actors cross with sacks; a bark from a grain-wife ("Mind the barrow, love!"); no letterbox-out until the player's own sprite walks into frame bottom — the world was here before you. Non-skippable (≤10 s sanctioned). |
| **wc_sangeroasa_hammers** | area: first approach to the forge rows (Z22) | 14 | **The hammers stop for a count of three** (mandated exemplar; Z22 canon vignette): full def above — pan up the forge stacks, every `forge_anims` node pauses, total silence three beats, resume; Drego pretends nothing happened. Second trigger variant fires post-TP-10 with a FIVE-beat stop (the world darkening measurably). |
| **wc_blestem_dead_end** | area: the Lower Market cul-de-sac (Z17), night only | 12 | Camera rails down a lamp-lit alley to the canon **twelve boot-prints facing a dead-end wall**; lights_dim; a Listener temp-actor at the mouth of the alley turns its head exactly once toward the camera (face op), then back. V-STONE beat `whisper_2` chains if TP-08 rubbing count ≥ 3. |
| **wc_black_night_stillmarket** | zone_entry Z12 | 12 | The **rows of twelve**: crane-down into the still market, zero fog (weather op forces clear — its absence is the horror), cam_rail tracks laterally along a row of Iele shells; one shell's name-tag flickers on for half a second (Ilka's named-shells hook, TP-11). No VO, no music — ambience only. |
| **wc_shortening_inscription** | beat: TP-05 approach (Z6 crossroads) | 16 | Cam pushes in on the standing stone; lights_dim; the Listener actor `face`s the player and `actor_say`s the flag-keyed deed line ("You burned the page." / "You copied the wall."); three-beat hold; the Listener faces back to the stone. First Tier-2 sting, staged. |
| **wc_bent_oar_stranger** | beat: evening after TP-05, entering the Bent Oar (Z3), night_only | 18 | Interior: letterbox; cam holds on a corner table where a grey temp-actor sits over untouched stew; he `actor_say`s the "Don't read the stones..." line (VoiceRegistry: speaker `chronicler`, pitch 0.98 — the films' voice, uncommented); fade-out 0.5 s, fade-in — the chair is empty, the stew still steams. Flag `met_stranger`. |
| **wc_quieting_reversal** | beat: TP-10 world-state flip | 20 | The one world-cinematic allowed to hurt: festival square, warm; cam finds the alchemist's bench (L2041 staging in-engine); her blue lamp passes over a stone shard — `lights_dim`, every lantern in the square dims one held breath (the `listener_whisper` op at town scale); `music_duck` kills the festival theme mid-phrase; she `actor_say`s: "…it's at every break. Every single one." Chains into chapter film C3. |
| **wc_grey_ferry_departure** | call: boarding the ferry (Z11 docks) | 22 | The era-crossing send-off: player auto-walks aboard (`dead_walk`-style input lock reused benignly); cam rail pulls back and up as the ferry slides into the fog wall; weather op thickens fog to white-out; one bell sfx; fade; the same rail plays REVERSED as the arrival at the Grey Piers, palette now brackish (the two docks are cousins — sell the millennium with symmetry, not exposition). |
| **wc_warm_tablet** | beat: TP-12 first hour in Greyhollow (Z27 shoreline) | 15 | Cam tilts down to the waterline; a temp tablet-prop washes against the stones; cam_zoom to close; `lights_dim` + faint heat-shimmer shader on the tablet; Pell (if present) `walk_to`s the shore, picks it up (emote), goes very still (a 2-beat wait is the acting); letterbox out BEFORE his dialogue — the reveal itself plays in normal dialogue_ui, where the player must press the button to hear their own name. The cinematic frames the dread; the interaction lands it. |
| **wc_last_hearth_walker** | beat: TP-15 supper scene (Z40) | 25 | The system's graduation piece: hearth interior, warm; the saved NPC (flag-priority walker) sits mid-table; mid-bark they stop — `set_scripted`, stand (anim), `face("north")`, `walk_to` the door as every other actor `face`s them in a stagger (0.2 s waves); cam_follow the walker out into the night until the thread-gate's blue light rims the frame; `actor_say` from behind the camera — Maren-echo NPC: "Go after her. Please." Letterbox stays ON as input unlocks — the bars only lift when the player takes their first step north. The game's one non-consensual frame: the choice that feels like your idea. |

### B.5 Build order

1. **`Cinematics` autoload + letterbox + cam_rail + fade/dim ops** — retrofit `listener_whisper` as the first data-defined sequence (proves the beat bridge; zero new content needed).
2. **Actor ops** (`walk_to`/`face`/`set_scripted` on NPC, temp actors, `actor_say` + subtitle) — ship `wc_bent_oar_stranger` as the vertical slice (it exercises voice, night_only, temp actors, and a flag).
3. **Triggers** (zone_entry + area via zone_builder; SaveSystem `seen_cinematics`) — ship the two mandated exemplars (`wc_angel_wings_arrival`, `wc_sangeroasa_hammers`).
4. **ChapterCinematic scene + defs + QA scripts**; generate C1's 8 plates (all its prompts exist today: L35, L1174, L2842, L912, L533, L378 + 2 derived); cast + bake the `chronicler` voice; ship C1 at new-game.
5. Remaining plates/films batch with their campaign arms (C2 with batch B, C3 with the TP-10 event, C4 with batch G, C5/C6 with the Pit).

**Non-negotiables checklist (for every future cinematic, either kind):** the stone arranges, never acts — on film too · whisper-language never translated, never subtitled in translation · warm is wrong (any warm-lit plate or sequence must be earning a later dread) · the Chronicler/Stranger is never named, never fully lit, never confirmed · chapter films always skippable; world-cinematics ≤ 25 s · all defs are GDScript data; all VO baked-first; all of it headless-QA'd.
