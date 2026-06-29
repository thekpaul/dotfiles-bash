#!/usr/bin/env bash
# Sourceability, idempotency, and behaviour checks for the conf.d modules.
#
# Pure Bash: no ShellCheck dependency, so this runs unchanged on the dev box
# and inside any CI container (Ubuntu, RHEL 8, CentOS 7).
# ShellCheck linting is handled separately in the workflow on the host runner.
#
# Usage:
#     bash tests/run-checks.sh
#
# Exits non-zero if any check fails; prints a per-check PASS/FAIL summary.

set -uo pipefail

# Resolve the repo root from this script's location, independent of CWD
# (works on the host and under `-w /repo` in a container).
_self="${BASH_SOURCE[0]}"
REPO_ROOT="$(cd "${_self%/*}/.." && pwd)"
cd "$REPO_ROOT" || exit 1

_failures=0

# check NAME COMMAND...
# Runs COMMAND in a subshell; reports PASS on exit 0, FAIL otherwise.
check() {
    local name="$1"; shift
    if ( "$@" ); then
        printf 'PASS  %s\n' "$name"
    else
        printf 'FAIL  %s\n' "$name"
        _failures=$(( _failures + 1 ))
    fi
}

# ── 1. Syntax: every module + the loader parses ──────────────────────────────
syntax_check() {
    local f rc=0
    bash -n main.bash || rc=1
    for f in conf.d/[0-9][0-9]_*.bash; do
        bash -n "$f" || { printf '  syntax error: %s\n' "$f" >&2; rc=1; }
    done
    return "$rc"
}
check "syntax (bash -n)" syntax_check

# ── 2. Full load: sourcing main.bash exits clean ─────────────────────────────
load_check() {
    bash -c 'source main.bash' >/dev/null 2>&1
}
check "full load (source main.bash)" load_check

# ── 3. Idempotency: PATH is byte-identical across two consecutive loads ──────
idempotency_check() {
    bash -c '
        source main.bash; a="$PATH"
        source main.bash; b="$PATH"
        [[ "$a" == "$b" ]]
    ' >/dev/null 2>&1
}
check "idempotency (stable PATH on re-source)" idempotency_check

# ── 4. add_paths dedup: a repeated entry appears at most once ────────────────
add_paths_dedup_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_add-paths.bash
        add_paths /usr/bin
        add_paths /usr/bin
        n=$(grep -oc ":/usr/bin:" <<<":${PATH}:")
        (( n <= 1 ))
    ' >/dev/null 2>&1
}
check "add_paths dedup (/usr/bin once)" add_paths_dedup_check

# ── 5. TMPDIR test mode: helpers stay in scope when autorun is disabled ──────
tmpdir_testmode_check() {
    TMPDIR_NO_AUTORUN=1 bash -c '
        source conf.d/05_tmpdir.bash
        declare -F _pick_tmpdir >/dev/null
    ' >/dev/null 2>&1
}
check "tmpdir test-mode (_pick_tmpdir in scope)" tmpdir_testmode_check

# ── 6. Platform detection: forced OSTYPE yields the expected THEKP_FS ────────
platform_check() {
    local got
    got="$(OSTYPE=linux-gnu bash -c 'source conf.d/00_platform.bash; printf %s "$THEKP_FS"' 2>/dev/null)"
    [[ "$got" == "linux-gnu" ]]
}
check "platform detection (THEKP_FS=linux-gnu)" platform_check

# ── Summary ──────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────"
if (( _failures == 0 )); then
    echo "All checks passed."
    exit 0
fi
printf '%d check(s) failed.\n' "$_failures"
exit 1
