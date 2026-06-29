# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 01: AUTOLOAD.bash
# Fish-style function autoloader for the sibling ../functions/ directory.
# Each functions/NAME.bash file holds one function named NAME
# (the Bash analogue of Fish's functions/NAME.fish ↔ NAME pairing).
#
# Loading is lazy: every functions/NAME.bash file gets a self-replacing stub.
# On first call the stub unsets itself, sources its file
# (defining the real function), then dispatches to it —
# so the body is parsed exactly once, on first use.
#
# add_paths is loaded lazily even though the next core module (02_defaults)
# calls it during startup: this demonstrates that the lazy mechanism resolves
# correctly even when first used mid-startup,
# not only in a later interactive shell.
#
# Loaded early in the core zone so subsequent modules can rely on
# the function names being callable.
# Must load after 00_platform.bash, since the autoloaded functions
# may consume THEKP_FS.
#
# Idempotent: re-sourcing re-installs identical stubs;
# the functions themselves are written to be safe to re-source.
# Depends on: 00_platform.bash (THEKP_FS, consumed by autoloaded functions).
# ─────────────────────────────────────────────────────────────────────────────

# Resolve the functions/ directory relative to this file, regardless of CWD.
_thekp_fn_dir="${BASH_SOURCE[0]%/*}/../functions"
[[ -d "$_thekp_fn_dir" ]] || return 0

for _thekp_f in "$_thekp_fn_dir"/*.bash; do
    [[ -e "$_thekp_f" ]] || continue            # guard the no-match glob
    _thekp_name="${_thekp_f##*/}"
    _thekp_name="${_thekp_name%.bash}"

    # Install a self-replacing stub.
    # The file path is frozen into the stub via `printf %q`
    # (not `${var@Q}`, kept for bash 4.2 / CentOS 7) as the loop variable
    # changes on each iteration.
    printf -v _thekp_qf '%q' "$_thekp_f"
    eval "
${_thekp_name}() {
    unset -f ${_thekp_name}
    source ${_thekp_qf}
    if ! declare -F ${_thekp_name} >/dev/null; then
        printf '01_autoload: %s did not define %s()\n' ${_thekp_qf} ${_thekp_name} >&2
        return 127
    fi
    ${_thekp_name} \"\$@\"
}
"
done

unset _thekp_fn_dir _thekp_f _thekp_name _thekp_qf
