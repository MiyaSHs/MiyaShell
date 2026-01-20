#!/usr/bin/env python3
"""steam_friends.py

Best-effort Steam friends list for a custom game-mode shell.

Steam does not offer an official local IPC API for friends/chat that is stable
for third-party clients. The officially documented way to fetch friends
presence is the Steam Web API.

This script is intentionally dependency-free.

Config (either is fine):
  - CLI args: --api-key, --steamid
  - Env vars: STEAM_API_KEY, STEAM_ID64

If missing, we still write a valid JSON file with an error field
so the UI can show a friendly message and provide an "Open Steam Friends" button.

Output schema:
{
  "generated_at": "...Z",
  "source": "webapi" | "none",
  "error": "..." | "",
  "friends": [
     {
       "provider": "steam",
       "steamid": "7656...",
       "name": "...",
       "avatar": "https://...",
       "persona_state": 1,
       "status": "online" | "offline" | "busy" | "away" | "snooze" | "looking_to_trade" | "looking_to_play",
       "game_name": "...",
       "game_id": "...",
       "server_ip": "1.2.3.4:27015",
       "lobby_id": "1097752..."
     }
  ]
}
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from typing import Any, Dict, List, Tuple


def _utc_iso() -> str:
    return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def _http_json(url: str) -> Dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": "miyashell/0.1"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = resp.read().decode("utf-8", errors="replace")
    return json.loads(data)


_STATE = {
    0: "offline",
    1: "online",
    2: "busy",
    3: "away",
    4: "snooze",
    5: "looking_to_trade",
    6: "looking_to_play",
}


def _s(x: Any) -> str:
    if x is None:
        return ""
    return str(x)


def fetch_friends(api_key: str, steamid64: str) -> List[Dict[str, Any]]:
    base = "https://api.steampowered.com"

    # 1) Friend list
    url1 = (
        base
        + "/ISteamUser/GetFriendList/v0001/?"
        + urllib.parse.urlencode(
            {
                "key": api_key,
                "steamid": steamid64,
                "relationship": "friend",
            }
        )
    )
    j1 = _http_json(url1)
    fl = j1.get("friendslist", {}).get("friends", [])
    ids = [f.get("steamid") for f in fl if isinstance(f, dict) and f.get("steamid")]
    ids = [i for i in ids if isinstance(i, str)]

    if not ids:
        return []

    # 2) Summaries (presence, avatar, game)
    url2 = (
        base
        + "/ISteamUser/GetPlayerSummaries/v0002/?"
        + urllib.parse.urlencode({"key": api_key, "steamids": ",".join(ids)})
    )
    j2 = _http_json(url2)
    players = j2.get("response", {}).get("players", [])

    out: List[Dict[str, Any]] = []
    for p in players:
        if not isinstance(p, dict):
            continue
        sid = p.get("steamid")
        if not sid:
            continue

        state = int(p.get("personastate", 0) or 0)
        gameserverip = _s(p.get("gameserverip"))
        if gameserverip == "0.0.0.0:0":
            gameserverip = ""

        out.append(
            {
                "provider": "steam",
                "steamid": _s(sid),
                "name": _s(p.get("personaname")),
                "avatar": _s(p.get("avatarfull") or p.get("avatarmedium") or p.get("avatar")),
                "persona_state": state,
                "status": _STATE.get(state, "offline"),
                "game_name": _s(p.get("gameextrainfo")),
                "game_id": _s(p.get("gameid")) if p.get("gameid") else "",
                # join helpers (best-effort)
                "server_ip": gameserverip,
                "server_steamid": _s(p.get("gameserversteamid")) if p.get("gameserversteamid") else "",
                "lobby_id": _s(p.get("lobbysteamid")) if p.get("lobbysteamid") else "",
            }
        )

    # Sort: online first, then alphabetical
    out.sort(key=lambda x: (0 if x.get("persona_state", 0) else 1, (x.get("name") or "").lower()))
    return out


def write_json(path: str, payload: Dict[str, Any]) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def _resolve_creds(cli_api: str, cli_sid: str) -> Tuple[str, str]:
    api_key = (cli_api or "").strip() or os.environ.get("STEAM_API_KEY", "").strip()
    sid64 = (cli_sid or "").strip() or os.environ.get("STEAM_ID64", "").strip()
    return api_key, sid64


def run_once(out_path: str, cli_api: str, cli_sid: str) -> None:
    api_key, sid64 = _resolve_creds(cli_api, cli_sid)

    payload: Dict[str, Any] = {
        "generated_at": _utc_iso(),
        "source": "none",
        "error": "",
        "friends": [],
    }

    if not api_key or not sid64:
        payload["error"] = "Missing Steam Web API credentials (steamApiKey / steamId64)."
        write_json(out_path, payload)
        return

    try:
        friends = fetch_friends(api_key, sid64)
        payload["source"] = "webapi"
        payload["friends"] = friends
        write_json(out_path, payload)
    except Exception as e:
        payload["error"] = f"Steam Web API failed: {e.__class__.__name__}: {e}"
        write_json(out_path, payload)


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--api-key", default="")
    ap.add_argument("--steamid", default="")
    ap.add_argument("--watch", action="store_true")
    ap.add_argument("--interval", type=float, default=10.0)
    args = ap.parse_args(argv)

    if not args.watch:
        run_once(args.out, args.api_key, args.steamid)
        return 0

    while True:
        run_once(args.out, args.api_key, args.steamid)
        time.sleep(max(1.0, float(args.interval)))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
