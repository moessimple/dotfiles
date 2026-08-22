# Dotfiles directory
export DOTFILES_DIR=~/.dotfiles

# Oh My Zsh installation
export ZSH=~/.oh-my-zsh

# Oh My Zsh theme
ZSH_THEME="agnoster"

# Hide username in prompt
DEFAULT_USER=$(whoami)

# Use this dotfiles repository as Oh My Zsh's custom directory
ZSH_CUSTOM=$DOTFILES_DIR

# Oh My Zsh plugins
plugins=(git composer macos)

source $ZSH/oh-my-zsh.sh

# Auto-fix TTY corruption (caused by interactive programs like artisan prompts that exit uncleanly)
autoload -Uz add-zsh-hook
add-zsh-hook precmd _fix_tty
_fix_tty() { stty sane 2>/dev/null }

# Use the US English UTF-8 locale
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Load the shell dotfiles
for _dotfile in ~/.dotfiles/home/.{exports,paths,aliases,functions}; do
    [ -r "$_dotfile" ] && [ -f "$_dotfile" ] && source "$_dotfile"
done
unset _dotfile

# Load git functions (pickaxe-diff.sh is a diff driver invoked by search, not sourced)
for _git_fn in ~/.dotfiles/support/git/*.sh; do
    [[ "$_git_fn" == */pickaxe-diff.sh ]] && continue
    source "$_git_fn"
done
unset _git_fn

# Load machine-specific shell configuration
[ -r ~/.extra ] && [ -f ~/.extra ] && source ~/.extra

# Load SSH keys from Keychain
ssh-add --apple-load-keychain 2>/dev/null

if command -v fzf &>/dev/null; then
    eval "$(fzf --zsh)"
fi

if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# Enable autosuggestions (installed via brew)
if [ -f "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Herd injected PHP binary.
export PHP_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/:$PHP_INI_SCAN_DIR"

# Herd injected NVM configuration
export NVM_DIR="$HOME/Library/Application Support/Herd/config/nvm"

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

[[ -f "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh" ]] && builtin source "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh"

# Herd injected PHP binary.
export PATH="$HOME/Library/Application Support/Herd/bin/:$PATH"

export PATH=~/.local/bin:$PATH


# Herd injected PHP 8.4 configuration.
export HERD_PHP_84_INI_SCAN_DIR="/Users/maurice/Library/Application Support/Herd/config/php/84"


# Herd injected PHP 8.5 configuration.
export HERD_PHP_85_INI_SCAN_DIR="/Users/maurice/Library/Application Support/Herd/config/php/85"

# Herd injected PHP 8.6 configuration.
export HERD_PHP_86_INI_SCAN_DIR="/Users/maurice/Library/Application Support/Herd/config/php/86"
