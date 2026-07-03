# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# vnclist.bash  (autoloaded function)
# Defines `vnclist`, a VNC server usage reporter for the current host:
# parses the full (visible) process list for VNC server instances.
#
# Output modes:
#   vnclist            per-display listing "<display> (<user>): <port>"
#   vnclist -u         per-user dictionary of displays and ports
#   vnclist -u=NAME    displays and ports for one user (also --user=NAME)
#
# Loaded on demand by conf.d/01_autoload.bash:
# the matching stub sources this file on first call, then
# dispatches to the function defined below.
#
# Idempotent: this file only defines a function with no external state.
# Depends on: 09_sysexits.bash
#             (EX_USAGE, EX_UNAVAILABLE, EX_NOUSER,
#              with baked-in standalone fallbacks);
#             `ps` is the one external requirement.
# ─────────────────────────────────────────────────────────────────────────────

# Display VNC usage on the current host.
# The optional value stays attached to its flag (`-u=NAME`, `--user=NAME`).
vnclist() {
    local user_flag=0 user=''
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user) user_flag=1 ;;
            --user=*)  user_flag=1; user="${1#--user=}" ;;
            -u*)       user_flag=1; user="${1#-u}"; user="${user#=}" ;;
            *)
                printf 'Usage: vnclist [-u[=USER] | --user[=USER]]\n' >&2
                return "${EX_USAGE:-64}"
                ;;
        esac
        shift
    done

    if ! type -P ps > /dev/null; then
        # shellcheck disable=SC2016
        # literal backticks in the hint; no expansion intended
        printf 'Function currently unavailable: Install `ps` to see current processes\n' >&2
        return "${EX_UNAVAILABLE:-69}"
    fi

    # Details on active VNC servers, indexed by (unique) display number.
    local -a users=() ports=()
    local line
    local re_bins='Xvnc|Xtigervnc|Xtightvnc|x11vnc'
    local re_info='^([^[:space:]]+).*[[:space:]]:([0-9]+).*[[:space:]]-rfbport[[:space:]]+([0-9]+)'
    # `ps` prints "[user] [command args]"; keep only VNC server binaries
    while IFS= read -r line; do
        [[ "$line" =~ $re_bins ]] || continue
        [[ "$line" =~ $re_info ]] || continue
        users[BASH_REMATCH[2]]="${BASH_REMATCH[1]}"
        ports[BASH_REMATCH[2]]="${BASH_REMATCH[3]}"
    done < <(command ps -eo user,args)

    if (( ${#users[@]} == 0 )); then
        printf 'No VNC servers currently running.\n'
        return 0
    fi

    # Default printing format: "<display> (<user>): <port>"
    local disp
    if (( ! user_flag )); then
        for disp in "${!users[@]}"; do
            printf '%3d (%s): %d\n' "$disp" "${users[disp]}" "${ports[disp]}"
        done
        return 0
    fi

    # User-keyed dictionary: "<user>: <display> (<port>), ..."
    # A parallel list keeps first-seen order for the print-by-user mode.
    local -A by_user=()
    local -a order=()
    local u entry
    for disp in "${!users[@]}"; do
        u="${users[disp]}"
        printf -v entry '%3d (%d)' "$disp" "${ports[disp]}"
        if [[ -n "${by_user[$u]:-}" ]]; then
            by_user[$u]+=", ${entry}"
        else
            by_user[$u]="$entry"
            order+=("$u")
        fi
    done

    if [[ -n "$user" ]]; then # Specific user is requested
        if [[ -z "${by_user[$user]:-}" ]]; then
            printf 'No VNC servers currently running for user %s\n' "$user" >&2
            return "${EX_NOUSER:-67}"
        fi
        if [[ "${by_user[$user]}" == *,* ]]; then
            printf 'User %s at displays %s\n' "$user" "${by_user[$user]}"
        else
            printf 'User %s at display %s\n' "$user" "${by_user[$user]}"
        fi
        return 0
    fi

    # No user specified: print every user's displays
    printf 'Print-by-user mode:\n'
    for u in "${order[@]}"; do
        printf '%12s: %s\n' "$u" "${by_user[$u]}"
    done
}
