{ pkgs, ... }:
let
  # 作業を終えるコマンド。WSL の入った Windows 機を休止させ、Mac をスリープさせる。
  #
  # Why not (Mac 専用モジュールにしない理由): herdr で WSL に入ったペインから
  # 打ち間違えたときに、command not found ではなく Mac 専用だと分かる案内を出したい。
  # そのため Linux にも入れ、実行時に OS を見て弾く。mac-sleep を nix のパスで
  # 参照せず PATH から呼ぶのも同じ理由で、mac-sleep が依存する blueutil は
  # Linux ではビルドできない。
  bye = pkgs.writeShellApplication {
    name = "bye";
    text = ''
      if [[ $(uname -s) != Darwin ]]; then
        echo "bye は Mac 専用です。Mac から打ってください" >&2
        exit 1
      fi

      # shutdown.exe /h は /t で遅らせられず、すぐに休止に入る。そのまま呼ぶと
      # ssh の応答が返る前に接続ごと止まるため、setsid -f で ssh のセッションから
      # 切り離し、数秒待ってから休止させる。
      # 接続先の wsl は ~/.ssh/config の Host 名。
      remote='setsid -f sh -c "sleep 3; /mnt/c/Windows/System32/shutdown.exe /h" </dev/null >/dev/null 2>&1'
      if ssh -o ConnectTimeout=5 -o BatchMode=yes wsl "$remote"; then
        echo "Windows を3秒後に休止させます"
      else
        echo "⚠️ WSL に繋がりませんでした。Mac だけスリープします" >&2
      fi

      exec mac-sleep
    '';
  };
in
{
  home.packages = [ bye ];
}
