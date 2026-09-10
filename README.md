# dot_tmux

My tmux + bash configuration, with working copy-paste and a one-command install.

```bash
git clone https://github.com/sarsanaee/dot_tmux.git ~/dot_tmux
cd ~/dot_tmux && ./install.sh
exec bash          # pick up the new shell config
```

That is the whole reinstall procedure on a new machine. `install.sh` is
idempotent — re-run it any time — and it backs up anything it replaces into
`~/.dotfiles-backup/<timestamp>/`.

| Flag | Effect |
|------|--------|
| `--dry-run` | Print every action, change nothing |
| `--no-deps` | Don't touch the package manager |

`./uninstall.sh` removes the symlinks and the `~/.bashrc` hook.

## Layout

```
tmux/tmux.conf     -> ~/.tmux.conf      (symlink)
bash/inputrc       -> ~/.inputrc        (symlink)
bash/bashrc.local  sourced from ~/.bashrc via a marked block
install.sh         installer
uninstall.sh       reverses the installer
```

Nothing is copied, so editing a file in this repo takes effect immediately and
`git status` shows what you changed. Your distro's `~/.bashrc` is never
rewritten — the installer only appends a guarded `source` line.

Host-specific or private settings go in `~/.bashrc.private`, which
`bashrc.local` sources if present and git never sees.

## Why copy-paste was broken

The old config ended selections with:

```tmux
bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel
```

`copy-pipe` pipes the selection into an external program — but no program was
named, and tmux's `copy-command` option was never set. So every copy went into
tmux's own paste buffer and stopped there. It was invisible to `Ctrl+V` in the
browser, the editor, or anywhere else. Compounding it, **no clipboard utility
was installed on the machine at all**, so there was nothing for tmux to pipe
into even if it had tried.

The fix is `copy-command`, detected at config-load time so the same file works
on Wayland, X11 and macOS:

```tmux
if-shell 'command -v wl-copy >/dev/null 2>&1' \
    "set -s copy-command 'wl-copy --type text/plain'"
```

With that set, a bare `copy-pipe-and-cancel` routes through it and lands in the
real system clipboard. `set -g set-clipboard on` additionally enables the
OSC 52 escape-sequence route, which makes copy work over SSH in terminals that
support it (kitty, alacritty, wezterm, foot, iTerm2). GNOME Terminal does not
support OSC 52, which is why the external binary is the load-bearing part here.

## Copy-paste cheat sheet

Prefix is `Ctrl+Space`.

### Keyboard

| Key | Action |
|-----|--------|
| `prefix` `Enter` | Enter copy mode |
| `Alt+Up` | Enter copy mode and start scrolling |
| `v` | Start selection |
| `V` | Select whole line |
| `Ctrl+v` | Toggle block (rectangle) selection |
| `y` or `Enter` | **Copy to system clipboard** and exit |
| `Y` | Copy the current line |
| `/` `?` `n` `N` | Search scrollback |
| `q` / `Escape` | Quit copy mode / clear selection |
| `prefix` `p` | Paste tmux buffer |
| `prefix` `Ctrl+v` | Paste the **system** clipboard |
| `prefix` `Ctrl+p` | Choose from paste history |

### Mouse

| Action | Result |
|--------|--------|
| Drag | Copy to system clipboard, keeping scroll position |
| Double-click | Copy word |
| Triple-click | Copy line |
| Middle-click | Paste system clipboard |
| Wheel | Scroll into copy mode |

Holding **Shift** while dragging bypasses tmux and uses GNOME Terminal's own
selection — useful for grabbing text across split panes, which tmux cannot do.

### From the shell

`bashrc.local` defines portable helpers:

```bash
ls -l | clip        # pipe command output to the clipboard
paste > out.txt     # write the clipboard to a file
cpwd                # copy the current directory path
cfile config.yaml   # copy a file's contents
```

## What else the bash config fixes

- **Bracketed paste** (`~/.inputrc`). Without it, pasting multiple lines
  executes each one on arrival, including a partial final line. This is the
  other half of "pasting into the terminal is awful".
- **`stty -ixon`** frees `Ctrl+S`, which otherwise sends XOFF and freezes the
  terminal until `Ctrl+Q` — a hang that looks exactly like a crash.
- **Shared history** across tmux panes, 100k entries, timestamped, deduplicated,
  flushed after every command so panes stop overwriting each other's history.
- **Up/Down search history by prefix** instead of walking every command.
- `Ctrl+Left` / `Ctrl+Right` word jumps, case-insensitive completion, no bell.

## tmux plugins

Managed by [TPM](https://github.com/tmux-plugins/tpm), installed automatically.

- **tmux-resurrect** — `prefix Ctrl+s` save, `prefix Ctrl+r` restore.

Add one by putting a `set -g @plugin '...'` line above the final `run` line in
`tmux/tmux.conf`, then `prefix I`.

## Notes

- Requires tmux **3.2+** for `copy-command`. Check with `tmux -V`.
- `default-terminal` is `tmux-256color`. If you SSH from inside tmux to a host
  that lacks that terminfo entry, send it over once:
  ```bash
  infocmp -x tmux-256color | ssh THEHOST tic -x -
  ```
- The `smcup@:rmcup@` override disables the alternate screen, so tmux output
  stays in the terminal's scrollback after you exit. Drop that line in
  `tmux/tmux.conf` if you would rather tmux restore the screen.
