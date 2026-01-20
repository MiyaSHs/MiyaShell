#!/usr/bin/env bash
set -euo pipefail

# MiyaShell installer (Gentoo + Arch)
#
# Goals:
# - Install runtime dependencies
# - Copy the repo into a user prefix (default: ~/.local/share/miyashell)
# - Install launchers:
#     - ~/.local/bin/miyashell          (UI-only, useful for dev)
#     - ~/.local/bin/miyashell-session  (Gamescope session, SteamOS-like)
# - Install a user-local .desktop entry (menu option). No auto-boot.
#
# This script is interactive and requires no flags.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PREFIX_DEFAULT="$HOME/.local/share/miyashell"
BIN_DIR_DEFAULT="$HOME/.local/bin"

say() { printf '\n%s\n' "$*"; }

confirm() {
  local prompt="$1"; local def="${2:-Y}"; local ans
  if [[ "$def" == "Y" ]]; then
    read -r -p "$prompt [Y/n]: " ans || true
    ans="${ans:-Y}"
  else
    read -r -p "$prompt [y/N]: " ans || true
    ans="${ans:-N}"
  fi
  [[ "$ans" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-}"
    return 0
  fi
  echo ""
}

install_files() {
  local prefix="$1"
  local bin_dir="$2"

  local xdg_apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  local xdg_sessions_dir="${XDG_DATA_HOME:-$HOME/.local/share}/wayland-sessions"

  mkdir -p "$prefix" "$bin_dir" "$xdg_apps_dir" "$xdg_sessions_dir"

  rsync -a --delete \
    --exclude '.git' \
    --exclude 'dist' \
    --exclude '*.tar.gz' \
    "$REPO_DIR/" "$prefix/"

  # UI-only launcher
  cat > "$bin_dir/miyashell" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PREFIX="${MIYASHELL_PREFIX:-$HOME/.local/share/miyashell}"

exec qs -p "$PREFIX"
EOF
  chmod +x "$bin_dir/miyashell"

  write_session() {
    local out="$1"
    local mode="$2"  # x11-games | wayland-first

    cat > "$out" <<EOF
#!/usr/bin/env bash
set -euo pipefail

PREFIX="${MIYASHELL_PREFIX:-$HOME/.local/share/miyashell}"

if ! command -v gamescope >/dev/null 2>&1; then
  echo "gamescope not found; starting MiyaShell without gamescope" >&2
  exec qs -p "$PREFIX"
fi

export MIYASHELL_SESSION_MODE="$mode"

# Prefer Wayland for the UI, but allow fallback to Xwayland if needed.
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"

if [[ "$mode" == "wayland-first" ]]; then
  # Proton experimental Wayland path.
  export MIYASHELL_WAYLAND_FIRST=1
  export PROTON_USE_WAYLAND=1
  export PROTON_ENABLE_WAYLAND=1
  # NTSYNC is kernel-dependent; Proton usually ignores this if unsupported.
  export PROTON_USE_NTSYNC="${PROTON_USE_NTSYNC:-1}"
  # A few common toolkits respect these.
  export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-wayland}"
  export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
else
  unset MIYASHELL_WAYLAND_FIRST
  unset PROTON_USE_WAYLAND
  unset PROTON_ENABLE_WAYLAND
fi

GS_FLAGS=()

# Prefer DRM backend if supported.
if gamescope --help 2>/dev/null | grep -q -- "--backend"; then
  GS_FLAGS+=(--backend drm)
fi

# Expose a Wayland socket to clients if supported (native Wayland apps / Proton experiments).
if gamescope --help 2>/dev/null | grep -q -- "--expose-wayland"; then
  GS_FLAGS+=(--expose-wayland)
fi

# Embedded mode if available; otherwise fall back to fullscreen.
if gamescope --help 2>/dev/null | grep -q -- " -e,"; then
  GS_FLAGS+=(-e)
else
  GS_FLAGS+=(-f)
fi

# Tag the UI as STEAM_GAME=769 where possible (SteamOS convention).
FG="$PREFIX/tools/gamescope-fg-lite"
if [[ -x "$FG" ]]; then
  exec gamescope "${GS_FLAGS[@]}" -- "$FG" --appid 769 --wait -- qs -p "$PREFIX"
else
  exec gamescope "${GS_FLAGS[@]}" -- qs -p "$PREFIX"
fi
EOF
    chmod +x "$out"
  }

  # Two session variants:
  # - x11-games: default Proton (Xwayland). UI still runs in Gamescope Wayland.
  # - wayland-first: exports PROTON_USE_WAYLAND=1 etc.
  write_session "$bin_dir/miyashell-session-x11" "x11-games"
  write_session "$bin_dir/miyashell-session-wayland" "wayland-first"

  # Backwards-compatible entrypoint
  ln -sf "$bin_dir/miyashell-session-x11" "$bin_dir/miyashell-session" >/dev/null 2>&1 || true

  write_app_desktop() {
    local out="$1"; local name="$2"; local exec_cmd="$3"; local comment="$4"
    cat > "$out" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$exec_cmd
Terminal=false
Categories=Game;
Icon=applications-games
StartupNotify=false
EOF
  }

  write_session_desktop() {
    local out="$1"; local name="$2"; local exec_cmd="$3"; local comment="$4"
    cat > "$out" <<EOF
[Desktop Entry]
Name=$name
Comment=$comment
Exec=$exec_cmd
Type=Application
DesktopNames=MiyaShell
EOF
  }

  # Desktop entries (menu)
  write_app_desktop "$xdg_apps_dir/miyashell-wayland.desktop" "MiyaShell (Game Mode • Wayland-first)" "$bin_dir/miyashell-session-wayland" "Handheld-friendly game UI (Gamescope session; PROTON_USE_WAYLAND=1)"
  write_app_desktop "$xdg_apps_dir/miyashell-x11.desktop" "MiyaShell (Game Mode • X11 games)" "$bin_dir/miyashell-session-x11" "Handheld-friendly game UI (Gamescope session; default Proton)"

  # Keep the original name as a stable launcher (defaults to X11 games).
  write_app_desktop "$xdg_apps_dir/miyashell.desktop" "MiyaShell (Game Mode)" "$bin_dir/miyashell-session-x11" "Handheld-friendly game UI (Gamescope session)"

  # Wayland session entries (display manager)
  write_session_desktop "$xdg_sessions_dir/miyashell-wayland.desktop" "MiyaShell (Gamescope • Wayland-first)" "$bin_dir/miyashell-session-wayland" "Start MiyaShell inside a Gamescope session (Wayland-first Proton)"
  write_session_desktop "$xdg_sessions_dir/miyashell-x11.desktop" "MiyaShell (Gamescope • X11 games)" "$bin_dir/miyashell-session-x11" "Start MiyaShell inside a Gamescope session (default Proton)"

  say "Installed MiyaShell to: $prefix"
  say "Launchers installed:"
  say " - $bin_dir/miyashell"
  say " - $bin_dir/miyashell-session-x11"
  say " - $bin_dir/miyashell-session-wayland"
  say "Desktop entries installed:"
  say " - $xdg_apps_dir/miyashell.desktop"
  say " - $xdg_apps_dir/miyashell-x11.desktop"
  say " - $xdg_apps_dir/miyashell-wayland.desktop"
  say "Wayland session entries installed:"
  say " - $xdg_sessions_dir/miyashell-x11.desktop"
  say " - $xdg_sessions_dir/miyashell-wayland.desktop"
}


install_arch_deps() {
  say "Installing dependencies for Arch Linux..."

  local pkgs=(
    gamescope
    mpv
    mangohud
    qt6-base
    qt6-declarative
    qt6-wayland
    qt6-svg
    qt6-multimedia
    qt6-5compat
    ttf-cascadia-code-nerd
    python
    python-requests
    python-mutagen
    xorg-xprop
    xdotool
    rsync
  )

  sudo pacman -S --needed --noconfirm "${pkgs[@]}"

  # Quickshell may not be in official repos; attempt repo package first.
  if ! pacman -Qi quickshell >/dev/null 2>&1; then
    say "Quickshell package not found in pacman database."
    say "You can install it from the AUR (recommended: quickshell or quickshell-git)."
    if confirm "Install quickshell from AUR using paru/yay?" Y; then
      if need_cmd paru; then
        paru -S --needed --noconfirm quickshell || paru -S --needed --noconfirm quickshell-git
      elif need_cmd yay; then
        yay -S --needed --noconfirm quickshell || yay -S --needed --noconfirm quickshell-git
      else
        say "No AUR helper (paru/yay) found. Install one, then run: paru -S quickshell"
      fi
    fi
  fi
}

install_gentoo_deps() {
  say "Installing dependencies for Gentoo..."

  if ! need_cmd emerge; then
    say "emerge not found. Are you on Gentoo?"
    return 1
  fi

  # Enable GURU overlay for quickshell.
  if confirm "Enable the GURU repository (needed for gui-apps/quickshell)?" Y; then
    if ! need_cmd eselect; then
      sudo emerge -av app-eselect/eselect
    fi
    if ! need_cmd eselect-repository; then
      sudo emerge -av app-eselect/eselect-repository
    fi
    sudo eselect repository enable guru || true
    sudo emaint sync -r guru || true
  fi

  sudo emerge -av \
    gui-apps/quickshell \
    dev-qt/qtbase:6 \
    dev-qt/qtdeclarative:6 \
    dev-qt/qtwayland:6 \
    dev-qt/qtsvg:6 \
    dev-qt/qtmultimedia:6 \
    dev-qt/qt5compat:6 \
    media-fonts/nerdfonts \
    games-util/gamescope \
    media-video/mpv \
    games-util/mangohud \
    dev-python/requests \
    dev-python/mutagen \
    x11-apps/xprop \
    x11-misc/xdotool \
    net-misc/rsync
}

install_optional_modules() {
  local distro="$1"

  if confirm "Install Steam (for Steam module)?" Y; then
    if [[ "$distro" == "gentoo" ]]; then
      sudo emerge -av games-util/steam-launcher || true
    else
      sudo pacman -S --needed --noconfirm steam
    fi
  fi

  if confirm "Install Lutris (for Lutris module)?" Y; then
    if [[ "$distro" == "gentoo" ]]; then
      sudo emerge -av games-util/lutris || true
    else
      sudo pacman -S --needed --noconfirm lutris
    fi
  fi
}

main() {
  say "=== MiyaShell installer ==="
  say "This will install dependencies + copy the UI locally for the current user."

  local distro
  distro="$(detect_distro)"

  local prefix="$PREFIX_DEFAULT"
  local bin_dir="$BIN_DIR_DEFAULT"

  read -r -p "Install prefix [$prefix]: " tmp || true
  if [[ -n "${tmp:-}" ]]; then prefix="$tmp"; fi

  read -r -p "Launcher bin dir [$bin_dir]: " tmp || true
  if [[ -n "${tmp:-}" ]]; then bin_dir="$tmp"; fi

  case "$distro" in
    arch|endeavouros|manjaro)
      install_arch_deps
      install_optional_modules "arch"
      ;;
    gentoo)
      install_gentoo_deps
      install_optional_modules "gentoo"
      ;;
    *)
      say "Unsupported distro ID: ${distro:-unknown}"
      say "Continuing with file installation only. You'll need to install dependencies manually."
      ;;
  esac

  install_files "$prefix" "$bin_dir"

  say "Next steps:"
  say " - Run MiyaShell as a session: $bin_dir/miyashell-session"
  say " - Or run UI-only (inside a normal desktop): $bin_dir/miyashell"
  say " - Optional autologin docs: $prefix/docs/AUTOLOGIN.md"
}

main "$@"
