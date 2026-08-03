{ lib, ... }:
{
  # 外部ディスプレイの入力切り替え(WSL側。ControlMyMonitor経由のDDC/CI)。
  #
  # home.nix ではなく hosts/linux.nix からのみ import する。WSL2 は GPU-PV で
  # GPU を仮想化しており、DDC/CI 通信に使う I2C バスがゲスト(WSL)側には
  # 公開されない。そのため Linux ネイティブの ddcutil はこの環境では動作せず、
  # DDC/CI 通信自体は Windows 側の ControlMyMonitor(NirSoft)に行わせ、WSL の
  # zsh からは interop 経由でその実行ファイルを叩くだけのラッパーにしている。
  # コマンド名は modules/m1ddc.nix(Mac側)の disp-win / disp-mac に合わせた。
  #
  # ControlMyMonitor 本体は nix ではなく Windows 側で scoop 管理
  # (scoop bucket add nirsoft && scoop install controlmymonitor)。
  # 新しいマシンでは `home-manager switch` だけでは入らないので別途インストールが必要。
  #
  # モニタ識別には Short Monitor ID を使う(ControlMyMonitor.exe /smonitors "" で
  # 確認できる)。DISPLAYn の番号は接続順で入れ替わるが、Short Monitor ID は
  # EDID 由来で固定される。
  #
  # VCP 60(Input Select)の値は Mac 側 m1ddc.nix と同じ
  # (BenQ RD320UA 15=Win(DP)/19=Mac(USB-C), DELL U3223QE 27=Win/17=Mac)。
  # DDC/CI はモニタ側の仕様で OS に依存しないため、実機で
  # `ControlMyMonitor.exe /GetValue BNQ809F 60` → 15、
  # `ControlMyMonitor.exe /GetValue DEL4276 60` → 27 と、
  # Mac 側の実測値がそのまま通用することを確認済み。
  home.sessionVariables = {
    # scoop install 先。ユーザー名(m1205)が変わる/別マシンの場合は要修正。
    CMM_EXE = "/mnt/c/Users/m1205/scoop/apps/controlmymonitor/current/ControlMyMonitor.exe";
  };

  programs.zsh.initContent = lib.mkOrder 1300 ''
    # モニタ名 → Short Monitor ID。
    ddc-id() {
      case "$1" in
        dell) echo "DEL4276" ;;  # DELL U3223QE
        benq) echo "BNQ809F" ;;  # BenQ RD320UA
        *)    echo "$1" ;;
      esac
    }

    # 入力を切り替える: ddc-input dell 27
    ddc-input() {
      local target="''${1:?dell / benq / Short Monitor ID を指定してください}"
      local code="''${2:?入力コードを指定してください}"
      "$CMM_EXE" /SetValue "$(ddc-id "$target")" 60 "$code" > /dev/null
    }

    disp-win() {
      ddc-input benq 15
      ddc-input dell 27
      echo "→ Win (BenQ=15 / DELL=27)"
    }

    disp-mac() {
      ddc-input dell 17
      ddc-input benq 19
      echo "→ Mac (DELL=17 / BenQ=19)"
    }
  '';
}
