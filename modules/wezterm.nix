{ pkgs, lib, ... }:
let
  # WezTermはWindows側のアプリケーション(WSLのUbuntuを起動する端末)であり、
  # このLinux環境には本体をインストールしない。設定ファイルの配置のみ行う。
  # 内容がWSL/Windows前提のため、Mac側では無効化する(Macで使う端末は ghostty.nix)。
  #
  # 置き場所: Windows版 WezTerm の設定探索順は
  #   %WEZTERM_CONFIG_FILE% → exe と同じディレクトリ → %USERPROFILE%\.config\wezterm\wezterm.lua
  #   → %USERPROFILE%\.wezterm.lua
  # で、WSL側の ~/.config は読まれない。よって生成物を activation で Windows のパスへ直接
  # 書き出す。UNC(\\wsl.localhost\...)経由にしない理由は、home.file が張るのは nix store への
  # symlink であり、リンク先が Linux の絶対パスなので Windows 側から辿れないため。
  # 直接書き出しなら 9P を経由しないため、WezTerm の設定自動リロード
  # (automatically_reload_config)のファイル監視もそのまま効く。
  winHome = "/mnt/c/Users/m1205";

  configFile = pkgs.writeText "wezterm.lua" ''
    -- このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
    -- 変更は ~/nix-config/modules/wezterm.nix を編集して home-manager switch する。

    local wezterm = require 'wezterm'
    local act = wezterm.action
    local config = wezterm.config_builder()

    -- WSL の Ubuntu を既定の接続先にする。ただし wsl.exe は使わず SSH で入る。
    -- wsl.exe を起動すると間に Windows の ConPTY が挟まり、ConPTY が Kitty graphics の
    -- APC シーケンス(ESC _G ...)を捨てるため、端末画像が一切表示できない。
    -- SSH なら ConPTY を通らず、WezTerm 自身が端末エミュレーションを行うので画像が通る。
    -- 上流でも未解決の既知問題で、回避策として wezterm ssh が案内されている(wezterm#1673)。
    -- 実測と手順は reporepo/github.com/i2702/aoao/WEZTERM.md を参照。
    config.ssh_domains = {
      {
        name = 'WSL:SSH',
        -- localhost と書くと ::1 に先に解決されるが、networkingMode=Mirrored では
        -- Windows → WSL の IPv6 ループバックが通らず、バナー待ちでタイムアウトする。
        -- IPv4 で明示する。
        remote_address = '127.0.0.1:2222',
        username = 'm1205062',
        -- 既定の 'WezTerm' はリモートに wezterm-mux-server を立てる方式で、画像の扱いに
        -- 難がある(wezterm#1237)。素の SSH 接続にする。
        multiplexing = 'None',
        assume_shell = 'Posix',
        ssh_option = { identityfile = wezterm.home_dir .. '/.ssh/id_ed25519' },
      },
    }
    config.default_domain = 'WSL:SSH'

    -- SSH で入れないとき(WSL 未起動、sshd 停止、鍵の入れ替え中など)の逃げ道として残す。
    -- 使うときは Windows 側から wezterm start --domain WSL:Ubuntu と叩く。
    -- default_cwd を省くと Windows 側のカレント(/mnt/c/...)で開くので明示する。
    config.wsl_domains = {
      {
        name = 'WSL:Ubuntu',
        distribution = 'Ubuntu',
        default_cwd = '~',
      },
    }

    config.font = wezterm.font 'HackGen Console NF'
    config.font_size = 15

    -- ウィンドウ分割やタブは tmux 側で行うため、WezTerm のタブバーは場所を取るだけ。
    -- 単一タブのときは隠す。
    config.hide_tab_bar_if_only_one_tab = true

    config.keys = {
      { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },
    }

    -- Windows の Win(Super)ショートカットを押すと、端末に文字が混入する問題への対処。
    -- 例: Win-V(クリップボード履歴)を押すと、履歴から選んだ文字列がペーストされる前に
    -- "v" が入力される。バインドに一致しないキーはそのまま文字として PTY へ書き込まれ、
    -- Super 修飾は文字生成に影響しないため素通りするのが原因。
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
