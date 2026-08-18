{ pkgs, lib, config, ... }:
let
  # zsh-forgit のラッパーは PATH の先頭に nixpkgs 既定の git を差し込む。
  # 素の pkgs.zsh-forgit のままだと、シェルで直接叩く git (git.nix で 2.55.0 に
  # 差し替え済み) と forgit の内部で動く git がズレる。override で同じ派生を渡して揃える。
  forgit = pkgs.zsh-forgit.override { git = config.programs.git.package; };

  # forgit のサブコマンドと、それに割り当てるエイリアス名 / 補完に出す1行説明。
  #
  # 既定のエイリアス名 (ga, gd, glo …) は使わない。理由は2つ:
  #   - oh-my-zsh の git プラグインと 16 個が同名で、どちらを採るか読み込み順に
  #     依存する不安定な状態になる。
  #   - g で始まるコマンドが多すぎる。この環境では `g<TAB>` の候補が 403 個
  #     (oh-my-zsh の g* エイリアス 197 個 + GNU coreutils の g* 一式) になり、
  #     zsh が "do you wish to see all 403 possibilities (187 lines)?" と聞く。
  #     説明付きで候補を出しても大量の列組みに埋もれてリファレンスにならない。
  # fg プレフィクスに寄せると衝突が消え、`fg<TAB>` の候補が fg / fgrep と
  # forgit の 29 個だけになるので、補完一覧がそのままコマンド表として読める。
  commands = [
    { sub = "add";                       alias = "fga";     desc = "ステージするファイルを選択"; }
    { sub = "reset_head";                alias = "fgrh";    desc = "ステージ解除するファイルを選択"; }
    { sub = "restore";                   alias = "fgrs";    desc = "変更を捨てるファイルを選択 (git restore)"; }
    { sub = "checkout_file";             alias = "fgcf";    desc = "変更を捨てるファイルを選択 (git checkout の旧形式)"; }
    { sub = "checkout_file_from_commit"; alias = "fgcff";   desc = "コミットを選んでファイルを復元"; }
    { sub = "log";                       alias = "fglo";    desc = "コミットログビューア"; }
    { sub = "reflog";                    alias = "fgrl";    desc = "reflog ビューア"; }
    { sub = "diff";                      alias = "fgd";     desc = "diff ビューア"; }
    { sub = "show";                      alias = "fgso";    desc = "git show ビューア"; }
    { sub = "blame";                     alias = "fgbl";    desc = "blame するファイルを選択"; }
    { sub = "ignore";                    alias = "fgi";     desc = ".gitignore を生成 (初回のみ要ネットワーク)"; }
    { sub = "attributes";                alias = "fgat";    desc = ".gitattributes を生成"; }
    { sub = "checkout_branch";           alias = "fgcb";    desc = "checkout するブランチを選択"; }
    { sub = "switch_branch";             alias = "fgsw";    desc = "switch するブランチを選択"; }
    { sub = "checkout_commit";           alias = "fgco";    desc = "checkout するコミットを選択"; }
    { sub = "checkout_tag";              alias = "fgct";    desc = "checkout するタグを選択"; }
    { sub = "branch_delete";             alias = "fgbd";    desc = "削除するブランチを選択"; }
    { sub = "revert_commit";             alias = "fgrc";    desc = "revert するコミットを選択"; }
    { sub = "cherry_pick";               alias = "fgcp";    desc = "ブランチを選んで cherry-pick"; }
    { sub = "rebase";                    alias = "fgrb";    desc = "rebase -i の起点コミットを選択"; }
    { sub = "fixup";                     alias = "fgfu";    desc = "fixup 先のコミットを選択"; }
    { sub = "squash";                    alias = "fgsq";    desc = "squash 先のコミットを選択"; }
    { sub = "reword";                    alias = "fgrw";    desc = "メッセージを書き直すコミットを選択"; }
    { sub = "clean";                     alias = "fgclean"; desc = "削除する未追跡ファイルを選択"; }
    { sub = "stash_show";                alias = "fgss";    desc = "stash ビューア"; }
    { sub = "stash_push";                alias = "fgsp";    desc = "stash に積むファイルを選択"; }
    { sub = "worktree";                  alias = "fgwt";    desc = "worktree ブラウザ"; }
    { sub = "worktree_add";              alias = "fgwa";    desc = "worktree を追加"; }
    { sub = "worktree_delete";           alias = "fgwd";    desc = "削除する worktree を選択"; }
  ];

  # プラグインは各エイリアス名を forgit_<サブコマンド> 変数から読む
  # (`builtin export forgit_add="${forgit_add:-ga}"`)。source より前に置く必要がある。
  aliasOverrides = lib.concatMapStringsSep "\n" (c: "forgit_${c.sub}=${c.alias}") commands;

  aliasNames = lib.concatMapStringsSep " " (c: c.alias) commands;
  fakeMatches = lib.concatMapStringsSep " \\\n      " (c: "'${c.alias}:${c.desc}'") commands;
in
{
  # forgit: git 操作を fzf でインタラクティブにするラッパー。
  # https://github.com/wfxr/forgit
  #
  # zsh-forgit パッケージが供給するもの:
  #   - bin/git-forgit                         … `git forgit <cmd>` のサブコマンド本体
  #   - share/zsh/zsh-forgit/forgit.plugin.zsh … zsh 関数とエイリアス (下で source する)
  #   - share/zsh/site-functions/_git-forgit   … 補完。~/.nix-profile 経由で fpath に載る
  home.packages = [ forgit ];

  # mkOrder は付けない (= 既定の 1000)。zsh.nix の initContent (order 1200) より
  # 前でありさえすればよい。あちらは末尾で herdr/tmux を起動してそこで実行が
  # 止まるため、後ろに置くとマルチプレクサを抜けるまでエイリアスが定義されない。
  programs.zsh.initContent = ''
    ${aliasOverrides}
    source ${forgit}/share/zsh/zsh-forgit/forgit.plugin.zsh

    # コマンド位置の補完 (fg<TAB>) に forgit のコマンド表を出す。
    #
    # 素のエイリアス候補は落とす。zsh はエイリアスを説明なしで compadd するため、
    # 下の fake と統合されず「説明付き1件 + 列組みの中に1件」の二重表示になる。
    zstyle ':completion:*:*:-command-:*:aliases' ignored-patterns ${aliasNames}

    # 説明は executables タグに載せる。このタグは PATH に "." が無い限り候補が
    # ゼロで、_command_names が fake スタイル用の空き枠として意図的に
    # _description だけ呼んでいる ("this is ignored but exists to facilitate the
    # use of the fake style")。専用グループになるので、他の補完の見た目を
    # 変えずに forgit だけを一覧の先頭にまとめられる。
    zstyle ':completion:*:*:-command-:*:executables' format '%F{yellow}-- forgit --%f'
    zstyle ':completion:*:*:-command-:*:executables' fake \
      ${fakeMatches}
  '';
}
