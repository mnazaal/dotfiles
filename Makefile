.PHONY: link clean check _link-codex-skills _clean-codex-skills

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

check:
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
