#!/usr/bin/env python3
"""
Unit test for the VFX-mode Vision Gauntlet (VFX_PIPELINE.md First Build Step 2,
Prime Mandate verification). Asserts the gate:

  (1) PASSES the Foozle CC0 fireball control (10x 64x64, hand-authored, CC0), and
  (2) REJECTS a known AI-mush clip (the soft Wan fireball frames) -- and REJECTS it
      specifically on a VFX lens: the emissive colourfulness-STRUCTURE lens
      (a mono-tint AI blob does not span a real red->white emissive ramp), with
      pixel_art (raw colour count) as a second independent killing lens.

Honest-degrade contract: the Foozle control MUST pass (it is the reference ceiling);
if the mush ever passes, TIGHTEN the mush lenses in vfx_bar.json until the blob
fails while Foozle still passes (do NOT loosen anything that would let the control
fail). Bands live in tools/assets/vfx_bar.json.

Run:  python tools/assets/test_vfx_gate.py     (or: pytest tools/assets/test_vfx_gate.py)
"""
from __future__ import annotations
import os
import sys
import glob

os.environ.setdefault("RH_GAUNTLET_VLM", "0")  # deterministic + fast; VLM is advisory anyway
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import gauntlet as G

_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

FOOZLE_DIR = os.environ.get(
    "RH_VFX_FOOZLE",
    os.path.join(_REPO, "_downloads", "vfx_packs", "foozle_pixel_magic", "extracted",
                 "Foozle_2DE0001_Pixel_Magic_Effects", "Fire_Ball"))

# Known AI-mush clips (soft Wan fireball). First present one wins; both are the
# "soft AI one" the pipeline doc names. RGB, un-quantized, soft -> must be rejected.
MUSH_GLOBS = [
    os.environ.get("RH_VFX_MUSH", ""),
    r"C:\Users\vstef\ComfyUI\output\rh_fb_clean_*.png",
    r"C:\Users\vstef\ComfyUI\output\rh_vid_fireball_*.png",
]


def _load(pattern_or_dir, limit=None):
    if os.path.isdir(pattern_or_dir):
        fs = sorted(glob.glob(os.path.join(pattern_or_dir, "*.png")))
    else:
        fs = sorted(glob.glob(pattern_or_dir))
    if limit:
        fs = fs[:limit]
    return [Image.open(f) for f in fs]


def _find_mush():
    for pat in MUSH_GLOBS:
        if pat and glob.glob(pat):
            return pat, _load(pat, limit=14)
    return None, []


def _killing_lenses(verdicts):
    return [name for name, p, _ in verdicts if p is False]


def _fmt(verdicts, only_fail=False):
    out = []
    for name, p, r in verdicts:
        if only_fail and p is not False:
            continue
        tag = "PASS" if p is True else ("FAIL" if p is False else "abstain")
        out.append(f"    [{tag}] {r}")
    return "\n".join(out)


# ------------------------------------------------------------------- pytest tests
def test_control_pack_present():
    frames = _load(FOOZLE_DIR)
    assert len(frames) >= 3, f"Foozle control pack missing/short at {FOOZLE_DIR} ({len(frames)} frames)"


def test_gate_passes_foozle():
    frames = _load(FOOZLE_DIR)
    assert frames, "no Foozle frames"
    ok, verdicts = G.run_vfx_gauntlet(frames, subject="a fireball projectile")
    kills = _killing_lenses(verdicts)
    assert ok is True, f"Gate WRONGLY rejected the Foozle control. Killing lenses: {kills}\n{_fmt(verdicts)}"
    # the control must be scored every run and reach itself (self-consistency)
    names = [n for n, _, _ in verdicts]
    assert "beats_control" in names, "control-comparison lens missing"
    assert "emissive_vivid" in names and "partial_alpha" in names, "VFX lenses missing"


def test_gate_rejects_mush():
    src, frames = _find_mush()
    assert frames, f"no known-mush clip found (looked in: {[p for p in MUSH_GLOBS if p]})"
    ok, verdicts = G.run_vfx_gauntlet(frames)
    kills = _killing_lenses(verdicts)
    assert ok is False, f"Gate WRONGLY passed known AI-mush ({src}). TIGHTEN mush lenses.\n{_fmt(verdicts)}"
    # must be killed by a real VFX lens, not by accident. emissive colourfulness-
    # STRUCTURE is the calibrated mush discriminator for a mono-tint blob.
    assert "emissive_vivid" in kills or "partial_alpha" in kills or "silhouette" in kills, (
        f"mush rejected but NOT by a VFX mush lens (emissive/partial-alpha/silhouette). Kills: {kills}")
    # pixel_art (raw colour count) should also independently catch un-quantized AI
    assert "pixel_art" in kills, f"expected pixel_art to also catch the raw AI blob. Kills: {kills}"


def test_mush_scores_below_control():
    src, frames = _find_mush()
    assert frames, "no mush clip"
    ctrl = G._control_score()
    assert ctrl is not None, "no Foozle control score"
    cand = G._vfx_composite(G._vfx_measure(frames))
    assert cand < ctrl, f"mush composite {cand:.1f} not below control {ctrl:.1f}"


# ------------------------------------------------------------------- standalone run
def _main():
    passed = True

    print("=" * 72)
    print("VFX GATE UNIT TEST  (PASS Foozle control / REJECT AI-mush)")
    print("=" * 72)

    ctrl = G._control_score()
    print(f"Foozle control composite score: {ctrl if ctrl is None else round(ctrl, 1)}")

    # (1) Foozle control must PASS
    foozle = _load(FOOZLE_DIR)
    print(f"\n[1] FOOZLE control ({len(foozle)} frames) @ {FOOZLE_DIR}")
    if not foozle:
        print("    ERROR: Foozle control pack not found."); return 2
    ok, verdicts = G.run_vfx_gauntlet(foozle, subject="a fireball projectile")
    print(f"    -> {'PASS' if ok else 'REJECT'}")
    print(_fmt(verdicts))
    if not ok:
        print("    !! FAIL: gate rejected the control"); passed = False

    # (2) known mush must be REJECTED
    src, mush = _find_mush()
    print(f"\n[2] MUSH clip ({len(mush)} frames) @ {src}")
    if not mush:
        print("    ERROR: no known-mush clip found."); return 2
    okm, vm = G.run_vfx_gauntlet(mush)
    kills = _killing_lenses(vm)
    print(f"    -> {'PASS' if okm else 'REJECT'}   killing lenses: {kills}")
    print(_fmt(vm, only_fail=True))
    if okm:
        print("    !! FAIL: gate passed known AI-mush (tighten mush lenses)"); passed = False
    elif not ("emissive_vivid" in kills or "partial_alpha" in kills or "silhouette" in kills):
        print("    !! FAIL: mush not killed by a VFX mush lens"); passed = False

    print("\n" + "=" * 72)
    print("RESULT:", "ALL TESTS PASS" if passed else "FAILURE")
    print("=" * 72)
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(_main())
