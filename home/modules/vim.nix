{ pkgs, ... }:

let
  commonConfig = ''
    syntax enable
    filetype plugin indent on

    set encoding=utf-8
    set termguicolors
    set number
    set relativenumber
    set cursorline
    set signcolumn=yes
    set mouse=a
    set clipboard=unnamedplus

    set expandtab
    set tabstop=4
    set shiftwidth=4
    set softtabstop=4
    set shiftround

    set ignorecase
    set smartcase
    set incsearch
    set hlsearch

    set hidden
    set confirm
    set autoread
    set splitbelow
    set splitright
    set scrolloff=4
    set sidescrolloff=4
    set wildmenu
    set wildmode=longest:full,full
    set completeopt=menuone,noselect
    set updatetime=300
    set timeoutlen=500
    set ttimeoutlen=10
    set noerrorbells
    set visualbell

    " Do not allow a repository file to execute editor commands through a
    " modeline. Project indentation remains available through EditorConfig.
    set nomodeline
  '';
  stateConfig = stateName: ''
    set undofile
    set undodir=~/.local/state/${stateName}/undo//
    set directory=~/.local/state/${stateName}/swap//
    set backupdir=~/.local/state/${stateName}/backup//
    set backupcopy=yes
  '';
  commonPlugins = [ pkgs.vimPlugins.editorconfig-vim ];
in
{
  programs.vim = {
    enable = true;
    defaultEditor = true;
    plugins = commonPlugins;
    extraConfig = commonConfig + stateConfig "vim";
  };

  # Keep Neovim configured equivalently without making it the default editor.
  programs.neovim = {
    enable = true;
    defaultEditor = false;
    viAlias = false;
    vimAlias = false;
    plugins = commonPlugins;
    extraConfig = commonConfig + stateConfig "nvim";
  };

  home.packages = [ pkgs.wl-clipboard ];

  home.file = {
    ".local/state/vim/undo/.keep".text = "";
    ".local/state/vim/swap/.keep".text = "";
    ".local/state/vim/backup/.keep".text = "";
    ".local/state/nvim/undo/.keep".text = "";
    ".local/state/nvim/swap/.keep".text = "";
    ".local/state/nvim/backup/.keep".text = "";
  };
}
