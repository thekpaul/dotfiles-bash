# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# pdk.bash  (autoloaded function)
# Defines `pdk`, the environmental-scripts wrapper for lab PDK servers.
#
# The Fish original had to `exec bash` because Fish cannot source Bash scripts;
# here the target is sourced directly into the current shell, so
# only the convenience features remain:
# bare invocation lists the available PDK scripts, and
# sourcing from outside the PDK directory asks first.
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
# Distinct from conf.d/80_pdk.bash, which applies host-gated session setup.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: 09_sysexits.bash
#             (EX_USAGE, EX_UNAVAILABLE, EX_TEMPFAIL,
#              with baked-in standalone fallbacks).
# ─────────────────────────────────────────────────────────────────────────────

# Source one PDK environment script into the current shell;
# list the available scripts when called without arguments.
pdk() {
    # Allow one target only per function call
    if [[ $# -gt 1 ]]; then
        printf 'Usage: pdk [SCRIPT]\n' >&2
        return "${EX_USAGE:-64}"
    fi

    local pdk_dir='/opt/mi-env/bin'
    if [[ ! -d "$pdk_dir" ]]; then
        printf 'Function currently unavailable: PDK scripts directory not found.\n' >&2
        return "${EX_UNAVAILABLE:-69}"
    fi

    # Show all available scripts if no argument is provided
    if [[ $# -eq 0 ]]; then
        local -a cmds=()
        local f
        for f in "$pdk_dir"/*; do
            [[ -f "$f" && -x "$f" ]] && cmds+=("${f##*/}")
        done
        if (( ${#cmds[@]} == 0 )); then
            printf 'Function currently unavailable: No eligible PDK scripts found.\n' >&2
            return "${EX_UNAVAILABLE:-69}"
        fi
        printf '%d possible scripts: %s\n' "${#cmds[@]}" "${cmds[*]}"
        return 0
    fi

    # Resolve the target: prefer the PDK directory (even when not on PATH),
    # then fall back to a PATH lookup as in the Fish original.
    local full_path
    if [[ -f "$pdk_dir/$1" && -x "$pdk_dir/$1" ]]; then
        full_path="$pdk_dir/$1"
    elif ! full_path="$(type -P "$1")"; then
        # shellcheck disable=SC2016
        # literal backticks in the message; no expansion intended
        printf 'FATAL: `%s` not available as an executable.\n' "$1" >&2
        return "${EX_USAGE:-64}"
    fi

    # Confirm before sourcing from outside the PDK directory
    local REPLY
    if [[ "${full_path%/*}" != "$pdk_dir" ]]; then
        printf 'WARNING: Sourcing from abnormal path %s, proceed?\n' "$full_path"
        read -r -p '[y/N] > '
        if [[ "$REPLY" != 'y' ]]; then
            printf 'Operation cancelled.\n' >&2
            return "${EX_TEMPFAIL:-75}"
        fi
    fi

    # Bash sources the environment script directly —
    # no `exec` round-trip through a new shell as the Fish original required.
    # shellcheck source=/dev/null
    source "$full_path"
}
