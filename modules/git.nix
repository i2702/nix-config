{ pkgs, lib, config, ... }:
{
  # このマシン専用の git identity(name/email)は ~/.config/git/config.local に置く。
  # 公開リポジトリに業務メール等を載せないため、managed 側では user を設定せず、
  # programs.git 下部の extraConfig.include.path 経由で config.local から取り込む。
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

  programs.git = {
    enable = true;
    # name/email はこのマシン専用の ~/.config/git/config.local(リポジトリ管理外)で設定し、
    # 下部 extraConfig の include.path 経由で読み込む(上の説明・存在チェック参照)。

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Monokai Extended Bright";
      };
    };

    aliases = {
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

    # helperを空文字→実値の順で並べ、継承されたグローバルヘルパーをクリアしてから
    # gh経由のヘルパーを設定する(元のgitconfigと同じパターン)。
    # 同一キーにリスト値を与えると同じキーの繰り返し行として展開されるため、
    # 空文字→実値の順序が保持される(生成される.gitconfigはリスト形式時と同一)。
    # 注: 新しいhome-managerではextraConfigはprograms.git.settings(単一attrset)へ
    # 統合されたため、list形式のextraConfigはaliases/user等のattrset定義と
    # マージできず型エラーになる。そのためattrset形式で記述する。
    extraConfig = {
      core = {
        editor = "vim";
        quotepath = false;
      };
      init.defaultBranch = "main";
      # ローカル固有設定の読み込み(このマシン専用: ~/.config/git/config.local)
      include.path = "~/.config/git/config.local";

      credential."https://github.com".helper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
      credential."https://gist.github.com".helper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
    };
  };
}
