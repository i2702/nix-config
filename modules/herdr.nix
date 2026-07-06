{ pkgs, lib, ... }:
{
  # herdr: AIエージェント時代のターミナルマルチプレクサ (https://herdr.dev)
  # パッケージは flake.nix の input (github:ogulcancelik/herdr) の overlay から供給。
  home.packages = [ pkgs.herdr ];

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

    # 分割は Alt-v / Alt-s を「自動タイル分割」(下の [[keys.command]])に割り当てた。
    # 一番大きいペインを長辺方向に分割してタブを常に均等グリッドに保つため、ペインが
    # 4つになると自動的に 2x2 になる。方向は自動判定なので Alt-v / Alt-s は同じ動作。
    # 方向を明示したいとき用に、herdr 標準の方向指定分割は prefix 側に残す:
    #   prefix+v (Alt-t → v) = 右に分割 / prefix+s (Alt-t → s) = 下に分割
    split_vertical = "prefix+v"
    split_horizontal = "prefix+s"

    # Alt-q でペインを閉じる
    close_pane = "alt+q"

    # Alt-c でコピーモード開始。
    copy_mode = "alt+c"

    # Alt-m で space 名変更。サイドバー見出しになる space 名は変更頻度が高い。
    # (rename_workspace は herdr デフォルトだと prefix+shift+w に埋もれている。)
    rename_workspace = "alt+m"

    # space(ワークスペース)の操作
    # プロジェクト単位のまとまり。タブはほぼ使わないため、元々タブ操作に充てていた
    # Alt キー一式(alt+n/o/p, alt+left/right, alt+w, alt+1..9)を space 操作へ振り替えた。
    # タブ操作自体は設定行の削除で herdr デフォルト(prefix+n / prefix+p / prefix+1..9 等の
    # prefix 系)に戻るため、必要なら prefix 経由で今も使える。
    # Mac では従来の cmd 系(cmd+t / cmd+] / cmd+[)も併用で残す(modules/ghostty.nix で unbind 済み)。
    # 補足: ctrl+tab / ctrl+alt+n 系はこの端末環境では herdr まで届かず不達だった
    # (Tab 系は kitty keyboard protocol の「全キー報告」フラグが必要)。素の Alt 系が確実。
    new_workspace = ["alt+n", "cmd+t"]
    next_workspace = ["alt+o", "alt+right", "cmd+]"]
    previous_workspace = ["alt+p", "alt+left", "cmd+["]

    # Alt-w で space を閉じる(confirm_close がデフォルト有効のため確認モーダルが出る)
    close_workspace = "alt+w"

    # Alt-1〜9 で space 直接選択
    switch_workspace = "alt+1..9"

    # 自動タイル分割: Alt-v / Alt-s のどちらでもフォーカス中タブに新ペインを追加して
    # 均等グリッドを保つ。type = "shell" はバックグラウンド実行で、スクリプトが herdr CLI 経由で
    # 「一番大きいペインを長辺方向に分割」する。これによりペイン4つで必ず 2x2 になる。
    [[keys.command]]
    key = "alt+v"
    type = "shell"
    command = "~/.config/herdr/scripts/autotile-split.sh"
    description = "自動タイル分割(グリッドに追加)"

    [[keys.command]]
    key = "alt+s"
    type = "shell"
    command = "~/.config/herdr/scripts/autotile-split.sh"
    description = "自動タイル分割(グリッドに追加)"

    # エージェント/ターミナルのペイン間フォーカス移動(現在タブ内で巡回)。
    # herdr の native な focus_agent はインデックス型(prefix+alt+1..9)しかなく、
    # 「ターミナルへフォーカス」に相当する native アクションは存在しない
    # (ターミナルは通常ペイン扱いで focus_pane_* / 方向指定でしか辿れない)。
    # そのため既存の自動タイル分割と同様、herdr CLI を使うカスタムコマンドで実装する。
    #   Alt-f = エージェント(claude 等)ペインへ / Alt-e = 非エージェント(シェル)ペインへ。
    # 同じ role のペインが現在タブに複数あれば、押すたびに次のペインへ巡回する。
    [[keys.command]]
    key = "alt+f"
    type = "shell"
    command = "~/.config/herdr/scripts/focus-role.sh agent"
    description = "エージェントペインへフォーカス(タブ内で巡回)"

    [[keys.command]]
    key = "alt+e"
    type = "shell"
    command = "~/.config/herdr/scripts/focus-role.sh terminal"
    description = "ターミナル(非エージェント)ペインへフォーカス(タブ内で巡回)"

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
  '';

  # 自動タイル分割スクリプト(Alt-v / Alt-s から呼ばれる)。
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

  # エージェント/ターミナルのペインへフォーカスを移すスクリプト(Alt-f / Alt-e から呼ばれる)。
  # 引数: agent = エージェント(.agent フィールドあり)ペイン, terminal = 非エージェント(シェル)ペイン。
  # 現在タブの、指定 role に合致するペイン一覧から「アクティブペインの次」を選んで巡回フォーカスする。
  # アクティブが別 role に居るとき(例: シェルに居て Alt-f)は role 側の先頭ペインへ移る。
  # フォーカスは herdr agent focus <terminal_id> で行う。任意ペインを id 指定でフォーカスできる
  # 唯一の CLI 手段がこれ(pane focus は方向指定のみ)。ターミナル(エージェント不在)を対象にすると
  # 戻り値は agent_not_found エラーになるが、フォーカス移動自体は副作用として成功するため
  # >/dev/null 2>&1 || true でエラー出力と終了コードを握りつぶす。
  xdg.configFile."herdr/scripts/focus-role.sh" = {
    text = ''
      #!/bin/bash
      set -eu
      herdr="''${HERDR_BIN_PATH:-herdr}"
      jq="${pkgs.jq}/bin/jq"
      active="''${HERDR_ACTIVE_PANE_ID:?HERDR_ACTIVE_PANE_ID is not set}"
      role="''${1:-agent}"

      # 現在タブの role 一致ペイン群から「アクティブの次」の terminal_id を選ぶ。
      # アクティブが一覧に無い(別 role に居る)ときは先頭を選ぶ。
      target=$(
        "$herdr" pane list \
          | "$jq" -r --arg a "$active" --arg role "$role" '
              .result.panes as $p
              | ($p[] | select(.pane_id == $a or .terminal_id == $a) | .tab_id) as $tab
              | [ $p[]
                  | select(.tab_id == $tab)
                  | select(if $role == "terminal" then (.agent == null) else (.agent != null) end) ] as $list
              | if ($list | length) == 0 then empty
                else
                  ($list | map(.pane_id == $a or .terminal_id == $a) | index(true)) as $idx
                  | (if $idx == null then 0 else (($idx + 1) % ($list | length)) end) as $next
                  | $list[$next].terminal_id
                end
            '
      )

      [ -n "''${target:-}" ] || exit 0
      "$herdr" agent focus "$target" >/dev/null 2>&1 || true
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
  programs.zsh.initContent = lib.mkOrder 1500 ''
    if [[ -n "$HERDR_PANE_ID" ]]; then
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
      claude() {
        _herdr_name_by_cwd
        command claude "$@"
        local ret=$?
        herdr agent rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1
        return $ret
      }
    fi
  '';
}
