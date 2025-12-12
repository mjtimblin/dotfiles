" GENERAL SETTINGS --------------------------------------------------------------- {{{

" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

" Enable type file detection. Vim will be able to try to detect the type of file in use.
filetype on

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent file for the detected file type.
filetype indent on

" Enable syntax highlighting
syntax on

" Add numbers to each line on the left-hand side.
set number

" Show the mode you are on the last line.
set showmode

" Show matching words during a search.
set showmatch

" Use highlighting when doing a search.
set hlsearch

" Set the commands to save in history default number is 20.
set history=1000

" Enable auto completion menu after pressing TAB.
set wildmenu

" Make wildmenu behave like similar to Bash completion.
set wildmode=list:longest

" There are certain files that we would never want to edit with Vim.
" Wildmenu will ignore files with these extensions.
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

" Allow right and left arrow keys to switch lines at beginning and end of
" lines
set whichwrap+=<,>,h,l,[,]

" Use a line cursor within insert mode and a block cursor everywhere else.
"
" Reference chart of values:
"   Ps = 0  -> blinking block.
"   Ps = 1  -> blinking block (default).
"   Ps = 2  -> steady block.
"   Ps = 3  -> blinking underline.
"   Ps = 4  -> steady underline.
"   Ps = 5  -> blinking bar (xterm).
"   Ps = 6  -> steady bar (xterm).
let &t_SI = "\e[6 q"
let &t_EI = "\e[4 q"

" Show tabs as an arrow and trailing spaces as dots
set list lcs=tab:→ ,trail:·

" Set default tab size
set tabstop=3
set shiftwidth=1
set expandtab!

set swapfile
set dir=~/.vim/tmp

" }}}


" PLUGINS ---------------------------------------------------------------- {{{
" Plugin code goes here.

" Automatically install vim-plug if not installed
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
  Plug 'dense-analysis/ale'
  Plug 'preservim/nerdtree'
  Plug 'sheerun/vim-polyglot'
  Plug 'vim-scripts/diffchanges.vim'
  Plug 'itchyny/lightline.vim'
  Plug 'tpope/vim-commentary'
  Plug 'airblade/vim-gitgutter'
  Plug 'editorconfig/editorconfig-vim'
  Plug 'dezza/vimdirs.vim'

  " Themes
  Plug 'NLKNguyen/papercolor-theme'
call plug#end()

" }}}


" MAPPINGS --------------------------------------------------------------- {{{

" map_mode <what_you_type> <what_is_executed>
" nnoremap - Allows you to map keys in normal mode
" inoremap - Allows you to map keys in insert mode
" vnoremap - Allows you to map keys in visual mode

" The backslash key is the default leader key
" It can be remapped to comman with `let mapleader = ","`

" Set the backslash as the leader key.
" let mapleader = "\"

" Map 'jj' to escape from insert mode
inoremap jj <Esc>

" Press the space bar to type the : character in command mode.
nnoremap <space> :

" Pressing the letter o will open a new line below the current one.
" Exit insert mode after creating a new line above or below the current line.
nnoremap o o<esc>
nnoremap O O<esc>

" Ctrl + Shift + Left/Right to shift selection right/up
nnoremap <C-S-Up> :m-2<CR>
nnoremap <C-S-Down> :m+<CR>
inoremap <C-S-Up> <Esc>:m-2<CR>
inoremap <C-S-Down> <Esc>:m+<CR>
xnoremap <C-S-Up> xkP`[V`]
xnoremap <C-S-Down> xp`[V`]

" Ctrl + Shift + Up/Down to move current line (or selection) up/down
xnoremap <C-S-Left> <gv
xnoremap <C-S-Right> >gv

" NERDTree specific mappings.
" Map the F3 key to toggle NERDTree open and close.
nnoremap <F3> :NERDTreeToggle<cr>

" Have nerdtree ignore certain files and directories.
let NERDTreeIgnore=['\.git$', '\.jpg$', '\.mp4$', '\.ogg$', '\.iso$', '\.pdf$', '\.pyc$', '\.odt$', '\.png$', '\.gif$', '\.db$']

" }}}


" VIMSCRIPT -------------------------------------------------------------- {{{

" This will enable code folding. Use the marker method of folding.
augroup filetype_vim
  autocmd!
  autocmd FileType vim setlocal foldmethod=marker
augroup END

" Source vim configuration file whenever it is saved
augroup reload_vimrc
  autocmd!
  autocmd! BufWritePost $MYVIMRC source % | echom "Reloaded " . $MYVIMRC | redraw
augroup END

" If Vim version is equal to or greater than 7.3 enable undofile.
" This allows you to undo changes to a file even after saving it.
if version >= 703
  set undodir=~/.vim/backup
  set undofile
  set undoreload=10000
endif

" You can split a window into sections by typing `:split` or `:vsplit`.
" Display cursorline and cursorcolumn ONLY in active window.
augroup cursor_off
  autocmd!
  autocmd WinLeave * set nocursorline nocursorcolumn
  autocmd WinEnter * set cursorline cursorcolumn
augroup END

" }}}


" STATUS LINE ------------------------------------------------------------ {{{

set laststatus=2
let g:lightline = { 'colorscheme': 'PaperColor', }
set noshowmode

" }}}


" THEME --------------------------------------------------------------- {{{

set background=dark
colorscheme PaperColor
let g:airline_theme='one'

" }}}


" LANGUAGE SPECIFIC SETTINGS --------------------------------------------------------------- {{{

" JSON
autocmd Filetype json setlocal tabstop=2

" Python
autocmd Filetype py setlocal tabstop=4
autocmd Filetype py setlocal shiftwidth=4
autocmd Filetype py setlocal expandtab      " Use spaces when the tab key is pressed

" }}}

