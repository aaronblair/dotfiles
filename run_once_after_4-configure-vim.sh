#!/bin/bash

nvim --headless -c 'autocmd User PackerComplete quitall'
nvim --headless -c 'PackerSync'

