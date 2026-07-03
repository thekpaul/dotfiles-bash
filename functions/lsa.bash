# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# lsa.bash  (autoloaded function)
# Defines `lsa`, the "list all" directory listing with sensible defaults:
# prefers `eza`, falling back to a compatible `ls` per platform.
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: 00_platform.bash
#             (THEKP_FS consumed at call time to pick `ls` flavour)
#             09_sysexits.bash
#             (EX_UNAVAILABLE, with a baked-in standalone fallback).
# ─────────────────────────────────────────────────────────────────────────────

# List all entries (including hidden, excluding . and ..), directories first.
# Extra arguments are passed through to the underlying command.
lsa() {
    # Pin the CWD as the target when no path argument is given: eza (>=0.23)
    # otherwise reads target paths from stdin whenever stdin is not a TTY,
    # which would make a bare `lsa` in a pipeline or script list nothing.
    # An argument counts as a path when it exists or is a bare word;
    # `-`/`+` prefixes cover options and option values such as
    # `--time-style`'s +FORMAT.
    local _arg _has_path=0
    for _arg in "$@"; do
        if [[ -e "$_arg" || "$_arg" == [!-+]* ]]; then
            _has_path=1
            break
        fi
    done
    (( _has_path )) || set -- "$@" .

    if type -P eza > /dev/null; then
        command eza -AX --group-directories-first --color=auto --icons=auto "$@"
        return
    fi

    case ${THEKP_FS} in
        darwin*)
            # BSD ls lacks the GNU flags; require coreutils' gls on macOS
            if type -P gls > /dev/null; then
                command gls --color=auto -vAH --group-directories-first "$@"
                return
            fi
            ;;
        linux-gnu|msys|cygwin|git-windows)
            command ls --color=auto -vAH --group-directories-first "$@"
            return
            ;;
    esac

    # shellcheck disable=SC2016
    # literal backticks in the hint; no expansion intended
    printf 'Function currently unavailable: Install `eza` or a compatible `ls`\n' >&2
    return "${EX_UNAVAILABLE:-69}"
}
