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

### `10` - `19`: Runtime and Language Managers

This zone initializes environment managers such as Pixi, Nix, various tooling
version managers, and other systems that modify PATHs or provide runtime shims.
These scripts should load after core setup but before language- or
tool-specific configuration.

### `20` - `39`: Language- and Tool-Specific Environments

Scripts in this range configure individual ecosystems such as TeX, Ruby
tooling, Python utilities, Rust environments, or other domain-specific
development setups.
They assume that any underlying runtime managers are already loaded.

### `40` - `59`: System Integrations

These files configure integrations with system-level utilities—such as tmux,
SSH agents, editors, container tooling, or desktop-specific tweaks.
They typically enhance the shell's interaction with the wider operating system.

### `60` - `79`: UX Helpers and Utility Functions

This zone includes aliases, abbreviations, helper routines, conditional
functions, and other quality-of-life improvements.
These scripts may rely on previously configured tools and should remain
lightweight to avoid slowing startup.

### `80` - `89`: Host or Context-Specific Overrides

Files here provide behavior tailored to particular machines, operating systems,
environments, or work contexts.
These scripts are optional and may override or extend earlier configuration.

### `90` - `99`: Application-Specific or Experimental Modules

The final zone contains scripts that integrate personal tools, rare utilities,
legacy behavior, or experimental features.
They load last to ensure they can rely on the full environment.
