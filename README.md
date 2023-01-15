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
   '''

3. Manual tasks
   
   Change shell to brew zsh:
   ```
   sudo vi /etc/shells
   ```
   Append
   ```
   /opt/homebrew/bin/zsh
   ```
