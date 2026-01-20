#!/usr/bin/env python3
"""gamescope_ctl.py

A tiny helper to control a running gamescope session.

gamescope exposes several runtime controls via X11 atoms on the Xwayland root
window. Projects like OpenGamepadUI use these atoms to implement Deck-like
"Quick Access" controls (FPS limit, scaling, blur, etc.).

This helper intentionally does not depend on python-xlib; it shells out to xprop.

IMPORTANT:
- This requires an Xwayland DISPLAY.
- Atom names vary between gamescope forks/versions. Treat as best-effort.

Examples:
  gamescope_ctl.py set-fps 40
  gamescope_ctl.py set-scaler fsr
  gamescope_ctl.py set-fsr-sharpness 2

"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from typing import List


def _run(cmd: List[str]) -> int:
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
    return proc.returncode


def _xprop_root(args: List[str]) -> int:
    # Keep env; rely on DISPLAY.
    if not os.environ.get("DISPLAY"):
        sys.stderr.write("gamescope_ctl: DISPLAY is not set (need Xwayland)\n")
        return 2
    return _run(["xprop", "-root"] + args)


def _set_u32(atom: str, value: int) -> int:
    # 32-bit cardinal
    return _xprop_root(["-f", atom, "32c", "-set", atom, str(int(value))])


def _set_str(atom: str, value: str) -> int:
    return _xprop_root(["-f", atom, "8s", "-set", atom, value])


def _remove(atom: str) -> int:
    return _xprop_root(["-remove", atom])


def cmd_set_fps(limit: int) -> int:
    atom = "GAMESCOPE_FPS_LIMIT"
    if limit <= 0:
        return _remove(atom)
    return _set_u32(atom, limit)


def cmd_set_scaler(mode: str) -> int:
    """Set scaler mode.

    Known modes used by some forks:
      - auto
      - fsr
      - nis
      - integer

    We write a string atom. gamescope may ignore unknown values.
    """
    atom = "GAMESCOPE_SCALER"
    return _set_str(atom, mode)


def cmd_set_fsr(enabled: bool) -> int:
    # Some versions use a scaler string; others expose a bool atom.
    # We set both to be safe.
    rc1 = cmd_set_scaler("fsr" if enabled else "auto")
    rc2 = _set_u32("GAMESCOPE_FSR", 1 if enabled else 0)
    return rc1 if rc1 != 0 else rc2


def cmd_set_fsr_sharpness(sharpness: int) -> int:
    return _set_u32("GAMESCOPE_FSR_SHARPNESS", sharpness)


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("set-fps")
    p.add_argument("limit", type=int, help="FPS limit (0 = uncapped)")

    p = sub.add_parser("set-scaler")
    p.add_argument("mode", choices=["auto", "fsr", "nis", "integer"], help="Scaling mode")

    p = sub.add_parser("set-fsr")
    p.add_argument("enabled", choices=["0", "1"], help="0/1")

    p = sub.add_parser("set-fsr-sharpness")
    p.add_argument("sharpness", type=int, help="FSR sharpness (int)")

    args = ap.parse_args()

    if args.cmd == "set-fps":
        return cmd_set_fps(args.limit)
    if args.cmd == "set-scaler":
        return cmd_set_scaler(args.mode)
    if args.cmd == "set-fsr":
        return cmd_set_fsr(args.enabled == "1")
    if args.cmd == "set-fsr-sharpness":
        return cmd_set_fsr_sharpness(args.sharpness)

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
