# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 80: PDK.bash
# Host-specific overrides for lab PDK servers (hostnames matching `pdk<N>`).
# Sources the site SNU profile when present and tightens the umask.
# No-op on every other host.
#
# Side-effect: sets `umask 0027` (no group-write, no other-access)
# for the session — intentional and idempotent (a fixed value).
# Idempotent: hostname-gated; re-sourcing re-applies the same umask and
# re-reads the same site profile.
# ─────────────────────────────────────────────────────────────────────────────

[[ "${HOSTNAME:-$(uname -n 2> /dev/null || hostname)}" =~ ^pdk[0-9]+ ]] || return

# PDK-specific: source SNU-specific configuration when available
# shellcheck source=/dev/null
[[ -f /opt/mi-env/.snu.bash_profile ]] && . /opt/mi-env/.snu.bash_profile

# Default permission masking for new inodes
umask 0027 # Disables group write and others access

# TODO: `XMODIFIERS` is used for language input (virt. kb), caution required
# unset XMODIFIERS
