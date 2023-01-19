#!/bin/bash

# Check that nvim as been created (by chezmoi) and that it
# isn't already initiaized by a prior run
if [ ! -d ~/.config/nvim ] || [ -d ~/.config/nvim/.git ]
then
  echo "AstroNvim has already been initialized, nothing to do"
  exit 0
fi

# Clone Astrovim repo into existing nvim directory (config file already present)
cd ~/.config/nvim/
git init
git remote add origin https://github.com/AstroNvim/AstroNvim
git pull origin main --allow-unrelated-histories

# Install Astrovim
nvim  --headless -c 'autocmd User PackerComplete quitall'

