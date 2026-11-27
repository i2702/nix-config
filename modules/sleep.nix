{ pkgs, ... }:
let
  # 画面だけを消す。Mac 本体は起きたままなので Bluetooth の状態も変わらない。
  # 待ってから消すのは、コマンドを打った Enter を離した入力で即座に点き直すため。
  disp-sleep = pkgs.writeShellApplication {
    name = "disp-sleep";
    text = ''
      sleep "''${1:-2}"
      /usr/bin/pmset displaysleepnow
    '';
  };

  # Bluetooth を切ってから Mac 本体をスリープさせ、復帰したら Bluetooth を戻す。
  #
  # Bluetooth を切るのは、本体がスリープに入ると Cornix (BLE キーボード) が
  # 入力を送ってきて数秒で復帰してしまうため (pmset -g log の復帰理由が
  # bluetooth-pcie/HID Activity)。macOS には Bluetooth 機器による復帰だけを
  # 止める設定が残っていない。
  #
  # 復帰の検知を sleepwatcher などの常駐に任せないのは、blueutil には Bluetooth の
  # アクセス許可が要り、launchd から起動すると許可ダイアログを出す先が無いため。
  # このスクリプト自体が復帰まで待ち、ターミナルの許可で Bluetooth を戻す。
  #
  # 復帰は kern.waketime の変化で判定する。sleep 1 の繰り返しで待てるのは、
  # スリープ中はこのプロセスも止まり、待ち時間がスリープ時間ぶん進まないため。
  mac-sleep = pkgs.writeShellApplication {
    name = "mac-sleep";
    runtimeInputs = [ pkgs.blueutil ];
    text = ''
      # スリープに入らなかったときに Bluetooth を切ったまま放置しないための上限(秒)。
      # pmset sleepnow は画面を消してから本体が眠るまで5秒ほどかかる。
      timeout=60

      before=$(/usr/sbin/sysctl -n kern.waketime)
      # 元から Bluetooth が切れていたなら、復帰後も切ったままにする。
      was_on=$(blueutil --power)

      [[ $was_on == 1 ]] && blueutil --power 0
      /usr/bin/pmset sleepnow

      for ((i = 0; i < timeout; i++)); do
        sleep 1
        [[ $(/usr/sbin/sysctl -n kern.waketime) != "$before" ]] && break
      done

      if [[ $was_on == 1 ]]; then
        blueutil --power 1
      fi
      if (( i >= timeout )); then
        echo "⚠️ スリープしませんでした。Bluetooth は元に戻しました" >&2
        exit 1
      fi
    '';
  };
in
{
  # スリープ関連のコマンド。pmset / sysctl は macOS 標準のものを絶対パスで使う。
  home.packages = [
    disp-sleep
    mac-sleep
  ];
}
