# Central Bash configuration loader.
#
# Sourced by ~/.bash_profile (login shells) and ~/.bashrc (interactive shells).
# Must never be executed directly;
# sourcing is required to affect the calling shell's environment.
#
# Session-type awareness:
#   This file carries no interactive or login guard of its own.
#   That is deliberate: non-interactive login shells (e.g. `ssh host cmd`)
#   reach this file via .bash_profile and must receive the full environment
#   setup (PATH, TMPDIR, tool registration, host overrides) to work correctly.
#
#   Individual conf.d scripts detect their own context using native Bash tests:
#     [[ $- == *i* ]]      -> true when the calling shell is interactive
#     shopt -q login_shell -> true when the calling shell is a login shell
#   Scripts with output or side-effects only make sense interactively
#   (prompts, session listings, colored status) use `[[ $- == *i* ]] || return`
#   at their top; all others run unconditionally.

# ── Safety guard ─────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    printf '%s: must be sourced, not executed.\n' "${0##*/}" >&2
    exit 1
fi

# ── conf.d loader ─────────────────────────────────────────────────────────────
# Resolves the conf.d directory relative to this file regardless of CWD.
# Scripts are sourced in lexicographic order;
# two-digit numeric prefixes with leading zeros guarantee correct ordering
# (00_ < 05_ < 09_ < 10_ < 99_).
# Each script may `return` early without affecting the loop;
# only that script exits, and loading continues with the next file.
_bash_main_dir="${BASH_SOURCE[0]%/*}"

for _bash_f in "$_bash_main_dir"/conf.d/[0-9][0-9]_*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$_bash_f" ]] && source "$_bash_f"
done

unset _bash_f _bash_main_dir

# ── Optional Fish login-shell handoff ────────────────────────────────────────
# The opt-in policy lives with the Fish configuration rather than in Bash.
# Source its bridge only for an interactive Bash login shell: non-login Bash
# sessions and remote command execution remain in Bash for POSIX compatibility.
_bash_fish_bridge="${XDG_CONFIG_HOME:-${HOME}/.config}/fish/bash-login.sh"

if [[ $- == *i* ]] && shopt -q login_shell && [[ -r "$_bash_fish_bridge" ]]; then
    # shellcheck source=/dev/null
    source "$_bash_fish_bridge"
fi

unset _bash_fish_bridge
