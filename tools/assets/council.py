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

# default model per lane (overridden by the scorecard when present)
DEFAULT_STILL = "comfyui:sdxl+pixelartxl"      # matrix winner for gothic props (fast, clean, on-style)
DEFAULT_VIDEO = "comfyui:wan2.2-ti2v-5b"       # only 16GB-fitting installed video model; consistent


def _best_still_model():
    """Pick the highest-scoring still model from the live scorecard (gauntlet-pass, then speed)."""
    try:
        sc = json.load(open(SCORECARD, encoding="utf-8"))["scores"]
    except Exception:
        return DEFAULT_STILL, "scorecard unavailable -> default"
    cands = [(k, v) for k, v in sc.items()
             if v.get("status") == "ok" and "video" not in k.lower()]
    if not cands:
        return DEFAULT_STILL, "no ok still models in scorecard -> default"
    cands.sort(key=lambda kv: (not kv[1].get("gauntlet_pass", False), kv[1].get("seconds", 999)))
    best = cands[0][0]
    return best, f"scorecard winner (gauntlet_pass + fastest of {len(cands)})"


def route(category, animated=False, motion_hint=None):
    """Return the routing decision for a batch. Logged so every choice is auditable."""
    lane = "video" if (animated or category in VIDEO_CATEGORIES or motion_hint) else "still"
    if lane == "video":
        model, why = DEFAULT_VIDEO, "motion/animation -> video lane (Wan 2.2, 16GB-fit, consistent)"
    else:
        model, why = _best_still_model()
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
