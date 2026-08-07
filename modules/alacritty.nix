{ pkgs, lib, ... }:
let
  # AlacrittyはWindows側のアプリケーション(WSLからwsl.exe経由で起動される)であり、
  # このLinux環境には本体をインストールしない。設定ファイルの配置のみ行う。
  # 内容がWSL/Windows前提(wsl.exe起動)のため、Mac側では無効化する。
  # Macで使う場合は別途 Mac用の内容に書き直すこと。
  #
  # 置き場所: Windows版 Alacritty が読むのは %APPDATA%\alacritty\alacritty.toml で、
  # WSL側の ~/.alacritty.toml は読まれない。以前はそちらに置いていたため設定が効かず、
  # Windows側の手書きファイルと内容がずれていた。nix を唯一の出所にするため、生成物を
  # activation で Windows のパスへ直接書き出す。
  # UNC(\\wsl.localhost\...)経由の import にしない理由: home.file が張るのは nix store への
  # symlink で、リンク先が Linux の絶対パスなので Windows 側から辿れない(実ファイルなら読める)。
  # 直接書き出しなら 9P を経由しないので、起動時のディストロ待ちも、live_config_reload の
  # ファイル監視がネットワークパス上で効かない問題も起きない。
  winAlacrittyDir = "/mnt/c/Users/m1205/AppData/Roaming/alacritty";

  # Windows の Win(Super)ショートカットを押すと、端末に文字が混入する問題への対処。
  # 例: Win-V(クリップボード履歴)を押すと、履歴から選んだ文字列がペーストされる前に
  # "v" が入力される。Alacritty はバインドに一致しないキーをそのまま文字として PTY へ
  # 書き込む仕様で、Super 修飾は文字生成に影響しないため "v" が素通りするのが原因。
  # 一致するバインドが1つでもあると Alacritty は文字送出を抑制する(ReceiveChar を除く)ので、
  # 何もしない action = "None" を置いて潰す。バインドの照合はキーシーケンス構築より前に
  # 走るため、kitty keyboard protocol の有効/無効(herdr が有効化する)に関わらず効く。
  # Windows 側のショートカット動作自体は OS が処理するので、履歴からのペーストは
  # Ctrl-V 送出として届き、下の Paste バインドで従来どおり機能する。
  # Alacritty にワイルドカード指定が無いため、英数字36個を列挙して生成する。
  superSuppressedKeys = lib.stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  superSuppressBindings = lib.concatMapStrings (key: ''

    [[keyboard.bindings]]
    key = "${key}"
    mods = "Super"
    action = "None"
  '') superSuppressedKeys;

  configFile = pkgs.writeText "alacritty.toml" ''
    # このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
    # 変更は ~/nix-config/modules/alacritty.nix を編集して home-manager switch する。

    # ローカル固有設定の読み込み(このマシン専用)。Alacritty は Windows アプリなので
    # ~ は %USERPROFILE% に解決される(= C:\Users\m1205\.alacritty.toml.local)。
    # ファイルが無いときはログに残るだけで無視される。
    [general]
    import = ["~/.alacritty.toml.local"]

    [terminal.shell]
    program = "/Windows/System32/wsl.exe"
    args = ["~", "-d", "Ubuntu"]

    [font]
    size = 15

    [font.normal]
    family = "HackGen Console NF"
    style = "Regular"

    [[keyboard.bindings]]
    key = "V"
    mods = "Control"
    action = "Paste"

    # Win(Super)+英数字は文字を送出させない(理由は modules/alacritty.nix 参照)
    ${superSuppressBindings}
  '';
in
{
  home.activation = lib.mkIf pkgs.stdenv.isLinux {
    alacrittyWindowsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "/mnt/c/Users/m1205" ]; then
        run mkdir -p "${winAlacrittyDir}"
        run install -m 644 ${configFile} "${winAlacrittyDir}/alacritty.toml"
      fi
    '';
  };
}
