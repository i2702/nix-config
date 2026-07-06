{ pkgs, lib, ... }:
{
  # herdr: AIエージェント時代のターミナルマルチプレクサ (https://herdr.dev)
  # パッケージは flake.nix の input (github:ogulcancelik/herdr) の overlay から供給。
  # キーバインドは modules/tmux.nix と同等の Alt キー中心の構成にしている。
  home.packages = [ pkgs.herdr ];

  xdg.configFile."herdr/config.toml".text = ''
    # herdr 設定 (https://herdr.dev/docs/configuration/)
    # tmux (modules/tmux.nix) と同じ操作感になるようキーバインドを合わせている。
    #
    # tmux にあって herdr に相当機能が無いもの:
    #   - Alt-a (attach): herdr はセッション外から `herdr` 実行でアタッチするため不要
    #   - Alt-= (ペイン均等化): 相当アクションは無いが、下の自動タイル分割で常に均等化される
    #     ため実質不要(手動リサイズは prefix+r のリサイズモードで代替)

    # 初回セットアップ画面をスキップする。このファイルは nix 管理の読み取り専用シンボリックリンク
    # なので、herdr 自身に config.toml を書き込ませない(設定変更はこのモジュールを編集して
    # home-manager switch で反映し、`herdr server reload-config` で再読み込みする)。
    onboarding = false

    [update]
    # 本体の更新は nix (flake input) で管理するため、バックグラウンドの更新チェックは無効化
    version_check = false

    [keys]
    # tmux: プレフィックスキーは Ctrl-b ではなく Alt-t
    prefix = "alt+t"

    # tmux: Alt-r で設定リロード
    reload_config = "alt+r"

    # tmux: Alt-d でデタッチ
    detach = "alt+d"

    # tmux: Alt-h/j/k/l でペイン移動(プレフィックス不要)
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

    # tmux: Alt-q でペインを閉じる
    close_pane = "alt+q"

    # tmux: Alt-c でコピーモード開始。
    # コピーモード内は herdr 標準で vi ライク(h/j/k/l 移動、v で選択開始、y でコピー)なので
    # tmux 側の copy-mode-vi カスタマイズと同等の操作になる。
    copy_mode = "alt+c"

    # tmux: Alt-n で新規ウィンドウ(herdr ではタブが tmux のウィンドウに対応)
    new_tab = "alt+n"

    # tmux: Alt-w でウィンドウ削除
    close_tab = "alt+w"

    # Alt-m は元々「ウィンドウ(タブ)名変更」だったが、サイドバー見出しになる space(ワークスペース)
    # 名の方が分かりにくく変更頻度も高いので、Alt-m を space 名変更(rename_workspace)に振り替える。
    # (rename_workspace は herdr デフォルトだと prefix+shift+w に埋もれている。)
    # タブ名変更(rename_tab)は失わないよう Alt-Shift-m へ退避する。
    rename_workspace = "alt+m"
    rename_tab = "alt+shift+m"

    # tmux: Alt-o / Alt-Right で次、Alt-p / Alt-Left で前のウィンドウ
    next_tab = ["alt+o", "alt+right"]
    previous_tab = ["alt+p", "alt+left"]

    # tmux: Alt-1〜9 でウィンドウ直接選択
    switch_tab = ["alt+1", "alt+2", "alt+3", "alt+4", "alt+5", "alt+6", "alt+7", "alt+8", "alt+9"]

    # tmux にはない「space(ワークスペース)」の操作。tab(=tmux ウィンドウ)の一つ上の階層で、
    # プロジェクト単位のまとまり。macOS では cmd 修飾キーは herdr まで届く(実機確認済み)ため
    # cmd 系に割り当てる。使う3キーはいずれも modules/ghostty.nix で unbind 済み:
    #   cmd+t         … 元 new_tab            -> space 追加
    #   cmd+] / cmd+[ … 元 goto_split 次/前   -> space 次/前(macOS の進む/戻る慣習に合わせる)
    # 補足: 当初 ctrl+tab / ctrl+shift+tab にしたが、Tab は kitty keyboard protocol の
    # 「全キー報告」フラグが無いと Ctrl+Tab が素の Tab に潰れて herdr が識別できず不達だった。
    # herdr にはキーボードプロトコルを制御する設定が無いため Tab 系は諦め、cmd 系にしている。
    new_workspace = "cmd+t"
    next_workspace = "cmd+]"
    previous_workspace = "cmd+["

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
    # 新規ペイン/タブはカレントディレクトリを引き継ぐ(tmux の -c "#{pane_current_path}" 相当)。
    # follow は「起動時」ではなく「現在(cd 後)」のディレクトリを引き継ぐ。自動タイル分割の
    # スクリプト側でも --cwd を明示しているため二重に確実。
    new_cwd = "follow"

    [theme]
    # ターミナルエミュレータの ANSI パレットをそのまま継承する
    name = "terminal"

    [theme.custom]
    # アクティブペイン境界などのアクセント色を tmux の colour214 相当のオレンジに
    accent = "#ffaf00"

    [ui]
    # tmux: set -g mouse on 相当(herdr はデフォルト有効だが明示しておく)
    mouse_capture = true
    # tmux の Alt-n は名前入力なしで即ウィンドウを作るため、タブ名の入力プロンプトは無効化
    # (タブ名は Alt-m でいつでも変更できる)
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
