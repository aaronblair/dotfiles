# Aaron's .files

## Setup a new mac

1. Set hostname

   ```
   sudo scutil --set HostName
   sudo scutil --set LocalHostName
   sudo scutil --set ComputerName
   dscacheutil -flushcache
   sudo shutdown -r now
   ```

2. grant access to terminal to edit applications



2. Install command line tools

   ```sh
   xcode-select --install
   ```

2. Install Homebrew & Chezmoi

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

3. Manual tasks

   - Turn on Filevault
   ```
   # Enables filevault - be sure to backup recovery key
   sudo fdesetup enable
   ```

   - Change shell to brew zsh (vs builtin MacOS Zsh):
   ```
   # Add shell /etc/shells (arm64)
   sudo echo '/opt/homebrew/bin/zsh' > /etc/shells

   # Change shell
   chsh -s /opt/homebrew/bin/zsh
   ```

   - Initialize VIM

   - Grant full disk access to apps that need it
     - Alfred
     - Alacritty

   - Copy SSH key to servers (incl github)

   - Login to key apps




