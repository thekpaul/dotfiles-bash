# Bash Configuration Scripts Subdirectory

This directory contains configuration scripts sourced by the configuration
module loader script [`./main.bash`](../main.bash) on session startup.
Each file defines environment variables, paths, integrations, or
small utility functions that should be applied during session startup.

## Composition

Scripts are organized and numerically prefixed with double-digit numbers to
enforce a clear loading order; early files configure core shell behavior, while
later files integrate language runtimes, system tools, or user-specific
customizations.

### `00` - `09`: Core Configuration

Files in this range establish the fundamental shell environment, including PATH
construction, locale settings, default variables, keybindings, UI adjustments,
and other essential behavior that all subsequent scripts depend on.

- [00 Platform](./00_platform.bash):
  Detects the platform family into `THEKP_FS`; loads first so later modules can
  branch on it.
- [01 add_paths](./01_add-paths.bash):
  Idempotent PATH-manipulation primitive (the Bash analogue of Fish's
  `fish_add_path`) used by every later module that extends PATH.
- [02 Defaults](./02_defaults.bash):
  Base directories (`XDG_CONFIG_HOME`, `LOCAL_OPT_HOME`), the user binary
  directory on PATH, and `EDITOR`/`VISUAL`.
- [05 TMPDIR](./05_tmpdir.bash):
  Selects and exports a persistent, sticky-bit-hardened per-user `TMPDIR`,
  preferring fast tmpfs scratch space.
- [09 sysexits](./09_sysexits.bash):
  `sysexits.h` exit-status constants (`EX_*`) for use throughout this
  configuration.

### `10` - `19`: Runtime and Language Managers

This zone initializes environment managers such as Pixi, Nix, various tooling
version managers, and other systems that modify PATHs or provide runtime shims.
These scripts should load after core setup but before language- or
tool-specific configuration.

- [10 Pixi](./10_pixi.bash):
  Registers a Pixi installation and adds its global binary directory to PATH.

### `20` - `39`: Language- and Tool-Specific Environments

Scripts in this range configure individual ecosystems such as TeX, Ruby
tooling, Python utilities, Rust environments, or other domain-specific
development setups.
They assume that any underlying runtime managers are already loaded.

- [20 Cargo](./20_cargo.bash):
  Initialises the Rust toolchain environment from `~/.cargo/env`.

### `40` - `59`: System Integrations

These files configure integrations with system-level utilities—such as tmux,
SSH agents, editors, container tooling, or desktop-specific tweaks.
They typically enhance the shell's interaction with the wider operating system.

### `60` - `79`: UX Helpers and Utility Functions

This zone includes aliases, abbreviations, helper routines, conditional
functions, and other quality-of-life improvements.
These scripts may rely on previously configured tools and should remain
lightweight to avoid slowing startup.

- [65 Aliases](./65_aliases.bash):
  Interactive convenience aliases; skipped entirely in non-interactive shells.

### `80` - `89`: Host or Context-Specific Overrides

Files here provide behavior tailored to particular machines, operating systems,
environments, or work contexts.
These scripts are optional and may override or extend earlier configuration.

- [80 PDK](./80_pdk.bash):
  Host-specific overrides for laboratory PDK servers (site profile, umask).

### `90` - `99`: Application-Specific or Experimental Modules

The final zone contains scripts that integrate personal tools, rare utilities,
legacy behavior, or experimental features.
They load last to ensure they can rely on the full environment.

- [90 Prompt](./90_prompt.bash):
  Custom interactive prompt with a failed-command exit-status marker and a
  red root-session indicator.

## Authoring Conventions

New modules follow a small set of conventions so the suite stays reusable,
unit-testable, and idempotent:

- **Header.** Begin with `# shellcheck shell=bash`, then
  a `# NN: NAME.bash` line, a one-line purpose, and a short description
  covering behaviour, idempotency, prerequisites, and side-effects.
- **Indentation.** Four spaces for new modules.
- **Session guards.** Environment-only modules run unconditionally
  (so non-interactive login shells are configured too).
  Modules that emit output or only make sense interactively
  start with `[[ $- == *i* ]] || return`;
  host-specific modules return early when their host test fails.
- **Idempotency.** Re-sourcing must not duplicate state or cause harm:
  prefer set-if-unset assignments, route PATH additions through `add_paths`
  and guard `readonly` declarations so a second source does not abort.
- **Testability.** Every module must source standalone and pass `shellcheck -x`
  (configuration in [`../.shellcheckrc`](../.shellcheckrc)).
  Modules that auto-run side-effecting logic expose a `*_NO_AUTORUN` hook for
  in-scope testing, as in [`05_tmpdir.bash`](./05_tmpdir.bash).
