# RAVEN HOLLOW — ROCKSTAR-GRADE AUDIO QA
**Owner mandate (MANDATES.md § Audio & Voice): automated LUFS loudness, loop-seam, clipping &
spectral validators on every audio asset — feeds the QA_AUTOMATION law. Sits under the 10k Sound
Council (BACKLOG § Audio): the Council judges taste; this pipeline judges physics. Nothing reaches
the Council's ears out of spec.**

Sources of truth read for this design: `design/QA_AUTOMATION.md` (QA_JSON protocol §0.5, Finding
shape §1.2, improve loop §4, runner §5), `design/OPTIONS_SUITE.md` §3 (bus audit + target layout —
this doc extends it, never contradicts it), `scripts/main.gd` (`_ensure_music`,
`_start_zone_ambience`, `.loop = true` on both), `scripts/weather.gd` (runtime `Weather` bus,
−40→−8 dB intensity ride), `scripts/voice_client.gd` (Master-bus `_dvo` + spatial 2D players),
`scripts/pause_menu.gd` (music slider via node metadata), `tools/tts_server.py` +
`tools/bake_vo.py` (VO pipeline, tts venv), and a **live first-run measurement of the entire
shipped corpus** (§7 — every number in this doc is real, measured 2026-07-05).

---

## 0. AUDIT — WHAT EXISTS TODAY

### 0.1 The corpus (the QA targets)
| Class | Where | Count | Measured reality |
|---|---|---|---|
| Music beds | `assets/audio/music/*.ogg` | 8 | 44.1/48 kHz stereo mixed; LUFS spread **−13.0 … −22.4** (9.4 dB!) |
| Ambience beds | `assets/audio/ambience/*.ogg` | 8 | 44.1/48 kHz stereo mixed; LUFS spread −18.8 … −27.8 |
| Weather | `assets/audio/weather/*.ogg` | 3 | 2 loops + 1 one-shot (thunder); `wind_loop` is **10 dB hot** |
| Dialogue VO | `assets/vo/<speaker>/<fnv>.ogg` | **173** (9 speakers + default) | 24 kHz TTS output; per-speaker means already ≈ −19 LUFS; per-line spread up to 8 dB |
| Strays | repo root: `wind.ogg`, `crow_caw.wav`, `dark_city.wav` | 3 | unshipped orphans outside `assets/` — conformance findings on sight |
| SFX / UI | — | 0 | none shipped yet; the standard (§1) is ready for them |

19 shipped music/ambience/weather files + 173 VO lines = **192 assets** in the first corpus.

### 0.2 Engine playback reality (what the validators must model)
- `main.gd` sets `AudioStreamOggVorbis.loop = true` on **both** music and zone ambience — every
  bed wraps raw, sample N−1 → sample 0, no crossfade. **The wrap point is therefore a real,
  audible moment of gameplay** and must be validated like one (§2.3).
- Weather loops play on the runtime `Weather` bus riding −40→−8 dB with intensity; thunder is a
  one-shot on the same bus.
- Only `Master` + runtime `Weather` buses exist today. Music/ambience/VO all sit on Master with
  per-node `volume_db` offsets (music −14, ZoneAmbience −14, VO 0). OPTIONS_SUITE §3.2 already
  specs the full bus tree; §3 below adopts it verbatim and adds the ducking laws.
- VO: `tools/tts_server.py` (Maya1, tts venv) → `bake_vo.py` → 24 kHz ogg per line, filename =
  FNV hash of the text. Voice v2 rebake (MANDATES 🔄) will regenerate all 173+ lines — this
  pipeline is the gate that rebake must pass.

### 0.3 Tooling reality (verified on this machine, 2026-07-05)
The tts venv — `C:/Users/vstef/tts/venv/Scripts/python.exe` — has **everything**:
`soundfile ✓ numpy ✓ pyloudnorm ✓ scipy ✓ librosa ✓`. No installs needed. `audio_qa.py`
re-execs itself under that interpreter when `pyloudnorm` is missing from the invoking Python
(§5.2), so `py tests/qa.py` can call it without caring which Python it woke up in.

---

## 1. THE RAVEN HOLLOW LOUDNESS STANDARD (the table everything obeys)

Integrated loudness per ITU-R BS.1770-4 (pyloudnorm, K-weighted, gated). True peak per §2.2
(4× oversampled). **Assets are normalized to the standard; the MIX is shaped on buses** — after
the corpus is normalized once, the two node baselines (`Music` player dB, `ZoneAmbience` −14) get
re-trimmed once, and no per-file gain hacking ever happens again.

| Class | Integrated LUFS | Tolerance | True peak max | Sample rate | Channels | Loop | Notes |
|---|---|---|---|---|---|---|---|
| `music` | **−16.0** | ±1.0 | −1.0 dBTP | 44.1 or 48 kHz | stereo | yes | beds loop in-engine; seam laws §2.3 |
| `ambience` | **−22.0** | ±1.5 | −3.0 dBTP | 44.1 or 48 kHz | stereo | yes | includes weather loops (rain/wind) |
| `sfx_oneshot` | — (too short to gate) | — | **−1.0 dBTP**, loudest-500 ms momentary ≤ −12 LUFS | 44.1/48 kHz | mono or stereo | no | thunder, UI, combat hits; peak-referenced class |
| `vo` | **−19.0** per line | ±2.0/line; per-speaker mean ±1.0; per-speaker spread ≤ 4 dB | −3.0 dBTP | 24 kHz (TTS native — resampling up adds nothing) | mono | no | consistency law §2.6 |
| `ui` | — | — | −6.0 dBTP, momentary ≤ −18 LUFS | 44.1/48 kHz | mono | no | quiet class: clicks/hovers under everything |

Universal laws (every class): DC offset |mean| ≤ 0.002 FS · no digital-clip runs (≥3 consecutive
samples at ≥ 0.999 FS) · leading/trailing dead air ≤ 250 ms for one-shots and VO (beds exempt —
they wrap) · file decodes cleanly with soundfile · lives under `assets/audio/` or `assets/vo/`
(strays in the repo root are findings) · has a row in the manifest (§5.1).

Rationale for the anchors: −16 music / −22 ambience gives the beds a 6 dB floor under the score —
the WoW/Diablo "music breathes over the world" balance; −19 VO sits 3 dB proud of music so dialogue
never fights the score even before ducking (§3.3) adds its 6 dB of law; SFX are peak-referenced
because integrated loudness is meaningless on a 300 ms sword hit.

---

## 2. THE VALIDATOR BATTERY (`tests/audio/checks/*.py`)

Each check: `def check(asset: Asset, manifest_row: dict, cfg: dict) -> list[Finding]` — same
`Finding = {check, severity, subject, detail, fix_hint, payload}` shape as QA_AUTOMATION §1.2.
`payload` always carries the measured numbers so the remediation loop (§6) never re-measures.

### 2.1 `c_lufs` — integrated loudness per class
`pyloudnorm.Meter(sr).integrated_loudness(data)` vs the §1 table. Files shorter than 0.4 s
(pyloudnorm's block size) fall back to the loudest-idth momentary proxy: RMS of the loudest 400 ms
window, K-weighting approximated by a 2-pole highshelf+highpass (the pyloudnorm filter coefficients,
applied manually) — flagged `"method":"momentary_fallback"` in the payload (5 of the 173 VO lines
need this). Out of tolerance → `fail` beyond 2× tolerance, else `warn`.

### 2.2 `c_truepeak` — true peak + digital-clip detection
- **True peak:** `scipy.signal.resample_poly(data, 4, 1)` per channel → max |sample| →
  `20*log10` dBTP. Sample-peak alone lies: an ogg that decodes to 1.126 FS (see `theme_south`, §7)
  will slam any fixed-point output stage.
- **Clip runs:** count runs of ≥3 consecutive samples with |x| ≥ 0.999. Any run → `fail`
  (`payload.clip_runs`, positions included so a human can listen to the worst one).
- Verdict: over class dBTP ceiling → `warn` to −0.1 dBTP, `fail` at ≥ 0 dBTP or any clip run.

### 2.3 `c_loopseam` — the wrap point is a frame of gameplay
Runs only on manifest `loop: true` assets (all music + ambience + weather loops, per §0.2).
Three signals across the seam, exactly the algorithm proven on the live corpus (§7):

1. **Click** — amplitude step across the wrap, `|x[0] − x[−1]|`, divided by the median local
   step `median(|diff(x)|)` → `click_ratio`. A wrap step 8× the file's own texture is a click.
2. **Level jump** — RMS dB of the last 250 ms vs the first 250 ms → `level_jump_db`. This is the
   killer: a bed that fades out then wraps to full level "restarts" audibly every N seconds.
3. **Spectral continuity** — cosine similarity of Hann-windowed magnitude spectra, last 500 ms vs
   first 500 ms → `spec_cos`. Catches "the birds stop dead at the wrap" even at equal level.

| Signal | pass | warn | fail |
|---|---|---|---|
| `abs(level_jump_db)` | ≤ 3 | ≤ 6 | > 6 |
| `click_ratio` | ≤ 4 | ≤ 8 | > 8 |
| `spec_cos` | ≥ 0.6 | ≥ 0.4 | < 0.4 |

Row verdict = worst signal. **Music seam policy:** a theme may declare
`"loop_style": "restart"` in the manifest (an authored ending + intentional da-capo — a valid
Diablo-2-style choice) which downgrades level/spectral fails to `warn`; the default is `"gapless"`
and the corpus shows why the default must be strict (§7: five of eight themes fail gapless).
The remediation loop's seam fixer (§6.2) renders a gapless candidate automatically.

### 2.4 `c_format` — conformance
Sample rate ∈ class set · channel count per class · duration sanity (beds ≥ 20 s so the wrap
isn't a metronome — `amb_night_crickets` at 22.9 s is the shortest legal bed; VO ≤ 30 s;
one-shots ≤ 10 s) · codec = ogg/vorbis for shipped assets (`.wav` under `assets/` → fail) ·
a matching `.import` file exists (Godot has actually ingested it) · path discipline: every
audio file under `assets/`, every `assets/` audio file in the manifest, both directions
(the three repo-root strays fail here on day one).

### 2.5 `c_silence_dc` — dead air, DC, dropouts
Leading/trailing silence (< −60 dBFS RMS in 50 ms hops) vs the 250 ms budget for VO/one-shots ·
DC offset per channel `|mean(x)| > 0.002` → warn, > 0.01 → fail (DC eats headroom and thumps on
stop) · **mid-file dropout scan**: any ≥ 120 ms window at < −70 dBFS inside a bed (not at its
edges) → warn — catches encoder glitches and truncated bakes; VO exempt (pauses are acting).

### 2.6 `c_vo_consistency` — one cast, one loudness law (the 173-line sweep)
Per speaker directory: integrated LUFS per line (§2.1), then per-speaker stats:
`mean` must sit within ±1.0 of −19 · `max − min` (spread) ≤ 4 dB, warn to 6, fail beyond ·
every line within ±2 of −19 individually · sample rate uniform within a speaker · **cross-cast**:
all speaker means within a 3 dB corridor of each other (the narrator must not out-shout the
gatewarden by pipeline accident). Payload carries the full per-line table so the fixer (§6.1)
can gain-trim individual lines, not whole speakers. Measured today (§7): three speakers already
pass everything; `marta` (8.0 dB spread) is the worst offender — the numbers say per-line trim,
not rebake.

### 2.7 `c_spectral_hygiene` — warn-only ears
Cheap FFT-average checks, all `warn` (taste belongs to the Sound Council, hygiene to us):
VO with > −30 dB relative energy below 60 Hz → mic rumble / TTS artifact, wants a highpass ·
beds whose top octave (> 14 kHz) is digital zero → over-lossy source encode (transcode-of-a-
transcode detector) · one-shots whose noise floor exceeds −50 dBFS in their quietest 100 ms.

---

## 3. MIX-BUS ARCHITECTURE + THE DUCKING LAWS

### 3.1 Bus tree (adopts OPTIONS_SUITE §3.2 verbatim — created in code by `SettingsManager._ensure_audio_buses()`)
```
Master
 ├─ Music      ← main.gd Music player + main_menu.gd MenuMusic
 ├─ Ambience   ← main.gd ZoneAmbience
 ├─ Weather    ← weather.gd ambience + thunder   (bus already exists — kept)
 ├─ Voice      ← voice_client.gd _dvo + spatial 2D players
 └─ SFX        ← all combat/UI one-shots (loot window, ability whooshes, hits)
```
Node baselines stay on the nodes (OPTIONS_SUITE law: "everything at 100 % sounds like today");
buses carry the user's six sliders **and** the ducking automation. Adaptive-music stems
(MANDATES: exploration/tension/combat layers, the Bloodstone-melody score) will be *N players on
the Music bus* — the bus tree does not grow per stem.

### 3.2 The ducking laws (owner-specified, engine-enforced, QA-asserted)
| Law | Trigger | Target bus | Depth | Attack | Release |
|---|---|---|---|---|---|
| **D1 — VO ducks Music** | any Voice-bus player playing | `Music` | **−6 dB** | 150 ms | 400 ms after last VO stops |
| **D2 — VO ducks Ambience+Weather** | same | `Ambience`, `Weather` | −3 dB | 150 ms | 400 ms |
| **D3 — Combat ducks Ambience** | combat state enter (player in_combat) | `Ambience` | **−6 dB** | 250 ms | 1200 ms after combat ends |
| **D4 — Thunder ducks Music** | thunder one-shot fires | `Music` | −4 dB | 50 ms | 800 ms |

Implementation: a 60-line autoload `scripts/game_mixer.gd` — scripted tweens on
`AudioServer.set_bus_volume_db` offsets stacked *additively per law* (VO during combat = Ambience
at −3 + −6 = −9 dB), each law owning its own offset variable so releases never fight. Scripted
beats Godot's `AudioEffectCompressor.sidechain` here because it is **deterministic and
assertable**: the QA hook `RH_MIXCHECK=1` (new, follows the RH_* idiom) boots headless, plays a
silent VO stub, and asserts via `QAReport.check()` that the Music bus offset reached −6 ± 0.5 dB
within 200 ms and released within 600 ms — the ducking laws become regression-tested physics.
`GameMixer` also exposes `duck_totals()` for the dump (§5.4).

### 3.3 Spatial rules for positional SFX
- **What is positional:** world one-shots (combat hits, footsteps-not-yours, doors, crafting
  stations, creature barks, spatial VO barks — `voice_client.gd`'s 2D players already are).
  **What is not:** music, beds, weather, dialogue-panel VO, UI — always `AudioStreamPlayer`, never 2D.
- `AudioStreamPlayer2D` on bus `SFX` (spatial barks: `Voice`), `max_distance` = **one screen +
  half**: 960 px at the game's 640×360 native (you hear slightly beyond what you see — the
  Ocarina-bar "the world continues" cue), `attenuation` = 1.0 (inverse-distance),
  `panning_strength` = 0.6 (full-hard pan reads as broken headphones in top-down 2D).
- Listener = the camera (player). One `AudioListener2D` maximum; QA asserts exactly one.
- **Voice budget:** ≤ 16 simultaneous positional players; beyond that, lowest-priority steals
  first (priority: quest/bark > combat > foley). `game_mixer.gd` owns the pool; `RH_MIXCHECK`
  spawns 32 requests and asserts the cap held and the right classes survived.
- Same-frame duplicate suppression: two identical one-shots within 30 ms merge (the "eight wolves
  bite at once" comb-filter guard) — a rule the TTK probe (QA_AUTOMATION §2.5) will exercise for free.

---

## 4. QA OUTPUT — HOW THIS FEEDS `tests/qa.py`

Speaks QA_AUTOMATION §0.5 protocol exactly. `audio_qa.py` prints `QA_JSON|` lines as it scans and
a final `QA_DONE|pass|fail`, and writes `build/qa/audio_findings.json` in the §1.2 Finding shape:

```
QA_JSON|{"check":"audio_lufs","subject":"music/theme_south.ogg","status":"fail","payload":{"lufs":-13.0,"target":-16.0,"tol":1.0}}
QA_JSON|{"check":"audio_loopseam","subject":"ambience/amb_dead_wind.ogg","status":"fail","payload":{"level_jump_db":20.3,"click_ratio":0.5,"spec_cos":0.515}}
QA_DONE|fail
```

Integration: one new row in the QA_AUTOMATION §1.2 validator table — **`v_audio.py`** — which
shells to `audio_qa.py scan` (under the tts venv interpreter) and adapts
`audio_findings.json` into the main findings stream. Audio findings ride the same escalation
discipline (§1.3 there): new checks land warn-only quarantined for one green run, then enforce.
`qa.py quick` includes `audio_qa.py scan --changed-only` (mtime cache — the full 192-file corpus
scan measures in seconds, but rebakes of 173 VO lines shouldn't re-scan untouched music).

---

## 5. IMPLEMENTATION — `tests/audio_qa.py`

### 5.1 The manifest (`tests/audio_manifest.json` — data, not code)
Every shipped audio asset gets a row; `c_format` fails both unlisted files and dead rows.
```json
{ "defaults": {"music":  {"class": "music",   "loop": true,  "loop_style": "gapless"},
               "ambience":{"class": "ambience","loop": true},
               "weather": {"class": "ambience","loop": true},
               "vo":      {"class": "vo",      "loop": false}},
  "overrides": {
    "assets/audio/weather/thunder.ogg":    {"class": "sfx_oneshot", "loop": false},
    "assets/audio/music/theme_north.ogg":  {"loop_style": "restart"}   // if the owner blesses its authored ending
  }}
```
Directory defaults mean 192 files need ~2 override rows today. VO is auto-enumerated from
`assets/vo/*/` — a rebake never edits the manifest.

### 5.2 Runner skeleton
```python
#!/usr/bin/env python3
"""Raven Hollow audio QA — LUFS / true-peak / loop-seam / conformance / VO consistency.
  py tests/audio_qa.py all|scan|vo|fix|report [--changed-only] [--json build/qa/audio_findings.json]
Runs under any Python; re-execs into the tts venv for DSP deps."""
import json, os, subprocess, sys
from pathlib import Path

TTS_PY = Path("C:/Users/vstef/tts/venv/Scripts/python.exe")   # soundfile+numpy+pyloudnorm+scipy verified
try:
    import soundfile, numpy, pyloudnorm                        # noqa: F401
except ImportError:                                            # re-exec under the venv (§0.3)
    if TTS_PY.exists() and os.environ.get("RH_AQA_REEXEC") != "1":
        os.environ["RH_AQA_REEXEC"] = "1"
        sys.exit(subprocess.call([str(TTS_PY), *sys.argv]))
    sys.exit("audio_qa: no DSP env (need soundfile+numpy; pyloudnorm optional->momentary fallback)")

import numpy as np, soundfile as sf, pyloudnorm as pyln
ROOT = Path(__file__).resolve().parent.parent
CFG  = json.loads((ROOT / "tests/audio_manifest.json").read_text("utf-8"))
STD  = {  # §1 — THE table
  "music":       dict(lufs=-16.0, tol=1.0, tp_dbfs=-1.0, srs={44100, 48000}, ch={2}),
  "ambience":    dict(lufs=-22.0, tol=1.5, tp_dbfs=-3.0, srs={44100, 48000}, ch={2}),
  "sfx_oneshot": dict(lufs=None,  tol=None, tp_dbfs=-1.0, srs={44100, 48000}, ch={1, 2}, mom_max=-12.0),
  "vo":          dict(lufs=-19.0, tol=2.0, tp_dbfs=-3.0, srs={24000}, ch={1},
                      spk_mean_tol=1.0, spk_spread=4.0),
  "ui":          dict(lufs=None,  tol=None, tp_dbfs=-6.0, srs={44100, 48000}, ch={1}, mom_max=-18.0)}

def analyze(path: Path) -> dict:
    """One decode, every number. Returns the measurement payload all checks share."""
    d, sr = sf.read(path, always_2d=True); mono = d.mean(axis=1); n = len(d)
    m = {"sr": sr, "ch": d.shape[1], "dur": n / sr, "sample_peak": float(np.abs(d).max())}
    m["dc"] = float(np.abs(d.mean(axis=0)).max())
    m["true_peak_dbfs"] = true_peak_db(d)                      # scipy resample_poly ×4 (§2.2)
    m["clip_runs"] = clip_runs(d)                              # runs of ≥3 samples ≥0.999 (§2.2)
    m["lufs"] = (pyln.Meter(sr).integrated_loudness(d) if m["dur"] >= 0.4
                 else momentary_fallback(mono, sr))            # §2.1
    m["seam"] = seam_metrics(mono, sr)                         # click_ratio/level_jump/spec_cos (§2.3)
    m["silence"] = edge_silence_ms(mono, sr); m["dropouts"] = dropout_scan(mono, sr)
    return m

def scan(changed_only: bool) -> list[dict]:
    findings = []
    for path, row in corpus(ROOT, CFG, changed_only):          # manifest ∪ disk, both-direction diff
        meas = analyze(path)
        for chk in (c_format, c_lufs, c_truepeak, c_silence_dc,
                    *( [c_loopseam] if row.get("loop") else [] )):
            findings += chk(path, row, meas, STD[row["class"]])
        qa_emit(findings)                                      # QA_JSON| lines as we go
    findings += c_vo_consistency(ROOT / "assets/vo", STD["vo"])# corpus-level check (§2.6)
    out = ROOT / "build/qa/audio_findings.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(findings, indent=1), "utf-8")
    print("QA_DONE|" + ("fail" if any(f["severity"] == "fail" for f in findings) else "pass"))
    return findings

def fix(findings: list[dict]) -> None:                         # §6 — never touches assets/ in place
    """Render remediated candidates into build/qa/audio_fixed/<same relpath> for review."""
    for f in findings:
        if f["check"] in ("audio_lufs", "audio_vo_line"): render_gain_fix(f)      # §6.1
        elif f["check"] == "audio_loopseam":              render_seam_fix(f)      # §6.2
        elif f["check"] == "audio_silence_dc":            render_dc_trim_fix(f)   # §6.3
    write_fix_report(ROOT / "build/qa/audio_fix_report.md")    # before/after table + listen list

if __name__ == "__main__":
    sys.exit(main())   # all = scan → (nonzero on fail); fix = scan + fix; report = summary table
```
Support lib `tests/audio/checks/` holds one file per §2 check plus `dsp.py` (`true_peak_db`,
`seam_metrics`, `clip_runs`…) — every function above ~15 lines each, all pure
(measurement dict in, findings out) so they unit-test without audio files.

### 5.3 Exit + report contract
`scan` exit 0/1 mirrors `QA_DONE`. `report` prints the ASCII corpus table (§7 format) and writes
`build/qa/audio_report.html` — per-file row: class badge, LUFS bar vs target band, TP, seam
triple, verdict; per-speaker VO strip charts. The Sound Council reads this page; humans bless
fixes from it.

### 5.4 Runtime half (the buses can't be validated from files)
`RH_MIXCHECK=1` (engine hook, lands with `game_mixer.gd`): asserts bus tree exists and matches
§3.1 exactly (names, sends, no extras) · every playing node sits on its lawful bus (a
`get_tree()` walk — a new SFX player born on Master is a `fail`) · ducking laws D1–D4 timing
asserts (§3.2) · exactly one `AudioListener2D` · voice-budget cap (§3.3). Reports through
`QAReport` like every other functional check; joins the QA_AUTOMATION §2 matrix as one more
headless job.

---

## 6. THE REMEDIATION LOOP (auto-normalize into `_fixed/`, humans bless)

Registered as `tools/qa/backfill_audio.py` in the QA_AUTOMATION §4 registry. Hard rules
inherited: never commits, never edits `assets/` in place, must converge on re-validate or revert.
Output: `build/qa/audio_fixed/<relpath>` mirrors + `audio_fix_report.md` (before/after numbers,
what to listen for). Review flow: `audio_qa.py fix` → listen to the flagged wrap points/lines →
copy blessed files over `assets/` → Godot reimports → `audio_qa.py scan` green → commit.

### 6.1 Gain-only normalization (LUFS offenders, VO lines)
`gain = target_lufs − measured_lufs`, applied in float, **then** true-peak guard: if post-gain TP
would exceed the class ceiling, apply a lookahead limiter *only if* required gain ≤ +3 dB of
limiting, else flag `needs_remaster` (a bed that needs 6 dB of limiting to hit target is broken
upstream — the Council decides, not a script). VO lines are trimmed individually (the §2.6
payload's per-line table); speakers stay in character because gain is timbre-neutral.

### 6.2 Loop-seam repair
For `gapless` loops that fail §2.3: render an **equal-power crossfade wrap** — take the final
`X` ms (default 750, config), overlap-add it onto the head with equal-power curves, trim the tail;
the wrap point becomes mathematically continuous. Re-run `c_loopseam` on the candidate; it must
pass or the fixer reverts it and files `needs_remaster`. Beds whose head and tail are *texturally*
different (spec_cos < 0.2 — `theme_port` at 0.016) get `needs_remaster` immediately: no crossfade
fixes "the song ends somewhere else than it began"; that is authoring, owner/Council territory.

### 6.3 Mechanical hygiene
DC removal (subtract mean per channel) · edge-silence trim to budget (VO/one-shots) ·
`.wav`-in-assets → transcode to ogg q0.7 + finding for the manifest row. All trivially safe,
all still `_fixed/`-routed — nothing self-applies.

### 6.4 After the corpus normalizes: the one-time mix re-trim
Normalizing music from a 9.4 dB spread onto −16 changes perceived balance. One session:
corpus green → set `Music` node baseline and `ZoneAmbience` −14 against the new standard by ear
in town + one wilderness zone → those two numbers freeze → from then on **every new asset that
passes `scan` drops into the mix correctly by construction.** That is the entire point of a
loudness standard.

---

## 7. FIRST CORPUS RUN (measured 2026-07-05 — the founding baseline)

### 7.1 Music vs −16 ±1 (8 files) — **6 fail, 1 warn, 1 pass**
| File | LUFS | Δ | TP proxy (sample peak) | Seam (jump dB / click / cos) | Verdict |
|---|---|---|---|---|---|
| theme_north | −16.8 | −0.8 | 0.906 | −60.2 / 0.0 / 0.13 | **pass** LUFS · seam = authored fade-out → owner call: bless `restart` or crossfade |
| theme_west | −17.0 | −1.0 | 0.848 | −4.5 / 0.1 / 0.48 | warn (edge of band) |
| theme_south | **−13.0** | **+3.0** | **1.126 — CLIPS** | −50.1 / 0.0 / 0.32 | **fail ×2**: 3 dB hot AND decodes over full scale |
| theme_plain | −18.5 | −2.5 | 0.634 | −11.3 / **19.7** / 0.14 | fail: quiet + audible wrap click |
| theme_border | −19.8 | −3.8 | 0.430 | −6.6 / 1.1 / 0.44 | fail: quiet |
| theme_lost_village | −20.7 | −4.7 | 0.587 | −16.2 / 3.8 / 0.17 | fail: quiet + seam |
| theme_port | −20.7 | −4.7 | 0.713 | −5.8 / **23.0** / **0.016** | fail: quiet + worst seam in corpus → needs_remaster (§6.2) |
| theme_east | −22.4 | −6.4 | 0.524 | −6.3 / 9.6 / 0.84 | fail: 6 dB quiet + click |

### 7.2 Ambience/weather vs −22 ±1.5 (10 loops + thunder) — **4 fail, 3 warn, 4 pass**
| File | LUFS | Seam (jump/click/cos) | Verdict |
|---|---|---|---|
| amb_forge_rumble | −22.4 | **+11.1** / 0.7 / 0.71 | fail: seam (level jump — audible restart) |
| amb_dead_wind | −20.0 | **+20.3** / 0.5 / 0.52 | fail: hot-ish + the worst ambience seam (fades out, wraps loud) |
| amb_swamp | −27.5 | **−14.2** / 0.2 / 0.73 | fail: 5.5 dB quiet + seam |
| amb_cave | −27.8 | +1.9 / 3.4 / 0.81 | fail: 5.8 dB quiet (seam fine) |
| amb_harbor | −18.8 | −2.1 / 2.5 / 0.77 | warn→fail: 3.2 dB hot |
| amb_night_crickets | −20.1 | −2.4 / 0.0 / 0.76 | warn: 1.9 dB hot; 22.9 s bed = shortest legal |
| amb_forest_birds | −23.6 | −1.0 / 1.5 / 0.57 | pass (spec_cos warn) |
| amb_wind_howl | −23.1 | −0.6 / 0.8 / 0.83 | **pass** — the model citizen |
| weather/rain_loop | −22.1 | −0.8 / 0.6 / 0.77 | **pass** |
| weather/wind_loop | **−11.8** | +0.7 / 3.2 / 0.71 | **fail: 10.2 dB hot** — worst LUFS offense in the corpus (sample peak 0.970) |
| weather/thunder (sfx_oneshot) | −16.3 | n/a | warn: sample peak 0.938 ≈ −0.55 dBFS, over the −1 dBTP ceiling once oversampled |

### 7.3 VO vs −19, spread ≤ 4 dB (173 lines, 9 speakers) — **3 speakers pass, 6 exceed spread**
| Speaker | n | mean | spread | Verdict |
|---|---|---|---|---|
| petra | 26 | −18.8 | 2.3 | **pass** |
| narrator | 17 | −18.8 | 3.2 | **pass** |
| gatewarden | 12 | −18.0 | 3.8 | pass (mean +1.0 = at the corridor edge) |
| goran | 24 | −18.9 | 3.9 | pass |
| ansel | 19 | −19.2 | 6.0 | fail spread → per-line trim |
| default | 20 | −19.8 | 6.4 | fail spread |
| vasile | 16 | −19.3 | 6.5 | fail spread |
| mira | 9 | −19.0 | 7.3 | fail spread |
| marta | 25 | −19.0 | **8.0** | fail spread — worst; per-line table says trim ~6 outlier lines |

All speakers 24 kHz uniform; cross-cast mean corridor (−18.0…−19.8) = 1.8 dB — **passes** the
3 dB law. The TTS pipeline is fundamentally sound; only per-line variance needs the §6.1 trim.
(5 sub-0.4 s lines used the momentary fallback.)

**Corpus verdict: RED — 14 hard fails / 192 assets.** Exactly why this pipeline exists. Also
filed on sight: 3 repo-root strays (`wind.ogg`, `crow_caw.wav`, `dark_city.wav`) → delete or
adopt through the manifest.

---

## 8. RUN ORDER + ROLLOUT (each phase lands green, QA_AUTOMATION discipline)

**Phase A0 — Scanner (one session).** `tests/audio_manifest.json` + `audio_qa.py` with
`analyze/scan/report` + checks §2.1–2.5 · reproduce §7's numbers exactly (the measurements above
are the acceptance test) · wire `v_audio.py` into `qa.py validate`, **warn-only quarantine**.
Exit: `py tests/audio_qa.py scan` reports the 14 fails listed here, `qa.py` shows them yellow.

**Phase A1 — VO sweep + remediation pilot (one session).** `c_vo_consistency` (§2.6) ·
`fix` stage §6.1 (gain) + §6.3 (hygiene) · run it: 6 speakers' outlier lines + the LUFS-only
music/ambience offenders render into `_fixed/` · listen, bless, copy, rescan.
Exit: VO fully green; LUFS-only offenders green; `wind_loop` −11.8 → −22 verified in-game
(rain still audible over it at intensity 1.0).

**Phase A2 — Seam repair + the one-time mix re-trim (one session).** §6.2 crossfade fixer ·
owner decisions: `theme_north` restart-vs-gapless; `theme_port` remaster ticket · §6.4 re-trim
of the two node baselines · flip `v_audio` from quarantine to **enforcing** (red blocks commit).
Exit: `audio_qa.py all` green on HEAD; a deliberately de-tuned file turns `qa.py` red.

**Phase A3 — Buses + runtime asserts (lands with OPTIONS_SUITE integration).**
`game_mixer.gd` (ducking D1–D4, voice budget, spatial defaults §3.3) · `RH_MIXCHECK` hook ·
join the functional matrix. Exit: ducking laws regression-tested; every player on its lawful bus.

**Phase A4 — The law goes live (ongoing).** MANDATES § Audio "ROCKSTAR-GRADE audio QA" 🔄→✅.
Every future audio delivery — Voice v2 rebake (173+ lines re-enter through §2.6), the
Hans-Zimmer adaptive score stems (each stem = one manifest row, class `music`, and **stem seams
get c_loopseam by construction**), UI/combat SFX packs, per-kingdom motifs — ships with manifest
rows in the same commit and enters through `scan`. The 10k Sound Council judges what passes;
nothing that fails physics gets to waste the Council's time.

---

## 9. WHAT THIS BUYS
| Mandate | Enforced by |
|---|---|
| Rockstar-grade audio QA on every asset | §2 battery + `v_audio.py` in `qa.py validate`, enforcing after A2 |
| Zone soundscapes never audibly "restart" | `c_loopseam` on every looping bed + §6.2 crossfade fixer |
| Marius-timbre narrator & cast sound like one production | `c_vo_consistency` across all 173 lines, rebake-gated forever |
| Hans-Zimmer adaptive stems mix predictably | one loudness standard (§1) + bus tree (§3.1) — stems arrive pre-conformed |
| Ducking laws are law, not vibes | `game_mixer.gd` + `RH_MIXCHECK` timing asserts (§3.2) |
| BE CHEAP | pure-local DSP in the existing tts venv, seconds per full-corpus scan, zero new installs |
| Sound Council spends taste, not triage | physics gate first; the Council's ledger reviews only green assets |
