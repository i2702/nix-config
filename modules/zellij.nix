{ pkgs, ... }:
{
  home.packages = [ pkgs.zellij ];

  xdg.configFile."zellij/config.kdl".text = ''
    // Zellij設定ファイル
    // tmux風のキーバインドとスタイリング

    // テーマ設定
    theme "custom"
    themes {
        custom {
            fg "#d4d4d4"
            bg "#1e1e1e"
            black "#000000"
            red "#cd3131"
            green "#0dbc79"
            yellow "#e5e510"
            blue "#2472c8"
            magenta "#bc3fbc"
            cyan "#11a8cd"
            white "#e5e5e5"
            orange "#ce9178"
        }
    }

    // 一般設定
    pane_frames false
    default_layout "default"
    mouse_mode true
    copy_on_select true
    scrollback_editor "vim"
    mirror_session false

    // UI設定
    ui {
        pane_frames {
            rounded_corners false
        }
    }

    // キーバインド設定(tmux風Alt中心)
    keybinds clear-defaults=true {
        // ロックモード(デフォルト)
        locked {
            bind "Alt g" { SwitchToMode "Normal"; }
        }

        // ノーマルモード
        normal {
            // モード切替
            bind "Alt g" { SwitchToMode "Locked"; }
            bind "Alt c" { SwitchToMode "Scroll"; }
            bind "Alt m" { SwitchToMode "RenameTab"; }
            bind "Alt r" { SwitchToMode "Resize"; }
            bind "Alt p" { SwitchToMode "Pane"; }
            bind "Alt t" { SwitchToMode "Tab"; }
            bind "Alt s" { SwitchToMode "Session"; }
            bind "Alt o" { SwitchToMode "Move"; }

            // ペイン操作(Alt-hjkl)
            bind "Alt h" { MoveFocus "Left"; }
            bind "Alt j" { MoveFocus "Down"; }
            bind "Alt k" { MoveFocus "Up"; }
            bind "Alt l" { MoveFocus "Right"; }

            // ペイン分割
            bind "Alt v" { NewPane "Right"; }
            bind "Alt V" { NewPane "Right"; SwitchToMode "Locked"; }
            bind "Alt s" { NewPane "Down"; }
            bind "Alt S" { NewPane "Down"; SwitchToMode "Locked"; }

            // ペイン閉じる
            bind "Alt q" { CloseFocus; }

            // 4分割レイアウト
            bind "Alt 4" {
                NewPane "Right"
                NewPane "Down"
                MoveFocus "Left"
                NewPane "Down"
            }

            // タブ操作
            bind "Alt n" { NewTab; }
            bind "Alt w" { CloseTab; }
            bind "Alt Left" { GoToPreviousTab; }
            bind "Alt Right" { GoToNextTab; }
            bind "Alt p" { GoToPreviousTab; }
            bind "Alt o" { GoToNextTab; }

            // タブ直接選択
            bind "Alt 1" { GoToTab 1; }
            bind "Alt 2" { GoToTab 2; }
            bind "Alt 3" { GoToTab 3; }
            bind "Alt 5" { GoToTab 5; }
            bind "Alt 6" { GoToTab 6; }
            bind "Alt 7" { GoToTab 7; }
            bind "Alt 8" { GoToTab 8; }
            bind "Alt 9" { GoToTab 9; }

            // デタッチ
            bind "Alt d" { Detach; }

            // 検索
            bind "Ctrl s" { SwitchToMode "EnterSearch"; SearchInput 0; }

            // 終了
            bind "Ctrl q" { Quit; }
        }

        // スクロール/コピーモード
        scroll {
            bind "Alt c" { SwitchToMode "Normal"; }
            bind "Esc" { SwitchToMode "Normal"; }
            bind "q" { SwitchToMode "Normal"; }
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
            bind "Ctrl f" "PageDown" { PageScrollDown; }
            bind "Ctrl b" "PageUp" { PageScrollUp; }
            bind "d" { HalfPageScrollDown; }
            bind "u" { HalfPageScrollUp; }
            bind "g" { ScrollToTop; }
            bind "G" { ScrollToBottom; }
            bind "s" { Search "down"; }
            bind "S" { Search "up"; }
        }

        // 検索入力モード
        entersearch {
            bind "Esc" { SwitchToMode "Normal"; }
            bind "Enter" { SwitchToMode "Search"; }
        }

        // 検索結果ナビゲーションモード
        search {
            bind "Esc" { SwitchToMode "Normal"; }
            bind "Ctrl s" { SwitchToMode "Normal"; }
            bind "n" { Search "down"; }
            bind "N" { Search "up"; }
            bind "j" "Down" { ScrollDown; }
            bind "k" "Up" { ScrollUp; }
        }

        // リサイズモード
        resize {
            bind "Esc" "Enter" { SwitchToMode "Normal"; }
            bind "h" "Left" { Resize "Increase Left"; }
            bind "j" "Down" { Resize "Increase Down"; }
            bind "k" "Up" { Resize "Increase Up"; }
            bind "l" "Right" { Resize "Increase Right"; }
            bind "H" { Resize "Decrease Left"; }
            bind "J" { Resize "Decrease Down"; }
            bind "K" { Resize "Decrease Up"; }
            bind "L" { Resize "Decrease Right"; }
        }

        // ペインモード
        pane {
            bind "Esc" "Enter" { SwitchToMode "Normal"; }
            bind "h" "Left" { MoveFocus "Left"; }
            bind "j" "Down" { MoveFocus "Down"; }
            bind "k" "Up" { MoveFocus "Up"; }
            bind "l" "Right" { MoveFocus "Right"; }
            bind "v" { NewPane "Right"; SwitchToMode "Normal"; }
            bind "s" { NewPane "Down"; SwitchToMode "Normal"; }
            bind "x" { CloseFocus; SwitchToMode "Normal"; }
            bind "f" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
            bind "z" { TogglePaneFrames; SwitchToMode "Normal"; }
            bind "w" { ToggleFloatingPanes; SwitchToMode "Normal"; }
        }

        // タブモード
        tab {
            bind "Esc" "Enter" { SwitchToMode "Normal"; }
            bind "h" "Left" { GoToPreviousTab; }
            bind "l" "Right" { GoToNextTab; }
            bind "n" { NewTab; SwitchToMode "Normal"; }
            bind "x" { CloseTab; SwitchToMode "Normal"; }
            bind "r" { SwitchToMode "RenameTab"; }
            bind "1" { GoToTab 1; SwitchToMode "Normal"; }
            bind "2" { GoToTab 2; SwitchToMode "Normal"; }
            bind "3" { GoToTab 3; SwitchToMode "Normal"; }
            bind "4" { GoToTab 4; SwitchToMode "Normal"; }
            bind "5" { GoToTab 5; SwitchToMode "Normal"; }
            bind "6" { GoToTab 6; SwitchToMode "Normal"; }
            bind "7" { GoToTab 7; SwitchToMode "Normal"; }
            bind "8" { GoToTab 8; SwitchToMode "Normal"; }
            bind "9" { GoToTab 9; SwitchToMode "Normal"; }
        }

        // タブ名変更モード
        renametab {
            bind "Esc" { UndoRenameTab; SwitchToMode "Normal"; }
            bind "Enter" { SwitchToMode "Normal"; }
        }

        // セッションモード
        session {
            bind "Esc" "Enter" { SwitchToMode "Normal"; }
            bind "d" { Detach; }
        }

        // 移動モード
        move {
            bind "Esc" "Enter" { SwitchToMode "Normal"; }
            bind "h" "Left" { MovePane "Left"; }
            bind "j" "Down" { MovePane "Down"; }
            bind "k" "Up" { MovePane "Up"; }
            bind "l" "Right" { MovePane "Right"; }
        }

        // 共通:すべてのモードでCtrl-qで終了
        shared_except "locked" {
            bind "Ctrl q" { Quit; }
        }
    }
  '';

  xdg.configFile."zellij/layouts/default.kdl".text = ''
    // Zellijデフォルトレイアウト
    // tmux風のシンプルなレイアウト

    layout {
        // タブバーを上部に配置
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="zellij:tab-bar"
            }
            children
            pane size=2 borderless=true {
                plugin location="zellij:status-bar"
            }
        }

        // デフォルトタブ
        tab name="main" {
            pane
        }
    }
  '';
}
