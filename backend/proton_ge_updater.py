#!/usr/bin/env python3
"""proton_ge_updater.py

Fetch and (optionally) install the latest GE-Proton (Proton-GE) release.

This script is intended to be run periodically by MiyaShell (via Quickshell Process).

It:
  * Queries GitHub Releases (default: GloriousEggroll/proton-ge-custom)
  * Detects installed GE-Proton versions in Steam's compatibilitytools.d
  * Optionally downloads + extracts the latest release
  * Writes a status JSON file (for UI consumption)
  * Optionally sends a desktop notification via notify-send (best-effort)

Output JSON schema (stable-ish):
{
  "generated_at": "...Z",
  "repo": "GloriousEggroll/proton-ge-custom",
  "install_dir": "/home/user/.local/share/Steam/compatibilitytools.d",
  "latest": {
    "tag": "GE-Proton10-28",
    "asset_name": "GE-Proton10-28.tar.gz",
    "asset_url": "https://...",
    "published_at": "..."
  },
  "installed": ["GE-Proton10-28", "GE-Proton10-27"],
  "update_available": true,
  "last_notified": "GE-Proton10-28",
  "last_error": ""
}

Notes:
- Steam also supports external compatibility tools via compatibilitytools.d.
  After installing/updating a custom tool, you usually need to restart Steam
  to see it in the Compatibility dropdown.
- We do NOT attempt to modify Steam's default Proton selection (too fragile).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

import requests


def _utc_iso() -> str:
    return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _read_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _write_json_atomic(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    tmp.replace(path)


def _notify(summary: str, body: str) -> None:
    """Best-effort desktop notification."""
    try:
        subprocess.run(
            ["notify-send", summary, body],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass


def _github_latest_release(repo: str, timeout: float = 10.0) -> Dict[str, Any]:
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "MiyaShell-ProtonGE-Updater",
    }
    r = requests.get(url, headers=headers, timeout=timeout)
    r.raise_for_status()
    return r.json()


def _pick_ge_tarball(release_json: Dict[str, Any]) -> Optional[Tuple[str, str]]:
    """Return (asset_name, browser_download_url) for the best GE-Proton tarball."""
    assets = release_json.get("assets") or []
    for a in assets:
        name = str(a.get("name") or "")
        url = str(a.get("browser_download_url") or "")
        if name.startswith("GE-Proton") and name.endswith(".tar.gz") and url:
            return name, url
    return None


def _discover_install_dir(override: str | None = None) -> Path:
    if override:
        return Path(override).expanduser()

    # Common native paths
    candidates = [
        Path("~/.local/share/Steam/compatibilitytools.d").expanduser(),
        Path("~/.steam/root/compatibilitytools.d").expanduser(),
        Path("~/.steam/steam/compatibilitytools.d").expanduser(),
        # Flatpak Steam
        Path("~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d").expanduser(),
    ]

    for p in candidates:
        if p.is_dir():
            return p

    # Default to the modern native path, create it if needed.
    return candidates[0]


_GE_DIR_RE = re.compile(r"^GE-Proton\d+\-\d+.*$")


def _installed_versions(install_dir: Path) -> list[str]:
    if not install_dir.is_dir():
        return []

    vers: list[str] = []
    for child in install_dir.iterdir():
        if not child.is_dir():
            continue
        name = child.name
        if _GE_DIR_RE.match(name) or name.startswith("GE-Proton"):
            vers.append(name)

    # Sort by "natural-ish" numeric order (best-effort)
    def key(v: str):
        nums = re.findall(r"\d+", v)
        return [int(x) for x in nums] + [v]

    vers.sort(key=key, reverse=True)
    return vers


def _download_to(url: str, dest: Path, timeout: float = 30.0) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=timeout) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)


def _extract_tarball(tar_path: Path, install_dir: Path) -> str:
    """Extract tarball into install_dir. Returns top-level folder name."""
    install_dir.mkdir(parents=True, exist_ok=True)

    with tarfile.open(tar_path, "r:gz") as tf:
        # Determine the top-level directory name.
        top_dirs = set()
        for m in tf.getmembers():
            parts = m.name.split("/", 1)
            if parts and parts[0]:
                top_dirs.add(parts[0])
        top = sorted(top_dirs)[0] if top_dirs else ""

        tf.extractall(path=install_dir)

    return top


def _maybe_prune_old(install_dir: Path, keep: int) -> None:
    if keep <= 0:
        return
    installed = _installed_versions(install_dir)
    for old in installed[keep:]:
        try:
            shutil.rmtree(install_dir / old)
        except Exception:
            pass


def run_once(
    out_path: Path,
    repo: str,
    install_dir: Path,
    auto_install: bool,
    keep: int,
    notify: bool,
) -> Dict[str, Any]:
    prev = _read_json(out_path)
    last_notified = str(prev.get("last_notified") or "")

    payload: Dict[str, Any] = {
        "generated_at": _utc_iso(),
        "repo": repo,
        "install_dir": str(install_dir),
        "latest": {},
        "installed": [],
        "update_available": False,
        "last_notified": last_notified,
        "last_error": "",
    }

    try:
        rel = _github_latest_release(repo)
        tag = str(rel.get("tag_name") or "")
        pub = str(rel.get("published_at") or "")
        pick = _pick_ge_tarball(rel)
        if not tag or not pick:
            raise RuntimeError("Could not find GE-Proton tar.gz asset in latest release")

        asset_name, asset_url = pick
        payload["latest"] = {
            "tag": tag,
            "asset_name": asset_name,
            "asset_url": asset_url,
            "published_at": pub,
        }

        installed = _installed_versions(install_dir)
        payload["installed"] = installed

        update_available = tag not in installed
        payload["update_available"] = bool(update_available)

        if update_available and notify and last_notified != tag:
            _notify("MiyaShell", f"New Proton-GE available: {tag}")
            payload["last_notified"] = tag

        if update_available and auto_install:
            # Download and extract.
            with tempfile.TemporaryDirectory(prefix="miyashell-protonge-") as td:
                td_path = Path(td)
                tar_path = td_path / asset_name
                _download_to(asset_url, tar_path)
                top = _extract_tarball(tar_path, install_dir)

            # Refresh installed list.
            installed = _installed_versions(install_dir)
            payload["installed"] = installed
            payload["update_available"] = tag not in installed

            if keep > 0:
                _maybe_prune_old(install_dir, keep=keep)
                payload["installed"] = _installed_versions(install_dir)

            if notify:
                _notify("MiyaShell", f"Installed Proton-GE: {tag} (restart Steam)")

            # If we extracted into a weird top-level dir, include it for debugging.
            if top and top not in installed and (install_dir / top).is_dir():
                payload.setdefault("notes", []).append(f"Extracted folder: {top}")

    except Exception as e:
        payload["last_error"] = str(e)

    _write_json_atomic(out_path, payload)
    return payload


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Path to write proton_ge.json")
    ap.add_argument("--repo", default="GloriousEggroll/proton-ge-custom", help="GitHub repo (owner/name)")
    ap.add_argument("--install-dir", default="", help="Override compatibilitytools.d directory")
    ap.add_argument("--auto-install", action="store_true", help="Download+install when an update is available")
    ap.add_argument("--keep", type=int, default=2, help="How many GE-Proton versions to keep (0=keep all)")
    ap.add_argument("--notify", action="store_true", help="Send notify-send desktop notifications")
    ap.add_argument("--watch", action="store_true", help="Poll and update the JSON repeatedly")
    ap.add_argument("--interval", type=float, default=3600.0, help="Seconds between checks for --watch")
    args = ap.parse_args()

    out_path = Path(args.out).expanduser()
    install_dir = _discover_install_dir(args.install_dir or None)

    # If install_dir doesn't exist yet, create it so the UI has a deterministic path.
    install_dir.mkdir(parents=True, exist_ok=True)

    def once() -> None:
        run_once(
            out_path=out_path,
            repo=str(args.repo),
            install_dir=install_dir,
            auto_install=bool(args.auto_install),
            keep=int(args.keep),
            notify=bool(args.notify),
        )

    once()

    if not args.watch:
        return 0

    try:
        while True:
            time.sleep(float(args.interval))
            once()
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
