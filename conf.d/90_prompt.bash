# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 90: PROMPT.bash
# Custom interactive prompt: trims deep directory display,
# shows a red exit-status marker after a failed command, and
# renders root sessions in red text.
# Uses raw ANSI escapes (no tput/terminfo dependency).
#
# Idempotent: function redefinition and the `PROMPT_COMMAND=` assignment
# (not append) yield the same state on every source.
# ─────────────────────────────────────────────────────────────────────────────

[[ $- == *i* ]] || return

# Trim deep cwd display so the prompt doesn't wrap on long paths
PROMPT_DIRTRIM=3

# Custom prompt: red exit-status marker on non-zero return, root prompt in red.
_prompt_command() {
    local last=$?
    local red=$'\e[31m'
    local reset=$'\e[0m'
    local fail=""
    if (( last != 0 )); then
        fail="\[${red}\]✘ ${last} \[${reset}\]"
    fi
    if (( EUID == 0 )); then
        PS1="${fail}\[${red}\]\u@\h:\w #\[${reset}\] "
    else
        PS1="${fail}[\u@\h:\w] \$ "
    fi
}
PROMPT_COMMAND=_prompt_command
