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
    for f in conf.d/[0-9][0-9]_*.bash functions/*.bash; do
        [[ -e "$f" ]] || continue
        bash -n "$f" || { printf '  syntax error: %s\n' "$f" >&2; rc=1; }
    done
    return "$rc"
}
check "syntax (bash -n)" syntax_check

# ── 2. Full load: sourcing main.bash exits clean ─────────────────────────────
# Use the ./ path form: `source main.bash` (bare) is resolved via PATH,
# leaving BASH_SOURCE[0] without a slash so the loader's dir-relative glob
# matches nothing and loads zero modules.
# Real callers source by path.
load_check() {
    bash -c 'source ./main.bash' >/dev/null 2>&1
}
check "full load (source ./main.bash)" load_check

# ── 3. Idempotency: PATH is byte-identical across two consecutive loads ──────
idempotency_check() {
    bash -c '
        source ./main.bash; a="$PATH"
        source ./main.bash; b="$PATH"
        [[ "$a" == "$b" ]]
    ' >/dev/null 2>&1
}
check "idempotency (stable PATH on re-source)" idempotency_check

# ── 4. add_paths dedup: a repeated entry appears at most once ────────────────
# Also exercises the autoload path: 01_autoload installs the add_paths stub,
# and the first call below triggers the lazy source of functions/add_paths.bash.
add_paths_dedup_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_autoload.bash
        declare -F add_paths >/dev/null || exit 1   # stub installed
        add_paths /usr/bin                           # first call -> lazy load
        add_paths /usr/bin
        n=$(grep -oc ":/usr/bin:" <<<":${PATH}:")
        (( n <= 1 ))
    ' >/dev/null 2>&1
}
check "add_paths dedup + autoload (/usr/bin once)" add_paths_dedup_check

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

# ── 7. Autoload swap: stub before first call, real body after ────────────────
# Confirms the lazy mechanism actually defers the body: immediately after
# sourcing the loader, add_paths is the self-replacing stub (its definition
# mentions the source line); after one call it has been replaced by the real
# function (whose body contains the relative-path guard message).
autoload_swap_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_autoload.bash
        declare -f add_paths | grep -q "source " || exit 1   # stub present
        add_paths /nonexistent-dir-xyz >/dev/null 2>&1        # trigger load
        declare -f add_paths | grep -q "Refusing relative path" || exit 1
    ' >/dev/null 2>&1
}
check "autoload swap (stub -> real on first call)" autoload_swap_check

# ── 8. Autoload cd-safety: a stub still resolves after the CWD changes ───────
# The loader is sourced by relative path here, so
# this fails unless the stub froze an absolute file path.
autoload_cd_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_autoload.bash
        cd / || exit 1
        add_paths /usr/bin
        declare -f add_paths | grep -q "Refusing relative path"
    ' >/dev/null 2>&1
}
check "autoload cd-safety (stub loads after cd)" autoload_cd_check

# ── 9. Stub coverage: every functions/*.bash file gets an autoload stub ──────
stub_coverage_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_autoload.bash
        for f in functions/*.bash; do
            n="${f##*/}"; n="${n%.bash}"
            declare -F "$n" >/dev/null || exit 1
        done
    ' >/dev/null 2>&1
}
check "autoload stub coverage (all functions/*.bash)" stub_coverage_check

# ── 10. mkcd behaviour: creates a nested directory and enters it ─────────────
# Exercises a second function end-to-end through the lazy autoload path.
mkcd_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_autoload.bash
        tmp="$(mktemp -d)" || exit 1
        trap '\''rm -rf "$tmp"'\'' EXIT
        mkcd "$tmp/a/b" || exit 1
        [[ "$PWD" == "$tmp/a/b" ]]
    ' >/dev/null 2>&1
}
check "mkcd (creates nested dir and enters it)" mkcd_check

# ── 11. rm passthrough: non-interactive shells delete without prompting ──────
rm_passthrough_check() {
    bash -c '
        source conf.d/00_platform.bash
        source conf.d/01_autoload.bash
        tmp="$(mktemp)" || exit 1
        rm "$tmp" < /dev/null || exit 1
        [[ ! -e "$tmp" ]]
    ' >/dev/null 2>&1
}
check "rm passthrough (non-interactive, no prompt)" rm_passthrough_check

# ── Summary ──────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────"
if (( _failures == 0 )); then
    echo "All checks passed."
    exit 0
fi
printf '%d check(s) failed.\n' "$_failures"
exit 1
