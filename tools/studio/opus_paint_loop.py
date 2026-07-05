# THE OPUS VISION-LOOP PAINTER harness  (BLUEPRINT #113, Tier 1)
#
# Orchestrates one render-see-fix pass of the Fable-method painting loop:
#   draft JSON -> render_draft.py (temp "studio_canvas" zone) -> boot windowed
#   Godot twice (overview @0.5x + close-up @0.9x) -> ALWAYS revert zone_defs.gd.
#
# The INTELLIGENCE is the driving Opus agent, not this script. Opus writes the
# layout JSON (its own spatial + aesthetic judgment), runs this harness, then
# READS the two screenshots it produced with native vision, self-critiques vs
# design/LEVEL_PAINTING_BIBLE.md + the 5 owner laws, revises the JSON, and loops
# (up to 6x) until both zoom levels pass its eye AND the walls. This file is only
# the hands: draft -> render -> screenshot -> feed the paths back.
#
# Usage:
#   python tools/studio/opus_paint_loop.py <brief> <tiles_w> <tiles_h> <biome> <out_prefix>
#
# Reads the layout the agent authored at _downloads/_studio/opus_draft.json.
# Recognised framing keys (harness-only; render_draft.py ignores them):
#   "_over_focus":  [x,y]  camera focus for the 0.5x overview  (default: canvas center)
#   "_close_focus": [x,y]  camera focus for the 0.9x close-up  (default: over_focus)
#   "_over_zoom":   float   (default 0.5 -- lower = more world in frame)
#   "_close_zoom":  float   (default 0.9)
#   "_time":        int      day/night hour 0..24 (default 12)
#
# Writes (and prints):
#   _screens/painter_exams/opus/<out_prefix>_over.png
#   _screens/painter_exams/opus/<out_prefix>_close.png
#
# HARD CONSTRAINT: scripts/zone_defs.gd is touched ONLY through render_draft.py's
# temp injection and is reverted in a finally block even on crash/timeout; the
# harness verifies `git status` is clean for it before returning.
import io
import json
import os
import pathlib
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]        # .../medieval_rpg
GODOT = os.environ.get(
    "RH_GODOT",
    r"C:/Users/vstef/tools/godot/Godot_v4.6.3-stable_win64_console.exe")
DRAFT = REPO / "_downloads" / "_studio" / "opus_draft.json"
SHOT_DIR = REPO / "_screens" / "painter_exams" / "opus"


def _revert_zone_defs() -> None:
    subprocess.run(["git", "checkout", "--", "scripts/zone_defs.gd"],
                   cwd=str(REPO), check=False)


def _zone_defs_clean() -> bool:
    out = subprocess.run(["git", "status", "--porcelain", "scripts/zone_defs.gd"],
                         cwd=str(REPO), capture_output=True, text=True)
    return out.stdout.strip() == ""


def _boot_shot(focus, zoom, time_h, shot_path) -> bool:
    env = dict(os.environ)
    env.update({
        "RH_CLASS": "warrior",
        "RH_MAP": "studio_canvas",
        "RH_TIME": str(time_h),
        "RH_ZOOM": str(zoom),
        "RH_NOHUD": "1",
        "RH_FOCUS": "%d,%d" % (int(focus[0]), int(focus[1])),
        "RH_SHOT": str(shot_path),
    })
    shot_path.parent.mkdir(parents=True, exist_ok=True)
    if shot_path.exists():
        shot_path.unlink()
    print("[boot] focus=%s zoom=%s time=%s -> %s"
          % (focus, zoom, time_h, shot_path.name))
    try:
        subprocess.run([GODOT, "res://scenes/main.tscn"],
                       cwd=str(REPO), env=env, timeout=240, check=False)
    except subprocess.TimeoutExpired:
        print("[boot] TIMEOUT -- Godot did not quit; screenshot may be missing")
    return shot_path.exists()


def main() -> None:
    if len(sys.argv) != 6:
        print(__doc__)
        sys.exit(2)
    brief, tw, th, biome, out_prefix = (
        sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], sys.argv[5])
    w, h = tw * 32, th * 32

    draft = json.load(io.open(DRAFT, encoding="utf-8"))
    over_focus = draft.get("_over_focus", [w // 2, h // 2])
    close_focus = draft.get("_close_focus", over_focus)
    over_zoom = float(draft.get("_over_zoom", 0.5))
    close_zoom = float(draft.get("_close_zoom", 0.9))
    time_h = int(draft.get("_time", 12))

    # Clean slate: never inject on top of a stale studio_canvas from a prior
    # crashed run (render_draft.py refuses to double-inject).
    _revert_zone_defs()

    inj = subprocess.run(
        [sys.executable, "tools/studio/render_draft.py",
         str(DRAFT), str(tw), str(th), biome],
        cwd=str(REPO))
    if inj.returncode != 0:
        _revert_zone_defs()
        print("!! render_draft.py failed to inject -- aborting")
        sys.exit(1)

    over = SHOT_DIR / ("%s_over.png" % out_prefix)
    close = SHOT_DIR / ("%s_close.png" % out_prefix)
    ok_over = ok_close = False
    try:
        ok_over = _boot_shot(over_focus, over_zoom, time_h, over)
        ok_close = _boot_shot(close_focus, close_zoom, time_h, close)
    finally:
        _revert_zone_defs()

    clean = _zone_defs_clean()
    print("\n=== opus_paint_loop :: %s  (%s %dx%d %s) ==="
          % (brief, out_prefix, tw, th, biome))
    print("  over  -> %s   [%s]" % (over, "OK" if ok_over else "MISSING"))
    print("  close -> %s   [%s]" % (close, "OK" if ok_close else "MISSING"))
    print("  zone_defs.gd reverted clean: %s" % clean)
    if not clean:
        print("  !! zone_defs.gd dirty -- run: git checkout -- scripts/zone_defs.gd")
        sys.exit(3)
    if not (ok_over and ok_close):
        sys.exit(4)


if __name__ == "__main__":
    main()
