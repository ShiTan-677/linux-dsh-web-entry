# Validation record

What was verified for 0.1.0 and 0.1.1, how, and what remains unverified. Written from the session that
built and installed the shell surface on 2026-10-14.

## Environment

| Item | Value |
| --- | --- |
| OS / desktop | Ubuntu 22.04, GNOME Shell 42.9, Wayland |
| Desktop icons | `ding@rastersoft.com` (Desktop Icons NG), state ENABLED |
| Default browser | `com.google.Chrome.desktop` (Google Chrome) |
| Terminal | `gnome-terminal` |
| Node | v24.21.0 via nvm (`~/.nvm/nvm.sh`) |
| DSH | `@deepseek-ai/dsh@0.2.0-rc.2`, launched as `npx @deepseek-ai/dsh web` |
| Web port | 3080, bound to 127.0.0.1 |

Mechanism facts below were read out of the installed packages, not assumed:

| Fact | Source |
| --- | --- |
| Port default 3080, overridable by `--port` | `dsh-web-app/cordis.patch.yml` (`port: !!js ctx.webStartup.port ?? 3080`), `dsh-web-app/lib/startup.js` |
| `--no-open` suppresses the built-in browser handoff | `dsh-web-app/lib/startup.js` |
| Root requests need a per-process token; the token becomes a signed cookie bound to the request authority | `dsh-client-connection/lib/index.js` (`TOKEN_QUERY`, `BrowserAuth`, `cookieName`, `signature`) |
| Cookie name is `dsh-auth-` + base64url(sha256(authority)) | `dsh-client-connection/lib/index.js` (`COOKIE_PREFIX`, `cookieName`) |
| The signing secret is persistent, so cookies survive server restarts | `initializeSecret` + `credentials.modifyRecord(AUTH_RECORD_KEY)` |

## Verified

| Claim | Evidence |
| --- | --- |
| `tools/selftest.sh` passes | 41/41 checks, exit 0. Covers: `200` and `401` stub servers, the real `wait_for_token` against the exact console shape, the `--serve` argv and `tee` against a stub `dsh`, the systemd start path against stub `systemctl`/`journalctl`, the no-user-manager fallback, sandboxed install/uninstall, and `systemd-analyze verify` on the generated unit |
| The start lock does not outlive the launcher | Regression checks spawn a browser and a terminal while fd 9 is locked and assert neither child inherits a copy of it, and that `flock` on `start.lock` succeeds once the launcher exits |
| A launcher that loses the lock race leaves the log intact | With the lock held and a pre-seeded `launch.log`, the second launcher reports the wait while the token line survives the run |
| A running server is opened without being touched | Launcher run against the live server printed `server on port 3080 is up (HTTP 401); opening the GUI` and exited 0 |
| The GUI really opened in Chrome | Chrome history (read-only copy of the profile database) shows `http://127.0.0.1:3080/` with its last visit at `2026-10-14 20:47:23` local — the moment of the launcher run |
| The clean URL is authenticated in the user's profile | Chrome cookie store (read-only copy, names/metadata only, values not read) holds `dsh-auth-VPhEEcLKeqRDBoBalzN2Nm7CnfxKhLE00pKIDWxt1sw` for host `127.0.0.1`, path `/`, `HttpOnly`, expiring `2026-11-12` (≈30 days). The name was recomputed from the algorithm above and matched |
| The desktop icon is launchable | `~/Desktop/dsh-web.desktop` is mode 0755, `gio info` reports `metadata::trusted: true` — DING refuses to launch a `.desktop` without it (`fileItem.js:227`, `desktopIconItem.js:648`) — and `desktop-file-validate` reports no errors |
| The icon renders | Composed SVG is well-formed, 128×128, generated from the installed `dsh-web-frontend/dist/favicon-dark.svg`; `libpixbufloader-svg.so` is present, so the absolute `Icon=` path resolves |
| The unit file is valid | `systemd-analyze verify` accepts the rendered `dsh-web.service` with no output |
| The plugin surface's contract still holds | `dsh-web-open.sh --status` asserted to print exactly `200` / `401` / `000`; `install.sh` with no arguments and `--uninstall` unchanged |
| `dsh-web-open.sh` also works from the CLI | `--status` against the live server returned `401` (no cookie from a non-browser client), matching the design |

## 0.1.1 addendum — the leaked start lock (2026-11-14)

The 0.1.0 launcher leaked its `flock` descriptor into the browser it spawned. That only
shows up on a launch that starts a server (the lock is held across `wait_for_token`, and
the browser is spawned before the launcher exits). On the real desktop the lock file was
still held long after every launcher had exited:

- `fuser -v ~/.local/state/dsh-web/start.lock` reported a leftover `chrome` process;
- a non-blocking `flock` on the file failed with `EWOULDBLOCK`;
- a second launcher printed `another launcher is already starting the server` and then
  timed out after 60 s, because the first launcher's shared `launch.log` had already been
  truncated by the second one before it took (or lost) the lock.

Verified for 0.1.1 on this desktop (2026-11-14; DSH `0.2.2-rc.1`, Node v24.21.0):

| Claim | Evidence |
| --- | --- |
| `tools/selftest.sh` passes | 41/41 checks, exit 0 (was 36/36) |
| Spawned children inherit no lock fd | New checks lock fd 9 in the launcher's context, spawn the stub browser and the stub terminal, and read `/proc/<pid>/fd/9` in each child: `clean` |
| The lock is released on exit | With the children still alive, `flock -n start.lock` succeeds after the launcher exits |
| A waiting launcher keeps the log | The lock holder keeps `launch.log` with a seeded token line; the second launcher reports the wait and the line survives |
| The suite stays hermetic with a unit installed | `run_launcher()` pins `DSH_WEB_SYSTEMD_UNIT_FILE` to a nonexistent path, so installing the real unit cannot reroute the dry-run cases into systemd mode |

## Not verified

| Item | Reason | How to check |
| --- | --- | --- |
| `systemctl --user enable --now` and login autostart | The validating shell cannot reach the user manager: `systemctl --user list-units` → `Failed to connect to bus: No data available`. systemd mode was therefore exercised through stub binaries plus `systemd-analyze verify`, not against a real user bus | Run `./install.sh --systemd` from a desktop terminal, then `systemctl --user status dsh-web` |
| First click with no server running (terminal mode) | A second live `dsh web` would contend for the shared `~/.dsh` profile files, so only the dry-run spawn command and the token parsing were asserted | Stop the running server, then double-click the icon |
| The GUI window itself | No screenshot path in the validating environment; the window is inferred from the Chrome history row and the valid cookie | Visual check on first use |
| Non-GNOME terminals, non-Chrome browsers, X11, other distributions | Out of scope for 0.1.0; `gnome-terminal` then `x-terminal-emulator`, and `google-chrome --app` then `xdg-open`, are the paths implemented | — |

## Reproduce

```sh
git clone https://github.com/ShiTan-677/linux-dsh-web-entry
cd linux-dsh-web-entry
tools/selftest.sh          # 41 checks, no side effects on the real desktop
./install.sh               # then double-click "DSH Web"
```

Note for agents: the validating session ran inside a DSH sandbox whose file policy allows
writes only under the session workspace, so installing to `~/.local` and `~/Desktop` required
an explicit escalation. The self-test itself needs no escalation.

## Known limits

- The browser cookie lives about 30 days. If it expires while a manually started server is
  running, the launcher must not restart that server; it opens the window and sends a
  notification asking for a restart of `dsh web`, which mints a fresh token URL.
- The cookie is bound to `host:port`. Changing `DSH_WEB_PORT` requires one fresh login
  through the printed token URL.
- The GUI is loopback-only by design (`--host 0.0.0.0` is rejected by `dsh web`), and this
  tool does not add any remote-access path.
