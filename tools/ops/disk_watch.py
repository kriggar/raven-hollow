# Disk-space watcher for Raven Hollow ops (#97 / #122 C:-drive relief).
# Reports drive usage + prunable categories across known hot dirs. DRY-RUN by default.
# Only ever deletes EXPLICITLY-SAFE categories, and only with --prune. Never touches
# source, data/, assets/ kept art, git, or model weights.
import argparse, os, shutil, sys, time

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Hot dirs we know grow. (label, path)
HOT = [
    ("repo", r"C:\Users\vstef\Desktop\rpg\medieval_rpg"),
    ("comfyui", r"C:\Users\vstef\ComfyUI"),
    ("comfy_output", r"C:\Users\vstef\ComfyUI\output"),
    ("comfy_temp", r"C:\Users\vstef\ComfyUI\temp"),
    ("user_temp", r"C:\Users\vstef\AppData\Local\Temp"),
    ("models_d", r"D:\ComfyUI-models"),
    ("assetlib_d", r"D:\raven hollow"),
]

# Categories safe to prune (relative-glob semantics via walk). Each: (label, predicate, why)
def _is_pycache(root, d): return d == "__pycache__"
def _is_downloads_raw(path): return os.sep + "_downloads" + os.sep in path
def _is_comfy_scratch(path):
    p = path.lower()
    return (os.sep + "comfyui" + os.sep + "temp" + os.sep) in p

SAFE_PRUNE_DIRS = [
    ("__pycache__", "python bytecode cache, regenerated on next run"),
]


def dir_size(path, cap_seconds=25):
    total, files, start = 0, 0, time.time()
    try:
        for r, dirs, fs in os.walk(path):
            for f in fs:
                try:
                    total += os.path.getsize(os.path.join(r, f)); files += 1
                except OSError:
                    pass
            if time.time() - start > cap_seconds:
                return total, files, True  # timed out (partial)
    except OSError:
        pass
    return total, files, False


def gb(n): return n / 1e9


def drives():
    print("=== DRIVE USAGE ===")
    for d in ("C:\\", "D:\\"):
        try:
            u = shutil.disk_usage(d)
            pct = u.used / u.total * 100
            flag = "  <-- TIGHT" if u.free / u.total < 0.10 else ""
            print(f"{d}  total {gb(u.total):6.0f}GB  used {gb(u.used):6.0f}GB ({pct:4.1f}%)  free {gb(u.free):6.1f}GB{flag}")
        except OSError:
            print(f"{d}  (unavailable)")
    print()


def scan_hot():
    print("=== HOT DIRS (size, may be partial if slow) ===")
    rows = []
    for label, path in HOT:
        if not os.path.isdir(path):
            print(f"{label:14s} MISSING  {path}")
            continue
        size, files, partial = dir_size(path)
        rows.append((label, path, size, files, partial))
        p = " ~partial" if partial else ""
        print(f"{label:14s} {gb(size):8.2f}GB  {files:>7} files{p}  {path}")
    print()
    return rows


def find_prunable():
    print("=== PRUNABLE (safe categories only) ===")
    hits = []  # (path, size, category)
    for label, root in HOT:
        if not os.path.isdir(root):
            continue
        start = time.time()
        for r, dirs, fs in os.walk(root):
            if time.time() - start > 30:
                break
            base = os.path.basename(r)
            if base == "__pycache__":
                sz, _, _ = dir_size(r, cap_seconds=5)
                hits.append((r, sz, "__pycache__"))
                dirs[:] = []  # don't descend
    total = sum(h[1] for h in hits)
    for path, sz, cat in sorted(hits, key=lambda x: -x[1])[:40]:
        print(f"  {gb(sz)*1000:7.1f}MB  [{cat}]  {path}")
    print(f"  ---- prunable total: {gb(total):.2f}GB across {len(hits)} dirs ----\n")
    return hits


def prune(hits, cap_gb):
    freed = 0
    print("=== PRUNING (safe categories) ===")
    for path, sz, cat in sorted(hits, key=lambda x: -x[1]):
        if gb(freed) >= cap_gb:
            print(f"  cap {cap_gb}GB reached; stopping."); break
        try:
            shutil.rmtree(path)
            freed += sz
            print(f"  removed {gb(sz)*1000:7.1f}MB  {path}")
        except OSError as e:
            print(f"  SKIP {path}: {e}")
    print(f"  ---- freed {gb(freed):.2f}GB ----\n")


def main():
    ap = argparse.ArgumentParser(description="Raven Hollow disk watcher (#97/#122)")
    ap.add_argument("--prune", action="store_true", help="actually delete safe categories (default: dry-run report)")
    ap.add_argument("--cap-gb", type=float, default=20.0, help="max GB to free in one prune run")
    a = ap.parse_args()
    drives()
    scan_hot()
    hits = find_prunable()
    if a.prune:
        prune(hits, a.cap_gb)
        drives()
    else:
        print("DRY-RUN. Re-run with --prune to remove the safe categories above.")


if __name__ == "__main__":
    main()
