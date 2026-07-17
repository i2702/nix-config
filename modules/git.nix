{ pkgs, lib, config, ... }:
{
  # このマシン専用の git identity(name/email)は ~/.config/git/config.local に置く。
  # 公開リポジトリに業務メール等を載せないため、managed 側では user を設定せず、
  # programs.git.settings の include.path 経由で config.local から取り込む。
  # (managed で user を設定すると、生成configのセクション順で include より後ろに
  #  並び config.local を上書きしてしまうため、あえて managed からは外している。)
  # config.local が無いまま activation すると誤った identity でコミットしかねないので、
  # 存在チェックし、無ければテンプレートの場所を案内して失敗させる。
  home.activation.requireGitConfigLocal =
    lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      cfgLocal="${config.home.homeDirectory}/.config/git/config.local"
      if [ ! -f "$cfgLocal" ]; then
        echo "" >&2
        echo "ERROR: $cfgLocal が見つかりません(このマシン専用の git identity / リポジトリ管理外)。" >&2
        echo "テンプレートをコピーし、name / email を自分の値に書き換えてください:" >&2
        echo "  cp <このリポジトリ>/templates/git-config.local.example \"$cfgLocal\"" >&2
        echo "" >&2
        exit 1
      fi
    '';

  # diff の配色は delta デフォルト(行背景がほぼ黒で判別できず、単語強調は高彩度で
  # 文字が潰れる)を使わず、公式 catppuccin/delta の catppuccin-mocha の値を固定する。
  # https://github.com/catppuccin/delta の gitconfig を include+features で読む方式に
  # しないのは、設定の実体をこのファイル一箇所に集めるため。
  # 値中の #RRGGBB は home-manager が値全体を引用符で囲むため gitconfig のコメント扱いにならない。
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      dark = true;
      # bat.nix で供給している Catppuccin Mocha テーマ(delta は bat のテーマを参照する)
      syntax-theme = "Catppuccin Mocha";
      blame-palette = "#1e1e2e #181825 #11111b #313244 #45475a";
      commit-decoration-style = "#6c7086 bold box ul";
      file-decoration-style = "#6c7086";
      file-style = "#cdd6f4";
      hunk-header-decoration-style = "#6c7086 box ul";
      hunk-header-file-style = "bold";
      hunk-header-line-number-style = "bold #a6adc8";
      hunk-header-style = "file line-number syntax";
      line-numbers-left-style = "#6c7086";
      line-numbers-minus-style = "bold #f38ba8";
      line-numbers-plus-style = "bold #a6e3a1";
      line-numbers-right-style = "#6c7086";
      line-numbers-zero-style = "#6c7086";
      map-styles = "bold purple => syntax #5b4e74, bold blue => syntax #445375, bold cyan => syntax #446170, bold yellow => syntax #6b635b";
      # 行背景はベース色(#1e1e2e)に赤/緑を20%混ぜた色、単語強調は35%+bold
      minus-style = "syntax #493447";
      minus-emph-style = "bold syntax #694559";
      plus-style = "syntax #394545";
      plus-emph-style = "bold syntax #4e6356";
    };
  };

  programs.git = {
    enable = true;

    # git 2.55.0 は nixpkgs 未収録(master も 2.54.0)のため src を差し替えて先行導入する。
    # nixpkgs が 2.55.0 に追従したらこの package 上書きごと削除する。
    # overlay で pkgs.git 全体を上書きしない理由: gitMinimal 経由で fetch 系ツールチェーン
    # (Python/cargo-vendor 等)が芋づる式にソースビルドになるため、ユーザー向け git に限定する。
    package = pkgs.git.overrideAttrs (old: rec {
      version = "2.55.0";
      src = pkgs.fetchurl {
        url = "https://www.kernel.org/pub/software/scm/git/git-${version}.tar.xz";
        hash = "sha256-RX/bBNyHKOAH1GiGleaRLm9oByeSDypAvxHqzBdQU1c=";
      };
      # 2.54.0 向けの nixpkgs パッチのうち 2.55.0 で不要になったものを除外する:
      # - t1517: 上流でテストが書き換わり当たらない(テスト専用なので除外で問題ない)
      # - osxkeychain: 上流が GITLIBS += $(RUST_LIB) で同等の修正を取り込み済み
      patches = builtins.filter
        (p: !(lib.any (s: lib.hasSuffix s (baseNameOf p)) [
          "expect-gui--askyesno-failure-in-t1517.patch"
          "osxkeychain-link-rust_lib.patch"
        ]))
        (old.patches or [ ]);
    });

    # name/email はこのマシン専用の ~/.config/git/config.local(リポジトリ管理外)で設定し、
    # 下部 settings の include.path 経由で読み込む(上の説明・存在チェック参照)。

    ignores = [
      "*.swp"
      "*.swo"
      "*~"
      ".*.sw?"
      ".*.md"
      ".config/"
      ".cache/"
      ".local/"
      "*.tmp"
      "*.bak"
      "*.log"
      ".DS_Store"
      "Thumbs.db"
      ".idea/"
      "*.iml"
      "node_modules/"
      "__pycache__/"
      "*.pyc"
      "*.pyo"
      ".pytest_cache/"
      "dist/"
      "build/"
      "*.o"
      "*.so"
      "*.dylib"
      "**/.claude/settings.local.json"
      "scheduled_tasks.lock"
      ".serena"
    ];

    settings = {
      alias = {
        s = "status";
        st = "status";
        co = "switch";
        b = "branch";
        a = "add";
        c = "commit";
        cm = "commit -m";
        ca = "commit --amend";
        r = "rebase";
        cp = "cherry-pick";
        d = "diff";
        dc = "diff --cached";
        l = "log --oneline";
        lg = "log --oneline --graph --decorate --all";
        last = "log -1 HEAD";
        unstage = "reset HEAD --";
        aliases = "config --get-regexp alias";
        f = "fetch";
        ps = "push";
        pl = "pull";
        w = "worktree";
      };

      core = {
        editor = "vim";
        quotepath = false;
      };
      init.defaultBranch = "main";
      # ローカル固有設定の読み込み(このマシン専用: ~/.config/git/config.local)
      include.path = "~/.config/git/config.local";

      # helperを空文字→実値の順で並べ、継承されたグローバルヘルパーをクリアしてから
      # gh経由のヘルパーを設定する(元のgitconfigと同じパターン)。
      # 同一キーにリスト値を与えると同じキーの繰り返し行として展開される。
      credential."https://github.com".helper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
      credential."https://gist.github.com".helper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
    };
  };
}
