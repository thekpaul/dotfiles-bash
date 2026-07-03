# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# lscd.bash  (autoloaded function)
# Defines `lscd`: change directory, then list the new location's contents.
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: lsa
#             (autoloaded sibling; lazy stub satisfies `declare -F` probe, so
#              dependency stays lazy end-to-end).
# ─────────────────────────────────────────────────────────────────────────────

# Change directory (all arguments forwarded to `cd`) and, on success,
# list the contents via `lsa` when available, plain `ls` otherwise.
lscd() {
    if declare -F lsa > /dev/null; then
        cd "$@" && lsa
    else
        cd "$@" && command ls
    fi
}
