.PHONY: help link clean check test session-entry check-agent-role-sync check-guardrails-native-sync check-machinery-ro-sync check-skill-frontmatter check-skill-spec check-pi-packages pi-packages

help:
	@printf '%s\n' \
		'link   - stow repository files' \
		'clean  - silently remove links this repository deployed (DEEP=1 also sweeps $$HOME for links left by renames)' \
		'test   - run isolated repository behavior tests' \
		'session-entry - point the GDM session at mango-session (needs root, once per machine)' \
		'check  - run tests, agent-role drift checks, doctor, ShellCheck, and shfmt (Org agenda optional)' \
		'pi-packages - install pi packages that settings.json declares but are missing'

# Deploying also brings the live crontab into step. stow only creates symlinks,
# and cron reads its own copy rather than the tracked file, so `make link` would
# otherwise leave the schedule describing the last hand-run `crontab` call.
# crontab-sync is idempotent and validates before installing.
#
# Guarded on HOME being the real login home: crontab is per-USER, not per-HOME,
# so an unguarded call would install this repository's crontab over the live one
# every time the test suite runs `make link HOME=<tmpdir>`.
link:
	stow --target="$(HOME)" --no-folding .
	@if [ "$(HOME)" = "$$(getent passwd "$$(id -un)" | cut -d: -f6)" ]; then \
		"$(HOME)/.local/scripts/crontab-sync"; \
	fi

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

# The one piece of this deployment that cannot be declarative: GDM reads only
# system session directories, so the entry naming the session is root-owned and
# outside this repository. Keeping the command here puts it in the repository
# instead of in someone's memory, and dotfiles-doctor warns whenever the live
# entry stops naming mango-session -- which a mango reinstall would do silently.
session-entry:
	sudo sed -i 's|^Exec=.*|Exec=$(HOME)/.local/scripts/mango-session|' /usr/share/wayland-sessions/mango.desktop
	@grep -n '^Exec=' /usr/share/wayland-sessions/mango.desktop

check: test check-agent-role-sync check-guardrails-native-sync check-machinery-ro-sync check-skill-frontmatter check-skill-spec check-pi-packages
	./.local/scripts/dotfiles-doctor "$(CURDIR)"
	@SHELL_SCRIPTS="$$(find .local/scripts .config/pass-extensions .config/git/hooks tests .claude/install-mcp.sh -type f \( -name '*.sh' -o -name '*.bash' -o -perm /111 \) 2>/dev/null | while IFS= read -r file; do \
		case "$$file" in *.sh|*.bash) printf '%s\n' "$$file"; continue ;; esac; \
		head -n 1 "$$file" | grep -Eq '^#!.*(sh|bash)' && printf '%s\n' "$$file"; \
	done | sort)"; \
	SC_STATUS=0; \
	if command -v shellcheck >/dev/null 2>&1; then \
		if [ -n "$$SHELL_SCRIPTS" ]; then \
			shellcheck --severity=warning $$SHELL_SCRIPTS || SC_STATUS=$$?; \
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
	fi; \
	if [ "$$SC_STATUS" -ne 0 ]; then \
		echo "ShellCheck reported findings above; 'make check' fails on them." >&2; \
		exit "$$SC_STATUS"; \
	fi

test:
	@bash tests/agent-checkpoint-test.sh
	@bash tests/guardrails-skill-state-test.sh
	@bash tests/pi-shim-test.sh
	@bash tests/git-hooks-confinement-test.sh
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
import glob, os, sys
try:
    import yaml
except ImportError:
    print("warn: PyYAML not installed; skipping skill-frontmatter check")
    sys.exit(0)
status = 0
# Enumerate DIRECTORIES, not SKILL.md files: globbing the file makes a skill
# whose SKILL.md is missing or misnamed invisible, which is precisely the
# silently-dropped-from-routing failure this check exists to catch.
dirs = sorted(d for d in glob.glob(".agents/skills/*") if os.path.isdir(d))
if not dirs:
    print("skill-frontmatter: no skill directories found -- wrong directory?", file=sys.stderr)
    sys.exit(1)
files = []
for d in dirs:
    f = os.path.join(d, "SKILL.md")
    if os.path.isfile(f):
        files.append(f)
    else:
        print("skill-frontmatter: %s: no SKILL.md (the skill cannot load)" % d, file=sys.stderr)
        status = 1
for f in files:
    text = open(f, encoding="utf-8").read()
    if not text.startswith("---\n"):
        print("skill-frontmatter: %s: no frontmatter block" % f, file=sys.stderr)
        status = 1
        continue
    # A block that is never closed makes split() hand back the whole file, which
    # then parses as YAML and passes. Require the closing delimiter.
    if len(text.split("---\n", 2)) < 3:
        print("skill-frontmatter: %s: frontmatter block is not closed" % f, file=sys.stderr)
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

# The Agent Skills spec's own validator, on top of the frontmatter check: name
# must equal the directory, no leading or doubled hyphens, description at most
# 1024 characters, compatibility at most 500. Both checks stay. This one needs
# uv and a cached package; the frontmatter check runs on bare python3 and also
# flags a description that parses as a non-string (a bare `yes`, a number),
# which is the shape of the failure that once dropped 29 of 39 skills from
# routing. One process for all skills: the CLI takes one directory per call, and
# forty `uv run` spawns cost about 16 s where the library call costs under one.
# Names, because they disagree: the PyPI distribution is `skills-ref`, the
# module is `skills_ref`, and the console script is `agentskills` -- the
# upstream README's `skills-ref validate` does not exist.
define SKILL_SPEC_PY
import glob, pathlib, sys
import skills_ref
status = 0
dirs = sorted(glob.glob(".agents/skills/*/"))
if not dirs:
    print("skill-spec: no skill directories found -- wrong directory?", file=sys.stderr)
    sys.exit(1)
for d in dirs:
    for err in skills_ref.validate(pathlib.Path(d)):
        print("skill-spec: %s: %s" % (d.rstrip("/"), err.splitlines()[0]), file=sys.stderr)
        status = 1
sys.exit(status)
endef
export SKILL_SPEC_PY

check-skill-spec:
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "warn: uv not installed; skipping skill-spec check"; exit 0; \
	fi; \
	uv run --quiet --no-project --with skills-ref -- python -c "$$SKILL_SPEC_PY"

# A `packages` entry in pi's settings.json DECLARES a package; it does not
# install one. pi auto-installs only for PROJECT settings (.pi/settings.json)
# after the project is trusted -- never for user settings -- so hand-editing the
# file leaves an entry that silently fetches nothing. Five entries sat that way
# for months here, including the one configured by the piClaudePermissions
# block, which made settings.json read as though a permission layer were in
# force when none was loaded.
#
# So the config cannot apply itself, and this pair is the substitute: the check
# makes the drift loud, and `make pi-packages` fixes it on a new machine or
# after editing the file. Both share one resolver so they cannot disagree about
# what "missing" means.
define PI_PACKAGES_PY
import json, os, shutil, sys

mode = sys.argv[1]
repo = os.environ.get("REPO") or "."
settings = os.path.join(repo, ".config/pi/agent/settings.json")

# pi finds its config from PI_CODING_AGENT_DIR and otherwise falls back to
# ~/.pi/agent, which is what it does on a machine that has not set the variable.
agent_dir = os.environ.get("PI_CODING_AGENT_DIR") or os.path.expanduser("~/.pi/agent")
node_modules = os.path.join(agent_dir, "npm", "node_modules")

if not os.path.exists(settings):
    sys.exit(0)
try:
    declared = (json.load(open(settings, encoding="utf-8")) or {}).get("packages") or []
except ValueError as e:
    print("pi-packages: %s is not valid JSON (%s)" % (settings, e), file=sys.stderr)
    sys.exit(1)
if not declared:
    sys.exit(0)

# Skip where pi is not in use on this machine. The gate must NOT be
# shutil.which("pi"): .local/scripts/pi is a shim THIS REPO DEPLOYS, so after
# `make link` the binary is always on PATH and the check failed on every
# deployed machine while skipping on undeployed ones -- exactly backwards, and
# the opposite of the intent stated above it. pi creates npm/ the first time it
# installs anything, so its presence is the honest signal that pi runs here.
if not os.path.isdir(os.path.join(agent_dir, "npm")):
    if mode == "check":
        print("warn: no pi package directory at %s; skipping pi-package check"
              % os.path.join(agent_dir, "npm"))
    sys.exit(0)

missing = []
unmappable = []
for entry in declared:
    source = entry if isinstance(entry, str) else (entry or {}).get("source")
    if not source:
        continue
    if not source.startswith("npm:"):
        # git:, https: and path sources do not map to a predictable directory
        # name, so their presence cannot be judged from the filesystem.
        unmappable.append(source)
        continue
    spec = source[4:]
    # Strip a trailing @version. A leading @ is a scope, not a version.
    at = spec.rfind("@")
    name = spec[:at] if at > 0 else spec
    if not os.path.isdir(os.path.join(node_modules, *name.split("/"))):
        missing.append(source)

if mode == "missing":
    for m in missing:
        print(m)
    sys.exit(0)

for u in unmappable:
    print("note: %s is not an npm source; presence not checked" % u)
if missing:
    print("pi-package drift: declared in settings.json but not installed:", file=sys.stderr)
    for m in missing:
        print("  %s" % m, file=sys.stderr)
    print("  a packages entry does not install anything -- run: make pi-packages", file=sys.stderr)
    sys.exit(1)
endef
export PI_PACKAGES_PY

check-pi-packages:
	@REPO="$(CURDIR)" python3 -c "$$PI_PACKAGES_PY" check

pi-packages:
	@set -e; \
	missing="$$(REPO="$(CURDIR)" python3 -c "$$PI_PACKAGES_PY" missing)"; \
	printf '%s\n' "$$missing" | while IFS= read -r src; do \
		[ -n "$$src" ] || continue; \
		printf 'installing %s\n' "$$src"; \
		pi install "$$src" || exit 1; \
	done
