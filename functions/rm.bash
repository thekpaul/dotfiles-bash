# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# rm.bash  (autoloaded function)
# Defines `rm`, a safer removal wrapper:
# interactive sessions are offered a platform-appropriate Trash backend
# (with confirmation) before falling back to `rm -i`, while
# non-interactive shells pass straight through to the real command.
#
# Trash backends by platform family (THEKP_FS):
#   freedesktop (linux-gnu, BSDs): `gio trash`, else `trash-put` (trash-cli)
#   darwin*: `trash` (bundled since macOS 14; also via Homebrew)
#   cygwin / msys / git-windows: `recycle` (cygutils)
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: 00_platform.bash (THEKP_FS, consumed at call time)
#             09_sysexits.bash
#             (EX_UNAVAILABLE, with a baked-in standalone fallback).
# ─────────────────────────────────────────────────────────────────────────────

# shellcheck disable=SC2016
# literal backticks in hints and confirmation prompts; no expansion intended
rm() {
    # Non-interactive callers get the real command: no prompts, no surprises
    if [[ $- != *i* ]]; then
        if type -P rm > /dev/null; then
            command rm "$@"
            return
        fi
        printf 'Function currently unavailable: Install `rm`\n' >&2
        return "${EX_UNAVAILABLE:-69}"
    fi

    # Resolve a Trash backend for the current platform family
    local -a trash=()
    case ${THEKP_FS} in
        darwin*)
            type -P trash > /dev/null && trash=(trash)
            ;;
        cygwin|msys|git-windows)
            type -P recycle > /dev/null && trash=(recycle)
            ;;
        *)  # freedesktop Trash spec: GLib's gio, else trash-cli
            if type -P gio > /dev/null; then
                trash=(gio trash)
            elif type -P trash-put > /dev/null; then
                trash=(trash-put)
            fi
            ;;
    esac

    local REPLY
    if (( ${#trash[@]} > 0 )); then
        printf 'Alternative file removal with Trash support: `%s`\n' "${trash[*]}"
        if [[ $# -eq 0 ]]; then
            "${trash[@]}"
            return
        fi
        printf 'Continue with the following command?\n\t%s %s\n' "${trash[*]}" "$*"
        read -r -p '[y|N] > '
        if [[ "$REPLY" == 'y' ]]; then
            "${trash[@]}" "$@"
            return
        fi
    fi

    # Fallback: the real `rm` in interactive mode for per-file confirmation
    if ! type -P rm > /dev/null; then
        printf 'Function currently unavailable: Install a Trash utility or `rm`\n' >&2
        return "${EX_UNAVAILABLE:-69}"
    fi

    printf 'Interactive file removal with `rm -i`\n'
    printf 'Continue with the following command?\n\trm -i %s\n' "$*"
    read -r -p '[y|N] > '
    if [[ "$REPLY" == 'y' ]]; then
        command rm -i "$@"
    fi
}
