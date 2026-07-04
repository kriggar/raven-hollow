# RAVEN HOLLOW — AAA OPTIONS SUITE (Steam-polish settings spec)
Full settings system for the Steam build: Video / Audio / Gameplay / Accessibility / Input,
the `SettingsManager` autoload that owns them, and the gold-bezel Settings panel that edits them.

**Grounded in (read before writing):**
- `project.godot` — 640×360 viewport, `window/stretch/mode="canvas_items"` + `scale_mode="integer"`,
  1920×1080 window override, `rendering/viewport/hdr_2d=true`, GL Compatibility renderer,
  nearest-neighbor filtering (`default_texture_filter=0`); autoloads `VoiceRegistry`, `Voice`,
  `TravelSystem`; the full InputMap (`move_*`, `interact`, `attack`, `skill_1..7`, `inventory`,
  `character_sheet`, `spellbook`, `sheathe`, `map`, `sprint`, `ui_advance_dialogue`).
- `scripts/main.gd` — `GlowEnv` WorldEnvironment (BG_CANVAS, `glow_intensity 0.35`, `glow_strength 0.9`,
  `glow_bloom 0.05`, `glow_hdr_threshold 1.08`, additive); `Vignette` CanvasLayer 5 (edge alpha 0.35);
  `Music` AudioStreamPlayer (−14 dB baseline, `PROCESS_MODE_ALWAYS`, group `"music"`); `ZoneAmbience`
  (−14 dB); camera `position_smoothing_speed = 6.0`; autosave on `change_map()` (line ~541) and quest
  turn-in (line ~718); layer bands (vignette 5 · weather 6 · HUD/minimap 8 · bag/sheet/craft 9 ·
  dialogue/world-prompt 10 · fade 25 · menus 30).
- `scripts/weather.gd` — runtime-created `"Weather"` audio bus (`_ensure_audio_bus`), 700-particle
  `GPUParticles2D` precip, lightning `_strike()` flash to alpha 0.85, ambience volume −40→−8 dB by
  intensity, CanvasLayer 6.
- `scripts/pause_menu.gd` — layer 30, `user://settings.cfg` `[audio] music_volume`, music volume via
  node-meta base-dB offset, gold-bezel constants (`GOLD`, `PARCHMENT`, `PANEL_BG`, `ROW_BG`,
  `PANEL_BORDER`…), Esc-precedence gating, row/focus/slider kit.
- `scripts/player.gd` — hold-to-sprint (`Input.is_action_pressed("sprint")`, ~line 361); skill casts on
  `skill_1..7` (~379–395); `_shake_camera()` (3 jolts of ±2.5 px); `_flash_red()`; Z = `sheathe`.
- `scripts/hud.gd` — layer 8; **hardcoded** `KEYBINDS: ["LMB","Q","R","F","1","2","3","4"]` captions.
- `scripts/minimap.gd` — layer 8; owns the day/night clock text; `map` toggles world map.
- `scripts/day_night.gd` — `"world_lights"` group registry, `dn_base_energy` meta, energy-scale keyframes.
- `scripts/vfx.gd` — `VFX.damage_number(...)`, `VFX.shake(camera, strength)` statics.
- `scripts/combat.gd` — `own_damage_numbers` meta on nameplated targets; damage numbers spawn at ~-26 px.
- `scripts/save_system.gd` — pure-static `SaveSystem.save_game(slot := 1) -> bool`, `user://save1.json`.
- `scripts/voice_client.gd` — dialogue VO on a Master-bus `AudioStreamPlayer` + spatial `AudioStreamPlayer2D`s.
- `scripts/main_menu.gd` — rows `New Game / Continue / Quit` (Settings row to be added).
- `design/COMBAT_PACING.md` / `design/ITEM_PROGRESSION.md` — TTK 8–15 s at-level normals, downtime
  regen rhythm, rarity-color loot language. Options below must never let a setting break those
  contracts (no "damage numbers off = can't learn fights" traps, no autosave mid-pull).

---

## 0. Design tenets

1. **Every setting applies instantly** (apply-on-change), persists to `user://settings.cfg`, and has a
   sane default equal to today's shipped behavior. Zero settings touched = the game looks/sounds
   exactly like the current build.
2. **Nothing gameplay-affecting hides in Video.** Screen shake, flashing, damage numbers are
   accessibility/gameplay levers, mirrored where players expect them.
3. **Honesty about 2D.** We do not fake "Ultra ray tracing" dropdowns. Section 9 maps every
   NVIDIA-style AAA toggle to its real Raven Hollow equivalent or declares it N/A.
4. **The pixel grid is sacred.** Defaults keep integer scaling and nearest filtering; fractional
   scaling and UI-scale tricks are offered but labeled with their shimmer cost.
5. **Settings survive the pause-menu's existing file.** `user://settings.cfg` `[audio] music_volume`
   (already written by `pause_menu.gd`) is migrated, not clobbered.

---

## 1. Architecture — the `SettingsManager` autoload

### 1.1 File + registration

`res://scripts/settings_manager.gd`, autoloaded as **`Settings`** and listed **first** so the audio
buses exist before `WeatherController._ensure_audio_bus()` runs and before any UI reads a value:

```ini
[autoload]
Settings="*res://scripts/settings_manager.gd"     ; NEW — must be first
VoiceRegistry="*res://scripts/voice_registry.gd"
Voice="*res://scripts/voice_client.gd"
TravelSystem="*res://scripts/travel_system.gd"
```

(`weather.gd`'s `_ensure_audio_bus()` is idempotent — it checks `AudioServer.get_bus_index("Weather")
== -1` — so it needs **no edit**; Settings simply wins the race and weather finds the bus already made.)

### 1.2 Skeleton (exact shape)

```gdscript
extends Node
## SettingsManager — owns user://settings.cfg, the audio bus layout, and
## apply-on-change hooks for every option. Autoload "Settings", first in list.

signal setting_changed(section: String, key: String, value: Variant)

const CFG_PATH := "user://settings.cfg"
const SAVE_DEBOUNCE_S := 0.5

## section -> key -> default. THE single source of truth; the UI iterates this.
const DEFAULTS := {
    "video": {
        "window_mode": "borderless",     # windowed | borderless | exclusive
        "window_scale": 3,               # windowed size = 640x360 * N (project ships 1920x1080)
        "scaling": "integer",            # integer | fractional
        "vsync": "on",                   # off | on | adaptive
        "fps_cap": 0,                    # 0 = uncapped, else 30/60/120/144/240
        "hdr_glow": "medium",            # off | low | medium | high  (medium == shipped 0.35)
        "light_shadows": "off",          # off | hard | soft  (2D shadow-casting lights)
        "weather_density": 1.0,          # 0.0 | 0.5 | 1.0
        "screen_shake": 1.0,             # 0.0..1.0 (mirrored in Accessibility)
        "vignette": 1.0,                 # 0.0..1.0 alpha scale on the 0.35 edge
    },
    "audio": {
        "master_volume": 1.0, "music_volume": 1.0, "ambience_volume": 1.0,
        "weather_volume": 1.0, "voice_volume": 1.0, "sfx_volume": 1.0,
        "mute_unfocused": false,
    },
    "gameplay": {
        "autosave_minutes": 10,          # 0 = off | 5 | 10 | 15  (travel/turn-in saves always on)
        "damage_numbers": "all",         # all | player_only | off
        "minimap_visible": true,
        "minimap_enemy_dots": true,
        "tooltip_verbosity": "full",     # full | compact  (flavor text + set/ilvl lines vs stats only)
        "camera_smoothing": "standard",  # off | low | standard | high  (standard == shipped 6.0)
    },
    "accessibility": {
        "colorblind_filter": "off",      # off | protanopia | deuteranopia | tritanopia
        "ui_scale": 100,                 # 100 | 111 | 125  (content_scale_size trick, §6.2)
        "font_outline_boost": false,     # +1 px outline on registered kit labels
        "reduced_flashing": false,       # caps lightning/hit flashes
        "screen_shake_off": false,       # hard off, wins over video.screen_shake
        "sprint_toggle": false,          # hold (default, shipped) vs toggle
    },
    "input": {},                         # rebinds only; empty = project.godot defaults
}

var _cfg := ConfigFile.new()
var _values: Dictionary = {}      # deep copy of DEFAULTS overlaid with cfg
var _save_timer: SceneTreeTimer = null
var _autosave_accum: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS   # autosave timer & focus-mute run under pause
    _load()
    _ensure_audio_buses()
    _apply_input_overrides()
    apply_all()

func get_v(section: String, key: String) -> Variant:
    return _values.get(section, {}).get(key, DEFAULTS[section][key])

func set_v(section: String, key: String, value: Variant) -> void:
    if get_v(section, key) == value: return
    _values[section][key] = value
    _apply_one(section, key, value)
    setting_changed.emit(section, key, value)
    _queue_save()
```

- `_apply_one()` is a `match` over `(section, key)` dispatching to the hooks in §§2–6.
- `apply_all()` runs every hook once at boot **and** is re-invoked by `main.gd` after any world
  (re)build (see §10) because `GlowEnv`, `Vignette`, `Weather`, and world lights are runtime nodes
  that get freed on quit-to-menu (`main.gd:~821`).
- `_queue_save()` debounces `ConfigFile.save(CFG_PATH)` by 0.5 s (sliders won't hammer the disk).
- **Migration:** on first load, if `[audio] music_volume` exists (written by today's
  `pause_menu.gd:_save_settings`), it seeds `audio/music_volume` — the key name is identical, so
  migration is automatic; the pause menu is repointed at `Settings` (§8.4).

### 1.3 Apply-hook safety rules

- Every hook is **null-safe against a missing world**: it looks nodes up by group/name
  (`get_tree().get_first_node_in_group("weather")`, `get_node_or_null("/root/Main/GlowEnv")`) and
  silently no-ops at the main menu. `apply_all()` after world build catches up.
- Hooks that touch the window (`window_mode`, `window_scale`, `vsync`) go through
  `DisplayServer`/`Window` and are safe at any time, including from the title screen.
- Destructive display changes (window mode, scaling) trigger the **revert countdown** (§8.3).

---

## 2. VIDEO

Current shipped state (the "default" column): 640×360 canvas-items stretch, integer scale, window
override 1920×1080, vsync = Godot default (on), no FPS cap, glow on at 0.35, no 2D shadows,
700 weather particles, shake on, vignette alpha 0.35.

| # | Setting | Values (UI cycler) | Default | cfg key |
|---|---|---|---|---|
| V1 | Window Mode | Windowed · Borderless Fullscreen · Exclusive Fullscreen | Borderless | `video/window_mode` |
| V2 | Window Size (windowed only) | 1× 640×360 · 2× 1280×720 · 3× 1920×1080 · 4× 2560×1440 · 6× 3840×2160 | 3× | `video/window_scale` |
| V3 | Pixel Scaling | Integer (crisp, letterboxed) · Fractional (fills screen) | Integer | `video/scaling` |
| V4 | VSync | Off · On · Adaptive | On | `video/vsync` |
| V5 | FPS Cap | Uncapped · 30 · 60 · 120 · 144 · 240 | Uncapped | `video/fps_cap` |
| V6 | Glow (HDR-2D bloom) | Off · Low · Medium · High | Medium | `video/hdr_glow` |
| V7 | Dynamic Light Shadows | Off · Hard · Soft | Off | `video/light_shadows` |
| V8 | Weather Particle Density | Off · Half · Full | Full | `video/weather_density` |
| V9 | Screen Shake | slider 0–100 % | 100 % | `video/screen_shake` |
| V10 | Vignette | slider 0–100 % | 100 % | `video/vignette` |

### V1 — Window Mode (exact Godot 4.6 API)

```gdscript
func _apply_window_mode(mode: String) -> void:
    match mode:
        "windowed":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
            _apply_window_scale(int(get_v("video", "window_scale")))  # restore size + center
        "borderless":
            # Godot 4: WINDOW_MODE_FULLSCREEN *is* the borderless fullscreen window.
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        "exclusive":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
```

Notes: on Windows, `WINDOW_MODE_FULLSCREEN` is the alt-tab-friendly borderless mode (default and
recommended); `WINDOW_MODE_EXCLUSIVE_FULLSCREEN` grabs the display for marginal latency wins and is
what "NVIDIA-tier" players expect to find. Changing mode fires the revert countdown (§8.3).

### V2 — Window Size (windowed only; integer multiples of 640×360)

```gdscript
func _apply_window_scale(n: int) -> void:
    if String(get_v("video", "window_mode")) != "windowed": return
    var sz := Vector2i(640, 360) * n
    var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
    get_window().size = sz
    get_window().position = usable.position + (usable.size - sz) / 2   # re-center
```

Only integer multiples are offered — a 1.5× window with integer content scaling would letterbox
half the frame. Sizes larger than the current screen's usable rect are greyed out in the UI
(`DisplayServer.screen_get_usable_rect()` check when building the cycler).

### V3 — Pixel Scaling (our "DLSS" — see §9)

```gdscript
func _apply_scaling(mode: String) -> void:
    get_window().content_scale_stretch = (
        Window.CONTENT_SCALE_STRETCH_INTEGER if mode == "integer"
        else Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
```

- **Integer** (shipped): pixel-perfect, black bars on non-multiple displays (e.g. 1366×768 shows 2×
  with bars). This is the correct default for the art.
- **Fractional**: fills the screen exactly; pixels are unevenly sized (shimmer on scroll). Offered
  for players who hate letterboxing; the UI hint says *"may cause pixel shimmer"*.
- Stretch **mode** stays `canvas_items` (project setting, not runtime-flipped).

### V4 — VSync

```gdscript
func _apply_vsync(mode: String) -> void:
    match mode:
        "off":      DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        "on":       DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
        "adaptive": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE)
```

Honesty notes: `VSYNC_MAILBOX` (fast-vsync) is **not offered** — it requires the Vulkan-based
renderers; we ship GL Compatibility where it silently degrades. `VSYNC_ADAPTIVE` on GL needs
`EXT_swap_control_tear`; where unsupported Godot falls back to plain vsync — acceptable, no lie in
the UI (tooltip: *"falls back to On if the driver lacks adaptive support"*).

### V5 — FPS Cap

```gdscript
func _apply_fps_cap(cap: int) -> void:
    Engine.max_fps = cap    # 0 = uncapped
```

One line, but Steam players expect it (laptops, Deck battery). Physics stays at the default
60 Hz tick — the cap only bounds rendering. UI warns below 60: *"30 FPS cap: animation and input
feel degrade; intended for battery saving."*

### V6 — Glow (HDR-2D pipeline)

The project already renders 2D in HDR (`rendering/viewport/hdr_2d=true` in `project.godot`) and
`main.gd:_spawn_systems()` builds the `GlowEnv` WorldEnvironment. The setting scales that
environment; Off also drops the HDR 2D buffer back to 8-bit for a small GL-Compat perf win:

```gdscript
const GLOW_LEVELS := {"off": 0.0, "low": 0.18, "medium": 0.35, "high": 0.6}  # medium == shipped

func _apply_hdr_glow(level: String) -> void:
    var we := get_tree().root.find_child("GlowEnv", true, false) as WorldEnvironment
    if we == null or we.environment == null: return
    var on := level != "off"
    we.environment.glow_enabled = on
    we.environment.glow_intensity = GLOW_LEVELS[level]
    # glow_strength 0.9 / glow_bloom 0.05 / glow_hdr_threshold 1.08 stay authored (main.gd).
    get_viewport().use_hdr_2d = on    # RGBA16F canvas only while glow needs >1.0 values
```

*"High" QA note:* 0.6 intensity makes forge fires and spell VFX halo hard — screenshot the town
forge and the necromancer `bone_nova` before shipping the value; the pixel art must stay readable.

### V7 — Dynamic Light Shadows (our 2D "ray tracing" — see §9)

Every world light already registers in group `"world_lights"` (day_night.gd contract §3:
lanterns, fires, forge glow, gate lights from `gate_builder.gd:_light()`). None currently cast
shadows. The setting flips real 2D shadow mapping on them:

```gdscript
func _apply_light_shadows(mode: String) -> void:
    for l: Node in get_tree().get_nodes_in_group("world_lights"):
        var light := l as Light2D
        if light == null: continue
        light.shadow_enabled = mode != "off"
        light.shadow_filter = (Light2D.SHADOW_FILTER_NONE if mode == "hard"
                else Light2D.SHADOW_FILTER_PCF13)         # "soft"
        light.shadow_filter_smooth = 2.5 if mode == "soft" else 0.0
        light.shadow_color = Color(0.05, 0.04, 0.08, 0.55) # night-blue, never pure black
```

**Prerequisite (content work, not settings work):** shadows need occluders. The builders
(`town_builder.gd`, `wilderness_builder.gd`, `gate_builder.gd`) must add `LightOccluder2D`
footprint polygons to buildings/tree trunks/fence lines and, per the day_night contract, animated
flicker lights keep `dn_ignore` semantics untouched (shadow flag is orthogonal to energy). Until
occluders exist the toggle is functional but visually inert — ship the occluder pass in the same
milestone. Project setting `rendering/2d/shadow_atlas/size = 2048` (default) is fine for our light
counts; raise only if QA sees shadow aliasing on 4× displays.
**Perf note:** GL Compatibility redraws occluders per shadow-casting light. Town has ~12 lanterns;
cap visible shadow lights via the existing culling habits (lights outside camera keep
`shadow_enabled` but Godot culls them). Default **Off** — this is the one setting where we spend
frame budget for mood, opted into.

### V8 — Weather Particle Density

`weather.gd` owns a single 700-particle `GPUParticles2D` (`_precip.amount = 700`). Add one method
to `WeatherController` (3-line patch, same public-API style as `set_weather`):

```gdscript
## weather.gd — PUBLIC API addition
const BASE_PARTICLES := 700
func set_particle_density(f: float) -> void:   # 0.0 | 0.5 | 1.0
    if _precip == null: return
    _precip.amount = maxi(1, int(BASE_PARTICLES * f))   # NOTE: setting amount restarts emission
    _precip.preprocess = _precip.lifetime               # refill instantly (same trick as _configure_precip)
    _precip.emitting = f > 0.0 and _intensity > 0.02 and _precip_family(_type) != Type.CLEAR
```

Hook: `Settings._apply_weather_density()` calls it via group `"weather"`. "Off" keeps darkening,
fog, and audio (the *mood* survives; only the particle spend goes). Density also composes with the
existing `amount_ratio` intensity ride in `_apply()` — untouched.

### V9 — Screen Shake  ·  V10 — Vignette

- **Shake:** `player.gd:_shake_camera()` and `VFX.shake()` multiply their jolt magnitude by
  `Settings.shake_scale()` — a helper returning `0.0` when `accessibility/screen_shake_off`
  else `video/screen_shake`. Two call-site patches:
  `var s: float = Settings.shake_scale(); if s <= 0.0: return` then scale the `randf_range` bounds.
- **Vignette:** `main.gd:_make_vignette()` builds layer `"Vignette"` with edge alpha 0.35. Hook:

```gdscript
func _apply_vignette(f: float) -> void:
    var v := get_tree().root.find_child("Vignette", true, false) as CanvasLayer
    if v == null: return
    v.visible = f > 0.0
    v.get_node("VignetteRect").modulate = Color(1, 1, 1, f)   # scales the 0.35 edge alpha
```

---

## 3. AUDIO

### 3.1 Current bus reality (audited)

| Sound | Node | Bus today | Baseline |
|---|---|---|---|
| Music theme | `main.gd` `Music` (group `"music"`) | **Master** | −14 dB |
| Zone ambience beds | `main.gd` `ZoneAmbience` | **Master** | −14 dB |
| Weather rain/wind + thunder | `weather.gd` `_ambience`/`_thunder` | **`Weather`** (runtime-created, → Master) | −40…−8 dB by intensity |
| Dialogue VO | `voice_client.gd` `_dvo` + spatial 2D players | **Master** | 0 dB |
| Combat/UI SFX | (future — `vfx.gd` is currently silent visuals) | — | — |
| Menu music | `main_menu.gd` `MenuMusic` | **Master** | authored |

Only `Master` + the runtime `Weather` bus exist. The pause menu fakes a music channel by offsetting
`Music.volume_db` through node metadata (`rh_music_base_db`).

### 3.2 Target bus layout (created in code, no `.tres` asset)

```
Master
 ├─ Music      ← main.gd Music player + main_menu.gd MenuMusic
 ├─ Ambience   ← main.gd ZoneAmbience
 ├─ Weather    ← weather.gd ambience + thunder  (bus already created by weather.gd — kept)
 ├─ Voice      ← voice_client.gd _dvo + spatial players
 └─ SFX        ← all future combat/UI one-shots (loot window, ability whooshes)
```

```gdscript
func _ensure_audio_buses() -> void:
    for bus_name: String in ["Music", "Ambience", "Weather", "Voice", "SFX"]:
        if AudioServer.get_bus_index(bus_name) == -1:
            var idx: int = AudioServer.bus_count
            AudioServer.add_bus(idx)
            AudioServer.set_bus_name(idx, bus_name)
            AudioServer.set_bus_send(idx, "Master")   # same 3 calls weather.gd already uses
```

Routing patches (one line each, integration checklist §10): `music.bus = "Music"` in
`main.gd:_ensure_music()` and `main_menu.gd`; `_zone_ambience.bus = "Ambience"`;
`_dvo.bus = "Voice"` (+ the spatial players in `voice_client.gd`); new SFX players are born with
`bus = "SFX"`. `weather.gd` needs **zero changes**.

### 3.3 Volume model

Six sliders, 0–100 %, all identical hook:

```gdscript
func _apply_bus_volume(bus_name: String, v: float) -> void:
    var idx: int = AudioServer.get_bus_index(bus_name)   # "Master" included
    if idx == -1: return
    AudioServer.set_bus_mute(idx, v <= 0.005)
    AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.005)))
```

- Bus at 0 dB == today's mix: the authored per-node baselines (−14 dB music, weather's intensity
  ride) are **kept on the nodes**, so "everything at 100 %" sounds exactly like the current build.
- The pause-menu music slider (§8.4) now writes `Settings.set_v("audio","music_volume",v)` —
  the meta-offset trick (`rh_music_base_db`) and the 300-frame boot-poll in `pause_menu.gd` are
  retired.
- **Mute on focus loss** (`audio/mute_unfocused`, default off): `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT/IN)`
  in SettingsManager toggles `AudioServer.set_bus_mute(0, …)`. Standard Steam courtesy toggle.

| Slider | Bus | Default | cfg key |
|---|---|---|---|
| Master | Master | 100 % | `audio/master_volume` |
| Music | Music | 100 % (migrated from pause menu's value) | `audio/music_volume` |
| Ambience | Ambience | 100 % | `audio/ambience_volume` |
| Weather | Weather | 100 % | `audio/weather_volume` |
| Voice | Voice | 100 % | `audio/voice_volume` |
| Effects | SFX | 100 % | `audio/sfx_volume` |

---

## 4. GAMEPLAY

| # | Setting | Values | Default | cfg key |
|---|---|---|---|---|
| G1 | Autosave Interval | Off · 5 min · 10 min · 15 min | 10 min | `gameplay/autosave_minutes` |
| G2 | Damage Numbers | All · Player Only · Off | All | `gameplay/damage_numbers` |
| G3 | Minimap | On · Off | On | `gameplay/minimap_visible` |
| G4 | Minimap Enemy Dots | On · Off | On | `gameplay/minimap_enemy_dots` |
| G5 | Tooltip Detail | Full · Compact | Full | `gameplay/tooltip_verbosity` |
| G6 | Camera Smoothing | Off · Low · Standard · High | Standard | `gameplay/camera_smoothing` |

### G1 — Autosave cadence

Existing autosaves — `change_map()` travel and quest turn-in (`main.gd:541,718`) — are **not**
optional; they're the demo's safety net. The setting adds a periodic tick on top, owned by
SettingsManager's `_process` (it's `PROCESS_MODE_ALWAYS`, so gate on pause):

```gdscript
func _process(delta: float) -> void:
    var mins: int = int(get_v("gameplay", "autosave_minutes"))
    if mins <= 0 or get_tree().paused: return
    _autosave_accum += delta
    if _autosave_accum < mins * 60.0: return
    var p: Node = get_tree().get_first_node_in_group("player")
    if p == null or p.get("hp") == null or float(p.hp) <= 0.0: return
    if _player_in_combat(p): return          # never mid-pull — COMBAT_PACING's death
    _autosave_accum = 0.0                    # pressure must stay honest
    if SaveSystem.save_game():
        get_tree().call_group("hud", "show_save_pip")   # tiny gold "Saved" fade, HUD hook
```

`_player_in_combat()`: any node in group `"enemies"` within 220 px of the player, or the player's
`target` is a live enemy — combat check is a heuristic and deliberately conservative (deferred
save beats a mid-dodge hitch). On skip, retry every 10 s until clear.

### G2 — Damage numbers

Single choke point — `VFX.damage_number()` (`vfx.gd:482`), which both `combat.gd` paths already
funnel through (including nameplated targets with the `own_damage_numbers` meta):

```gdscript
# vfx.gd damage_number(), first line:
static func damage_number(parent: Node, pos: Vector2, amount: int, color: Color, is_player_source := true) -> void:
    var mode := String(Settings.get_v("gameplay", "damage_numbers"))
    if mode == "off": return
    if mode == "player_only" and not is_player_source: return
```

Call sites tag `is_player_source` (player hits + crits true; enemy-on-player numbers false).
Pacing-contract note: the UI tooltip for "Off" reads *"Fight feedback comes from hit flashes and
health bars only"* — flashes/nameplates stay, so fights still teach (COMBAT_PACING §audit).

### G3/G4 — Minimap options

`minimap.gd` is a CanvasLayer in group `"minimap"`: G3 sets its `visible` (the M world map still
opens — the overlay is information, not chrome). G4 gates the red enemy-dot pass in its redraw
(one `if` in the dot loop). The day/night clock is drawn by the minimap; when hidden, the clock
hides too — accepted (WoW-Classic has no clock either), noted in the tooltip.

### G5 — Tooltip verbosity

`item_tooltip.gd` renders name/stats/flavor. **Full** = today. **Compact** drops the italic flavor
paragraph and the ITEM_PROGRESSION extension lines (`ilvl`, `set_id` set-list) — stats, rarity
color, and `req_level` always render (they're decision data, never trimmed).

### G6 — Camera smoothing

`main.gd:_make_camera()` ships `position_smoothing_enabled = true, speed = 6.0`:

```gdscript
const SMOOTH := {"off": -1.0, "low": 4.0, "standard": 6.0, "high": 10.0}
func _apply_camera_smoothing(mode: String) -> void:
    var cam := get_tree().root.find_child("PlayerCamera", true, false) as Camera2D
    if cam == null: return
    var v: float = SMOOTH[mode]
    cam.position_smoothing_enabled = v > 0.0
    if v > 0.0: cam.position_smoothing_speed = v
```

"Off" is the motion-sensitivity / pixel-purist choice (camera locks to the player, whole-pixel
steps). Re-applied on world rebuild (camera is recreated per map) via `apply_all()` (§10).

---

## 5. ACCESSIBILITY

| # | Setting | Values | Default | cfg key |
|---|---|---|---|---|
| A1 | Colorblind Filter | Off · Protanopia · Deuteranopia · Tritanopia | Off | `accessibility/colorblind_filter` |
| A2 | UI Scale | 100 % · 111 % · 125 % | 100 % | `accessibility/ui_scale` |
| A3 | Text Outline Boost | Off · On | Off | `accessibility/font_outline_boost` |
| A4 | Reduced Flashing | Off · On | Off | `accessibility/reduced_flashing` |
| A5 | Screen Shake Off | Off · On | Off | `accessibility/screen_shake_off` |
| A6 | Sprint Mode | Hold · Toggle | Hold | `accessibility/sprint_toggle` |

### A1 — Colorblind filter (full-screen canvas shader)

A `CanvasLayer` at **layer 100** (above PauseMenu 30 — the filter must recolor menus and the
rarity-colored loot text too, per ITEM_PROGRESSION's color-language contract) holding one
full-rect `ColorRect` with a screen-reading shader. Built by SettingsManager at `_ready`,
`mouse_filter = IGNORE`, hidden when Off (zero cost):

```glsl
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int mode = 0;  // 1 protanopia, 2 deuteranopia, 3 tritanopia

void fragment() {
    vec3 c = texture(screen_tex, SCREEN_UV).rgb;
    mat3 m = mat3(vec3(1.0), vec3(1.0), vec3(1.0));
    if (mode == 1)      m = mat3(vec3(0.567, 0.433, 0.0), vec3(0.558, 0.442, 0.0), vec3(0.0, 0.242, 0.758));
    else if (mode == 2) m = mat3(vec3(0.625, 0.375, 0.0), vec3(0.700, 0.300, 0.0), vec3(0.0, 0.300, 0.700));
    else if (mode == 3) m = mat3(vec3(0.950, 0.050, 0.0), vec3(0.0, 0.433, 0.567), vec3(0.0, 0.475, 0.525));
    // daltonize: simulate, take the error, push it into visible channels
    vec3 sim = vec3(dot(c, m[0]), dot(c, m[1]), dot(c, m[2]));
    vec3 err = c - sim;
    vec3 shift = vec3(0.0, err.r * 0.7 + err.g, err.r * 0.7 + err.b);
    COLOR = vec4(clamp(c + shift, 0.0, 1.0), 1.0);
}
```

`hint_screen_texture` works on GL Compatibility; `filter_nearest` keeps the pixel grid intact.
QA gate: the six rarity colors (poor grey → legendary orange, ITEM_PROGRESSION §1) must remain
six *distinguishable* values under each mode — screenshot the loot window under all four filters.

### A2 — UI Scale (honest lever: `content_scale_size`)

Every UI is code-built in absolute 640×360 coordinates — a naive `CanvasLayer.scale` would shove
right-anchored elements (minimap, tracker) off-screen. The honest lever is shrinking the design
viewport, which makes *everything* (UI **and** world) proportionally larger:

```gdscript
const UI_SCALE_SIZES := {100: Vector2i(640, 360), 111: Vector2i(576, 324), 125: Vector2i(512, 288)}
func _apply_ui_scale(pct: int) -> void:
    get_window().content_scale_size = UI_SCALE_SIZES[pct]
    if pct != 100:  # 576/324 & 512/288 are not integer divisors of 1080p — avoid giant letterbox
        get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
    else:
        _apply_scaling(String(get_v("video", "scaling")))   # restore the player's choice
```

Documented trade-offs, shown in the UI hint: larger UI = **less world visible** (shorter sight
lines vs the 120 px aggro radius — still 2× safe at 512×288) and non-100 % forces fractional
scaling (mild shimmer). All shipped panels fit 512×288? **No** — audit: pause panel 216×186 ✓,
bag/sheet/crafting ✓ (≤ ~440×280), Settings panel (§8.1, 480×320) ✗ at 125 %. Therefore the
Settings panel itself is authored at 460×300 max and anchored center — see §8.1. 125 % ships only
after that audit passes QA screenshots (`RH_UI` harness).

### A3 — Text outline boost

Kit labels use `outline_size` 2–3 with `OUTLINE_DARK`. Rather than walking every Control, the
ornate-kit styling helpers (`_style_label` in pause_menu/hud/etc.) add the label to group
`"rh_text"`; the hook bumps outlines:

```gdscript
func _apply_outline_boost(on: bool) -> void:
    for n: Node in get_tree().get_nodes_in_group("rh_text"):
        var l := n as Label
        if l == null: continue
        if not l.has_meta("rh_base_outline"):
            l.set_meta("rh_base_outline", l.get_theme_constant("outline_size"))
        l.add_theme_constant_override("outline_size", int(l.get_meta("rh_base_outline")) + (1 if on else 0))
```

Integration cost: one `add_to_group("rh_text")` line inside each `_style_label` helper (5 files).
New labels inherit it for free. (Same meta-baseline pattern as `day_night.gd`'s `dn_base_energy`.)

### A4 — Reduced flashing

Caps the two full-screen flashes and the hit flash:
- `weather.gd:_strike()` — lightning peak alpha 0.85 → **0.25**, second pulse dropped. Patch:
  read `Settings.flash_scale()` (1.0 or ~0.3) and multiply the tween targets.
- `player.gd:_flash_red()` — modulate `(1.0, 0.4, 0.4)` → gentler `(1.0, 0.7, 0.7)`.
- Any future screen-flash VFX must route through `Settings.flash_scale()` (add to the VFX
  authoring checklist).
Thunder audio and the darkening keep firing — information survives, photic risk doesn't.

### A5 — Screen Shake Off

Hard override consumed by `Settings.shake_scale()` (§2 V9). Duplicated here deliberately —
players look for it on this tab; both rows edit the same effective value and mirror live.

### A6 — Sprint: Hold vs Toggle

`player.gd:361` reads `Input.is_action_pressed("sprint")` each physics tick. Patch:

```gdscript
# player.gd — replace the is_action_pressed("sprint") term with:
var sprint_held: bool = Input.is_action_pressed("sprint")
if Settings.get_v("accessibility", "sprint_toggle"):
    if Input.is_action_just_pressed("sprint"): _sprint_latch = not _sprint_latch
    if not moving: _sprint_latch = false        # stopping drops the latch (WoW autorun feel)
    sprint_held = _sprint_latch
```

One new private var `_sprint_latch := false`. No InputMap change.

---

## 6. INPUT

### 6.1 Rebinding — scope

Rebindable actions (all shipped in `project.godot`, consumed via polled `Input` in
`player.gd:357–411` and `_unhandled_input` in the UIs):

```
move_up  move_down  move_left  move_right          (WASD + arrows)
attack   skill_1..skill_7                           (LMB/J · Q R F 1 2 3 4)
interact (E)   sprint (Shift)   sheathe (Z)
inventory (I)  character_sheet (C)  spellbook (P)  map (M)
```

**Not rebindable:** `ui_cancel` (Esc — the pause/close spine; rebinding it can soft-lock every
panel's Esc-precedence chain documented in `pause_menu.gd` §3), `ui_accept`, `ui_up/down/left/right`,
and `ui_advance_dialogue` (Enter/Space, low-stakes). Standard AAA practice: menu keys are fixed.

### 6.2 Serialization (`[input]` section of settings.cfg)

Store **only actions that differ from defaults** (defaults captured from
`InputMap.action_get_events()` at first boot, before overrides). Each event serialized flat:

```ini
[input]
skill_1=[{"type":"key","physical":69}]                 ; E on skill_1...
interact=[{"type":"key","physical":81}]                ; ...swapped with Q
attack=[{"type":"mouse","button":1},{"type":"key","physical":74}]
sprint=[{"type":"joy_button","button":8}]              ; L3
```

```gdscript
func _apply_input_overrides() -> void:
    for action: String in _cfg.get_section_keys("input") if _cfg.has_section("input") else []:
        if not InputMap.has_action(action): continue
        InputMap.action_erase_events(action)
        for e: Dictionary in _cfg.get_value("input", action, []):
            InputMap.action_add_event(action, _event_from_dict(e))
```

`_event_from_dict` builds `InputEventKey` (set `physical_keycode` — layout-independent, matching
how `project.godot` authors every binding), `InputEventMouseButton` (`button_index`),
`InputEventJoypadButton`, or `InputEventJoypadMotion` (`axis` + `axis_value` sign, deadzone 0.5).

**Display names** are layout-aware:
`OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))`
so a French AZERTY player sees "Z" where the physical key W sits. Mouse/pad events use a small
glyph map (`"LMB"`, `"RMB"`, `"A"`, `"RT"`, …).

### 6.3 Rebind flow (in the Settings panel, §8)

1. Focus an action row, press Enter/click → row control shows **"press a key…"** (gold pulse),
   input capture goes modal (`_input()` with `set_input_as_handled()`).
2. Next key/mouse/pad event binds as the action's **primary** event; Esc cancels; Backspace clears
   to unbound (blocked — shown as "—" — only for actions with a secondary still bound; movement
   actions can never end up fully unbound).
3. **Conflict policy: swap.** Binding a key already used by another rebindable action swaps them
   (WoW behavior) and toasts *"E ↔ Q swapped with Interact"*. Conflicts with fixed `ui_*` keys are
   refused with a toast.
4. **Reset Tab** (see §8.2 footer) restores `project.godot` defaults for the visible tab —
   input reset also deletes the whole `[input]` cfg section.

### 6.4 HUD keybind captions — required integration

`hud.gd:63` hardcodes `KEYBINDS: ["LMB","Q","R","F","1","2","3","4"]` under the ability bar. This
**must** become a live lookup or rebinding ships as a lie:

```gdscript
# hud.gd — replace the const with:
func _keybind_caption(slot: int) -> String:    # slot 0 = attack, 1..7 = skill_N
    var action := "attack" if slot == 0 else "skill_%d" % slot
    var evs := InputMap.action_get_events(action)
    return Settings.event_short_name(evs[0]) if not evs.is_empty() else "—"
```

Refresh on `Settings.setting_changed` (section `"input"`). `Settings.event_short_name()` is the
shared glyph helper from §6.2 (also used by the rebind rows and dialogue's "[E] Talk" prompt —
`dialogue_ui.gd` and `main.gd`'s world prompts interpolate the same helper instead of literal "E").

### 6.5 Controller support plan (phased)

**Phase 1 — playable (ship with the options suite):**
- Default pad bindings added to `project.godot` actions (players can re-map in-game afterwards):

| Action | Pad default | | Action | Pad default |
|---|---|---|---|---|
| move_* | Left stick (`JoypadMotion` axes 0/1) | | skill_1 | X |
| attack | RT (`axis 5 > 0.5`) | | skill_2 | Y |
| interact | A | | skill_3 | B |
| sprint | L3 | | skill_4 | RB |
| inventory | D-pad Up | | skill_5 | LB |
| map | Back/Select | | skill_6 | LT (`axis 4`) |
| ui_cancel (pause) | Start | | skill_7 | D-pad Right |
| character_sheet | D-pad Down | | sheathe | D-pad Left |

- `attack` on pad **auto-targets** the nearest enemy in facing (the `_acquire_target()` path
  already exists in `player.gd:380`); no cursor needed for combat.
- Menu navigation already works: every panel (pause, bag, sheet, settings) is keyboard-first via
  `ui_up/down/left/right/accept/cancel`, and Godot ships pad defaults on those built-ins.
- Deadzone: expose `input/pad_deadzone` (0.05–0.5, default 0.2 — matches the authored actions).

**Phase 2 — polish (post-suite):** pad glyph textures (Kenney input prompts, CC0 — fits the
asset pipeline), `Input.joy_connection_changed` toast + auto-glyph-swap keyboard↔pad, cursor
emulation for bag drag-and-drop (left stick moves a virtual cursor while a grid panel is open;
`Input.warp_mouse()`), and rumble on `player.take_damage` (`Input.start_joy_vibration`, gated by
a `input/rumble` toggle and `accessibility/screen_shake_off`).

---

## 7. settings.cfg — full reference example

```ini
[video]
window_mode="borderless"
window_scale=3
scaling="integer"
vsync="on"
fps_cap=0
hdr_glow="medium"
light_shadows="off"
weather_density=1.0
screen_shake=1.0
vignette=1.0

[audio]
master_volume=1.0
music_volume=0.8      ; migrated automatically from the old pause-menu key
ambience_volume=1.0
weather_volume=1.0
voice_volume=1.0
sfx_volume=1.0
mute_unfocused=false

[gameplay]
autosave_minutes=10
damage_numbers="all"
minimap_visible=true
minimap_enemy_dots=true
tooltip_verbosity="full"
camera_smoothing="standard"

[accessibility]
colorblind_filter="off"
ui_scale=100
font_outline_boost=false
reduced_flashing=false
screen_shake_off=false
sprint_toggle=false

[input]
; only deltas from project.godot defaults, see §6.2
```

---

## 8. SETTINGS UI — gold-bezel tabbed panel (640×360-safe)

### 8.1 Placement & geometry

New scene-free code-built node `SettingsPanel` (`res://scripts/settings_panel.gd`,
`CanvasLayer`, **layer 31** — one above PauseMenu/MainMenu at 30 so it stacks over either host).
Opened from **both** the pause menu (new "Settings" row) and the main menu (new "Settings" row
between Continue and Quit in `main_menu.gd:247–250`). Reuses the exact pause-menu kit constants
(`GOLD`, `GOLD_BRIGHT`, `PARCHMENT`, `PANEL_BG`, `ROW_BG`, `ROW_BG_FOCUS`, `PANEL_BORDER`,
`OUTLINE_DARK`, Alagard font, `StyleBoxFlat` 2 px border + 6 px shadow) — promote them to a tiny
`scripts/ui_kit.gd` (`class_name UIKit`) so pause menu, main menu, and this panel share one palette.

```
Design space 640×360, panel 460×300 @ (90, 30)  — fits the 512×288 UI-scale floor (§A2)
┌──────────────────────────────────────────────────────────────┐
│  ⚙  SETTINGS                                    [Alagard 18] │  y 8..30 title band
│ ┌────────┬────────┬────────┬──────────────┬───────┐          │
│ │ VIDEO  │ AUDIO  │ GAME   │ ACCESSIBILITY│ INPUT │          │  tab strip 5×~88×18,
│ ├────────┴────────┴────────┴──────────────┴───────┤          │  focused tab gold border
│ │  Window Mode              ‹ Borderless ›        │          │  rows 420×20, step 24
│ │  Window Size              ‹ 3× (1920×1080) ›    │          │  ≤ 9 rows per page;
│ │  Pixel Scaling            ‹ Integer ›           │          │  Input tab pages (18
│ │  VSync                    ‹ On ›                │          │  actions → 2 pages,
│ │  FPS Cap                  ‹ Uncapped ›          │          │  page dots at bottom)
│ │  Glow                     ‹ Medium ›            │          │
│ │  Light Shadows            ‹ Off ›               │          │
│ │  Weather Density          ‹ Full ›              │          │
│ │  Screen Shake             [▮▮▮▮▮▮▮▮▮▮] 100%     │          │  kit HSlider (grabber
│ ├──────────────────────────────────────────────────┤        │  icon from pause menu)
│ │ hint line: per-row description, parchment 9 pt  │          │
│ │ Esc back · ←→ change · R reset tab              │          │  footer y 300-22
│ └──────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

Row controls (all kit-styled, `FOCUS_NONE`, driven by the panel's own focus index like
`pause_menu.gd:_rows`): **cycler** `‹ value ›` (enum settings), **slider** (volumes, shake,
vignette — reuse `_add_slider_row` + `_make_grabber_icon` verbatim), **toggle** (`On/Off` cycler),
**bind button** (Input tab: action name left, primary + secondary glyphs right).

### 8.2 Navigation & behavior

- **Keyboard/pad:** ↑↓ rows (wraps), ←→ adjusts cycler/slider (sliders step 5 %), Enter activates
  (rebind capture / toggle), **Tab / Q·E (or LB·RB)** switch tabs, Esc closes (one level: capture →
  panel → host menu), **R** resets the visible tab to `DEFAULTS` after a confirm toast.
- **Mouse:** hover focuses (same `_on_row_hover` pattern), click cycles forward, right-click cycles
  back, sliders drag, tabs click.
- Every row change calls `Settings.set_v(...)` — **apply-on-change**, no Apply button, matching
  the SettingsManager contract (§1.2). The hint line under the rows shows the focused setting's
  one-line description (the honesty notes from §§2–6).
- Opened from pause: the tree is already paused (`pause_menu.open()`); panel is
  `PROCESS_MODE_ALWAYS` like its host. Opened from main menu: nothing to pause. The pause menu's
  Esc-precedence contract is untouched — SettingsPanel consumes its own Esc with
  `set_input_as_handled()` exactly like PauseMenu does while open.

### 8.3 Revert countdown (Steam polish, display-destructive changes only)

Changing **Window Mode**, **Pixel Scaling**, or **UI Scale** pops a kit-styled confirm strip in
the footer: *"Keep these display settings? Reverting in 10…"* — Enter keeps, Esc or timeout
reverts by re-applying the previous value through the same hooks. Implemented in the panel (not
the manager): it remembers `_pending_revert := {section, key, old_value, deadline}` and ticks in
`_process`. Standard PC-port armor against "picked exclusive fullscreen on the broken monitor."

### 8.4 Pause-menu diff

`pause_menu.gd` rows become **Resume / Settings / Save / Quit to Menu**. The inline Music slider
moves into Settings→Audio (its cfg key and value carry over, §1.2 migration); the pause menu keeps
its compact 216×186 panel and loses ~60 lines of music-meta plumbing (`apply_music_volume`,
`_find_music_player`, `MUSIC_BASE_META`, the 300-frame boot poll) — all superseded by the Music
bus. `main.gd`'s `call_group("pause_menu", "apply_music_volume")` map-change hook is deleted:
bus volume is node-independent, the whole reason for the bus refactor.

---

## 9. "NVIDIA-style" features — honest mapping for a 2D pixel Godot game

The Steam checklist a AAA options screen implies, and what each really means here. Marketing
names never appear in our UI; the honest row name is listed.

| AAA feature | Applies? | Raven Hollow equivalent (and where it lives) |
|---|---|---|
| **Ray tracing** | Conceptually yes | **Dynamic Light Shadows (V7)**: real occlusion — `Light2D.shadow_enabled` + `LightOccluder2D` polygons, hard vs PCF13-soft penumbra. This *is* 2D light transport: per-pixel occlusion tests against scene geometry, just rasterized. Optional garnish on top: Godot's 2D **SDF** (`texture_sdf()` in canvas shaders, built from the same occluders) enables cheap contact-glow/fake-GI effects for torch halos — a candidate for the "High" glow tier, not a separate toggle. |
| **DLSS / FSR upscaling** | N/A as-is | The game *is* an upscaler: it renders at 640×360 and integer-scales to the display — mathematically lossless, zero ms, no ghosting. **Pixel Scaling (V3)** integer vs fractional is our entire reconstruction menu. Godot's FSR2 lives in the 3D pipeline (`scaling_3d`) and does not apply to 2D; ML upscaling of pixel art is aesthetic vandalism anyway. |
| **Frame generation** | N/A | Interpolated frames would smear the deliberate low-FPS sprite animations (8-frame walk cycles). Closest honest lever: **FPS Cap Uncapped + VSync Off** — the camera scroll is where high Hz shows, and it's real frames. |
| **HDR display output** | Not yet honest | `rendering/viewport/hdr_2d=true` (shipped) is an **internal** HDR pipeline: an RGBA16F canvas so emissive values >1.0 feed `GlowEnv`'s threshold-1.08 bloom (**Glow, V6**). The final swapchain is still SDR — Godot 4.6 on Windows/GL Compatibility does not expose HDR10/scRGB output for this renderer, so we make no "HDR On" claim in the UI. If a future Godot ships display HDR for our stack, V6 grows an "HDR Output" row; the pipeline is already 16-bit-ready. |
| **VRR / G-Sync / FreeSync** | Yes, via driver | **VSync: Adaptive (V4)** plus Uncapped/high FPS Cap is the VRR-friendly configuration; VRR itself is monitor+driver domain. Tooltip says exactly that. |
| **Reflex / low-latency mode** | Partially | No render-queue to shorten (2D, one-frame pipeline). Real latency levers we ship: **Exclusive Fullscreen (V1)**, **VSync Off (V4)**, **FPS Cap 0**. The 0.5 s enemy telegraphs (COMBAT_PACING §4) dwarf display latency by design. |
| **Anti-aliasing (MSAA/TAA/FXAA)** | N/A — anti-goal | Nearest-neighbor filtering (`default_texture_filter=0`) is the art direction; AA would blur the grid. The aliasing players might see is fractional-scaling shimmer — fixed by **Pixel Scaling: Integer**, not by AA. No AA row is shown. |
| **Texture quality / anisotropy** | N/A | Assets are native-resolution pixel sprites with no mips; there is nothing to degrade or filter. No row shown. |
| **Ambient occlusion (SSAO/HBAO)** | N/A | SSAO is a 3D depth-buffer effect. Our occlusion is authored: sprite contact shadows and the day/night `CanvasModulate` + weather MUL darkening. Closest dynamic analog is again **V7 shadows**. |
| **Volumetrics / god rays** | Partial | The **weather fog** (FastNoiseLite scroll shader) and storm darkening are our participating media; density rides **V8**. Screen-space light shafts are a possible future `Weather` visual, not a setting. |
| **Motion blur / film grain / CA** | N/A — anti-goal | Post-FX that fight pixel-art legibility. Deliberately absent; **Vignette (V10)** is the one cinematic overlay we keep, and it's optional. |
| **Shader/driver pre-caching** | Mostly free | GL Compatibility + procedural `StyleBoxFlat`/shader UI compiles trivially at boot; the handful of canvas shaders (fog, colorblind, future SDF) are warmed by SettingsManager instancing each once at `_ready` behind the fade — no visible hitching, no UI row. |

---

## 10. Integration checklist (per file, smallest honest diff)

| File | Change |
|---|---|
| `project.godot` | Add `Settings` autoload (first); add pad events to actions (§6.5 P1). |
| `scripts/settings_manager.gd` | **NEW** — §1 skeleton + §§2–6 hooks (~350 lines). |
| `scripts/settings_panel.gd` | **NEW** — §8 tabbed panel (~500 lines, pause-menu kit reuse). |
| `scripts/ui_kit.gd` | **NEW** (~40 lines) — shared palette/StyleBox/label-styling constants; `_style_label` adds `"rh_text"` group (§A3). |
| `scripts/pause_menu.gd` | Row list → Resume/Settings/Save/Quit; delete music-meta plumbing; open SettingsPanel (§8.4). |
| `scripts/main_menu.gd` | Add "Settings" row → opens SettingsPanel over the title. |
| `scripts/main.gd` | `music.bus="Music"`, `_zone_ambience.bus="Ambience"`; delete `apply_music_volume` call-group hook; call `Settings.apply_all()` at the end of `_bootstrap_world`, `_bootstrap_world_from_save`, and `change_map` (world-node hooks re-attach); world prompts use `Settings.event_short_name()` (§6.4). |
| `scripts/weather.gd` | Add `set_particle_density()` (§V8); `_strike()` reads `Settings.flash_scale()` (§A4). No bus change needed. |
| `scripts/player.gd` | `_shake_camera` × `Settings.shake_scale()`; `_flash_red` softened under reduced-flashing; sprint toggle latch (§A6). |
| `scripts/vfx.gd` | `damage_number` gate + `is_player_source` arg (§G2); `shake` × `shake_scale()`. |
| `scripts/hud.gd` | Live keybind captions (§6.4); `show_save_pip()` autosave toast (§G1). |
| `scripts/minimap.gd` | `visible` + enemy-dot gates (§G3/G4). |
| `scripts/item_tooltip.gd` | Compact-mode branch (§G5). |
| `scripts/voice_client.gd` | `_dvo.bus = "Voice"` + spatial players (§3.2). |
| `scripts/town_builder.gd` / `wilderness_builder.gd` / `gate_builder.gd` | `LightOccluder2D` pass for V7 (content milestone, may trail the suite by one release with V7 hidden until then). |

**QA harness:** extend the existing env-hook pattern (`main.gd:_run_env_hooks`) with
`RH_SETTINGS="video/light_shadows=soft;accessibility/colorblind_filter=deuteranopia"` — parsed
into `Settings.set_v` calls before the screenshot frame, so the `RH_SHOT`/`RH_UI` pipeline can
capture every setting permutation headlessly (colorblind × loot window, shadows × night town,
UI scale × every panel).

**Ship gate:** defaults-untouched run must be pixel- and byte-identical in behavior to today's
build except for the new audio buses at 0 dB (inaudible) — verified by an `RH_SHOT` diff against
a pre-suite screenshot set.
