# Agent Notes

This file is repo-local and ignored by Chezmoi; do not mirror it into managed dotfiles or expect it to apply on target machines.

This is a Chezmoi source repo for macOS and Linux dotfiles. Edit source files here, not generated files in `$HOME`.

## Chezmoi Workflow

- Resolve managed target paths with `chezmoi source-path ~/.zshrc` or `chezmoi source-path ~/.ssh/config` before editing from a target-file request.
- Prefer editing the source file directly; if a source file ends in `.tmpl`, preserve its Go template logic and do not replace it with rendered output.
- Do not use `chezmoi add` on templated files unless the user explicitly wants to discard the template attribute; copy or edit the `.tmpl` source instead.
- Validate dotfile changes with `chezmoi diff`; use `chezmoi apply --dry-run --verbose` before applying broad changes.
- Use `chezmoi cat <target>` to inspect rendered output for one managed file without modifying `$HOME`.
- For profile-sensitive changes, validate all supported profiles: `macos`, `server`, `dev`, and `ai`.
- After editing `.chezmoi.toml.tmpl`, run `chezmoi init --no-tty` to regenerate the local config, then rerun `chezmoi diff` and `chezmoi apply --dry-run --verbose`.
- Use `.chezmoi.toml.tmpl` data fields such as `.is_macos`, `.is_linux`, `.manages_opencode`, `.bootstraps_nvim`, and `.installs_zellij`; do not duplicate profile derivation in individual templates.

## Recommended Flow

- When making changes, aim to finish the full loop: edit source, validate rendered output, run `chezmoi diff`, and dry-run broad changes before stopping.
- If live application is the natural next step, recommend `chezmoi apply --verbose` and ask for approval before running it.
- After changes are applied, verify with `chezmoi diff` and `chezmoi verify`.
- Once the work is validated, recommend committing and pushing the completed change set. Only commit or push when the user explicitly requests it.
- Before committing, inspect `git status --short`, `git diff --find-renames`, and `git log --oneline -10`; stage only intended files.

## Common Commands

- Resolve source path: `chezmoi source-path ~/.zshrc`
- Inspect rendered target: `chezmoi cat ~/.zshrc`
- Check live drift: `chezmoi diff --no-pager`
- Dry-run apply: `chezmoi apply --dry-run --verbose --no-pager`
- Verify live state: `chezmoi verify --no-pager`
- Regenerate config after `.chezmoi.toml.tmpl`: `chezmoi init --no-tty`
- Review git changes: `git diff --find-renames`

## Source Naming

- Chezmoi prefixes are in use: `dot_` maps to a leading `.`, `private_` marks private targets, `run_once_*` scripts execute once, and `run_onchange_*` scripts rerun when their rendered contents change.
- Key templates are `.chezmoi.toml.tmpl`, `dot_zshrc.tmpl`, `dot_zprofile.tmpl`, and `dot_gitconfig.tmpl`.
- `private_dot_ssh/config` is managed source for `~/.ssh/config`; treat SSH changes as sensitive even though this file currently has no secrets.

## Platform Behavior

- `.chezmoi.toml.tmpl` sets explicit profile-driven data including `profile`, `is_macos`, `is_linux`, `has_display`, `is_server`, `is_dev`, and `is_ai`; `CHEZMOI_PROFILE`, `CHEZMOI_NAME`, and `CHEZMOI_EMAIL` drive the rendered config.
- Valid profiles are `macos`, `server`, `dev`, and `ai`; invalid profiles fail during config/template rendering.
- `CHEZMOI_HAS_DISPLAY` overrides display-target behavior independently of profile.
- `.chezmoitemplates/profile-guard.tmpl` is the shared fail-fast guard for profile-aware templates.
- `.chezmoiignore` is profile-aware and matches target paths, not source paths.
- macOS package setup is in `run_onchange_before_2-install-packages-darwin.sh.tmpl` using inline `brew bundle`; Linux setup is in `run_onchange_before_1-install-packages-linux.sh.tmpl` using `.chezmoidata/packages.yaml` plus `apt-get` or `apk`.
- Darwin-only shell paths in `dot_zshrc.tmpl` include Homebrew NVM, Java 17, Android SDK, Antigravity, and Bun; they apply only to the `macos` profile.
- External Powerlevel10k Meslo fonts are declared only for the `macos` profile in `.chezmoiexternal.toml.tmpl`.
- `.chezmoiremove.tmpl` removes trust-sensitive files when a profile no longer manages them.

## App Configs

- Neovim is a LazyVim config under `dot_config/nvim`; plugin overrides live in `dot_config/nvim/lua/plugins/`.
- Lua formatting convention for Neovim is in `dot_config/nvim/stylua.toml`: 2-space indents and 120 columns.
- `run_once_after_4-setup-nvim.sh.tmpl` bootstraps Neovim only for `macos`, `dev`, and `ai`, ignoring failures so bootstrap can continue.
- OpenCode config is managed under `dot_config/opencode`; its config denies tool access to `~/.config/env.d/**` because that directory is for local secrets.
- `dot_zshenv.tmpl` loads `~/.config/env.d/*.zsh` on all platforms; keep it quiet because zsh reads it for every invocation.
- `dot_config/zsh/functions/bifrost-vkey.zsh` provides `bifrost_vkey`; `dev` defaults to copying non-secret governance config from Bifrost virtual key `openclaw-main`.
- Do not read, print, edit, stage, or commit files under `~/.config/env.d/`; they are intentionally unmanaged local secret stores.
- Treat `private_dot_ssh/config`, `dot_config/gh/hosts.yml`, and OpenCode auth/provider config as sensitive when reading, printing, staging, or reviewing diffs.

## Repo Constraints

- `README.md`, `AGENTS.md`, repo-local agent/tooling directories, and `.gitignore` are ignored by Chezmoi and should not be expected to apply to target machines.
- `.chezmoitemplates/` contains source-only include templates for chezmoi rendering; it is not a managed target directory.
- Do not run `chezmoi apply` without user approval; it mutates the live home directory.
