.PHONY: help link clean check test check-agent-role-sync check-guardrails-native-sync _link-codex-skills _clean-codex-skills

help:
	@printf '%s\n' \
		'link   - stow repository files and link Codex skills' \
		'clean  - silently remove only repository-owned links from HOME' \
		'test   - run isolated repository behavior tests' \
		'check  - run tests, agent-role drift checks, doctor, ShellCheck, and shfmt (Org agenda optional)'

link:
	stow --target="$(HOME)" --no-folding .
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

# The $HOME symlink sweep also removes codex skill links (they resolve into
# .agents/skills), so clean does not need _clean-codex-skills; the target is
# kept for tests/codex-skills-link-test.sh.
clean:
	@DOTFILES="$(CURDIR)" find "$(HOME)" \
		-path "$(HOME)/.local/share/containers" -prune -o \
		-path "$(CURDIR)" -prune -o \
		-type l -exec sh -c 'for link do target=$$(readlink -m "$$link"); case "$$target" in "$$DOTFILES"/*) rm "$$link"; rmdir -p --ignore-fail-on-non-empty "$${link%/*}" 2>/dev/null || true;; esac; done' sh {} +

_clean-codex-skills:
	@set -eu; \
	for d in "$(CURDIR)"/.agents/skills/*; do \
		name="$$(basename "$$d")"; \
		source="$$(readlink -f "$$d")"; \
		target="$(HOME)/.config/codex/skills/$$name"; \
		if [ -L "$$target" ] && [ "$$(readlink -f "$$target")" = "$$source" ]; then \
			rm "$$target"; \
		fi; \
	done

check: test check-agent-role-sync check-guardrails-native-sync
	./.local/scripts/dotfiles-doctor "$(CURDIR)"
	@SHELL_SCRIPTS="$$(find .local/scripts .config/srcup .config/pass-extensions .config/renv .config/git/hooks tests .claude/install-mcp.sh -type f \( -name '*.sh' -o -name '*.bash' -o -perm /111 \) 2>/dev/null | while IFS= read -r file; do \
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
	@bash tests/agent-checkpoint-test.sh
	@bash tests/codex-skills-link-test.sh
	@bash tests/renv-claude-test.sh
	@bash tests/renv-codex-test.sh
	@bash tests/renv-goose-test.sh
	@bash tests/renv-guardrails-preflight-test.sh
	@bash tests/renv-opencode-test.sh
	@bash tests/sandbox-agent-profile-test.sh
	@bash tests/sandbox-codex-profile-test.sh
	@bash tests/sandbox-env-test.sh
	@bash tests/sandbox-external-profile-test.sh
	@bash tests/deployment-lifecycle-test.sh
	@bash tests/dotfiles-doctor-org-test.sh
	@bun test ./.config/codex/hooks/guardrails.test.ts
	@bun test ./tests/guardrails-severity-test.ts

check-agent-role-sync:
	@python3 .agents/render-agent-roles.py --check

# Drift check for the hand-maintained native permission duplicates of
# .agents/guardrails/sensitive-paths.json. Claude mirrors credentials; Codex's
# guarded-workspace profile mirrors both credentials and machinery.
check-guardrails-native-sync:
	@set -eu; \
	paths_file="$(CURDIR)/.agents/guardrails/sensitive-paths.json"; \
	status=0; \
	credentials="$$(awk '/"credentials": \[/{f=1} f{print} f && /\]/{f=0}' "$$paths_file" | grep -o '"~[^"]*"' | tr -d '"')"; \
	machinery="$$(awk '/"machinery": \[/{f=1} f{print} f && /\]/{f=0}' "$$paths_file" | grep -o '"~[^"]*"' | tr -d '"')"; \
	if [ -z "$$credentials" ] || [ -z "$$machinery" ]; then \
		printf 'native-sync: extracted no %s paths from %s — the awk extraction depends on the current JSON formatting\n' \
			"$$([ -z "$$credentials" ] && echo credential || echo machinery)" "$$paths_file" >&2; \
		exit 1; \
	fi; \
	for p in $$credentials; do \
		grep -qF "$$p" "$(CURDIR)/.claude/settings.json" || { printf 'native permission drift: credential path %s missing from %s\n' "$$p" ".claude/settings.json" >&2; status=1; }; \
		grep -qF "$$p" "$(CURDIR)/.config/codex/config.toml.template" || { printf 'native permission drift: credential path %s missing from %s\n' "$$p" ".config/codex/config.toml.template" >&2; status=1; }; \
	done; \
	for p in $$machinery; do \
		grep -qF "$$p" "$(CURDIR)/.config/codex/config.toml.template" || { printf 'native permission drift: machinery path %s missing from %s\n' "$$p" ".config/codex/config.toml.template" >&2; status=1; }; \
	done; \
	exit "$$status"
