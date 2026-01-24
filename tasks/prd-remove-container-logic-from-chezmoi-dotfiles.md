# PRD: Remove Container Logic from Chezmoi Dotfiles

## Overview
Clean up container-related logic from this chezmoi dotfiles repository. The dotfiles are now scoped to personal laptop and Linux server use cases only—no longer containers. This involves removing `/.dockerenv` file checks, `container` environment variable checks, and related documentation while preserving headless/SSH detection and toolbox display features.

## Goals
- Remove all "am I running inside a container" detection logic
- Simplify the `headless` variable to only check for DISPLAY
- Remove container-related documentation from README
- Keep toolbox p10k segment (displays when you've *entered* a toolbox)
- Keep Neovim dockerfile Treesitter parser (still editing Dockerfiles)
- Maintain working dotfiles for laptop + SSH-to-server use cases

## Quality Gates

These commands must pass for every user story:
- `chezmoi apply --dry-run` - Validates templates render correctly and source state is valid

## User Stories

### US-001: Simplify headless detection in chezmoidata
As a user, I want the `headless` variable to only check for DISPLAY so that container detection is removed but SSH-to-headless-server still works.

**Acceptance Criteria:**
- [ ] `.chezmoidata.yaml` headless logic removes `(stat "/.dockerenv")` check
- [ ] Headless is now simply `{{ not (env "DISPLAY") }}`
- [ ] Templates using `headless` continue to work correctly

### US-002: Remove container checks from verify-prereqs script
As a user, I want container detection removed from the prerequisites script so that container-specific logic is cleaned up.

**Acceptance Criteria:**
- [ ] `.chezmoiscripts/run_once_before_00-verify-prereqs.sh.tmpl` removes container detection
- [ ] Any conditional logic gated on container detection is removed or simplified
- [ ] Script still validates prerequisites for laptop/server use cases

### US-003: Remove container checks from gnome-settings script
As a user, I want container detection removed from the GNOME settings script so that it only checks for relevant conditions.

**Acceptance Criteria:**
- [ ] `.chezmoiscripts/run_onchange_after_10-gnome-settings.sh.tmpl` removes container checks
- [ ] Script still correctly skips on headless systems (no DISPLAY)
- [ ] Script still applies GNOME settings when DISPLAY is available

### US-004: Audit and clean remaining container references
As a user, I want all remaining container detection logic removed so that the codebase is consistent.

**Acceptance Criteria:**
- [ ] Search codebase for `dockerenv`, `container` env var checks, and similar patterns
- [ ] Remove any remaining container-specific conditionals
- [ ] Preserve toolbox-related display logic (p10k segment) as this shows container *entry*, not detection

### US-005: Update README documentation
As a user, I want README to reflect the current scope so that documentation is accurate.

**Acceptance Criteria:**
- [ ] Remove references to container/Codespaces support
- [ ] Remove any container-related setup instructions
- [ ] Ensure README accurately describes laptop + Linux server use case

## Functional Requirements
- FR-1: The `headless` variable must be `true` when DISPLAY is unset, `false` when DISPLAY is set
- FR-2: No chezmoi templates may reference `/.dockerenv` or check for container environment variables
- FR-3: Toolbox p10k segment configuration in `.p10k.zsh` must be preserved
- FR-4: Neovim Treesitter dockerfile parser configuration must be preserved
- FR-5: All templates must render successfully after changes

## Non-Goals
- Removing toolbox p10k segment (still useful for interactive container entry)
- Removing Dockerfile editing support (Neovim Treesitter parser)
- Changing SSH/headless behavior beyond removing container checks
- Adding new functionality

## Technical Considerations
- Chezmoi templates use Go template syntax
- The `stat` function checks for file existence
- The `env` function reads environment variables
- Changes affect template rendering, so `chezmoi apply --dry-run` validates correctness

## Success Metrics
- `chezmoi apply --dry-run` passes on both macOS laptop and Linux server
- No references to `dockerenv` or container env var checks remain in source
- README accurately reflects current scope
- Existing functionality (headless detection, GNOME settings, etc.) continues working

## Open Questions
- None - scope is well-defined