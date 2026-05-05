# Agent Notes

This is a Chezmoi source repo for macOS and Linux dotfiles. Edit source files here, not generated files in `$HOME`.

## Chezmoi Workflow

- Resolve managed target paths with `chezmoi source-path ~/.zshrc` or `chezmoi source-path ~/.ssh/config` before editing from a target-file request.
- Prefer editing the source file directly; if a source file ends in `.tmpl`, preserve its Go template logic and do not replace it with rendered output.
- Do not use `chezmoi add` on templated files unless the user explicitly wants to discard the template attribute; copy or edit the `.tmpl` source instead.
- Validate dotfile changes with `chezmoi diff`; use `chezmoi apply --dry-run --verbose` before applying broad changes.
- Use `chezmoi cat <target>` to inspect rendered output for one managed file without modifying `$HOME`.

## Source Naming

- Chezmoi prefixes are in use: `dot_` maps to a leading `.`, `private_` marks private targets, and `run_once_*` scripts execute once during apply.
- Key templates are `.chezmoi.toml.tmpl`, `dot_zshrc.tmpl`, `dot_zprofile.tmpl`, and `dot_gitconfig.tmpl`.
- `private_dot_ssh/config` is managed source for `~/.ssh/config`; treat SSH changes as sensitive even though this file currently has no secrets.

## Platform Behavior

- `.chezmoi.toml.tmpl` sets `.fullname`, `.email`, and `.headless`; `CHEZMOI_NAME` and `CHEZMOI_EMAIL` override defaults.
- `.chezmoiignore` excludes Darwin-only targets on Linux and excludes `dot_wezterm.lua` when `DISPLAY` is unset.
- macOS package setup is in `run_once_before_2-install-packages-darwin.sh.tmpl` using inline `brew bundle`; Linux setup is in `run_once_before_1-install-packages-linux.sh.tmpl` using `apk` or `apt-get`.
- Darwin-only shell paths in `dot_zshrc.tmpl` include Homebrew NVM, Java 17, Android SDK, Antigravity, and Bun; keep Linux-safe shell edits outside Darwin template blocks.
- External Powerlevel10k Meslo fonts are declared only for Darwin in `.chezmoiexternal.toml.tmpl`.

## App Configs

- Neovim is a LazyVim config under `dot_config/nvim`; plugin overrides live in `dot_config/nvim/lua/plugins/`.
- Lua formatting convention for Neovim is in `dot_config/nvim/stylua.toml`: 2-space indents and 120 columns.
- `run_once_after_4-setup-nvim.sh.tmpl` runs headless Lazy sync and Tree-sitter installs, ignoring failures so bootstrap can continue.

## Repo Constraints

- `README.md`, `AGENTS.md`, repo-local agent/tooling directories, and `.gitignore` are ignored by Chezmoi and should not be expected to apply to target machines.
- Do not run `chezmoi apply` without user approval; it mutates the live home directory.
