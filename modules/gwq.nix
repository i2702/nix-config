{ pkgs, lib, ... }:
let
  # gwq は nixpkgs 未収録かつ公式リポジトリに flake も無いため、
  # リリースタグから buildGoModule でソースビルドする
  gwq = pkgs.buildGoModule rec {
    pname = "gwq";
    version = "0.1.1";

    src = pkgs.fetchFromGitHub {
      owner = "d-kuro";
      repo = "gwq";
      rev = "v${version}";
      hash = "sha256-MfCYFbODWnfPxx+6sLlcMT6tqghgILHB13+ccYqVjBA=";
    };

    vendorHash = "sha256-4K01Xf1EXl/NVX1loQ76l1bW8QglBAQdvlZSo7J4NPI=";

    subPackages = [ "cmd/gwq" ];
    env.CGO_ENABLED = 0;
    ldflags = [ "-s" "-w" ];

    # テストは git 実環境前提のものがあるためスキップ
    doCheck = false;
  };
in
{
  home.packages = [ gwq ];

  # このファイルは nix 管理の読み取り専用シンボリックリンクなので、`gwq config set` は使えない
  # (設定変更はこのモジュールを編集して home-manager switch で反映する)。
  xdg.configFile."gwq/config.toml".text = ''
    [cd]
    # shim (__GWQ_CD_SHIM) 経由のときだけ効くフラグなので、
    # スクリプトやエージェントの非対話 `gwq add` の挙動は変わらない。
    auto_cd_on_add = true
    # サブシェル起動(true)にしないのは、旧 herdr (TUI) がペイン cwd を
    # 「OSC 7 報告 → ペイン直下のルートシェルのプロセス cwd」の順で解決するため。
    # サブシェル方式だとルートシェルは元のディレクトリのまま gwq を待ってブロックし、
    # split / new_cwd = "follow" が worktree ではなく移動前のディレクトリに新ペインを開いてしまう。
    # false + シェル統合(zsh 側で source <(gwq completion zsh))なら現在のシェル自身が
    # builtin cd するので、herdr のプロセス cwd フォールバックが正しい場所を返す。
    launch_shell = false

    [finder]
    preview = true

    [naming]
    template = '{{.Host}}/{{.Owner}}/{{.Repository}}/{{.Branch}}'

    [naming.sanitize_chars]
    '/' = '-'
    ':' = '-'

    [ui]
    icons = true
    tilde_home = true

    [worktree]
    auto_mkdir = true
    basedir = '~/worktrees'

    # リポジトリごとの設定。リポジトリ側の .gwq.toml ではなく全体設定に書く。
    # .gwq.toml は cwd のファイルをフルパス単位で信頼するため、ワークツリーごとに信頼の確認が出る。
    # しかもその確認は、新しいペインの zsh 起動時の source <(gwq completion zsh) の中でも出る。
    # そこはバックグラウンドのプロセスで端末を読めず、y を打っても進まないままペインが止まる。
    # 全体設定は信頼の確認の対象外。
    # repository は MatchPath(doublestar)でリポジトリの絶対パスと照合する。先頭を / にするのは、
    # gwq の試験にある "/Users/**/repo" と同じ形にするため(先頭 ** の形は試験が無い)。
    [[repository_settings]]
    repository = "/**/up-stream/sptv-vega-tv-app"
    setup_commands = [
      # web/.env.e2e(IDCS 検証環境の secret)の実体はメインのチェックアウトにだけ置き、
      # 各ワークツリーからはシンボリックリンクで参照する。複製だと secret を差し替えたときに古い値が残る。
      'main="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"; [ -e web/.env.e2e ] || [ -L web/.env.e2e ] || ln -s "$main/web/.env.e2e" web/.env.e2e',
    ]
  '';

  # gwq のシェル統合(補完 + cd/add ラッパー関数)。
  # cd.launch_shell = false のとき、completion 出力の末尾に gwq() ラッパーが付き、
  # `gwq cd` / `gwq add`(cw も同じ)が現在のシェルで builtin cd するようになる。
  # compdef を使うため oh-my-zsh の compinit 後(mkOrder 1200 の後)に読み込む。
  programs.zsh.initContent = lib.mkOrder 1300 ''
    command -v gwq >/dev/null && source <(gwq completion zsh)

    # ローカルブランチと、リモートブランチのリモート名を除いた名前を列挙する
    __cw_branches() {
      {
        git for-each-ref --format='%(refname:lstrip=2)' refs/heads
        git for-each-ref --format='%(refname:lstrip=3)' refs/remotes
      } 2>/dev/null | command grep -Fxv HEAD | sort -u
    }

    # 新規ブランチの派生元。develop があれば develop、なければ main。
    # ローカルを優先し、無いときだけ origin/ を使う。
    __cw_base() {
      local ref
      for ref in refs/heads/develop refs/remotes/origin/develop refs/heads/main refs/remotes/origin/main; do
        if git show-ref --verify --quiet "$ref"; then
          print -r -- "$ref"
          return 0
        fi
      done
      return 1
    }

    cw() {
      # 引数1つ以外(引数なし・フラグ付き)と git リポジトリ外は gwq cd にそのまま渡す
      if (( $# != 1 )) || [[ $1 == -* ]] || ! git rev-parse --git-dir >/dev/null 2>&1; then
        gwq cd "$@"
        return
      fi

      # git worktree list の branch 行で照合する。gwq list / gwq get は部分一致なので、
      # 別のブランチのワークツリーを「作成済み」と誤判定する。
      if git worktree list --porcelain | command grep -Fxq -- "branch refs/heads/$1"; then
        gwq cd "$1"
      elif __cw_branches | command grep -Fxq -- "$1"; then
        gwq add "$1"
      else
        # ブランチも無いので新しく切る。gwq add -b はカレントの HEAD から切るので使わない。
        git check-ref-format --branch "$1" >/dev/null || return 1
        local base
        base="$(__cw_base)" || { print -u2 "cw: develop も main も見つかりません"; return 1; }
        # origin/... から切ると上流が origin/develop 等になり、誤って push しかねないので --no-track
        git branch --no-track -- "$1" "$base" || return 1
        print -u2 "cw: $1 を ''${base#refs/*/} から作成しました"
        gwq add "$1"
      fi
    }

    _cw() {
      (( CURRENT == 2 )) || return
      local -a branches
      branches=("''${(@f)$(__cw_branches)}")
      compadd -a branches
    }
    compdef _cw cw

    # ブランチ $1 のワークツリーのパスを出す。引数なしならメインのチェックアウト(先頭の worktree)。
    __dw_worktree_of() {
      git worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$1" -v want_main=$(( $# == 0 )) '
        /^worktree / { p = substr($0, 10); if (want_main) { print p; exit } }
        $0 == "branch " b { print p; exit }'
    }

    # dw [-f] [ブランチ名]: ワークツリーをブランチごと消す。ブランチ名を省くと今いるワークツリー。
    # 未コミットの変更も未マージのコミットも捨てる(worktree remove --force + branch -D)。
    # 命名ルール([種別]/...)のブランチは作業の本体なので、-f を付けたときだけ消す。
    dw() {
      local force=0
      [[ $1 == -f ]] && { force=1; shift; }
      if (( $# > 1 )) || [[ $1 == -* ]]; then
        print -u2 "usage: dw [-f] [branch]"
        return 2
      fi
      git rev-parse --git-dir >/dev/null 2>&1 || { print -u2 "dw: git リポジトリではありません"; return 1; }

      local branch="$1"
      if [[ -z $branch ]]; then
        branch="$(git symbolic-ref --quiet --short HEAD)" || { print -u2 "dw: detached HEAD なのでブランチ名を指定してください"; return 1; }
      fi
      git show-ref --verify --quiet "refs/heads/$branch" || { print -u2 "dw: ブランチ $branch がありません"; return 1; }

      if [[ $branch == (main|develop) ]]; then
        print -u2 "dw: $branch は消せません"
        return 1
      fi
      if [[ $branch =~ '^((spike|wip|archive)/)?(feature|bugfix|fix|chore|refactor|docs|test)/' ]] && (( ! force )); then
        print -u2 "dw: $branch は命名ルールに沿ったブランチです。消すなら dw -f $branch"
        return 1
      fi

      local main_wt wt
      main_wt="$(__dw_worktree_of)"
      wt="$(__dw_worktree_of "$branch")"
      if [[ -n $wt && $wt == $main_wt ]]; then
        print -u2 "dw: $branch はメインのチェックアウトで使われています"
        return 1
      fi

      # 消すワークツリーの中にいたら、先にメインのチェックアウトへ出る
      if [[ -n $wt && ''${PWD:A}/ == ''${wt:A}/* ]]; then
        builtin cd -- "$main_wt" || return 1
      fi

      # gwq rm -b は使わない。ワークツリー内で実行するとブランチ削除だけ失敗し、しかも終了コードが 0 になる。
      # パターンも部分一致なので、名前の似た別のワークツリーを消しかねない。
      if [[ -n $wt ]]; then
        git -C "$main_wt" worktree remove --force "$wt" || return 1
      fi
      git -C "$main_wt" branch -D -- "$branch" || return 1
      print -u2 "dw: $branch''${wt:+ と $wt} を削除しました"
    }

    _dw() {
      local main_wt
      main_wt="$(__dw_worktree_of)"
      local -a branches
      branches=("''${(@f)$(git worktree list --porcelain 2>/dev/null | awk -v m="$main_wt" '
        /^worktree / { p = substr($0, 10) }
        /^branch refs\/heads\// && p != m { print substr($0, 19) }')}")
      _arguments '-f[命名ルールのブランチも消す]' "1:branch:(''${branches[*]})"
    }
    compdef _dw dw
  '';
}
