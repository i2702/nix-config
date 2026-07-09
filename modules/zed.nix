{ ... }:
{
  # Zed 本体は GUI アプリのため nix では管理せず(/Applications/Zed.app、CLI は
  # modules/zsh.nix の z / za エイリアス経由)、設定ファイルの配置のみ行う。
  #
  # 設定の出所: ベースは ~/Repository/github.com/i2702/zedzed リポジトリ
  # (settings.json / keymap.json)。zedzed 自体は nix 管理しない(別マシンと共有する
  # 生きたリポジトリなので、ここへ内容を取り込むだけ)。それに Mac/herdr 固有の追加
  # (下記コメント参照)を重ねたものがこのモジュールの内容。設定変更はこのファイルを編集して
  # home-manager switch で反映する(nix 管理の読み取り専用シンボリックリンクになるため、
  # Zed の設定 UI からの書き込みは反映されない点に注意)。

  xdg.configFile."zed/settings.json".text = ''
    // Zed settings
    //
    // For information on how to configure Zed, see the Zed
    // documentation: https://zed.dev/docs/configuring-zed
    //
    // To see all of Zed's default settings without changing your
    // custom settings, run `zed: open default settings` from the
    // command palette (cmd-shift-p / ctrl-shift-p)
    {
      // [Mac 固有] macOS のネイティブなウィンドウタブを使う
      "use_system_window_tabs": true,
      "minimap": {
        "show": "auto"
      },
      // タブをプレビュー(テンポラリ)で開かず、常に通常タブとして開く
      "preview_tabs": {
        "enabled": false
      },
      "cli_default_open_behavior": "existing_window",
      "project_panel": {
        "dock": "right"
      },
      "outline_panel": {
        "dock": "right"
      },
      "collaboration_panel": {
        "dock": "right"
      },
      "agent": {
        "dock": "left",
        "favorite_models": [],
        "model_parameters": []
      },
      "git_panel": {
        "dock": "right"
      },
      "wsl_connections": [
        {
          "distro_name": "Ubuntu",
          "user": null,
          "projects": [
            {
              "paths": [
                "/home/m1205062"
              ]
            },
            {
              "paths": [
                "/home/m1205062/metronome"
              ]
            }
          ]
        }
      ],
      "icon_theme": "Catppuccin Mocha",
      "session": {
        "trust_all_worktrees": true
      },
      "vim_mode": true,
      "git": {
        "inline_blame": {
          "enabled": true
        }
      },
      "base_keymap": "VSCode",
      "search": {
        "include_ignored": true
      },
      "use_smartcase_search": true,
      "current_line_highlight": "all",
      "cursor_blink": true,
      "autosave": "on_focus_change",
      // [Mac/herdr 固有] Zed 内蔵ターミナルと herdr の統合
      "terminal": {
        // Option(Alt)キーをメタキーとして送出し、herdr等のAltショートカットを効かせる
        "option_as_meta": true,
        // Zedのターミナルでは"zed"という名前付きセッションのherdrにアタッチする。
        // Ghostty(defaultセッション)とはspace/ペイン/agents一覧が完全に分離され、
        // 両方を同時に開いても表示が同期しなくなる。config.tomlは全セッション共通なので
        // キーバインドやスクリプトはそのまま効く。
        "env": {
          "HERDR_SESSION": "zed"
        }
      },
      "buffer_font_family": "HackGen Console NF",
      "hard_tabs": false,
      "tab_size": 2,
      "ui_font_size": 16,
      "buffer_font_size": 16.0,
      "theme": {
        "mode": "system",
        "light": "Ayu Light",
        "dark": "Catppuccin Mocha",
      },
    }
  '';

  xdg.configFile."zed/keymap.json".text = ''
    // Zed keymap
    //
    // For information on binding keys, see the Zed
    // documentation: https://zed.dev/docs/key-bindings
    //
    // To see the default key bindings run `zed: open default keymap`
    // from the command palette.
    [
      {
        "context": "Workspace && !ProjectPanel",
        "bindings": {
          "alt-p": "project_panel::ToggleFocus"
        }
      },
      {
        "context": "Editor && vim_mode == insert",
        "bindings": {
          // "j k": "vim::NormalBefore"
          "ctrl-v": "editor::Paste"
        }
      },
      {
        "context": "Pane",
        "bindings": {
          "alt-w": "pane::CloseActiveItem"
        }
      },
      {
        // Cmd-P/Cmd-Shift-P で開くパレットを Ctrl-P/Ctrl-Shift-P でも開く
        // (ctrl-p=ファイルファインダー、ctrl-shift-p=コマンドパレット)
        "bindings": {
          "ctrl-p": "file_finder::Toggle",
          "ctrl-shift-p": "command_palette::Toggle"
        }
      },
      // 各種フォーカス
      {
        "bindings": {
          "ctrl-alt-e": "editor::ToggleFocus",
          "ctrl-alt-a": "agent::ToggleFocus",
          "ctrl-alt-p": "project_panel::ToggleFocus",
          "ctrl-alt-o": "outline_panel::ToggleFocus",
          "ctrl-alt-g": "git_panel::ToggleFocus",
          "ctrl-alt-c": "collab_panel::ToggleFocus",
          "ctrl-alt-t": "terminal_panel::Toggle",
          // プロジェクト全体を対象とした検索(VSCode の Find in Files 相当)
          "ctrl-alt-f": "pane::DeploySearch"
        }
      },
      {
        // ctrl-j のボトムドック(ターミナル)トグルを無効化
        "context": "Workspace",
        "bindings": {
          "ctrl-j": null
        }
      },
      {
        // editor のタブ移動: ctrl-tab で右隣、ctrl-shift-tab で左隣
        "context": "Editor",
        "bindings": {
          "ctrl-tab": "pane::ActivateNextItem",
          "ctrl-shift-tab": "pane::ActivatePreviousItem"
        }
      },
      {
        // ホバーを起動する
        "context": "Editor",
        "bindings": {
          "ctrl-,": "editor::Hover"
        }
      },
      {
        // すべての参照を検索
        "context": "Editor",
        "bindings": {
          "g r": "editor::FindAllReferences"
        }
      },
      {
        // g r で開いた references(multibuffer)から、選択中の excerpt(ファイル)を開く。
        // 既定の g space に加えて g o でも開けるようにする。
        "context": "VimControl && !menu",
        "bindings": {
          "g o": "editor::OpenExcerpts"
        }
      },
      {
        // [Mac/herdr 固有] ターミナル内では Alt 系をすべて素通りさせ、herdr に届ける
        // (settings.json の terminal.option_as_meta=true と併用)
        "context": "Terminal",
        "bindings": {
          "alt-a": null, "alt-b": null, "alt-c": null, "alt-d": null,
          "alt-e": null, "alt-f": null, "alt-g": null, "alt-h": null,
          "alt-i": null, "alt-j": null, "alt-k": null, "alt-l": null,
          "alt-m": null, "alt-n": null, "alt-o": null, "alt-p": null,
          "alt-q": null, "alt-r": null, "alt-s": null, "alt-t": null,
          "alt-u": null, "alt-v": null, "alt-w": null, "alt-x": null,
          "alt-y": null, "alt-z": null,
          "alt-up": null, "alt-down": null, "alt-left": null, "alt-right": null
        }
      }
    ]
  '';
}
