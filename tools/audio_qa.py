# Audio QA validator (BACKLOG #54 / design/AUDIO_QA.md layer 4).
# Rockstar-bar automated gate over every shipped audio file:
#   1. header/decode integrity (catches libsndfile shell files)
#   2. duration sanity
#   3. true-peak clipping
#   4. integrated loudness windows per class (music/ambience/weather/vo)
#   5. loop-seam smoothness for loopable beds (music/ambience)
# Run with the TTS venv python (has soundfile/numpy/pyloudnorm):
#   C:/Users/vstef/tts/venv/Scripts/python.exe tools/audio_qa.py
# Exit 1 on any FAIL. --json <path> writes a machine-readable report.
import argparse
import glob
import json
import math
import os
import sys

import numpy as np
import pyloudnorm
import soundfile as sf

# class -> (glob roots, LUFS window, loopable)
CLASSES = {
    "music":    (["assets/audio/music/*.ogg"],    (-24.0, -11.0), True),
    "ambience": (["assets/audio/ambience/*.ogg"], (-30.0, -14.0), True),
    "weather":  (["assets/audio/weather/*.ogg"],  (-30.0, -12.0), True),
    "vo":       (["assets/vo/*/*.ogg"],           (-25.0, -13.0), False),
}
PEAK_CEILING_DBFS = -0.2   # anything hotter risks clipping on cheap DACs
MIN_DURATION_S = 0.15
SEAM_WINDOW_S = 0.10       # loop check: first vs last 100 ms
SEAM_MAX_DELTA_DB = 8.0    # bigger jump = audible loop pop/level step


def db(x: float) -> float:
    return 20.0 * math.log10(max(1e-9, x))


def check_file(path: str, lufs_win, loopable: bool):
    problems = []
    try:
        data, rate = sf.read(path, always_2d=True)
    except Exception as exc:
        return ["DECODE: %s" % exc]
    dur = len(data) / float(rate)
    if dur < MIN_DURATION_S:
        problems.append("DURATION: %.3fs (< %.2fs — header-only shell?)" % (dur, MIN_DURATION_S))
        return problems
    mono = data.mean(axis=1)
    peak = db(float(np.abs(data).max()))
    if peak > PEAK_CEILING_DBFS:
        problems.append("PEAK: %.2f dBFS (> %.1f)" % (peak, PEAK_CEILING_DBFS))
    # integrated loudness (files shorter than the 400ms gate window: use RMS)
    if dur >= 0.5:
        try:
            lufs = pyloudnorm.Meter(rate).integrated_loudness(mono)
        except Exception:
            lufs = db(float(np.sqrt((mono ** 2).mean())))
    else:
        lufs = db(float(np.sqrt((mono ** 2).mean())))
    lo, hi = lufs_win
    if not (lo <= lufs <= hi):
        problems.append("LOUDNESS: %.1f LUFS (window %.0f..%.0f)" % (lufs, lo, hi))
    if loopable and dur >= 2.0:
        n = int(SEAM_WINDOW_S * rate)
        head = db(float(np.sqrt((mono[:n] ** 2).mean())))
        tail = db(float(np.sqrt((mono[-n:] ** 2).mean())))
        if abs(head - tail) > SEAM_MAX_DELTA_DB:
            problems.append("LOOP SEAM: head %.1f dB vs tail %.1f dB (step > %.0f dB)"
                            % (head, tail, SEAM_MAX_DELTA_DB))
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="write JSON report here")
    args = ap.parse_args()
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    report, fails, total = {}, 0, 0
    for cls, (roots, win, loopable) in CLASSES.items():
        for root in roots:
            for path in sorted(glob.glob(root)):
                total += 1
                problems = check_file(path, win, loopable)
                if problems:
                    fails += 1
                    report[path.replace("\\", "/")] = problems
                    print("FAIL %-60s %s" % (path, "; ".join(problems)))
    print("audio_qa: %d files checked, %d FAIL" % (total, fails))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"total": total, "fails": fails, "problems": report}, fh, indent=1)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
