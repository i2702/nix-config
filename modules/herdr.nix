{ pkgs, lib, ... }:
{
  # herdr: AIエージェント時代のターミナルマルチプレクサ (https://herdr.dev)
  # パッケージは flake.nix の input (github:herdrdev/herdr) の overlay から供給。
  #
  # COPY MODE の ctrl-e / ctrl-y (vim 風の1行表示スクロール)は src パッチで追加している。
  # COPY MODE 内のキーは上流でハードコードされていて config.toml では変更できないため
  # (config で変えられるのは COPY MODE 開始キーのみ)。上流に入ったらパッチごと削除する。
  # overlay 全体ではなくここで overrideAttrs する理由: パッチは利用パッケージ限定の
  # 先行導入で、git.nix の src 差し替えと同じ「モジュール内で完結させる」方針に合わせる。
  home.packages = [
    (pkgs.herdr.overrideAttrs (old: {
      # 素のパス参照にしない理由: flake 評価ではパスが flake ソース全体の store パス配下を
      # 指すため、リポジトリ内のどのファイルを変更しても herdr の再ビルドが走ってしまう。
      # builtins.path で単一ファイルとして取り込み、パッチ内容だけを drv の入力にする。
      patches = (old.patches or [ ]) ++ [
        (builtins.path { path = ./patches/herdr-copy-mode-ctrl-e-y.patch; })
      ];
    }))
  ];

  xdg.configFile."herdr/config.toml".text = ''
    # herdr 設定 (https://herdr.dev/docs/configuration/)
    #
    # 初回セットアップ画面をスキップする。このファイルは nix 管理の読み取り専用シンボリックリンク
    # なので、herdr 自身に config.toml を書き込ませない(設定変更はこのモジュールを編集して
    # home-manager switch で反映し、`herdr server reload-config` で再読み込みする)。
    onboarding = false

    [update]
    # 本体の更新は nix (flake input) で管理するため、バックグラウンドの更新チェックは無効化
    version_check = false

    [keys]
    # プレフィックスキーは Ctrl-b ではなく Alt-t
    prefix = "alt+t"

    # Alt-r で設定リロード
    reload_config = "alt+r"

    # Alt-d でデタッチ
    detach = "alt+d"

    # Alt-h/j/k/l でペイン移動(プレフィックス不要)
    focus_pane_left = "alt+h"
    focus_pane_down = "alt+j"
    focus_pane_up = "alt+k"
    focus_pane_right = "alt+l"

    # 方向指定の分割(herdr 標準動作: フォーカス中ペインを割る)。
    #   Alt-v = 右に分割(縦線。vim の :vsplit と同じ向き) / Alt-s = 下に分割(横線)
    # 方向を自動判定してグリッドを保つ「自動タイル分割」は Alt-f(下の [[keys.command]])。
    # 以前は Alt-v / Alt-s の両方を自動タイルに充てて方向指定を prefix 側(Alt-t → v/s)に
    # 追いやっていたが、2キーが同じ動作で冗長なうえ v/s が方向を連想させるのに区別されず、
    # 「ここを右に割りたい」ときに2打必要だったので入れ替えた。prefix 側は標準のまま残す。
    split_vertical = ["prefix+v", "alt+v"]
    split_horizontal = ["prefix+s", "alt+s"]

    # Alt-q でペインを閉じる
    close_pane = "alt+q"

    # Alt-c でコピーモード開始。
    # モード内キーは設定不可(ハードコード)。ctrl-e / ctrl-y の1行表示スクロールは
    # src パッチ(patches/herdr-copy-mode-ctrl-e-y.patch)で追加している。
    copy_mode = "alt+c"

    # Alt-m で space 名変更。サイドバー見出しになる space 名は変更頻度が高い。
    # (rename_workspace は herdr デフォルトだと prefix+shift+w に埋もれている。)
    rename_workspace = "alt+m"

    # space(ワークスペース)の操作
    # プロジェクト単位のまとまり。タブはほぼ使わないため、元々タブ操作に充てていた
    # Alt キー一式(alt+n/o/p, alt+left/right, alt+w, alt+1..9)を space 操作へ振り替えた。
    # タブ操作自体は設定行の削除で herdr デフォルト(prefix+n / prefix+p / prefix+1..9 等の
    # prefix 系)に戻るため、必要なら prefix 経由で今も使える。
    # Mac/WSL とも Alt 系に統一する(以前 Mac 用に併記していた cmd+t / cmd+] / cmd+[ は廃止)。
    # 補足: ctrl+tab / ctrl+alt+n 系はこの端末環境では herdr まで届かず不達だった
    # (Tab 系は kitty keyboard protocol の「全キー報告」フラグが必要)。素の Alt 系が確実。
    new_workspace = "alt+n"
    next_workspace = ["alt+p", "alt+right"]
    previous_workspace = ["alt+o", "alt+left"]

    # Alt-w で space を閉じる(confirm_close がデフォルト有効のため確認モーダルが出る)
    close_workspace = "alt+w"

    # Alt-1〜9 で space 直接選択
    switch_workspace = "alt+1..9"

    # タブ機能は実質無効化する。空文字は「ユーザー設定済み・バインドなし」の扱いになり、
    # prefix 系デフォルトごと消えてタブを作る手段が無くなる(各 space は常に1タブのまま)。
    # 他のタブ操作キー(next_tab 等)はタブが増えない限り無害なのでデフォルトのまま放置。
    new_tab = ""

    # 自動タイル分割: Alt-f でフォーカス中タブに新ペインを追加して均等グリッドを保つ。
    # type = "shell" はバックグラウンド実行で、スクリプトが herdr CLI 経由で
    # 「一番大きいペインを長辺方向に分割」する。これによりペイン4つで必ず 2x2 になる。
    # 方向を明示したいときは Alt-v / Alt-s(keys の split_vertical / split_horizontal)。
    [[keys.command]]
    key = "alt+f"
    type = "shell"
    command = "~/.config/herdr/scripts/autotile-split.sh"
    description = "自動タイル分割(グリッドに追加)"

    # エージェント/ターミナルのペイン間フォーカス移動。
    # herdr の native な focus_agent はインデックス型(prefix+alt+1..9)しかなく、
    # 「ターミナルへフォーカス」に相当する native アクションは存在しない
    # (ターミナルは通常ペイン扱いで focus_pane_* / 方向指定でしか辿れない)。
    # そのため既存の自動タイル分割と同様、herdr CLI を使うカスタムコマンドで実装する。
    #   Alt-a = エージェント(claude 等)ペインへ。タブも space も飛び越えて全エージェントを巡回する
    #           (socket API の pane.focus は space をまたいでフォーカスできることを確認済み)。
    #   Alt-e = 非エージェント(シェル)ペインへ。こちらは従来どおり現在タブ内で巡回する
    #           (シェルはプロジェクト内の行き来がほとんどのため。global を渡せば横断になる)。
    # 同じ role のペインが複数あれば、押すたびに次のペインへ巡回する。
    [[keys.command]]
    key = "alt+a"
    type = "shell"
    command = "~/.config/herdr/scripts/focus-role.sh agent global"
    description = "エージェントペインへフォーカス(全 space 横断で巡回)"

    # Alt-Shift-a は同じリングを逆順に巡回する(行き過ぎたとき一つ戻る用)
    [[keys.command]]
    key = "alt+shift+a"
    type = "shell"
    command = "~/.config/herdr/scripts/focus-role.sh agent global prev"
    description = "エージェントペインへフォーカス(全 space 横断で逆順巡回)"

    [[keys.command]]
    key = "alt+e"
    type = "shell"
    command = "~/.config/herdr/scripts/focus-role.sh terminal"
    description = "ターミナル(非エージェント)ペインへフォーカス(タブ内で巡回)"

    # Alt-; でスクラッチシェルをポップアップで開く。
    # type = "popup" はセッションモーダルの一時ターミナルで、タブのレイアウトを一切変えずに
    # 開いてコマンド終了で消える。「ちょっと1コマンド叩きたい」ためにペインを割って閉じる
    # (Alt-f → Alt-q)手間を無くすのが目的。
    # キーが Alt-a でない理由: Alt-a は上のエージェントペインフォーカスで埋まっており、
    # そちらは使用頻度が高く動かしたくない。Alt-; は herdr デフォルトとも既存設定とも衝突しない。
    # なお句読点+修飾キーの到達性は端末依存(default-config にも注記あり)。届かない端末に
    # 当たったら alt+shift+semicolon 等ではなく別の英字キーへ振り替える。
    # popup で claude を起動しない理由: popup には HERDR_PANE_ID が渡らない(背後のペインの
    # HERDR_ACTIVE_PANE_ID のみ)ため、下の zsh ラッパーによるサイドバー名/ペインラベルの
    # cwd 追従が丸ごと効かない。エージェントは通常ペインで起動する。
    [[keys.command]]
    key = "alt+;"
    type = "popup"
    command = "exec \"''${SHELL:-sh}\""
    description = "スクラッチシェルをポップアップで開く"
    width = "80%"
    height = "80%"

    [terminal]
    # 新規ペイン/タブはカレントディレクトリを引き継ぐ
    # follow は「起動時」ではなく「現在(cd 後)」のディレクトリを引き継ぐ。自動タイル分割の
    # スクリプト側でも --cwd を明示しているため二重に確実。
    new_cwd = "follow"

    [theme]
    # ターミナルエミュレータの ANSI パレットをそのまま継承する
    name = "terminal"

    [theme.custom]
    # アクティブペイン境界などのアクセント色をオレンジに
    accent = "#ffaf00"

    [ui]
    # マウスを有効化
    mouse_capture = true
    # 名前入力なしでタブを即時作成する
    prompt_new_tab_name = false
    # タブが1つのときはタブバーを表示しない。new_tab 無効化(keys 参照)と合わせると
    # タブは常に1つなので、タブ UI が完全に見えなくなる
    hide_tab_bar_when_single_tab = true

    [experimental]
    # ペイン内での Kitty graphics(画像描画)を有効化する。herdr 側はまだ experimental 扱いで、
    # 全ペインの Kitty graphics 処理に効く。端末側は Ghostty なのでプロトコルは対応済み。
    kitty_graphics = true
  '';

  # 自動タイル分割スクリプト(Alt-f から呼ばれる)。
  # フォーカス中タブの「一番大きいペイン」を長辺方向に分割する。端末セルは縦:横 ≒ 2:1 なので
  # 幅 > 2*高さ なら右(縦線)分割、そうでなければ下(横線)分割。これを繰り返すとタブは常に
  # 均等グリッドに保たれ、ペインが4つになると自動的に 2x2 になる。
  # 新ペインはフォーカス中ペインのカレントディレクトリ(HERDR_ACTIVE_PANE_CWD)を引き継ぐ。
  # herdr の layout.apply は端末を作り直す破壊的動作なので、非破壊なこの逐次分割方式を採る。
  xdg.configFile."herdr/scripts/autotile-split.sh" = {
    text = ''
      #!/bin/bash
      set -eu
      herdr="''${HERDR_BIN_PATH:-herdr}"
      jq="${pkgs.jq}/bin/jq"
      active="''${HERDR_ACTIVE_PANE_ID:?HERDR_ACTIVE_PANE_ID is not set}"

      # 現在タブのレイアウトから、最大面積のペインとその分割方向を求める。
      read -r target dir < <(
        "$herdr" pane layout --pane "$active" \
          | "$jq" -r '.result.layout.panes
              | max_by(.rect.width * .rect.height)
              | "\(.pane_id) \(if .rect.width > (2 * .rect.height) then "right" else "down" end)"'
      )
      [ -n "''${target:-}" ] || exit 0

      # 新ペインはフォーカス中ペインのカレントディレクトリを引き継ぐ。
      # 取得できなければ config の new_cwd = "follow" に委ねる。
      cwd="''${HERDR_ACTIVE_PANE_CWD:-}"
      if [ -n "$cwd" ]; then
        "$herdr" pane split --pane "$target" --direction "$dir" --cwd "$cwd" --focus
      else
        "$herdr" pane split --pane "$target" --direction "$dir" --focus
      fi
    '';
    executable = true;
  };

  # エージェント/ターミナルのペインへフォーカスを移すスクリプト(Alt-a / Alt-Shift-a / Alt-e から呼ばれる)。
  # 引数1: agent = エージェント(.agent フィールドあり)ペイン, terminal = 非エージェント(シェル)ペイン。
  # 引数2: 巡回範囲。global = タブも space も飛び越えて全ペインを対象 / tab(既定) = 現在タブ内のみ。
  # 引数3: 巡回方向。next(既定) = 並び順 / prev = 逆順。
  # 指定 role に合致するペイン一覧から「アクティブペインの次(prev なら前)」を選んで巡回フォーカスする。
  # pane list は全 space のペインを space 順で返すので、そのままの並びが巡回リングになる。
  # アクティブが別 role に居るとき(例: シェルに居て Alt-a)は、まず同じ space の role ペイン、
  # 無ければ並び順でアクティブより後ろの最初のペイン(prev なら前の最後のペイン)へ移る。
  # フォーカスは socket API の pane.focus を socat で直接叩く。herdr CLI を使わない理由:
  # `herdr pane focus` は --direction 必須(= pane.focus_direction)で id 指定ができず、
  # `herdr agent focus` は対象がエージェントペインに限られる(非エージェントには
  # agent_not_found を返し、フォーカスも動かない)。pane.focus なら role を問わず pane_id 一発で、
  # space をまたぐ移動も含めて動く。
  # 以前は `herdr agent focus <terminal_id>` を使い、ターミナル対象で返る agent_not_found を
  # 「エラーだがフォーカス移動は副作用で成功する」として握り潰していた。herdr 0.7.5 では agent
  # target が terminal_id を一切解決しなくなり(pane_id のみ)、かつその副作用も無くなったため、
  # Alt-a / Alt-Shift-a / Alt-e が揃って無反応になった。エラーを握り潰さないのは、同じ壊れ方を
  # 二度と静かに起こさないため。
  xdg.configFile."herdr/scripts/focus-role.sh" = {
    text = ''
      #!/bin/bash
      set -eu
      herdr="''${HERDR_BIN_PATH:-herdr}"
      jq="${pkgs.jq}/bin/jq"
      socat="${pkgs.socat}/bin/socat"
      active="''${HERDR_ACTIVE_PANE_ID:?HERDR_ACTIVE_PANE_ID is not set}"
      role="''${1:-agent}"
      scope="''${2:-tab}"
      dir="''${3:-next}"

      # role 一致ペイン群(scope=tab なら現在タブに限定)から「アクティブの次(prev なら前)」の
      # pane_id を選ぶ。to_entries の key = pane list 全体での並び位置。これをアクティブ同定と
      # 「前後」判定に使う。
      target=$(
        "$herdr" pane list \
          | "$jq" -r --arg a "$active" --arg role "$role" --arg scope "$scope" --arg dir "$dir" '
              (.result.panes | to_entries) as $e
              | ($e[] | select(.value.pane_id == $a or .value.terminal_id == $a)) as $act
              | [ $e[]
                  | select(.value.agent | if $role == "terminal" then . == null else . != null end)
                  | select($scope == "global" or .value.tab_id == $act.value.tab_id) ] as $list
              | (if $dir == "prev" then -1 else 1 end) as $step
              | if ($list | length) == 0 then empty
                else
                  ($list | map(.key == $act.key) | index(true)) as $idx
                  | if $idx != null then $list[($idx + $step + ($list | length)) % ($list | length)]
                    else
                      ([ $list[] | select(.value.workspace_id == $act.value.workspace_id) ] | first)
                      // (if $dir == "prev"
                          then ([ $list[] | select(.key < $act.key) ] | last)  // $list[-1]
                          else ([ $list[] | select(.key > $act.key) ] | first) // $list[0]
                          end)
                    end
                end
              | .value.pane_id
            '
      )

      [ -n "''${target:-}" ] || exit 0
      socket="''${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
      printf '{"id":"focus-role","method":"pane.focus","params":{"pane_id":"%s"}}\n' "$target" \
        | "$socat" - UNIX-CONNECT:"$socket" >/dev/null
    '';
    executable = true;
  };

  # herdr の agents 一覧(サイドバー)に、Claude Code を起動しているペインだけを
  # 「カレントディレクトリ名」で表示する。
  #
  # 背景と設計:
  # - agents パネルは space 見出し(= ワークスペースのラベル。既定では作成ディレクトリ名)の下に
  #   「ステータス ・ エージェント名」を並べる。既定の名前は検出名(claude 等)止まりで
  #   「今どのディレクトリか」が分からないので、cwd のベース名を付けたい。
  # - ただし herdr は `agent rename` を呼ぶとそのペインを "エージェント扱い" に昇格させ、
  #   Claude Code が居ない素のシェルまで一覧に出してしまう。しかも素シェルに付いた名前は
  #   `agent rename --clear` では消せない(agent_not_found)。よって「全ペインを cd 毎に rename」は
  #   不可(素シェルが一覧に残り続ける)。
  # - そこで rename は Claude Code を起動する瞬間に限定する。`claude`(および alias c)を関数で
  #   ラップし、起動直前に cwd 名を付け、claude 終了直後(まだ herdr が claude を検出中で
  #   `--clear` が効くうち)に名前を消す。これで「claude が動いているペインだけ・cwd 名」になる。
  #
  # 一意性: herdr はエージェント名の一意を強制する(同名の別ペインがあると `agent_name_taken`)。
  # 同じプロジェクトに複数の claude を開くと basename が衝突するため、"base~2","base~3"… と
  # 連番で再試行する(一意制約以外のエラーは即中断)。
  #
  # ペイン境界ラベル: これとは別に、全ペインの境界タイトルへカレントディレクトリ名を
  # 常時表示する(_herdr_label_by_cwd)。`pane rename` は手動ラベルだけを設定するコマンドで、
  # `agent rename` と違い素のシェルをサイドバーへ昇格させないため、cd 毎に全ペインで安全に
  # 呼べる。手動ラベルは show_agent_labels_on_pane_borders 設定と無関係に境界へ常時表示される
  # (見えるのは分割時のみ。1ペインだけのタブは境界自体が無い)。socket 経由 ~6ms なので同期実行。
  # なお `agent rename` は内部で手動ラベルも同時に設定し、`--clear` はエージェント名しか
  # 消さない(ラベルは残留する)。claude 終了時に _herdr_label_by_cwd を呼び直すことで、
  # 連番付き残留ラベル(例: "repo~2")を素の cwd 名へ戻す。
  programs.zsh.initContent = lib.mkOrder 1500 ''
    if [[ -n "$HERDR_PANE_ID" ]]; then
      # ペイン境界ラベルをカレントディレクトリ名に追従させる(シェル起動時 + cd 毎)。
      _herdr_label_by_cwd() {
        local label="''${PWD:t}"
        [[ "$PWD" == "$HOME" ]] && label="~"
        [[ "$PWD" == "/" ]] && label="/"
        herdr pane rename "$HERDR_PANE_ID" "$label" >/dev/null 2>&1
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook chpwd _herdr_label_by_cwd
      _herdr_label_by_cwd

      _herdr_name_by_cwd() {
        local base="''${PWD:t}" try out n=1
        [[ "$PWD" == "$HOME" ]] && base="~"
        [[ "$PWD" == "/" ]] && base="/"
        try="$base"
        while (( n <= 9 )); do
          out=$(herdr agent rename "$HERDR_PANE_ID" "$try" 2>&1) && return
          [[ "$out" == *agent_name_taken* ]] || return
          (( n++ )); try="$base~$n"
        done
      }
      # claude 起動ラッパー。起動時に cwd 名を付け、終了時に名前を外す(= 一覧から落とす)。
      # command で実体を呼ぶので再帰しない。alias c=claude も alias 展開後この関数に届く。
      # --clear は境界ラベルまでは消さないため、_herdr_label_by_cwd で cwd 名へ戻す
      # (agent rename が付けた連番付きラベル "repo~2" などの残留を防ぐ)。
      claude() {
        _herdr_name_by_cwd
        command claude "$@"
        local ret=$?
        herdr agent rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1
        _herdr_label_by_cwd
        return $ret
      }
    fi
  '';
}
