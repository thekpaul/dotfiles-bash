Bash Shell Submodule Repository
===

This repository tracks configurations for the Bash shell.

## Installation Methods

> [!IMPORTANT]
> While Bash shell sources its configuration from hard-coded paths such as
> `.bashrc` and `.bash_profile` from the user `$HOME` directory,
> this repository divides configurations by themed segments for modularity.
> Users will need to ensure that the partitioned configuration scripts are
> accessible by the loader scripts for them to be applied.

### Acquiring the Repository

Install this submodule repository at `$XDG_CONFIG_HOME/bash`:

> [!TIP]
> While not used by Bash shell, `$XDG_CONFIG_HOME` is used to store this
> repository for consistency with configurations for other targets.
> This environment variable (or its preferred default of `$HOME/.config`)
> will be used by the loader scripts to search for the partitioned scripts
> mentioned above.

#### Git Worktree

Create a new Git worktree from the submodule recursively cloned into your local
[dotfiles][dotfiles] installation to the destination path:
```sh
git worktree add $XDG_CONFIG_HOME/bash -b main --track <remote_name>/dotfiles-bash
```
where `remote_name` is the name of the "remote" repository from which your
"dotfiles" installation is cloned.

#### Standalone Installation from Remote

```sh
git clone https://github.com/thekpaul/dotfiles-bash.git $XDG_CONFIG_HOME/bash
```

#### (Sym)link from Local "dotfiles" Installation

- Unix-based systems where `ln` is available:
  ```sh
  ln -s <DOTFILES_INSTALLATION_PATH>/bash $XDG_CONFIG_HOME/bash
  ```
  Using the `-s` flag creates a "symbolic" ("soft") link, which is most likely
  to be the only type of link possible to create for directories on Unix-based
  systems.
  Omitting the `-s` flag creates a "hard" link, which is possible for
  **individual files**.
- Windows systems with PowerShell, using the `New-Item` cmdlet:
  ```pwsh
  New-Item -Path $env:XDG_CONFIG_HOME\bash -ItemType Junction -Value <DOTFILES_INSTALLATION_PATH>\bash
  ```
  `ItemType` may be changed to `HardLink` for **individual files** or
  `SymbolicLink` to create "shortcut"s ("symbolic" links).

Make sure to use the _full path_ for `<DOTFILES_INSTALLATION_PATH>`.

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
(sym)link to the file located in the original "dotfiles" installation path:
```sh
ln -s <DOTFILES_INSTALLATION_PATH>/bash/.bash{rc,_profile} ~
```
```pwsh
New-Item -Path $env:USERPROFILE\.bashrc       -ItemType HardLink -Value <DOTFILES_INSTALLATION_PATH>\bash\.bashrc
New-Item -Path $env:USERPROFILE\.bash_profile -ItemType HardLink -Value <DOTFILES_INSTALLATION_PATH>\bash\.bash_profile
```

## Meta

Authored and maintained by [Paul Kim](https://thekpaul.dev).

Distributed under the [MIT License](./LICENSE).

[dotfiles]: https://github.com/thekpaul/dotfiles
