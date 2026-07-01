{ pkgs, ... }:
{
  home.packages = [ pkgs.lazygit ];

  xdg.configFile."lazygit/config.yml".text = ''
    # yaml-language-server: $schema=https://raw.githubusercontent.com/jesseduffield/lazygit/master/schema/config.json

    # lazygit 設定ファイル
    # 2025年ベストプラクティスに準拠
    # Vim操作、Nerd Fonts v3、delta連携、UI重視

    gui:
      language: "ja" # 日本語UI
      nerdFontsVersion: "3" # Nerd Fonts v3対応
      border: "rounded" # 角丸ボーダー
      showFileTree: true # ファイルツリー表示
      showCommandLog: true # コマンドログ表示
      showBottomLine: true # 下部キーバインド表示
      filterMode: "fuzzy" # ファジー検索
      mouseEvents: true # マウス操作有効
      scrollHeight: 4 # スクロール行数増加
      scrollPastBottom: true # 下端スクロール許可
      showBranchCommitHash: true # ブランチコミットハッシュ表示
      commitLength:
        show: true # コミットメッセージ長表示
      theme:
        lightTheme: false # ダークテーマ
        activeBorderColor:
          - "#ff8800" # オレンジアクセント
          - bold
        inactiveBorderColor:
          - default
        selectedLineBgColor:
          - "#3d3d00" # 暖色系選択行背景
        cherryPickedCommitFgColor:
          - "#ff8800" # cherry-pick時のオレンジ強調
    git:
      autoFetch: true # 自動フェッチ
      autoRefresh: true # 自動リフレッシュ
      fetchAll: true # 全リモートフェッチ
      mainBranches:
        - master
        - main
        - develop
      commit:
        verbose: true # 詳細コミット情報表示
      pagers:
        - useConfig: true # gitconfig pager使用(delta)
      merging:
        edit: true # 外部エディタでマージ
      log:
        order: "date-order" # 日付順ログ
        showGraph: "always" # グラフ常時表示
    os:
      editPreset: "vim" # エディタプリセット
    keybinding:
      universal:
        scrollUpMain-alt1: "<c-u>" # Ctrl+U: 半ページ上
        scrollDownMain-alt1: "<c-d>" # Ctrl+D: 半ページ下
    customCommands:
      - key: "<c-p>"
        context: "global"
        command: "git push"
        description: "プッシュ"
      - key: "<c-f>"
        context: "global"
        command: "git fetch --all --prune"
        description: "全フェッチ(prune付き)"
  '';
}
