{ pkgs, lib, ... }:
let
  # WezTermはWindows側のアプリケーション(WSLのUbuntuを起動する端末)であり、
  # このLinux環境には本体をインストールしない。設定ファイルの配置のみ行う。
  # 内容がWSL/Windows前提のため、Mac側では無効化する(Macで使う端末は ghostty.nix)。
  #
  # 置き場所: Windows版 WezTerm の設定探索順は
  #   %WEZTERM_CONFIG_FILE% → exe と同じディレクトリ → %USERPROFILE%\.config\wezterm\wezterm.lua
  #   → %USERPROFILE%\.wezterm.lua
  # で、WSL側の ~/.config は読まれない。よって alacritty.nix と同じく、生成物を activation で
  # Windows のパスへ直接書き出す。UNC(\\wsl.localhost\...)経由にしない理由も同じで、home.file が
  # 張るのは nix store への symlink であり、リンク先が Linux の絶対パスなので Windows 側から
  # 辿れない。直接書き出しなら 9P を経由しないため、WezTerm の設定自動リロード
  # (automatically_reload_config)のファイル監視もそのまま効く。
  winHome = "/mnt/c/Users/m1205";

  configFile = pkgs.writeText "wezterm.lua" ''
    -- このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
    -- 変更は ~/nix-config/modules/wezterm.nix を編集して home-manager switch する。

    local wezterm = require 'wezterm'
    local act = wezterm.action
    local config = wezterm.config_builder()

    -- WSL の Ubuntu を既定の接続先にする。wsl.exe を default_prog で直接起動する手もあるが
    -- (Alacritty はそうしている)、ドメインにしておくと新しいタブやペインも同じ Ubuntu 上で
    -- 開き、カレントディレクトリも引き継がれる。
    -- default_cwd を省くと Windows 側のカレント(/mnt/c/...)で開くので明示する。
    config.wsl_domains = {
      {
        name = 'WSL:Ubuntu',
        distribution = 'Ubuntu',
        default_cwd = '~',
      },
    }
    config.default_domain = 'WSL:Ubuntu'

    config.font = wezterm.font 'HackGen Console NF'
    config.font_size = 15

    -- ウィンドウ分割やタブは tmux 側で行うため、WezTerm のタブバーは場所を取るだけ。
    -- 単一タブのときは隠して Alacritty と同じ見た目にする。
    config.hide_tab_bar_if_only_one_tab = true

    config.keys = {
      { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
    }

    -- Windows の Win(Super)ショートカットを押すと、端末に文字が混入する問題への対処。
    -- 例: Win-V(クリップボード履歴)を押すと、履歴から選んだ文字列がペーストされる前に
    -- "v" が入力される。バインドに一致しないキーはそのまま文字として PTY へ書き込まれ、
    -- Super 修飾は文字生成に影響しないため素通りするのが原因(経緯は alacritty.nix 参照)。
    -- 何もしない Nop を割り当てて潰す。SUPER+英数字には既定バインド(SUPER-c=Copy、
    -- SUPER-t=SpawnTab、SUPER-1..9=タブ切替 など)があるが、Windows では Win+英数字は
    -- OS のショートカットに奪われて WezTerm まで届かないため、潰しても実質失うものは無い。
    -- どの文字に既定があるかはバージョンで変わるので、範囲を絞らず英数字を一律に潰す。
    -- Windows 側のショートカット動作自体は OS が処理するので、履歴からのペーストは
    -- Ctrl-V 送出として届き、上の PasteFrom バインドで従来どおり機能する。
    for key in ('abcdefghijklmnopqrstuvwxyz0123456789'):gmatch('.') do
      table.insert(config.keys, { key = key, mods = 'SUPER', action = act.Nop })
    end

    -- ローカル固有設定の読み込み(このマシン専用)。WezTerm は Windows アプリなので
    -- home_dir は %USERPROFILE% (= C:\Users\m1205)。設定テーブルを返すファイルを置くと
    -- その内容で上書きする。ファイルが無いときは黙って無視される。
    local ok, overrides = pcall(dofile, wezterm.home_dir .. '/.wezterm.local.lua')
    if ok and type(overrides) == 'table' then
      for k, v in pairs(overrides) do
        config[k] = v
      end
    end

    return config
  '';
in
{
  home.activation = lib.mkIf pkgs.stdenv.isLinux {
    weztermWindowsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "${winHome}" ]; then
        run install -m 644 ${configFile} "${winHome}/.wezterm.lua"
      fi
    '';
  };
}
