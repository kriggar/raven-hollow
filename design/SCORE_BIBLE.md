# THE DRACONIA SCORE BIBLE
**Raven Hollow · Hans-Zimmer-level score & ambiance mandate (MANDATES.md, Audio & Voice) · Godot 4.6**

> *"The old songs had three notes. Ours have two. Nobody planned that. The world's just… agreeing with itself. And when it fully agrees, it stops."* — the Archivist (`_lore_extract.txt` ~683–684)

**The concept is canon, not a gimmick:** the Bloodstone's name IS a three-note melody, and *as the notes converge to one tone, the broadcast completes* (lore ~97–100, ~669–684; Rules of the World #7, ~870–873). Therefore the entire score is one long, 60-level performance of the villain's name being slowly pronounced. Every theme in the game is a harmonization, inversion, fragmentation, or rhythmicization of the same three notes; across the acts the outer notes physically drift toward the center; the finale is a single tone. **The soundtrack is the villain closing in.** The player who never reads a lore page still hears the doomsday clock — that is the whole design.

Canon sources: `_lore_extract.txt` (cited by ~line), `design/VILLAIN_ARC.md` (TP-## touch-points), `WORLD_PLAN.md` (Z# zones). Engine facts read from `scripts/main.gd` (§7). Sibling mandates honored: BE CHEAP, VERIFIED FREE ASSETS ONLY, ROCKSTAR-GRADE audio QA, the 10k Sound Council, TONE LAW (heavy-cheerful, Witcher-3).

---

## 1. THE NAME — the three-note motif

### 1.1 The notes

**C — E♭ — D.** Sing it: *up a minor third, down a half step, rest.*

| Note | Role | Interval it creates | Why |
|---|---|---|---|
| **C** | The reach | — (departure) | The human note. Every folk tune in the Border starts here; it is where songs *used* to begin. |
| **E♭** | The wrongness | **minor 3rd up** from C | The minor third is the oldest human singing interval — the child-taunt, the cuckoo, the keening. The stone's name begins by sounding *almost like a song*, because the stone never forces; it arranges. The reach lands somewhere slightly too dark. |
| **D** | THE TONE | **minor 2nd down** from E♭ | The convergence target. The broadcast tone. The half-step fall E♭→D is the "sigh" — relief offered, the stone's cruelest sentence (*"You may stop now,"* VILLAIN_ARC Whisper Register). D is chosen deliberately for the instrumentarium: open D drone on hurdy-gurdy, open D string on the fiddle, D1 (36.7 Hz) sub-drone, a low bell's hum-tone — **every diegetic and orchestral anchor in the game can hold D without effort.** The world is built to agree with itself. |

Written as intervals: **+3 semitones, −1 semitone**. Total span: a minor third (C→E♭) with the resting tone (D) *inside* the span — which is what makes literal pitch convergence possible: C rises, E♭ falls, D never moves. The name collapses inward onto its own middle.

### 1.2 Why these intervals (design defense, for the Sound Council)

1. **The minor 2nd (E♭ against D) is the engine of dread.** Held vertically it is the closest dissonance Western ears track; it is Jaws, it is the Dies-irae half-step, it is a bell slightly out of tune with its own hum. Every kingdom theme keeps an E♭ rubbing a D *somewhere* in the texture — the wrongness under the warmth (TONE LAW: warmth that earns its dread).
2. **The minor 3rd (C–E♭) is the human interval.** It lets Act I ambience hide the name inside things that sound like lullabies and field hollers. Canon requires curiosity to be the vector: the melody must be *hummable*, catchy enough that Mira hums it, Torn hums it, the player hums it. The horror is retroactive.
3. **Convergence is mechanically literal.** C and E♭ are each ≤3 semitones from D. Microtonal drift (25–50 cents per act) is trivially achievable with pitch-bent samples and detuned strings, and audibly reads as "the world going out of tune with itself" long before the player can articulate it.
4. **It survives every transformation** used in §3: inversion (−3, +1), retrograde (D–E♭–C), augmentation, verticalization (the C/E♭/D cluster chord), and rhythmicization (3 strikes: short-short-LONG) all remain recognizable after one hearing.

### 1.3 The Convergence Table (the doomsday clock, in cents)

The score is delivered in **four tuning eras**. Stems are pre-baked per era (cheap, deterministic — no runtime pitch DSP), swapped by act flag. The drift is subtle on any single day of play and devastating across a playthrough.

| Era | Levels / arc | The name sounds as | Detune of outer notes toward D | Player-facing truth |
|---|---|---|---|---|
| **Era 1 — A Chord, Distant** | 1–12 (TP-01…05) | Fragments only. Ambience hums **C–E♭** and *never plays the D*. The resolution is withheld; the village bell supplies E♭; the drones supply D without melody. Three separate tones, never assembled. | 0 cents (pure) | "The old songs had three notes." Folk cues in this era genuinely use the C–E♭–D trichord as their mode — the Border has been singing the name forever without knowing. |
| **Era 2 — Two and a Half Notes** | 12–34 (TP-06…10) | Full motif appears at touch-points, per-kingdom harmonized (§3). | C +25¢, E♭ −25¢ | Post-Quieting (TP-10), all Era-2 stems swap to **Era-2b**: C +50¢, E♭ −50¢. Diegetic musicians start dropping the C: *"Ours have two."* The Bent Oar hum is two notes (canon, TP-10). |
| **Era 3 — Two Notes** | 34–58 (TP-11…15, Continent 2) | The motif is now **E♭-quarter-flat → D**: a sigh, no reach. C survives only in *player-aligned* warm cues (Last Hearth, Moment themes) — human memory keeps the note the world has surrendered. Debt-tablets sing the three notes (canon ~2028) — the only place the full old chord is still heard, filed. | C +75¢, E♭ −75¢ | The world audibly cannot say its own old songs. Fiddles sound "badly tuned." That is not a mixing error and QA must whitelist it. |
| **Era 4 — One Tone** | 58–60 (TP-16, the Pit) | **D. Only D.** Every octave of it, from D1 sub to a glassy D6, "very nearly one" (VILLAIN_ARC stage 3). The final door: the melody plays once, complete, pure-tuned — the name spoken — then resolves to unison. | → 0 (unison) | Silence and D become indistinguishable. The TRANSMIT ending *breaks* the unison: one Moment = one wrong, warm, out-of-tune note forced back into the record (§9, cue 24). |

**Law: the pure, complete, in-tune C–E♭–D is played exactly twice in the whole game** — under the main title (before the player knows what it is) and at the last door of the Pit (when they do). Everything between is fragment, transformation, or drift. The bookends are the hindsight test in audio form.

---

## 2. SCORE PILLARS (the laws every cue obeys)

1. **The stone arranges; the score arranges.** Music never "stings" a jump-scare. Dread arrives as *arrangement*: a note missing, a layer too still, a rhythm too regular. If a cue can be read as the villain *doing* something, rewrite it as the villain *having already tuned* something.
2. **Warmth is load-bearing.** TONE LAW: the game is mostly not dread. Cheerful cues (harvest fairs, taverns, the Quieting festival) are written with full craft and zero irony — they are what the stone is trying to erase, and the finale withdraws from this account. Every warm cue hides the motif *honestly* (as mode, not as sting).
3. **Silence is an instrument with a part to write.** Not "no music" — *authored* silence with entry and exit (§4.4). Black Night's score is mostly rests. The hammers-stop beat is a notated tacet.
4. **Braams are stone-touchpoints only.** One braam per touch-point, maximum (16 + Pit stages). A braam anywhere else in the score is a defect the Sound Council rejects. When the player hears the low brass swell, it *means something noticed you* — the sound is a narrative token, not a trailer habit.
5. **Diegetic first.** Where the world can make the sound (bell, hammers, hum, foghorn, tablets), the score borrows it rather than doubling it (§5). The mix must let the world play its own instruments.
6. **Nothing loops naked.** Every stem loop-point is seam-validated (ROCKSTAR-GRADE audio QA mandate); exploration beds are ≥2:30 before repeat with 2 alternate-take variants rotated to kill fatigue.

---

## 3. THE KINGDOMS — six harmonizations of one name

Each kingdom theme is a **different transformation of C–E♭–D**, in a **different instrument palette**, so that the player's ear learns: different lands, same word underneath. Palettes are strict; instruments do not cross kingdom lines except at the Stonepath (the crossroads cue deliberately bleeds all six).

### 3.1 BORDER REGION / Vetka ring (Z1–Z6) — *"the fragment"*
- **Transformation:** incomplete statement — **C–E♭ only, D withheld** (Era 1 law). The tune always stops one note early; local folk melody is built on the trichord as a mode.
- **Palette:** worn solo **fiddle** (open D/A strings, first position, amateur warmth — a village player, not a soloist), **sparse folk frame drum**, low **dread pads** (bowed double-bass harmonics + tape-saturated drone on D that the fiddle never quite lands on). Room tone: close, dry, small.
- **Feel:** poor, kind, tired, watched. The Witcher-3 "Kaer Morhen" register: beauty with a hole in it.
- **Signature move:** the fiddle ends phrases on E♭ and lets the *drone* answer with D — the land finishes the sentence, the people don't.

### 3.2 ANGEL WINGS — WEST, Humans (Z7–Z11) — *"the inversion"*
- **Transformation:** **inversion: C–A–B♭** (−3, +1 — the reach goes *down*, humbly, and steps back up). Harmonized warm: over a B♭ major sonority the original E♭ and D become the 4th and 3rd — the same notes, made hopeful. Angel Wings sings the name *upside down and refuses its meaning* — the resistance-thesis in counterpoint (Fielderine says no every night, ~2809–2812).
- **Palette:** **worn strings** (small chamber section, gut-string warmth, audible bow noise), **hurdy-gurdy** (drone on D, melody on the trompette course), wooden flute, soft tavern percussion (spoons, stamps). Choir only as distant congregation hum.
- **Feel:** crowded, ordinary, decent. Grain markets and orphanage chalk. The most "medieval" palette in the game, on purpose — humility as the beginning of resistance (~1349–1352).
- **Signature move:** the hurdy-gurdy's D drone is *always there* — Angel Wings lives on top of THE TONE and answers it with the inverted melody. Bravery you can hear.

### 3.3 BLACK NIGHT — NORTH, Iele (Z12–Z16) — *"the cluster"*
- **Transformation:** **verticalization** — C, E♭, D sounded *simultaneously* as a frozen cluster chord. No melody. The name is not being sung here; it is being *held*, the way the Veil is held.
- **Palette:** **bowed glass** (glass harmonica / wine-glass rims, crystal bowls), **sub-drones** (D1/D2 sine + bowed bass drum), air. **Stillness as the primary instrument:** target ≥40% of any Black Night cue is silence or near-silence (canon: "a silence that is not peace," ~1304–1307; no fog, unnaturally clear air — so the mix is unnaturally clear too: no reverb wash, every sound placed in dry, still air).
- **Feel:** the quietest capital and the most wrong. Cold blue. Citizens who do not breathe get a score that does not breathe.
- **Signature move:** the cluster chord swells from nothing over ~20 s, holds, and *stops without decay* (gated release — sound that ends the way the Iele move). The absence after is the downbeat.

### 3.4 BLESTEM — EAST, Strigoi (Z17–Z21) — *"the retrograde"*
- **Transformation:** **retrograde: D–E♭–C**, as a ticking ostinato — the name read *backwards*, the way a spymaster reads everything: from the conclusion toward the source. Cazimir's tragedy in three notes: he has the word in his files and has it the wrong way round.
- **Palette:** **whisper-strings** (sul tasto, sul ponticello scratch, harmonics), **col legno ticking** (wood-on-string, clock-regular — *the listening walls keeping time*), pizzicato contrabass, breath sounds and paper-dry shaker. Perpetual-dusk register: mid-lows hollowed, hiss-quiet highs.
- **Feel:** GoT small-council menace; information as currency; twelve boot-prints at a dead-end wall. The score eavesdrops on the player.
- **Signature move:** the col legno tick pattern is the motif's *rhythm* (short-short-long) at clock tempo; every 12th bar, one tick is silently omitted — rows of twelve with one clerical error (TP-08). Players who notice earn nothing but the shiver. Correct.

### 3.5 SANGEROASA — SOUTH, Varcolaci (Z22–Z26) — *"the hammer"*
- **Transformation:** **rhythmicization + augmentation.** The motif becomes percussion: **anvil strikes in the pattern short–short–LONG** (C, E♭ as two bright anvils, D as the deep one), while **low brass** states the melody augmented, an octave down, at half speed — a king's rhetoric slowly flattening into the stone's cadence (Valrom's canon drift, ~1290–1295).
- **Palette:** **anvil percussion** (real forge metals: anvils at 3 sizes, chains, quench-hiss as hi-hat), taiko-weight low drums, **low brass** (cimbasso, bass trombone, horns in low unison), male throat-hum. The city's real hammers are the click track (§5.2).
- **Feel:** industry as violence, violence as worship; Zimmer's ostinato engine at its most literal. Loud is the resting state — which makes the hammers-stop beat (§5.2) the loudest thing in the zone.
- **Signature move:** the score's anvils are mixed *indistinguishably* from the city's diegetic hammers. The player cannot tell where the forge ends and the theme begins. In Sangeroasa the villain's name is the means of production.

### 3.6 GREYHOLLOW / CONTINENT 2 — Collector era (Z27–Z40) — *"the augmentation"*
- **Transformation:** **extreme augmentation over the arrived tone.** The **foghorn IS the D** — huge, patient, already here. Against it, a noir **solo cello** plays C and E♭ stretched to breaking length, Era-3 detuned (three-quarter-tone from D). The melody is almost over; the future is the note that got there first.
- **Palette:** **noir cello** (close-miked, smoky, portamento), **foghorn** (real signal horn, D2, irregular schedule), **water** (canal lap, drips, black-harbor swell as the percussion section), muted trumpet ghosts, detuned upright piano in a flooded room, tape hiss and gaslight flicker as texture. Debt-tablet chimes: three tiny struck tones, C–E♭–D, *pure-tuned* — the bureaucracy keeps the name in perfect filing order (canon ~2028).
- **Feel:** drowned-ledger noir. Rain that never quite falls. Mercy is a transfer, not a cancellation.
- **Signature move:** the foghorn never syncs to the music's bar lines — it is on the *harbor's* schedule. When, once per zone visit, a phrase happens to land with it, the alignment feels like being noticed. (Scripted to occur exactly once; feels like chance.)

**The Stonepath exception (Z6):** the crossroads cue is the only track where all six palettes may appear, one phrase each, handing the fragment around — four kingdoms, one word. It is the score's thesis statement and the bed for TP-05 and TP-10.

---

## 4. ZIMMER TECHNIQUES, TRANSLATED (not imitated)

| Zimmer device | Draconia translation | Where |
|---|---|---|
| **Ostinato build** (Time / Chevaliers): one cell, additive layers, no melody development — accumulation as emotion | The motif's rhythm cell (short–short–long) as the universal ostinato. Combat stems build by *adding instruments of the local kingdom palette* over the unchanging cell, 8-bar terraces. Emotional peaks add layers; they never speed up — the stone is patient. | All combat stems; TP-10 boss; the Great Battle |
| **The single sustained tone** (Joker / Dark Knight one-note cello) | THE TONE, D, as a rising-intensity held note under tension states. The tension stem in every zone is, at minimum, D sustained in the kingdom's palette. As acts pass, tension stems need fewer other notes — convergence does the composing. | Every zone's tension stem |
| **Shepard tone** (Dunkirk endless rise) | The **Listening meter** (Pit stage 3, comprehension gauntlet): a Shepard-riser on D that always seems to be arriving and never arrives — comprehension as an auditory illusion. Also, quietly, under the Orange Fog beds. | Z37–39, TP-16 stage 3 |
| **Braam** | **Stone-touchpoint token only** (§2.4): a soft-attack low-brass+sub bloom on D, with the E♭ half-step *inside* the chord. 16 touch-points + Pit stages. Never in combat, never in trailers-for-their-own-sake. Scarcity is the sound design. | TP-01…16 |
| **Silence as instrument** (Interstellar docking cut-outs) | Authored tacets: the hammers-stop (3 beats, canon), the Black Night 40% rest law, the lantern-dim whisper beats (`listener_whisper` — score *ducks to zero* for the held breath, canon TP-02), and the moment after the Quieting reversal (the world's first truly empty bar). | §5.2, Z12–16, TP-02/10/16 |
| **Detuned/processed acoustic sources** (Batman cello forests, Man of Steel pedal steel) | The Convergence Table *is* the detune plan — but sourced from acoustic performances bent in post, never raw synth detune. The world must sound like real instruments going wrong, not like electronics. | Eras 2–3, all stems |
| **Spotting restraint** (huge scores, sparingly placed) | Wilderness exploration target: music present ≤60% of walk time in Acts I–II (ambience carries the rest — zone soundscapes are canon-mandated and already shipped), rising to ≤80% on Continent 2 as the world runs out of natural sound. | MusicDirector duty-cycle (§7.6) |

---

## 5. DIEGETIC ANCHORS (the world plays the score)

These are in-world sound sources that double as score elements. They live on the SFX/ambience side of the mix but are **pitched and scheduled by the score system**, so the world and the music are one instrument. Each is a canon object, not an invention.

### 5.1 The Vetka church bell — E♭, the wrongness, rung daily
The village bell is cast slightly sharp of D: it rings **E♭**. Against the Border drone (D), every toll carries the minor-second rub — the village has been ringing the wrongness over its own roofs for generations and calls it the noon bell. Schedule: dawn/noon/dusk via `day_night.gd` hooks. Era 2b and later: the bell's *hum-tone* (the long decay partial) is pitch-bent 25¢ flat per era — the bell converging too. On the Quieting festival week it is rung joyously and, for one week only, the score tunes itself TO the bell — consonance as false victory. Players will say the festival "sounds happy" and be unable to say why.

### 5.2 The Sangeroasa forge hammers — percussion section of the South
Canon: hundreds of hammers, a pulse felt in the teeth (~1264–1266, ~1619). Implementation: the hammer soundscape is not random — it is a generative percussion grid at the South theme's tempo (72 BPM, the motif rhythm-cell distributed across hundreds of strike samples with humanized offsets). The music's anvil stems lock to the same grid, so **the city is the drummer and the theme sits in its pocket.**
**The hammers-stop beat (canon vignette, ~1296):** at scripted moments — and exactly once, unscripted-feeling, per long visit — all hammers stop for a count of three, and the MusicDirector hard-mutes every music stem for the same three beats (no fade: gated, Black-Night-style). Then both resume mid-phrase as if nothing happened. No one on the killing floor will meet your eye about it; neither will the mix.

### 5.3 The Bent Oar hum — the countdown you can drink next to
The tavern's ambient bed contains a barely-audible human hum: Era 1, two notes (C–E♭ — the "old song" fragment); post-Quieting, canon-exact, *"very nearly one."* Mira's tuneless hum (TP-02, `moment_hum`) is the same fragment, recorded as a child's voice, and returns as TRANSMIT-ending ammunition (§9 cue 24).

### 5.4 The debt-tablet chimes (Continent 2)
Tablets "sing the three notes" (canon ~2028): interaction SFX for any tablet is the tiny pure-tuned C–E♭–D chime (§3.6) — the Archive keeps the name perfectly, which is the horror. Marrow Pell's tablet-tap: just the D.

### 5.5 The Greyhollow foghorn — THE TONE, ambient
D2, on the harbor's own schedule (§3.6). In the Orange Fog wastes (Z39) the "foghorn" is replaced by something with the same pitch and *no identifiable source* — same tone, no throat. The player's ear knows the difference before their mind does.

### 5.6 Whisper beats (`listener_whisper` family)
Canon staging (TP-02/10/14/16): every lantern dims one held breath — the score does the same: full-mix duck to −∞ over 150 ms, hold 1.5–2.5 s, return over 400 ms. The whisper itself is never musical, never translated, never reverberant (it arrives *through the teeth*: dry, bone-conduction close, mono, center).

---

## 6. TENSION GRAMMAR — how the score tracks the stone's attention

The villain arc's attention-tier ladder (VILLAIN_ARC §1.4) gets an audible grammar, so the score escalates *exactly* when the arc does and never elsewhere:

| Tier | Arc meaning | Score grammar |
|---|---|---|
| 0 (lv 1–9) | You are weather | Motif only as environment (bell, hum, mode of folk tunes). No braams. Tension stems are weatherless D-drones. |
| 1 (lv 10–24) | You are a useful hand | Kingdom harmonizations state the motif at quest climaxes. First braams at touch-points. Combat stems gain the ostinato cell. |
| 2 (lv 25–40) | You are a deed | Era 2b detune. Tension stems begin *quoting the player*: the kingdom where the player made their biggest flagged choice (transcribed_chamber, fed_cazimir_rubbings…) leaks one phrase of ITS transformation into OTHER kingdoms' tension stems — deeds travel. |
| 3 (lv 40–55) | You are an entry | Era 3. Direct-address moments (TP-12/14) score as *the player's own earlier cues*, replayed warped: the Act-I fiddle fragment returns inside Greyhollow cello cues, detuned — your journal, read back. |
| 4 (lv 58–60) | You are the only option | Era 4. One tone. §9 cues 21–24. |

---

## 7. THE ADAPTIVE LAYER SYSTEM (Godot implementation)

### 7.1 What exists today (read from `scripts/main.gd`)
- One `AudioStreamPlayer` named `Music` (created in `_ensure_music()`, `volume_db = -14.0`, `PROCESS_MODE_ALWAYS`, in group `"music"` so `pause_menu.gd` volume control reaches it). Track chosen per map def via `def["music"]` path → `_start_music_for_def()` → `_start_music_for_path()`.
- One `AudioStreamPlayer` named `ZoneAmbience` (`def["ambience"]` id → `assets/audio/ambience/<id>.ogg`, −14 dB, 2.5 s fade-in tween, idempotent if same stream).
- `WeatherController` owns weather SFX independently; `RH_WEATHER` env forces states for QA.
- 8 zone themes + 8 ambience beds + 3 weather loops ship today under `assets/audio/`.

### 7.2 Target architecture — `MusicDirector` (autoload)
Replace the single `Music` player with a director that owns **one `AudioStreamPlayer` whose stream is an `AudioStreamSynchronized`** (Godot 4.3+, available in 4.6) holding the zone's stems. `AudioStreamSynchronized` plays up to 32 sub-streams sample-locked on one clock with per-stream volume — exactly the crossfade-stem model, with zero drift risk (parallel `AudioStreamPlayer`s can drift over long loops; use them only as the fallback if a zone ships stems of unequal length — and then fix the stems, because unequal stem lengths are a build error).

**Stem set per zone (the `music_set` def key):**
```gdscript
# map def (map_registry.gd) — legacy "music" key stays as fallback
"music_set": {
    "explore": "res://assets/audio/music/z17_blestem_explore.ogg",  # full bed
    "tension": "res://assets/audio/music/z17_blestem_tension.ogg",  # D-drone + palette unease
    "combat":  "res://assets/audio/music/z17_blestem_combat.ogg",   # ostinato build
    "motif":   "res://assets/audio/music/z17_blestem_motif_e2.ogg", # era-stamped name layer
    "bpm": 84, "bars": 64,
}
```
All four stems: same key (D-centric), same BPM, same length, loop-seam-validated. `motif` is the era-detuned convergence layer (§1.3) — the *only* stem swapped by act flag (`e1/e2/e2b/e3/e4` suffix), so convergence ships as data, not DSP.

**Director core:**
```gdscript
# music_director.gd (autoload) — sketch
enum State { EXPLORE, TENSION, COMBAT }
var _player: AudioStreamPlayer          # group "music", PROCESS_MODE_ALWAYS (unchanged contract)
var _sync: AudioStreamSynchronized
var _state := State.EXPLORE

const FADE := {  # equal-power crossfades, seconds
    State.EXPLORE: 3.0,   # combat->explore: slow release, Zimmer patience
    State.TENSION: 1.5,
    State.COMBAT:  0.8,   # fast attack into combat
}

func set_state(s: State) -> void:
    if s == _state: return
    _state = s
    for i in _sync.stream_count:
        var target_db := 0.0 if _stem_active(i, s) else -60.0
        var tw := create_tween()
        tw.tween_method(_set_stem_db.bind(i), _get_stem_db(i), target_db, FADE[s]) \
          .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _set_stem_db(db: float, idx: int) -> void:
    _sync.set_sync_stream_volume(idx, db)
```
Rules: `tension` stem also stays up (−6 dB) under `combat` (it is the connective tissue); `motif` volume is owned by the attention-tier logic, not the state machine. Optional polish: wrap the whole set in `AudioStreamInteractive` for bar-quantized combat entries (transition on next beat/bar with auto-crossfade) — adopt only if the immediate crossfade reads as cheap in playtest; immediate + 0.8 s equal-power is the proven-cheap default (BE CHEAP).

### 7.3 State inputs (who calls `set_state`)
- **COMBAT:** `combat.gd` — on first hostile aggro within ~600 px (the sight radius the 40-Second Rule already uses); release 4 s after last combatant drops/leashes (hysteresis; no flip-flap at territory edges).
- **TENSION:** any of — night in a hostile zone (`day_night.gd`), villain-arc `cinematic_beat` pre-roll, warm-ground/inscription proximity (the "warm is wrong" decals already carry positions), Listening-meter > 0 (Pit), boss-room entered.
- **EXPLORE:** default.
- **Whisper duck (§5.6):** `Quests.cinematic_beat` family drives a director-level `duck(seconds)` that overrides everything, including ambience.

### 7.4 Buses (extend the layout, keep the contracts)
```
Master
├─ Music          ← MusicDirector player (group "music": pause-menu volume keeps working)
│   └─ MusicDuck  (director-controlled volume for whisper beats / hammers-stop)
├─ Ambience       ← ZoneAmbience + diegetic anchors (§5) — bell/hammers/foghorn route HERE, not Music
├─ Weather        ← WeatherController players (storms auto-duck Music −4 dB via send)
└─ SFX
```
Diegetic anchors on Ambience with score-scheduled pitch/timing = the §5 illusion, while options-menu sliders (OPTIONS_SUITE) stay honest: "Music" slider never silences the world's own bell.

### 7.5 Migration path (staged, testable — Engineering Law)
1. Ship `MusicDirector` reading legacy `def["music"]` as a one-stem set (behavior identical today; smoke test green).
2. Add `music_set` support + state machine; convert one zone (Blestem — richest palette contrast) end-to-end; windowed QA capture with `RH_WEATHER`-style env force: `RH_MUSICSTATE=combat`.
3. Convert remaining zones as stems are produced (§8); add era-suffix motif swapping keyed off the villain-arc act flags.
4. Validators (§10) wired into the asset gauntlet before any stem batch lands.

### 7.6 Duty cycle (spotting restraint, §4 last row)
Exploration stems fade to −60 dB after 2 full loop passes without a state change, leaving ambience alone for 60–120 s, then return on next POI/anchor proximity. Music that is sometimes absent is music that means something when present — and it is free performance headroom.

---

## 8. PRODUCTION PATHS — honestly ranked

Constraints that do the ranking: **VERIFIED FREE ASSETS ONLY** (supreme rule), **BE CHEAP**, and one hard creative fact: *no pre-existing catalog contains our motif.* The three-note convergence cannot be curated into existence — the `motif` stems and touch-point cues **must be authored**. That single fact decides the ranking.

### Rank 1 — HYBRID: authored motif layer over generated/CC beds *(recommended; adopt)*
- **How:** the `motif`, touch-point, and finale stems are sequenced by hand (they are, by design, three notes and their transformations — a MIDI craft job, not a virtuoso job) and rendered with **CC0/free orchestral sample libraries**: **VSCO-2 Community Edition** (CC0 — strings, brass, winds, orch percussion), **Versilian VCSL** (CC0 — huge misc/percussion incl. anvils and bells), **Salamander Grand** (CC-BY), plus free-with-EULA-clearance synth/glass sources where CC0 gaps exist (Spitfire LABS is free and its EULA permits use in games, but it is *not* CC — run it through the Asset Gauntlet's license verification explicitly; if the gauntlet balks, bowed-glass gets sampled from VCSL crystal/glass sets and our own recorded wine-glass takes, which are owner-original and automatically clean).
- Exploration/tension/combat *beds* come from Rank-2 local generation and Rank-3 curated CC, then are **conformed**: pitch-mapped to D-centric keys, tempo-mapped to the zone BPM, the authored motif layer mixed on top. Stem-layering of CC recordings (path d) lives inside this rank as a technique, not a separate path — CC-BY/CC0 licenses permit adaptation (avoid ND-licensed tracks entirely; avoid NC for a commercial future — enforce in the gauntlet).
- **Cost:** ~0 money; the spend is working hours. Fits every mandate. **This is the plan.**

### Rank 2 — LOCAL GENERATION on the 5070 Ti (MusicGen / Stable Audio Open / ACE-Step) *(adopt as the bed factory)*
Feasibility on the 16 GB 5070 Ti (the ComfyUI + MCP rig is already proven for images, and the MCP server exposes `generate_audio`):
- **Stable Audio Open 1.0** — 44.1 kHz stereo, up to ~47 s per generation, runs comfortably in ComfyUI's native audio nodes on 16 GB. Best at *texture, ambience, percussion beds, drones* — i.e., exactly what beds need. Weak at long-form melody: irrelevant, the melody is ours.
- **MusicGen (Meta)** — `musicgen-stereo-large` (3.3B) fits in fp16 (~7 GB weights); 32 kHz output (EQ/upsample in post — acceptable under a pixel-art aesthetic, but route its output to beds, never to featured solo lines). **`musicgen-melody`** accepts a melodic conditioning track: feed it the motif as a rendered guide and it will harmonize *around our actual three notes* — the only generative path with direct motif control. Generation ≈ real-time-ish for 30 s chunks on this GPU.
- **ACE-Step (3.5B)** — long-form (minutes) coherent instrumentals on 16 GB; useful for first-draft full beds to be chopped into stems.
- **Licensing honesty:** MusicGen weights are CC-BY-NC — **NC: outputs are contaminated for a commercial future; use MusicGen for sketching only, never for shipped assets, or accept the game stays non-commercial.** Stable Audio Open's license permits commercial use of outputs for small entities (verify current terms in the gauntlet at generation time and log it). ACE-Step is Apache-2.0. **Default shipped-bed generator: Stable Audio Open + ACE-Step; MusicGen = scratchpad.**
- **Prompt recipes (Stable Audio Open, per palette):**
  - *Border:* `lonely folk fiddle, sparse frame drum, low drone in D, dark medieval village, sorrowful, slow, sparse, field recording warmth, 60 bpm`
  - *Angel Wings:* `hurdy-gurdy drone in D, warm chamber strings, wooden flute, medieval market, hopeful but weary, 84 bpm, acoustic, intimate`
  - *Black Night:* `bowed glass harmonics, deep sub drone, vast silence, glacial, no rhythm, dark ambient, unsettling stillness, sparse single tones`
  - *Blestem:* `whispering string harmonics, col legno ticking rhythm, pizzicato double bass, tense espionage, quiet, dry, clockwork, 84 bpm minor`
  - *Sangeroasa:* `industrial anvil percussion, taiko drums, low brass drone, volcanic forge, relentless ostinato, 72 bpm, heavy, dark epic`
  - *Greyhollow:* `noir solo cello, distant foghorn, dripping water, detuned piano, rainy harbor at night, slow, smoky, melancholic, sparse`
  - Suffix every bed prompt with `instrumental, no vocals, seamless loop` and generate 4–6 takes per stem; the Sound Council picks; conform to D and BPM in post.
- **Cost:** electricity. Cheapest bed source that can match the palette specs.

### Rank 3 — CURATED PRO-GRADE CC (real catalogs that fit) *(adopt for gap-fill + reference)*
Named composers whose free/CC catalogs genuinely fit Draconia (verify each track's exact license at download; **reject NC and ND** for anything shipped; credit per license — the credits pipeline already exists for the 17 shipped audio files):
- **Alexander Nakarada** (serpentsoundstudios / FMA, CC-BY 4.0) — large medieval/folk catalog: hurdy-gurdy, fiddle, tavern sets. Angel Wings / Border beds and diegetic tavern tunes.
- **Vindsvept** (CC-BY 4.0) — folk-fantasy fiddle/harp instrumentals; Border wilderness gold.
- **Kai Engel** (FMA, CC-BY 4.0) — somber piano/orchestral; Greyhollow and Act-III interiors.
- **Scott Buckley** (scottbuckley.com.au, CC-BY 4.0) — modern cinematic strings; tension/emotion beds that take the motif overlay well.
- **Kevin MacLeod** (incompetech, CC-BY 4.0/3.0) — enormous range incl. dark ambient ("Ossuary" series and kin); utility gap-fill.
- **Alexandr Zhelanov** (OpenGameArt, mostly CC-BY 3.0/4.0) — dark orchestral/adventure, made *for* games; combat beds.
- **Matthew Pablo** (OpenGameArt, CC-BY 3.0) — pro orchestral game scores ("Soliloquy" etc.); explore beds.
- **cynicmusic / Brandon Morris (HaelDB)** (OpenGameArt, CC0) — CC0 ambient/fantasy; free-to-mangle stem fodder.
- **Yubatake, Otto Halmén, Marcelo Fernandez, HorrorPen** (OpenGameArt, CC-BY variants) — medieval/dark one-offs.
- **"Of Far Different Nature"** (fardifferent.itch.io, CC-BY 4.0) — hundreds of loopable game tracks; adaptive-friendly.
- **Explicitly excluded:** Tabletop Audio (CC-BY-**NC**), Adrian von Ziegler / Darren Curtis-style "free with credit but not CC" catalogs unless their terms pass gauntlet verification in writing.
- **Honest limitation:** none of these contain the name. Curated-only would produce a *good pastiche score* and a **broken concept** — the mandate's convergence design would not exist. That is why this ranks under hybrid despite the higher floor quality per track.

### Rank 4 — COMMISSIONING *(owner cost note; not recommended now)*
Honest market numbers: indie game composers run **$300–$1,500 per finished minute** for pro-grade bespoke work (hobbyist floor ~$50–150/min; names with credits $2k+/min). This score is ~25 cues × ~2.5 min × 3–4 stems of real material ≈ **60–90 finished minutes → roughly $20k–$100k+**, plus adaptive-stem deliverable surcharges. It is the only path that buys a live hurdy-gurdy player performing our actual motif — and it violates BE CHEAP and adds a scheduling dependency on a human. **Verdict: defer.** If the game ever earns money, commission a re-record of the 6 kingdom themes and the finale (8 cues, ~$8k–25k) over the shipped hybrid skeleton — the design transfers 1:1 because the motif spec (§1) is notation, not vibes.

---

## 9. THE CUE LIST — 25 cues, with adaptive stem breakdown

Stems: **E** = explore bed, **T** = tension, **C** = combat, **M** = motif layer (era-stamped, §1.3). "Anchor" = diegetic instrument the cue locks to (§5). All cues D-centric unless noted. Zone themes cover their whole arm (capital cue + wilds cue per kingdom keeps the count honest and the palette coherent; per-zone variation comes from ambience + stem mix, not new tunes — BE CHEAP, and WoW Classic did exactly this).

| # | Cue title | Where / when | Palette & transformation | Stems | Notes |
|---|---|---|---|---|---|
| 1 | **The Name** (main title) | Title screen | All palettes, one by one, then the pure C–E♭–D — 1 of 2 complete statements in the game | linear | Ends on unresolved E♭/D rub held under the menu loop. |
| 2 | **Raven Hollow** | Z1 (exists: `theme_lost_village` seeds it) | Border fragment; fiddle + dread pads | E/T/C/M-e1 | M-e1 = C–E♭ only; the D lives in the drone. |
| 3 | **Flat Grey Bread** (Vetka) | Z2, Z3 | Border; warmer, more frame-drum, tavern hum anchor | E/T/M-e1 | Anchor: Vetka bell (E♭), Bent Oar hum. No combat stem — Vetka's first monster is a symptom. |
| 4 | **The Courier Read the Wall** | Z5 Chamber Depths (dungeon) | Border palette *stripped*: pads + warming-stone sub; first braam (TP-04) | T/C/M-e1 | Music enters only after first hostiles; dungeon opens in authored silence. |
| 5 | **The Shortening Inscription** | Z4, Z6 Stonepath | All six palettes, one phrase each (§3 exception) | E/T/C/M-e1→e2 | The era seam is audible mid-arc here, on purpose. |
| 6 | **Angel Wings** (capital) | Z7 | Inversion C–A–B♭; hurdy-gurdy + worn strings | E/T/M-e2 | Anchor: orphanage children's clapping game = motif rhythm. |
| 7 | **The Full Granary** (West wilds) | Z8–Z11 | West palette, thinner; dread pads under folk fiddle | E/T/C/M-e2 | TP-06 coda: E stem drops to fiddle alone as the hungering walk east. |
| 8 | **Rows of Twelve** (Blestem capital) | Z17 | Retrograde tick; whisper-strings, col legno | E/T/M-e2 | The omitted 12th tick (§3.4). Combat inside the city uses cue 9's C stem. |
| 9 | **The Whisper Passes** (East wilds) | Z18–Z21 | East palette + mountain air; sound-carries-strangely mix (dry close, wet far) | E/T/C/M-e2 | Listener watch-posts pin T stem on proximity. |
| 10 | **The Forge That Eats** (Sangeroasa capital) | Z22 | Hammer rhythmicization; anvils + low brass | E/T/M-e2 | Anchor: the city hammer grid IS the click (§5.2); hammers-stop tacet scripted. |
| 11 | **The Gift / Bloodroad** (South wilds) | Z23–Z26 | South palette, field version: fewer anvils, more throat-hum and war-drums | E/T/C/M-e2 | Ashvents variant: T stem is *warmth* — comfortable, and wrong (canon heat-masking). |
| 12 | **The Quieting** (festival, world event) | TP-10 week | ALL palettes, major-mode, tuned to the bell; the game's brightest cue | E (+layers) | Layer-additive celebration; NO tension/combat stems exist for one week. Then cue 13. |
| 13 | **It Went Quiet Because It Finished** | Post-TP-10 world state | Every zone's M stem swaps e2→e2b (−50¢); E stems lose one instrument each | (patch) | Not a cue — a world-wide stem swap. The player's whole map is worse and cannot say how. |
| 14 | **The Still Market** (Black Night capital) | Z12 | Cluster verticalization; bowed glass + sub; ≥40% rest | E/T/M-e2b | Anchor: none — the anchor is absence. Gated releases (§3.3). |
| 15 | **Threadlands / Gravemark** (North wilds) | Z13–Z15 | North palette + wind; snow-wolf combat adds the only rhythm the North ever gets | E/T/C/M-e2b | TP-11 second-person stone: braam + full duck, text on screen, wind continues. |
| 16 | **The Grey Ferry** (era-crossing voyage) | Riverfork ⇢ Grey Piers | Border fiddle sinking under water percussion; ends in Greyhollow palette — 1000 years in 90 seconds | linear | The motif detunes e2b→e3 *during* the cue. The only place drift is audible in real time. |
| 17 | **Greyhollow** (capital) | Z27 | Augmentation over foghorn; noir cello, canal water | E/T/M-e3 | Anchors: foghorn (D), debt-tablet chimes (pure C–E♭–D). |
| 18 | **The Drowned Ledger** (C2 wilds) | Z28–Z34, Z36 | Greyhollow palette thinned: cello + water + detuned piano | E/T/C/M-e3 | Morven Reach variant: Blestem's tick returns, older, slower — the lineage audible. |
| 19 | **The Archive** | Z35 | Black Night cluster REVOICED for paper: page-turns, stamp thuds, glass — same chord, clerk's instruments | E/T/M-e3 | Marta's stick corrected → 4 bars of the *Border fiddle*, in tune, once (`moment_stick`). |
| 20 | **Orange Fog / Finalized Fields** | Z37–Z39 | Shepard-riser on D; signal-warped palette remnants | E/T/C/M-e3 | Direct-address walls: whisper duck + the player's Act-I cues replayed warped (§6 tier 3). |
| 21 | **The Last Hearth** | Z40 | ALL warm palettes, small: fiddle + hurdy-gurdy + children; **the C note restored, in tune** | E/M-e1(!) | The only Era-3 zone scored in Era-1 tuning — memory holds the note the world lost. No T/C stems. When the walker stands up (TP-15), the cue does not react. That is the horror. |
| 22 | **The Descent** (Pit stages 1–3) | Z12→Z16, TP-16 | Era 4: D in every octave, Shepard listening-meter, Lilith's grave = solo bowed glass + her contempt as sub-pulse | T/M-e4 (state-driven) | Stage 3 comprehension gauntlet: music IS the hazard meter. Standing still lets it resolve; moving keeps it dissonant. |
| 23 | **The Touch** (stage 4, the choice) | The Thirsty Stone | One tone. The second complete C–E♭–D statement plays as the hand rises — the name, spoken | linear | Then, per ending: RECEIVE → unison D swells and the mix *finalizes* (all width collapses to mono, cold blue). REFUSE → the tone persists, unresolved, under the epilogue crawl. |
| 24 | **Transmit** (the dead walk + Moment) | `dead_walk` state | Greyscale world: near-silence, footsteps, heartbeatless. The chosen Moment plays its OWN sound — Mira's hum, the stick's fiddle bars, stew-ladle clink, the ring's church bell — **out of tune with D, and it stays** | linear | The wrong warm note is forced into the unison and the unison *breaks*: final chord = D + the Moment's note, held. The Pause renewed, not won. |
| 25 | **A Bookmark, Not an Ending** (credits) | Credits | Border fiddle plays the full melody for the first time in the player's presence *as a village tune* — three notes, in tune, ordinary. As it always was. | linear | Vasile's line lands on the last E♭→D. Silence. One bell (E♭). Out. |

Combat coverage: cues 2, 4, 5, 7, 9, 11, 15, 18, 20 carry C stems (every leveling band has one); capitals reuse their arm's wilds C stem — city combat is rare and the reuse is inaudible in practice. Total unique audio ≈ 25 cues ≈ 70–85 stem files after era variants; storage trivial (OGG).

---

## 10. QA & DELIVERY STANDARDS (feeds the ROCKSTAR-GRADE mandate + Asset Gauntlet)

- **Format:** OGG Vorbis q7, 44.1 kHz stereo (upsampled 32 kHz MusicGen sketches never ship). Loop metadata via seamless-cut stems (no gap, no fade at file edges).
- **Loudness:** exploration stems **−20 LUFS-I**, tension **−18**, combat **−16**, all true-peak ≤ −1.0 dBTP; final in-game music bus lands ≈ −23 LUFS relative to a −16 LUFS-I overall game mix. Diegetic anchors mixed on Ambience per zone-soundscape levels.
- **Validators (automated, per the QA_AUTOMATION law):** LUFS/dBTP check, loop-seam click detector (analyze wrap-point discontinuity), spectral-hole check (no dead bands from generation artifacts), **motif-tuning check** — assert each `motif` stem's detected pitch centers match its era suffix within ±10 cents (a build-time script with librosa/aubio; the Convergence Table becomes a unit test). Detuned-by-design stems are *whitelisted by era*, never hand-waved.
- **Sound Council gate:** every cue passes the 10k Sound Council against this bible — specifically §2 pillars (braam scarcity is a countable check: `grep` the cue sheet; >1 braam outside touch-points = automatic NO).
- **Credits:** every CC source logged with composer, track, license, URL at acquisition time (existing credited-audio pipeline), and every generated bed logged with model, version, license snapshot, prompt, seed (ANTI-HALLUCINATION LAW: the provenance ledger is the resume point).

## 11. NON-NEGOTIABLES (pin this list)

The name is C–E♭–D and it converges · the pure complete statement plays exactly twice · braams = touch-points only · Black Night is ≥40% silence · the hammers stop for three and the score stops with them · the bell is E♭ and always was · warm cues are sincere · nothing loops naked · Era stems are data, not DSP · no NC/ND licenses ship · the finale's last chord is out of tune, and that is the victory.
