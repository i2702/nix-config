{ pkgs, lib, ... }:
{
  # alacritty自体はWindows側のアプリケーション(WSLからwsl.exe経由で起動される)であり、
  # このLinux環境にはインストールしない。設定ファイルの配置のみ行う。
  # 内容がWSL/Windows前提(wsl.exe起動)のため、Mac側では無効化する。
  # Macで使う場合は別途 Mac用の内容に書き直すこと。
  home.file.".alacritty.toml" = lib.mkIf pkgs.stdenv.isLinux {
    text = ''
      # ローカル固有設定の読み込み(このマシン専用: ~/.alacritty.toml.local)
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
    '';
  };
}
