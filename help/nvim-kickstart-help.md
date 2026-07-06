# 📖 kickstart.nvim 由来の追加機能ガイド

`modules/neovim.nix` に kickstart.nvim の主要要素を移植した。
このドキュメントは追加された各機能の使い方をまとめたもの。

> ⚠️ 設定の実体は `modules/neovim.nix`。`~/.config/nvim/` 以下は Nix ストアへのリンクなので直接編集できない。
> 変更は `modules/neovim.nix` を編集して `home-manager switch --flake ~/nix-config#linux` で反映する。
> リーダーキーは `,`（カンマ）。

---

## 🌳 nvim-treesitter — 構文解析ベースのハイライト

正規表現ではなく構文木でコードを解析する。ハイライトとインデントが正確になる。

- 対象言語のパーサーは自動でインストールされる（`auto_install = true`）
- 事前導入済み: bash, c, diff, html, lua, luadoc, markdown, markdown_inline, query, vim, vimdoc, nix, typescript, tsx, javascript, json, yaml

| コマンド | 動作 |
|---|---|
| `:TSUpdate` | パーサーを更新 |
| `:TSInstall <言語>` | パーサーを手動追加 |
| `:InspectTree` | 現在のファイルの構文木を表示 |

---

## 📦 mason — LSPサーバーの自動インストール

LSP サーバーを nvim 内から自動でインストール・管理する。
`ensure_installed` に書いたサーバーは初回起動時に自動導入される。

導入済みサーバー:

| サーバー | 言語 |
|---|---|
| `lua_ls` | Lua（nvim 設定編集用） |
| `ts_ls` | TypeScript / JavaScript |
| `nil_ls` | Nix |

| コマンド | 動作 |
|---|---|
| `:Mason` | インストール状況の管理画面を開く（`g?` でヘルプ） |
| `:MasonInstall <名前>` | サーバーを手動追加 |
| `:LspInfo` | 現在のバッファにアタッチ中の LSP を確認 |

サーバーを増やすときは `modules/neovim.nix` の `ensure_installed` に追記する。
インストール先は `~/.local/share/nvim/mason/`。

💡 `nil_ls` は flake inputs を自動 fetch する設定済み（`autoArchive = true`）。
初回アタッチ時は fetch で数秒かかることがある。

### LSP キーマップ（既存設定・参考）

| キー | 動作 |
|---|---|
| `gd` / `gD` | 定義 / 宣言へジャンプ |
| `gr` / `gi` | 参照一覧 / 実装へジャンプ |
| `K` | ホバー情報 |
| `,rn` | リネーム |
| `,ca` | コードアクション |
| `[d` / `]d` | 前 / 次の診断 |

---

## 📶 fidget — LSP進捗表示

LSP のインデックス処理などの進捗が右下に小さく表示される。設定・操作は不要。
「LSP が動いているのか分からない」問題がなくなる。

---

## 🌙 lazydev — nvim設定編集の補完強化

Lua ファイルを開くと `lua_ls` が `vim.*` API を認識する。
`modules/neovim.nix` 内の Lua 設定を書くときに補完と型情報が効く。
「undefined global vim」警告も出なくなる。設定・操作は不要。

---

## ⌨️ which-key — キーマップのカンニングペーパー

キー入力の途中で候補が下部にポップアップする。
`,` を押すとリーダーキー配下の一覧が出るので、キーマップを覚える必要がない。

| コマンド | 動作 |
|---|---|
| `,`（押して待つ） | リーダー配下のキーマップ一覧 |
| `:WhichKey` | 全キーマップ一覧 |

グループ名を設定済み: `,f` 🔍 検索/フォーマット、`,b` 📄 バッファ、`,c` 🔧 コード、`,r` ✏️ リネーム、`,h` 🌿 Git hunk

---

## 🌿 gitsigns — Git変更の可視化とhunk操作

変更行の左端にサインが出る（追加 `+` / 変更 `~` / 削除 `_`）。

| キー | 動作 |
|---|---|
| `]h` / `[h` | 次 / 前の変更 hunk へ移動 |
| `,hp` | hunk の差分をプレビュー |
| `,hs` | hunk をステージ |
| `,hr` | hunk をリセット（変更を破棄）⚠️ |
| `,hb` | カーソル行の blame 表示 |

コミット前に `]h` で変更を巡回して `,hp` で確認 → `,hs` でステージ、という流れが便利。

---

## 🧩 mini.nvim — 小粒プラグイン集

### mini.ai — テキストオブジェクト強化

`a`（around）/ `i`（inside）のテキストオブジェクトが賢くなる。
カーソルが対象の外にあっても最大500行先まで探しに行く。

| 入力例 | 動作 |
|---|---|
| `va)` | 括弧を含めて選択（カーソルが括弧の外でも効く） |
| `ci'` | クォート内を書き換え |
| `daf` | 関数呼び出しごと削除（`f` = function call） |
| `cia` | 引数1つを書き換え（`a` = argument） |
| `vat` | HTMLタグごと選択（`t` = tag） |

### mini.surround — 囲み操作

| 入力例 | 動作 |
|---|---|
| `saiw)` | カーソル下の単語を `(` `)` で囲む（**s**urround **a**dd） |
| `sd'` | 一番近い `'` の囲みを削除（**s**urround **d**elete） |
| `sr)'` | `(` `)` を `'` に置換（**s**urround **r**eplace） |
| `sf)` / `sF)` | 次 / 前の `)` 囲みへ移動（**s**urround **f**ind） |

ビジュアル選択中に `sa)` でも囲める。

### mini.statusline — ステータスライン

モード・Git ブランチ・診断・ファイル情報・カーソル位置を表示する。
`showmode = false`（既存設定）はこれが前提。Nerd Font アイコン有効。

---

## 🔧 トラブルシューティング

| 症状 | 対処 |
|---|---|
| プラグインが壊れた | `:Lazy` で状況確認、`:Lazy sync` で再同期 |
| ハイライトがおかしい | `:TSUpdate` でパーサー更新 |
| LSP が起動しない | `:LspInfo` と `:Mason` で状態確認 |
| 全体の健康診断 | `:checkhealth` |
