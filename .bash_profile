# BASH_PROFILE: User-specific Bash login shell configurations.
#
# Responsibilities:
#   - Source main.bash for environment setup (PATH, TMPDIR, tools, etc.).
#
# Does NOT source ~/.bashrc.
# Session-type awareness (interactive vs. non-interactive, login vs. non-login)
# is handled by individual conf.d scripts using native Bash tests;
# see main.bash for details.
#
# Non-interactive login shells (e.g. `ssh host cmd`) receive the
# full environment setup from main.bash because
# main.bash itself carries no interactive guard;
# only conf.d scripts that produce user-facing output
# (prompts, session listings) guard themselves individually.

# ── Source the central loader ────────────────────────────────────────────────
_bash_profile_main="${XDG_CONFIG_HOME:-${HOME}/.config}/bash/main.bash"

if [[ -f "$_bash_profile_main" ]]; then
    source "$_bash_profile_main"
else
    printf '.bash_profile: warning: main.bash not found at %s\n' \
        "$_bash_profile_main" >&2
fi
unset _bash_profile_main
