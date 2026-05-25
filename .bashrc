# BASHRC: User-specific Bash interactive shell configurations.
#
# Responsibilities:
#   - Bail immediately for non-interactive shells.
#   - Guard system-wide bashrc sourcing against double-execution.

# ── 0. FUNDAMENTALS ──────────────────────────────────────────────────────────

# If not running interactively, don't do anything.
[[ $- != *i* ]] && return

# Guard system bashrc sourcing against double-execution.
# BASHRCSOURCED is not standardised; it may already be set by the system's
# /etc/bash.bashrc on some distributions (e.g., openSUSE).
# It is intentionally absent from .bash_profile;
# login shells receive system-wide configuration via /etc/profile,
# which Bash sources automatically before .bash_profile.
if [[ -z "${BASHRCSOURCED}" ]]; then
    # Windows-derived environments handle system configuration separately and
    # must not source /etc/bash.bashrc here.
    if [[ ! ${OSTYPE} =~ ^(cygwin|msys) ]]; then
        if [[ -f /etc/bash.bashrc ]]; then
            source /etc/bash.bashrc
        elif [[ -f /etc/bashrc ]]; then
            source /etc/bashrc
        fi
    fi
    # Set manually in case the system bashrc above did not set it.
    [[ -z "${BASHRCSOURCED}" ]] && BASHRCSOURCED="Y"
fi
