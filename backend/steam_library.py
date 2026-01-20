#!/usr/bin/env python3
"""steam_library.py

Generate a JSON description of the user's Steam library.

Goals:
- Always work offline for *installed* games (parse Steam's local manifests).
- Optionally enrich with the *owned* library via Steam Web API if STEAM_API_KEY
  and STEAM_ID64 are provided.

Output JSON schema (stable-ish):
{
  "generated_at": "2026-01-17T12:00:00Z",
  "steam_root": "/home/user/.local/share/Steam",
  "games": [
    {
      "appid": 570,
      "name": "Dota 2",
      "installed": true,
      "library_path": "/home/user/.local/share/Steam",
      "installdir": "dota 2 beta",
      "state_flags": 4,
      "size_on_disk": 123456789,
      "cover": "/home/user/.local/share/Steam/appcache/librarycache/570_library_600x900.jpg"
    }
  ]
}

This is intentionally dependency-free (no external pip modules required).
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterator, List, Optional, Tuple, Union


Token = Union[str, "_LBrace", "_RBrace"]


class _LBrace:
    pass


class _RBrace:
    pass


LBRACE = _LBrace()
RBRACE = _RBrace()


_QUOTED = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')


def _unescape(s: str) -> str:
    # Valve KeyValues escape handling (minimal): \" and \\ and \n etc.
    return bytes(s, "utf-8").decode("unicode_escape")


def tokenize_keyvalues(text: str) -> Iterator[Token]:
    """Tokenize a Valve KeyValues (VDF/ACF) file into strings + braces."""
    i = 0
    n = len(text)

    while i < n:
        c = text[i]

        # whitespace
        if c.isspace():
            i += 1
            continue

        # comments: // ...
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            # skip to end of line
            j = text.find("\n", i)
            if j == -1:
                return
            i = j + 1
            continue

        if c == "{":
            i += 1
            yield LBRACE
            continue
        if c == "}":
            i += 1
            yield RBRACE
            continue

        # quoted string
        if c == '"':
            m = _QUOTED.match(text, i)
            if not m:
                raise ValueError(f"Invalid quoted string at offset {i}")
            raw = m.group(1)
            yield _unescape(raw)
            i = m.end()
            continue

        # bareword (rare in modern Steam files, but handle it)
        j = i
        while j < n and (not text[j].isspace()) and text[j] not in "{}":
            j += 1
        yield text[i:j]
        i = j


def parse_keyvalues(tokens: Iterator[Token]) -> Dict[str, Any]:
    """Parse tokens into a nested dict."""

    def parse_object() -> Dict[str, Any]:
        obj: Dict[str, Any] = {}
        while True:
            try:
                tok = next(tokens)
            except StopIteration:
                return obj

            if tok is RBRACE:
                return obj
            if tok is LBRACE:
                raise ValueError("Unexpected '{' while parsing object")

            if not isinstance(tok, str):
                raise ValueError(f"Unexpected token: {tok!r}")

            key = tok

            try:
                val = next(tokens)
            except StopIteration as e:
                raise ValueError(f"Unexpected EOF after key {key!r}") from e

            if val is LBRACE:
                obj[key] = parse_object()
            elif val is RBRACE:
                raise ValueError("Unexpected '}' after key")
            else:
                if not isinstance(val, str):
                    raise ValueError(f"Unexpected value token: {val!r}")
                obj[key] = val

    root = parse_object()
    return root


def load_keyvalues_file(path: Path) -> Dict[str, Any]:
    data = path.read_text(errors="replace")
    return parse_keyvalues(tokenize_keyvalues(data))


def find_steam_root() -> Path:
    """Best-effort Steam root resolution on Linux."""
    env = os.environ.get("STEAM_ROOT")
    candidates = [
        Path(env).expanduser() if env else None,
        Path("~/.steam/root").expanduser(),
        Path("~/.local/share/Steam").expanduser(),
        Path("~/.steam/steam").expanduser(),
    ]

    for c in candidates:
        if not c:
            continue
        if (c / "steamapps").is_dir():
            return c

    # fall back to first existing
    for c in candidates:
        if c and c.exists():
            return c

    raise FileNotFoundError(
        "Could not locate Steam root. Set STEAM_ROOT=/path/to/Steam." 
    )


def discover_library_paths(steam_root: Path) -> List[Path]:
    """Return a list of Steam library paths (each containing steamapps/)."""
    libs: List[Path] = []

    def add(p: Path) -> None:
        p = p.expanduser()
        if (p / "steamapps").is_dir() and p not in libs:
            libs.append(p)

    add(steam_root)

    vdf = steam_root / "steamapps" / "libraryfolders.vdf"
    if not vdf.exists():
        return libs

    try:
        kv = load_keyvalues_file(vdf)
    except Exception:
        return libs

    root = kv.get("libraryfolders")
    if not isinstance(root, dict):
        return libs

    for _k, v in root.items():
        if isinstance(v, dict):
            p = v.get("path")
            if isinstance(p, str) and p:
                add(Path(p))

    return libs


@dataclass
class Game:
    appid: int
    name: str
    installed: bool
    library_path: str
    installdir: str = ""
    state_flags: int = 0
    size_on_disk: int = 0
    cover: str = ""


def _int(x: Any, default: int = 0) -> int:
    try:
        return int(str(x))
    except Exception:
        return default


def find_cover(steam_root: Path, appid: int) -> str:
    """Return a best-effort local cover path if present."""
    cache = steam_root / "appcache" / "librarycache"
    if not cache.is_dir():
        return ""

    # Common Steam library asset names.
    candidates = [
        cache / f"{appid}_library_600x900.jpg",
        cache / f"{appid}_library_600x900.png",
        cache / f"{appid}_library_capsule.jpg",
        cache / f"{appid}_library_capsule.png",
        cache / f"{appid}_header.jpg",
        cache / f"{appid}_header.png",
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    return ""


def parse_installed_games(steam_root: Path, libs: List[Path]) -> Dict[int, Game]:
    games: Dict[int, Game] = {}

    for lib in libs:
        steamapps = lib / "steamapps"
        if not steamapps.is_dir():
            continue

        for mf in steamapps.glob("appmanifest_*.acf"):
            try:
                kv = load_keyvalues_file(mf)
            except Exception:
                continue

            appstate = kv.get("AppState")
            if not isinstance(appstate, dict):
                continue

            appid = _int(appstate.get("appid"), 0)
            if not appid:
                continue

            name = str(appstate.get("name") or "").strip() or f"App {appid}"
            installdir = str(appstate.get("installdir") or "").strip()
            state_flags = _int(appstate.get("StateFlags"), 0)
            size_on_disk = _int(appstate.get("SizeOnDisk"), 0)

            games[appid] = Game(
                appid=appid,
                name=name,
                installed=True,
                library_path=str(lib),
                installdir=installdir,
                state_flags=state_flags,
                size_on_disk=size_on_disk,
                cover=find_cover(steam_root, appid),
            )

    return games


def fetch_owned_games_from_webapi(api_key: str, steamid64: str) -> Dict[int, Dict[str, Any]]:
    """Fetch owned games using the Steam Web API.

    NOTE: This uses api.steampowered.com and is intentionally minimal.
    """
    base = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/"
    params = {
        "key": api_key,
        "steamid": steamid64,
        "include_appinfo": "1",
        "include_played_free_games": "1",
        "format": "json",
    }
    url = base + "?" + urllib.parse.urlencode(params)

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "miyashell-quickshell-ui/0.1 (+https://example.invalid)"
        },
    )

    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read()

    data = json.loads(body.decode("utf-8", errors="replace"))
    resp_obj = data.get("response", {})
    games = resp_obj.get("games") or []

    out: Dict[int, Dict[str, Any]] = {}
    if isinstance(games, list):
        for g in games:
            if not isinstance(g, dict):
                continue
            appid = _int(g.get("appid"), 0)
            if not appid:
                continue
            out[appid] = g
    return out


def merge_games(installed: Dict[int, Game], owned: Dict[int, Dict[str, Any]], steam_root: Path) -> List[Game]:
    merged: Dict[int, Game] = dict(installed)

    for appid, og in owned.items():
        if appid in merged:
            # installed wins for local paths, but allow name override if missing
            if merged[appid].name.startswith("App ") and isinstance(og.get("name"), str):
                merged[appid].name = og["name"]
            continue

        name = str(og.get("name") or "").strip() or f"App {appid}"
        merged[appid] = Game(
            appid=appid,
            name=name,
            installed=False,
            library_path="",
            installdir="",
            state_flags=0,
            size_on_disk=0,
            cover=find_cover(steam_root, appid),
        )

    # sort for UI
    return sorted(merged.values(), key=lambda g: g.name.casefold())


def write_json(out_path: Path, steam_root: Path, games: List[Game]) -> None:
    payload = {
        "generated_at": _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "steam_root": str(steam_root),
        "games": [
            {
                "appid": g.appid,
                "name": g.name,
                "installed": g.installed,
                "library_path": g.library_path,
                "installdir": g.installdir,
                "state_flags": g.state_flags,
                "size_on_disk": g.size_on_disk,
                "cover": g.cover,
            }
            for g in games
        ],
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    tmp.replace(out_path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Path to write library.json")
    ap.add_argument("--once", action="store_true", help="Generate once and exit (default)")
    ap.add_argument("--watch", action="store_true", help="Poll and regenerate when manifests change")
    ap.add_argument("--interval", type=float, default=2.0, help="Poll interval for --watch")
    args = ap.parse_args()

    out_path = Path(args.out).expanduser()

    steam_root = find_steam_root()
    libs = discover_library_paths(steam_root)
    installed = parse_installed_games(steam_root, libs)

    api_key = os.environ.get("STEAM_API_KEY")
    steamid64 = os.environ.get("STEAM_ID64")

    owned: Dict[int, Dict[str, Any]] = {}
    if api_key and steamid64:
        try:
            owned = fetch_owned_games_from_webapi(api_key, steamid64)
        except Exception:
            owned = {}

    games = merge_games(installed, owned, steam_root)
    write_json(out_path, steam_root, games)

    if args.watch:
        last_mtime = 0.0
        while True:
            # crude: scan all manifest mtimes
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
                libs = discover_library_paths(steam_root)
                installed = parse_installed_games(steam_root, libs)
                games = merge_games(installed, owned, steam_root)
                write_json(out_path, steam_root, games)

            try:
                import time

                time.sleep(args.interval)
            except KeyboardInterrupt:
                break

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
