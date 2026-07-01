{ pkgs, ... }:
{
  # git の core.editor = vim はシェルの alias(vim -> nvim) を経由しないため、
  # 実体としての vim バイナリが必要。
  home.packages = [ pkgs.vim ];

  home.file.".vimrc".text = ''
    " Basic Settings
    set nocompatible
    set encoding=utf-8
    set fileencoding=utf-8
    set fileencodings=utf-8,cp932,euc-jp

    " Display
    set number
    set wrap
    set breakindent
    set showmatch
    set matchtime=1

    " Indentation
    set autoindent
    set smartindent
    set expandtab
    set tabstop=2
    set shiftwidth=2
    set softtabstop=2

    " Search
    set incsearch
    set hlsearch
    set ignorecase
    set smartcase

    " Behavior
    set backspace=indent,eol,start
    set virtualedit=block
    set wildmenu
    set wildmode=longest:full,full
    set hidden
    set history=200
    set undofile
    set undodir=~/.vim/undo
    set autochdir

    " Filetype and Indentation
    filetype plugin indent on

    " Performance
    set ttyfast
    set lazyredraw

    " Color and Theme
    syntax enable
    set background=dark
    colorscheme habamax

    " Status Line
    set laststatus=2
    set statusline=%F%m%r%h%w\ [%{&fileencoding}]\ [%{&filetype}]\ %=%l,%c\ %p%%

    " Highlight trailing spaces and tabs
    set list
    set listchars=tab:>\ ,trail:-,extends:>,precedes:<

    " Minimal UI
    set noshowmode
    set cmdheight=1

    " Git commit message - disable auto line break
    autocmd FileType gitcommit setlocal textwidth=0

    " 矩形VISUAl Mode
    noremap <Ctrl-q> <C-v>
    xnoremap z <C-v>

    " ローカル固有設定の読み込み(このマシン専用: ~/.vimrc.local)
    if filereadable(expand('~/.vimrc.local'))
      source ~/.vimrc.local
    endif
  '';
}
