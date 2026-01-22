# Aaron's .files

## Setup a new mac

1. Set hostname

   ```
   sudo scutil --set HostName <hostname>
   sudo scutil --set LocalHostName <hostname>
   sudo scutil --set ComputerName <hostname>
   dscacheutil -flushcache
   sudo shutdown -r now
   ```

2. Grant access to terminal to edit applications

    System Settings -> Privacy & Security -> Full Disk Access
    - Add terminal
    
    System Settings -> Privacy & Security -> App Management
    - Add Terminal

3. Install command line tools

   ```sh
   xcode-select --install
   ```

4. Install Homebrew & Chezmoi

   ```sh
   # Install Homebrew
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

   # Update path
   eval $(/opt/homebrew/bin/brew shellenv)

   # Install Chezmoi
   brew install chezmoi

   # Apply config from this repo
   chezmoi init aaronblair --apply
   ```

5. SSH Key Setup

   Either generate a new key or restore from secure backup:
   ```sh
   # Generate new key
   ssh-keygen -t ed25519 -C "your_email@example.com"

   # Start ssh-agent and add key
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519

   # Copy public key to clipboard
   pbcopy < ~/.ssh/id_ed25519.pub
   ```

   Add key to GitHub: https://github.com/settings/keys

6. Authenticate GitHub CLI

   ```sh
   gh auth login
   ```

7. Manual tasks

   - Turn on FileVault
   ```sh
   # Enables FileVault - be sure to backup recovery key
   sudo fdesetup enable
   ```

   - Grant full disk access to apps that need it
     - Alfred
     - WezTerm

   - Sign into apps
     - Bitwarden
     - Google Drive
     - Notion
     - Obsidian
     - Brave Browser (sync)
     - VSCode (Settings Sync)

   - Disable useless shortcuts in Keyboard settings

   - (If doing mobile dev) Install Android Studio SDK
