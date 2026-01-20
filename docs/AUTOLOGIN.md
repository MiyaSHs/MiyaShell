# Autologin into MiyaShell (optional)

The installer **does not** enable autologin or change your boot flow.

If you want a SteamOS-like experience where the device boots straight into MiyaShell (Gamescope session), you can configure autologin on `tty1` and then auto-start the session launcher.

`scripts/install.sh` installs:

- `~/.local/bin/miyashell` (runs MiyaShell inside your current desktop, no Gamescope)
- `~/.local/bin/miyashell-session-x11` (Gamescope session; default Proton/X11 games)
- `~/.local/bin/miyashell-session-wayland` (Gamescope session; exports `PROTON_USE_WAYLAND=1`)
- `~/.local/bin/miyashell-session` (compat symlink to `miyashell-session-x11`)

Pick **one** of the session launchers below depending on your preference.

## systemd (most distros, incl. Arch)

1) Create a getty override directory:

```bash
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
```

2) Copy the template from this repo and edit the username:

```bash
sudo cp contrib/systemd/getty@tty1-autologin.conf /etc/systemd/system/getty@tty1.service.d/autologin.conf
sudo $EDITOR /etc/systemd/system/getty@tty1.service.d/autologin.conf
```

3) Reload systemd:

```bash
sudo systemctl daemon-reload
sudo systemctl restart getty@tty1
```

4) Auto-start MiyaShell from your login shell profile (bash example):

Add this to `~/.bash_profile` (or `~/.zprofile` for zsh):

```bash
if [ "$(tty)" = "/dev/tty1" ] && [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
  # Choose one:
  # exec "$HOME/.local/bin/miyashell-session-x11"
  exec "$HOME/.local/bin/miyashell-session-wayland"
fi
```

## OpenRC (Gentoo)

1) Enable autologin for tty1 by editing `/etc/inittab`.

There is a snippet template at `contrib/openrc/inittab-snippet.txt`. Replace `__USER__` with your username.

2) Add the same `~/.bash_profile` (or `~/.zprofile`) snippet shown above so it starts MiyaShell automatically.

## Escape hatch

- Switch to another TTY: `Ctrl+Alt+F2` / `Ctrl+Alt+F3`, etc.
- If you get stuck in a boot loop, remove the `exec miyashell-session-*` block from your shell profile.
