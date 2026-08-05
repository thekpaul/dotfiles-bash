Bash Shell Configurations
===

This repository tracks configurations for the Bash shell.

## Installation Methods

Install this repository at `$XDG_CONFIG_HOME/bash`:

> [!IMPORTANT]
> While the Bash shell sources its configuration from hard-coded paths such as
> `.bashrc` and `.bash_profile` from the user `$HOME` directory,
> this repository divides configurations by themed segments for modularity.
> Although Bash itself does not use `$XDG_CONFIG_HOME`, this repository is
> stored there for consistency with configurations for other targets, and
> the loader scripts use it (or its preferred default of `$HOME/.config`)
> to search for the partitioned configuration scripts.
> Users will need to ensure that the partitioned configuration scripts are
> accessible by the loader scripts for them to be applied.

### Git Worktree (Recommended)

Create a new Git worktree from the submodule copy inside your
local superproject installation to the destination path:
```sh
git worktree add $XDG_CONFIG_HOME/bash -b main --track <remote_name>/main
```
where `remote_name` is the name of the "remote" repository from which
your superproject installation is cloned.

### Standalone Installation from Remote

```sh
git clone https://github.com/thekpaul/dotfiles-bash.git $XDG_CONFIG_HOME/bash
```

### (Sym)link from Local Superproject Installation (Not recommended)

> [!CAUTION]
> Modifications made through the link are committed from
> inside the superproject installation:
> with this repository integrated as a subtree, they land in
> the superproject's history instead of this repository, and
> with a submodule they leave the superproject's recorded pin unsynchronised.
> Prefer a worktree, which always commits to this repository directly.

- Unix-based systems where `ln` is available:
  ```sh
  ln -s <SUPERPROJECT_INSTALLATION_PATH>/bash $XDG_CONFIG_HOME/bash
  ```
  Using the `-s` flag creates a "symbolic" ("soft") link, which is
  most likely to be the only type of link possible to create for directories
  on Unix-based systems.
  Omitting the `-s` flag creates a "hard" link, which is
  possible for **individual files**.
- Windows systems with PowerShell, using the `New-Item` cmdlet:
  ```pwsh
  New-Item -Path $env:XDG_CONFIG_HOME\bash -ItemType Junction -Value <SUPERPROJECT_INSTALLATION_PATH>\bash
  ```
  `ItemType` may be changed to `HardLink` for **individual files** or
  `SymbolicLink` to create "shortcut"s ("symbolic" links).

Make sure to use the _full path_ for `<SUPERPROJECT_INSTALLATION_PATH>`.

### Deploying the Configuration Scripts

(Sym)linking `.bashrc` and `.bash_profile` to the user `$HOME` directory is
necessary for Bash shell to recognise the configuration scripts on startup.
- Unix-based systems where `ln` is available:
  ```sh
  ln -s $XDG_CONFIG_HOME/bash/.bash{rc,_profile} ~
  ```
  Using the `-s` flag creates a "symbolic" ("soft") link, while omitting the
  `-s` flag creates a "hard" link.
  Both are possible for individual files.
- Windows systems with PowerShell, using the `New-Item` cmdlet:
  ```pwsh
  New-Item -Path $env:USERPROFILE\.bashrc       -ItemType HardLink -Value $env:XDG_CONFIG_HOME\bash\.bashrc
  New-Item -Path $env:USERPROFILE\.bash_profile -ItemType HardLink -Value $env:XDG_CONFIG_HOME\bash\.bash_profile
  ```
  `ItemType` may be changed to `SymbolicLink` to create "shortcut"s
  ("symbolic" links).

If your `$XDG_CONFIG_HOME/bash` is already a (sym)link, you can directly
(sym)link to the file located in the original superproject installation path:
```sh
ln -s <SUPERPROJECT_INSTALLATION_PATH>/bash/.bash{rc,_profile} ~
```
```pwsh
New-Item -Path $env:USERPROFILE\.bashrc       -ItemType HardLink -Value <SUPERPROJECT_INSTALLATION_PATH>\bash\.bashrc
New-Item -Path $env:USERPROFILE\.bash_profile -ItemType HardLink -Value <SUPERPROJECT_INSTALLATION_PATH>\bash\.bash_profile
```

## Superproject Integration

Any superproject may import this repository in either of two ways —
the author's own [dotfiles][dotfiles] is one such superproject,
not a privileged one.
Both methods track the same `main` branch, and
neither changes how the configurations behave once installed.

### As a Submodule

```sh
git submodule add https://github.com/thekpaul/dotfiles-bash.git bash
```
The superproject pins an exact commit of this repository;
refresh the pin to the latest `main` with:
```sh
git submodule update --remote bash
```

### As a Subtree

```sh
git subtree add --prefix=bash https://github.com/thekpaul/dotfiles-bash.git main --squash
```
The configurations are copied into the superproject's own tree;
import later updates with:
```sh
git subtree pull --prefix=bash https://github.com/thekpaul/dotfiles-bash.git main --squash
```

## Structure

- `.bash_profile`: login-shell entry point — always sources `main.bash`, with
  no interactive guard, so non-interactive login shells (e.g. `ssh host cmd`)
  still receive the full environment setup.
- `.bashrc`: interactive-shell entry point — bails immediately for
  non-interactive shells, guards system-wide `bashrc` sourcing to
  prevent double-execution, then sources `main.bash`.
- [`main.bash`](./main.bash): the central loader sourced by both entry points.
  Carries a source-only guard (refuses to be executed directly) and
  globs `conf.d/[0-9][0-9]_*.bash` in lexicographic order;
  each module may `return` early without breaking the loop.
- [`conf.d/`](./conf.d/): numerically-prefixed scripts sourced on all sessions.
  See its [README](./conf.d/README.md) for the loading-order zones and
  module-authoring conventions.
- [`functions/`](./functions/): autoloaded functions, one per file
  (filename matches function name) — the Bash analogue of
  Fish's `functions/` directory, lazily loaded on first call.
  See its [README](./functions/README.md) for the full list.
- [`tests/`](./tests/): the check suite (`run-checks.sh`).

## Version Expectations

The version axis here is the **OS-shipped** Bash, not a package-manager-pinned
interpreter: this configuration targets whatever Bash a distribution ships.
Development floor is Bash **4.2** (CentOS 7); the configuration has
no version-gated internals, so the floor surfaces purely as
authoring constraints — `printf %q` in place of `${var@Q}`, no namerefs, and
similar 4.2-safe idioms throughout `conf.d/` and `functions/`.
CI's `centos7` leg (see below) enforces the floor directly, since
that container image itself ships bash 4.2.

## External Tool Assumptions

None of the following are required for the configuration to *load*;
each is probed at runtime, and absence degrades gracefully rather than erroring
(the suite's fallback checks exercise this pattern):

- `eza` — preferred backend for `lsa`, `lscd`, and `tree`;
  each falls back to a platform `ls` (GNU `ls`, or `gls` on macOS) or
  the real `tree` command, and errors with `EX_UNAVAILABLE` only when
  no backend exists at all.
- `gio` / `trash-put` / `trash` — enable trash-backed interactive `rm`
  (`gio trash` or `trash-put` on freedesktop platforms, `trash` on macOS,
  `recycle` on Cygwin/MSYS/Git Bash); falls back to
  a plain `rm -i` confirmation without one.
  Non-interactive shells bypass all of this and pass straight through to
  the real `rm`.
- `ps` — powers `vnclist`'s VNC-server detection;
  exits `EX_UNAVAILABLE` when unavailable.
- PDK environment — the `pdk` function exits `EX_UNAVAILABLE` when
  the host's PDK scripts directory (`/opt/mi-env/bin`) is missing, and
  `conf.d/80_pdk.bash`'s hostname gate (`pdk<N>`) is no-op on every other host.
- `pixi` — registered only when its install root exists under `LOCAL_OPT_HOME`;
  otherwise `conf.d/10_pixi.bash` is a no-op.
- Cargo (`~/.cargo/env`) — sourced only when present;
  otherwise `conf.d/20_cargo.bash` is a no-op.
- `nvim` — preferred as `EDITOR`/`VISUAL` when present, falling back to `vi`;
  a user-set `EDITOR` is always preserved.
- `cygpath` — normalises Windows-style paths on Cygwin/Git Bash
  (`add_paths`, `XDG_CONFIG_HOME`/`LOCAL_OPT_HOME` normalisation);
  falls back to the raw or `HOME`-derived path when absent.

## Testing

Run the check suite locally:
```sh
bash tests/run-checks.sh
```
This exercises syntax (`bash -n`), an isolated full load, login load, and
non-interactive-silence behaviour against throwaway `HOME`/ `XDG_CONFIG_HOME`
directories, the autoload machinery (stub swap, cd-safety, stub coverage),
minimal-PATH-binder fallbacks for `lsa`/`lscd`/ `tree`/`vnclist`/`pdk`, and
function behaviour (`mkcd`, `rm`, the interactive prompt, sysexits constants) —
no real shell state is touched.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on push and pull request
against `main`:
- **ShellCheck** — static analysis over `main.bash`, `conf.d/*.bash`, and
  `functions/*.bash` on a single `ubuntu-latest` runner
  (configuration in `.shellcheckrc`).
- **Sourceability matrix** — the check suite run against three
  OS-shipped Bash versions: `ubuntu-24.04` (bash 5.2, native),
  `redhat/ubi8` (bash 4.4, container), and `centos:7` (bash 4.2, container).
  Each container leg checks out the repository on the host first, since
  node24 actions cannot run under CentOS 7's glibc, then
  runs the suite inside the container via a bind mount.

## Meta

Authored and maintained by [Paul Kim](https://thekpaul.dev).

Distributed under the [MIT License](./LICENSE).

[dotfiles]: https://github.com/thekpaul/dotfiles
