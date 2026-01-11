# JSH Makefile
# Automation for development, CI, and maintenance

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Paths
JSH_DIR := $(shell pwd)
LIB_DIR := $(JSH_DIR)/lib
CONFIG_DIR := $(JSH_DIR)/config
SRC_DIR := $(JSH_DIR)/src

# Colors
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Output helpers (matches src/core.sh style - colored text, no prefixes)
define print_info
@printf "$(CYAN)%s$(RESET)\n" "$(1)"
endef

define print_success
@printf "$(GREEN)%s$(RESET)\n" "$(1)"
endef

define print_warn
@printf "$(YELLOW)%s$(RESET)\n" "$(1)"
endef

define print_error
@printf "$(RED)%s$(RESET)\n" "$(1)" >&2
endef

# Prefixed output helpers (for status lists, validation results)
BLUE := \033[34m

define prefix_info
@printf "$(BLUE)◆$(RESET) %s\n" "$(1)"
endef

define prefix_success
@printf "$(GREEN)✔$(RESET) %s\n" "$(1)"
endef

define prefix_warn
@printf "$(YELLOW)⚠$(RESET) %s\n" "$(1)"
endef

define prefix_error
@printf "$(RED)✘$(RESET) %s\n" "$(1)" >&2
endef

# Lib components
NVIM_VERSION := 0.11.5
GITSTATUS_VERSION := v1.5.4
NVIM_PLATFORMS := linux-amd64:linux-x86_64 linux-arm64:linux-arm64 darwin-amd64:macos-x86_64 darwin-arm64:macos-arm64
GITSTATUS_PLATFORMS := linux-amd64:linux-x86_64 linux-arm64:linux-aarch64 darwin-amd64:darwin-x86_64 darwin-arm64:darwin-arm64
PLATFORMS := linux-amd64 linux-arm64 darwin-amd64 darwin-arm64

# Lib command defaults
ACTION ?= status
C ?= all

# Docker
DOCKER_IMAGE := jsh-test
DOCKER_FILE := docker/Dockerfile

# Helper: run command if tool exists
define run-if-exists
@if command -v $(1) >/dev/null 2>&1; then $(2); else printf "$(YELLOW)⚠$(RESET) $(1) not installed\n"; fi
endef

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help: ## Show this help
	@printf "\n$(CYAN)JSH Makefile$(RESET)\n\n"
	@printf "$(YELLOW)Usage:$(RESET) make [target]\n\n"
	@printf "$(YELLOW)Targets:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@printf "\n"

# =============================================================================
# Installation
# =============================================================================

.PHONY: install
install: submodules ## Install jsh (init submodules, link dotfiles)
	@./jsh install

.PHONY: uninstall
uninstall: ## Uninstall jsh (remove symlinks)
	@./jsh uninstall

.PHONY: submodules
submodules: ## Initialize/update git submodules
	$(call print_info,Initializing submodules...)
	@git submodule update --init --depth 1

.PHONY: update
update: ## Update jsh and all submodules
	$(call print_info,Updating jsh...)
	@git pull --rebase || true
	@git submodule update --remote --merge
	$(call print_success,Updated!)

# =============================================================================
# Development
# =============================================================================

.PHONY: lint
lint: ## Run all linting (pre-commit or fallback to shellcheck)
	$(call print_info,Linting...)
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit run --all-files; \
	else \
		$(MAKE) lint-shell lint-yaml; \
	fi

.PHONY: lint-shell
lint-shell: ## Lint shell scripts with shellcheck
	$(call run-if-exists,shellcheck,find $(SRC_DIR) -name "*.sh" -exec shellcheck -x {} \; && shellcheck -x jsh bin/jssh)

.PHONY: lint-yaml
lint-yaml: ## Lint YAML files with yamllint
	$(call run-if-exists,yamllint,yamllint --config-file .yamllint .)

.PHONY: fmt
fmt: ## Format code with prettier and shfmt
	$(call print_info,Formatting...)
	@if command -v shfmt >/dev/null 2>&1; then \
		find $(SRC_DIR) -name "*.sh" -exec shfmt -w -i 2 {} \; ; \
	fi
	@if command -v bunx >/dev/null 2>&1; then \
		bunx --bun prettier --write --ignore-unknown "**/*.{json,yaml,yml,md}" 2>/dev/null || true; \
	elif command -v npx >/dev/null 2>&1; then \
		npx --yes prettier --write --ignore-unknown "**/*.{json,yaml,yml,md}" 2>/dev/null || true; \
	fi

.PHONY: test
test: ## Run tests (requires Docker)
	@command -v docker >/dev/null 2>&1 || { printf "$(RED)✘$(RESET) Docker not installed\n" >&2; exit 1; }
	$(call print_info,Building Docker test image...)
	@docker build -t $(DOCKER_IMAGE) -f $(DOCKER_FILE) .
	$(call print_info,Testing jsh in Docker...)
	@docker run --rm -e JSH_TEST_SHELL=zsh -v "$(JSH_DIR):/home/testuser/.jsh:ro" $(DOCKER_IMAGE)
	@printf "\n"
	$(call print_success,All tests passed!)

.PHONY: pre-commit-install
pre-commit-install: ## Install pre-commit hooks
	$(call print_info,Installing pre-commit hooks...)
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install && pre-commit install --hook-type commit-msg; \
		printf "$(GREEN)✔$(RESET) Pre-commit hooks installed!\n"; \
	else \
		printf "$(YELLOW)⚠$(RESET) pre-commit not installed. Run: pip install pre-commit\n"; \
	fi

# =============================================================================
# Lib Management (ACTION=build|clean|status C=fzf|nvim|all)
# =============================================================================

.PHONY: lib
lib: ## Manage lib components (ACTION=build|clean|status C=fzf|nvim|all)
	@case "$(ACTION)" in \
		build) $(MAKE) --no-print-directory _lib-build-$(C);; \
		clean) $(MAKE) --no-print-directory _lib-clean-$(C);; \
		status|*) $(MAKE) --no-print-directory _lib-status;; \
	esac

# Internal build targets
.PHONY: _lib-build-all _lib-build-fzf _lib-build-nvim _lib-build-gitstatus
_lib-build-all: _lib-build-fzf _lib-build-nvim _lib-build-gitstatus
	$(call print_success,All lib components built!)

_lib-build-fzf:
	$(call print_info,Building fzf from source...)
	@command -v go >/dev/null 2>&1 || { printf "$(RED)✘$(RESET) Go not installed (requires 1.23+)\n" >&2; exit 1; }
	@mkdir -p $(LIB_DIR)/bin/{linux-amd64,linux-arm64,darwin-amd64,darwin-arm64}
	@cd $(LIB_DIR)/fzf && \
		VERSION=$$(git describe --tags --always 2>/dev/null || echo "dev") && \
		REVISION=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") && \
		printf "  $(YELLOW)Version: $$VERSION ($$REVISION)$(RESET)\n" && \
		for platform in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64; do \
			GOOS=$${platform%/*}; GOARCH=$${platform#*/}; \
			OUT="../bin/$${GOOS}-$${GOARCH}/fzf"; \
			printf "  $(YELLOW)$${GOOS}-$${GOARCH}$(RESET)\n"; \
			CGO_ENABLED=0 GOOS=$$GOOS GOARCH=$$GOARCH go build \
				-ldflags="-s -w -X main.version=$$VERSION -X main.revision=$$REVISION" \
				-o "$$OUT" . || exit 1; \
		done
	$(call print_success,fzf built!)

_lib-build-nvim:
	$(call print_info,Downloading nvim $(NVIM_VERSION)...)
	@mkdir -p $(LIB_DIR)/bin/{linux-amd64,linux-arm64,darwin-amd64,darwin-arm64}
	@for mapping in $(NVIM_PLATFORMS); do \
		platform=$${mapping%:*}; archive=$${mapping#*:}; \
		printf "  $(YELLOW)$$platform$(RESET)\n"; \
		rm -rf $(LIB_DIR)/bin/$$platform/nvim $(LIB_DIR)/bin/$$platform/nvim-lib $(LIB_DIR)/bin/$$platform/nvim-share; \
		curl -sL "https://github.com/neovim/neovim/releases/download/v$(NVIM_VERSION)/nvim-$$archive.tar.gz" | \
			tar -xz -C /tmp && \
			mv /tmp/nvim-$$archive/bin/nvim $(LIB_DIR)/bin/$$platform/ && \
			mv /tmp/nvim-$$archive/lib $(LIB_DIR)/bin/$$platform/nvim-lib && \
			mv /tmp/nvim-$$archive/share $(LIB_DIR)/bin/$$platform/nvim-share && \
			rm -rf /tmp/nvim-$$archive || exit 1; \
	done
	$(call print_success,nvim $(NVIM_VERSION) downloaded!)

_lib-build-gitstatus:
	$(call print_info,Downloading gitstatusd $(GITSTATUS_VERSION)...)
	@mkdir -p $(LIB_DIR)/bin/{linux-amd64,linux-arm64,darwin-amd64,darwin-arm64}
	@for mapping in $(GITSTATUS_PLATFORMS); do \
		platform=$${mapping%:*}; archive=$${mapping#*:}; \
		printf "  $(YELLOW)$$platform$(RESET)\n"; \
		curl -sL "https://github.com/romkatv/gitstatus/releases/download/$(GITSTATUS_VERSION)/gitstatusd-$$archive.tar.gz" | \
			tar -xz -C $(LIB_DIR)/bin/$$platform/ || exit 1; \
	done
	$(call print_success,gitstatusd $(GITSTATUS_VERSION) downloaded!)
	$(call print_warn,Update lib/p10k/gitstatus/build.info if version changed)

# Internal clean targets
.PHONY: _lib-clean-all _lib-clean-fzf _lib-clean-nvim _lib-clean-gitstatus
_lib-clean-all: _lib-clean-fzf _lib-clean-nvim _lib-clean-gitstatus
	$(call print_success,Lib binaries cleaned!)

_lib-clean-fzf:
	$(call print_info,Removing fzf binaries...)
	@rm -rf $(LIB_DIR)/bin/*/fzf

_lib-clean-nvim:
	$(call print_info,Removing nvim binaries...)
	@rm -rf $(LIB_DIR)/bin/*/nvim $(LIB_DIR)/bin/*/nvim-lib $(LIB_DIR)/bin/*/nvim-share

_lib-clean-gitstatus:
	$(call print_info,Removing gitstatusd binaries...)
	@rm -rf $(LIB_DIR)/bin/*/gitstatusd-*

# Internal status target
.PHONY: _lib-status
_lib-status:
	@printf "$(CYAN)Lib Components:$(RESET)\n"
	@printf "\n$(YELLOW)Submodules:$(RESET)\n"
	@git submodule status
	@printf "\n$(YELLOW)Binaries:$(RESET)\n"
	@for platform in $(PLATFORMS); do \
		printf "  $(YELLOW)$$platform:$(RESET)\n"; \
		for bin in fzf nvim; do \
			if [[ -f "$(LIB_DIR)/bin/$$platform/$$bin" ]]; then \
				size=$$(du -h "$(LIB_DIR)/bin/$$platform/$$bin" | cut -f1); \
				printf "    $(GREEN)✔$(RESET) $$bin ($$size)\n"; \
			else \
				printf "    $(RED)✘$(RESET) $$bin\n"; \
			fi; \
		done; \
		gitstatusd=$$(ls "$(LIB_DIR)/bin/$$platform"/gitstatusd-* 2>/dev/null | head -1); \
		if [[ -n "$$gitstatusd" ]]; then \
			size=$$(du -h "$$gitstatusd" | cut -f1); \
			printf "    $(GREEN)✔$(RESET) gitstatusd ($$size)\n"; \
		else \
			printf "    $(RED)✘$(RESET) gitstatusd\n"; \
		fi; \
	done

# =============================================================================
# Nvim Tools (for jssh offline support)
# =============================================================================

# blink.cmp version (from lazy-lock.json)
BLINK_VERSION := v1.7.0
BLINK_BASE_URL := https://github.com/Saghen/blink.cmp/releases/download/$(BLINK_VERSION)

.PHONY: nvim-tools
nvim-tools: nvim-tools-blink nvim-tools-mason ## Download nvim tools for offline jssh

.PHONY: nvim-tools-blink
nvim-tools-blink: ## Download blink.cmp fuzzy library for all platforms
	$(call print_info,Downloading blink.cmp $(BLINK_VERSION) fuzzy library...)
	@mkdir -p $(LIB_DIR)/nvim-data/blink.cmp/{darwin-arm64,darwin-amd64,linux-amd64,linux-arm64}
	@printf "  $(YELLOW)darwin-arm64$(RESET)\n"
	@curl -sL "$(BLINK_BASE_URL)/aarch64-apple-darwin.dylib" \
		-o $(LIB_DIR)/nvim-data/blink.cmp/darwin-arm64/libblink_cmp_fuzzy.dylib
	@printf "  $(YELLOW)darwin-amd64$(RESET)\n"
	@curl -sL "$(BLINK_BASE_URL)/x86_64-apple-darwin.dylib" \
		-o $(LIB_DIR)/nvim-data/blink.cmp/darwin-amd64/libblink_cmp_fuzzy.dylib
	@printf "  $(YELLOW)linux-amd64$(RESET)\n"
	@curl -sL "$(BLINK_BASE_URL)/x86_64-unknown-linux-gnu.so" \
		-o $(LIB_DIR)/nvim-data/blink.cmp/linux-amd64/libblink_cmp_fuzzy.so
	@printf "  $(YELLOW)linux-arm64$(RESET)\n"
	@curl -sL "$(BLINK_BASE_URL)/aarch64-unknown-linux-gnu.so" \
		-o $(LIB_DIR)/nvim-data/blink.cmp/linux-arm64/libblink_cmp_fuzzy.so
	$(call print_success,blink.cmp fuzzy library downloaded!)

.PHONY: nvim-tools-mason
nvim-tools-mason: ## Download mason tools for all platforms
	@$(JSH_DIR)/scripts/download-mason-tools.sh

.PHONY: nvim-tools-clean
nvim-tools-clean: ## Remove downloaded nvim tools
	$(call print_info,Removing nvim tools...)
	@rm -rf $(LIB_DIR)/nvim-data $(LIB_DIR)/mason-packages
	$(call print_success,nvim tools removed)

.PHONY: nvim-tools-status
nvim-tools-status: ## Show nvim tools status
	@printf "$(CYAN)Nvim Tools:$(RESET)\n"
	@printf "\n$(YELLOW)blink.cmp:$(RESET)\n"
	@for platform in $(PLATFORMS); do \
		if ls "$(LIB_DIR)/nvim-data/blink.cmp/$$platform/libblink_cmp_fuzzy"* >/dev/null 2>&1; then \
			size=$$(du -h "$(LIB_DIR)/nvim-data/blink.cmp/$$platform/"* 2>/dev/null | tail -1 | cut -f1); \
			printf "  $(GREEN)✔$(RESET) $$platform ($$size)\n"; \
		else \
			printf "  $(RED)✘$(RESET) $$platform\n"; \
		fi; \
	done
	@printf "\n$(YELLOW)mason-packages:$(RESET)\n"
	@for platform in $(PLATFORMS); do \
		if [[ -d "$(LIB_DIR)/mason-packages/$$platform" ]]; then \
			size=$$(du -sh "$(LIB_DIR)/mason-packages/$$platform" 2>/dev/null | cut -f1); \
			printf "  $(GREEN)✔$(RESET) $$platform ($$size)\n"; \
		else \
			printf "  $(RED)✘$(RESET) $$platform\n"; \
		fi; \
	done

# =============================================================================
# Build & Release
# =============================================================================

.PHONY: build
build: submodules ## Build (initialize everything)
	$(call print_success,Build complete)

.PHONY: release
release: ## Create a release (VERSION=x.y.z)
	@if [[ -z "$(VERSION)" ]]; then \
		printf "$(RED)✘$(RESET) VERSION not set. Use: make release VERSION=x.y.z\n" >&2; \
		exit 1; \
	fi
	$(call print_info,Creating release v$(VERSION)...)
	@git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	@git push origin "v$(VERSION)"
	$(call print_success,Released v$(VERSION))

# =============================================================================
# Utilities
# =============================================================================

.PHONY: status
status: ## Show jsh status
	@./jsh status

.PHONY: doctor
doctor: ## Run diagnostics
	@./jsh doctor

.PHONY: clean
clean: ## Clean caches and temporary files
	$(call print_info,Cleaning...)
	@rm -rf ~/.cache/jsh ~/.cache/jssh ~/.cache/zsh
	$(call print_success,Cleaned!)

.PHONY: shell
shell: ## Debug shell with JSH_DEBUG=1
	@JSH_DEBUG=1 $(SHELL)

.PHONY: install-tools
install-tools: ## Install development tools (linters, formatters)
	$(call print_info,Installing development tools...)
ifeq ($(shell uname), Darwin)
	@brew install shellcheck shfmt yamllint pre-commit || true
	@pip3 install --user pre-commit || true
else
	$(call print_warn,Install manually: shellcheck shfmt yamllint pre-commit)
endif
	$(call print_success,Done! Run 'make pre-commit-install' to set up git hooks)

.PHONY: docker-shell
docker-shell: ## Interactive Docker shell (SHELL_TYPE=zsh|bash)
	@command -v docker >/dev/null 2>&1 || { printf "$(RED)✘$(RESET) Docker not installed\n" >&2; exit 1; }
	@docker build -t $(DOCKER_IMAGE) -f $(DOCKER_FILE) . >/dev/null 2>&1
	$(call print_info,Launching interactive Docker shell...)
	@docker run --rm -it -e JSH_TEST_SHELL=$(or $(SHELL_TYPE),zsh) -v "$(JSH_DIR):/home/testuser/.jsh" $(DOCKER_IMAGE)

.PHONY: strategy
strategy: ## Generate/update commit strategy at .github/CHANGES.md
	$(call print_info,Analyzing changes...)
	@mkdir -p $(JSH_DIR)/.github
	@if [ -f "$(JSH_DIR)/.github/CHANGES.md" ]; then \
		claude --print "OUTPUT FORMAT: Raw markdown ONLY. No preamble, no 'Here is...', no questions, no commentary. \
Start directly with '# Commit Strategy' or similar heading. \
\
You are updating an existing commit strategy document. \
\
EXISTING DOCUMENT: \
$$(cat $(JSH_DIR)/.github/CHANGES.md) \
\
CURRENT GIT STATUS: \
$$(git status --porcelain) \
\
TASK: Update the existing document - do NOT replace it entirely. \
1. Preserve the existing structure, insights, and commit sequence \
2. Mark commits that have already been executed (check git log) as DONE \
3. Add any NEW changes detected in git status that are not yet covered \
4. Update file counts and metrics if they have changed \
5. Remove commits for changes that no longer exist \
6. Keep all helper sections (Partial Commits, Verification, etc.) \
7. Do NOT include Co-Authored-By footers in commit messages \
8. PARTIAL COMMITS ARE MANDATORY for modified files: \
   - For each 'M' file, inspect diff for multiple logical purposes \
   - If yes: use git diff -U0 + git apply --cached to split into separate commits \
   - If no: document WHY the entire file belongs to one commit \
   - Never use plain 'git add <file>' for modified files without justification \
\
If a commit has been partially completed, note which files remain. \
I will handle the actual git commands later and I expect being able to copy paste a partial file \
commit without issue. \
\
REMINDER: Output ONLY the markdown document. No conversational text." > $(JSH_DIR)/.github/CHANGES.md & \
		_pid=$$!; \
		frames='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'; \
		elapsed=0; \
		while kill -0 $$_pid 2>/dev/null; do \
			for frame in $$frames; do \
				kill -0 $$_pid 2>/dev/null || break 2; \
				elapsed=$$((elapsed + 1)); \
				printf '\r\033[36m%s Updating strategy... %ds\033[0m' "$$frame" "$$((elapsed / 10))"; \
				sleep 0.1; \
			done; \
		done; \
		printf '\r\033[K'; \
		wait $$_pid; \
	else \
		claude --print "OUTPUT FORMAT: Raw markdown ONLY. No preamble, no 'Here is...', no questions, no commentary. \
Start directly with '# Commit Strategy' heading. \
\
Generate a detailed commit strategy document for the current git changes. \
\
CURRENT GIT STATUS: \
$$(git status --porcelain) \
\
Requirements: \
1. Group changes logically by feature, component, or concern - NOT by conventional commit type \
2. Be verbose - highlight what each change introduces or improves \
3. Create granular commits (prefer more smaller commits over fewer large ones) \
4. For each commit provide a one-liner git command with 'git add' for the chunks/files/dirs/etc. \
and 'git commit' with conventional commit message \
5. Include multi-line commit bodies explaining the 'why' and listing affected files \
6. Order: cleanup/removal first, then infrastructure, then features, then config updates \
7. Include a summary table of key enhancements at the top \
\
PARTIAL COMMITS (MANDATORY FOR MODIFIED FILES): \
For each file marked 'M' (modified) in git status, you MUST: \
- Inspect the diff to identify if changes serve multiple logical purposes \
- If yes: use partial staging to split them into separate commits \
- If no: document WHY the entire file belongs to one commit \
\
Never use plain 'git add <file>' for modified files without justification. \
\
Techniques for partial staging: \
\
8. Line-range staging with git apply: \
   git diff -U0 <file> | head -n <end_line> | tail -n +<start_line> | git apply --cached \
   \
9. Hunk-based staging (extract specific diff hunks): \
   git diff <file> | awk '/^@@.*@@/{p=0} /<pattern>/{p=1} p||/^diff --git/' | git apply --cached \
   \
10. Stage-then-unstage workflow: \
    git add <file> && git diff --cached <file> | grep -v '<unwanted>' | git apply --cached -R \
    \
11. For each partial commit, include the EXACT git diff + git apply --cached pipeline \
\
Example partial commit block: \
\`\`\`bash \
# Stage only the function rename (lines 45-52) \
git diff -U0 src/core.sh | sed -n '1,/^@@/p; /rename_func/,/^@@/p' | git apply --cached \
git commit -m \"refactor(core): rename internal function\" \
\`\`\` \
\
Additional sections to include: \
- Partial Commits Reference: document git diff + sed/awk + git apply --cached patterns \
- Batch alternatives for simpler workflows (when atomicity is less critical) \
- Verification commands (git diff --cached --stat, git diff --cached <file>) \
\
Do NOT include Co-Authored-By footers in commit messages. \
Note: GitHub adds copy buttons to fenced code blocks automatically. \
Working directory: $(JSH_DIR) \
\
REMINDER: Output ONLY the markdown document. No conversational text." > $(JSH_DIR)/.github/CHANGES.md & \
		_pid=$$!; \
		frames='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏'; \
		elapsed=0; \
		while kill -0 $$_pid 2>/dev/null; do \
			for frame in $$frames; do \
				kill -0 $$_pid 2>/dev/null || break 2; \
				elapsed=$$((elapsed + 1)); \
				printf '\r\033[36m%s Generating strategy... %ds\033[0m' "$$frame" "$$((elapsed / 10))"; \
				sleep 0.1; \
			done; \
		done; \
		printf '\r\033[K'; \
		wait $$_pid; \
	fi
	$(call print_success,Strategy written to .github/CHANGES.md)

.PHONY: commit
commit: ## Interactive commit executor (fzf-based)
	@$(JSH_DIR)/scripts/commit-wizard.sh

.PHONY: commit-reset
commit-reset: ## Reset commit wizard state (start over)
	@$(JSH_DIR)/scripts/commit-wizard.sh --reset

.PHONY: commit-status
commit-status: ## Show which commits have been completed
	@$(JSH_DIR)/scripts/commit-wizard.sh --status
