# DSH Web desktop entrance

A one-click entrance to the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)
Web GUI on Linux desktops: a launcher icon that opens the GUI in a browser app
window, and starts `dsh web` in a terminal window when the server is not running
yet.

```
double-click "DSH Web"
  ├─ server already listening on 127.0.0.1:3080 → open the GUI
  └─ nothing listening                          → start `dsh web` in a terminal
                                                  window, then open the GUI
```

The launcher **never restarts or stops a server that is already running**, so it
is safe to use while a DSH session is live.

## Why a launcher script instead of a browser bookmark

`dsh web` protects the GUI with a per-process launch token: a bare request to
`http://127.0.0.1:3080/` answers `401 dsh web authentication required`. Only the
URL printed at startup — `http://127.0.0.1:3080/?token=…` — exchanges that token
for a signed browser cookie.

That cookie is issued with a signing secret persisted in
`$DSH_HOME/.credentials.yaml` and bound to the request authority, so it survives
server restarts and a plain `http://127.0.0.1:3080/` keeps working until the
cookie expires. The token itself is random per process and is never written to
disk, which is why the launcher reads it out of the server console (tee'd to a
log) instead of trying to construct it.

## Requirements

- Linux with a desktop entry spec compliant launcher (tested on Ubuntu 22.04 /
  GNOME 42, Wayland).
- `dsh` on `PATH`, or `npx`, or an existing `~/.npm/_npx/*` cache install of
  `@deepseek-ai/dsh` — the launcher picks the first one it finds, preferring
  the resolved npx cache so it works offline.
- `curl` (falls back to bash `/dev/tcp` when missing), `notify-send` and `gio`
  for notifications and the trusted-launcher flag (both optional).
- A Chromium-family browser for the app window; falls back to `xdg-open`.

## Install

```sh
./install.sh              # install for the current user
./install.sh --uninstall  # remove everything it installed
```

No root is required. The installer writes:

| Path | What |
| --- | --- |
| `~/.local/bin/dsh-web-open.sh` | the launcher |
| `~/.local/share/applications/dsh-web.desktop` | Activities / app menu entry |
| `~/Desktop/dsh-web.desktop` | the desktop icon (marked trusted via `gio`) |
| `~/.local/share/icons/dsh-web.svg` | icon: the Harness glyph on an app tile |

The icon is composed at install time from the `dsh-web-frontend` favicon inside
your own DSH installation, so no third-party artwork is vendored in this repo
and the icon tracks whatever DSH version you run.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `DSH_WEB_PORT` | `3080` | Port the launcher probes and passes to `dsh web` |
| `DSH_WEB_BROWSER` | `google-chrome` | Browser used for the `--app` window |
| `DSH_WEB_START_TIMEOUT` | `60` | Seconds to wait for the token URL |
| `DSH_WEB_DRY_RUN` | `0` | `1` prints the planned actions instead of doing them |
| `DSH_WEB_PREFIX` | `~/.local` | Install prefix (installer) |
| `DSH_WEB_DESKTOP_DIR` | XDG desktop dir | Where the desktop icon is copied (installer) |

`dsh-web-open.sh` also accepts `--status` (print the HTTP status of the running
server) and `--help`.

Logs from the most recent start live in `~/.local/state/dsh-web/launch.log`.

## Tests

```sh
tools/selftest.sh
```

The self-test runs the launcher against loopback stub servers that answer `200`
and `401`, exercises the start path in dry-run mode, and installs into a
temporary prefix to check rendering and uninstall. It touches nothing in your
real desktop or DSH home.

## Deliberately not included

- **Login autostart.** Keeping a server resident is a resource decision, not a
  convenience one; the launcher already starts one on demand. A `systemd --user`
  unit would be the natural home for it if that trade-off ever changes.
- **Non-GNOME terminals.** `gnome-terminal` is tried first, then
  `x-terminal-emulator`; other emulators need their own invocation.
