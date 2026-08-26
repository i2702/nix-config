---
name: herdr
description: >-
  herdr(ターミナルマルチプレクサ)の本体を更新するとき、設定を変えるときに必ず使う。
  「herdr」「live-handoff」「protocol_mismatch」「kitty_graphics」に言及されたときも、
  ユーザーが明示的に指示しなくても参照する。
---

# herdr の操作

設定は nix-config リポジトリ(`~/nix-config`)の
`modules/herdr.nix` で宣言的に管理している。`~/.config/herdr/config.toml` はその
読み取り専用シンボリックリンクなので直接編集しない(herdr 自身にも書かせない)。

## 設定を変える

1. `modules/herdr.nix` を編集
2. `hms`
3. `herdr config check` — 不明なキーはここで落ちる
4. `herdr server reload-config` — 再起動せず反映される

## 本体を更新する

herdr は nixpkgs 未収録で、flake input `github:herdrdev/herdr` の master 追従。
「最新版」を求められたら nixpkgs ではなく上流の master HEAD を見る。

```bash
nix flake update herdr
hms
```

`src` パッチ(COPY MODE の ctrl-e/ctrl-y)を `overrideAttrs` で当てているので、
ビルド前に新しい rev でパッチが当たるかを確認すると無駄なビルドを避けられる。
上流に同等機能が入っていたらパッチごと削除する。

### 更新後は live-handoff が必要になることがある

socket プロトコルのバージョンが上がると、起動中の旧サーバと新 CLI が不一致になる。
確認は任意の CLI を叩くだけでよい:

```bash
herdr pane list   # → {"error":{"code":"protocol_mismatch",...}} なら不一致
```

この状態ではキーバインドのシェルスクリプト(Alt-f / Alt-a / Alt-e)と cd 毎の
ペインラベル更新が全部止まる。解消はライブペインを保持したまま新バイナリのサーバへ
引き継ぐこのコマンド:

```bash
herdr server live-handoff --import-exe ~/.nix-profile/bin/herdr
```

`--import-exe` を省略するとサーバは自分の `current_exe()`(= 旧 store パス)を
再実行してしまい更新されない。プロトコル不一致状態でも通る復旧経路はこれだけ。

**`herdr server stop` は使わない。** ペインのプロセスを全部殺すので、作業中の
エージェントも落ちる。
