# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 10: PIXI.bash
# Registers a Pixi installation for the session:
# sets PIXI_HOME to the install prefix under LOCAL_OPT_HOME (when unset) and
# prepends its global binary directory to PATH.
# Pixi is a declarative, conda-compatible package and environment manager.
#
# Idempotent: PIXI_HOME is set only when unset; the bin directory is added via
# `add_paths`, which skips entries already present on PATH.
# Depends on: 02_defaults.bash (LOCAL_OPT_HOME),
#             01_autoload.bash (add_paths, lazily loaded from ../functions/).
# ─────────────────────────────────────────────────────────────────────────────

if [[ -z ${PIXI_HOME} && -d ${LOCAL_OPT_HOME}/pixi ]]; then
    export PIXI_HOME="${LOCAL_OPT_HOME}/pixi"
fi

[[ -n ${PIXI_HOME} ]] && add_paths --prepend "${PIXI_HOME}/bin"
