ZPLUGINDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
ZPLUGIN_URLS=(
    https://github.com/aloxaf/fzf-tab
    https://github.com/jeffreytse/zsh-vi-mode
    https://github.com/zsh-users/zsh-syntax-highlighting
)

_zplugin_load() {
    local url="$1"
    local name="${url:t}"
    local plugin_path="${ZPLUGINDIR}/${name}"

    if [[ ! -d "$plugin_path" ]]; then
        print -u2 "zplugin: ${name} is not installed; run zplugin-install"
        return 0
    fi

    local init_file="${plugin_path}/${name}.plugin.zsh"
    if [[ ! -r "$init_file" ]]; then
        print -u2 "zplugin: no init file found for ${name} (looked for ${init_file})"
        return 1
    fi

    source "$init_file"
}

zplugin-install() {
    if ! command -v git >/dev/null 2>&1; then
        print -u2 'zplugin-install: git not found'
        return 1
    fi
    local url name plugin_path failed=0
    mkdir -p "$ZPLUGINDIR"
    for url in "${ZPLUGIN_URLS[@]}"; do
        name="${url:t}"
        plugin_path="${ZPLUGINDIR}/${name}"
        [[ -d "$plugin_path" ]] && continue
        print "Installing ${name}..."
        local -a clone_cmd=(git clone --depth=1 "$url" "$plugin_path")
        command -v timeout >/dev/null 2>&1 && clone_cmd=(timeout 60 "${clone_cmd[@]}")
        "${clone_cmd[@]}" || {
            print -u2 "ERROR: failed to install ${name}"
            rm -rf "$plugin_path"
            failed=$((failed + 1))
            continue
        }
        _zplugin_load "$url" || failed=$((failed + 1))
    done
    ((failed == 0))
}

zplugin-update() {
    if ! command -v git >/dev/null 2>&1; then
        print -u2 "zplugin-update: git not found"
        return 1
    fi
    local dir failed=0
    for dir in "${ZPLUGINDIR}"/*/; do
        [[ -d "${dir}/.git" ]] || continue # skip non-git dirs
        echo "Updating ${dir:t}..."
        git -C "$dir" pull --ff-only || {
            print -u2 "WARNING: failed to update ${dir:t}"
            ((failed++))
        }
    done
    ((failed == 0)) || print -u2 "zplugin-update: ${failed} plugin(s) failed to update"
}

for url in "${ZPLUGIN_URLS[@]}"; do
    _zplugin_load "$url"
done
