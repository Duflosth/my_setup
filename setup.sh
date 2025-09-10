#!/bin/bash

# setup.sh - Configuration rapide pour nouvelles machines
# Usage: curl -fsSL https://raw.githubusercontent.com/[user]/dotfiles/main/setup.sh | bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Check for AWS Linux 2023 first
        if [ -f /etc/os-release ] && grep -q "Amazon Linux" /etc/os-release; then
            if grep -q "VERSION_ID=\"2023\"" /etc/os-release; then
                OS="al2023"
            else
                OS="amazon"
            fi
        elif command -v apt-get >/dev/null 2>&1; then
            OS="ubuntu"
        elif command -v dnf >/dev/null 2>&1; then
            # Could be Fedora, RHEL 8+, or other dnf-based
            if [ -f /etc/redhat-release ]; then
                OS="redhat"
            else
                OS="fedora"
            fi
        elif command -v yum >/dev/null 2>&1; then
            OS="centos"
        elif command -v pacman >/dev/null 2>&1; then
            OS="arch"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        error "OS non supporté: $OSTYPE"
    fi
    log "OS détecté: $OS"
    
    # Check curl situation early
    if command -v curl >/dev/null 2>&1; then
        if rpm -q curl-minimal >/dev/null 2>&1 || dpkg -l | grep -q "curl-minimal"; then
            log "curl-minimal détecté - sera préservé"
        else
            log "curl standard détecté"
        fi
    fi
}

# Fix curl for AL2023
fix_al2023_curl() {
    if rpm -q curl-minimal >/dev/null 2>&1; then
        log "Mise à jour de curl-minimal vers curl-full pour AL2023..."
        sudo dnf swap -y libcurl-minimal libcurl-full
        sudo dnf swap -y curl-minimal curl-full
    fi
}

# Install packages based on OS
install_packages() {
    log "Installation des packages essentiels..."
    
    case $OS in
        ubuntu)
            sudo apt-get update
            sudo apt-get install -y \
                git zsh curl wget vim neovim \
                htop tree unzip zip \
                build-essential software-properties-common \
                fzf ripgrep fd-find bat exa \
                docker.io docker-compose \
                nodejs npm python3 python3-pip
            ;;
        macos)
            # Install Homebrew if not present
            if ! command -v brew >/dev/null 2>&1; then
                log "Installation de Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install \
                git zsh curl wget vim neovim \
                htop tree unzip \
                fzf ripgrep fd bat exa \
                docker docker-compose \
                node python
            ;;
        al2023)
            # AWS Linux 2023 specific setup
            fix_al2023_curl
            
            sudo dnf update -y
            
            # Enable EPEL for additional packages
            sudo dnf install -y epel-release || true
            
            # Core packages
            sudo dnf install -y \
                git zsh curl wget vim \
                htop tree unzip zip \
                gcc gcc-c++ make \
                nodejs npm python3 python3-pip
            
            # Try to install modern tools, fallback gracefully
            sudo dnf install -y fzf ripgrep fd-find bat || warn "Certains outils modernes non disponibles"
            
            # Docker installation for AL2023
            sudo dnf install -y docker
            sudo systemctl enable docker
            sudo systemctl start docker
            sudo usermod -aG docker $USER
            
            # Docker Compose (install via pip if not available)
            if ! command -v docker-compose >/dev/null 2>&1; then
                pip3 install --user docker-compose
                export PATH="$HOME/.local/bin:$PATH"
            fi
            
            # Try to install neovim
            sudo dnf install -y neovim || warn "Neovim non disponible, vim sera utilisé"
            ;;
        redhat|fedora)
            sudo dnf update -y
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y \
                git zsh curl wget vim \
                htop tree unzip zip \
                fzf ripgrep fd-find bat \
                nodejs npm python3 python3-pip
            ;;
        centos)
            sudo yum update -y
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                git zsh curl wget vim \
                htop tree unzip zip \
                nodejs npm python3 python3-pip
            ;;
    esac
}

# Install Oh My Zsh
install_ohmyzsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log "Installation d'Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log "Oh My Zsh déjà installé"
    fi
}

# Install useful zsh plugins
install_zsh_plugins() {
    log "Installation des plugins zsh..."
    
    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
    
    # zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
    fi
    
    # fast-syntax-highlighting (alternative plus rapide)
    if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
        git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
    fi
    
    # powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
    fi
}

# Setup .zshrc with AL2023 considerations
setup_zshrc() {
    log "Configuration de .zshrc..."
    
    cat > $HOME/.zshrc << 'EOF'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
    git
    docker
    docker-compose
    sudo
    history
    copypath
    copybuffer
    dirhistory
    zsh-autosuggestions
    fast-syntax-highlighting
    fzf
    web-search
    extract
    copyfile
)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'
export LANG=en_US.UTF-8

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Modern alternatives (with fallbacks)
if command -v exa >/dev/null 2>&1; then
    alias ls='exa'
    alias ll='exa -la'
    alias tree='exa --tree'
fi

if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
elif command -v fd-find >/dev/null 2>&1; then
    alias find='fd-find'
fi

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Docker aliases
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
alias dcl='docker-compose logs'

# Development aliases
alias py='python3'
alias pip='pip3'

# FZF configuration
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
if command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
elif command -v find >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/\.git/*"'
fi

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

# Auto-completion
autoload -Uz compinit
compinit

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Custom functions
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Load local customizations if they exist
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF
}

# Setup vim configuration
setup_vim() {
    log "Configuration de vim..."
    
    cat > $HOME/.vimrc << 'EOF'
" Basic settings
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set hlsearch
set incsearch
set ignorecase
set smartcase
set showmatch
set ruler
set showcmd
set wildmenu
set scrolloff=5
set backspace=indent,eol,start

" Enable syntax highlighting
syntax on

" Color scheme
colorscheme desert

" Key mappings
nnoremap <C-n> :nohl<CR>
inoremap jj <Esc>

" Status line
set laststatus=2
set statusline=%F%m%r%h%w[%L][%{&ff}]%y[%p%%][%04l,%04v]
EOF
}

# Setup git configuration
setup_git() {
    log "Configuration de git..."
    
    # Only set if not already configured
    if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
        read -p "Nom pour git: " git_name
        git config --global user.name "$git_name"
    fi
    
    if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
        read -p "Email pour git: " git_email
        git config --global user.email "$git_email"
    fi
    
    # Global git configuration
    git config --global init.defaultBranch main
    git config --global core.editor vim
    git config --global color.ui auto
    git config --global push.default simple
    git config --global pull.rebase false
    
    # Useful aliases
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual '!gitk'
    git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
}

# Change default shell to zsh
change_shell() {
    if [ "$SHELL" != "$(which zsh)" ]; then
        log "Changement du shell par défaut vers zsh..."
        
        # Install util-linux-user if chsh is missing (AL2023 issue)
        if ! command -v chsh >/dev/null 2>&1; then
            log "Installation de util-linux-user pour chsh..."
            case $OS in
                al2023|redhat|fedora)
                    sudo dnf install -y util-linux-user
                    ;;
                centos)
                    sudo yum install -y util-linux-user
                    ;;
                ubuntu)
                    # chsh should be available by default
                    ;;
            esac
        fi
        
        if command -v chsh >/dev/null 2>&1; then
            # Try with sudo first (common on cloud instances)
            if sudo chsh -s $(which zsh) $USER; then
                warn "Le shell sera changé au prochain login"
            elif chsh -s $(which zsh) 2>/dev/null; then
                warn "Le shell sera changé au prochain login"
            else
                warn "Impossible de changer le shell avec chsh"
                log "Alternative: modification directe de /etc/passwd..."
                
                # Fallback: direct /etc/passwd modification
                if [ -w /etc/passwd ] || sudo -n true 2>/dev/null; then
                    sudo sed -i "s|^$USER:.*:|$USER:x:$(id -u):$(id -g):$USER:/home/$USER:$(which zsh)|" /etc/passwd
                    log "Shell modifié directement dans /etc/passwd"
                    warn "Le shell sera changé au prochain login"
                else
                    warn "Execute manuellement: sudo usermod -s $(which zsh) $USER"
                fi
            fi
        else
            warn "chsh non disponible. Execute: sudo usermod -s $(which zsh) $USER"
        fi
    else
        log "zsh est déjà le shell par défaut"
    fi
}

# Create useful directories
create_directories() {
    log "Création des répertoires utiles..."
    mkdir -p $HOME/{bin,scripts,projects,tmp}
    mkdir -p $HOME/.local/bin
}

# Post-installation messages
show_post_install_info() {
    log "✅ Configuration terminée!"
    echo
    log "🔄 Actions requises:"
    echo "1. Redémarre ton terminal ou execute: exec zsh"
    echo "2. Pour configurer le thème Powerlevel10k: p10k configure"
    
    if [ "$OS" = "al2023" ]; then
        echo "3. Tu peux avoir besoin de te déconnecter/reconnecter pour que Docker fonctionne"
        echo "4. Vérifie que docker fonctionne: docker --version"
    fi
    
    echo
    warn "Note: Certains outils modernes (exa, bat, etc.) peuvent ne pas être disponibles sur AL2023"
    warn "Le script les installera si possible, sinon utilisera les alternatives standard"
}

# Main execution
main() {
    log "🚀 Début de la configuration de la machine..."
    
    detect_os
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        error "Ne pas exécuter en tant que root"
    fi
    
    # Create directories first
    create_directories
    
    # Install packages
    install_packages
    
    # Setup zsh
    install_ohmyzsh
    install_zsh_plugins
    setup_zshrc
    
    # Setup other tools
    setup_vim
    setup_git
    
    # Change shell
    change_shell
    
    show_post_install_info
}

# Run main function
main "$@"
