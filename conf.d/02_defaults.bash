# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 02: DEFAULTS.bash
# Baseline environment defaults the rest of the configuration builds on:
# Windows-specific XDG_CONFIG_HOME normalisation,
# the LOCAL_OPT_HOME toolchain prefix, the user binary directory on PATH, and
# EDITOR/VISUAL.
#
# Idempotent: every assignment is set-if-unset or routed through `add_paths`
# (which skips entries already on PATH).
# Depends on: 00_platform.bash (THEKP_FS),
#             01_autoload.bash (add_paths, lazily loaded from ../functions/).
# ─────────────────────────────────────────────────────────────────────────────

# ── Alternative XDG_CONFIG_HOME for Windows-based Bash environments ──────────
[[ -n ${XDG_CONFIG_HOME} ]] && case ${THEKP_FS} in
    cygwin|git-windows)
        # Cygwin and Git Bash inherit the home directory from Windows
        if command -v cygpath > /dev/null 2>&1; then
            XDG_CONFIG_HOME="$(cygpath "${XDG_CONFIG_HOME}")"
            export XDG_CONFIG_HOME
        fi
        ;;
    msys*)
        # MSYS shells use a separate home directory available as `HOME`
        export XDG_CONFIG_HOME="${HOME}/.config"
        ;;
esac

# ── Local applications installation directory LOCAL_OPT_HOME ─────────────────
case ${THEKP_FS} in
    cygwin|git-windows)
        if command -v cygpath > /dev/null 2>&1; then
            if [[ -n ${LOCAL_OPT_HOME} ]]; then
                LOCAL_OPT_HOME="$(cygpath "${LOCAL_OPT_HOME}")"
            else
                LOCAL_OPT_HOME="$(cygpath "${USERPROFILE}/Apps")"
            fi
            export LOCAL_OPT_HOME
        elif [[ -z ${LOCAL_OPT_HOME} ]]; then
            # Best-effort fallback when cygpath is missing; HOME is almost
            # certainly inherited from USERPROFILE on these environments
            export LOCAL_OPT_HOME="${HOME}/Apps"
        fi
        # else: preserve user's value (cannot normalise without cygpath)
        ;;
    msys*)
        if [[ -z ${LOCAL_OPT_HOME} ]]; then
            export LOCAL_OPT_HOME="${HOME}/.local/opt"
        elif command -v cygpath > /dev/null 2>&1; then
            LOCAL_OPT_HOME="$(cygpath "${LOCAL_OPT_HOME}")"
            export LOCAL_OPT_HOME
        fi
        # else: preserve user's value (cannot normalise without cygpath)
        ;;
    *)
        [[ -n ${LOCAL_OPT_HOME} ]] || export LOCAL_OPT_HOME="${HOME}/.local/opt"
        ;;
esac

# ── User-specific binary directory on PATH ───────────────────────────────────
# Idempotent prepend (mirrors the monolith's `~/.local/bin` at the front).
add_paths --prepend "${HOME}/.local/bin"

# ── Editor defaults ──────────────────────────────────────────────────────────
# Prefer Neovim when present, fall back to vi. A user-set EDITOR is preserved.
if _bash_nvim="$(command -v nvim 2> /dev/null)"; then
    : "${EDITOR:=${_bash_nvim}}"
else
    : "${EDITOR:=vi}"
fi
: "${VISUAL:=${EDITOR}}"
export EDITOR VISUAL
unset _bash_nvim
