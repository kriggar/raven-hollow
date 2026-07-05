# Loop-seam + loudness fixer for music/ambience beds (BACKLOG #54).
# For each failing file from tools/audio_qa.py:
#   1. trim edge silence (below -55 dBFS)
#   2. render a seamless loop: cut the head region off, then equal-power
#      crossfade the file's original head INTO the tail — the loop point
#      then plays identical material on both sides (no pop, no level step)
#   3. normalize integrated loudness to the class target
# OGG writes are CHUNKED (sf.SoundFile, 1 s blocks) — single-call writes
# >10 s hard-crash libsndfile 1.2.2 silently (exit 127).
# Run: C:/Users/vstef/tts/venv/Scripts/python.exe tools/audio_fix_loops.py
import math
import os
import sys

import numpy as np
import pyloudnorm
import soundfile as sf

TARGETS = {  # path prefix -> target LUFS
    "assets/audio/music": -17.0,
    "assets/audio/ambience": -21.0,
    "assets/audio/weather": -21.0,
}
FILES = [  # pass only the currently-failing files (avoid lossy re-encodes)
    "assets/audio/music/theme_south.ogg",
    "assets/audio/ambience/amb_swamp.ogg",
]
SILENCE_DB = -55.0


def db(x):
    return 20.0 * math.log10(max(1e-9, float(x)))


def trim_silence(x, rate):
    win = max(1, int(0.02 * rate))
    rms = np.sqrt(np.convolve((x ** 2).mean(axis=1), np.ones(win) / win, mode="same"))
    loud = np.where(20.0 * np.log10(np.maximum(rms, 1e-9)) > SILENCE_DB)[0]
    if len(loud) == 0:
        return x
    return x[loud[0]: loud[-1] + 1]


def seamless_loop(x, rate):
    # cut to sustained-level material (drops musical fade-in/out edges),
    # then wrap the body onto itself with an equal-power crossfade — the
    # loop point plays identical material on both sides by construction.
    win = max(1, int(0.1 * rate))
    env = np.sqrt(np.convolve((x ** 2).mean(axis=1), np.ones(win) / win, mode="same"))
    env_db = 20.0 * np.log10(np.maximum(env, 1e-9))
    floor = np.median(env_db) - 8.0
    idx = np.where(env_db >= floor)[0]
    if len(idx) > int(2.0 * rate):
        x = x[idx[0]: idx[-1] + 1]
    # rotate the loop point into the highest-energy sustained region —
    # a seam in a loud steady passage is inaudible; one at a quiet edge pops
    if len(x) > int(6.0 * rate):
        env2 = np.sqrt(np.convolve((x ** 2).mean(axis=1), np.ones(win) / win, mode="same"))
        peak_at = int(np.argmax(env2[int(2.0 * rate): -int(2.0 * rate)])) + int(2.0 * rate)
        x = np.roll(x, -peak_at, axis=0)
    fade = min(int(1.5 * rate), len(x) // 8)
    if fade < int(0.2 * rate):
        return x
    body = x.copy()
    t = np.linspace(0.0, 1.0, fade, endpoint=False)[:, None]
    body[-fade:] = body[-fade:] * np.sqrt(1.0 - t) + body[:fade] * np.sqrt(t)
    return body


def write_chunked(path, x, rate):
    with sf.SoundFile(path, "w", samplerate=rate, channels=x.shape[1], format="OGG") as fh:
        step = rate
        for i in range(0, len(x), step):
            fh.write(x[i: i + step])


def main():
    os.chdir(os.path.join(os.path.dirname(__file__), ".."))
    for path in FILES:
        x, rate = sf.read(path, always_2d=True)
        x = trim_silence(x, rate)
        x = seamless_loop(x, rate)
        target = next(v for k, v in TARGETS.items() if path.startswith(k))
        mono = x.mean(axis=1)
        lufs = pyloudnorm.Meter(rate).integrated_loudness(mono)
        gain = 10.0 ** ((target - lufs) / 20.0)
        x = x * gain
        peak = float(np.abs(x).max())
        if peak > 0.90:  # headroom for vorbis encode overshoot (~0.5 dB)
            x = x * (0.90 / peak)
        write_chunked(path, x, rate)
        print("fixed %-46s %.1f -> %.1f LUFS, len %.1fs" % (path, lufs, target, len(x) / rate))


if __name__ == "__main__":
    main()
