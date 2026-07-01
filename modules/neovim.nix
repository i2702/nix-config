{ pkgs, ... }:
{
  # lazy.nvim が git clone でプラグインを取得し、telescope-fzf-native.nvim は
  # make でネイティブ拡張をビルドするため gcc/gnumake が必要。
  # ripgrep は telescope の live_grep が使う(home.nix で導入済み)。
  home.packages = [
    pkgs.neovim
    pkgs.gcc
    pkgs.gnumake
  ];

  xdg.configFile."nvim/init.lua".text = ''
    -- ===================================
    -- 🚀 Neovim 設定エントリーポイント
    -- ===================================

    -- リーダーキーをSpaceに設定(プラグイン読み込み前に設定)
    vim.g.mapleader = ","
    vim.g.maplocalleader = ","

    -- 基本設定を読み込み
    require("config.options")
    require("config.keymaps")
    require("config.autocmds")

    -- プラグイン管理(lazy.nvim)
    require("plugins")

    -- ローカル固有設定の読み込み(このマシン専用: ~/.config/nvim/init.lua.local)
    local local_init = vim.fn.stdpath("config") .. "/init.lua.local"
    if vim.loop.fs_stat(local_init) then
      dofile(local_init)
    end
  '';

  xdg.configFile."nvim/lua/config/options.lua".text = ''
    -- ===================================
    -- ⚙️ Neovim 基本設定
    -- 既存vimrcから継承・拡張
    -- ===================================

    local opt = vim.opt

    -- 📝 エンコーディング
    vim.scriptencoding = "utf-8"
    opt.encoding = "utf-8"
    opt.fileencoding = "utf-8"
    opt.fileencodings = "utf-8,cp932,euc-jp"

    -- 👁️ 表示設定
    opt.number = true              -- 行番号表示
    opt.relativenumber = false     -- 絶対行番号に固定
    opt.statuscolumn = '%s%=%{v:relnum?v:lnum:""} %{v:relnum?"":v:lnum} '
    opt.cursorline = true          -- カーソル行を強調
    opt.wrap = true                -- 折り返し有効
    opt.breakindent = true         -- 折り返し時のインデント保持
    opt.showmatch = true           -- 対応括弧ハイライト
    opt.matchtime = 1              -- 括弧ハイライト時間

    -- 📐 インデント設定
    opt.autoindent = true          -- 自動インデント
    opt.smartindent = true         -- スマートインデント
    opt.expandtab = true           -- タブをスペースに展開
    opt.tabstop = 2                -- タブ幅
    opt.shiftwidth = 2             -- インデント幅
    opt.softtabstop = 2            -- タブキー入力幅

    -- 🔍 検索設定
    opt.incsearch = true           -- インクリメンタル検索
    opt.hlsearch = true            -- 検索結果ハイライト
    opt.ignorecase = true          -- 大文字小文字無視
    opt.smartcase = true           -- 大文字入力時は区別

    -- 🎯 動作設定
    opt.backspace = "indent,eol,start"  -- Backspace動作
    opt.virtualedit = "block"      -- 矩形選択で行末を超える
    opt.wildmenu = true            -- コマンドライン補完
    opt.wildmode = "longest:full,full"
    opt.hidden = true              -- 未保存バッファの切替許可
    opt.history = 200              -- コマンド履歴数
    opt.undofile = true            -- Undo永続化
    opt.undodir = vim.fn.expand("~/.config/nvim/undo")  -- Undoディレクトリ

    -- 🎨 見た目設定
    vim.cmd("syntax enable")
    opt.termguicolors = true       -- 24bit色有効
    opt.background = "dark"        -- ダークモード
    opt.laststatus = 3             -- グローバルステータスライン
    opt.showmode = false           -- モード表示無効(lualineで表示)
    opt.cmdheight = 1              -- コマンドライン高さ

    -- 📋 不可視文字表示
    opt.list = true
    opt.listchars = {
      tab = "> ",
      trail = "-",
      extends = ">",
      precedes = "<",
    }

    -- ⚡ パフォーマンス
    opt.ttyfast = true
    opt.lazyredraw = true
    opt.updatetime = 250           -- CursorHold待機時間
    opt.timeoutlen = 300           -- キー入力待機時間

    -- 📂 ファイル種別検出
    vim.cmd("filetype plugin indent on")

    -- 🧹 スワップ・バックアップ
    opt.swapfile = false           -- スワップファイル無効
    opt.backup = false             -- バックアップ無効
    opt.writebackup = false        -- 書き込み前バックアップ無効

    -- 📋 クリップボード連携(WSL対応)
    opt.clipboard = "unnamedplus"

    -- 🪟 ウィンドウ区切り文字
    opt.fillchars = {
      vert      = "│",
      vertleft  = "┤",
      vertright = "├",
      verthoriz = "┼",
      horiz     = "─",
      horizup   = "┴",
      horizdown = "┬",
    }

    -- 📌 その他
    opt.splitright = true          -- 縦分割時は右に開く
    opt.splitbelow = true          -- 横分割時は下に開く
    opt.scrolloff = 8              -- スクロール時の余白行数
    opt.sidescrolloff = 8          -- 横スクロール時の余白列数
    opt.signcolumn = "yes"         -- サイン列常時表示(LSP用)
    opt.completeopt = "menu,menuone,noselect"  -- 補完メニュー設定

    -- Undoディレクトリが存在しない場合は作成
    vim.fn.mkdir(vim.fn.expand("~/.config/nvim/undo"), "p")
  '';

  xdg.configFile."nvim/lua/config/keymaps.lua".text = ''
    -- ===================================
    -- ⌨️ キーマッピング設定
    -- ===================================

    local keymap = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- 🎯 基本操作
    -- ESCでハイライト解除
    keymap("n", "<Esc>", "<cmd>nohlsearch<CR>", opts)

    -- Shift-Y でカーソル行をyank(vim互換)
    keymap("n", "Y", "yy", { desc = "カーソル行をyank" })

    -- 矩形VISUAL Mode(既存vimrcから継承)
    keymap("n", "<C-q>", "<C-v>", opts)

    -- VISUAL中にzでBlock modeへ切替(<C-v>はクリップボードに使うため)
    keymap("x", "z", "<C-v>", { desc = "VISUAL→Block mode切替" })

    -- Yをvim互換のyy(line-wise)に。neovimデフォルトのy$を上書き
    keymap("n", "Y", "yy", { desc = "1行yank(vim互換)" })

    -- 📋 Windowsクリップボード操作 (Ctrl-c / Ctrl-v)
    keymap("n", "<C-c>", '"+yy', { desc = "クリップボードへコピー(行)" })
    keymap("v", "<C-c>", '"+y',  { desc = "クリップボードへコピー(選択)" })

    keymap("n", "<C-v>", '"+p',   { desc = "クリップボードからペースト" })
    keymap("i", "<C-v>", "<C-r>+", { desc = "クリップボードからペースト" })
    keymap("v", "<C-v>", '"+p',   { desc = "クリップボードからペースト" })
    keymap("c", "<C-v>", "<C-r>+", { desc = "クリップボードからペースト" })

    -- ウィンドウ移動
    keymap("n", "<C-h>", "<C-w>h", { desc = "左ウィンドウへ移動" })
    keymap("n", "<C-j>", "<C-w>j", { desc = "下ウィンドウへ移動" })
    keymap("n", "<C-k>", "<C-w>k", { desc = "上ウィンドウへ移動" })
    keymap("n", "<C-l>", "<C-w>l", { desc = "右ウィンドウへ移動" })

    -- ウィンドウリサイズ
    keymap("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "高さ増" })
    keymap("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "高さ減" })
    keymap("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "幅減" })
    keymap("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "幅増" })

    -- バッファ操作
    keymap("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "前のバッファ" })
    keymap("n", "<S-l>", "<cmd>bnext<CR>", { desc = "次のバッファ" })
    keymap("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "バッファ削除" })

    -- インデント調整(ビジュアルモード)
    keymap("v", "<", "<gv", { desc = "インデント減(選択維持)" })
    keymap("v", ">", ">gv", { desc = "インデント増(選択維持)" })

    -- 行移動(ビジュアルモード)
    keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "選択行を下へ" })
    keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "選択行を上へ" })

    -- 🗂️ ファイルエクスプローラー(neo-tree)
    keymap("n", "<leader>e", "<cmd>Neotree toggle<CR>", { desc = "ファイルツリー開閉" })
    keymap("n", "<leader>o", "<cmd>Neotree focus<CR>", { desc = "ファイルツリーにフォーカス" })

    -- 🔭 Telescope
    keymap("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "ファイル検索" })
    keymap("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "文字列検索" })
    keymap("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "バッファ一覧" })
    keymap("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "ヘルプ検索" })
    keymap("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "最近開いたファイル" })
    keymap("n", "<leader>fc", "<cmd>Telescope commands<CR>", { desc = "コマンド検索" })

    -- 🔧 LSP操作
    keymap("n", "gd", vim.lsp.buf.definition, { desc = "定義へジャンプ" })
    keymap("n", "gD", vim.lsp.buf.declaration, { desc = "宣言へジャンプ" })
    keymap("n", "gi", vim.lsp.buf.implementation, { desc = "実装へジャンプ" })
    keymap("n", "gt", vim.lsp.buf.type_definition, { desc = "型定義へジャンプ" })
    keymap("n", "gr", vim.lsp.buf.references, { desc = "参照一覧" })
    keymap("n", "K", vim.lsp.buf.hover, { desc = "ホバー情報" })
    keymap("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "コードアクション" })
    keymap("n", "<leader>rn", vim.lsp.buf.rename, { desc = "リネーム" })
    keymap("n", "<leader>f", vim.lsp.buf.format, { desc = "フォーマット" })
    keymap("n", "[d", vim.diagnostic.goto_prev, { desc = "前の診断" })
    keymap("n", "]d", vim.diagnostic.goto_next, { desc = "次の診断" })
    keymap("n", "<leader>q", vim.diagnostic.setloclist, { desc = "診断リスト" })

    -- 💾 保存・終了
    keymap("n", "<leader>w", "<cmd>w<CR>", { desc = "保存" })
    keymap("n", "<leader>q", "<cmd>q<CR>", { desc = "終了" })
  '';

  xdg.configFile."nvim/lua/config/autocmds.lua".text = ''
    -- ===================================
    -- 🤖 自動コマンド設定
    -- ===================================

    local autocmd = vim.api.nvim_create_autocmd
    local augroup = vim.api.nvim_create_augroup

    -- 📝 Git コミットメッセージ設定(既存vimrcから継承)
    autocmd("FileType", {
      group = augroup("GitCommit", { clear = true }),
      pattern = "gitcommit",
      callback = function()
        vim.opt_local.textwidth = 0  -- 自動改行無効
      end,
      desc = "Gitコミットメッセージの自動改行を無効化",
    })

    -- 🔍 検索時に結果を中央に表示
    autocmd("CursorMoved", {
      group = augroup("CenterSearch", { clear = true }),
      callback = function()
        if vim.v.hlsearch == 1 then
          vim.cmd("normal! zz")
        end
      end,
      desc = "検索結果を画面中央に表示",
    })

    -- 💾 保存時に末尾の空白を削除
    autocmd("BufWritePre", {
      group = augroup("TrimWhitespace", { clear = true }),
      pattern = "*",
      callback = function()
        local save_cursor = vim.fn.getpos(".")
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.setpos(".", save_cursor)
      end,
      desc = "保存時に末尾の空白を削除",
    })

    -- 📂 最後のカーソル位置を復元
    autocmd("BufReadPost", {
      group = augroup("RestoreCursor", { clear = true }),
      pattern = "*",
      callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
          pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
      end,
      desc = "最後のカーソル位置を復元",
    })

    -- 🎨 ヤンク時にハイライト
    autocmd("TextYankPost", {
      group = augroup("HighlightYank", { clear = true }),
      pattern = "*",
      callback = function()
        vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
      end,
      desc = "ヤンク時にハイライト表示",
    })


    -- 🔢 行番号の色を白寄りに
    autocmd("ColorScheme", {
      group = augroup("LineNrColor", { clear = true }),
      pattern = "*",
      callback = function()
        vim.api.nvim_set_hl(0, "LineNr", { fg = "#aaaaaa" })
        vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#ffffff", bold = true })
      end,
      desc = "行番号の色を白寄りに調整",
    })
    -- 初回読み込み時にも適用
    vim.api.nvim_set_hl(0, "LineNr", { fg = "#aaaaaa" })
    vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#ffffff", bold = true })

    -- 🪟 ウィンドウ境界線のハイライト(カラースキーム適用後に上書き)
    autocmd("ColorScheme", {
      group = augroup("WinSeparator", { clear = true }),
      pattern = "*",
      callback = function()
        vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#585b70", bg = "NONE" })
      end,
      desc = "ウィンドウ境界線を視認しやすい色に設定",
    })

    -- 🔧 LSP起動時の設定
    autocmd("LspAttach", {
      group = augroup("LspConfig", { clear = true }),
      callback = function(args)
        local bufnr = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        -- LSP起動メッセージ
        vim.notify(
          string.format("🚀 LSP起動: %s", client.name),
          vim.log.levels.INFO
        )

        -- バッファローカルキーマップは keymaps.lua で定義済み
      end,
      desc = "LSP起動時の設定",
    })
  '';

  xdg.configFile."nvim/lua/plugins/init.lua".text = ''
    -- ===================================
    -- 📦 lazy.nvim プラグインマネージャー
    -- ===================================

    -- lazy.nvimのブートストラップ(自動インストール)
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.loop.fs_stat(lazypath) then
      vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
      })
    end
    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
      require("plugins.colorscheme"),
      require("plugins.cmp"),
      require("plugins.lsp"),
      require("plugins.telescope"),
    }, {
      ui = {
        border = "rounded",
      },
      performance = {
        rtp = {
          disabled_plugins = {
            "gzip",
            "matchit",
            "matchparen",
            "netrwPlugin",
            "tarPlugin",
            "tohtml",
            "tutor",
            "zipPlugin",
          },
        },
      },
    })
  '';

  # chezmoiでは追跡されていなかったが、init.luaが require するため実機上で
  # 必須のファイル(~/.config/nvim/lua/plugins/colorscheme.lua)から採取。
  xdg.configFile."nvim/lua/plugins/colorscheme.lua".text = ''
    -- ===================================
    -- 🎨 カラースキーマ
    -- ===================================

    return {
      {
        "scottmckendry/cyberdream.nvim",
        lazy = false,
        priority = 1000,
        config = function()
          require("cyberdream").setup({
            transparent = false,
            italic_comments = true,
            hide_fillchars = false,
            borderless_telescope = true,
            terminal_colors = true,
          })
          vim.cmd("colorscheme cyberdream")
        end,
      },
    }
  '';

  xdg.configFile."nvim/lua/plugins/cmp.lua".text = ''
    -- 補完: nvim-cmp
    return {
      "hrsh7th/nvim-cmp",
      dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
      },
      config = function()
        local cmp = require("cmp")

        cmp.setup({
          mapping = cmp.mapping.preset.insert({
            ["<C-n>"] = cmp.mapping.select_next_item(),
            ["<C-p>"] = cmp.mapping.select_prev_item(),
            ["<C-b>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<CR>"] = cmp.mapping.confirm({ select = true }),
          }),
          sources = cmp.config.sources({
            { name = "nvim_lsp" },
            { name = "buffer" },
            { name = "path" },
          }),
        })
      end,
    }
  '';

  xdg.configFile."nvim/lua/plugins/lsp.lua".text = ''
    -- LSP: nvim-lspconfig (nvim 0.11+ style)
    return {
      "neovim/nvim-lspconfig",
      config = function()
        local capabilities = require("cmp_nvim_lsp").default_capabilities()

        -- TypeScript / JavaScript
        vim.lsp.config("ts_ls", {
          capabilities = capabilities,
        })
        vim.lsp.enable("ts_ls")

        -- キーマップ(LSP アタッチ時に設定)
        vim.api.nvim_create_autocmd("LspAttach", {
          callback = function(ev)
            local opts = { buffer = ev.buf, silent = true }
            vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
            vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
            vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
            vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
            vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)
          end,
        })

        -- 診断表示設定
        vim.diagnostic.config({
          virtual_text = true,
          signs = true,
          underline = true,
          update_in_insert = false,
        })
      end,
    }
  '';

  xdg.configFile."nvim/lua/plugins/telescope.lua".text = ''
    -- Telescope: ファジーファインダー
    return {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      },
      config = function()
        local telescope = require("telescope")
        local builtin = require("telescope.builtin")

        telescope.setup({
          defaults = {
            layout_strategy = "horizontal",
            sorting_strategy = "ascending",
            layout_config = {
              prompt_position = "top",
            },
          },
        })

        telescope.load_extension("fzf")

        -- キーマップ
        vim.api.nvim_create_user_command("E", function(opts)
          local dir = opts.args ~= "" and opts.args or vim.fn.expand("%:p:h")
          builtin.find_files({ cwd = dir })
        end, { nargs = "?", complete = "dir", desc = "Telescope find_files (:E)" })

        vim.keymap.set("n", "t",          builtin.find_files,  { desc = "ファイル検索" })
        vim.keymap.set("n", "<leader>ff", builtin.find_files,  { desc = "ファイル検索" })
        vim.keymap.set("n", "<leader>fg", builtin.live_grep,   { desc = "grep検索" })
        vim.keymap.set("n", "<leader>fb", builtin.buffers,     { desc = "バッファ一覧" })
        vim.keymap.set("n", "<leader>fh", builtin.help_tags,   { desc = "ヘルプ検索" })
        vim.keymap.set("n", "<leader>fr", builtin.oldfiles,    { desc = "最近開いたファイル" })
      end,
    }
  '';
}
