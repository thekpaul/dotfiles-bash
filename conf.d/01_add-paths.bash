# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 01: ADD-PATHS.bash
# Defines `add_paths`, the idempotent PATH-manipulation primitive
# used by every later module that extends PATH
# (the Bash analogue of Fish's built-in `fish_add_path`).
# Loaded early in the core zone so subsequent modules can rely on it.
# May later move into a dedicated `functions/` autoload directory.
#
# Idempotent: this module only defines a function;
# the function itself skips directories already present in PATH, so
# repeated calls never duplicate entries.
# Depends on: 00_platform.bash (THEKP_FS, consumed at call time for cygpath).
# ─────────────────────────────────────────────────────────────────────────────

# Add one or more directories to `PATH`, skipping any that don't exist or
# are already in `PATH`.
# Default: append.
# Use -p/--prepend to prepend.
# Use -v/--verbose for status messages on success/no-op (errors always print).
# Use --strict to make missing directories a failure rather than a silent skip.
# Returns the number of failures (0 if all OK, capped at 255).
add_paths() {
  local verbose=0
  local prepend=0
  local strict=0
  local usage="Usage: add_paths [-v|--verbose] [-p|--prepend] [--strict] <directory>..."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--verbose) verbose=1; shift ;;
      -p|--prepend) prepend=1; shift ;;
      --strict)     strict=1;  shift ;;
      -h|--help)    echo "${usage}"; return 0 ;;
      --)           shift; break ;;
      -*)
        echo "Unknown option: $1" >&2
        echo "${usage}" >&2
        return 2
        ;;
      *) break ;;
    esac
  done

  if [[ $# -eq 0 ]]; then
    echo "${usage}" >&2
    return 1
  fi

  # Deduplicate the input list while preserving left-to-right order
  local -a inputs=()
  local arg seen existing
  for arg in "$@"; do
    seen=0
    for existing in "${inputs[@]}"; do
      if [[ "$existing" == "$arg" ]]; then
        seen=1
        break
      fi
    done
    (( seen )) || inputs+=("$arg")
  done

  local failures=0

  # Build the list of directories to add.
  # We accumulate first, then splice into PATH in one operation so
  # prepend mode preserves left-to-right input order.
  local -a to_add=()
  local input dir

  for input in "${inputs[@]}"; do
    # Convert Windows-style paths to Unix-style on Windows-derived envs only
    case ${THEKP_FS} in
      cygwin|msys|git-windows)
        if command -v cygpath > /dev/null 2>&1; then
          dir="$(cygpath -u "$input")"
        else
          dir="$input"
        fi
        ;;
      *)
        dir="$input"
        ;;
    esac

    # Reject relative paths regardless of mode (security policy)
    if [[ "$dir" != /* ]]; then
      echo "Refusing relative path: $input" >&2
      (( failures++ ))
      continue
    fi

    # Strip trailing slashes
    while [[ "$dir" == */ ]]; do
      dir="${dir%/}"
    done

    if [[ ! -d "$dir" ]]; then
      if (( strict )); then
        echo "Directory does not exist: $dir" >&2
        (( failures++ ))
      else
        (( verbose )) && echo "Skipping (not found): $dir"
      fi
      continue
    fi

    # Check if already in PATH
    if [[ ":$PATH:" == *":$dir:"* ]]; then
      (( verbose )) && echo "$dir is already in PATH"
      continue
    fi

    # Check if already queued by an earlier iteration of this same call
    # (dedup against canonical form, so
    # trailing-slash variants of the same path collapse)
    local queued=0 q
    for q in "${to_add[@]}"; do
      if [[ "$q" == "$dir" ]]; then
        queued=1
        break
      fi
    done
    if (( queued )); then
      (( verbose )) && echo "$dir is already queued in this call"
      continue
    fi

    to_add+=("$dir")
  done

  # Splice the accumulated list into PATH preserving left-to-right ordering
  if (( ${#to_add[@]} > 0 )); then
    local joined
    printf -v joined '%s:' "${to_add[@]}"
    joined="${joined%:}"
    if (( prepend )); then
      export PATH="${joined}:${PATH}"
      (( verbose )) && echo "Prepended ${#to_add[@]} path(s): ${joined}"
    else
      export PATH="${PATH}:${joined}"
      (( verbose )) && echo "Appended ${#to_add[@]} path(s): ${joined}"
    fi
  fi

  # Cap return value at 255 (8-bit exit status)
  (( failures > 255 )) && failures=255
  return $failures
}
