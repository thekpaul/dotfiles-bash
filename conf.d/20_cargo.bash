# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 20: CARGO.bash
# Initialises the Rust toolchain environment from the default Cargo location
# (~/.cargo/env), which prepends ~/.cargo/bin to PATH and sets related vars.
#
# Idempotent: modern `~/.cargo/env` guards its own PATH edit
# (`case ":${PATH}:" in *":$HOME/.cargo/bin:"*`), so
# re-sourcing does not add a duplicate entry.
# ─────────────────────────────────────────────────────────────────────────────

# shellcheck source=/dev/null
[[ -f ${HOME}/.cargo/env ]] && . "${HOME}/.cargo/env"
