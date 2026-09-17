{ config, pkgs, lib, ... }:
let
  # ペインの名前(リポジトリ名、リポジトリ外ならディレクトリ名)とブランチを出す zsh 関数群。
  # 素のシェル(initContent の precmd)と Claude Code のフック(claude-pane-label.zsh)で
  # 同じ値を出すため、両方へこの定義をそのまま埋め込む。
  #
  # ブランチを名前に混ぜず pane の branch トークンに分けて持つのは、サイドバーの space 2行目
  # ($branch)へ単独で出すため。herdr 組み込みの branch トークンを使わない理由は
  # space-label-follow.zsh のコメント参照。
  #
  # リポジトリ名を --show-toplevel の basename にしない理由: gwq のワークツリーは
  # "sub-feature-xxx" のようなブランチ由来のディレクトリ名になり、どのリポジトリか分からない。
  # 共通 git ディレクトリ(本体の .git)の親から取ればワークツリーでも本体の名前になる。
  # 共通ディレクトリが .git で終わらない(サブモジュール/ベアリポジトリ)ときだけ toplevel に戻す。
  # rev-parse を1回にまとめているのは、precmd で毎プロンプト走るため(実測 ~6ms)。
  paneLabelFns = ''
    # $1 のディレクトリについて reply=(<名前> <ブランチ>) を返す。リポジトリ外ならブランチは空。
    _herdr_label_for() {
      local dir=$1 out common top branch repo
      out=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir --show-toplevel --abbrev-ref HEAD 2>/dev/null)
      local -a info=("''${(@f)out}")
      common=''${info[1]} top=''${info[2]} branch=''${info[3]}
      if [[ -z "$common" || -z "$top" ]]; then
        if [[ "$dir" == "$HOME" ]]; then reply=("~" "")
        elif [[ "$dir" == / ]]; then reply=(/ "")
        else reply=("''${dir:t}" "")
        fi
        return
      fi
      # --abbrev-ref が名前を返せない(空 or "HEAD")のは、コミットの無い新規リポジトリか detached HEAD。
      # 前者は symbolic-ref でブランチ名が引け、後者は失敗するので短縮 SHA にする。
      if [[ -z "$branch" || "$branch" == HEAD ]]; then
        branch=$(git -C "$dir" symbolic-ref --short -q HEAD) \
          || branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
      fi
      repo=''${top:t}
      [[ "''${common:t}" == .git ]] && repo=''${common:h:t}
      reply=("$repo" "$branch")
    }

    # ペイン $1 に名前 $2 を付け、名前・ブランチ $3・それを引いたディレクトリ $4 を
    # name / branch / dir トークンとして報告する(ブランチが空なら branch を消す)。
    # dir は space-label-follow.zsh が「報告がペインの今の cwd に対するものか」を突き合わせるためのもの。
    # 末尾80文字だけ持つ理由: トークン値は herdr 側で先頭80文字に黙って切り詰められ、
    # ワークツリーのパスは容易に超える。末尾なら切られず、比較する側も末尾80文字で揃えられる。
    _herdr_report_pane() {
      local herdr="''${HERDR_BIN_PATH:-herdr}" dir=$4
      local -a branch=(--clear-token branch)
      [[ -n "$3" ]] && branch=(--token "branch=$3")
      "$herdr" pane rename "$1" "$2" >/dev/null 2>&1 || return
      "$herdr" pane report-metadata "$1" --source herdr-labels \
        --token "name=$2" "''${branch[@]}" --token "dir=''${dir[-80,-1]}" >/dev/null 2>&1
    }
  '';

  # Claude Code のセッション cwd を、ペインごとに1ファイル(中身はフルパス1行)で置く場所。
  # フック(claude-pane-label.zsh)が書き、claude ラッパーが終了時に消し、split-pane.sh と
  # space-label-follow.zsh が読む。herdr のトークンに置かない理由: 値は先頭80文字に切られて
  # フルパスを復元できず、live-handoff でも消えるため。
  claudeCwdDir = "${config.xdg.stateHome}/herdr/claude-cwd";

  # 外側の端末のウィンドウタイトルとして herdr 自身に書かせる文字列。
  # WSL (= Win 機) では "󰖳 Win"、Mac では空 (= herdr に書かせない)。
  #
  # 記号は Nerd Font の Windows ロゴ U+F05B3。TOML の \U エスケープで書くのは、
  # 私用領域の字をソースに直接置くとエディタで豆腐に見え、編集事故になるため
  # (同じ字を出す Mac 側の zsh も $'\U000F05B3 Win' で持っている: modules/zsh.nix)。
  #
  # Mac を空にする理由: ローカル " Mac" と ssh 中 "󰖳 Win" の出し分けは zsh が
  # socket API (client.window_title.set) で行う。API 値は config より優先されるので
  # 両方に持たせても効くが、出し先が2箇所に散るだけで得が無い。
  #
  # WSL に値を持たせる理由 (Why not: 空のままにしない): ssh 先の herdr を再起動しても
  # Ghostty のタイトルが "󰖳 Win" に戻らなかった。herdr を抜けている間の ssh 側
  # ログインシェルが oh-my-zsh の termsupport で OSC 2 ("%n@%m:%~" や実行中コマンド) を
  # 書き、herdr を挟まない経路なのでそれが Mac まで素通りして、zsh が ssh 実行時に
  # 立てた "󰖳 Win" を潰す。空だと herdr は何も書かないため潰れたままになる。
  # herdr 自身に正しい値を書かせておけば、前面クライアントが付き直すたび
  # (再起動 / live-handoff / 再アタッチ) にタイトルが戻る。
  windowTitle = lib.optionalString pkgs.stdenv.isLinux "\\U000F05B3 Win";
in
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

    # 分割の Alt キーは、方向を自動判定してグリッドを保つ「自動タイル分割」の Alt-s だけにする。
    # 下の [[keys.command]] で split-pane.sh を呼ぶ(ネイティブの split_vertical / split_horizontal に
    # しない理由は同スクリプト参照)。向きを指定したいときは prefix 側(Alt-t → v = 右 / s = 下)の
    # ネイティブ分割を使う。
    # 以前は Alt-v / Alt-s を方向指定、Alt-f を自動タイルに充てていたが、Alt-s へ自動タイルを寄せて
    # Alt-f / Alt-v は外した。
    split_vertical = "prefix+v"
    split_horizontal = "prefix+s"

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
    # Alt-n の space 作成は下の [[keys.command]] の new-space.sh が担う(アクティブ space の直下に
    # 作るため)。ネイティブ側を空にするのは、組み込みアクションと同じキーのカスタムコマンドは
    # herdr に無効化されるため。
    new_workspace = ""
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

    # Alt-n で新しい space を、アクティブ space の直下に作る(ネイティブの new_workspace は末尾に足す)
    [[keys.command]]
    key = "alt+n"
    type = "shell"
    command = "~/.config/herdr/scripts/new-space.sh"
    description = "アクティブ space の直下に新しい space を作る"

    # 分割。type = "shell" はバックグラウンド実行で、split-pane.sh が herdr CLI 経由で分割する。
    #   Alt-s = 自動タイル分割: フォーカス中のペインを起点に 2x2 グリッドへ割る(4分割済みなら何もしない)
    [[keys.command]]
    key = "alt+s"
    type = "shell"
    command = "~/.config/herdr/scripts/split-pane.sh auto"
    description = "自動タイル分割(2x2 グリッドに追加)"

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
    # (Alt-s → Alt-q)手間を無くすのが目的。
    # キーが Alt-a でない理由: Alt-a は上のエージェントペインフォーカスで埋まっており、
    # そちらは使用頻度が高く動かしたくない。Alt-; は herdr デフォルトとも既存設定とも衝突しない。
    # なお句読点+修飾キーの到達性は端末依存(default-config にも注記あり)。届かない端末に
    # 当たったら alt+shift+semicolon 等ではなく別の英字キーへ振り替える。
    # popup で claude を起動しない理由: popup には HERDR_PANE_ID が渡らない(背後のペインの
    # HERDR_ACTIVE_PANE_ID のみ)ため、下の zsh ラッパーによるサイドバー名/ペインラベルの
    # cwd 追従が丸ごと効かない。エージェントは通常ペインで起動する。
    # 閉じるのは Ctrl-D(シェル終了)か Alt-'(下の zsh 側の _herdr_close_popup)。
    # ここに閉じるキーを足せない理由は下のウィジェットのコメント参照。
    [[keys.command]]
    key = "alt+;"
    type = "popup"
    command = "exec \"''${SHELL:-sh}\""
    description = "スクラッチシェルをポップアップで開く"
    width = "80%"
    height = "80%"

    [terminal]
    # 新規ペイン/タブはカレントディレクトリを引き継ぐ
    # follow は「起動時」ではなく「現在(cd 後)」のディレクトリを引き継ぐ。ただし前面プロセスの
    # cwd を優先するため、Claude Code のペインでは起動ディレクトリになる。キー操作の分割
    # (split-pane.sh)は --cwd を明示してこれを避けるが、マウス操作や prefix+v / prefix+s の分割は
    # この follow のまま。
    new_cwd = "follow"

    [theme]
    # ターミナルエミュレータの ANSI パレットをそのまま継承する
    name = "terminal"

    [theme.custom]
    # アクティブペイン境界などのアクセント色をオレンジに
    accent = "#ffaf00"

    [ui]
    # 外側の端末(Ghostty / WezTerm)のウィンドウタイトル。前面クライアントが付くたびに
    # OSC 0 で1回書かれる。値と、Mac が空で WSL だけ "󰖳 Win" を持つ理由は
    # 冒頭の let の windowTitle 参照。
    window_title = "${windowTitle}"
    # マウスを有効化
    mouse_capture = true
    # 名前入力なしでタブを即時作成する
    prompt_new_tab_name = false
    # タブが1つのときはタブバーを表示しない。new_tab 無効化(keys 参照)と合わせると
    # タブは常に1つなので、タブ UI が完全に見えなくなる
    hide_tab_bar_when_single_tab = true

    [ui.sidebar.spaces]
    # space カードの2行: 1行目 = space 名(フォーカス中ペインのリポジトリ名) / 2行目 = そのブランチ。
    # 2行目を組み込みの branch ではなく $branch(space-label-follow.zsh が workspace トークンとして
    # 写す値)にする理由は同スクリプトのコメント参照(組み込みは最初のタブの root ペインしか見ない)。
    # 組み込みの git_status(↑↓)も同じく root ペイン基準でフォーカス中のリポジトリと食い違うため外した。
    rows = [["state_icon", "workspace"], ["$branch"]]

    [experimental]
    # ペイン内での Kitty graphics(画像描画)を有効化する。herdr 側はまだ experimental 扱いで、
    # 全ペインの Kitty graphics 処理に効く。端末側は Ghostty なのでプロトコルは対応済み。
    kitty_graphics = true
  '';

  # 新しい space をアクティブ space の直下に作るスクリプト(Alt-n から呼ばれる)。
  # herdr は space を常に一覧の末尾へ足し、作成位置を指定する設定も CLI オプションも無いので、
  # 作ってから socket API の workspace.move で「アクティブ space の位置 + 1」へ移す
  # (insert_index は「その位置の前へ挿入」)。移動後もフォーカスは新しい space に残る。
  # workspace.move を socat で直接叩くのは、CLI の `herdr workspace` に move サブコマンドが無いため。
  # --cwd を渡さない理由: workspace.create は cwd 省略時にネイティブの new_workspace と同じ解決
  # (アクティブ space のフォーカス中ペインの cwd → new_cwd = "follow")をするので、ここで真似る必要が無い。
  # herdr 自身の worktree 機能で作った space はサイドバーで親の下にまとめて描かれ、一覧の並びと
  # 見た目の並びがずれるが、ワークツリーは gwq で作っているので考慮しない。
  xdg.configFile."herdr/scripts/new-space.sh" = {
    text = ''
      #!/bin/bash
      set -eu
      herdr="''${HERDR_BIN_PATH:-herdr}"
      jq="${pkgs.jq}/bin/jq"
      socat="${pkgs.socat}/bin/socat"
      active="''${HERDR_ACTIVE_WORKSPACE_ID:-}"

      new=$("$herdr" workspace create --focus | "$jq" -r '.result.workspace.workspace_id // empty')
      [ -n "$new" ] || exit 1
      # space が1つも無い状態からの作成なら並べ替える相手が居ない
      [ -n "$active" ] || exit 0

      index=$(
        "$herdr" workspace list \
          | "$jq" -r --arg a "$active" '.result.workspaces | map(.workspace_id) | index($a) // empty'
      )
      [ -n "$index" ] || exit 0
      socket="''${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
      printf '{"id":"new-space","method":"workspace.move","params":{"workspace_id":"%s","insert_index":%d}}\n' \
        "$new" "$((index + 1))" \
        | "$socat" - UNIX-CONNECT:"$socket" >/dev/null
    '';
    executable = true;
  };

  # ペイン分割スクリプト(Alt-s から auto で呼ばれる)。引数: auto | right | down。
  #   auto         = 自動タイル分割。フォーカス中のペインを起点に 2x2 グリッドを作る。
  #                  タブの全幅を占めている(まだ縦に割られていない)なら縦線で2分割、全幅は無いが全高を
  #                  占めているなら横線で2分割。herdr の split は right / down しか無いため、元ペインは
  #                  常に左 / 上に残る。フォーカス中が既に 1/4 サイズなら、まだ 1/4 でない他のペインを
  #                  代わりに割り、全部 1/4(= 4分割済み)なら何もしない。
  #                  「全幅/全高を占めるか」を splits ツリーの構造ではなく rect とタブ area の比(0.6 超)で
  #                  見る理由: 4分割済みかどうかは面積の話で、ツリーの形(左右を先に割ったか上下を先に割ったか)
  #                  とは独立に決まるため。代わりに手動リサイズで 6:4 より偏らせたペインは「まだ割られていない」
  #                  と見なされて更に割れるが、グリッドを保つ使い方では起きない。
  #                  herdr の layout.apply は端末を作り直す破壊的動作なので、非破壊なこの逐次分割方式を採る。
  #   right / down = フォーカス中のペインをその向きに分割する。今はどのキーにも割り当てていない。
  #                  消さないのは、方向指定分割を Alt キーへ戻すときにネイティブ分割の cwd 問題(下記)を
  #                  避ける手段としてそのまま使えるため。
  # 新ペインのディレクトリは --cwd で明示する。シェルのペインなら herdr が渡す HERDR_ACTIVE_PANE_CWD、
  # Claude Code のペインならフックが claudeCwdDir に残したセッション cwd(= space 名が示す場所)。
  # ネイティブの分割(new_cwd = "follow")に任せない理由: follow はペインの前面プロセスの cwd を
  # 最優先する(PaneRuntime::follow_cwd)。Claude Code は中で移動してもプロセスの cwd が起動時のまま
  # なので、space 名は移動先のワークツリーを示しているのに新ペインは起動ディレクトリで開いていた。
  xdg.configFile."herdr/scripts/split-pane.sh" = {
    text = ''
      #!/bin/bash
      set -eu
      herdr="''${HERDR_BIN_PATH:-herdr}"
      jq="${pkgs.jq}/bin/jq"
      active="''${HERDR_ACTIVE_PANE_ID:?HERDR_ACTIVE_PANE_ID is not set}"
      mode="''${1:-auto}"

      if [ "$mode" = auto ]; then
        # 現在タブのレイアウトから、割るペインとその向きを求める。2x2 が埋まっていれば何も出力しない。
        read -r target dir < <(
          "$herdr" pane layout --pane "$active" \
            | "$jq" -r --arg active "$active" '
                .result.layout as $l
                # タブ area の6割超を占める辺は、その向きにまだ割られていない。
                | def dir_of:
                    if .rect.width > $l.area.width * 0.6 then "right"
                    elif .rect.height > $l.area.height * 0.6 then "down"
                    else null end;
                  [$l.panes[] | . + { dir: dir_of }] as $panes
                | (
                    ($panes[] | select(.pane_id == $active and .dir))
                    // ($panes | map(select(.dir)) | max_by(.rect.width * .rect.height))
                  ) as $t
                | if $t then "\($t.pane_id) \($t.dir)" else empty end'
        ) || true
        [ -n "''${target:-}" ] || exit 0
      else
        target=$active
        dir=$mode
      fi

      # 新ペインのディレクトリ。Claude Code のペインならセッション cwd を優先する。
      # ファイルがあるだけで信じず agent を確かめるのは、ラッパーを通らず終了した claude の
      # 残骸ファイルで、シェルに戻ったペインを古いディレクトリへ飛ばさないため。
      cwd="''${HERDR_ACTIVE_PANE_CWD:-}"
      claude_cwd_file="${claudeCwdDir}/$active"
      if [ -f "$claude_cwd_file" ] \
        && [ "$("$herdr" pane get "$active" | "$jq" -r '.result.pane.agent // empty')" = claude ]; then
        claude_cwd=$(<"$claude_cwd_file")
        [ -d "$claude_cwd" ] && cwd=$claude_cwd
      fi

      # 取得できなければ config の new_cwd = "follow" に委ねる。
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

  # Claude Code の中でのペイン名・ブランチ追従。claude ラッパー(下の initContent)が --settings で読み込ませる。
  # Bash ツールで cd してもペインのシェル自体は動かないので、zsh の precmd では追従できない。
  # 代わりにフックで、Claude のセッション cwd から paneLabelFns の名前とブランチを報告し直す。
  #   SessionStart      = 起動直後(ラッパーの agent rename が付けた basename ラベルを上書き)
  #   CwdChanged        = セッション内の移動
  #   PostToolUse(Bash) = cd を伴わない git switch 等でブランチだけが変わった場合
  # フック入力の new_cwd を使わない理由: 作業ディレクトリ外への cd でも CwdChanged は new_cwd に
  # 移動先を載せて発火し、直後に元へ戻されるが、戻った側の CwdChanged は来ない(実測)。
  # 入力の cwd は戻された後の値なので、常にこちらを使う。
  #
  # ~/worktrees(gwq.nix の worktree.basedir)を additionalDirectories に入れる理由: gwq の
  # ワークツリーはプロジェクト外なので、そのままでは cd が即座に戻されてペイン名も移らない。
  # 作業ディレクトリとして許可すると移動が持続する(代償: ~/worktrees 配下全体がプロジェクトと
  # 同じ権限範囲になる)。~/.claude/settings.json に書かないのは、claude-code.nix の方針で
  # settings.json を nix 管理していないのと、herdr 外で起動した claude には不要なため。
  xdg.configFile."herdr/claude-settings.json".text = builtins.toJSON {
    permissions.additionalDirectories = [ "${config.home.homeDirectory}/worktrees" ];
    hooks =
      let
        relabel = [{ type = "command"; command = "$HOME/.config/herdr/scripts/claude-pane-label.zsh"; }];
      in
      {
        SessionStart = [{ hooks = relabel; }];
        CwdChanged = [{ hooks = relabel; }];
        PostToolUse = [{ matcher = "Bash"; hooks = relabel; }];
      };
  };

  xdg.configFile."herdr/scripts/claude-pane-label.zsh" = {
    text = ''
      #!${pkgs.zsh}/bin/zsh -f
      # stdin: Claude Code のフック入力(JSON)。herdr 外や cwd が取れないときは何もしない。
      # 失敗しても Claude の動作を止めないよう、常に 0 で抜ける。
      [[ -n "$HERDR_PANE_ID" ]] || exit 0
      dir=$(${pkgs.jq}/bin/jq -r '.cwd // empty')
      [[ -d "$dir" ]] || exit 0
      ${paneLabelFns}
      # split-pane.sh と space-label-follow.zsh 用に、セッション cwd をフルパスで残す。
      # 報告より先に書くのは、報告の pane.updated を受けた常駐側がこのファイルを読むため。
      mkdir -p "${claudeCwdDir}" && print -r -- "$dir" > "${claudeCwdDir}/$HERDR_PANE_ID"
      _herdr_label_for "$dir"
      _herdr_report_pane "$HERDR_PANE_ID" "''${reply[1]}" "''${reply[2]}" "$dir"
      exit 0
    '';
    executable = true;
  };

  # space の表示を、フォーカスしたペインに合わせる常駐スクリプト。
  #   1行目(space 名) = ペインの名前(リポジトリ名 / リポジトリ外ならディレクトリ名)
  #   2行目($branch)  = そのブランチ(config.toml の [ui.sidebar.spaces] rows)
  # 値はペインが報告した name / branch トークン(precmd / Claude フック)を使うが、報告が
  # 「ペインの今の cwd に対するもの」と確かめられないときは捨て、ここで cwd から引き直す。
  # 報告を鵜呑みにしない理由: 報告しないシェル(この仕組みより前の .zshrc を読んだまま)や
  # 手動の pane rename があると、名前とブランチが別の時点・別のディレクトリの値になる。
  # 実際に ~/worktrees/.../nix-config/foobar で "foobar" と古い "main" が組み合わさって出た。
  # 確かめ方: name があり、dir トークンが基準ディレクトリの末尾80文字と一致すれば信じる。基準は
  # ペインの cwd だが、Claude Code のペイン(agent あり)は中で移動してもペインの cwd が起動時の
  # ままなので、フックが claudeCwdDir に残したセッション cwd を基準にする。
  # herdr 組み込みの branch トークンを使わない理由: 組み込みのブランチ(と自動 space 名)は、space の
  # 「最初のタブの root ペイン」の cwd から引かれる(Workspace::resolved_identity_cwd_from)。
  # root 以外のペインで移動しても変わらず、root ペインがリポジトリ外に居ればブランチは出ない。
  # フォーカス中のペインを基準にするには、ブランチを自前で workspace のトークンへ流すしかない。
  # なお $branch はカスタムトークンだが、space カードでは組み込み branch と同じスタイルで描かれる。
  #
  # herdr にはフォーカス変更時にコマンドを走らせる設定が無いため、socket API の events.subscribe を
  # 購読し続けるプロセスを1つ置く。起動は zsh の precmd(_herdr_ensure_space_follow)が、ロックが
  # 空いているとき(= 未起動か落ちた後)だけ行う。
  #   pane.focused / workspace.focused = フォーカスしたペインの名前とブランチを、その space へ写す
  #   pane.updated = フォーカス中ペインの名前かブランチが変わったとき(cd / git switch / Claude 内の移動)も写す。
  #                  ターミナルタイトルの変化でも頻繁に届くので、前回写した値と同じ部分は送らない。
  # 帰結として、Alt-m で手で付けた space 名は次にフォーカスが動くかペイン名が変わった時点で上書きされる。
  # 切断されたら(server 再起動 / live-handoff)3秒後に再接続し、socket 自体が消えたら終了する
  # (herdr が居ないのに回り続けないため。herdr のシェルが次にプロンプトを出せば再起動される)。
  #
  # focus-role.sh のように socat を使わない理由: 購読リクエストを送った後も接続を開いたままに
  # するには socat の stdin に sleep 等を繋ぐ必要があり、サーバ側が切断しても左側のプロセスが残って
  # 再接続のたびに溜まる。zsocket なら接続を自分で持ち、jq が EOF を受けた時点でパイプラインが終わる。
  xdg.configFile."herdr/scripts/space-label-follow.zsh" = {
    text = ''
      #!${pkgs.zsh}/bin/zsh -f
      zmodload zsh/system zsh/net/socket || exit 1
      herdr="''${HERDR_BIN_PATH:-herdr}"
      jq="${pkgs.jq}/bin/jq"
      socket="''${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
      # 列の区切り。タブは IFS 上の空白扱いで連続すると空欄が潰れ、ブランチの無いペインで
      # 列がずれるため、空白扱いされない US(0x1f)を使う。
      us=$'\x1f'

      # 多重起動防止。zsystem flock は fcntl ロックなので、プロセスが落ちれば自動で外れる。
      # ロックファイルは自動生成されないため先に作る。
      lock="$socket.space-label.lock"
      : >> "$lock"
      zsystem flock -t 0 -f lockfd "$lock" 2>/dev/null || exit 0

      # 報告を信用できないペインの名前とブランチを、ここで cwd から引くための _herdr_label_for
      ${paneLabelFns}

      # workspace_id -> このスクリプトが最後に写した名前 / ブランチ
      typeset -A applied_label applied_branch
      # pane_id -> 自前で引いたときの cwd と結果(頻繁に届く pane.updated のたびに git を叩かないため)
      typeset -A computed_cwd computed_name computed_branch

      # jq で1ペインを US 区切りの1行にする(区切りは --arg us で渡す)。並びは read の変数順と揃える。
      pane_fields='def fields: [.workspace_id, .pane_id, (.cwd // ""), (.agent // ""),
        (.tokens.name // ""), (.tokens.branch // ""), (.tokens.dir // "")] | join($us);'

      # space $1 へ名前 $2 とブランチ $3 を写す。前回写した値と同じ部分は送らない。
      apply_space() {
        [[ -n "$1" && -n "$2" ]] || return
        if [[ "''${applied_label[$1]}" != "$2" ]]; then
          "$herdr" workspace rename "$1" "$2" >/dev/null 2>&1 && applied_label[$1]=$2
        fi
        if (( ! ''${+applied_branch[$1]} )) || [[ "''${applied_branch[$1]}" != "$3" ]]; then
          if [[ -n "$3" ]]; then
            "$herdr" workspace report-metadata "$1" --source herdr-labels --token "branch=$3" >/dev/null 2>&1
          else
            "$herdr" workspace report-metadata "$1" --source herdr-labels --clear-token branch >/dev/null 2>&1
          fi && applied_branch[$1]=$3
        fi
      }

      # ペイン $1(cwd $2 / agent $3 / 報告された name $4・branch $5・dir $6)の表示値を
      # reply=(<名前> <ブランチ>) に入れる。$7 が空でなければ覚えを使わず引き直す
      # (フォーカス時。報告しないシェルで cd を伴わず git switch した場合を拾う)。
      resolve_pane() {
        local base=$2
        if [[ -n "$3" && -f "${claudeCwdDir}/$1" ]]; then
          base=$(<"${claudeCwdDir}/$1")
        fi
        if [[ -n "$4" && "$6" == "''${base[-80,-1]}" ]]; then
          reply=("$4" "$5")
          return
        fi
        [[ -d "$base" ]] || return 1
        if [[ -z "$7" && "''${computed_cwd[$1]}" == "$base" ]]; then
          reply=("''${computed_name[$1]}" "''${computed_branch[$1]}")
          return
        fi
        _herdr_label_for "$base"
        computed_cwd[$1]=$base computed_name[$1]=''${reply[1]} computed_branch[$1]=''${reply[2]}
      }

      # focus イベントは表示値を持たない(workspace.focused はペイン ID すら無い)ので引き直す。
      # 前回値を捨ててから写すのは、Alt-m などで手で変えた space 名もフォーカス時に戻すため。
      sync_focused() {
        local ws pane cwd agent name branch dir
        "$herdr" pane list 2>/dev/null \
          | "$jq" -r --arg us "$us" "$pane_fields"' first(.result.panes[] | select(.focused)) | fields' \
          | IFS=$us read -r ws pane cwd agent name branch dir
        [[ -n "$ws" ]] || return
        resolve_pane "$pane" "$cwd" "$agent" "$name" "$branch" "$dir" force || return
        unset "applied_label[$ws]" "applied_branch[$ws]"
        apply_space "$ws" "''${reply[1]}" "''${reply[2]}"
      }

      while [[ -S "$socket" ]]; do
        if zsocket "$socket" 2>/dev/null; then
          fd=$REPLY
          print -u$fd -r -- '{"id":"space-label-follow","method":"events.subscribe","params":{"subscriptions":[{"type":"pane.focused"},{"type":"workspace.focused"},{"type":"pane.updated"}]}}'
          # 切断中に起きた変更を取りこぼさないよう、接続のたびに一度合わせる
          sync_focused
          "$jq" --unbuffered -r --arg us "$us" "$pane_fields"'
              if .event == "pane_focused" or .event == "workspace_focused" then "focus"
              elif .event == "pane_updated" and .data.pane.focused then "update" + $us + (.data.pane | fields)
              else empty end' <&$fd \
            | while IFS=$us read -r kind ws pane cwd agent name branch dir; do
                if [[ "$kind" == focus ]]; then sync_focused
                elif resolve_pane "$pane" "$cwd" "$agent" "$name" "$branch" "$dir"; then
                  apply_space "$ws" "''${reply[1]}" "''${reply[2]}"
                fi
              done
          exec {fd}>&-
        fi
        sleep 3
      done
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
  # ペイン境界ラベル: これとは別に、全ペインの境界タイトルへリポジトリ名(リポジトリ外なら
  # ディレクトリ名。paneLabelFns)を常時表示し、ブランチは pane の branch トークンとして報告する
  # (space の2行目へは space-label-follow.zsh が写す)。`pane rename` は手動ラベルだけを
  # 設定するコマンドで、`agent rename` と違い素のシェルをサイドバーへ昇格させないため、全ペインで
  # 安全に呼べる。手動ラベルは show_agent_labels_on_pane_borders 設定と無関係に境界へ常時表示される
  # (見えるのは分割時のみ。1ペインだけのタブは境界自体が無い)。socket 経由 ~6ms なので同期実行。
  # chpwd ではなく precmd で更新するのは、cd を伴わない git switch でもブランチを追従させるため
  # (AUTO_CD で cd を省略した移動も、プロンプトは必ず出るので同じ経路で拾える)。
  # ディレクトリ・名前・ブランチのどれかが変わったときだけ報告するので、毎プロンプトの追加コストは
  # git 1回(~6ms)で済む。
  # Claude Code の中の移動はシェルの precmd に届かないため、claude ラッパーが --settings で渡す
  # フック(claude-pane-label.zsh)が付け直す。
  # なお `agent rename` は内部で手動ラベルも同時に設定し、`--clear` はエージェント名しか
  # 消さない(ラベルは残留する)。claude 終了時に _herdr_label(前回報告した名前とブランチ)を捨てて
  # 次の precmd で付け直させ、連番付き残留ラベル(例: "repo~2")や Claude 内で移動した先の値を戻す。
  programs.zsh.initContent = lib.mkOrder 1500 ''
    if [[ -n "$HERDR_PANE_ID" ]]; then
      ${paneLabelFns}
      # シェル起動時に直接呼ばない理由: Claude Code の shell snapshot(tty 無しの interactive zsh)も
      # .zshrc を通るため、フックが付けた Claude 側の値を上書きしうる。precmd はプロンプトを
      # 出す実シェルでしか走らない。
      _herdr_label=""
      _herdr_update_label() {
        _herdr_label_for "$PWD"
        # 同じリポジトリ内の移動でも dir トークンを今の cwd に合わせ直すため、$PWD も比較に含める
        local current="$PWD"$'\n'"''${(pj:\n:)reply}"
        [[ "$current" == "$_herdr_label" ]] && return
        _herdr_report_pane "$HERDR_PANE_ID" "''${reply[1]}" "''${reply[2]}" "$PWD" && _herdr_label=$current
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _herdr_update_label

      # space 名追従の常駐スクリプト(space-label-follow.zsh)を、居なければ起動する。
      # ロックを試しに取れた = 誰も持っていない = 未起動か落ちた後。取れたらすぐ外して起動する
      # (同時に複数のシェルが起動しても、スクリプト側のロックで1つ以外は即終了する)。
      # シェル起動時の1回だけにしない理由: server 再起動で socket が消えて常駐が終了した後も、
      # どこかのシェルがプロンプトを出した時点で戻るようにするため。確認は fcntl 1回で済む。
      zmodload zsh/system
      _herdr_ensure_space_follow() {
        local lock="''${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}.space-label.lock" fd
        if [[ -e "$lock" ]]; then
          zsystem flock -t 0 -f fd "$lock" 2>/dev/null || return
          zsystem flock -u $fd
        fi
        ~/.config/herdr/scripts/space-label-follow.zsh </dev/null >/dev/null 2>&1 &!
      }
      add-zsh-hook precmd _herdr_ensure_space_follow

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
      # --settings はペイン名追従のフックと ~/worktrees の許可(claude-settings.json)を足すもので、
      # ユーザー/プロジェクトの設定とは併合される。
      # 終了後に _herdr_label を捨て、次の precmd でシェル自身の cwd の名前へ付け直させる
      # (--clear は境界ラベルまでは消さないため、agent rename の連番付きラベル "repo~2" や
      # Claude 内で移動した先の名前が残るのを防ぐ)。フックが残したセッション cwd のファイルも消し、
      # シェルに戻ったペインの分割先や space 名がセッションの移動先に引きずられないようにする。
      claude() {
        _herdr_name_by_cwd
        command claude --settings ~/.config/herdr/claude-settings.json "$@"
        local ret=$?
        herdr agent rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1
        rm -f "${claudeCwdDir}/$HERDR_PANE_ID"
        _herdr_label=""
        return $ret
      }
    elif [[ -n "$HERDR_ENV" ]]; then
      # HERDR_ENV はあるが HERDR_PANE_ID が無い = ポップアップ(Alt-;)のシェル。
      # ポップアップは pane 同一性を持たないので herdr 側が HERDR_PANE_ID だけを env から
      # 取り除く。この差分がポップアップ判定になる。
      #
      # 閉じるキーを herdr の config.toml 側に置けない理由: ポップアップが開いている間、
      # herdr はキーバインド照合より前に全キーをポップアップの PTY へ素通しする
      # (handle_key が popup_pane を最初に見て handle_terminal_key へ抜ける)。prefix すら
      # 発火しないため、閉じるキーは「受け取る側」であるこのシェルに置くしかない。
      # socket API の popup.close を直接叩く(params は空)。herdr CLI に popup サブコマンドは
      # 無いので、focus-role.sh の pane.focus と同じく socat で直に投げる。
      #
      # 制約: zle ウィジェットなので zsh のプロンプトにいるときだけ効く。ポップアップ内で
      # vim や lazygit が動いていればキーはそちらに食われる。素のシェルなら Ctrl-D でも
      # 閉じられるので、これはあくまで代替キー。
      _herdr_close_popup() {
        local socket="''${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock}"
        printf '{"id":"close-popup","method":"popup.close","params":{}}\n' \
          | ${pkgs.socat}/bin/socat - UNIX-CONNECT:"$socket" >/dev/null 2>&1
      }
      zle -N _herdr_close_popup
      bindkey "\e'" _herdr_close_popup
    fi
  '';
}
