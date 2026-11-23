# sezeni – saving and restoring window sessions in niri

[Čeština](niri-sezeni.md) | **English**

("sezeni" is Czech for "session".) The script saves open windows (command, working directory,
output, workspace, floating/tiled mode, size and position) to a file and can launch and arrange
them again. Only kitty, zen and notes (`cz.poznamka.view`) windows are saved; others
(noctalia, kando, kitty-float dictionaries…) are ignored.

## Quick usage

```sh
sezeni -a            # asks for a name and saves the current session
sezeni -n            # restores the default session (last saved)
sezeni -n prace      # restores the session "prace"
sezeni -l            # list sessions (* = default)
sezeni -v prace      # makes "prace" the default
```

The default session is restored automatically when niri starts – in `~/.config/niri/config.kdl`:

```kdl
spawn-sh-at-startup "~/.local/bin/sezeni -n"
```

(Kitty, zen-browser and notes used to be started directly there; now they are restored from
the session.)

## Files

- Script: `dotfiles/sezeni/.local/bin/sezeni` → `~/.local/bin/sezeni` (stow)
- Sessions: `~/.config/niri/sezeni/<name>.json`
- Default session: symlink `~/.config/niri/sezeni/vychozi.json` – after every `sezeni -a` it
  points to the session just saved; change it with `sezeni -v`.

## Options / configuration (at the top of the script)

- `POVOLENE_APP_ID` – regex of app-ids that are saved (`^(kitty|zen|cz\.poznamka\.view)$`).
  Add other applications here.
- `UKLADANE_PROMENNE` – whitelist of environment variables saved if they differ from niri's
  environment (e.g. `POZNAMKA_ZOOM=1.5`). The full environment is deliberately not saved because
  it contains secret keys and tokens.
- `TIMEOUT_OKNA` (30 s) – how long to wait for a window to open.
- `TIMEOUT_DALSIHO` (5 s) – wait for another window of the same process.

`sezeni -a` in a terminal asks via `input()`; without a terminal (e.g. from a key binding) it
uses `fuzzel --dmenu`. A binding can be added to `binds`:
`Mod+Shift+S { spawn-sh "~/.local/bin/sezeni -a"; }`

## How it works

**Saving:** `niri msg --json windows/workspaces` → for each window the command is taken from
`/proc/<pid>/cmdline` and the directory from `/proc/<pid>/cwd`. Special cases:
- `kitty` – the directory of the shell inside the terminal is saved (`kitty --directory …`);
  a running program (e.g. Claude Code) is not restored, only the shell in that directory.
- `zen-bin` – replaced by the `zen-browser` command (Zen restores tabs itself).

**Restoring:** tiled windows first, column by column, then floating ones. For each window:
focus the output and workspace, run the command, wait for a new window with the same app-id,
move it to the right output/workspace, add further tiles of the same column with
`consume-or-expel-window-left`, set width/height (`set-window-width/height`) and position of
floating windows (`move-floating-window`). Finally the window that was focused when saving is
focused. If an output (monitor) is not connected, the window opens on the current output.

## Dependencies

`niri` (tested with 26.04), `python3`, `fuzzel` (name prompt without a terminal),
optionally `notify-send`.

## Troubleshooting

- Restore log at startup: `journalctl --user -b | grep -i sezeni` (script stderr), or run
  `sezeni -n` manually in a terminal.
- A window does not appear within 30 s → it is skipped; increase `TIMEOUT_OKNA`.
- Single-process, multi-window applications (browsers) may open windows themselves from their
  own session; the script first waits 5 s for another window to appear and only then runs the
  command again.
- Workspace order is saved as an index on the output; named workspaces are restored by name.
