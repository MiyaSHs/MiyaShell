#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

prompt() {
  local q="$1" def="${2:-}" ans=""
  if [[ -n "$def" ]]; then
    read -r -p "${q} [${def}]: " ans || true
    echo "${ans:-$def}"
  else
    read -r -p "${q}: " ans || true
    echo "${ans}"
  fi
}

prompt_yn() {
  local q="$1" def="${2:-Y}" ans=""
  read -r -p "${q} [${def}/n]: " ans || true
  ans="${ans:-$def}"
  [[ "$ans" =~ ^[Yy]$ ]]
}

detect_distro() {
  local id="unknown"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-unknown}"
  fi
  echo "$id"
}

have_sudo() {
  [[ "${EUID}" -eq 0 ]] && return 0
  need_cmd sudo
}

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# Dependency installation (Arch-focused; Gentoo users usually have their own flow)
# -----------------------------------------------------------------------------

install_deps_arch() {
  need_cmd pacman || die "pacman not found."
  have_sudo || die "sudo not found (install sudo or run as root)."

  say "==> Installing dependencies (Arch)..."

  local pkgs=(
    gamescope
    mpv
    mangohud
    libnotify
    xorg-xprop
    xdotool
    python
    python-requests
    python-mutagen
    qt6-base
    qt6-declarative
    qt6-wayland
    qt6-multimedia
    qt6-5compat
  )

  # Nerd font (best effort)
  if pacman -Si ttf-cascadia-code-nerd >/dev/null 2>&1; then
    pkgs+=(ttf-cascadia-code-nerd)
  elif pacman -Si ttf-cascadia-code >/dev/null 2>&1; then
    pkgs+=(ttf-cascadia-code)
  else
    warn "No Cascadia/Nerd font package found via pacman repos. Install Nerd Font manually if desired."
  fi

  as_root pacman -Sy --needed --noconfirm "${pkgs[@]}"

  # Quickshell
  if need_cmd quickshell; then
    say "==> quickshell already installed."
    return 0
  fi

  if pacman -Si quickshell >/dev/null 2>&1; then
    as_root pacman -S --needed --noconfirm quickshell
    return 0
  fi

  warn "quickshell not found in official repos on this system."
  warn "Install via AUR: quickshell or quickshell-git"
  if need_cmd paru; then
    paru -S --needed --noconfirm quickshell-git || paru -S --needed --noconfirm quickshell || true
  elif need_cmd yay; then
    yay -S --needed --noconfirm quickshell-git || yay -S --needed --noconfirm quickshell || true
  else
    warn "No AUR helper (paru/yay) found. Install quickshell manually, then rerun installer."
  fi

  need_cmd quickshell || warn "quickshell still missing. MiyaShell won't run until quickshell is installed."
}

install_deps() {
  case "$(detect_distro)" in
    arch|endeavouros|manjaro)
      install_deps_arch
      ;;
    *)
      warn "Unknown distro for automated deps. Install deps manually."
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Install files
# -----------------------------------------------------------------------------

write_wrapper() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  printf '%s\n' "$@" >>"$path"
  chmod +x "$path"
}

main() {
  say "==> MiyaShell installer"
  say "Project root: ${ROOT_DIR}"

  # System install is what you want for SDDM + global PATH.
  local want_system="N"
  if [[ "${EUID}" -eq 0 ]]; then
    want_system="Y"
  fi
  if prompt_yn "Install system-wide (recommended for SDDM & global PATH)?" "${want_system}"; then
    have_sudo || die "Need sudo (or run as root) for system install."

    # Defaults for SYSTEM install
    local PREFIX_DEFAULT="/opt/miyashell"
    local BINDIR_DEFAULT="/usr/local/bin"
    local APPS_DIR_DEFAULT="/usr/share/applications"
    local SESSIONS_DIR_DEFAULT="/usr/share/wayland-sessions"

    local PREFIX BINDIR APPS_DIR SESSIONS_DIR
    PREFIX="$(prompt "Install prefix" "${PREFIX_DEFAULT}")"
    BINDIR="$(prompt "Install bin dir" "${BINDIR_DEFAULT}")"
    APPS_DIR="$(prompt "Desktop entry dir" "${APPS_DIR_DEFAULT}")"
    SESSIONS_DIR="$(prompt "Wayland sessions dir (SDDM reads this)" "${SESSIONS_DIR_DEFAULT}")"

    if prompt_yn "Install/update dependencies now?" "Y"; then
      install_deps
    fi

    say "==> Copying MiyaShell to: ${PREFIX}"
    as_root mkdir -p "${PREFIX}"
    if need_cmd rsync; then
      as_root rsync -a --delete \
        --exclude ".git" \
        --exclude "node_modules" \
        --exclude "__pycache__" \
        "${ROOT_DIR}/" "${PREFIX}/"
    else
      warn "rsync not found; using cp -a fallback (won't delete old files)."
      as_root cp -a "${ROOT_DIR}/." "${PREFIX}/"
    fi

    # Ensure scripts are executable
    as_root chmod +x "${PREFIX}/scripts/"*.sh 2>/dev/null || true
    as_root chmod +x "${PREFIX}/backend/"*.py 2>/dev/null || true

    as_root mkdir -p "${BINDIR}" "${APPS_DIR}" "${SESSIONS_DIR}"

    # Global launchers (in /usr/local/bin)
    write_wrapper "/tmp/miyashell" \
      "export MIYASHELL_PREFIX=\"${PREFIX}\"" \
      "exec \"${PREFIX}/scripts/run-qs.sh\" \"\$@\""
    as_root install -m 0755 /tmp/miyashell "${BINDIR}/miyashell"

    write_wrapper "/tmp/miyashell-session-x11" \
      "export MIYASHELL_PREFIX=\"${PREFIX}\"" \
      "unset QT_QPA_PLATFORM || true" \
      "unset PROTON_USE_WAYLAND || true" \
      "unset PROTON_ENABLE_WAYLAND || true" \
      "exec \"${PREFIX}/scripts/run-gamescope.sh\" \"\$@\""
    as_root install -m 0755 /tmp/miyashell-session-x11 "${BINDIR}/miyashell-session-x11"

    write_wrapper "/tmp/miyashell-session-wayland" \
      "export MIYASHELL_PREFIX=\"${PREFIX}\"" \
      "export QT_QPA_PLATFORM=wayland" \
      "export PROTON_USE_WAYLAND=1" \
      "export PROTON_ENABLE_WAYLAND=1" \
      "exec \"${PREFIX}/scripts/run-gamescope.sh\" \"\$@\""
    as_root install -m 0755 /tmp/miyashell-session-wayland "${BINDIR}/miyashell-session-wayland"

    rm -f /tmp/miyashell /tmp/miyashell-session-x11 /tmp/miyashell-session-wayland

    # Desktop entries (global)
    cat > /tmp/miyashell.desktop <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell
Comment=Controller-first launcher UI
Exec=${BINDIR}/miyashell
Terminal=false
Categories=Game;System;
EOF
    as_root install -m 0644 /tmp/miyashell.desktop "${APPS_DIR}/miyashell.desktop"

    cat > /tmp/miyashell-gamemode-x11.desktop <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell (Game Mode • X11 games)
Comment=Gamescope session (compat-first)
Exec=${BINDIR}/miyashell-session-x11
Terminal=false
Categories=Game;System;
EOF
    as_root install -m 0644 /tmp/miyashell-gamemode-x11.desktop "${APPS_DIR}/miyashell-gamemode-x11.desktop"

    cat > /tmp/miyashell-gamemode-wayland.desktop <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell (Game Mode • Wayland-first)
Comment=Gamescope session (Wayland-first Proton defaults)
Exec=${BINDIR}/miyashell-session-wayland
Terminal=false
Categories=Game;System;
EOF
    as_root install -m 0644 /tmp/miyashell-gamemode-wayland.desktop "${APPS_DIR}/miyashell-gamemode-wayland.desktop"

    rm -f /tmp/miyashell*.desktop

    # Wayland sessions for SDDM (global)
    cat > /tmp/miyashell-x11.desktop <<EOF
[Desktop Entry]
Name=MiyaShell (X11 games)
Comment=Gamescope session (compat-first)
Exec=${BINDIR}/miyashell-session-x11
Type=Application
EOF
    as_root install -m 0644 /tmp/miyashell-x11.desktop "${SESSIONS_DIR}/miyashell-x11.desktop"

    cat > /tmp/miyashell-wayland.desktop <<EOF
[Desktop Entry]
Name=MiyaShell (Wayland-first)
Comment=Gamescope session (Wayland-first Proton defaults)
Exec=${BINDIR}/miyashell-session-wayland
Type=Application
EOF
    as_root install -m 0644 /tmp/miyashell-wayland.desktop "${SESSIONS_DIR}/miyashell-wayland.desktop"

    rm -f /tmp/miyashell-x11.desktop /tmp/miyashell-wayland.desktop

    say ""
    say "✅ System install complete."
    say "SDDM sessions installed to: ${SESSIONS_DIR}"
    say "Launchers installed to:     ${BINDIR}"
    say ""
    say "You should now see MiyaShell sessions in SDDM:"
    say "  - MiyaShell (X11 games)"
    say "  - MiyaShell (Wayland-first)"
    return 0
  fi

  # USER install fallback (still works, but SDDM may not show sessions)
  local PREFIX_DEFAULT="${HOME}/.local/share/miyashell"
  local BINDIR_DEFAULT="${HOME}/.local/bin"
  local APPS_DIR_DEFAULT="${HOME}/.local/share/applications"
  local SESSIONS_DIR_DEFAULT="${HOME}/.local/share/wayland-sessions"

  local PREFIX BINDIR APPS_DIR SESSIONS_DIR
  PREFIX="$(prompt "Install prefix" "${PREFIX_DEFAULT}")"
  BINDIR="$(prompt "Install bin dir" "${BINDIR_DEFAULT}")"
  APPS_DIR="$(prompt "Desktop entry dir" "${APPS_DIR_DEFAULT}")"
  SESSIONS_DIR="$(prompt "Wayland sessions dir" "${SESSIONS_DIR_DEFAULT}")"

  if prompt_yn "Install/update dependencies now?" "Y"; then
    install_deps
  fi

  mkdir -p "${PREFIX}" "${BINDIR}" "${APPS_DIR}" "${SESSIONS_DIR}"
  if need_cmd rsync; then
    rsync -a --delete \
      --exclude ".git" \
      --exclude "node_modules" \
      --exclude "__pycache__" \
      "${ROOT_DIR}/" "${PREFIX}/"
  else
    warn "rsync not found; using cp -a fallback."
    cp -a "${ROOT_DIR}/." "${PREFIX}/"
  fi

  chmod +x "${PREFIX}/scripts/"*.sh 2>/dev/null || true
  chmod +x "${PREFIX}/backend/"*.py 2>/dev/null || true

  write_wrapper "${BINDIR}/miyashell" \
    "export MIYASHELL_PREFIX=\"${PREFIX}\"" \
    "exec \"${PREFIX}/scripts/run-qs.sh\" \"\$@\""

  write_wrapper "${BINDIR}/miyashell-session-x11" \
    "export MIYASHELL_PREFIX=\"${PREFIX}\"" \
    "unset QT_QPA_PLATFORM || true" \
    "unset PROTON_USE_WAYLAND || true" \
    "unset PROTON_ENABLE_WAYLAND || true" \
    "exec \"${PREFIX}/scripts/run-gamescope.sh\" \"\$@\""

  write_wrapper "${BINDIR}/miyashell-session-wayland" \
    "export MIYASHELL_PREFIX=\"${PREFIX}\"" \
    "export QT_QPA_PLATFORM=wayland" \
    "export PROTON_USE_WAYLAND=1" \
    "export PROTON_ENABLE_WAYLAND=1" \
    "exec \"${PREFIX}/scripts/run-gamescope.sh\" \"\$@\""

  cat > "${APPS_DIR}/miyashell.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell
Exec=${BINDIR}/miyashell
Terminal=false
Categories=Game;System;
EOF

  say ""
  say "✅ User install complete."
  say "Note: SDDM might not show sessions from ~/.local."
  say "Launch manually: ${BINDIR}/miyashell-session-x11"
}

main "$@"
