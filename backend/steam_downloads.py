#!/usr/bin/env python3
"""steam_downloads.py

Best-effort download / update queue reporting for Steam.

Steam does not expose a stable, supported local API for *download progress*.
So this script infers progress from local Steam app manifests:
  ~/.local/share/Steam/steamapps/appmanifest_<appid>.acf

In those manifests, AppState commonly includes byte counters like:
  - BytesDownloaded
  - BytesToDownload
  - BytesToStage

Those values are not officially documented; treat them as hints.

Output JSON schema:
{
  "generated_at": "...Z",
  "steam_root": "/home/user/.local/share/Steam",
  "downloads": [
    {
      "appid": 123,
      "name": "Game",
      "library_path": "/path/to/library",
      "bytes_downloaded": 123,
      "bytes_to_download": 456,
      "bytes_to_stage": 0,
      "total_bytes": 579,
      "progress": 0.212,
      "state_flags": 0
    }
  ]
}

Designed to be dependency-free.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
from pathlib import Path
from typing import Any, Dict, List

# Reuse the KeyValues parser + Steam discovery logic from steam_library.py
from steam_library import discover_library_paths, find_steam_root, load_keyvalues_file, _int


def _utc_iso() -> str:
    return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _extract_appstate(manifest: Path) -> Dict[str, Any] | None:
    try:
        kv = load_keyvalues_file(manifest)
    except Exception:
        return None

    appstate = kv.get("AppState")
    if not isinstance(appstate, dict):
        return None
    return appstate


def _maybe_download_entry(appstate: Dict[str, Any], library_path: Path) -> Dict[str, Any] | None:
    appid = _int(appstate.get("appid"), 0)
    if not appid:
        return None

    name = str(appstate.get("name") or f"App {appid}")

    # These fields exist for many (not all) manifests.
    bytes_downloaded = _int(appstate.get("BytesDownloaded"), 0)
    bytes_to_download = _int(appstate.get("BytesToDownload"), 0)
    bytes_to_stage = _int(appstate.get("BytesToStage"), 0)
    state_flags = _int(appstate.get("StateFlags"), 0)

    # Heuristic: treat as actively downloading/updating if any pending bytes exist.
    if bytes_to_download <= 0 and bytes_to_stage <= 0:
        return None

    total = bytes_downloaded + max(bytes_to_download, 0)
    progress = 0.0
    if total > 0:
        progress = max(0.0, min(1.0, bytes_downloaded / float(total)))

    return {
        "appid": appid,
        "name": name,
        "library_path": str(library_path),
        "bytes_downloaded": bytes_downloaded,
        "bytes_to_download": bytes_to_download,
        "bytes_to_stage": bytes_to_stage,
        "total_bytes": total,
        "progress": progress,
        "state_flags": state_flags,
    }


def generate() -> Dict[str, Any]:
    steam_root = find_steam_root()
    libs = discover_library_paths(steam_root)

    downloads: List[Dict[str, Any]] = []

    for lib in libs:
        steamapps = lib / "steamapps"
        if not steamapps.is_dir():
            continue

        for mf in steamapps.glob("appmanifest_*.acf"):
            appstate = _extract_appstate(mf)
            if not appstate:
                continue
            entry = _maybe_download_entry(appstate, lib)
            if entry:
                downloads.append(entry)

    # Sort: highest progress first, then name
    downloads.sort(key=lambda d: (-float(d.get("progress", 0.0)), str(d.get("name", "")).casefold()))

    return {
        "generated_at": _utc_iso(),
        "steam_root": str(steam_root),
        "downloads": downloads,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Path to write downloads.json")
    ap.add_argument("--watch", action="store_true", help="Poll and rewrite when manifests change")
    ap.add_argument("--interval", type=float, default=2.0, help="Poll interval for --watch")
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

    # Watch: rewrite when manifests change.
    steam_root = find_steam_root()
    libs = discover_library_paths(steam_root)
    last_mtime = 0.0
    try:
        import time

        while True:
            mt = 0.0
            for lib in libs:
                steamapps = lib / "steamapps"
                if not steamapps.is_dir():
                    continue
                for mf in steamapps.glob("appmanifest_*.acf"):
                    try:
                        mt = max(mt, mf.stat().st_mtime)
                    except Exception:
                        pass

            if mt > last_mtime:
                last_mtime = mt
                write_once()

            time.sleep(float(args.interval))
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
