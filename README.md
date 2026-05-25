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

## Meta

Authored and maintained by [Paul Kim](https://thekpaul.dev).

Distributed under the [MIT License](./LICENSE).

[dotfiles]: https://github.com/thekpaul/dotfiles
