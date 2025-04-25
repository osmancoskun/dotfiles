" Modern Vim Configuration for Web & Linux Development
" ====================================================

" Basic Settings
" -------------
set nocompatible
set encoding=UTF-8
syntax enable
set number                     " Show line numbers
set relativenumber             " Show relative line numbers
set cursorline                 " Highlight current line
set showmatch                  " Highlight matching brackets
set hlsearch                   " Highlight search results
set incsearch                  " Incremental search
set ignorecase                 " Case insensitive search
set smartcase                  " Override ignorecase if search pattern has uppercase
set expandtab                  " Use spaces instead of tabs
set tabstop=2                  " 2 spaces for a tab
set shiftwidth=2               " 2 spaces for indentation
set autoindent                 " Auto indent
set smartindent                " Smart indent
set wrap                       " Wrap lines
set linebreak                  " Break lines at words
set scrolloff=8                " Keep cursor 8 lines away from screen border
set sidescrolloff=8            " Keep cursor 8 columns away from screen border
set clipboard=unnamedplus      " Use system clipboard
set mouse=a                    " Enable mouse
set hidden                     " Allow hidden buffers
set nobackup                   " No backup files
set nowritebackup              " No backup files while editing
set noswapfile                 " No swap files
set undofile                   " Persistent undo
set undodir=~/.vim/undodir     " Undo directory
set updatetime=300             " Faster completion
set timeoutlen=500             " Timeout for key mappings
set shortmess+=c               " Don't pass messages to ins-completion-menu
set signcolumn=yes             " Always show sign column
set splitright                 " Split windows right
set splitbelow                 " Split windows below

" Enable 24-bit colors if supported
if has('termguicolors')
  set termguicolors
endif

" Create undodir if it doesn't exist
if !isdirectory($HOME."/.vim/undodir")
    call mkdir($HOME."/.vim/undodir", "p", 0700)
endif

" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" Plugins
" -------
call plug#begin('~/.vim/plugged')
  " Theme and UI
  Plug 'morhetz/gruvbox'                          " Gruvbox theme
  Plug 'vim-airline/vim-airline'                  " Status bar
  Plug 'vim-airline/vim-airline-themes'           " Airline themes
  Plug 'ryanoasis/vim-devicons'                   " Icons
  
  " File navigation
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " FZF base
  Plug 'junegunn/fzf.vim'                         " FZF integration
  
  " File browser
  Plug 'preservim/nerdtree'                       " File explorer
  
  " Editing
  Plug 'tpope/vim-surround'                       " Surround text objects
  Plug 'tpope/vim-commentary'                     " Easy commenting
  Plug 'jiangmiao/auto-pairs'                     " Auto close brackets
  Plug 'mattn/emmet-vim'                          " HTML/CSS expansion
  
  " Auto-completion and LSP
  Plug 'neoclide/coc.nvim', {'branch': 'release'} " Intellisense
  
  " Git
  Plug 'tpope/vim-fugitive'                       " Git integration
  Plug 'airblade/vim-gitgutter'                   " Git diff in sign column
  
  " Syntax highlighting and language support
  Plug 'sheerun/vim-polyglot'                     " Language pack
  Plug 'evanleck/vim-svelte'                      " Svelte support
  Plug 'pangloss/vim-javascript'                  " JavaScript support
  Plug 'HerringtonDarkholme/yats.vim'             " TypeScript syntax
  Plug 'maxmellon/vim-jsx-pretty'                 " JSX/React
  
  " Code formatting
  Plug 'prettier/vim-prettier', { 'do': 'npm install --frozen-lockfile --production' }
  
  " Spell checking and auto-correct
  Plug 'kamykn/spelunker.vim'                     " Better spell checking
  Plug 'sedm0784/vim-you-autocorrect'             " Auto-correction
call plug#end()

" Theme Configuration
" ------------------
set background=dark
colorscheme gruvbox
let g:airline_theme='gruvbox'
let g:airline_powerline_fonts = 1

" Font Settings (for GVim)
" -----------------------------------
if has('gui_running')
  set guifont=JetBrainsMono\ Nerd\ Font:h12
endif

" Spell Check Configuration
" ------------------------
let g:spelunker_check_type = 2
let g:spelunker_highlight_type = 2
let g:enable_spelunker_vim = 1
let g:enable_spelunker_vim_on_readonly = 1

" AutoCorrect Setup (toggle with <leader>a)
let g:autocorrect_enable = 0
nnoremap <leader>a :AutoCorrectToggle<CR>

" FZF Configuration (as an alternative to Telescope)
" -------------------------------------------------
" Create a preview window for FZF
command! -bang -nargs=? -complete=dir Files
    \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

" Customize FZF colors to match your colorscheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Layout options
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }

" NERDTree Configuration
" ---------------------
let NERDTreeShowHidden = 1
let NERDTreeMinimalUI = 1
let NERDTreeIgnore = ['\.pyc$', '\.git$', '__pycache__', 'node_modules', 'dist', 'build']

" Emmet Configuration
" ------------------
let g:user_emmet_leader_key='<C-e>'
let g:user_emmet_settings = {
\  'javascript.jsx' : {
\      'extends' : 'jsx',
\  },
\  'svelte' : {
\      'extends' : 'html',
\  },
\}

" CoC Configuration
" ----------------
let g:coc_global_extensions = [
  \ 'coc-tsserver',
  \ 'coc-json',
  \ 'coc-html',
  \ 'coc-css',
  \ 'coc-eslint',
  \ 'coc-prettier',
  \ 'coc-pyright',
  \ 'coc-svelte',
  \ 'coc-snippets',
  \ 'coc-pairs',
  \ 'coc-highlight',
  \ 'coc-spell-checker'
  \ ]

" Use tab for trigger completion
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> accept selected completion item
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" Symbol renaming
nmap <leader>rn <Plug>(coc-rename)

" Formatting selected code
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

" Prettier Configuration
" ---------------------
command! -nargs=0 Prettier :CocCommand prettier.forceFormatDocument

" Custom Key Mappings
" ------------------
let mapleader = " "  " Space as leader key

" FZF shortcuts (similar to Telescope)
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :Rg<CR>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fh :Helptags<CR>
nnoremap <leader>fc :Commands<CR>
nnoremap <leader>fl :Lines<CR>
nnoremap <leader>ft :BTags<CR>

" Show file preview with FZF
nnoremap <leader>fp :Files<CR>

" NERDTree shortcuts
nnoremap <leader>e :NERDTreeToggle<CR>
nnoremap <leader>nf :NERDTreeFind<CR>

" Buffer navigation
nnoremap <leader>bn :bnext<CR>
nnoremap <leader>bp :bprevious<CR>
nnoremap <leader>bd :bdelete<CR>

" Window navigation
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Window resizing
nnoremap <M-j> :resize -2<CR>
nnoremap <M-k> :resize +2<CR>
nnoremap <M-h> :vertical resize -2<CR>
nnoremap <M-l> :vertical resize +2<CR>

" Format document
nnoremap <leader>p :Prettier<CR>

" Escape from terminal mode
tnoremap <Esc> <C-\><C-n>

" Clear search highlighting
nnoremap <leader>nh :nohl<CR>

" Save and quit shortcuts
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>wq :wq<CR>

" Move lines up and down
nnoremap <A-j> :m .+1<CR>==
nnoremap <A-k> :m .-2<CR>==
inoremap <A-j> <Esc>:m .+1<CR>==gi
inoremap <A-k> <Esc>:m .-2<CR>==gi
vnoremap <A-j> :m '>+1<CR>gv=gv
vnoremap <A-k> :m '<-2<CR>gv=gv

" Indent blocks of code
vnoremap < <gv
vnoremap > >gv

" Toggle spell checking
nnoremap <leader>sp :set spell!<CR>

" Filetype specific settings
" -------------------------
augroup customFiletypes
  autocmd!
  " Web Development
  autocmd FileType html,css,javascript,javascriptreact,typescript,typescriptreact,svelte setlocal tabstop=2 softtabstop=2 shiftwidth=2
  
  " Python Development
  autocmd FileType python setlocal tabstop=4 softtabstop=4 shiftwidth=4
  
  " Auto format on save for specific file types
  autocmd BufWritePre *.js,*.jsx,*.ts,*.tsx,*.css,*.html,*.svelte,*.json,*.py Prettier
augroup END

" Install Coc Language Servers on first launch
" -------------------------------------------
" Run :CocInstall after first launch
