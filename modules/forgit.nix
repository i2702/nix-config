{ pkgs, lib, config, ... }:
let
  # zsh-forgit のラッパーは PATH の先頭に nixpkgs 既定の git を差し込む。
  # 素の pkgs.zsh-forgit のままだと、シェルで直接叩く git (git.nix で 2.55.0 に
  # 差し替え済み) と forgit の内部で動く git がズレる。override で同じ派生を渡して揃える。
  forgit = pkgs.zsh-forgit.override { git = config.programs.git.package; };
in
{
  # forgit: git 操作を fzf でインタラクティブにするラッパー。
  # https://github.com/wfxr/forgit
  #
  # zsh-forgit パッケージが供給するもの:
  #   - bin/git-forgit                         … `git forgit <cmd>` のサブコマンド本体
  #   - share/zsh/zsh-forgit/forgit.plugin.zsh … zsh 関数とエイリアス (下で source する)
  #   - share/zsh/site-functions/_git-forgit   … 補完。~/.nix-profile 経由で fpath に載る
  #
  # 注意: `gi` (forgit ignore) だけは初回実行時に github/gitignore を
  # ~/.cache/forgit へ clone する。nix で固定できない実行時ダウンロードなので、
  # ネットワークが無い環境ではこのサブコマンドだけ動かない。
  home.packages = [ forgit ];

  programs.zsh.initContent = lib.mkOrder 1150 ''
    # 読み込み順序が要件になっている:
    #   - oh-my-zsh の git プラグイン (order 800) より後。ga/gd/glo/gco/gcb/gcf/gss/
    #     gcp/gbd/gbl/gclean/grb/grh/grs/gsw/gwt の 16 個が git プラグインと同名で、
    #     後から alias したほうが勝つ。forgit 側を採用するのでここは 800 より後。
    #   - zsh.nix の initContent (order 1200) より前。あちらは末尾で herdr/tmux を
    #     起動してそこで実行が止まるため、後ろに置くとマルチプレクサを抜けるまで
    #     forgit のエイリアスが定義されない。
    source ${forgit}/share/zsh/zsh-forgit/forgit.plugin.zsh
  '';
}
