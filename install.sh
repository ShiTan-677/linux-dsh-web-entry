#!/usr/bin/env bash
# Install (or remove) the DSH Web desktop entrance for the current user.
#
#   ./install.sh              install into ~/.local and the desktop directory
#   ./install.sh --uninstall  remove everything it installed
#
# Overrides:
#   DSH_WEB_PREFIX   install prefix for the launcher (default ~/.local)
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${DSH_WEB_PREFIX:-$HOME/.local}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$PREFIX/bin"
APP_DIR="$DATA_HOME/applications"
ICON_DIR="$DATA_HOME/icons"
LAUNCHER="$BIN_DIR/dsh-web-open.sh"
ICON_PATH="$ICON_DIR/dsh-web.svg"
ENTRY_NAME="dsh-web.desktop"
APP_ENTRY="$APP_DIR/$ENTRY_NAME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dsh-web"

desktop_dir() {
  if command -v xdg-user-dir >/dev/null 2>&1; then
    xdg-user-dir DESKTOP 2>/dev/null || printf '%s\n' "$HOME/Desktop"
  else
    printf '%s\n' "$HOME/Desktop"
  fi
}
DESKTOP_DIR="${DSH_WEB_DESKTOP_DIR:-$(desktop_dir)}"
DESKTOP_ENTRY="$DESKTOP_DIR/$ENTRY_NAME"

render_entry() {
  sed -e "s|__EXEC__|$LAUNCHER|" -e "s|__ICON__|$1|" "$REPO_DIR/share/dsh-web.desktop.in"
}

install_all() {
  mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR" "$DESKTOP_DIR"
  install -m 0755 "$REPO_DIR/bin/dsh-web-open.sh" "$LAUNCHER"

  local icon="$ICON_PATH"
  if command -v python3 >/dev/null 2>&1 &&
    python3 "$REPO_DIR/tools/compose-icon.py" --output "$ICON_PATH"; then
    :
  else
    rm -f "$ICON_PATH"
    icon="web-browser"
    printf 'install: icon composition unavailable, falling back to the %s theme icon\n' "$icon" >&2
  fi

  render_entry "$icon" >"$APP_ENTRY"
  chmod 0644 "$APP_ENTRY"
  render_entry "$icon" >"$DESKTOP_ENTRY"
  chmod 0755 "$DESKTOP_ENTRY"

  # A launcher on the desktop has to be marked trusted before the file manager
  # will run it, and only the metadata service knows that.
  if command -v gio >/dev/null 2>&1; then
    gio set -t string "$DESKTOP_ENTRY" metadata::trusted true >/dev/null 2>&1 || true
  fi
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
  command -v gtk-update-icon-cache >/dev/null 2>&1 &&
    gtk-update-icon-cache -f -t "$ICON_DIR" >/dev/null 2>&1 || true

  cat <<EOF
installed:
  launcher   $LAUNCHER
  app entry  $APP_ENTRY
  desktop    $DESKTOP_ENTRY
  icon       $icon

Double-click "DSH Web" on the desktop (or launch it from Activities).
The launcher opens a running server, and starts one in a terminal window when
none is listening. Remove everything with: $REPO_DIR/install.sh --uninstall
EOF
}

uninstall_all() {
  local removed=0 target
  for target in "$DESKTOP_ENTRY" "$APP_ENTRY" "$LAUNCHER" "$ICON_PATH"; do
    if [ -e "$target" ]; then
      rm -f "$target"
      printf 'removed: %s\n' "$target"
      removed=1
    fi
  done
  command -v update-desktop-database >/dev/null 2>&1 &&
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
  [ "$removed" = 1 ] || printf 'nothing to remove\n'
  printf 'kept: %s (start logs; remove by hand if you want)\n' "$STATE_DIR"
}

case "${1:-}" in
  --uninstall) uninstall_all ;;
  "" | --install) install_all ;;
  *)
    printf 'usage: %s [--install|--uninstall]\n' "$0" >&2
    exit 2
    ;;
esac
