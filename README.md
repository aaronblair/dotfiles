# Aaron's Dotfiles

Chezmoi-managed dotfiles for profile-driven macOS and Linux environments.

## Profiles

This repo uses `CHEZMOI_PROFILE` to decide what to install and manage.

| Profile | Purpose | Notes |
| --- | --- | --- |
| `macos` | Full daily desktop setup | Preserves the current desktop-oriented behavior. |
| `server` | Lean Linux admin environment | Minimal CLI/admin tooling, no OpenCode by default. |
| `dev` | Rich Linux admin/dev environment | Includes OpenCode, GitHub/dev tooling, SSH convenience config. |
| `ai` | Disposable Linux agent box | Includes OpenCode, but excludes personal SSH and GitHub trust config. |

`has_display` is separate from `profile` and defaults to `true` only for `macos`. Override it with `CHEZMOI_HAS_DISPLAY=true|false` if needed.

## What's Included

- **Shell**: Zsh with Powerlevel10k prompt, Zim framework
- **Editor**: Neovim (LazyVim config)
- **Terminal**: tmux everywhere, Zellij for `macos`, `dev`, and `ai`
- **CLI Tools**: eza, fzf, zoxide, ripgrep, fd, htop, jq, rsync
- **OpenCode**: managed under `~/.config/opencode` for `macos`, `dev`, and `ai`

## Infra Handoff

This repo assumes an infrastructure/bootstrap layer already:

- creates the machine
- creates the target user
- installs bootstrap prerequisites
- invokes `chezmoi` as the target user
- passes `CHEZMOI_PROFILE`, `CHEZMOI_NAME`, and `CHEZMOI_EMAIL`

Recommended env vars:

```sh
export CHEZMOI_PROFILE=dev
export CHEZMOI_NAME="Aaron Blair"
export CHEZMOI_EMAIL="aaron.blair@gmail.com"
```

Optional display override:

```sh
export CHEZMOI_HAS_DISPLAY=false
```

If `CHEZMOI_PROFILE` is not set, this repo currently defaults to `macos` on Darwin and `server` on Linux.

## Quick Start

### macOS

1. Install Xcode CLI tools and Homebrew:

   ```sh
   xcode-select --install
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

2. Apply the `macos` profile:

   ```sh
   brew install chezmoi
   export CHEZMOI_PROFILE=macos
   export CHEZMOI_NAME="Aaron Blair"
   export CHEZMOI_EMAIL="aaron.blair@gmail.com"
   chezmoi init aaronblair --apply
   ```

### Linux

```sh
# Install bootstrap prerequisites and chezmoi
if command -v apt-get >/dev/null 2>&1; then
  sudo env DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    apt-get install -y ca-certificates curl git
elif command -v apk >/dev/null 2>&1; then
  sudo apk add --no-cache ca-certificates curl git
fi
curl -fsLS get.chezmoi.io | sudo sh -s -- -b /usr/local/bin

# Choose a profile: server, dev, or ai
export CHEZMOI_PROFILE=dev
export CHEZMOI_NAME="Aaron Blair"
export CHEZMOI_EMAIL="aaron.blair@gmail.com"

# Apply dotfiles
chezmoi init aaronblair --apply
```

## Profile Behavior

### server

- lean Linux admin tooling
- no OpenCode by default
- no personal SSH traversal config
- no GitHub CLI auth state
- no automatic Neovim plugin bootstrap

### dev

- `server` tools plus richer dev tooling
- installs `uv`, `bun`, `opencode`, and `zellij`
- manages `~/.ssh/config`
- manages `~/.config/gh/*`
- bootstraps Neovim plugins and Tree-sitter parsers

### ai

- dev-capable Linux environment for disposable boxes
- installs `uv`, `bun`, `opencode`, and `zellij`
- does not manage personal SSH traversal config
- does not manage GitHub CLI auth/trust config
- keeps OpenCode config under `~/.config/opencode`

## Linux Package Flow

Linux packages are defined declaratively in `.chezmoidata/packages.yaml` and installed by `run_onchange_before_1-install-packages-linux.sh.tmpl`.

- package tier changes re-run cleanly on the next `chezmoi apply`
- `apt` and `apk` installs are best-effort for repo packages
- `uv`, `bun`, `opencode`, and `zellij` are installed by profile-aware installer logic for `dev` and `ai`

## Profile Switching

Profile changes can remove previously-managed files through `.chezmoiremove.tmpl`.

This is mainly used to clean up trust-sensitive state when moving away from `dev`/`macos`, including:

- `~/.ssh/config`
- `~/.config/gh/config.yml`
- `~/.config/gh/hosts.yml`
- `~/.config/opencode/`

## OpenCode

- managed config lives in `~/.config/opencode`
- enabled by default for `macos`, `dev`, and `ai`
- not installed by default for `server`
- shell shortcuts in `~/.zshrc`: `oc`, `occ`, `ocu`
- Context7 MCP is enabled only when `CONTEXT7_API_KEY` is present
- local secrets are loaded from `~/.config/env.d/*.zsh` on Linux profiles and denied to OpenCode tools by config
- `bifrost_vkey dev` creates a new Bifrost virtual key by copying non-secret governance settings from the existing `openclaw-main` virtual key

## Local Secrets

Secret values are intentionally not managed by Chezmoi. Put machine-local exports in `~/.config/env.d/*.zsh`; these files are sourced by zsh on Linux profiles before interactive startup.

Example local file:

```zsh
export CONTEXT7_API_KEY="..."
export BIFROST_BASE_URL="https://bifrost.example"
export BIFROST_ADMIN_TOKEN="..."
```

OpenCode is configured to deny read/edit/glob/grep/list access to `~/.config/env.d/**`. Do not commit those files or paste their contents into agent sessions.

### Bifrost Virtual Keys

The `bifrost_vkey` zsh helper lives at `~/.config/zsh/functions/bifrost-vkey.zsh` and is sourced from `~/.zshrc`.

Required local env:

```zsh
export BIFROST_BASE_URL="https://bifrost.example"
export BIFROST_ADMIN_TOKEN="..."
```

Default dev usage:

```zsh
bifrost_vkey dev
```

For the `dev` profile, the helper defaults to `--from openclaw-main`. It copies `provider_configs`, team/customer association, budget, rate limit, and key restrictions from that source key, then stores only the new virtual key value in `~/.config/env.d/opencode-bifrost.zsh`.

Useful variants:

```zsh
bifrost_vkey dev --dry-run
bifrost_vkey dev --from another-source-key
bifrost_vkey ai --from openclaw-main
```

Manual mode requires explicit provider configs and key IDs:

```zsh
export BIFROST_PROVIDER_CONFIGS_JSON_DEV='[{"provider":"openai","weight":1,"allowed_models":["gpt-4o-mini"]}]'
export BIFROST_KEY_IDS_JSON_DEV='["provider-key-id"]'
bifrost_vkey dev --no-source
```

## Existing Machines

If `.chezmoi.toml.tmpl` changes, regenerate the live Chezmoi config before relying on new template data:

```sh
chezmoi init
```

## macOS Post-Install

<details>
<summary>Expand for full macOS setup steps</summary>

### Set Hostname

```sh
sudo scutil --set HostName <hostname>
sudo scutil --set LocalHostName <hostname>
sudo scutil --set ComputerName <hostname>
dscacheutil -flushcache
sudo shutdown -r now
```

### System Permissions

Grant access before running chezmoi:

- System Settings → Privacy & Security → Full Disk Access → Add Terminal
- System Settings → Privacy & Security → App Management → Add Terminal

### SSH Key Setup

Generate a new key or restore from secure backup:

```sh
ssh-keygen -t ed25519 -C "your_email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
```

Add to GitHub: https://github.com/settings/keys

### Authenticate GitHub CLI

```sh
gh auth login
```

### Manual Tasks

- Enable FileVault: `sudo fdesetup enable`
- Grant Full Disk Access to Alfred, WezTerm
- Sign into apps (Bitwarden, Google Drive, Notion, Obsidian, Brave, VSCode)
- Disable unused keyboard shortcuts in System Settings
- (If doing mobile dev) Install Android Studio SDK

</details>
