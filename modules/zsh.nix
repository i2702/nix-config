{ pkgs, lib, ... }:
let
  # WSL から Windows ネイティブの Zed を CLI 起動するためのコマンド。
  # bin/Zed.exe が CLI 本体で、--wsl <user@distro> を付けると WSL 内のパスを
  # Windows 側の Zed から開ける(GUI の wsl_connections と同じ仕組み)。
  # 注意: パスは絶対パスで渡すこと。Windows 側は WSL のカレントを知らないため、
  # 引数なし(カレント)や相対パスは解決できない。
  zedWinCli = "/mnt/c/Users/m1205/AppData/Local/Programs/Zed/bin/Zed.exe --wsl m1205062@Ubuntu";

  # 設定反映コマンド。カレントに依らず動くよう flake のパスを固定する。
  # -b backup は必須。管理対象パスに実体ファイルが居座っていると activation の
  # linkGeneration が中断し、ビルドは成功しているのに ~/.zshrc 等が古い世代を
  # 指したまま放置される(症状: 追加したはずの alias が効かない)。
  # -b があれば衝突ファイルを .backup へ退避して最後まで通る。
  hmSwitch =
    let
      target = if pkgs.stdenv.isDarwin then "mac" else "linux";
    in
    "home-manager switch -b backup --flake ~/nix-config#${target}";

  # $BROWSER の実体。WSL から Windows の既定ブラウザで URL を開く。
  wslOpenUrl = pkgs.writeShellApplication {
    name = "wsl-open-url";
    text = ''
      url="''${1:?URL を指定してください}"

      # url.dll,FileProtocolHandler は URL を既定ハンドラ(= 既定ブラウザ)へ
      # 渡すための Windows の口。rundll32 はコマンドラインを cmd に通さず、
      # カンマ以降をそのまま 1 引数として扱うので、URL 中の & や % が
      # 壊れない(cmd.exe /c start だと & を ^& に自前で逃がす必要がある)。
      #
      # explorer.exe "$url" は使わない。URL を URL として解釈せず、既定の
      # フォルダ(ドキュメント)をエクスプローラーで開いてしまう。
      /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$url"
    '';
  };

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

    # WSL の systemd=true では appendWindowsPath で足されるはずの Windows 側
    # ディレクトリがユーザーセッションに渡らない。explorer.exe / clip.exe /
    # shutdown.exe / powershell.exe が名前で引けなくなるため自前で足す。
    # 末尾に置いて Linux 側のコマンドを優先させる(find や sort が .exe に
    # 取られると壊れるため)。
    export PATH="$PATH:/mnt/c/Windows/System32:/mnt/c/Windows:/mnt/c/Windows/System32/WindowsPowerShell/v1.0"

    # WSL_INTEROP を生きているソケットに繋ぎ直す(上の PATH 問題と根本原因は同じ)。
    #
    # systemd=true ではユーザーのシェルが login 経由で起動し wsl.exe の子孫に
    # ならないため、WSL_INTEROP が渡ってこない。この変数が無いと /init は
    # ディストロ初回起動時の interop(/run/WSL/1_interop)にフォールバックし、
    # そこから起動した Windows プロセスは Session 0(サービス用の非対話セッション)
    # で動く。Session 0 にはデスクトップが無く、実ディスプレイも見えない
    # (1024x768 の "WinDisc" 擬似ディスプレイのみ)。
    # 症状: ControlMyMonitor がモニタを1台も列挙できず、disp-win / disp-mac が
    # エラーも出さずに何もしなくなる(modules/controlmymonitor.nix)。
    #
    # wsl.exe から開かれたセッションのソケット(<pid>_interop)は Session 1 に
    # 属するので、そちらを拾う。
    #
    # 候補を1つに決め打たず列挙で返すのは、ここでは「使えるソケット」を確定
    # できないため。ソケットはファイルとして存在し zsocket の connect も通るのに、
    # それ経由の Windows プロセス起動だけが "Invalid argument" (exit 1) で落ちる
    # ことがある(Session 0 の 2_interop が実際にそう)。-S でも connect でも
    # 見分けられないので、実際に exe を起動して確かめ、駄目なら次の候補へ進む
    # 責務は呼び出し側に持たせる(modules/controlmymonitor.nix の cmm-ensure)。
    wsl-interop-list() {
      # 1_interop は初回起動時のもの = Session 0。実体(2_interop 等)ごと除外する。
      local fallback="$(readlink -f /run/WSL/1_interop 2>/dev/null)"
      local sock pid
      # (=Nom): ソケットのみ / 無ければ空 / 新しい順。symlink は lstat で弾かれる。
      for sock in /run/WSL/*_interop(=Nom); do
        [[ -n "$fallback" && "$sock" == "$fallback" ]] && continue
        # 名前の pid が生きているものだけが有効。閉じた端末の残骸を掴まない。
        pid="''${sock:t}"
        [[ -d "/proc/''${pid%%_*}" ]] || continue
        print -r -- "$sock"
      done
    }

    # 起動時の初期値を入れるだけの軽い版。ソケットは接続元の端末を閉じると
    # 消えるので、長く開いたシェルではここで入れた値がいずれ無効になる。
    wsl-interop-refresh() {
      [[ -S "$WSL_INTEROP" ]] && return 0
      local sock
      sock=$(wsl-interop-list | head -1)
      [[ -n "$sock" ]] || return 1
      export WSL_INTEROP="$sock"
    }
    wsl-interop-refresh

    # ブラウザ起動は Windows 側に投げる。
    #
    # webbrowser crate や xdg-open は「$BROWSER → xdg の既定ブラウザ設定 →
    # デスクトップ環境別(WSL なら cmd.exe /c start)」の順に試す。ところが
    # WSL 内に Linux 版 Chrome が入っていると 2 段目で拾われてしまう
    # (xdg-settings get default-web-browser → com.google.Chrome.desktop)。
    # SSH ログイン(= WezTerm の既定ドメイン)には WSLg の $DISPLAY が渡らない
    # ので、その Chrome は "Missing X server or $DISPLAY" で即死する。
    # 呼び出し側は spawn が通った時点で成功と見なすため、エラーも出ずに
    # ブラウザだけ開かないという症状になる(aoao の o キー)。
    # 最優先で見られる $BROWSER を埋めて、xdg 段階に落ちる前に決着させる。
    export BROWSER="wsl-open-url %s"

    # Workaround to prevent Claude Code from repeatedly spawning powershell.exe.
    # ref: https://github.com/anthropics/claude-code/issues/14352
    export CLAUDE_CODE_SKIP_WINDOWS_PROFILE=1
    export USERPROFILE="/mnt/c/Users/m1205"

    # Nodeに証明書を追加
    export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
  '';
in
{
  home.packages = lib.optionals pkgs.stdenv.isLinux [
    pkgs.nkf
    wslOpenUrl
  ];

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
      # noglob: rg 'foo.*bar' のようにクォート無しで正規表現を渡せるようにする
      # 色やページャの制御は rg-page / rgf-page 側で持つ
      rg = ''noglob rg-page'';
      rgf = ''noglob rgf-page'';
      cw = "gwq cd";
      hms = hmSwitch;
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
      e = "explorer.exe";
      # WSL から Windows 本体を落とす/再起動する。.exe を付けないと Linux 側の
      # /sbin/shutdown が当たるため必ず付ける。/t 60 は取り消し猶予で、
      # 誤って叩いても winabort で止められる。WSL のディストリも一緒に終了する。
      winoff = "shutdown.exe /s /t 60";
      winreboot = "shutdown.exe /r /t 60";
      winabort = "shutdown.exe /a";
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

      # 端末に出すときだけページャを挟む。bat --paging=auto は less に
      # --quit-if-one-screen を渡すので、1画面に収まる分はそのまま画面に残り、
      # 溢れたときだけ less が開く。パイプ・リダイレクト時は素通しする。
      #
      # --style=plain で bat の枠と行番号を落とす。rg 側が既に行番号やパスを
      # 出しており、bat の装飾が二重に付くと読みにくいため。
      page-if-long() {
        if [[ -t 1 ]]; then
          bat --language=help --paging=auto --style=plain
        else
          cat
        fi
      }

      # rg: ファイルの中身を検索する (rg エイリアスの実体)。
      # --pretty は色・見出し・行番号を固定する。パイプ先へ色を残すため、
      # 出力先が端末でなくても外さない (rg foo | le で色が消えないようにする)。
      #
      # command を付けないと、関数定義がパースされる時点で alias rg が展開されて
      # 自分自身を呼ぶ形になる。
      rg-page() {
        command rg --pretty "$@" | page-if-long
        # ページャ側ではなく rg の終了ステータスを返す (ヒット0 = 1)
        return $pipestatus[1]
      }

      # rgf: ファイル名(リポジトリ相対パス)を検索する (rgf エイリアスの実体)。
      # rg --files が出すパス一覧をもう一段 rg に通すだけなので、パターンは rg と
      # 同じ正規表現で書ける。旧実装の `--iglob` と違い `rgf '*.nix'` のように
      # 前後へ `*` を付ける必要がなく、`rgf nix` で中間一致する。-i や -v などの
      # オプションもそのまま効く。
      #
      # --smart-case は旧実装の --iglob (大文字小文字を無視するグロブ) の
      # 使い勝手に合わせたもの。小文字だけのパターンなら大小を区別しない。
      #
      # パスで絞りたい場合は引数ではなくパターンに書く (rgf 'modules/.*nix')。
      # 2つめの引数はパス指定として後段の rg に渡ってしまい、ファイル名検索では
      # なく中身の検索になる。
      rgf-page() {
        command rg --files \
          | command rg --color=always --no-heading --no-line-number --smart-case "$@" \
          | page-if-long
        return $pipestatus[2]
      }

      # ghq 管理下のリポジトリを fzf で選んで移動する。
      # alias の `cd $(ghq list -p | fzf)` にしないのは、fzf をキャンセルすると
      # コマンド置換が空になり、引数なしの cd = ホーム移動になってしまうため。
      # 引数は fzf の初期クエリになる (cg sptv → sptv で絞り込んだ状態で開く)。
      # --select-1: 候補が1つに絞れたら fzf を開かず即移動する (gwq cd と同じ挙動)。
      # --exit-0 は付けない。無言で終わるより、0件のまま fzf が開いて
      # クエリを打ち直せるほうが分かりやすいため。
      cg() {
        local dir
        dir="$(ghq list -p | fzf --query="$*" --select-1)" || return
        [[ -n "$dir" ]] && cd "$dir"
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

      # nixのパスも無条件でprependする。/etc/zshrc等の標準フックに任せないのは、
      # ガード変数(__ETC_PROFILE_NIX_SOURCED)が環境系譜で一度しか効かず、
      # herdr/tmux配下のネストしたログインシェルではpath_helperの並べ替えで
      # /usr/binが先頭に戻り、Apple git等がnix供給版より優先されてしまうため。
      export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
      typeset -U path PATH

      # bun completions
      [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

      # bun
      export BUN_INSTALL="$HOME/.bun"
      export PATH="$BUN_INSTALL/bin:$PATH"

      # cargo install したバイナリ (zellij 等)。ツールチェーン本体は nix が
      # 供給する (modules/rust.nix)。先頭に足さないのは、WSL に rustup の
      # shim (~/.cargo/bin/cargo 等) が残っており、prepend すると nix 供給版
      # より優先されてしまうため。末尾なら cargo install 分だけが有効になる。
      export PATH="$PATH:$HOME/.cargo/bin"

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
