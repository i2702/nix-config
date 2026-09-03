# 手動セットアップ

nix で宣言できず、マシンごとに手で実行する必要がある作業の記録。

`home-manager switch` では復元されないため、環境を作り直したときやこのリポジトリを
別マシンへ持っていったときはここを見る。逆に言えば、**このファイルに書かれた作業を
していないマシンでは、対応する機能が動かない**。

---

## herdr 更新後の live-handoff

`nix flake update herdr` + `home-manager switch` の後、socket プロトコルの
バージョンが上がっていると、起動中の旧サーバと新 CLI が不一致になる。

```bash
herdr pane list   # → {"error":{"code":"protocol_mismatch",...}} なら不一致
```

この状態ではキーバインドのシェルスクリプト(Alt-f / Alt-a / Alt-e)と cd 毎の
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

---

## m1ddc (ディスプレイ入力切り替え)

`disp-win` / `disp-mac` / `m1ddc-probe` などの zsh 関数(`modules/m1ddc.nix`)が動くために必要。
Mac 専用のため `hosts/mac.nix` からのみ import している。

m1ddc は nixpkgs に無いので Homebrew で入れる。

```bash
brew install m1ddc
```

入っていない場合、関数は定義されるが実行時に `command not found: m1ddc` で失敗する。

### 入力コードと UUID

DDC の VCP コード(0x60)は機種ごとに値が違い、MCCS 標準表(0x0F〜0x12)とも一致しない。
下記は実測値なので、モニタを入れ替えたら取り直す。

| ディスプレイ | Mac | Win |
|---|---|---|
| DELL U3223QE | 17 | 27 |
| BenQ RD320UA | 19 (USB-C) | 15 (DP) |

`modules/m1ddc.nix` が持つ UUID もこの2台に紐づく。別のモニタでは
`m1ddc display list detailed` で取り直す。

### この環境固有の制約

- Win 機は BenQ を Win 入力として掴むまで DELL へ出力しない。`disp-win` が BenQ を
  先に切り替えて5秒待つのはこのため
- DDC 読み取りは4〜5割が失敗し、ディスプレイ固有の固定値(DELL=110 / BenQ=0)を返す。
  `m1ddc-probe` が複数回読んで分布を出すのはこのため。書き込み側は取りこぼしが少ない
- DELL は信号の無い入力でも選択状態を保持し続けるので、読み戻しからは信号の有無を
  判別できない。入力コードの特定は最終的に目視で行う

---

## Raycast のスクリプトディレクトリ登録

`modules/raycast.nix` が置く Focus Mac Window / Focus Win Window
(Ghostty のウィンドウをタイトルで探して前面に出す) が動くために必要。

Raycast の Script Command は決め打ちのパスを見に行くのではなく、設定で登録された
ディレクトリだけを走査する。登録先は Raycast 内部の DB で、plist にも
`~/.config` にも出ないため nix からは宣言できない。

Raycast → Settings → Extensions → Script Commands → **Add Directories** で
`~/.config/raycast/scripts` を追加する。

そのうえで一覧に出た各コマンドにホットキーを割り当てる。引数なしのコマンドに
してあるので、ホットキーを押した瞬間にフォーカスが移る (引数つきにすると
Raycast が入力欄を開いてしまい、ホットキー一発では飛べない)。

### 補助アクセス (Accessibility)

ウィンドウの列挙と AXRaise は Accessibility API なので、**Raycast** に
システム設定 → プライバシーとセキュリティ → アクセシビリティ の許可が要る。
許可が無いと `Error: 584:968` のような文字オフセットだけのエラーになる(実体は
`-25211` 補助アクセスは許可されません)。理由が読み取れないので、スクリプト側で
`UI elements enabled` を先に見て「Raycast に補助アクセスの許可がありません」と
出すようにしてある。この文言が出たらここを疑う。

既に一覧に居るのに出る場合は、Raycast の更新で TCC のエントリが古くなっている。
一度オフ/オンして Raycast を再起動する。

許可の主体は「スクリプトを実行したアプリ」なので、ターミナルから同じスクリプトを
叩いて失敗しても Raycast 側の可否とは無関係。切り分けの材料にしないこと。
