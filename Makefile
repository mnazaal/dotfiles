.PHONY: link clean check check-agent-role-sync check-guardrails-native-sync _link-codex-skills _clean-codex-skills

link:
	stow --target="$(HOME)" --no-folding --ignore='^\.config/codex/skills($$|/)' .
	$(MAKE) _link-codex-skills

_link-codex-skills:
	@mkdir -p "$(HOME)/.config/codex/skills"
	@for d in "$(CURDIR)"/.agents/skills/*; do \
		name="$$(basename "$$d")"; \
		target="$(HOME)/.config/codex/skills/$$name"; \
		rm -rf "$$target"; \
		ln -s "../../../dotfiles/.agents/skills/$$name" "$$target"; \
	done

clean:
	@$(MAKE) _clean-codex-skills
	@DOTFILES="$(CURDIR)" find "$(HOME)" \
		-path "$(HOME)/.local/share/containers" -prune -o \
		-xtype l -exec sh -c 'for link do target=$$(readlink -m "$$link"); case "$$target" in "$$DOTFILES"/*) printf "%s\n" "$$link"; rm "$$link"; rmdir -p --ignore-fail-on-non-empty "$${link%/*}" 2>/dev/null || true;; esac; done' sh {} +

_clean-codex-skills:
	@for d in "$(CURDIR)"/.agents/skills/*; do \
		name="$$(basename "$$d")"; \
		target="$(HOME)/.config/codex/skills/$$name"; \
		if [ -L "$$target" ]; then \
			printf "%s\n" "$$target"; \
			rm "$$target"; \
		fi; \
	done

check: check-agent-role-sync check-guardrails-native-sync
	./.local/scripts/dotfiles-doctor "$(CURDIR)"
	@SHELL_SCRIPTS="$$(find .local/scripts .config/srcup .config/pass-extensions -type f \( -name '*.sh' -o -name '*.bash' -o -perm -111 \) 2>/dev/null | while IFS= read -r file; do \
		case "$$file" in *.sh|*.bash) printf '%s\n' "$$file"; continue ;; esac; \
		head -n 1 "$$file" | grep -Eq '^#!.*(sh|bash)' && printf '%s\n' "$$file"; \
	done | sort)"; \
	if command -v shellcheck >/dev/null 2>&1; then \
		if [ -n "$$SHELL_SCRIPTS" ]; then \
			shellcheck --severity=warning $$SHELL_SCRIPTS || echo "warn: shellcheck reported issues"; \
		else \
			echo "warn: no shell scripts found for shellcheck"; \
		fi; \
	else \
		echo "warn: shellcheck not installed; skipping shellcheck"; \
	fi; \
	if command -v shfmt >/dev/null 2>&1; then \
		if [ -n "$$SHELL_SCRIPTS" ]; then \
			SHFMT_FILES="$$(shfmt -l $$SHELL_SCRIPTS)"; \
			if [ -n "$$SHFMT_FILES" ]; then \
				echo "warn: shfmt would reformat:"; \
				printf '%s\n' "$$SHFMT_FILES"; \
			fi; \
		else \
			echo "warn: no shell scripts found for shfmt"; \
		fi; \
	else \
		echo "warn: shfmt not installed; skipping shfmt"; \
	fi

check-agent-role-sync:
	@set -eu; \
	ref_body=$$(mktemp); target_body=$$(mktemp); \
	trap 'rm -f "$$ref_body" "$$target_body"' EXIT; \
	body() { awk '/^---$$/ { delimiters++; next } delimiters >= 2 { print }' "$$1"; }; \
	status=0; \
	for role in brainstormer build docs-verify eval-review idea-critic plan research-strategist second-brain writer-critic; do \
		reference="$(CURDIR)/.claude/agents/$$role.md"; \
		body "$$reference" > "$$ref_body"; \
		for target in "$(CURDIR)/.config/opencode/agents/$$role.md"; do \
			body "$$target" > "$$target_body"; \
			if ! cmp -s "$$ref_body" "$$target_body"; then \
				printf 'agent role body drift: %s (%s)\n' "$$role" "$${target#$(CURDIR)/}" >&2; status=1; \
			fi; \
		done; \
		if [ "$$role" != build ] && [ "$$role" != plan ]; then \
			target="$(CURDIR)/.config/pi/agent/agents/$$role.md"; \
			body "$$target" > "$$target_body"; \
			if ! cmp -s "$$ref_body" "$$target_body"; then \
				printf 'agent role body drift: %s (%s)\n' "$$role" "$${target#$(CURDIR)/}" >&2; status=1; \
			fi; \
		fi; \
	done; \
	exit "$$status"

# Drift check for the hand-maintained duplicates of
# .agents/guardrails/sensitive-paths.json living in each agent's native
# permission config (Claude's settings.json, opencode's opencode.jsonc,
# Codex's config.toml.template). sensitive-paths.json is credentials +
# machinery; only Codex's [permissions.guarded-workspace.filesystem] table
# covers machinery natively, so machinery paths are only checked there.
check-guardrails-native-sync:
	@set -eu; \
	paths_file="$(CURDIR)/.agents/guardrails/sensitive-paths.json"; \
	status=0; \
	credentials="$$(awk '/"credentials": \[/{f=1} f{print} f && /\]/{f=0}' "$$paths_file" | grep -o '"~[^"]*"' | tr -d '"')"; \
	for p in $$credentials; do \
		grep -qF "$$p" "$(CURDIR)/.claude/settings.json" || { printf 'native permission drift: credential path %s missing from %s\n' "$$p" ".claude/settings.json" >&2; status=1; }; \
	done; \
	exit "$$status"
