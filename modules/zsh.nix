{ pkgs, lib, ... }:
let
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
      p = "pnpm";
      c = "claude";
      lg = "lazygit";
      v = "nvim";
      nv = "nvim";
      vim = "nvim";
      le = "less";
      z = "zed";
      za = "zed -a";
      gr = ''grep -rniE --color=auto --exclude-dir={node_modules,dist,build,.git} -C 2'';
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      e = "explorer.exe";
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

      export BAT_PAGER='less -RFM'

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

      # 777ディレクトリ(other-writable=ow / sticky+other-writable=tw)の緑背景を消し、
      # 通常ディレクトリと同じ青文字にする。
      # 末尾追記だと(1)tmux等のネストで増殖し(2)zsh補完は重複時に最初の定義を優先するため効かない。
      # 既存の ow=/tw= を除去して1つだけ設定し、補完(list-colors)にも再適用する。
      typeset -a _ls_entries
      _ls_entries=("''${(@s.:.)LS_COLORS}")
      _ls_entries=("''${(@)_ls_entries:#(ow|tw)=*}")
      _ls_entries+=("ow=01;34" "tw=01;34")
      export LS_COLORS="''${(j.:.)_ls_entries}"
      unset _ls_entries
      zstyle ':completion:*' list-colors "''${(@s.:.)LS_COLORS}"

      # tmux自動起動
      if command -v tmux &> /dev/null && [ -z "$TMUX" ]; then
        tmux
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
