# Bash Autoloaded Functions Subdirectory

This directory is a Fish-style function library, the analogue of Fish's
`~/.config/fish/functions/`.
It is loaded not by the [`../main.bash`](../main.bash) loader directly, but by
the autoloader [`../conf.d/01_autoload.bash`](../conf.d/01_autoload.bash),
which runs early in the core zone.

## Pairing Convention

Each file defines exactly one function, and the filename (minus `.bash`)
**must match the function name** — `functions/add_paths.bash` defines
`add_paths()`, just as Fish pairs `functions/NAME.fish` with `NAME`.
The autoloader relies on this pairing to map a stub to its definition file.

## Load Strategy

Loading is lazy.
A self-replacing stub is installed for each function; on its first call
the stub unsets itself, sources this file (defining the real function), then
dispatches to it — so the body is parsed exactly once, on first use.
This defers the parse cost and keeps non-interactive shells lean.

## Functions

- [add_paths](./add_paths.bash):
  Idempotent PATH-manipulation (the Bash analogue of Fish's `fish_add_path`)
  used by every later module that extends PATH.
  Shipped lazy: first consumed by `conf.d/02_defaults.bash` on startup, which
  demonstrates that the lazy path resolves correctly even mid-startup.
- [lsa](./lsa.bash):
  "List all" directory listing: prefers `eza`, falling back to
  a compatible `ls` per platform (branching on `THEKP_FS`).
- [lscd](./lscd.bash):
  Change directory and list the new location, via `lsa` when available.
- [mkcd](./mkcd.bash):
  Create a directory (parents included) and change into it.
- [rm](./rm.bash):
  Safer removal: offers a platform-appropriate Trash backend
  (`gio trash`, `trash-put`, `trash`, or `recycle`, keyed by `THEKP_FS`)
  with confirmation, falling back to `rm -i`;
  non-interactive shells pass through untouched.
- [tree](./tree.bash):
  Recursive tree listing: `eza`-backed through `lsa`, falling back to
  the real `tree` command.

## Authoring Conventions

- Begin with `# shellcheck shell=bash`, then
  a `# NAME.bash (autoloaded function)` line, a one-line purpose, and
  a short description.
- Define one function whose name matches the filename;
  keep helpers it needs private within the same file.
- Four-space indentation; the function must source standalone and
  pass `shellcheck -x` (configured in [`../.shellcheckrc`](../.shellcheckrc)).
- Write the body to be safe to re-source
  (re-sourcing must not duplicate state or cause harm), since
  the autoloader may re-run on a re-sourced shell.
