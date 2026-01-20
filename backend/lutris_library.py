#!/usr/bin/env python3
"""lutris_library.py

Generate a JSON description of the user's Lutris library.

Primary source: Lutris CLI.

The Lutris man page documents:
- `--list-games`: list games
- `--json`: print results in JSON
- `lutris:rungameid/<numerical-id>`: run a game by its ID

So the preferred way to query the library is:

    lutris --list-games --json

This script is intentionally dependency-free.

Output JSON schema (stable-ish):

{
  "generated_at": "2026-01-17T12:00:00Z",
  "source": "cli" | "sqlite" | "none",
  "games": [
    {
      "id": 123,
      "name": "Some Game",
      "slug": "some-game",
      "runner": "wine",
      "platform": "windows",
      "installed": true,
      "raw": { ... }   # original fields, if present
    }
  ]
}

If the CLI isn't available or doesn't support JSON, we fall back to Lutris' local
SQLite DB (~/.local/share/lutris/pga.db) and extract best-effort columns.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def _utc_iso() -> str:
    return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _run_cli() -> Optional[List[Dict[str, Any]]]:
    """Return Lutris game list from CLI as a list of dicts, or None."""

    # Try a few invocations; Lutris CLI options have varied across versions.
    candidates: List[List[str]] = [
        ["lutris", "--list-games", "--json"],
        ["lutris", "-l", "--json"],
        ["lutris", "--list-games"],
        ["lutris", "-l"],
    ]

    for cmd in candidates:
        try:
            proc = subprocess.run(
                cmd,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
        except FileNotFoundError:
            return None
        except Exception:
            continue

        out = (proc.stdout or "").strip()
        if not out:
            continue

        # If it's JSON, parse it.
        if out.startswith("{") or out.startswith("["):
            try:
                data = json.loads(out)
            except Exception:
                continue

            # Common shapes: list[...] or {"games": [...]}
            if isinstance(data, list):
                return [g for g in data if isinstance(g, dict)]
            if isinstance(data, dict):
                games = data.get("games")
                if isinstance(games, list):
                    return [g for g in games if isinstance(g, dict)]
                # Sometimes the CLI returns a dict keyed by id.
                vals = list(data.values())
                if vals and all(isinstance(v, dict) for v in vals):
                    return vals  # type: ignore[return-value]
            continue

        # Non-JSON output: can't reliably parse.
        continue

    return None


def _guess_lutris_db_path() -> Path:
    home = Path(os.path.expanduser("~"))
    return home / ".local" / "share" / "lutris" / "pga.db"


def _sql_tables(conn: sqlite3.Connection) -> List[str]:
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    return [r[0] for r in cur.fetchall() if isinstance(r[0], str)]


def _table_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.execute(f"PRAGMA table_info({table})")
    cols: List[str] = []
    for _cid, name, _type, _notnull, _dflt, _pk in cur.fetchall():
        if isinstance(name, str):
            cols.append(name)
    return cols


def _run_sqlite() -> Optional[List[Dict[str, Any]]]:
    """Return Lutris game list from local DB as a list of dicts, or None."""

    db = _guess_lutris_db_path()
    if not db.exists():
        return None

    try:
        conn = sqlite3.connect(str(db))
    except Exception:
        return None

    try:
        tables = _sql_tables(conn)
        if not tables:
            return None

        # Prefer 'games', otherwise choose a table containing 'game'.
        table = "games" if "games" in tables else None
        if not table:
            for t in tables:
                if "game" in t.lower():
                    table = t
                    break
        if not table:
            return None

        cols = _table_columns(conn, table)
        if not cols:
            return None

        wanted = [
            "id",
            "name",
            "slug",
            "runner",
            "platform",
            "installed",
            "is_installed",
            "directory",
            "configpath",
        ]
        select_cols = [c for c in wanted if c in cols]
        if not select_cols:
            # At least get id + name if possible.
            for c in ("id", "game_id"):
                if c in cols:
                    select_cols.append(c)
                    break
            if "name" in cols:
                select_cols.append("name")
            if not select_cols:
                return None

        sql = f"SELECT {', '.join(select_cols)} FROM {table}"
        cur = conn.execute(sql)
        rows = cur.fetchall()

        games: List[Dict[str, Any]] = []
        for row in rows:
            raw: Dict[str, Any] = {select_cols[i]: row[i] for i in range(len(select_cols))}

            # Normalize
            gid = raw.get("id")
            if gid is None:
                gid = raw.get("game_id")

            try:
                gid_i = int(gid)
            except Exception:
                continue

            name = str(raw.get("name") or f"Lutris Game {gid_i}")
            slug = str(raw.get("slug") or "")
            runner = str(raw.get("runner") or "")
            platform = str(raw.get("platform") or "")

            installed_val = raw.get("installed")
            if installed_val is None:
                installed_val = raw.get("is_installed")
            installed = bool(int(installed_val)) if installed_val is not None else True

            games.append(
                {
                    "id": gid_i,
                    "name": name,
                    "slug": slug,
                    "runner": runner,
                    "platform": platform,
                    "installed": installed,
                    "raw": raw,
                }
            )

        # Sort by name
        games.sort(key=lambda g: str(g.get("name", "")).casefold())
        return games

    finally:
        try:
            conn.close()
        except Exception:
            pass


def _write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    tmp.replace(path)


def generate() -> Dict[str, Any]:
    games_cli = _run_cli()
    if games_cli is not None:
        games: List[Dict[str, Any]] = []
        for g in games_cli:
            # Normalize some common keys.
            gid = g.get("id") or g.get("game_id")
            try:
                gid_i = int(gid)
            except Exception:
                continue

            name = str(g.get("name") or g.get("title") or f"Lutris Game {gid_i}")
            slug = str(g.get("slug") or "")
            runner = str(g.get("runner") or g.get("runner_name") or "")
            platform = str(g.get("platform") or g.get("platforms") or "")

            installed_val = g.get("installed")
            if installed_val is None:
                installed_val = g.get("is_installed")
            installed = bool(installed_val) if installed_val is not None else True

            games.append(
                {
                    "id": gid_i,
                    "name": name,
                    "slug": slug,
                    "runner": runner,
                    "platform": platform,
                    "installed": installed,
                    "raw": g,
                }
            )

        games.sort(key=lambda x: x["name"].casefold())
        return {"generated_at": _utc_iso(), "source": "cli", "games": games}

    games_sql = _run_sqlite()
    if games_sql is not None:
        return {"generated_at": _utc_iso(), "source": "sqlite", "games": games_sql}

    return {"generated_at": _utc_iso(), "source": "none", "games": []}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Path to write lutris_library.json")
    ap.add_argument("--once", action="store_true", help="Generate once and exit (default)")
    ap.add_argument("--watch", action="store_true", help="Poll and regenerate")
    ap.add_argument("--interval", type=float, default=3.0, help="Poll interval for --watch")
    args = ap.parse_args()

    out = Path(args.out).expanduser()

    def do_once() -> None:
        payload = generate()
        _write_json(out, payload)

    do_once()

    if not args.watch:
        return 0

    # Simple polling.
    while True:
        time.sleep(max(args.interval, 0.5))
        do_once()


if __name__ == "__main__":
    raise SystemExit(main())
