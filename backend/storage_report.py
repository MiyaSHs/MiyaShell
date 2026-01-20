#!/usr/bin/env python3
"""storage_report.py

A lightweight storage usage report for a Steam-ish handheld UI.

Goals:
- Provide a disk usage summary similar to Steam's "Storage" / "Disk usage" views.
- Work offline.

We report, per Steam library folder:
- Filesystem total/used/free (from statvfs)
- Best-effort Steam usage (size of common Steam subdirs)

NOTE: Computing exact folder sizes can be expensive. We default to "du -sb"
when available (fast, implemented in C), otherwise fall back to a Python walk.

Output JSON:
{
  "generated_at": "...Z",
  "steam_root": "/home/user/.local/share/Steam",
  "libraries": [
    {
      "path": "/home/user/.local/share/Steam",
      "fs_total": 123,
      "fs_used": 45,
      "fs_free": 78,
      "steam_bytes": 12,
      "steam_breakdown": {"common": 1, "compatdata": 2, ...}
    }
  ]
}
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import subprocess
from pathlib import Path
from typing import Dict, Tuple

from steam_library import discover_library_paths, find_steam_root


def _utc_iso() -> str:
    return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _statvfs_bytes(path: Path) -> Tuple[int, int, int]:
    """Return (total, used, free) bytes for filesystem containing path."""
    st = os.statvfs(str(path))
    total = st.f_frsize * st.f_blocks
    free = st.f_frsize * st.f_bavail
    used = total - (st.f_frsize * st.f_bfree)
    return int(total), int(used), int(free)


def _du_bytes(path: Path) -> int:
    """Return directory size in bytes (best-effort)."""
    if not path.exists():
        return 0

    # Prefer du -sb if present.
    try:
        proc = subprocess.run(
            ["du", "-sb", str(path)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        if proc.returncode == 0 and proc.stdout:
            head = proc.stdout.strip().split("\t", 1)[0]
            return int(head)
    except Exception:
        pass

    # Fallback: Python walk (slower).
    total = 0
    for root, _dirs, files in os.walk(str(path)):
        for fn in files:
            fp = Path(root) / fn
            try:
                total += fp.stat().st_size
            except Exception:
                pass
    return int(total)


def generate() -> Dict:
    steam_root = find_steam_root()
    libs = discover_library_paths(steam_root)

    libraries = []

    for lib in libs:
        fs_total, fs_used, fs_free = _statvfs_bytes(lib)

        steamapps = lib / "steamapps"
        breakdown = {
            "common": _du_bytes(steamapps / "common"),
            "compatdata": _du_bytes(steamapps / "compatdata"),
            "shadercache": _du_bytes(steamapps / "shadercache"),
            "workshop": _du_bytes(steamapps / "workshop"),
            "downloading": _du_bytes(steamapps / "downloading"),
        }
        steam_bytes = sum(int(v) for v in breakdown.values())

        libraries.append(
            {
                "path": str(lib),
                "fs_total": fs_total,
                "fs_used": fs_used,
                "fs_free": fs_free,
                "steam_bytes": steam_bytes,
                "steam_breakdown": breakdown,
                "other_bytes": max(0, fs_used - steam_bytes),
            }
        )

    return {
        "generated_at": _utc_iso(),
        "steam_root": str(steam_root),
        "libraries": libraries,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Path to write storage.json")
    ap.add_argument("--watch", action="store_true", help="Refresh periodically")
    ap.add_argument("--interval", type=float, default=15.0, help="Refresh interval for --watch")
    args = ap.parse_args()

    out_path = Path(args.out).expanduser()

    def write_once() -> None:
        payload = generate()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = out_path.with_suffix(out_path.suffix + ".tmp")
        tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        tmp.replace(out_path)

    write_once()

    if not args.watch:
        return 0

    try:
        import time

        while True:
            time.sleep(float(args.interval))
            write_once()
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
