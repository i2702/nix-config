# 手動セットアップ

nix で宣言できず、マシンごとに手で実行する必要がある作業の記録。

`home-manager switch` では復元されないため、環境を作り直したときやこのリポジトリを
別マシンへ持っていったときはここを見る。逆に言えば、**このファイルに書かれた作業を
していないマシンでは、対応する機能が動かない**。

---

## herdr-browser プラグイン

herdr のブラウザペイン(**Alt-b** / localhost URL の Ctrl-クリック)を使うために必要。

`modules/herdr.nix` 側は宣言済みで、手で触る必要はない。

- `[experimental] kitty_graphics = true` — Chromium の画面をペインへ描画するのに必要
- **Alt-b** のキーバインド(`plugin pane open --plugin official.browser`)

プラグイン本体は herdr が管理するディレクトリへ clone される命令的インストールで、
nix では宣言できない。

```bash
herdr plugin install ogulcancelik/herdr-browser --yes
```

`herdr plugin list` に `official.browser` が出れば成功。以降 Alt-b が使える。
インストール前に Alt-b を押しても何も起きない(プラグイン未登録エラーになるだけ)。

インストール後の疎通確認は、ペインを開かずに済む `status` アクションが早い:

```bash
herdr plugin action invoke official.browser.status
herdr plugin log list --plugin official.browser   # stdout に結果が入る
```

`ok: true` と `daemon.chrome_pid` が出れば、Bun が herdr サーバから到達でき、
Chromium の自動検出も成功している。

### 配置されるパス

いずれも herdr が管理する領域で、このリポジトリの管理外(`~/.config/herdr/` 配下だが
nix が作るのは `config.toml` と `scripts/` だけ)。

| 用途 | パス |
|---|---|
| プラグイン本体 | `~/.config/herdr/plugins/github/official.browser-<hash>` |
| 設定 (`browser.json`) | `~/.config/herdr/plugins/config/official.browser` |
| 状態 (Chrome プロファイル) | `~/.local/state/herdr/plugins/official.browser` |

ハッシュ付きなのでパスを直書きしない。必要なときは
`herdr plugin list --plugin official.browser --json` の `plugin_root` を引く。

### 前提

| 前提 | 備考 |
|---|---|
| herdr 0.7.4 以上 | flake input で管理しているので通常は自動的に満たす |
| Bun | Homebrew 由来 (`/opt/homebrew/bin/bun`)。このリポジトリの管理外 |
| Google Chrome または Chromium | プラグインは Chromium を自動ダウンロードしない |
| Kitty graphics 対応端末 | Ghostty を使っているので満たしている |

Bun と Chrome は Homebrew 由来で nix 管理外。`herdr plugin install` はプラグインの
マニフェストに build コマンドが無いため npm 依存の取得は走らず、Bun は実行時に
`bun run` として必要になる。herdr サーバの PATH に Bun が居ることが条件なので、
Bun を入れ替えたら herdr を再起動(live-handoff)する。

### 運用上の注意

- プラグインのコードは sandbox されず、自分のユーザ権限で herdr CLI をフルに
  呼べる(公式ドキュメントに明記あり)。作者は herdr 本体と同一人物・MIT ライセンスだが
  まだ v0.1.0
- `plugin update` は存在しない。更新は GitHub から再インストールする
- プラグイン設定は `herdr plugin config-dir official.browser` が出すディレクトリの
  `browser.json`。描画が重ければ `captureScale` を `0.75` に下げる(HiDPI では
  画素数が支配的なので最も効く)
- 削除は `herdr plugin uninstall official.browser`
- SSH 越しはフレームの帯域が足りないのでローカルセッション専用

---

## herdr 更新後の live-handoff

`nix flake update herdr` + `home-manager switch` の後、socket プロトコルの
バージョンが上がっていると、起動中の旧サーバと新 CLI が不一致になる。

```bash
herdr pane list   # → {"error":{"code":"protocol_mismatch",...}} なら不一致
```

この状態ではキーバインドのシェルスクリプト(Alt-v / Alt-a / Alt-e)と cd 毎の
ペインラベル更新が止まる。解消はこのコマンド:

```bash
herdr server live-handoff --import-exe ~/.nix-profile/bin/herdr
```

`--import-exe` を省略するとサーバは自分の `current_exe()`(= 旧 store パス)を
再実行してしまい更新されない。

**`herdr server stop` は使わない。** ペインのプロセスを全部殺すので、作業中の
エージェントも落ちる。live-handoff はライブペインを保持したまま引き継ぐ経路で、
プロトコル不一致状態でも通る唯一のコマンド。

---

## git identity

`templates/git-config.local.example` を `~/.config/git/config.local` にコピーして
name / email を埋める。詳細は README の「セットアップ」を参照。
これが無いと activation が失敗して停止する。
