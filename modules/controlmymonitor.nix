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
  programs.zsh.initContent = lib.mkOrder 1300 ''
    # scoop install 先。ユーザー名(m1205)が変わる/別マシンの場合は要修正。
    #
    # home.sessionVariables ではなくここで直接定義しているのは、
    # hm-session-vars.sh 側の「一度だけsourceする」ガード(__HM_SESS_VARS_SOURCED)
    # のせいで、tmux 等の既存シェルから新しい zsh を起動した場合に環境変数が
    # 引き継がれ、新規追加した変数が再読み込みされないため。initContent の
    # 変数は .zshrc が読まれる対話シェル起動のたびに必ず再定義される。
    CMM_EXE="/mnt/c/Users/m1205/scoop/apps/controlmymonitor/current/ControlMyMonitor.exe"

    # モニタ名 → Short Monitor ID。
    ddc-id() {
      case "$1" in
        dell) echo "DEL4276" ;;  # DELL U3223QE
        benq) echo "BNQ809F" ;;  # BenQ RD320UA
        *)    echo "$1" ;;
      esac
    }

    # WSL_INTEROP を、実際に exe が起動できるソケットに合わせる。
    #
    # 掴んだソケットは提供元(wsl.exe を開いた Windows 側の端末)が閉じれば無効に
    # なるので、長く開いたままの zsh — 特に Mac から SSH したセッション — では
    # 起動時に入れた値がいつのまにか死んでいる。この状態で叩くと exe が
    # "Invalid argument" で落ち、2台とも切り替わらない。
    #
    # 死活は事前判定できない(ソケットは残り connect も通る)ため、候補を順に
    # 当てて実際に起動できたものを採る。判定に /smonitors を使うのは DDC 通信を
    # 伴わず 0.1 秒で返るため(/GetValue は DDC を読むので 1.3 秒かかる)。
    cmm-ensure() {
      local sock
      "$CMM_EXE" /smonitors "" > /dev/null 2>&1 && return 0

      for sock in ''${(f)"$(wsl-interop-list)"}; do
        export WSL_INTEROP="$sock"
        "$CMM_EXE" /smonitors "" > /dev/null 2>&1 && return 0
      done

      print -u2 "ControlMyMonitor を起動できません(有効な WSL_INTEROP が無い)。Windows 側で WSL の端末を1つ開いてから再実行してください。"
      return 1
    }

    # 対象モニタが Windows から見えているか。
    # /smonitors の出力は UTF-16LE なので iconv を通す。Short Monitor ID は
    # 引用符ごと照合する(Monitor ID 行の MONITOR\BNQ809F\... に誤爆させない)。
    ddc-visible() {
      "$CMM_EXE" /smonitors "" 2>/dev/null \
        | iconv -f UTF-16LE -t UTF-8 2>/dev/null \
        | grep -q "\"$1\""
    }

    # 入力を切り替える: ddc-input dell 27
    #
    # /SetValue は成否を返さない。存在しないモニタを指定しても、でたらめな ID を
    # 渡しても exit 0 で返る(exit code を返すのは /GetValue だけ)。そのため
    # 書きっぱなしでは何も検証できず、失敗しても無音で終わる。/GetValue で
    # 読み戻して確かめ、DDC 書き込みの取りこぼしはリトライで拾う。
    #
    # 読み戻せなくなった場合は成功とみなす。DELL U3223QE は Win 以外の入力へ移ると
    # Windows の列挙から丸ごと消えるため(BenQ は DP リンクを保つので見え続ける)、
    # 切り替えが効いた結果として読み戻し自体ができなくなる。
    ddc-input() {
      local target="''${1:?dell / benq / Short Monitor ID を指定してください}"
      local code="''${2:?入力コードを指定してください}"
      local id i now

      cmm-ensure || return 1
      id=$(ddc-id "$target")

      # 最初から見えていないなら、そのモニタは既に別 OS の入力を表示している。
      # WSL 側からは DDC が届かないので、切り替えは Mac 側から行うしかない。
      if ! ddc-visible "$id"; then
        print -u2 "$target ($id) が Windows から見えません。別の入力を表示中のため WSL 側からは切り替えられません。"
        return 1
      fi

      for ((i = 1; i <= 3; i++)); do
        "$CMM_EXE" /SetValue "$id" 60 "$code" > /dev/null 2>&1
        "$CMM_EXE" /GetValue "$id" 60 > /dev/null 2>&1
        now=$?
        (( now == code )) && return 0
        ddc-visible "$id" || return 0
      done

      print -u2 "$target ($id) を $code に切り替えられませんでした (現在値 $now)"
      return 1
    }

    # 片方が失敗しても残りは試す。1台だけ切り替わった状態こそ復帰させたいため。
    disp-win() {
      local ng=0
      ddc-input benq 15 || ng=1
      ddc-input dell 27 || ng=1
      (( ng )) && return 1
      echo "→ Win (BenQ=15 / DELL=27)"
    }

    disp-mac() {
      local ng=0
      ddc-input dell 17 || ng=1
      ddc-input benq 19 || ng=1
      (( ng )) && return 1
      echo "→ Mac (DELL=17 / BenQ=19)"
    }
  '';
}
