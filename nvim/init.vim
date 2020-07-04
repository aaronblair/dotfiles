" Load Plugins
call plug#begin()
Plug 'tpope/vim-sensible'
Plug 'chriskempson/base16-vim'
Plug 'terryma/vim-multiple-cursors'
call plug#end()

set background=dark
set mouse=a

" Load Base-16 colors
if filereadable(expand("~/.vimrc_background"))
  let base16colorspace=256
  source ~/.vimrc_background
endif
