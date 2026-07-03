# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# mkcd.bash  (autoloaded function)
# Defines `mkcd`: create a directory (parents included) and change into it.
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: 09_sysexits.bash
#             (EX_UNAVAILABLE, with a baked-in standalone fallback).
# ─────────────────────────────────────────────────────────────────────────────

# Create one or more directories, then `cd` into the last argument
# (skipped when the last argument is an option).
# Arguments are forwarded to `mkdir`; parent creation is attempted first.
mkcd() {
    if ! type -P mkdir > /dev/null; then
        # shellcheck disable=SC2016
        # literal backticks in the hint; no expansion intended
        printf 'Function currently unavailable: Install `mkdir`\n' >&2
        return "${EX_UNAVAILABLE:-69}"
    fi

    command mkdir -p "$@" 2> /dev/null || command mkdir "$@" || return

    if [[ $# -gt 0 && "${*: -1}" != -* ]]; then
        cd "${*: -1}" || return
    fi
}
