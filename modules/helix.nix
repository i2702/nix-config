{ pkgs, ... }:
{
  home.packages = [ pkgs.helix ];

  xdg.configFile."helix/config.toml".text = ''
    theme = "catppuccin_mocha"

    [editor]
    line-number = "absolute"
    scrolloff = 5
    mouse = true
    middle-click-paste = true
    scroll-lines = 3
    shell = ["zsh", "-c"]
    rulers = [80, 120]
    bufferline = "always"
    color-modes = true
    cursorline = true
    cursorcolumn = false
    gutters = ["diagnostics", "line-numbers", "spacer", "diff"]
    auto-completion = true
    auto-format = true
    auto-save = false
    idle-timeout = 400
    completion-timeout = 250
    preview-completion-insert = true
    completion-trigger-len = 2
    completion-replace = false
    auto-info = true
    true-color = true
    undercurl = true
    insert-final-newline = true
    popup-border = "all"

    [editor.statusline]
    left = ["mode", "spinner", "file-name", "read-only-indicator", "file-modification-indicator"]
    center = ["version-control"]
    right = ["diagnostics", "selections", "register", "position", "file-encoding"]
    separator = "│"
    mode.normal = "NORMAL"
    mode.insert = "INSERT"
    mode.select = "SELECT"

    [editor.lsp]
    display-messages = true
    auto-signature-help = true
    display-inlay-hints = true
    display-signature-help-docs = true
    snippets = true
    goto-reference-include-declaration = true

    [editor.cursor-shape]
    insert = "bar"
    normal = "block"
    select = "underline"

    [editor.file-picker]
    hidden = false
    follow-symlinks = true
    deduplicate-links = true
    parents = true
    ignore = true
    git-ignore = true
    git-global = true
    git-exclude = true
    max-depth = 25

    [editor.auto-pairs]
    '(' = ')'
    '{' = '}'
    '[' = ']'
    '"' = '"'
    '`' = '`'
    '<' = '>'

    [editor.search]
    smart-case = true
    wrap-around = true

    [editor.whitespace.render]
    space = "none"
    nbsp = "none"
    nnbsp = "none"
    tab = "all"
    newline = "none"

    [editor.whitespace.characters]
    tab = "→"
    tabpad = "·"

    [editor.indent-guides]
    render = true
    character = "│"
    skip-levels = 0

    [editor.soft-wrap]
    enable = false

    # Vimライクなキーバインド設定
    [keys.normal]
    # 移動系
    G = "goto_file_end"
    "0" = "goto_line_start"
    "$" = "goto_line_end"
    "^" = "goto_first_nonwhitespace"
    H = "goto_window_top"
    M = "goto_window_center"
    L = "goto_window_bottom"
    z = { z = "align_view_center" }

    # 編集系
    D = ["extend_to_line_end", "delete_selection"]
    C = ["goto_line_start", "extend_to_line_end", "change_selection"]
    J = "join_selections"
    "C-r" = "redo"
    V = "extend_to_line_bounds"

    # ウィンドウ操作
    "C-w" = { h = "jump_view_left", j = "jump_view_down", k = "jump_view_up", l = "jump_view_right", v = "vsplit", s = "hsplit", q = "wclose" }

    # スペースキー(リーダーキー)はデフォルト設定を継承
    # esc = ["collapse_selection", "keep_primary_selection"]

    [keys.insert]
    # 挿入モード
    "C-c" = "normal_mode"
    "C-w" = "delete_word_backward"
    "C-u" = "kill_to_line_start"

    [keys.select]
    # セレクトモード(デフォルトを継承)
    esc = ["collapse_selection", "keep_primary_selection", "normal_mode"]
  '';
}
