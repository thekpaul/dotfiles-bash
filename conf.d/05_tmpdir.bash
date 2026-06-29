# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 05: TMPDIR.bash
# Selects and exports a persistent, per-user TMPDIR, preferring
# fast tmpfs scratch space and falling back to on-disk locations, with
# sticky-bit hardening and an optional SELinux relabel.
#
# Selection order (Linux):
#
#   Phase 0: Validate and reuse an inherited TMPDIR if it is still good.
#   Phase 1: Scan tmpfs mounts.
#            Drop anything matching TMPDIR_BLACKLIST, then
#            rank the remainder by tier (highest first):
#              A: site-specific scratch —
#                 any writable tmpfs not in TMPDIR_GENERAL_TMPFS;
#              B: general-purpose tmpfs matching TMPDIR_GENERAL_TMPFS
#                 (typically /dev/shm).
#            Within the highest tier that has a candidate, pick the one with
#            the most effective space.
#   Phase 2: Create a persistent sticky public subdir on the winning mount.
#   Phase 3: Fall back to /var/tmp then /tmp on disk with the same permissions.
#   Phase 4: Last-resort /tmp/<user>-tmp guaranteed to emit a usable path.
#
# Directory setup, applied in order:
#
#   - Mode 1777 (public writable + sticky bit) set atomically via `install -d`.
#   - Optional SELinux type relabel via `chcon` (no root required).
#
# Platform handling:
#
#   - Linux: full selection logic above.
#   - macOS (darwin): defers to launchd's per-user TMPDIR under
#     /var/folders/<hash>/<hash>/T/,
#     which is already mode 0700 under SIP-protected /var/folders.
#     The Linux selection logic also depends on GNU coreutils options
#     (stat -c, df --output, install -d -m) absent from Darwin BSD tools, so
#     running it on macOS would fail mid-flight.
#   - Cygwin / MSYS: skipped entirely; native Windows temp handling applies.
#
# Idempotent: a previously selected TMPDIR that still validates is reused as-is
# (Phase 0), so re-sourcing converges on the same path without churn.
#
# Unit-test mode: set TMPDIR_NO_AUTORUN=1 before sourcing this file.
# On Linux, all helper functions and TMPDIR_* configuration variables remain
# in scope (the selection and cleanup blocks are skipped),
# allowing direct invocation in the same shell session:
#
#     TMPDIR_NO_AUTORUN=1 source conf.d/05_tmpdir.bash
#     declare -F _pick_tmpdir         # confirm helpers are in scope
#     _effective_avail_mb /tmp        # exercise directly
#
# This module may also be executed directly for a quick diagnostic;
# see the footer: `bash conf.d/05_tmpdir.bash` prints the resulting TMPDIR.
# ─────────────────────────────────────────────────────────────────────────────

_tmpdir_direct=0
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && _tmpdir_direct=1

case "${OSTYPE}" in
    cygwin|msys)
        # Skip entirely — native Windows temp handling applies.
        if (( _tmpdir_direct )); then
            printf 'TMPDIR -> %s\n' "${TMPDIR:-<unset>}"
            exit 0
        fi
        unset _tmpdir_direct
        return 0
        ;;

    darwin*)
        # macOS: trust launchd's per-user TMPDIR
        # (mode 0700, owner-only, under SIP-protected /var/folders).
        # Only fall back if launchd somehow failed
        # (corrupt user domain, rescue boot, etc.).
        # TMPDIR_NO_AUTORUN is honoured here for consistency even though
        # there are no testable helpers defined on this platform.
        if [[ -z "${TMPDIR_NO_AUTORUN:-}" ]]; then
            if [[ -n "$TMPDIR" && -d "$TMPDIR" && -w "$TMPDIR" ]]; then
                export TMPDIR
            else
                TMPDIR="/tmp/${USER:-$(id -un)}-tmp"
                mkdir -p  "$TMPDIR" 2>/dev/null
                chmod 0700 "$TMPDIR" 2>/dev/null
                export TMPDIR
            fi
        fi

        if (( _tmpdir_direct )); then
            printf 'TMPDIR -> %s\n' "${TMPDIR:-<unset>}"
            exit 0
        fi
        unset _tmpdir_direct
        return 0
        ;;
esac

# Linux (and any other POSIX platform not matched above): full selection.

# ── Configuration ────────────────────────────────────────────────────────────

# Minimum effective space (MiB) a candidate must offer to be viable.
TMPDIR_MIN_MB=1024

# SELinux type to apply to TMPDIR via chcon.
# Empty disables relabeling.
# user_tmp_t is the most broadly accessible label achievable without root under
# RHEL 8 targeted policy from an unconfined_t user domain.
#   Recommended:  "user_tmp_t"  (broad service-domain compatibility)
#   Alternative:  "tmp_t"       (often blocked for non-root chcon)
TMPDIR_SELINUX_TYPE=""

# tmpfs mount points considered "general-purpose" —
# system-shared spaces not dedicated to scratchpad usage.
# Phase 1 prefers any writable tmpfs OUTSIDE this list
# (site-specific /scratch, /tmp_local, etc.) if existing with enough space.
# Bash glob syntax; space-separated.
TMPDIR_GENERAL_TMPFS="/dev/shm /tmp /var/tmp /run /run/user/*"

# Mount points that should never be used as TMPDIR,
# regardless of writability, capacity, or tier classification.
# Filtered before tier assignment in Phase 1.
# Bash glob syntax; space-separated.
#
# Default entries:
#   /sys/*  /proc/*  pseudo-filesystems, never appropriate for TMPDIR.
#   /run/lock        system lock directory, sized for very small files.
#   /run/user/*      user runtime dirs.
#                    Your own ($XDG_RUNTIME_DIR) is torn down at
#                    last-session-end unless lingering is enabled
#                    (`loginctl enable-linger`);
#                    other users' would already fail the writability test,
#                    but this makes the policy explicit.
#
# To opt back in to your runtime dir after enabling linger,
# remove the /run/user/* glob from this list.
TMPDIR_BLACKLIST="/sys/* /proc/* /run/lock /run/user/*"

# ── Internal helpers ─────────────────────────────────────────────────────────

# _check_quota_avail_mb MOUNTPOINT
_check_quota_avail_mb() {
    local mountpoint="$1"

    command -v quota >/dev/null 2>&1 || return 1

    local qout
    qout="$(quota -f "$mountpoint" -w -p 2>/dev/null)" || return 1

    local used_kb='' limit_kb='' line
    local -a fields
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*(Filesystem|Disk[[:space:]]quotas) ]] && continue
        read -ra fields <<< "$line"
        (( ${#fields[@]} >= 4 )) || continue
        used_kb="${fields[1]%\*}"
        limit_kb="${fields[3]}"
        break
    done <<< "$qout"

    [[ -z "$limit_kb" ]] && return 1
    (( limit_kb == 0 ))  && return 1

    local avail_kb=$(( limit_kb - used_kb ))
    (( avail_kb < 0 )) && avail_kb=0

    echo $(( avail_kb / 1024 ))
}

# _effective_avail_mb PATH
_effective_avail_mb() {
    local path="$1"

    command -v df >/dev/null 2>&1 || return 1

    local info
    info="$(df --output=avail,size,fstype,target -m "$path" 2>/dev/null \
            | tail -1)"
    [[ -z "$info" ]] && return 1

    local fs_avail total_mb fstype mountpoint
    read -r fs_avail total_mb fstype mountpoint <<< "$info"
    [[ -z "$fs_avail" || -z "$mountpoint" ]] && return 1

    local quota_mb
    quota_mb="$(_check_quota_avail_mb "$mountpoint")"

    if [[ -n "$quota_mb" ]]; then
        (( quota_mb < fs_avail )) && echo "$quota_mb" || echo "$fs_avail"
    elif [[ "$fstype" == "tmpfs" ]]; then
        local courtesy_cap=$(( total_mb / 10 ))
        (( fs_avail < courtesy_cap )) && echo "$fs_avail" || echo "$courtesy_cap"
    else
        echo "$fs_avail"
    fi
}

# _selinux_active
# Returns 0 when /sys/fs/selinux/enforce is readable —
# i.e. SELinux-loaded kernel with selinuxfs pseudo-filesystem mounted —
# and 1 otherwise.
# Pure Bash; no fork, no dependency on the libselinux-utils package.
#
# Both enforcing and permissive modes count as "active" because
# file labelling still happens in permissive mode.
_selinux_active() {
    [[ -r /sys/fs/selinux/enforce ]]
}

# _mac_system
# Diagnostic-only: identifies the active mandatory-access-control LSM by
# inspecting /sys/kernel/security/lsm.
# Outputs one of:  selinux | apparmor | tomoyo | smack | none
_mac_system() {
    _selinux_active && { echo "selinux"; return 0; }

    [[ -r /sys/kernel/security/lsm ]] || { echo "none"; return 0; }
    local lsm_list
    read -r lsm_list < /sys/kernel/security/lsm 2>/dev/null

    # Sentinel commas avoid partial matches (e.g. "smackfs" vs "smack").
    case ",${lsm_list}," in
        *,apparmor,*) echo "apparmor" ;;
        *,tomoyo,*)   echo "tomoyo"   ;;
        *,smack,*)    echo "smack"    ;;
        *)            echo "none"     ;;
    esac
}

# _apply_selinux_label DIR
# Applies $TMPDIR_SELINUX_TYPE to DIR via chcon.
# No-op when the variable is empty, when SELinux is not active, or
# when chcon is unavailable.
# Failures are warnings only.
#
# Without root, chcon can only transition to types your current domain
# has a transition rule for.
# Under RHEL 8 targeted policy an "unconfined_u:unconfined_r:unconfined_t" user
# can typically reach user_tmp_t;
# attempts to reach tmp_t, httpd_tmp_t, etc. will fail.
_apply_selinux_label() {
    local dir="$1"

    [[ -n "$TMPDIR_SELINUX_TYPE" ]] || return 0
    _selinux_active                 || return 0

    command -v chcon >/dev/null 2>&1 || {
        printf '_pick_tmpdir: warning: chcon not found, skipping SELinux relabel\n' >&2
        return 1
    }

    if ! chcon -t "$TMPDIR_SELINUX_TYPE" "$dir" 2>/dev/null; then
        printf '_pick_tmpdir: warning: chcon -t %q on %s failed (transition not allowed?)\n' \
            "$TMPDIR_SELINUX_TYPE" "$dir" >&2
        return 1
    fi
}

# _secure_mkdir DIR
# Creates / repairs DIR with mode 1777 and applies the SELinux label.
# Each setup step is independent:
# failure of a later step does not roll back earlier successful ones.
_secure_mkdir() {
    local dir="$1"

    if [[ -d "$dir" ]]; then
        command -v stat >/dev/null 2>&1 || return 1

        local owner_uid
        owner_uid="$(stat -c '%u' "$dir" 2>/dev/null)"
        [[ "$owner_uid" == "$(id -u)" ]] || return 1

        chmod 1777 "$dir" 2>/dev/null || return 1
    else
        command -v install >/dev/null 2>&1 || return 1
        install -d -m 1777 "$dir" 2>/dev/null || return 1
    fi

    _apply_selinux_label "$dir"
    return 0
}

# _validate_existing_tmpdir
# Validates inherited TMPDIR; repairs mode and re-applies the SELinux label
# so configuration changes propagate without manual intervention.
_validate_existing_tmpdir() {
    local dir="$TMPDIR"

    [[ -n "$dir" ]] || return 1
    [[ -d "$dir" ]] || return 1
    [[ -w "$dir" ]] || return 1

    command -v stat >/dev/null 2>&1 || return 1

    local owner_uid
    owner_uid="$(stat -c '%u' "$dir" 2>/dev/null)"
    [[ "$owner_uid" == "$(id -u)" ]] || return 1

    local perms
    perms="$(stat -c '%a' "$dir" 2>/dev/null)"
    if [[ "$perms" != "1777" ]]; then
        chmod 1777 "$dir" 2>/dev/null || return 1
    fi

    local avail
    avail="$(_effective_avail_mb "$dir")" || return 1
    (( avail >= TMPDIR_MIN_MB ))           || return 1

    _apply_selinux_label "$dir"
    return 0
}

# _is_tmpfs_blacklisted MOUNTPOINT
# Returns 0 (true) if MOUNTPOINT matches any pattern in TMPDIR_BLACKLIST.
# Splits TMPDIR_BLACKLIST via `read -r -a` so configured globs like
# /sys/* and /proc/* are not pathname-expanded against the real filesystem
# during iteration; globbing only happens inside `[[ == $pat ]]`.
_is_tmpfs_blacklisted() {
    local mountpoint="$1"
    local -a patterns
    local pat
    read -r -a patterns <<< "$TMPDIR_BLACKLIST"
    for pat in "${patterns[@]}"; do
        # shellcheck disable=SC2053
        if [[ "$mountpoint" == $pat ]]; then
            return 0
        fi
    done
    return 1
}

# _classify_tmpfs MOUNTPOINT
# Outputs the priority tier of a tmpfs mountpoint:
#   A: site-specific scratch — writable tmpfs not in TMPDIR_GENERAL_TMPFS.
#   B: general-purpose tmpfs — matches a TMPDIR_GENERAL_TMPFS pattern
#      (typically /dev/shm).
# TMPDIR_GENERAL_TMPFS is split the same way as TMPDIR_BLACKLIST to
# suppress pathname expansion.
_classify_tmpfs() {
    local mountpoint="$1"
    local -a patterns
    local pat
    read -r -a patterns <<< "$TMPDIR_GENERAL_TMPFS"
    for pat in "${patterns[@]}"; do
        # shellcheck disable=SC2053
        if [[ "$mountpoint" == $pat ]]; then
            echo "B"
            return 0
        fi
    done
    echo "A"
}

# _pick_tmpdir
# Selection driver. Always emits a path.
_pick_tmpdir() {
    local best=""
    local best_a="" best_a_mb=0
    local best_b="" best_b_mb=0
    local mountpoint effective_mb tier _unused
    local user_slug="${USER:-$(id -un)}-tmp"
    local candidate dir fb_avail fallback

    if _validate_existing_tmpdir; then
        echo "$TMPDIR"
        return 0
    fi

    if command -v df >/dev/null 2>&1; then
        while read -r _unused mountpoint; do
            [[ -w "$mountpoint" ]] || continue
            _is_tmpfs_blacklisted "$mountpoint" && continue
            effective_mb="$(_effective_avail_mb "$mountpoint")" || continue
            (( effective_mb >= TMPDIR_MIN_MB )) || continue
            tier="$(_classify_tmpfs "$mountpoint")"
            case "$tier" in
                A)
                    if (( effective_mb > best_a_mb )); then
                        best_a="$mountpoint"
                        best_a_mb="$effective_mb"
                    fi
                    ;;
                B)
                    if (( effective_mb > best_b_mb )); then
                        best_b="$mountpoint"
                        best_b_mb="$effective_mb"
                    fi
                    ;;
            esac
        done < <(df --output=avail,target -m -t tmpfs 2>/dev/null | tail -n +2)

        # Prefer A → B; within the chosen tier, the largest already won.
        if   [[ -n "$best_a" ]]; then best="$best_a"
        elif [[ -n "$best_b" ]]; then best="$best_b"
        fi
    fi

    if [[ -n "$best" ]]; then
        dir="${best}/${user_slug}"
        if _secure_mkdir "$dir"; then
            echo "$dir"
            return 0
        fi
    fi

    for candidate in /var/tmp /tmp; do
        dir="${candidate}/${user_slug}"
        if _secure_mkdir "$dir"; then
            fb_avail="$(_effective_avail_mb "$dir")" || continue
            if (( fb_avail >= TMPDIR_MIN_MB )); then
                echo "$dir"
                return 0
            fi
        fi
    done

    fallback="/tmp/${user_slug}"
    _secure_mkdir "$fallback" 2>/dev/null || {
        mkdir -p "$fallback" 2>/dev/null
        chmod 1777 "$fallback" 2>/dev/null
    }
    echo "$fallback"
}

# ── Selection & cleanup ──────────────────────────────────────────────────────
# When TMPDIR_NO_AUTORUN is set, skip both selection and cleanup so
# all helpers and TMPDIR_* configuration variables remain in scope
# for the current shell session.
# This is the unit-test hook described in the header.
#
# Usage:
#     TMPDIR_NO_AUTORUN=1 source conf.d/05_tmpdir.bash
#     declare -F _pick_tmpdir         # confirm helpers are in scope
#     _effective_avail_mb /tmp        # exercise directly
if [[ -z "${TMPDIR_NO_AUTORUN:-}" ]]; then
    TMPDIR="$(_pick_tmpdir)"
    export TMPDIR

    unset -f _pick_tmpdir _validate_existing_tmpdir _effective_avail_mb \
        _check_quota_avail_mb _secure_mkdir _apply_selinux_label \
        _classify_tmpfs _is_tmpfs_blacklisted _selinux_active \
        _mac_system
    unset TMPDIR_MIN_MB TMPDIR_SELINUX_TYPE TMPDIR_GENERAL_TMPFS \
        TMPDIR_BLACKLIST
fi

# ── Direct execution: emit the selected TMPDIR as a basic diagnostic ─────────
# Sourced loads stay silent; running `bash conf.d/05_tmpdir.bash` prints the
# resulting path (helpers have already been cleaned up by this point).
if (( _tmpdir_direct )); then
    printf 'TMPDIR -> %s\n' "${TMPDIR:-<unset>}"
else
    unset _tmpdir_direct
fi
