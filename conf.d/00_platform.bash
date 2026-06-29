# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 00: PLATFORM.bash
# Detects the current platform family into the custom `THEKP_FS` variable,
# derived from the built-in `OSTYPE` with extra disambiguation for
# Windows-derived Bash flavours (Cygwin, MSYS2, Git Bash).
# Loads first because later modules branch on it
# (path normalisation, base directories, add_paths).
#
# Idempotent: a plain re-assignment yielding the same value on every source.
# ─────────────────────────────────────────────────────────────────────────────

# THEKP_FS is consumed by later conf.d modules, not within this file.
# shellcheck disable=SC2034

case ${OSTYPE} in
    cygwin*)
        # Disambiguate MSYS2 from Cygwin via `MSYSTEM`
        if [[ -n ${MSYSTEM} ]]; then
            THEKP_FS='msys'
        else
            THEKP_FS='cygwin'
        fi
        ;;
    msys*)
        # Git Bash (TODO: May need further proof)
        THEKP_FS='git-windows'
        ;;
    *)
        # Inherit builtin `OSTYPE` variable by default, may be subject to change
        THEKP_FS=${OSTYPE}
        ;;
esac
