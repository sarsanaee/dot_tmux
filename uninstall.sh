#!/usr/bin/env bash
# Remove the symlinks and the ~/.bashrc hook created by install.sh.
# Backups in ~/.dotfiles-backup/ are left alone; restore from there by hand.
set -euo pipefail

MARKER="# >>> dot_tmux bashrc.local >>>"

for f in "$HOME/.tmux.conf" "$HOME/.inputrc"; do
    if [ -L "$f" ]; then rm "$f"; echo "removed symlink $f"
    elif [ -e "$f" ]; then echo "left alone (not a symlink): $f"
    fi
done

if grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
    cp "$HOME/.bashrc" "$HOME/.bashrc.pre-uninstall"
    sed -i "/$(printf '%s' "$MARKER" | sed 's/[][\.*^$/]/\\&/g')/,/^# <<< dot_tmux bashrc.local <<<$/d" "$HOME/.bashrc"
    echo "removed bashrc hook (previous version: ~/.bashrc.pre-uninstall)"
fi

echo "Done. tmux plugins in ~/.tmux/plugins were left in place."
