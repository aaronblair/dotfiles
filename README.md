# Aaron's .files

## Setup a new mac

1. Install command line tools

   ```sh
   xcode-select --install
   ```

2. Install Homebrew & Chezmoi

   ```sh
   # Install Homebrew
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

   # Install Chezmoi
   brew install chezmoi

   # Apply config from this repo
   chezmoi init aaronblair --apply
   ```

3. Manual tasks
   
   Change shell to brew zsh (vs builtin MacOS Zsh):
   ```
   # Add shell /etc/shells (arm64)
   sudo echo '/opt/homebrew/bin/zsh' > /etc/shells

   # Change shell
   chsh -s /opt/homebrew/bin/zsh
  
