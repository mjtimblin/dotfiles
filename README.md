# dotfiles

This repository currently contains dotfiles, config, themes, and plugins for bash, zsh, and vim.

## Installation

To install, clone the repository and run `./bin/install.sh`

## Updating Config

### Local Config

Local config are changes that are specific to the given machine. Examples of this could be changes to the path, initialization of tools or software for that machine only, and secrets stored in environment variables.

To update local config:

- Make the desired changes `~/.shell_config/shell_local` (or `~/.shell_config/shell_paths` for changes to path variables)
- Re-open the terminal for changes to take effect

### Shared Config

Shared config are changes that should affect all machines. Examples of this could be new aliases, changes to the zsh theme, or new package manager environment variables.

To update shared config:

- Make the changes to the proper file in the repository (most changes will probably be in the `.shell_config` directory)
- Commit and push the changes using git
- Run `./bin/install.sh`
- Re-open the terminal for changes to take effect

Note: Never include secrets in shared config. Instead use a placeholder or empty string in the shared config, and overwrite the value using local config.

## Acknowledgments

Several zsh plugins (colored-man-pages, docker, docker-compose, git, macos, ubuntu, and vscode) were copied directly from [ohmyzsh's plugins](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins)

The peru theme (.zsh_custom/themes/peru.omp.json) was taken from [oh-my-posh's themes](https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/peru.omp.json). The peru_customized theme (.zsh_custom/themes/peru_customized.omp.json) is the peru theme with a [transient prompt](https://ohmyposh.dev/docs/configuration/transient) added.

