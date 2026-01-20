#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# MiyaShell installer (Arch + Gentoo)
# - Installs deps (optional prompt)
# - Copies MiyaShell into ~/.local/share/miyashell (or custom)
# - Creates launchers in ~/.local/bin
# - Creates .desktop entries + wayland session entries (no autologin / no autoboot)
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

# Defaults (IMPORTANT: define before any use; fixes PREFIX "unbound variable")
PREFIX_DEFAULT="${HOME}/.local/share/miyashell"
BINDIR_DEFAULT="${HOME}/.local/bin"
APPS_DIR_DEFAULT="${HOME}/.local/share/applications"
SESSIONS_DIR_DEFAULT="${HOME}/.local/share/wayland-sessions"

say() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

prompt() {
  # prompt "Question" "default"
  local q="$1"
  local def="${2:-}"
  local ans
  if [[ -n "${def}" ]]; then
    read -r -p "${q} [${def}]: " ans || true
    echo "${ans:-$def}"
  else
    read -r -p "${q}: " ans || true
    echo "${ans}"
  fi
}

prompt_yn() {
  # prompt_yn "Question" "Y"
  local q="$1"
  local def="${2:-Y}"
  local ans
  read -r -p "${q} [${def}/n]: " ans || true
  ans="${ans:-$def}"
  [[ "${ans}" =~ ^[Yy]$ ]]
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
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi
  need_cmd sudo
}

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    bash -c "$*"
  else
    sudo bash -c "$*"
  fi
}

# -----------------------------------------------------------------------------
# Dependency installation
# -----------------------------------------------------------------------------

install_deps_arch() {
  say "==> Installing dependencies (Arch)..."
  need_cmd pacman || die "pacman not found."

  local pkgs=(
    # core
    gamescope
    mpv
    mangohud
    libnotify
    xorg-xprop
    xdotool
    python
    python-requests
    python-mutagen

    # Qt/Wayland
    qt6-base
    qt6-declarative
    qt6-wayland
    qt6-multimedia
    qt6-5compat
  )

  # Nerd font package name differs by repo setups; try a couple.
  local font_pkg=""
  if pacman -Si ttf-cascadia-code-nerd >/dev/null 2>&1; then
    font_pkg="ttf-cascadia-code-nerd"
  elif pacman -Si ttf-cascadia-code >/dev/null 2>&1; then
    font_pkg="ttf-cascadia-code"
  fi
  if [[ -n "${font_pkg}" ]]; then
    pkgs+=("${font_pkg}")
  else
    warn "Could not find a Cascadia/Nerd font package in pacman repos."
    warn "You can install a Nerd Font manually later (e.g. CaskaydiaCove Nerd Font)."
  fi

  as_root "pacman -Sy --needed --noconfirm ${pkgs[*]}"

  # Quickshell: might be in repos or AUR depending on setup.
  if need_cmd quickshell; then
    say "==> quickshell already installed."
    return 0
  fi

  # Try pacman first
  if pacman -Si quickshell >/dev/null 2>&1; then
    as_root "pacman -S --needed --noconfirm quickshell"
    return 0
  fi

  warn "quickshell not found in official repos on this system."
  warn "Install it via AUR (recommended): quickshell or quickshell-git"
  if need_cmd paru; then
    paru -S --needed --noconfirm quickshell-git || paru -S --needed --noconfirm quickshell || true
  elif need_cmd yay; then
    yay -S --needed --noconfirm quickshell-git || yay -S --needed --noconfirm quickshell || true
  else
    warn "No AUR helper (paru/yay) found. Install quickshell manually, then re-run install."
  fi

  need_cmd quickshell || warn "quickshell still not found. MiyaShell won't run until it's installed."
}

enable_guru_gentoo() {
  # Enables GURU overlay if not already enabled.
  need_cmd eselect || die "eselect not found (install app-eselect/eselect-repository)."
  if eselect repository list | grep -qE '^\s*\[.*\]\s+guru(\s|$)'; then
    say "==> GURU overlay already enabled."
    return 0
  fi

  say "==> Enabling GURU overlay (needed for gui-apps/quickshell, media-fonts/nerdfonts on many setups)..."
  as_root "eselect repository enable guru"
  if need_cmd emaint; then
    as_root "emaint sync -r guru"
  else
    warn "emaint not found; please sync overlays manually if needed."
  fi
}

install_deps_gentoo() {
  say "==> Installing dependencies (Gentoo)..."
  have_sudo || die "sudo is required (or run as root)."

  if prompt_yn "Enable/sync GURU overlay (recommended for quickshell + nerdfonts)?" "Y"; then
    enable_guru_gentoo
  fi

  local pkgs=(
    gui-apps/quickshell
    games-util/gamescope
    media-video/mpv
    games-util/mangohud
    x11-apps/xprop
    x11-misc/xdotool
    x11-libs/libnotify
    dev-python/requests
    dev-python/mutagen
    dev-qt/qtmultimedia:6
    dev-qt/qtdeclarative:6
    dev-qt/qtwayland:6
    dev-qt/qtbase:6
    media-fonts/nerdfonts
  )

  as_root "emerge -av --noreplace ${pkgs[*]}"
  need_cmd quickshell || warn "quickshell not found after emerge; check overlay/package availability."
}

install_deps() {
  local distro
  distro="$(detect_distro)"
  case "$distro" in
    arch|endeavouros|manjaro)
      install_deps_arch
      ;;
    gentoo)
      install_deps_gentoo
      ;;
    *)
      warn "Unknown distro ID: ${distro}. Skipping automated deps."
      warn "You must install: quickshell, gamescope, qt6 (declarative/wayland/multimedia), mpv, python-requests, python-mutagen, mangohud, libnotify, xprop, xdotool, and a Nerd Font."
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Install MiyaShell files + launchers
# -----------------------------------------------------------------------------

write_wrapper() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF
  printf '%s\n' "$content" >>"$path"
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

  [[ -n "${PREFIX}" ]] || die "PREFIX cannot be empty."
  [[ -n "${BINDIR}" ]] || die "BINDIR cannot be empty."

  if prompt_yn "Install/update dependencies now?" "Y"; then
    install_deps
  fi

  say "==> Installing MiyaShell files to: ${PREFIX}"
  mkdir -p "${PREFIX}"
  if need_cmd rsync; then
    rsync -a --delete \
      --exclude ".git" \
      --exclude "node_modules" \
      --exclude "__pycache__" \
      "${ROOT_DIR}/" "${PREFIX}/"
  else
    # Fallback: copy (won't delete old files)
    warn "rsync not found; using cp -a fallback."
    cp -a "${ROOT_DIR}/." "${PREFIX}/"
  fi

  # Ensure scripts are executable
  chmod +x "${PREFIX}/scripts/"*.sh 2>/dev/null || true
  chmod +x "${PREFIX}/backend/"*.py 2>/dev/null || true

  mkdir -p "${BINDIR}" "${APPS_DIR}" "${SESSIONS_DIR}"

  # Core launcher (runs in current session)
  write_wrapper "${BINDIR}/miyashell" "
export MIYASHELL_PREFIX=\"${PREFIX}\"
exec \"${PREFIX}/scripts/run-qs.sh\" \"\$@\"
"

  # Gamescope sessions
  write_wrapper "${BINDIR}/miyashell-session-x11" "
export MIYASHELL_PREFIX=\"${PREFIX}\"
# UI side: allow Qt to pick; most setups under gamescope end up Xwayland-friendly.
unset QT_QPA_PLATFORM || true
# Proton defaults (compat-first)
unset PROTON_USE_WAYLAND || true
unset PROTON_ENABLE_WAYLAND || true
exec \"${PREFIX}/scripts/run-gamescope.sh\" \"\$@\"
"

  write_wrapper "${BINDIR}/miyashell-session-wayland" "
export MIYASHELL_PREFIX=\"${PREFIX}\"
# Wayland-first policy
export QT_QPA_PLATFORM=wayland
export PROTON_USE_WAYLAND=1
export PROTON_ENABLE_WAYLAND=1
exec \"${PREFIX}/scripts/run-gamescope.sh\" \"\$@\"
"

  # Desktop entry: run in current desktop
  cat > "${APPS_DIR}/miyashell.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MiyaShell
Comment=Controller-first launcher UI
Exec=${BINDIR}/miyashell
Terminal=false
Categories=Game;System;
EOF

  # Desktop entries: Game Mode variants
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
  say "Run inside desktop:  ${BINDIR}/miyashell"
  say "Game Mode (X11):     ${BINDIR}/miyashell-session-x11"
  say "Game Mode (Wayland): ${BINDIR}/miyashell-session-wayland"
  say ""
  say "Desktop entries installed to: ${APPS_DIR}"
  say "Wayland sessions installed to: ${SESSIONS_DIR}"
  say ""
  say "Note: This installer does NOT enable autologin/autoboot (by design)."
}

main "$@"
