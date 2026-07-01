{ pkgs, ... }:
{
  home.packages = [ pkgs.tmux ];

  home.file.".tmux.conf".text = ''
    # ==========================================
    # 基本設定
    # ==========================================

    # プレフィックスキーを Ctrl-b から Alt-t に変更
    set -g prefix M-t
    unbind C-b
    bind M-t send-prefix

    # zedのためにマウスを有効化
    set -g mouse on

    # ESCキーの入力遅延を解消(Vim使用者向け)
    set -s escape-time 0

    # ウィンドウとペインの番号を1から開始(0はキーが遠いため)
    set -g base-index 1
    setw -g pane-base-index 1

    # 256色モードを有効化
    set -g default-terminal "screen-256color"
    set -ga terminal-overrides ",*256col*:Tc:XT"

    # 設定ファイルをリロードするショートカット (Alt + r)
    bind -n M-r source-file ~/.tmux.conf \; display "Reloaded!"

    # Windows Terminal タブタイトル設定
    set-option -g set-titles on
    set-option -g set-titles-string "[#{b:pane_current_path}] #{pane_current_command}"

    # ==========================================
    # キーバインド設定 (Altキー併用)
    # ==========================================
    # Alt-d でデタッチ
    bind -n M-d detach-client
    # Alt-a でアタッチ
    bind -n M-a attach-session

    # Alt-h, j, k, l でペイン移動(プレフィックス不要)
    bind -n M-h select-pane -L
    bind -n M-j select-pane -D
    bind -n M-k select-pane -U
    bind -n M-l select-pane -R

    # Alt-v で左右に分割(Vertical split的な直感操作)
    # -c オプションで現在のディレクトリを引き継ぐ
    # ペイン数が4つになったら自動的に2x2グリッドに整列
    bind -n M-v split-window -h -c "#{pane_current_path}" \; \
                run-shell 'if [ $(tmux list-panes | wc -l) -eq 4 ]; then tmux select-layout tiled; fi'

    # Alt-s で上下に分割(Split window的な直感操作)
    # ペイン数が4つになったら自動的に2x2グリッドに整列
    bind -n M-s split-window -v -c "#{pane_current_path}" \; \
                run-shell 'if [ $(tmux list-panes | wc -l) -eq 4 ]; then tmux select-layout tiled; fi'

    # Alt-q でペインを閉じる(最後のペインならウィンドウ終了、最後のウィンドウならセッション終了)
    bind -n M-q if-shell "[ #{window_panes} -eq 1 ]" \
        "if-shell '[ #{session_windows} -eq 1 ]' 'kill-session' 'kill-window'" \
        "kill-pane"


    # Alt-= でペインを均等なサイズにする
    bind -n 'M-=' select-layout tiled

    # Alt-4 でペインを均等に4分割(2x2グリッド)
    bind -n M-4 split-window -h -c "#{pane_current_path}" \; \
                select-pane -t 0 \; \
                split-window -v -c "#{pane_current_path}" \; \
                select-pane -t 2 \; \
                split-window -v -c "#{pane_current_path}" \; \
                select-layout tiled \; \
                select-pane -t 0

    # ==========================================
    # 見た目の微調整 (最小限)
    # ==========================================

    # ステータスバーの色を少し落ち着かせる
    set -g status-fg white
    set -g status-bg black

    # アクティブなペインを目立たせる
    set -g window-active-style 'bg=#282c34'
    set -g window-style 'bg=#4a4a4a'
    set -g pane-border-lines heavy
    set -g pane-border-indicators both
    set -g pane-border-style fg=colour238
    set -g pane-active-border-style "fg=colour214 bg=colour234"

    # ペイン上部にステータス表示(カレントディレクトリとプロセス名)
    set -g pane-border-status top
    set -g pane-border-format "#{?pane_active,#[fg=colour214#,bold],#[fg=colour238]} #(~/.tmux/scripts/pane_title.sh '#{pane_current_path}') | #{pane_current_command} #{?pane_active,#[default],}"

    # アクティブペインの下部もハイライト(擬似的に実現)
    # focus時にボーダースタイルを変更
    set-hook -g pane-focus-in 'set -p pane-border-style "fg=colour214"'
    set-hook -g pane-focus-out 'set -p pane-border-style "fg=colour238"'

    # Claude
    set -g focus-events on

    # ==========================================
    # コピーモード
    # ==========================================

    bind -n M-c copy-mode

    # コピーモードのキー操作をviライクにする
    set-window-option -g mode-keys vi

    # --- コピーモード(Vi)のキーバインドをVimに合わせる ---
    # v で選択開始
    bind -T copy-mode-vi v send -X begin-selection
    # y でコピー(copyモードは維持)
    bind -T copy-mode-vi y send -X copy-selection
    # z で矩形選択を即開始
    bind -T copy-mode-vi z send -X rectangle-toggle \; send -X begin-selection


    # ==========================================
    # ウィンドウ(タブ)設定
    # ==========================================

    # ステータスバーを上部に配置(タブっぽく見せる)
    set -g status-position top

    # ウィンドウ名を自動的にカレントディレクトリに更新
    set -g automatic-rename on
    set -g automatic-rename-format '#{b:pane_current_path}'

    # ウィンドウ番号の欠番を自動的に詰める
    set -g renumber-windows on

    # ステータスバーのウィンドウリストを左寄せ(タブっぽく)
    set -g status-justify left

    # ステータスバー左側(セッション名)
    set -g status-left '#[fg=colour214,bold][#S] #[default]'
    set -g status-left-length 20

    # ステータスバー右側(時刻のみ)
    set -g status-right '#[fg=colour246]%H:%M'
    set -g status-right-length 10

    # 非アクティブウィンドウのフォーマット
    set -g window-status-format ' #I:#W '

    # アクティブウィンドウのフォーマット(目立たせる)
    set -g window-status-current-format '#[fg=colour214,bold] #I:#W #[default]'

    # ==========================================
    # ウィンドウ操作キーバインド
    # ==========================================

    # Alt-n で新規ウィンドウ作成(カレントディレクトリを引き継ぐ)
    bind -n M-n new-window -c "#{pane_current_path}"

    # Alt-w でウィンドウ削除
    bind -n M-w kill-window

    # Alt-m でウィンドウ名変更
    bind -n M-m command-prompt -I "#W" "rename-window '%%'"

    # Alt-o で次のウィンドウ(Ctrl-Tab からも呼び出し可能)
    bind -n M-o next-window

    # Alt-p で前のウィンドウ(Ctrl-Shift-Tab からも呼び出し可能)
    bind -n M-p previous-window

    # Alt-Right / Alt-Left でウィンドウ移動(追加の操作方法)
    bind -n M-Right next-window
    bind -n M-Left previous-window

    # Alt-1〜9 でウィンドウを直接選択(Alt-4は既存の4分割機能で使用中のためスキップ)
    bind -n M-1 select-window -t 1
    bind -n M-2 select-window -t 2
    bind -n M-3 select-window -t 3
    bind -n M-5 select-window -t 5
    bind -n M-6 select-window -t 6
    bind -n M-7 select-window -t 7
    bind -n M-8 select-window -t 8
    bind -n M-9 select-window -t 9

    # ローカル固有設定の読み込み(このマシン専用: ~/.tmux.conf.local)
    if-shell '[ -f ~/.tmux.conf.local ]' 'source-file ~/.tmux.conf.local'
  '';

  home.file.".tmux/scripts/pane_title.sh" = {
    text = ''
      #!/bin/bash
      dir="$1"
      dirname=$(basename "$dir")
      branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ -n "$branch" ]; then
          echo "$dirname($branch)"
      else
          echo "$dirname"
      fi
    '';
    executable = true;
  };
}
