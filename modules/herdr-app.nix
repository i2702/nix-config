{ config, pkgs, lib, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # 置き場所。Mac は ~/.config/herdr-app。Windows 版は %USERPROFILE%\.config\herdr-app を読み、
  # WSL 側の ~/.config は見ないため、WSL(= Linux)では Windows のパスへ直接書き出す
  # (modules/wezterm.nix と同じ理由・同じやり方)。
  winHome = "/mnt/c/Users/m1205";
  appHome = if isDarwin then "${config.xdg.configHome}/herdr-app" else "${winHome}/.config/herdr-app";

  # 制御文字1つの文字列。Nix の文字列リテラルは \u エスケープを解釈しないため JSON 経由で作る。
  ctrl = code: builtins.fromJSON ''"\u${code}"'';

  # 1〜9 の数字キーを並べる。f は数字の文字列を受け取って { キー = 動作; } を返す。
  digitKeys = f: lib.foldl' (acc: n: acc // f (toString n)) { } (lib.range 1 9);

  # キー割り当て(https://herdr.dev のアプリ内ガイド ~/.config/herdr-app/AGENTS.md「Keys」)。
  # OS ごとにアプリが初回起動時に書き出した既定値をそのまま持ち、その上に旧 herdr
  # (modules/herdr.nix)の Alt 系(herdrKeys、OS 共通)を重ねる。既定値ごと持つ理由: keys.json は
  # 既定値への差分ではなくキー割り当ての全体として読まれ、書かなかった既定キー(cmd-c など)が
  # 消えるおそれがあるため。既定値が OS で違う(Mac は cmd、Windows は ctrl-shift が主)ので分ける。
  #
  # 旧 herdr から移していないもの(Why not):
  #   - prefix(Alt-t)系: herdr-app にプレフィックスキーの仕組みが無い。方向指定の分割は既定の
  #     cmd-d / cmd-shift-d(Windows は ctrl-shift-o / ctrl-shift-e)を使う
  #   - Alt-e シェルペイン巡回 / Alt-; ポップアップ: 相当するコマンドが無く、
  #     mod(JS)で作る必要があるため今回は見送った
  #   - Alt-r 設定リロード / Alt-d デタッチ / Alt-c コピーモード: ファイルは保存で即時反映され、
  #     ウィンドウを閉じても端末は herdr-core に残り、選択はマウスでできるので不要
  macDefaultKeys = {
    global = {
      "cmd-q" = "app.quit";
      "cmd-h" = "app.hide";
      "cmd-alt-h" = "app.hide_others";
      "cmd-t" = "tab.new";
      "cmd-w" = "tab.close";
      "ctrl-tab" = "tab.next";
      "ctrl-shift-tab" = "tab.prev";
      "cmd-shift-]" = "tab.next";
      "cmd-shift-[" = "tab.prev";
      "cmd-alt-]" = "space.next";
      "cmd-alt-[" = "space.prev";
      "cmd-]" = "agent.next";
      "cmd-[" = "agent.prev";
      "cmd-shift-l" = "layout.switch";
      "cmd-n" = "space.new";
      "cmd-p" = "mod.open:picker";
      "cmd-shift-p" = "app.palette";
      "cmd-," = "app.settings";
      "cmd-d" = "pane.split:right";
      "cmd-shift-d" = "pane.split:down";
      "cmd-shift-w" = "pane.close";
      "cmd-shift-enter" = "pane.zoom";
      "cmd-alt-left" = "pane.go:left";
      "cmd-alt-right" = "pane.go:right";
      "cmd-alt-up" = "pane.go:up";
      "cmd-alt-down" = "pane.go:down";
      "cmd-alt-shift-left" = "pane.swap:left";
      "cmd-alt-shift-right" = "pane.swap:right";
      "cmd-alt-shift-up" = "pane.swap:up";
      "cmd-alt-shift-down" = "pane.swap:down";
      "f2" = "tab.rename";
      "shift-f2" = "space.rename";
      "cmd-/" = "app.help";
      "cmd-shift-/" = "app.help";
      "cmd-b" = "layout.toggle:sidebar";
      "cmd-=" = "app.zoom_in";
      "cmd-+" = "app.zoom_in";
      "cmd--" = "app.zoom_out";
      "cmd-0" = "app.zoom_reset";
    }
    # Cmd-1〜9 = タブ選択 / Ctrl-1〜9 = space 選択
    // digitKeys (i: {
      "cmd-${i}" = "tab.select:${i}";
      "ctrl-${i}" = "space.select:${i}";
    });

    terminal = {
      "cmd-c" = "terminal.copy";
      "cmd-v" = "terminal.paste";
      "ctrl-v" = "terminal.paste_image";
      "alt-backspace" = "send:${ctrl "0017"}";
      "alt-left" = "send:${ctrl "001b"}b";
      "alt-right" = "send:${ctrl "001b"}f";
      "cmd-left" = "send:${ctrl "0001"}";
      "cmd-right" = "send:${ctrl "0005"}";
      "cmd-backspace" = "send:${ctrl "0015"}";
    };
  };

  # Windows 版の既定値。Alt-h/j/k/l のペイン移動や Alt-1〜9 の space 選択は既定で入っている。
  windowsDefaultKeys = {
    global = {
      "alt-h" = "pane.go:left";
      "alt-j" = "pane.go:down";
      "alt-k" = "pane.go:up";
      "alt-l" = "pane.go:right";
      "alt-left" = "pane.go:left";
      "alt-right" = "pane.go:right";
      "alt-shift-h" = "pane.swap:left";
      "alt-shift-j" = "pane.swap:down";
      "alt-shift-k" = "pane.swap:up";
      "alt-shift-l" = "pane.swap:right";
      "ctrl-+" = "app.zoom_in";
      "ctrl--" = "app.zoom_out";
      "ctrl-0" = "app.zoom_reset";
      "ctrl-=" = "app.zoom_in";
      "ctrl-pagedown" = "tab.next";
      "ctrl-pageup" = "tab.prev";
      "ctrl-tab" = "tab.next";
      "ctrl-shift-tab" = "tab.prev";
      "alt-]" = "tab.next";
      "alt-[" = "tab.prev";
      "ctrl-shift-pagedown" = "space.next";
      "ctrl-shift-pageup" = "space.prev";
      "alt-down" = "agent.next";
      "alt-up" = "agent.prev";
      "ctrl-shift-/" = "app.help";
      "ctrl-shift-?" = "app.help";
      "ctrl-shift-b" = "layout.toggle:sidebar";
      "ctrl-shift-n" = "space.new";
      "ctrl-shift-t" = "tab.new";
      "ctrl-shift-k" = "mod.open:picker";
      "ctrl-shift-p" = "app.palette";
      "ctrl-," = "app.settings";
      "ctrl-shift-o" = "pane.split:right";
      "ctrl-shift-e" = "pane.split:down";
      "ctrl-shift-w" = "tab.close";
      "ctrl-shift-x" = "pane.close";
      "ctrl-shift-z" = "pane.zoom";
      "ctrl-shift-l" = "layout.switch";
      "f2" = "tab.rename";
      "shift-f2" = "space.rename";
    }
    # Ctrl-1〜9 = タブ選択 / Alt-1〜9 = space 選択
    // digitKeys (i: {
      "ctrl-${i}" = "tab.select:${i}";
      "alt-${i}" = "space.select:${i}";
    });

    terminal = {
      "ctrl-backspace" = "send:${ctrl "0017"}";
      "ctrl-left" = "send:${ctrl "001b"}b";
      "ctrl-right" = "send:${ctrl "001b"}f";
      "ctrl-shift-c" = "terminal.copy";
      "ctrl-shift-v" = "terminal.paste";
      "ctrl-v" = "terminal.paste_image";
    };
  };

  # 旧 herdr の Alt 系(OS 共通)。Mac で Alt を使うには settings の option_as_alt が要る(下記)。
  herdrKeys = {
    global = {
      # Alt-h/j/k/l でペイン移動
      "alt-h" = "pane.go:left";
      "alt-j" = "pane.go:down";
      "alt-k" = "pane.go:up";
      "alt-l" = "pane.go:right";

      # Alt-q でペインを閉じる。最後のペインで space ごと消えるときも確認ダイアログを出さない
      # (pane.close に confirmed が無いので mod 経由。close-pane 参照)
      "alt-q" = "mod.open:close-pane";

      # Alt-m で space 名変更(引数なしなのでアプリが名前を尋ねる)
      "alt-m" = "space.rename";

      # space 操作。旧 herdr と同じく Alt-n で作成、Alt-o/p で前後、Alt-w で閉じる。
      # Alt-n は表示中の space と同じマシンに作る(space.new に machine を渡すため mod 経由。new-space 参照)。
      # 旧 herdr の new-space.sh がしていた「アクティブ space の直下に作る」は再現していない
      # (space.new は末尾に足す。直下へ移すには作成後に space.move を呼ぶ mod が要る)。
      "alt-n" = "mod.open:new-space";
      "alt-p" = "space.next";
      "alt-o" = "space.prev";
      # Alt-w は確認ダイアログ無しで閉じる(space.close の confirmed を渡すため mod 経由。close-space 参照)
      "alt-w" = "mod.open:close-space";

      # Alt-a / Alt-Shift-a でエージェントを全 space 横断で巡回する。旧 herdr では focus-role.sh で
      # 自作していたが、herdr-app は agent.next / agent.prev をネイティブに持つ。
      "alt-a" = "agent.next";
      "alt-shift-a" = "agent.prev";

      # Alt-s で自動タイル分割(2x2 グリッドへ割っていく)。旧 herdr の split-pane.sh auto を
      # mod(herdr-app/autotile)に移したもの。判定の詳細は同 mod のコメント参照。
      "alt-s" = "mod.open:autotile";
    }
    # Alt-1〜9 は旧 herdr と同じく space 選択
    // digitKeys (i: { "alt-${i}" = "space.select:${i}"; });

    # Alt-←/→ は旧 herdr と同じく space の前後移動にする。terminal 節は global 節より優先されるので、
    # アプリ既定(Mac は terminal 節の単語移動 send:\eb / \ef、Windows は global 節のペイン移動)を
    # ここで置き換える。
    terminal = {
      "alt-left" = "space.prev";
      "alt-right" = "space.next";
    };
  };

  defaultKeys = if isDarwin then macDefaultKeys else windowsDefaultKeys;
  keys = {
    global = defaultKeys.global // herdrKeys.global;
    terminal = defaultKeys.terminal // herdrKeys.terminal;
  };

  # 本人の設定(AGENTS.md「The person: settings.json」)。zoom / sounds / minimum_contrast /
  # appearance はアプリが初回起動時に書いた値(zoom は OS ごとに違う値が書かれた)。
  settings = {
    zoom = if isDarwin then 1 else 1.2;
    sounds.enabled = true;
    minimum_contrast = 1;
    appearance = "dark";
    # 旧 herdr の [theme.custom] accent と同じオレンジ
    colors.accent = "#ffaf00";
    # ターミナルのフォント。Ghostty(modules/ghostty.nix)/ WezTerm(modules/wezterm.nix)と同じ HackGen Console NF
    font = "HackGen Console NF";
  } // lib.optionalAttrs isDarwin {
    # Option を常に Alt として送る。既定の "auto" は US / ABC 配列のときだけ Alt 扱いにし、
    # ATOK などの入力ソースでは Option が文字入力に使われて上の Alt 系キーが届かない。
    # Mac 専用の設定(Linux / Windows では無視される)。
    option_as_alt = "on";
  };

  # modules/herdr-app/<名前>/ に置いた自作 mod。
  # spaces-remote(This computer を出さない spaces の複製)と、それを使う layouts/main-remote.json は
  # Windows だけに置く。Mac は手元で作業するので This computer を消さない。
  # 表示するレイアウトの選択はアプリが shared.json に書く状態なので nix では持たない
  # (新しい Windows 機では一度 `herdr-app do layout.switch --name main-remote` する)。
  mods = [ "autotile" "close-space" "close-pane" "new-space" ]
    ++ lib.optionals (!isDarwin) [ "spaces-remote" ];
  layouts = lib.optionals (!isDarwin) [ "main-remote" ];

  keysFile = pkgs.writeText "herdr-app-keys.json" (builtins.toJSON keys);
  settingsFile = pkgs.writeText "herdr-app-settings.json" (builtins.toJSON settings);
in
{
  # herdr-app: herdr のデスクトップアプリ版(旧 herdr = TUI とは別物。modules/herdr.nix とは独立)。
  # 本体は公式インストーラで入れたアプリで(Mac の ~/.local/bin/herdr-app はアプリ自身が張るリンク)、
  # 自動更新もアプリに任せるため nix ではパッケージを入れない。Mac と Windows(WSL から書き出す)で使っている。
  #
  # 設定ファイルは xdg.configFile の読み取り専用シンボリックリンクにせず、activation で書き込み可能な
  # コピーとして置く。理由: アプリは設定画面から settings.json を書き換え、escape hatch
  # (ctrl-alt-shift-escape)では keys.json を退避する。読み取り専用だとこれらが失敗する。
  # Windows 側はそもそも nix store への symlink を辿れない。
  # 正本はこのモジュールなので、アプリ側で変えた値は次の hms で上書きされる。残したい変更はここへ移す。
  # 自作 mod も同じくコピーで置く。アプリが mod のフォルダへ jsconfig.json と型定義を書き込むため。
  #
  # WSL では Windows 側のホームが無い(マウントされていない)ときは何もしない。
  home.activation.herdrAppConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (''
    if [ -d "${if isDarwin then config.home.homeDirectory else winHome}" ]; then
      run mkdir -p "${appHome}"
      run install -m 644 ${keysFile} "${appHome}/keys.json"
      run install -m 644 ${settingsFile} "${appHome}/settings.json"
  '' + lib.concatMapStrings
    (mod: ''
      run mkdir -p "${appHome}/mods/${mod}"
      run install -m 644 ${./herdr-app/${mod}/main.js} "${appHome}/mods/${mod}/main.js"
      run install -m 644 ${./herdr-app/${mod}/mod.json} "${appHome}/mods/${mod}/mod.json"
    '')
    mods + lib.concatMapStrings
    (layout: ''
      run mkdir -p "${appHome}/layouts"
      run install -m 644 ${./herdr-app/layouts/${layout}.json} "${appHome}/layouts/${layout}.json"
    '')
    layouts + ''
    fi
  '');
}
