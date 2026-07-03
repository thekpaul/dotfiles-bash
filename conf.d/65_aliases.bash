# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 65: ALIASES.bash
# Interactive convenience aliases.
# Skipped entirely in non-interactive shells.
#
# Idempotent: re-aliasing overwrites the previous definition.
# ─────────────────────────────────────────────────────────────────────────────

[[ $- == *i* ]] || return

# `lsa` is an autoloaded function (../functions/lsa.bash), not an alias:
# aliases expand before function lookup, so it must not be shadowed here.
# TODO: Reinforce (mkdir, ls, cp) and convert into function (rm)
alias mkdir='mkdir -p'
alias ls='ls --color=auto'
alias ll='ls -l'
alias cp='cp -p'
# shellcheck disable=SC2139,SC2230
# bake the rm path in at definition; `which` is intentional
alias rm="echo Use the full path i.e. $(which rm), consider using \'gio trash\'"
