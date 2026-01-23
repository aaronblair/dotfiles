# Aaron's Dotfiles

Chezmoi-managed dotfiles for macOS and Linux environments.

## What's Included

- **Shell**: Zsh with Powerlevel10k prompt, Zim framework
- **Editor**: Neovim (LazyVim config)
- **Terminal**: WezTerm (macOS), tmux
- **CLI Tools**: eza, fzf, zoxide, ripgrep, fd, lazygit, delta, htop

## Security Note for Container Usage

When used with Docker, chezmoi runs at **build time**. Dotfiles content and build args (`CHEZMOI_EMAIL`, `CHEZMOI_NAME`) are baked into image layers.

**Do not add to this repo:**
- API keys, passwords, or tokens
- Private SSH keys
- 1Password/Bitwarden template functions

This repo is safe for build-time usage—it contains only shell config, package lists, and non-sensitive templates.

## Quick Start

### macOS

1. Install Xcode CLI tools and Homebrew:
   ```sh
   xcode-select --install
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   eval $(/opt/homebrew/bin/brew shellenv)
   ```

2. Install and apply dotfiles:
   ```sh
   brew install chezmoi
   chezmoi init aaronblair --apply
   ```

### Linux / Docker

```sh
# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

# Set identity (optional)
export CHEZMOI_EMAIL=you@example.com
export CHEZMOI_NAME="Your Name"

# Apply dotfiles
chezmoi init aaronblair --apply
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
