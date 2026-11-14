# Changelog

## 0.1.3 — 2026-11-14 (patch)

- 0.1.2's custom-directory guard was not enough. It compared the configured unit
  directory with the (possibly redirected) default, so a caller that redirects
  `XDG_CONFIG_HOME` **and** `DSH_WEB_SYSTEMD_UNIT_DIR` into one sandbox — the plugin
  surface's self-test does exactly that — still reached the live user manager, which
  resolves the unit by name over D-Bus. Add `DSH_WEB_NO_USER_MANAGER=1`: the installer
  then reports the unit as installed but never asks the manager. The plugin surface's
  self-test sets it.
- `tools/selftest.sh`: 46 checks (was 43). The new checks pin the opt-out with aligned
  paths and a working stub manager: only the opt-out keeps the manager call count at zero,
  and the skip is reported.

## 0.1.2 — 2026-11-14 (patch)

- Guard `remove_systemd_unit()` the same way `install_systemd_unit()` is guarded: with a
  custom `DSH_WEB_SYSTEMD_UNIT_DIR`, uninstall no longer asks the live user manager, so
  `systemctl --user disable --now` can no longer act on a same-named unit in the standard
  directory. Found by running the plugin surface's self-test on a desktop where
  `dsh-web.service` was enabled: every run silently flipped it to `disabled`.
- `tools/selftest.sh`: 43 checks (was 41). A stub `systemctl` on `PATH` records what a
  custom-directory uninstall asks the user manager; the answer must be nothing, and the
  skip is reported to the caller.

## 0.1.1 — 2026-11-14 (patch)

- Fix the launcher leaking its start lock into long-lived children: the detached browser
  inherited the `flock` descriptor (fd 9), so the lock stayed held for the life of the
  window and later launches waited for a token that could never appear. All spawned
  children now close fd 9, and `--serve` drops an inherited lock before starting the
  server.
- Fix two launchers racing over one log: the shared log is truncated only after the start
  lock is taken, so a launcher that lost the race can no longer delete the token line the
  winner is waiting for. The timeout message now names the stale-lock remedy.
- `tools/selftest.sh`: 41 checks (was 36). The additions cover the descriptor leak for the
  browser and the terminal, the lock release when the launcher exits, and a waiting
  launcher leaving the shared log intact. `run_launcher()` pins
  `DSH_WEB_SYSTEMD_UNIT_FILE`, so the suite stays hermetic once a unit is installed.

## 0.1.0 — 2026-10-14 (public preview)

- Add a one-click Linux desktop entrance for the DeepSeek Harness Web GUI: an XDG desktop
  file plus a launcher that probes the port, opens a running server, and starts `dsh web`
  in a terminal window when nothing is listening.
- Recover the per-process launch token from the server console (terminal mode) so the GUI
  opens authenticated even on a browser profile that has no signed cookie yet.
- Add an opt-in `install.sh --systemd` mode: a generated `systemd --user` unit starts the
  server at login, and the launcher then reads the token back out of journald instead of
  opening a terminal window.
- Compose the desktop icon from the locally installed DSH frontend favicon, so no
  third-party artwork is vendored and the icon follows the installed DSH version.
- Ship `tools/selftest.sh`: 36 checks over loopback stub servers, a stub `dsh`, stub
  `systemctl`/`journalctl`, and a sandboxed install/uninstall. `docs/VALIDATION.md`
  records what was and was not exercised on the real desktop.
- Scope the project to Linux: the launcher depends on XDG desktop files, `xdg-open`, and a
  Linux terminal emulator.
