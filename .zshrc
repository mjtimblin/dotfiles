[[ ! -f ~/.shell_config/shell_environment ]] || source ~/.shell_config/shell_environment
[[ ! -f ~/.shell_config/shell_paths ]] || source ~/.shell_config/shell_paths
[[ ! -f ~/.shell_config/shell_aliases ]] || source ~/.shell_config/shell_aliases
[[ ! -f ~/.shell_config/shell_setup ]] || source ~/.shell_config/shell_setup
[[ ! -f ~/.shell_config/shell_local ]] || source ~/.shell_config/shell_local

setopt extendedglob
setopt auto_cd
setopt share_history
setopt hist_ignore_dups

HISTFILE=$HOME/.zsh_history
HISTSIZE=1000
SAVEHIST=1000

ZSH_THEME="peru_customized"  # https://github.com/JanDeDobbeleer/oh-my-posh/blob/main/themes/peru.omp.json
ZSH_PLUGINS=(
  colored-man-pages    # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/colored-man-pages
  docker               # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/docker
  docker-compose       # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/docker-compose
  git                  # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
  vscode               # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/vscode
  you-should-use       # https://github.com/MichaelAquilina/zsh-you-should-use
  zsh-autosuggestions  # https://github.com/zsh-users/zsh-autosuggestions
  git-open             # https://github.com/paulirish/git-open
  zsh-nvm              # https://github.com/lukechilds/zsh-nvm
)

if [[ "$PLATFORM" == "macos" ]]; then
  ZSH_PLUGINS+=( "macos" )  # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/macos
elif [[ "$PLATFORM" == "linux" ]]; then
  ZSH_PLUGINS+=( "ubuntu" )  # https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/ubuntu
fi

# Load plugins
for PLUGIN in "${ZSH_PLUGINS[@]}"; do
  source $ZSH_PLUGIN_DIR/$PLUGIN/$PLUGIN.plugin.zsh
done
unset PLUGIN

# Load oh-my-posh
eval "$(oh-my-posh init zsh --config $ZSH_THEME_DIR/$ZSH_THEME.omp.json)"

enable_poshtransientprompt

