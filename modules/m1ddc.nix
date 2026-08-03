{ lib, ... }:
{
  # 外部ディスプレイの入力切り替え(m1ddc / DDC-CI)。
  #
  # home.nix ではなく hosts/mac.nix からのみ import する。m1ddc は Apple Silicon 専用
  # かつ UUID も机上の実機に紐づくため、Linux 側へ持ち込む意味がない。
  # stdenv.isDarwin でガードせず import 元で分けているのは、構成ファイルを読んだときに
  # 「この設定がどのホストに入るか」を条件式ではなく import 関係で追えるようにするため。
  #
  # m1ddc 本体は nix ではなく homebrew 管理(brew install m1ddc)。新しいマシンでは
  # `home-manager switch` だけでは入らないので別途インストールが必要。
  programs.zsh.initContent = lib.mkOrder 1300 ''
    # ディスプレイ名 → UUID。m1ddcのdisplay番号(1,2...)を使わないのは、
    # CGGetOnlineDisplayListの返す順序が接続順や再起動で入れ替わり、
    # 別のモニタを誤って切り替えてしまうため。
    m1ddc-uuid() {
      case "$1" in
        dell) echo "A08557B8-C7A6-48D6-8232-00A42B52E5C6" ;;  # DELL U3223QE
        benq) echo "BDD65C3C-EBC9-4866-A494-0FF997B7F844" ;;  # BenQ RD320UA
        *)    echo "$1" ;;
      esac
    }

    # 入力ソースを読み出す: m1ddc-probe dell [試行回数] [間隔秒]
    # モニタのOSDで入力を切り替えるたびに実行し、出現数の多い値をそのポートのコードとする。
    #
    # 単発ではなく複数回読むのは、DDC読み取りが一定割合で失敗し、そのとき
    # ディスプレイ固有の固定値が返るため(DELL=110(0x6E, DDCのアドレスバイト) /
    # BenQ=0(空バッファ))。この値は luminance や contrast を読んでも同じものが
    # 出るので、実値と区別できる。
    #
    # 間隔のデフォルトを1秒と長めに取るのは、0.3秒では全試行が失敗値になったため。
    # m1ddc側の待ち(headers/i2c.h の DDC_WAIT=10ms)がこのモニタには足りない。
    m1ddc-probe() {
      local target="''${1:?dell / benq / UUID を指定してください}"
      local count="''${2:-10}"
      local delay="''${3:-1}"
      local uuid raw i
      uuid=$(m1ddc-uuid "$target")

      for ((i = 1; i <= count; i++)); do
        raw=$(m1ddc display "$uuid" get input)
        # 2>/dev/null で弾けないのは、m1ddcがDDC通信失敗のメッセージも
        # /dev/stdout へ書くため(sources/m1ddc.m の writeToStdOut)。
        [[ "$raw" =~ '^-?[0-9]+$' ]] || continue
        # m1ddcはVCP値を signed char で保持するので128以上が負数で出る
        # (LGの input-alt 208 → -48)。VCPの実値へ戻す。
        (( raw < 0 )) && raw=$(( raw + 256 ))
        echo "$raw"
        sleep "$delay"
      done | sort -n | uniq -c | sort -rn
    }

    # 入力を切り替える: m1ddc-input dell 27
    # 現在値を読んで分岐させないのは、get input の単発読み取りが 0 や 110(=0x6E,
    # DDCのアドレスバイト)を返して安定しないため。setは無条件に叩く。
    m1ddc-input() {
      local target="''${1:?dell / benq / UUID を指定してください}"
      local code="''${2:?入力コードを指定してください}"
      m1ddc display "$(m1ddc-uuid "$target")" set input "$code"
    }

    # 2台まとめて Mac / Win へ切り替える。
    #   DELL U3223QE  17=Mac / 27=Win
    #   BenQ RD320UA  19=Mac(USB-C) / 15=Win(DP)
    # MCCS標準表(0x0F〜0x12)を使わないのは、BenQのUSB-Cが19(0x13)と
    # 標準表に無い値を返すため。表は当てにせず実測値を直に持つ。
    #
    # DELL の Win 側は m1ddc-probe では決められず目視で確定させた。このモニタは
    # 信号の無い入力でも選択状態を保持し続けるので、15 と 27 のどちらに信号が
    # あるかを読み戻しから判別できない(無効コード投入時のフォールバック先も、
    # 確実に信号のある 17 を飛ばして 27 になるため判定材料にならない)。
    #
    # BenQ を先に切り替えて待つのは、Win機が BenQ を Win 入力として掴むまで
    # DELL へ出力を出さないため。逆順だと DELL が無信号の入力に飛ぶ。
    disp-win() {
      m1ddc-input benq 15 > /dev/null
      sleep 5
      m1ddc-input dell 27 > /dev/null
      echo "→ Win (BenQ=15 / DELL=27)"
    }

    # Win表示中でもMac側からDDCが届くことは実機で確認済み。
    # 2周させるのは、DDC書き込みが応答を返さず取りこぼしを検知できないため。
    # 取りこぼすとWin表示のまま復帰操作をやり直すことになり手間が大きい。
    disp-mac() {
      local i
      for i in 1 2; do
        m1ddc-input dell 17 > /dev/null
        m1ddc-input benq 19 > /dev/null
        sleep 1
      done
      echo "→ Mac (DELL=17 / BenQ=19)"
    }
  '';
}
