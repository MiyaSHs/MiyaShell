#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Prevent sourcing (sourcing can leave you inside python etc)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  echo "ERROR: Do not source this script. Run: bash scripts/install.sh" >&2
  return 1
fi

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
  # Run a command with args safely (no bash -c, no string eval)
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

PREFIX_DEFAULT="${HOME}/.local/share/miyashell"
BINDIR_DEFAULT="${HOME}/.local/bin"
APPS_DIR_DEFAULT="${HOME}/.local/share/applications"
SESSIONS_DIR_DEFAULT="${HOME}/.local/share/wayland-sessions"

install_deps_arch() {
  need_cmd pacman || die "pacman not found."
  have_sudo || die "sudo not found (install sudo or run as root)."

  say "==> Installing dependencies (Arch)..."

  # Use arrays to avoid line-continuation bugs / CRLF issues
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

  # Nerd font (best-effort)
  if pacman -Si ttf-cascadia-code-nerd >/dev/null 2>&1; then
    pkgs+=(ttf-cascadia-code-nerd)
  elif pacman -Si ttf-cascadia-code >/dev/null 2>&1; then
    pkgs+=(ttf-cascadia-code)
  else
    warn "No Cascadia/Nerd font package found via pacman. Install a Nerd Font later if desired."
  fi

  as_root pacman -Sy --needed --noconfirm "${pkgs[@]}"

  # Quickshell (repo or AUR)
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
    warn "No paru/yay found. Install quickshell manually, then rerun installer."
  fi

  need_cmd quickshell || warn "quickshell still missing. MiyaShell won't run until quickshell is installed."
}

install_deps_gentoo() {
  have_sudo || die "sudo not found (install sudo or run as root)."
  say "==> Gentoo deps install not implemented in this minimal script variant."
  say "Install: quickshell, gamescope, qt6 (declarative/wayland/multimedia), mpv, requests, mutagen, mangohud, libnotify, xprop, xdotool, nerd font."
}

install_deps() {
  case "$(detect_distro)" in
    arch|endeavouros|manjaro)
      install_deps_arch
      ;;
    gentoo)
      install_deps_gentoo
      ;;
    *)
      warn "Unknown distro. Skipping deps install."
      ;;
  esac
}

write_wrapper() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  # shellcheck disable=SC2129
  printf '%s\n' "$@" >>"$path"
  chmod +x "$path"
}

main() {
  say "==> MiyaShell installer"
  say "Project root: ${ROOT_DIR}"

  local PREFIX BINDIR APPS_DIR SESSIONS_DIR
  PREFIX="$(prompt "Install prefix" "${PREFIX_DEFAULT}")"
  BINDIR="$(prompt "Install bin dir" "${BINDIR_DEFAULT}")"
  APPS_DIR="$(prompt "Desktop entry dir" "${APPS_DIR_DEFAULT}")"
  SESSIONS_DIR="$(prompt "Wayland sessions dir" "${SESSIONS_DIR_DEFAULT}")"

  [[ -n "$PREFIX" ]] || die "PREFIX cannot be empty."
  [[ -n "$BINDIR" ]] || die "BINDIR cannot be empty."

  if prompt_yn "Install/update dependencies now?" "Y"; then
    install_deps
  fi

  say "==> Installing files to ${PREFIX}"
  mkdir -p "$PREFIX"

  if need_cmd rsync; then
    rsync -a --delete \
      --exclude ".git" \
      --exclude "node_modules" \
      --exclude "__pycache__" \
      "${ROOT_DIR}/" "${PREFIX}/"
  else
    warn "rsync not found; using cp -a fallback (won't delete old files)."
    cp -a "${ROOT_DIR}/." "${PREFIX}/"
  fi

  mkdir -p "$BINDIR" "$APPS_DIR" "$SESSIONS_DIR"

  # Ensure run scripts exist
  [[ -x "${PREFIX}/scripts/run-qs.sh" ]] || warn "Missing executable scripts/run-qs.sh (expected)."
  [[ -x "${PREFIX}/scripts/run-gamescope.sh" ]] || warn "Missing executable scripts/run-gamescope.sh (expected)."

  # Launchers
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

  # Desktop entries (no autologin / no autoboot)
  cat > "${APPS_DIR}/miyashell.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell
Comment=Controller-first launcher UI
Exec=${BINDIR}/miyashell
Terminal=false
Categories=Game;System;
EOF

  cat > "${APPS_DIR}/miyashell-gamemode-x11.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell (Game Mode • X11 games)
Comment=Gamescope session (compat-first)
Exec=${BINDIR}/miyashell-session-x11
Terminal=false
Categories=Game;System;
EOF

  cat > "${APPS_DIR}/miyashell-gamemode-wayland.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell (Game Mode • Wayland-first)
Comment=Gamescope session (Wayland-first Proton defaults)
Exec=${BINDIR}/miyashell-session-wayland
Terminal=false
Categories=Game;System;
EOF

  # Wayland session entries (for display managers)
  cat > "${SESSIONS_DIR}/miyashell-x11.desktop" <<EOF
[Desktop Entry]
Name=MiyaShell (X11 games)
Comment=Gamescope session (compat-first)
Exec=${BINDIR}/miyashell-session-x11
Type=Application
EOF

  cat > "${SESSIONS_DIR}/miyashell-wayland.desktop" <<EOF
[Desktop Entry]
Name=MiyaShell (Wayland-first)
Comment=Gamescope session (Wayland-first Proton defaults)
Exec=${BINDIR}/miyashell-session-wayland
Type=Application
EOF

  say ""
  say "✅ Installed!"
  say "Run in desktop:          ${BINDIR}/miyashell"
  say "Game Mode (X11 games):   ${BINDIR}/miyashell-session-x11"
  say "Game Mode (Wayland):     ${BINDIR}/miyashell-session-wayland"
  say "Desktop entries:         ${APPS_DIR}"
  say "Wayland sessions:        ${SESSIONS_DIR}"
  say ""
  say "Note: installer does NOT configure autologin/autoboot (by design)."
}

main "$@"
