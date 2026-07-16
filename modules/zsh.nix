{ pkgs, lib, ... }:
let
  # WSL から Windows ネイティブの Zed を CLI 起動するためのコマンド。
  # bin/Zed.exe が CLI 本体で、--wsl <user@distro> を付けると WSL 内のパスを
  # Windows 側の Zed から開ける(GUI の wsl_connections と同じ仕組み)。
  # 注意: パスは絶対パスで渡すこと。Windows 側は WSL のカレントを知らないため、
  # 引数なし(カレント)や相対パスは解決できない。
  zedWinCli = "/mnt/c/Users/m1205/AppData/Local/Programs/Zed/bin/Zed.exe --wsl m1205062@Ubuntu";

  # WSL(Windows側との連携)に依存する部分。Macでは無効化する。
  wslOnly = lib.optionalString pkgs.stdenv.isLinux ''
    # WSL clipboard (UTF-8 → Shift-JIS変換)
    clip() {
        nkf -s | clip.exe
    }

    # 🔍 Mermaidプレビュー: mmp foo.mermaid
    mmp() {
      local input="''${1:?ファイルを指定してください}"
      local out="''${input%.*}.png"
      mmdc -i "$input" -o "$out" -b transparent -w 1400 && explorer.exe "$(wslpath -w "$out")"
    }

    export PATH="/snap/bin:$PATH"

    # Workaround to prevent Claude Code from repeatedly spawning powershell.exe.
    # ref: https://github.com/anthropics/claude-code/issues/14352
    export CLAUDE_CODE_SKIP_WINDOWS_PROFILE=1
    export USERPROFILE="/mnt/c/Users/m1205"

    # Nodeに証明書を追加
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
  '';
in
{
  home.packages = lib.optionals pkgs.stdenv.isLinux [ pkgs.nkf ];

  programs.zsh = {
    enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "half-life";
      plugins = [ "git" ];
    };

    autosuggestion.enable = true;

    shellAliases = {
      t = "tmux";
      h = "herdr";
      p = "pnpm";
      c = "claude";
      lg = "lazygit";
      v = "nvim";
      nv = "nvim";
      vim = "nvim";
      le = "less";
      gr = ''grep -rniE --color=auto --exclude-dir={node_modules,dist,build,.git} -C 2'';
      cg = "cd $(ghq list -p | fzf)";
      cw = "gwq cd";
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      e = "explorer.exe";
      # WSL: Windows ネイティブの Zed で開く(za は既存ウィンドウに追加)
      z = zedWinCli;
      za = "${zedWinCli} -a";
    } // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # macOSでは zed CLI がPATHにないため、Zed.app 同梱のCLIを直接使う
      # -n で常に新しいウィンドウで開く(既存ウィンドウに追加したいときは za を使う)
      z = "/Applications/Zed.app/Contents/MacOS/cli -n";
      za = "/Applications/Zed.app/Contents/MacOS/cli -a";
    };

    initContent = lib.mkOrder 1200 ''
      # tmux内でのターミナルクエリ抑制(デバイス属性の表示を防ぐ)
      if [[ -n "$TMUX" ]]; then
          unset TMUX_PANE_INIT
      fi

      # 🎨 half-lifeテーマのプロンプトをカスタマイズ
      # フォーマット: カレントディレクトリ [ブランチ名] ステータス記号 λ
      if [[ "$ZSH_THEME" == "half-life-custom" ]] || [[ "$ZSH_THEME" == "half-life" ]]; then
        FMT_BRANCH=" ''${turquoise}[%b]%u%c''${PR_RST}"
        zstyle ':vcs_info:*:prompt:*' formats "''${FMT_BRANCH}"

        function steeef_precmd {
          (( PR_GIT_UPDATE )) || return
          if [[ -n "$(git ls-files --other --exclude-standard 2>/dev/null)" ]]; then
            PR_GIT_UPDATE=1
            FMT_BRANCH="''${PR_RST} ''${turquoise}[%b]%u%c''${hotpink} ●''${PR_RST}"
          else
            FMT_BRANCH="''${PR_RST} ''${turquoise}[%b]%u%c''${PR_RST}"
          fi
          zstyle ':vcs_info:*:prompt:*' formats "''${FMT_BRANCH}"
          vcs_info 'prompt'
          PR_GIT_UPDATE=
        }

        PROMPT="''${limegreen}%~%{$reset_color%}\$vcs_info_msg_0_''${orange} λ%{$reset_color%} "
      fi

      # Preferred editor
      export EDITOR='nvim'
      export VISUAL='nvim'

      unalias less 2>/dev/null
      less() {
        if [[ $# -eq 0 ]]; then
          bat --language=help --paging=always
        else
          bat "$@"
        fi
      }

      # 空Enterでls実行
      my-accept-line() {
        if [[ -z "$BUFFER" ]]; then
          BUFFER="ls"
        fi
        zle .accept-line
      }
      zle -N accept-line my-accept-line

      ${wslOnly}

      export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

      # bun completions
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      # bun
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"

      # vp node
      [ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"

      # 新規ターミナル(ホーム直起動)時の初期作業ディレクトリを ~/Repository に変更
      # マルチプレクサ自動起動より前に実行し、herdr/tmux セッションの初期ディレクトリにも反映させる。
      # $PWD == $HOME に限定することで、プロジェクト内で開いた新規ペインが飛ばされるのを防ぐ。
      if [[ "$PWD" == "$HOME" && -d "$HOME/Repository" ]]; then
        cd "$HOME/Repository"
      fi

      # ==========================================
      # ターミナルマルチプレクサの自動起動(herdr / tmux の振り分け)
      #   - Zed のターミナル($ZED_TERM が設定される)     → tmux
      #   - それ以外(Ghostty など通常ターミナル)          → herdr
      #
      # 【同時起動の防止】既に herdr($HERDR_PANE_ID)または tmux($TMUX)の
      #   セッション内にいる場合は何もしない。これで
      #     - herdr ペイン内で再帰的に herdr が起動する
      #     - tmux 内で再帰的に tmux が起動する
      #     - herdr と tmux が入れ子・二重に起動する
      #   のいずれも防ぐ($HERDR_PANE_ID / $TMUX はどちらも子シェルへ継承される)。
      #
      # 【対話シェル限定】-o interactive のときだけ起動する。Zed エージェントパネルが
      #   実行するコマンドは非対話シェル(.zshrc を読み込まない)なので、そもそもここへ
      #   到達しないが、明示条件を付けて安全側に倒す。エージェントパネルの「ターミナル
      #   スレッド」のような対話ターミナルでは $ZED_TERM が立つため tmux が起動する。
      #   (補足: Zed には通常ターミナルとエージェント用ターミナルを区別する環境変数が
      #    無いため、Zed のターミナルは一律 tmux とする。)
      # ==========================================
      if [[ -o interactive && -z "$TMUX" && -z "$HERDR_PANE_ID" ]]; then
        if [[ -n "$ZED_TERM" ]]; then
          command -v tmux &> /dev/null && tmux
        else
          command -v herdr &> /dev/null && herdr
        fi
      fi

      # マージ済みローカルブランチを削除
      git-prune-localbranch() {
        local target="''${1:?⚠️ 比較対象ブランチ名を指定してください}"
        if ! git rev-parse --verify "$target" &>/dev/null; then
          echo "⚠️ ブランチ '$target' は存在しません" >&2
          return 1
        fi
        git branch --merged "$target" | grep -v -E "^\*|^\s*(''${target}|master|develop)\$" | xargs -r git branch -d
      }

      # ローカル固有設定の読み込み(このマシン専用: ~/.zshrc.local)
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
    '';
  };
}
