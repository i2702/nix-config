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
          # osascript 自体が失敗した場合 (補助アクセス未許可の -25211 など) は msg が空になる。
          # 握り潰すと「押しても何も起きない」だけになって原因が判らないので、終了コードを
          # そのまま返して Raycast にエラーとして出させる (メッセージは osascript の stderr)。
          msg=$(osascript <<'APPLESCRIPT'
          on run
            tell application "System Events"
              -- Why not (全プロセスを舐めない理由): 元にした版は background only でない
              -- プロセス全部のウィンドウを見ていたが、(1) System Events の AX 問い合わせは
              -- 1ウィンドウずつ IPC が走るので数秒かかり、ホットキーの応答としては遅すぎる、
              -- (2) "Mac" / "Win" はブラウザのタブ名にも普通に現れるため、Ghostty より先に
              -- 見つかった無関係なウィンドウを前面に出してしまう。探す先は Ghostty に限る。
              --
              -- プロセス名は実測で小文字の "ghostty" (.app 内の実行ファイル名)。
              -- AppleScript の文字列比較は既定で大文字小文字を区別しないので、将来
              -- "Ghostty" に変わってもこのまま通る。
              if not (exists application process "ghostty") then
                return "ghostty が起動していません"
              end if

              tell application process "ghostty"
                repeat with w in windows
                  if name of w contains "${match}" then
                    -- AXRaise と frontmost の両方が要る。AXRaise はアプリ内での重なり順を
                    -- 上げるだけでアプリ自体は前に出ず、frontmost はアプリを前に出すだけで
                    -- どのウィンドウが最前面かは選べない。2つ揃って初めて
                    -- 「目的のウィンドウが最前面」になる。
                    perform action "AXRaise" of w
                    set frontmost to true
                    return ""
                  end if
                end repeat
              end tell
            end tell
            return "タイトルに \"${match}\" を含む Ghostty のウィンドウがありません"
          end run
          APPLESCRIPT
          ) || exit $?

          if [[ -n "$msg" ]]; then
            echo "$msg"
          fi
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
