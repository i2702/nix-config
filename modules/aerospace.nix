{ pkgs, lib, ... }:
{
  # AeroSpace (macOS のタイル型ウィンドウマネージャ) の設定。
  # 本体は Homebrew でインストール済み (/Applications/AeroSpace.app) のため、
  # ここでは設定ファイル ~/.aerospace.toml の配置のみ行う。
  #
  # 注意: AeroSpace は設定ファイルを置くと [mode.main.binding] の内容が
  # デフォルトとマージされず「完全置換」になる。そのため v0.21.1 同梱の
  # デフォルト設定一式をベースにして、必要箇所だけ変更している。
  #
  # デフォルトからの変更点:
  #   - レイアウトは既定の tiles(左右に並べる)を維持。窓が3列以上に増えたら
  #     join-with(⌃⌥[ / ⌃⌥])で隣の列へ畳んで縦スタック化し、列数を抑える手動運用。
  #     (AeroSpace は i3 系の手動タイルで「列数の自動上限」は無い)
  #   - ウィンドウ移動: alt-shift-h/j/k/l -> Ctrl+Option + 矢印キー (ctrl-alt-left/down/up/right)
  #   - 修飾キー: alt (Option) -> ctrl-alt (Ctrl+Option)。
  #     tmux が bare Option (M-) を多用しており、AeroSpace(既定の alt)と全面衝突して
  #     Option+文字を押すたび空ワークスペースへ飛ばされていた(=全ウィンドウが一瞬消える)。
  #     素の Option は tmux 専用に空け、AeroSpace は ctrl-alt にずらして共存させる。
  #
  # macOS 専用のため Darwin でのみ配置する。
  home.file.".aerospace.toml" = lib.mkIf pkgs.stdenv.isDarwin {
    text = ''
      # Config version for compatibility and deprecations
      # See: https://nikitabobko.github.io/AeroSpace/guide#config-version
      config-version = 2

      # You can use it to add commands that run after AeroSpace startup.
      # Available commands : https://nikitabobko.github.io/AeroSpace/commands
      after-startup-command = []

      # Start AeroSpace at login
      start-at-login = false

      # Automatically reload the config when the config file is saved
      # After setting this to true, reload once manually to start the auto-reloading
      # 注意: nix管理では ~/.aerospace.toml は store へのシンボリックリンクのため、
      # home-manager switch でリンク先が差し替わっても FSEvents が拾えず自動リロード
      # されない場合がある。その時は一度だけ手動で `aerospace reload-config` を叩く。
      auto-reload-config = true

      # Normalizations. See: https://nikitabobko.github.io/AeroSpace/guide#normalization
      enable-normalization-flatten-containers = true
      enable-normalization-opposite-orientation-for-nested-containers = true

      # See: https://nikitabobko.github.io/AeroSpace/guide#layouts
      # The 'accordion-padding' specifies the size of accordion padding
      # You can set 0 to disable the padding feature
      accordion-padding = 30

      # Possible values: tiles|accordion
      # 既定はタイル(窓は左右に並ぶ=左右分割)。3列以上に増えたら join-with
      # (⌃⌥[ / ⌃⌥])で隣の列へ畳んで縦スタックにし、列数を抑える。
      # AeroSpace に「列数の自動上限」は無いため畳むのは手動運用。
      default-root-container-layout = 'tiles'

      # Possible values: horizontal|vertical|auto
      # 変更: 新規ウィンドウは基本「左右(バーティカル)2分割」で並べたいので horizontal 固定。
      #       (AeroSpace の horizontal = 左右並び)
      default-root-container-orientation = 'horizontal'

      # Mouse follows focus when focused monitor changes
      on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

      # You can effectively turn off macOS "Hide application" (cmd-h) feature by toggling this flag
      automatically-unhide-macos-hidden-apps = false

      # List of workspaces that should stay alive even when they contain no windows.
      persistent-workspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B",
                               "C", "D", "E", "F", "G", "I", "M", "N", "O", "P", "Q",
                               "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

      # A callback that runs every time binding mode changes
      on-mode-changed = []

      focus-follows-mouse.enabled = false

      # Possible values: (qwerty|dvorak|colemak)
      key-mapping.preset = 'qwerty'

      # Gaps between windows (inner-*) and between monitor edges (outer-*).
      gaps.inner.horizontal = 0
      gaps.inner.vertical =   0
      gaps.outer.left =       0
      gaps.outer.bottom =     0
      gaps.outer.top =        0
      gaps.outer.right =      0

      # 'main' binding mode declaration
      # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
      # 修飾キーは ctrl-alt (Ctrl+Option)。bare Option は tmux 用に空けてある。
      [mode.main.binding]

          # レイアウト切替
          # See: https://nikitabobko.github.io/AeroSpace/commands#layout
          ctrl-alt-comma = 'layout tiles accordion'         # タイル ⇄ accordion をトグル
          ctrl-alt-slash = 'layout tiles horizontal vertical' # タイルにして 左右 ⇄ 上下 をトグル

          # ウィンドウ間のフォーカス移動 (hjkl)
          # See: https://nikitabobko.github.io/AeroSpace/commands#focus
          ctrl-alt-h = 'focus left'
          ctrl-alt-j = 'focus down'
          ctrl-alt-k = 'focus up'
          ctrl-alt-l = 'focus right'

          # ウィンドウ自体の移動 (Ctrl+Option + 矢印キー)
          #   --boundaries all-monitors-outer-frame:
          #     ワークスペースの端まで来たら、その向きにディスプレイがあれば隣のディスプレイへ飛ばす。
          #     → 連打すれば別ディスプレイのタイルへ移動できる。
          #     端にディスプレイが無い向きは従来どおり暗黙コンテナを作る(＝上下/左右分割の作成は維持)。
          # See: https://nikitabobko.github.io/AeroSpace/commands#move
          ctrl-alt-left  = 'move left  --boundaries all-monitors-outer-frame'
          ctrl-alt-down  = 'move down  --boundaries all-monitors-outer-frame'
          ctrl-alt-up    = 'move up    --boundaries all-monitors-outer-frame'
          ctrl-alt-right = 'move right --boundaries all-monitors-outer-frame'

          # 窓1枚を隣のディスプレイへ一発で飛ばす (Ctrl+Option+Shift + 矢印キー)
          #   連打不要で、指定方向のディスプレイへ即移動。--focus-follows-window で
          #   移動後もその窓にフォーカスが付いてくる。
          # See: https://nikitabobko.github.io/AeroSpace/commands#move-node-to-monitor
          ctrl-alt-shift-left  = 'move-node-to-monitor --focus-follows-window left'
          ctrl-alt-shift-down  = 'move-node-to-monitor --focus-follows-window down'
          ctrl-alt-shift-up    = 'move-node-to-monitor --focus-follows-window up'
          ctrl-alt-shift-right = 'move-node-to-monitor --focus-follows-window right'

          # 分割の向きを直接指定 (Ctrl+Option+Shift + hjkl)
          #   h/l = 左右分割(バーティカル / AeroSpace: horizontal)
          #   j/k = 上下分割(ホリゾンタル / AeroSpace: vertical)
          # ※ bare Option は tmux 予約、Ctrl+Option+hjkl はフォーカス移動のため Shift を足している
          ctrl-alt-shift-h = 'layout tiles horizontal'
          ctrl-alt-shift-l = 'layout tiles horizontal'
          ctrl-alt-shift-j = 'layout tiles vertical'
          ctrl-alt-shift-k = 'layout tiles vertical'

          # 列が増えすぎたとき、現在の窓を隣の列に畳んで列数を減らす (join-with)
          #   ⌃⌥ [ = 左の列へ畳む / ⌃⌥ ] = 右の列へ畳む
          #   opposite-orientation 正規化により、畳んだ窓は列内で上下スタックになる
          ctrl-alt-leftSquareBracket = 'join-with left'
          ctrl-alt-rightSquareBracket = 'join-with right'

          # See: https://nikitabobko.github.io/AeroSpace/commands#resize
          ctrl-alt-minus = 'resize smart -50'
          ctrl-alt-equal = 'resize smart +50'

          # See: https://nikitabobko.github.io/AeroSpace/commands#workspace
          ctrl-alt-1 = 'workspace 1'
          ctrl-alt-2 = 'workspace 2'
          ctrl-alt-3 = 'workspace 3'
          ctrl-alt-4 = 'workspace 4'
          ctrl-alt-5 = 'workspace 5'
          ctrl-alt-6 = 'workspace 6'
          ctrl-alt-7 = 'workspace 7'
          ctrl-alt-8 = 'workspace 8'
          ctrl-alt-9 = 'workspace 9'
          ctrl-alt-a = 'workspace A' # In your config, you can drop workspace bindings that you don't need
          ctrl-alt-b = 'workspace B'
          ctrl-alt-c = 'workspace C'
          ctrl-alt-d = 'workspace D'
          ctrl-alt-e = 'workspace E'
          ctrl-alt-f = 'workspace F'
          ctrl-alt-g = 'workspace G'
          ctrl-alt-i = 'workspace I'
          ctrl-alt-m = 'workspace M'
          ctrl-alt-n = 'workspace N'
          ctrl-alt-o = 'workspace O'
          ctrl-alt-p = 'workspace P'
          ctrl-alt-q = 'workspace Q'
          ctrl-alt-r = 'workspace R'
          ctrl-alt-s = 'workspace S'
          ctrl-alt-t = 'workspace T'
          ctrl-alt-u = 'workspace U'
          ctrl-alt-v = 'workspace V'
          ctrl-alt-w = 'workspace W'
          ctrl-alt-x = 'workspace X'
          ctrl-alt-y = 'workspace Y'
          ctrl-alt-z = 'workspace Z'

          # See: https://nikitabobko.github.io/AeroSpace/commands#move-node-to-workspace
          ctrl-alt-shift-1 = 'move-node-to-workspace 1'
          ctrl-alt-shift-2 = 'move-node-to-workspace 2'
          ctrl-alt-shift-3 = 'move-node-to-workspace 3'
          ctrl-alt-shift-4 = 'move-node-to-workspace 4'
          ctrl-alt-shift-5 = 'move-node-to-workspace 5'
          ctrl-alt-shift-6 = 'move-node-to-workspace 6'
          ctrl-alt-shift-7 = 'move-node-to-workspace 7'
          ctrl-alt-shift-8 = 'move-node-to-workspace 8'
          ctrl-alt-shift-9 = 'move-node-to-workspace 9'
          ctrl-alt-shift-a = 'move-node-to-workspace A'
          ctrl-alt-shift-b = 'move-node-to-workspace B'
          ctrl-alt-shift-c = 'move-node-to-workspace C'
          ctrl-alt-shift-d = 'move-node-to-workspace D'
          ctrl-alt-shift-e = 'move-node-to-workspace E'
          ctrl-alt-shift-f = 'move-node-to-workspace F'
          ctrl-alt-shift-g = 'move-node-to-workspace G'
          ctrl-alt-shift-i = 'move-node-to-workspace I'
          ctrl-alt-shift-m = 'move-node-to-workspace M'
          ctrl-alt-shift-n = 'move-node-to-workspace N'
          ctrl-alt-shift-o = 'move-node-to-workspace O'
          ctrl-alt-shift-p = 'move-node-to-workspace P'
          ctrl-alt-shift-q = 'move-node-to-workspace Q'
          ctrl-alt-shift-r = 'move-node-to-workspace R'
          ctrl-alt-shift-s = 'move-node-to-workspace S'
          ctrl-alt-shift-t = 'move-node-to-workspace T'
          ctrl-alt-shift-u = 'move-node-to-workspace U'
          ctrl-alt-shift-v = 'move-node-to-workspace V'
          ctrl-alt-shift-w = 'move-node-to-workspace W'
          ctrl-alt-shift-x = 'move-node-to-workspace X'
          ctrl-alt-shift-y = 'move-node-to-workspace Y'
          ctrl-alt-shift-z = 'move-node-to-workspace Z'

          # See: https://nikitabobko.github.io/AeroSpace/commands#workspace-back-and-forth
          ctrl-alt-tab = 'workspace-back-and-forth'
          # See: https://nikitabobko.github.io/AeroSpace/commands#move-workspace-to-monitor
          ctrl-alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

          # See: https://nikitabobko.github.io/AeroSpace/commands#mode
          ctrl-alt-shift-semicolon = 'mode service'

      # 'service' binding mode declaration.
      # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
      [mode.service.binding]
          esc = ['reload-config', 'mode main']
          r = ['flatten-workspace-tree', 'mode main'] # reset layout
          f = ['layout floating tiling', 'mode main'] # Toggle between floating and tiling layout
          backspace = ['close-all-windows-but-current', 'mode main']

          ctrl-alt-shift-h = ['join-with left', 'mode main']
          ctrl-alt-shift-j = ['join-with down', 'mode main']
          ctrl-alt-shift-k = ['join-with up', 'mode main']
          ctrl-alt-shift-l = ['join-with right', 'mode main']
    '';
  };
}
