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
    # サブシェル起動(true)にしないのは、herdr がペイン cwd を
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
  # `gwq cd`(alias cw も同じ)が現在のシェルで builtin cd するようになる。
  # compdef を使うため oh-my-zsh の compinit 後(mkOrder 1200 の後)に読み込む。
  programs.zsh.initContent = lib.mkOrder 1300 ''
    command -v gwq >/dev/null && source <(gwq completion zsh)
  '';
}
