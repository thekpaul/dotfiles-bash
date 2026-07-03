# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# tree.bash  (autoloaded function)
# Defines `tree`, a recursive directory listing:
# prefers an `eza`-backed tree via the sibling `lsa`, falling back to
# the real `tree` command.
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: lsa (autoloaded sibling, used with `eza`)
#             09_sysexits.bash
#             (EX_UNAVAILABLE, with a baked-in standalone fallback).
# ─────────────────────────────────────────────────────────────────────────────

# Recursively list directory contents as a tree.
# Extra arguments are passed through to the underlying command.
tree() {
    if type -P eza > /dev/null && declare -F lsa > /dev/null; then
        lsa --tree -lo --no-permissions --time-style '+%y/%m/%d %H:%M' "$@"
    elif type -P tree > /dev/null; then
        command tree "$@"
    else
        # shellcheck disable=SC2016
        # literal backticks in the hint; no expansion intended
        printf 'Function currently unavailable: Install `eza` or `tree`\n' >&2
        return "${EX_UNAVAILABLE:-69}"
    fi
}
