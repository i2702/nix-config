{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "idetachment2702";
    userEmail = "idetachment2702@gmail.com";

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
    # リスト形式はセクションの繰り返し・順序を保つため(extraConfigを単一attrsetにすると
    # 同一キーが1つに潰れてしまう)。
    extraConfig = [
      {
        core = {
          editor = "vim";
          quotepath = false;
        };
        init.defaultBranch = "main";
        # ローカル固有設定の読み込み(このマシン専用: ~/.config/git/config.local)
        include.path = "~/.config/git/config.local";
      }
      { credential."https://github.com".helper = ""; }
      { credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential"; }
      { credential."https://gist.github.com".helper = ""; }
      { credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential"; }
    ];
  };
}
