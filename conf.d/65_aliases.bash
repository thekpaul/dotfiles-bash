# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 65: ALIASES.bash
# Interactive convenience aliases.
# Skipped entirely in non-interactive shells.
#
# Idempotent: re-aliasing overwrites the previous definition.
# ─────────────────────────────────────────────────────────────────────────────

[[ $- == *i* ]] || return

# `lsa` and `rm` are autoloaded functions (../functions/), not aliases:
# aliases expand before function lookup, so they must not be shadowed here.
# TODO: Reinforce (mkdir, ls, cp)
alias mkdir='mkdir -p'
alias ls='ls --color=auto'
alias ll='ls -l'
alias cp='cp -p'
