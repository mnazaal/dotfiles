: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
export XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME

umask 077

export LANG=en_US.UTF-8
# Only force LC_ALL if the locale is actually built on this host; otherwise
# minimal/HPC nodes spew "setlocale: cannot change locale" on every command.
# $+commands check is a zsh builtin (no fork); locale runs only when present.
if (( ${+commands[locale]} )) && locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
    export LC_ALL=en_US.UTF-8
fi

export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | (command -v bat >/dev/null 2>&1 && bat --paging=always --style=plain -l man || less)'"
export EDITOR=$(command -v nvim || command -v vim || command -v vi)
export VISUAL=$EDITOR
export COLORTERM=truecolor
export GPG_TTY=$TTY

export XCURSOR_PATH="/usr/share/icons:/usr/share/themes:$XDG_DATA_HOME/icons:$XDG_DATA_HOME/themes"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export PASSWORD_STORE_DIR="$XDG_DATA_HOME/pass"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true
export PASSWORD_STORE_EXTENSIONS_DIR="$XDG_DATA_HOME/password-store/extensions"
export BASH_COMPLETION_USER_DIR="$XDG_DATA_HOME/bash-completion/completions"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export PYTHON_HISTORY="$XDG_STATE_HOME/python_history"
export PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME/python"
export PYTHONUSERBASE="$XDG_DATA_HOME/python"
export JUPYTER_PLATFORM_DIRS="$XDG_CONFIG_HOME/jupyter"
export UNISON="$XDG_DATA_HOME/unison"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export NPM_CONFIG_INIT_MODULE="$XDG_CONFIG_HOME/npm/config/npm-init.js"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export BUN_INSTALL="$XDG_DATA_HOME/bun"
export BROWSER="zen"
export MAMBA_EXE="$HOME/.local/bin/micromamba"
export MAMBA_ROOT_PREFIX="$XDG_DATA_HOME/micromamba"
export GOROOT="$HOME/.local/go"
export GOPATH="$XDG_DATA_HOME/go"
export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
export KERAS_HOME="$XDG_STATE_HOME/keras"
export TEXMFHOME="$XDG_DATA_HOME/texlive/texmf-local"
export TEXMFCONFIG="$XDG_CONFIG_HOME/texlive"
export TEXMFVAR="$XDG_CACHE_HOME/texlive"
export JULIAP_DEPOT_PATH="$XDG_DATA_HOME/juliap"

export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
export PI_OFFLINE=1
export PI_SKIP_VERSION_CHECK=1
export CODEX_HOME="$XDG_CONFIG_HOME/codex"

export PATH="$GOPATH/bin:$PATH"
export PATH="$CARGO_HOME/bin:$PATH"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/scripts:$PATH"
