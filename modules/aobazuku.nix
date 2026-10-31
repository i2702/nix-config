{ lib, config, ... }:
{
  # aobazuku(Bluesky クライアント)の共有設定。認証情報(handle / app_password)は
  # 公開リポジトリと Nix store に載せないため、ここには書かず、マシンごとの
  # ~/.config/aobazuku/config.local.toml(リポジトリ管理外)に置く。aobazuku は
  # config.toml に config.local.toml を重ねて読み、local 側に書かれたキーが勝つ。
  xdg.configFile."aobazuku/config.toml".text = ''
    # herdr-app のペインは Kitty graphics の問い合わせ (a=q) に応答せず、自動判定が
    # halfblocks に落ちる(アイコンが 4x4 画素になる)ため明示する。herdr-app 側が直るまでの
    # 応急処置。Kitty graphics を持たない端末では AOBAZUKU_PROTOCOL か config.local.toml で上書きする。
    protocol = "kitty"

    [[columns]]
    kind = "timeline"

    [[columns]]
    kind = "notifications"

    [[columns]]
    kind = "author"

    [[columns]]
    kind = "pinned"          # 公式アプリでピン留めしたフィード/リストがここに展開される
  '';

  # config.local.toml が無くても aobazuku の起動時に案内が出るだけなので、git.nix の
  # config.local と違って activation は止めない。aobazuku を使わないマシンもあるため。
  home.activation.warnAobazukuConfigLocal =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      cfgLocal="${config.home.homeDirectory}/.config/aobazuku/config.local.toml"
      if [ ! -f "$cfgLocal" ]; then
        echo "" >&2
        echo "WARNING: $cfgLocal が見つかりません(aobazuku の認証情報 / リポジトリ管理外)。" >&2
        echo "aobazuku を使うなら、テンプレートをコピーして handle / app_password を書き換えてください:" >&2
        echo "  install -m 600 <このリポジトリ>/templates/aobazuku-config.local.example \"$cfgLocal\"" >&2
        echo "" >&2
      fi
    '';
}
