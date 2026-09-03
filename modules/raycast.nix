{ pkgs, ... }:
let
  # ウィンドウタイトルで Ghostty のウィンドウを探して前面に出す Raycast Script Command。
  #
  # home.nix ではなく hosts/mac.nix からのみ import する。Raycast は macOS 専用アプリで
  # あり、探す相手のタイトル (" Mac" / "󰖳 Win") を書いているのも modules/zsh.nix の
  # Darwin 分岐だけなので、Linux 側へ持ち込んでも指す対象が無い。
  # stdenv.isDarwin でガードせず import 元で分けるのは m1ddc.nix / controlmymonitor.nix と
  # 同じ方針 (どのホストに入るかを条件式ではなく import 関係で追えるようにする)。
  #
  # 前提: ウィンドウタイトルは modules/zsh.nix が出している。ローカル作業中は " Mac"、
  # Windows 機へ ssh している間は "󰖳 Win"。つまり「タイトルが Win のウィンドウ」は
  # 「今 Windows 機に繋がっているペインを含む Ghostty ウィンドウ」と同義になる。
  #
  # Why not (System Events 経由にしない理由): 元にした版は System Events で全プロセスの
  # ウィンドウを舐めて AXRaise していた。これは Accessibility API なので Raycast に
  # 補助アクセスの許可が要り、さらに System Events へ Apple Events を送る Automation の
  # 許可も別途要る (実測: 後者が無いと -1743 で落ちる)。2種類の権限を GUI で通す手間の
  # わりに、Raycast から起動された osascript にどちらが帰属するかも読みにくい。
  # Ghostty 1.3.1 は自前の AppleScript 辞書 (Ghostty.app/Contents/Resources/Ghostty.sdef)
  # を持ち、window の name と `activate window` コマンドを公開している。こちらなら
  # 必要なのは「Raycast → Ghostty」の Automation 1つだけで、初回実行時に macOS が
  # 自動でダイアログを出す。補助アクセスは一切要らない。
  #
  # Why not (引数つきの1コマンドにしない理由): Raycast の Script Command は引数を取れるが、
  # ホットキーを割り当てても引数の入力欄が開くだけで、そこから Mac / Win を打たされる。
  # 欲しいのは「ホットキー一発で目的のウィンドウへ飛ぶ」ことなので、行き先ごとに
  # 引数なしのコマンドを生やす。行き先を増やすときは下の targets に1行足す。
  focusCommand =
    {
      file,
      title,
      icon,
      match,
    }:
    {
      name = "raycast/scripts/${file}";
      value = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          # このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
          # 変更は ~/nix-config/modules/raycast.nix を編集して home-manager switch する。

          # @raycast.schemaVersion 1
          # @raycast.title ${title}
          # @raycast.mode silent
          # @raycast.packageName Window
          # @raycast.icon ${icon}
          # @raycast.description タイトルに "${match}" を含む Ghostty のウィンドウを前面に出す

          # 失敗したときだけ喋る。mode silent の Raycast は stdout の最終行を HUD に出すので、
          # 成功時に何か書くと毎回トーストが出て邪魔になる。
          #
          # stderr も stdout へ混ぜるのは、AppleScript の実行時エラーを osascript が stderr へ
          # 書くため。捨てると「押しても何も起きない」になって原因が辿れない。成功時の
          # osascript は stdout / stderr とも空なので、混ぜても成功時に喋ることはない。
          msg=$(osascript 2>&1 <<'APPLESCRIPT'
          on run
            -- `tell application "Ghostty"` の中で windows を触ると、Ghostty が居なければ
            -- 起動してしまう。このコマンドの目的は「既にあるウィンドウへ飛ぶ」ことなので、
            -- 勝手に起動させず先に弾く。`is running` は起動を伴わずに読める。
            if not (application "Ghostty" is running) then
              return "Ghostty が起動していません"
            end if

            try
              tell application "Ghostty"
                repeat with w in windows
                  if name of w contains "${match}" then
                    -- Why not (activate window 単独で済ませない理由): Ghostty.sdef の
                    -- activate window は "bringing it to the front" を謳うが、Ghostty が背面に
                    -- いる状態で呼ぶとアプリは前に出るもののウィンドウは直前に使っていた
                    -- ものが選ばれ、目的のウィンドウには2回目の呼び出しでやっと届く
                    -- (実測: Finder を前に出してから呼ぶと front window が変わらない。
                    -- Ghostty が既に前面なら1回で切り替わる)。
                    -- アプリの活性化がウィンドウの選択より後に完了し、その時点で活性化前の
                    -- キーウィンドウが復元されて選択を上書きしていると見られる。
                    -- 先にアプリを活性化して frontmost を確かめてから window を選ぶと一度で
                    -- 届く (実測)。待ちループは実測では 0 周で抜けるが、活性化が遅れた場合の
                    -- 保険として残す。
                    activate
                    repeat 20 times
                      if frontmost then exit repeat
                      delay 0.05
                    end repeat
                    activate window w
                    return ""
                  end if
                end repeat
              end tell
            on error errText number errNum
              -- -1743 は Apple Events の送信が許可されていない (Automation 未許可)。
              -- osascript の素のエラーは文字オフセットと定型文だけで、どの設定画面を
              -- 開けばよいかが伝わらないので、ここで直し方に書き換える。
              if errNum is -1743 then
                return "Raycast から Ghostty へ Apple Events を送る許可がありません。システム設定 → プライバシーとセキュリティ → オートメーション → Raycast → Ghostty を ON にしてください"
              end if
              return errText & " (" & errNum & ")"
            end try

            return "タイトルに \"${match}\" を含む Ghostty のウィンドウがありません"
          end run
          APPLESCRIPT
          )
          rc=$?

          # 切り分け用のログ。成功時は書かない (modules/wezterm.nix の wezterm-focus.log と
          # 同じ方針で、失敗の切り分けのためだけに残す)。
          #
          # $0 を残すのが肝。nix の生成物は switch のたびに store パスが変わるので、
          # Raycast がディレクトリ走査時に symlink を解決して realpath を握っていると、
          # 更新しても古い版を実行し続ける。そのときここには古い store パスが出る。
          # ログ行がそもそも増えないなら、ログを書かない更に古い版が動いている。
          if [[ $rc -ne 0 || -n "$msg" ]]; then
            mkdir -p "$HOME/.cache"
            printf '%s  rc=%s  %s  %s\n' "$(date '+%F %T')" "$rc" "$0" "$msg" >> "$HOME/.cache/raycast-focus-window.log"
          fi

          if [[ -n "$msg" ]]; then
            echo "$msg"
          fi
          exit $rc
        '';
      };
    };

  targets = [
    {
      file = "focus-mac-window.sh";
      title = "Focus Mac Window";
      icon = "🍎";
      match = "Mac";
    }
    {
      file = "focus-win-window.sh";
      title = "Focus Win Window";
      icon = "🪟";
      match = "Win";
    }
  ];
in
{
  # 置き場所は ~/.config/raycast/scripts/。Raycast は決め打ちのディレクトリを見に行くのでは
  # なく、設定で登録されたディレクトリだけを走査する。登録は GUI からしか出来ず nix では
  # 宣言できないので、新しいマシンでは一度だけ手で行う (手順は MANUAL.md)。
  xdg.configFile = builtins.listToAttrs (map focusCommand targets);
}
