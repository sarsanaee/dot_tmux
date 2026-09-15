#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  Install these dotfiles on a fresh machine.
#
#    ./install.sh              install everything
#    ./install.sh --no-deps    skip installing system packages
#    ./install.sh --dry-run    print what would happen, change nothing
#
#  Safe to run repeatedly: it is idempotent, and any real file it would
#  replace is backed up to ~/.dotfiles-backup/<timestamp>/ first.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
MARKER="# >>> dot_tmux bashrc.local >>>"
ZMARKER="# >>> dot_tmux zshrc.local >>>"
DRY_RUN=0
NO_DEPS=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --no-deps) NO_DEPS=1 ;;
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

if [ -t 1 ]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
else
    B=""; G=""; Y=""; R=""; N=""
fi
info() { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
err()  { printf '  %s✗%s %s\n' "$R" "$N" "$*" >&2; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }

# ── 1. System dependencies ─────────────────────────────────────────
install_deps() {
    info "Checking system dependencies"

    local want=() 
    command -v tmux >/dev/null 2>&1 || want+=(tmux)
    command -v git  >/dev/null 2>&1 || want+=(git)

    # A clipboard bridge is what makes tmux copy actually reach the
    # system clipboard. Pick the one matching the display server.
    if ! command -v wl-copy >/dev/null 2>&1 \
       && ! command -v xclip >/dev/null 2>&1 \
       && ! command -v xsel  >/dev/null 2>&1 \
       && ! command -v pbcopy >/dev/null 2>&1; then
        if [ -n "${WAYLAND_DISPLAY:-}" ]; then want+=(wl-clipboard xclip)
        elif [ -n "${DISPLAY:-}" ];       then want+=(xclip)
        else warn "headless session: no clipboard tool needed"
        fi
    fi

    if [ ${#want[@]} -eq 0 ]; then ok "all dependencies present"; return; fi

    info "Installing: ${want[*]}"
    if   command -v apt-get >/dev/null 2>&1; then
        run sudo apt-get update -qq && run sudo apt-get install -y "${want[@]}"
    elif command -v dnf     >/dev/null 2>&1; then run sudo dnf install -y "${want[@]}"
    elif command -v pacman  >/dev/null 2>&1; then run sudo pacman -S --needed --noconfirm "${want[@]}"
    elif command -v zypper  >/dev/null 2>&1; then run sudo zypper install -y "${want[@]}"
    elif command -v brew    >/dev/null 2>&1; then run brew install "${want[@]}"
    else
        err "no known package manager; install manually: ${want[*]}"
        return 1
    fi
    ok "dependencies installed"
}

# ── 2. Symlink a dotfile, backing up whatever is there now ─────────
link() {
    local src="$1" dst="$2"

    if [ ! -e "$src" ]; then err "missing source: $src"; return 1; fi

    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        ok "$(basename "$dst") already linked"
        return 0
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        run mkdir -p "$BACKUP"
        run mv "$dst" "$BACKUP/"
        warn "backed up existing $(basename "$dst") -> $BACKUP/"
    fi

    run ln -s "$src" "$dst"
    ok "linked $dst -> $src"
}

# ── 3. Hook bashrc.local into ~/.bashrc (idempotently) ─────────────
hook_bashrc() {
    info "Wiring bash configuration into ~/.bashrc"
    local rc="$HOME/.bashrc"

    [ -f "$rc" ] || run touch "$rc"

    if grep -qF "$MARKER" "$rc" 2>/dev/null; then
        ok "~/.bashrc already sources bashrc.local"
        return 0
    fi

    run mkdir -p "$BACKUP"
    run cp "$rc" "$BACKUP/bashrc"

    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] append source block to %s\n' "$rc"
    else
        cat >> "$rc" <<EOF

$MARKER
# Managed by $REPO — edit bash/bashrc.local there, not here.
[ -f "$REPO/bash/bashrc.local" ] && . "$REPO/bash/bashrc.local"
# <<< dot_tmux bashrc.local <<<
EOF
    fi
    ok "~/.bashrc now sources bash/bashrc.local"
}

# ── 3b. Hook zshrc.local into ~/.zshrc (idempotently) ──────────────
# zsh has been the default login shell on macOS since Catalina, and it never
# reads ~/.bashrc — so on those machines everything in bash/bashrc.local was
# configured and then silently never loaded.
hook_zshrc() {
    info "Wiring zsh configuration into ~/.zshrc"
    local rc="$HOME/.zshrc"

    if [ ! -f "$REPO/zsh/zshrc.local" ]; then
        warn "no zsh/zshrc.local in this repo; skipping"
        return 0
    fi

    [ -f "$rc" ] || run touch "$rc"

    if grep -qF "$ZMARKER" "$rc" 2>/dev/null; then
        ok "~/.zshrc already sources zshrc.local"
        return 0
    fi

    run mkdir -p "$BACKUP"
    run cp "$rc" "$BACKUP/zshrc"

    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] append source block to %s\n' "$rc"
    else
        cat >> "$rc" <<EOF

$ZMARKER
# Managed by $REPO — edit zsh/zshrc.local there, not here.
[ -f "$REPO/zsh/zshrc.local" ] && . "$REPO/zsh/zshrc.local"
# <<< dot_tmux zshrc.local <<<
EOF
    fi
    ok "~/.zshrc now sources zsh/zshrc.local"
}

# ── 4. TPM + tmux plugins ──────────────────────────────────────────
install_tpm() {
    info "Installing tmux plugin manager and plugins"
    local tpm="$HOME/.tmux/plugins/tpm"

    if [ -d "$tpm/.git" ]; then
        ok "tpm already present"
    else
        run mkdir -p "$HOME/.tmux/plugins"
        run git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm" 2>/dev/null \
            && ok "tpm cloned" || { err "tpm clone failed"; return 1; }
    fi

    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] %s/bin/install_plugins\n' "$tpm"
    elif [ -x "$tpm/bin/install_plugins" ]; then
        TMUX= "$tpm/bin/install_plugins" >/dev/null 2>&1 \
            && ok "tmux plugins installed" || warn "plugin install reported an issue"
    fi
}

# ── 5. Verify the result ───────────────────────────────────────────
verify() {
    info "Verifying"
    [ "$DRY_RUN" = 1 ] && { warn "dry run, nothing to verify"; return 0; }

    local fail=0

    if tmux -f "$REPO/tmux/tmux.conf" -L dotfiles-verify new-session -d 2>/dev/null; then
        local cc
        cc="$(tmux -L dotfiles-verify show-options -sv copy-command 2>/dev/null || true)"
        if [ -n "$cc" ]; then ok "tmux copy-command = '$cc'"
        else err "tmux copy-command is EMPTY — copy will not reach the clipboard"; fail=1; fi
        tmux -L dotfiles-verify kill-server 2>/dev/null || true
    else
        err "tmux refused to load the config"; fail=1
    fi

    # xsel and pbcopy were missing here, so a working macOS (or xsel-only)
    # setup was reported as having no clipboard at all.
    if command -v wl-copy >/dev/null 2>&1 || command -v xclip >/dev/null 2>&1 \
       || command -v xsel >/dev/null 2>&1 || command -v pbcopy >/dev/null 2>&1; then
        ok "clipboard bridge available"
    else
        warn "no clipboard tool found"
    fi

    bash -ic 'true' >/dev/null 2>&1 && ok "~/.bashrc parses cleanly" \
        || { err "~/.bashrc has an error"; fail=1; }

    if [ -f "$REPO/zsh/zshrc.local" ] && command -v zsh >/dev/null 2>&1; then
        zsh -ic 'true' >/dev/null 2>&1 && ok "~/.zshrc parses cleanly" \
            || { err "~/.zshrc has an error"; fail=1; }
    fi

    # Regression guard. A helper named after a real command shadows it — and a
    # *function* shadows it silently, discarding the arguments rather than
    # erroring. `paste` (coreutils) and `gs` (Ghostscript) were both caught
    # this way. The self-wrapping aliases (grep, rm, cp, ...) are deliberate
    # and deliberately not listed here.
    local shadowed="" n
    for n in paste gs sed awk find sort tr cut join comm; do
        command -v "$n" >/dev/null 2>&1 || continue
        case "$(bash -ic "type -t $n" 2>/dev/null)" in
            function|alias) shadowed="$shadowed $n" ;;
        esac
    done
    if [ -z "$shadowed" ]; then
        ok "no helper shadows a system command"
    else
        err "these system commands are shadowed by a helper:$shadowed"; fail=1
    fi

    return $fail
}

main() {
    printf '%sInstalling dotfiles from %s%s\n\n' "$B" "$REPO" "$N"
    [ "$DRY_RUN" = 1 ] && warn "DRY RUN — no changes will be made"

    [ "$NO_DEPS" = 1 ] && info "Skipping dependencies (--no-deps)" || install_deps

    info "Linking dotfiles"
    link "$REPO/tmux/tmux.conf" "$HOME/.tmux.conf"
    link "$REPO/bash/inputrc"   "$HOME/.inputrc"

    hook_bashrc
    hook_zshrc
    install_tpm
    verify || { printf '\n%sInstall finished with problems.%s\n' "$R" "$N"; exit 1; }

    printf '\n%sDone.%s  Start a new shell (or: exec bash) and run tmux.\n' "$G" "$N"
    if [ -d "$BACKUP" ]; then
        printf 'Replaced files were saved in %s\n' "$BACKUP"
    fi
    return 0
}

main "$@"
