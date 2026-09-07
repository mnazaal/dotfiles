.PHONY: help link clean check test check-agent-role-sync check-guardrails-native-sync check-machinery-ro-sync check-skill-frontmatter

help:
	@printf '%s\n' \
		'link   - stow repository files' \
		'clean  - silently remove links this repository deployed (DEEP=1 also sweeps $$HOME for links left by renames)' \
		'test   - run isolated repository behavior tests' \
		'check  - run tests, agent-role drift checks, doctor, ShellCheck, and shfmt (Org agenda optional)'

link:
	stow --target="$(HOME)" --no-folding .

# Undo what link deployed, driven by the repository tree rather than by a walk
# of $HOME: stow removes its own links, and the rmdir pass clears directories
# --no-folding left behind.
#
# DEEP=1 adds a full sweep of $HOME for any link resolving into the repository.
# It walks every inode under $HOME, so it is not the everyday path; it catches
# the one case the steps above cannot see — links left behind when repository
# content is renamed or removed, which no longer correspond to anything stow
# knows about.
clean:
	@stow --target="$(HOME)" --no-folding -D .
	@cd "$(CURDIR)" && find . -mindepth 1 -depth -type d | sed 's|^\./||' | \
		while IFS= read -r dir; do rmdir "$(HOME)/$$dir" 2>/dev/null || true; done
	@if [ -n "$(DEEP)" ]; then \
		DOTFILES="$(CURDIR)" find "$(HOME)" \
			-path "$(CURDIR)" -prune -o \
			-type l -exec sh -c 'for link do target=$$(readlink -m "$$link"); case "$$target" in "$$DOTFILES"/*) rm "$$link"; rmdir -p --ignore-fail-on-non-empty "$${link%/*}" 2>/dev/null || true;; esac; done' sh {} +; \
	fi

check: test check-agent-role-sync check-guardrails-native-sync check-machinery-ro-sync check-skill-frontmatter
	./.local/scripts/dotfiles-doctor "$(CURDIR)"
	@SHELL_SCRIPTS="$$(find .local/scripts .config/pass-extensions .config/git/hooks tests .claude/install-mcp.sh -type f \( -name '*.sh' -o -name '*.bash' -o -perm /111 \) 2>/dev/null | while IFS= read -r file; do \
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
	@bash tests/guardrails-skill-state-test.sh
	@bash tests/pi-shim-test.sh
	@bash tests/sandbox-env-test.sh
	@bash tests/sandbox-profile-test.sh
	@bash tests/deployment-lifecycle-test.sh
	@bash tests/dotfiles-doctor-org-test.sh
	@bun test ./tests/guardrails-severity-test.ts

check-agent-role-sync:
	@python3 .agents/render-agent-roles.py --check

# Drift check between the shared policy (what the hook enforces for BOTH agents)
# and Claude's own permission layers. Bidirectional: a path missing from
# settings.json leaves claude's typed tools uncovered, and a path settings.json
# denies but the policy omits leaves PI uncovered, since pi has no native layer.
check-guardrails-native-sync:
	@python3 .agents/guardrails/check-native-sync.py "$(CURDIR)"

# Drift check for the machinery paths the sandbox must pin read-only. Policy
# lists them in sensitive-paths.json; machinery-ro.profile is what enforces them
# at launch. A rename in one file and not the other unprotects the path with no
# symptom: the sandbox silently drops binds whose source is missing, and most
# pins have no test of their own. Only ~/dotfiles entries are checked — the others are
# the stow-deployed links, whose targets these pins already cover.
check-machinery-ro-sync:
	@set -eu; \
	paths_file="$(CURDIR)/.agents/guardrails/sensitive-paths.json"; \
	profile="$(CURDIR)/.config/sandbox/machinery-ro.profile"; \
	status=0; \
	machinery="$$(awk '/"machinery": \[/{f=1} f{print} f && /\]/{f=0}' "$$paths_file" | grep -o '"~/dotfiles[^"]*"' | tr -d '"')"; \
	if [ -z "$$machinery" ]; then \
		printf 'machinery-ro-sync: extracted no ~/dotfiles machinery paths from %s — the awk extraction depends on the current JSON formatting\n' "$$paths_file" >&2; \
		exit 1; \
	fi; \
	pinned="$$(grep -v '^[[:space:]]*#' "$$profile")"; \
	for p in $$machinery; do \
		pin="$$(printf '%s' "$$p" | sed 's|^~|$$H|')"; \
		printf '%s\n' "$$pinned" | grep -qF "\"$$pin\"" || { printf 'machinery-ro drift: %s is policy-protected but not pinned read-only in machinery-ro.profile\n' "$$p" >&2; status=1; }; \
	done; \
	exit "$$status"

# Every skill's frontmatter must load as YAML with string values. The failure
# this catches is silent and per-file: pi parses strictly, so one unquoted
# `description: Use for X: y` drops THAT skill from routing with no error
# anywhere -- 29 of 39 were broken this way at once. Asserts the values LOAD as
# strings rather than grepping for quote characters, so any spelling that is
# genuinely valid passes and one that merely looks valid does not.
define SKILL_FRONTMATTER_PY
import glob, sys
try:
    import yaml
except ImportError:
    print("warn: PyYAML not installed; skipping skill-frontmatter check")
    sys.exit(0)
status = 0
files = sorted(glob.glob(".agents/skills/*/SKILL.md"))
if not files:
    print("skill-frontmatter: no SKILL.md files found -- wrong directory?", file=sys.stderr)
    sys.exit(1)
for f in files:
    text = open(f, encoding="utf-8").read()
    if not text.startswith("---\n"):
        print("skill-frontmatter: %s: no frontmatter block" % f, file=sys.stderr)
        status = 1
        continue
    try:
        data = yaml.safe_load(text.split("---\n", 2)[1])
    except yaml.YAMLError as e:
        print("skill-frontmatter: %s: not valid YAML (%s)" % (f, str(e).splitlines()[0]), file=sys.stderr)
        status = 1
        continue
    if not isinstance(data, dict):
        print("skill-frontmatter: %s: frontmatter is not a mapping" % f, file=sys.stderr)
        status = 1
        continue
    for key in ("name", "description"):
        if key not in data:
            print("skill-frontmatter: %s: missing %s" % (f, key), file=sys.stderr)
            status = 1
        elif not isinstance(data[key], str):
            print("skill-frontmatter: %s: %s loaded as %s, not a string -- quote it"
                  % (f, key, type(data[key]).__name__), file=sys.stderr)
            status = 1
sys.exit(status)
endef
export SKILL_FRONTMATTER_PY

check-skill-frontmatter:
	@python3 -c "$$SKILL_FRONTMATTER_PY"
