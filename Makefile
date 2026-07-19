.PHONY: help link clean check test check-agent-role-sync check-guardrails-native-sync _link-codex-skills _clean-codex-skills

help:
	@printf '%s\n' \
		'link   - stow repository files and link Codex skills' \
		'clean  - remove repository-owned links from HOME' \
		'test   - run isolated repository behavior tests' \
		'check  - run tests, agent-role drift checks, doctor, ShellCheck, and shfmt'

link:
	stow --target="$(HOME)" --no-folding --ignore='^\.config/codex/skills($$|/)' .
	$(MAKE) _link-codex-skills

_link-codex-skills:
	@set -eu; \
	mkdir -p "$(HOME)/.config/codex/skills"; \
	for d in "$(CURDIR)"/.agents/skills/*; do \
		name="$$(basename "$$d")"; \
		source="$$(readlink -f "$$d")"; \
		target="$(HOME)/.config/codex/skills/$$name"; \
		if [ -e "$$target" ] && [ ! -L "$$target" ]; then \
			printf 'refusing to replace non-symlink Codex skill target: %s\n' "$$target" >&2; \
			exit 1; \
		fi; \
		if [ -L "$$target" ]; then rm "$$target"; fi; \
		ln -s "$$source" "$$target"; \
	done

clean:
	@$(MAKE) _clean-codex-skills
	@DOTFILES="$(CURDIR)" find "$(HOME)" \
		-path "$(HOME)/.local/share/containers" -prune -o \
		-xtype l -exec sh -c 'for link do target=$$(readlink -m "$$link"); case "$$target" in "$$DOTFILES"/*) printf "%s\n" "$$link"; rm "$$link"; rmdir -p --ignore-fail-on-non-empty "$${link%/*}" 2>/dev/null || true;; esac; done' sh {} +

_clean-codex-skills:
	@set -eu; \
	for d in "$(CURDIR)"/.agents/skills/*; do \
		name="$$(basename "$$d")"; \
		source="$$(readlink -f "$$d")"; \
		target="$(HOME)/.config/codex/skills/$$name"; \
		if [ -L "$$target" ] && [ "$$(readlink -f "$$target")" = "$$source" ]; then \
			printf "%s\n" "$$target"; \
			rm "$$target"; \
		fi; \
	done

check: test check-agent-role-sync check-guardrails-native-sync
	./.local/scripts/dotfiles-doctor "$(CURDIR)"
	@SHELL_SCRIPTS="$$(find .local/scripts .config/srcup .config/pass-extensions -type f \( -name '*.sh' -o -name '*.bash' -o -perm -111 \) 2>/dev/null | while IFS= read -r file; do \
		case "$$file" in *.sh|*.bash) printf '%s\n' "$$file"; continue ;; esac; \
		head -n 1 "$$file" | grep -Eq '^#!.*(sh|bash)' && printf '%s\n' "$$file"; \
	done | sort)"; \
	if command -v shellcheck >/dev/null 2>&1; then \
		if [ -n "$$SHELL_SCRIPTS" ]; then \
			shellcheck --severity=warning $$SHELL_SCRIPTS; \
		else \
			echo "warn: no shell scripts found for shellcheck"; \
		fi; \
	else \
		echo "warn: shellcheck not installed; skipping shellcheck"; \
	fi; \
	if command -v shfmt >/dev/null 2>&1; then \
		if [ -n "$$SHELL_SCRIPTS" ]; then \
			shfmt -d $$SHELL_SCRIPTS; \
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

test:
	@bash tests/codex-skills-link-test.sh

check-agent-role-sync:
	@python3 .agents/render-agent-roles.py --check

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
