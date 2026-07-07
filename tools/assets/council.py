#!/usr/bin/env python3
"""
THE GENERATION COUNCIL  (owner law #115.2) — before each asset/category batch, decide:
  (a) PICTURE-gen vs VIDEO-gen, and (b) WHICH model — from asset type + the measured model scorecard.

Rule of thumb from the Model Matrix (_screens/model_matrix_scores.json is the live scorecard):
  * static prop / tile / building / monument  -> STILL lane
  * animated entity / creature / VFX / motion  -> VIDEO lane
Model choice within a lane is measured, not guessed: the still winner is whichever model has the best
gauntlet-pass + speed on that category; the video model is Wan 2.2 (the only installed video model that
fits 16 GB and holds character consistency). `route()` returns the decision + rationale, logged per batch.
"""
from __future__ import annotations
import os, json

SCORECARD = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "_screens", "model_matrix_scores.json"))

# category -> lane. Everything the still pipeline makes is static; motion goes to video.
VIDEO_CATEGORIES = {"creature", "vfx", "spell", "animation", "torch", "fire", "water", "flag_anim"}

# OWNER MODEL LOCK (2026-07-05, from the model matrix): PixelArtXL is the HOUSE model.
PRIMARY_STILL = "comfyui:sdxl+pixelartxl"       # LOCKED primary for all stills (crispest, on-style, fast)
SECONDARY_STILL = "comfyui:sdxl-base"           # secondary: richer detail; use where it survives the razor cut
DEFAULT_VIDEO = "comfyui:wan2.2-ti2v-5b"        # only 16GB-fitting installed video model; consistent

# categories dense enough that SDXL-base's extra detail is worth trying (still verified by the razor cut
# + Gauntlet; if it fails, the batch falls back to the locked primary).
DENSE_DETAIL = {"buildings", "market_food", "ruins", "tavern", "monuments"}


def _still_model(category):
    """Owner lock: PixelArtXL primary. SECONDARY (SDXL-base) is only *offered* for dense-detail
    categories; it never overrides the lock — the razor cut + Gauntlet decide if its output survives."""
    if category in DENSE_DETAIL:
        return PRIMARY_STILL, f"LOCKED primary PixelArtXL (SDXL-base secondary may be tried for dense '{category}')"
    return PRIMARY_STILL, "LOCKED primary: SDXL+PixelArtXL (house model)"


def route(category, animated=False, motion_hint=None):
    """Return the routing decision for a batch. Logged so every choice is auditable."""
    lane = "video" if (animated or category in VIDEO_CATEGORIES or motion_hint) else "still"
    if lane == "video":
        model, why = DEFAULT_VIDEO, "motion/animation -> video lane (Wan 2.2, 16GB-fit, consistent)"
    else:
        model, why = _still_model(category)
    decision = {"category": category, "lane": lane, "model": model, "rationale": why}
    return decision


def log_decision(decision, logfile=None):
    line = f"[council] {decision['category']}: {decision['lane']} via {decision['model']} — {decision['rationale']}"
    print(line, flush=True)
    if logfile:
        try:
            with open(logfile, "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except Exception:
            pass
    return line


if __name__ == "__main__":
    for cat, anim in [("prop", False), ("building", False), ("creature", True), ("vfx", True), ("harbor", False)]:
        log_decision(route(cat, animated=anim))
