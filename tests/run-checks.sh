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

# Creates a throwaway HOME + XDG_CONFIG_HOME tree with this repo symlinked in
# as the Bash config directory, so isolated bash invocations load *this* config
# without touching the real user's home or dotfiles.
# Echoes the tree's root path; caller is responsible for `rm -rf` on it.
setup_home() {
    local tmp
    tmp="$(mktemp -d)" || return 1
    mkdir -p "$tmp/home" "$tmp/config" || return 1
    ln -s "$REPO_ROOT" "$tmp/config/bash" || return 1
    ln -s "$REPO_ROOT/.bash_profile" "$tmp/home/.bash_profile" || return 1
    ln -s "$REPO_ROOT/.bashrc" "$tmp/home/.bashrc" || return 1
    printf '%s' "$tmp"
}

# Runs `bash` with HOME/XDG_CONFIG_HOME pointed at an isolated tree
# (built by setup_home) and HOSTNAME neutralised, so ./conf.d/80_pdk.bash's
# hostname gate stays closed even when this suite runs on a real pdk<N> host.
# Takes tree explicitly: several checks below make two invocations on one tree.
isolated_bash() {
    local tree="$1"; shift
    HOME="$tree/home" \
    XDG_CONFIG_HOME="$tree/config" \
    HOSTNAME=ci-neutral \
        bash "$@"
}

# Creates a throwaway directory containing symlinks to only the named binaries
# (resolved from the real PATH) and echoes its path.
# Used as the *entire* PATH for optional-tool/fallback checks
# (no /usr/bin:/bin suffix) so branch choices stay deterministic everywhere —
# a stray /usr/bin/tree or eza cannot flip a fallback branch.
make_binder() {
    local dir tool path
    dir="$(mktemp -d)" || return 1
    for tool in "$@"; do
        path="$(type -P "$tool")" || continue
        ln -s "$path" "$dir/$tool" || return 1
    done
    printf '%s' "$dir"
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

# ── 12. Login load: .bash_profile -> main.bash in non-interactive login shell
# EX_UNAVAILABLE is readonly but *not* exported, so seeing 69 in
# a fresh `bash -l -c` process proves main.bash was sourced in that same shell
# (the ssh-command path: `ssh host cmd` reaches only .bash_profile).
login_load_check() {
    local tmp out
    tmp="$(setup_home)" || return 1
    trap 'rm -rf "$tmp"; trap - RETURN' RETURN
    out="$(isolated_bash "$tmp" -l -c 'printf %s "${EX_UNAVAILABLE:-missing}"' 2>"$tmp/stderr.log")"
    [[ "$out" == "69" && ! -s "$tmp/stderr.log" ]]
}
check "login load (.bash_profile -> main.bash)" login_load_check

# ── 13. Non-interactive silence: no output leaks, .bashrc guard bails early ──
# (a) a non-interactive *login* shell (the ssh-command path) must
#     produce no output on either stream;
# (b) sourcing .bashrc directly in a non-interactive shell must
#     also produce no output — the interactive guard bails
#     before reaching main.bash, and the unexported THEKP_FS staying unset
#     proves main.bash was never reached.
noninteractive_silence_check() {
    local tmp out
    tmp="$(setup_home)" || return 1
    trap 'rm -rf "$tmp"; trap - RETURN' RETURN
    out="$(isolated_bash "$tmp" -l -c 'true' 2>&1)"
    [[ -z "$out" ]] || return 1
    out="$(isolated_bash "$tmp" -c 'source ~/.bashrc; printf %s "${THEKP_FS:-}"' 2>&1)"
    [[ -z "$out" ]]
}
check "non-interactive silence (login + .bashrc guard)" noninteractive_silence_check

# ── 14. lsa fallback: no eza on PATH -> GNU ls backend still lists entries ───
lsa_fallback_check() {
    local binder work out
    binder="$(make_binder bash ls)" || return 1
    work="$(mktemp -d)" || return 1
    trap 'rm -rf "$binder" "$work"; trap - RETURN' RETURN
    touch "$work/a" "$work/b" || return 1
    out="$(cd "$work" && PATH="$binder" bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        type -P eza >/dev/null && exit 1
        lsa
    ' 2>&1)"
    [[ "$out" == *"a"* && "$out" == *"b"* ]]
}
check "lsa fallback (no eza -> GNU ls)" lsa_fallback_check

# ── 15. lscd fallback: cd + list via the lsa fallback path end-to-end ────────
lscd_fallback_check() {
    local binder work out
    binder="$(make_binder bash ls)" || return 1
    work="$(mktemp -d)" || return 1
    trap 'rm -rf "$binder" "$work"; trap - RETURN' RETURN
    mkdir -p "$work/sub" || return 1
    touch "$work/sub/marker" || return 1
    out="$(cd "$work" && PATH="$binder" bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        lscd '"$work"'/sub && pwd
    ' 2>&1)"
    [[ "$out" == *"$work/sub"* && "$out" == *"marker"* ]]
}
check "lscd fallback (cd + GNU ls listing)" lscd_fallback_check

# ── 16. tree fallback: no eza, no real tree -> EX_UNAVAILABLE, no stdout ─────
tree_fallback_check() {
    local binder out rc
    binder="$(make_binder bash)" || return 1
    trap 'rm -rf "$binder"; trap - RETURN' RETURN
    out="$(PATH="$binder" bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        tree
    ' 2>/dev/null)"
    rc=$?
    [[ -z "$out" ]] && (( rc == 69 ))
}
check "tree fallback (no backend -> EX_UNAVAILABLE)" tree_fallback_check

# ── 17. vnclist: no ps -> EX_UNAVAILABLE; bad args -> EX_USAGE ───────────────
# Both are deterministic on every host: arg parsing runs before the `ps` probe
vnclist_check() {
    local binder rc
    binder="$(make_binder bash)" || return 1
    trap 'rm -rf "$binder"; trap - RETURN' RETURN
    PATH="$binder" bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        vnclist
    ' >/dev/null 2>&1
    rc=$?
    (( rc == 69 )) || return 1

    bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        vnclist bogus
    ' >/dev/null 2>&1
    rc=$?
    (( rc == 64 ))
}
check "vnclist (no ps -> EX_UNAVAILABLE; bad args -> EX_USAGE)" vnclist_check

# ── 18. vnclist parse: a fake `ps` exercises the VNC-line parse path ─────────
# The only way a VNC-free CI host can exercise the parser;
# deterministic onhosts that run Xvnc too, since the binder excludes real `ps`.
vnclist_parse_check() {
    local binder out
    binder="$(make_binder bash)" || return 1
    trap 'rm -rf "$binder"; trap - RETURN' RETURN

    cat > "$binder/ps" <<'FAKE_PS'
#!/bin/sh
printf 'USER       COMMAND\n'
printf 'alice      /usr/bin/Xvnc :7 -rfbport 5907 -auth /home/alice/.Xauthority\n'
FAKE_PS
    chmod +x "$binder/ps" || return 1

    out="$(PATH="$binder" bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        vnclist
    ' 2>&1)"
    [[ "$out" == *"7 (alice): 5907"* ]] || return 1

    cat > "$binder/ps" <<'FAKE_PS'
#!/bin/sh
printf 'USER       COMMAND\n'
printf 'bob        /usr/bin/bash\n'
FAKE_PS

    out="$(PATH="$binder" bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        vnclist
    ' 2>&1)"
    [[ "$out" == "No VNC servers currently running." ]]
}
check "vnclist parse (fake ps: VNC line, no-VNC line)" vnclist_parse_check

# ── 19. pdk: bad args -> EX_USAGE; no PDK dir -> EX_UNAVAILABLE ──────────────
# Degrades (returns success without asserting) on real PDK hosts, where
# /opt/mi-env/bin exists and the bare-call branch can't be exercised this way.
pdk_check() {
    bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        pdk one two
    ' >/dev/null 2>&1
    (( $? == 64 )) || return 1

    [[ -d /opt/mi-env/bin ]] && return 0

    bash -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/01_autoload.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        pdk
    ' >/dev/null 2>&1
    (( $? == 69 ))
}
check "pdk (bad args -> EX_USAGE; no PDK dir -> EX_UNAVAILABLE)" pdk_check

# ── 20. Prompt: exit-status marker set on failure, cleared on success ────────
# `bash -i` without a TTY emits job-control noise on stderr;
# judged by exit status only, both streams discarded.
# HISTFILE/TERM neutralise history-file and terminal-capability side effects of
# the forced interactive shell.
prompt_check() {
    HISTFILE=/dev/null TERM=dumb bash --norc -i -c '
        source '"$REPO_ROOT"'/conf.d/00_platform.bash
        source '"$REPO_ROOT"'/conf.d/09_sysexits.bash
        source '"$REPO_ROOT"'/conf.d/90_prompt.bash
        [[ "$PROMPT_COMMAND" == "_prompt_command" ]] || exit 1
        [[ "$PROMPT_DIRTRIM" == "3" ]] || exit 1
        false
        _prompt_command
        [[ "$PS1" == *"✘ 1 "* ]] || exit 1
        true
        _prompt_command
        [[ "$PS1" != *"✘"* ]] || exit 1
    ' </dev/null >/dev/null 2>&1
}
check "prompt (exit-status marker set then cleared)" prompt_check

# ── 21. sysexits: constants resolve correctly and are readonly ───────────────
# Same-shell assertion is mandatory: the constants are deliberately unexported.
sysexits_check() {
    bash -c '
        source ./main.bash
        [[ "$EX_USAGE" == "64" ]] || exit 1
        [[ "$EX_UNAVAILABLE" == "69" ]] || exit 1
        [[ "$EX_CONFIG" == "78" ]] || exit 1
        readonly -p | grep -q "EX_UNAVAILABLE="
    ' >/dev/null 2>&1
}
check "sysexits (constants correct and readonly)" sysexits_check

# ── Summary ──────────────────────────────────────────────────────────────────
echo "─────────────────────────────────────────"
if (( _failures == 0 )); then
    echo "All checks passed."
    exit 0
fi
printf '%d check(s) failed.\n' "$_failures"
exit 1
