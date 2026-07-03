ZPLUGINDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

_zplugin_load() {
    local url="$1"
    local name="${url:t}"
    local plugin_path="${ZPLUGINDIR}/${name}"

    if [[ ! -d "$plugin_path" ]]; then
        if ! command -v git >/dev/null 2>&1; then
            print -u2 "zplugin: skipping ${name}: git not found"
            return 1
        fi
        mkdir -p "$ZPLUGINDIR"
        echo "Installing ${name}..."
        # Bound the clone so a blocked/flaky network (common on locked-down
        # HPC nodes) can't hang the whole login. Use timeout when available.
        local -a clone_cmd=(git clone --depth=1 "$url" "$plugin_path")
        command -v timeout >/dev/null 2>&1 && clone_cmd=(timeout 60 "${clone_cmd[@]}")
        "${clone_cmd[@]}" || {
            echo "ERROR: failed to install ${name}" >&2
            rm -rf "$plugin_path" # don't leave a broken partial clone
            return 1
        }
    fi

    local init_file="${plugin_path}/${name}.plugin.zsh"
    if [[ ! -r "$init_file" ]]; then
        print -u2 "zplugin: no init file found for ${name} (looked for ${init_file})"
        return 1
    fi

    source "$init_file"
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

_zplugin_load https://github.com/aloxaf/fzf-tab
_zplugin_load https://github.com/jeffreytse/zsh-vi-mode
_zplugin_load https://github.com/zsh-users/zsh-syntax-highlighting
