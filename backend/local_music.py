#!/usr/bin/env python3
"""local_music.py

Scan a local music folder and emit a JSON index.

Goals:
- Dependency-free (no mutagen).
- Fast enough for handheld use.
- Stable schema for QML.

Schema:
{
  "generated_at": "...Z",
  "root": "/home/user/Music",
  "error": "" | "...",
  "albums": [
     {
       "id": "relative/folder",
       "title": "relative/folder",
       "track_count": 12,
       "tracks": [
          {"id": "relative/path.flac", "title": "Track", "path": "/abs/path", "ext": "flac"}
       ]
     }
  ]
}

Notes:
- "albums" is simply a folder grouping (subfolders under root).
- Title is derived from filename (no tags).

"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Dict, List


AUDIO_EXTS = {"flac", "mp3", "ogg", "opus", "m4a", "aac", "wav"}


def _utc_iso() -> str:
    return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


_cleanup = re.compile(r"\s+")


def _title_from_filename(name: str) -> str:
    # Remove extension and common track number prefixes.
    base = Path(name).stem
    base = re.sub(r"^\d+\s*[-._]\s*", "", base)
    base = base.replace("_", " ")
    base = base.replace(".", " ")
    base = _cleanup.sub(" ", base).strip()
    return base or Path(name).stem


def _write_json(path: str, payload: Dict) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def build_index(root: Path) -> Dict:
    payload: Dict = {
        "generated_at": _utc_iso(),
        "root": str(root),
        "error": "",
        "albums": [],
    }

    if not root.exists():
        payload["error"] = f"Music root not found: {root}"
        return payload
    if not root.is_dir():
        payload["error"] = f"Music root is not a directory: {root}"
        return payload

    albums: Dict[str, Dict] = {}

    # Walk
    for dirpath, _dirnames, filenames in os.walk(root):
        d = Path(dirpath)
        rel_dir = os.path.relpath(d, root)
        # Use "." to represent the root itself.
        album_id = "" if rel_dir == "." else rel_dir

        for fn in filenames:
            ext = fn.rsplit(".", 1)[-1].lower() if "." in fn else ""
            if ext not in AUDIO_EXTS:
                continue
            full_path = d / fn
            try:
                rel_path = str(full_path.relative_to(root))
            except Exception:
                rel_path = str(full_path)

            album = albums.get(album_id)
            if album is None:
                title = "Local" if album_id == "" else album_id
                album = {
                    "id": album_id,
                    "title": title,
                    "tracks": [],
                }
                albums[album_id] = album

            album["tracks"].append(
                {
                    "id": rel_path,
                    "title": _title_from_filename(fn),
                    "path": str(full_path),
                    "ext": ext,
                }
            )

    # Sort albums and tracks
    def album_sort_key(a: Dict) -> str:
        return (a.get("id") or "").lower()

    out_albums: List[Dict] = list(albums.values())
    for a in out_albums:
        a["tracks"].sort(key=lambda t: (t.get("title") or "").lower())
        a["track_count"] = len(a["tracks"])

    out_albums.sort(key=album_sort_key)
    payload["albums"] = out_albums
    return payload


def run_once(out_path: str, root_path: str) -> None:
    root = Path(root_path).expanduser() if root_path else Path("~/Music").expanduser()
    payload = build_index(root)
    _write_json(out_path, payload)


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--root", default="")
    ap.add_argument("--watch", action="store_true")
    ap.add_argument("--interval", type=float, default=10.0)
    args = ap.parse_args(argv)

    if not args.watch:
        run_once(args.out, args.root)
        return 0

    while True:
        run_once(args.out, args.root)
        time.sleep(max(2.0, float(args.interval)))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
