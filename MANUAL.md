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

### オートメーション (Automation)

スクリプトは Ghostty 自身の AppleScript 辞書 (`Ghostty.app/Contents/Resources/Ghostty.sdef`、
1.3.1 で確認) を叩く。Apple Events を Raycast から Ghostty へ送るので、**Raycast** に
システム設定 → プライバシーとセキュリティ → **オートメーション** → Raycast → **Ghostty** の
許可が要る。初回実行時に macOS がダイアログを出すので、そこで許可すれば済む。

補助アクセス (アクセシビリティ) は**要らない**。System Events を使わないため。

許可が無いと `-1743` (Apple Events を送信する権限がありません) になる。スクリプト側で
これを捕まえて「Raycast から Ghostty へ Apple Events を送る許可がありません」と
出すようにしてあるので、この文言が出たらここを疑う。

ダイアログで「許可しない」を押してしまった、あるいは一覧に Raycast が出てこない場合は
TCC の記録を消してダイアログを出し直す:

```bash
tccutil reset AppleEvents com.raycast.macos
```

許可の主体は「スクリプトを実行したアプリ」なので、ターミナルから同じスクリプトを
叩けた/叩けなかったことは Raycast 側の可否とは無関係。切り分けの材料にしないこと。

### 切り分け

失敗した回だけ `~/.cache/raycast-focus-window.log` に
`日時 rc=<終了コード> <実行されたパス> <メッセージ>` が1行残る。

- 行が増えない / パスが `/nix/store/...` → Raycast が古い版を実行している。
  ディレクトリを一度削除して追加し直す
- 「Ghostty が起動していません」「タイトルに "Mac" を含む…ありません」 → 権限は通っている。
  `osascript -e 'tell application "Ghostty" to get name of every window'` で実際の
  タイトルを見る (ターミナルからは Ghostty 自身への送信なので許可なしで通る)

---

## WSL の sshd (:2222) を常時上げておく

Windows 機の WSL へ外から入るための設定。`modules/wezterm.nix` の SSH ドメイン
(`127.0.0.1:2222`) と `modules/zsh.nix` の `ssh wsl` がこれに乗っている。

WSL の distro は Windows を起動しただけでは立ち上がらず、`wsl.exe` のクライアントが
1つも居なくなると落ちる。SSH で入る使い方は `wsl.exe` を経由しないため、放っておくと
**「ターミナルを開くまで 2222 番に繋がらない」** 状態になる。防いでいるのは次の 2つで、
どちらも Windows 側にあるため nix からは宣言できない。

### `C:\Users\<user>\.wslconfig`

```ini
[wsl2]
networkingMode=Mirrored
vmIdleTimeout=-1
```

`vmIdleTimeout` の既定は 60000ms で、最後の `wsl.exe` クライアントが消えてから 1分で
VM が落ちる。`-1` で無効化する。ただしこれは VM の寿命の話で、distro インスタンスの
アイドル終了は止められない。それが次のタスク。

### タスクスケジューラ `\WSL-KeepAlive`

`wsl.exe -d Ubuntu --exec sleep infinity` を常駐させ、distro を掴んで落ちないようにする。
定義は `templates/wsl-keepalive-task.xml.example`。トリガーは 3本:

| トリガー | 設定 | 役割 |
| --- | --- | --- |
| TimeTrigger | 開始 2026-01-01、5分間隔・無期限 | 死んだときの復旧 |
| BootTrigger | 遅延 30秒 | 起動直後に素早く立てる |
| EventTrigger | Power-Troubleshooter id=1、遅延 15秒 | スリープ/休止からの復帰 |

**繰り返しは `TimeTrigger` に持たせる。** `BootTrigger` 配下に置いた繰り返しは、その起動
トリガーが発火した時点から始まる仕様なので、登録し直した回は次のブートまで効かない
(`Get-ScheduledTaskInfo` の `NextRunTime` が空になる)。`StartBoundary` を過去に置いた
`TimeTrigger` なら登録直後から回る。

`MultipleInstancesPolicy=IgnoreNew` が要。生きている間は 5分ごとの発火が「既に実行中」
(タスクスケジューラのイベント id=322) として捨てられ、`sleep infinity` が死んだときだけ
新しいものが立つ。

登録には UAC 昇格が要る。ルートフォルダのタスクなので、昇格しないと
`Register-ScheduledTask` が `Access is denied` になる。

### 切り分け

2222 番に繋がらないとき、**sshd の設定から見ない**。まず distro が生きているかを見る:

```bash
ps -eo etime,args | grep '[s]leep infinity'  # 無ければ KeepAlive が効いていない
uptime -s                                    # WSL の起動時刻
```

WSL の起動時刻が Windows の起動時刻(`Get-CimInstance Win32_OperatingSystem`)より
大幅に後なら、ターミナルを開いた時に初めて起きている。Windows 側では:

```powershell
Get-ScheduledTaskInfo -TaskName 'WSL-KeepAlive'   # NextRunTime が空なら繰り返しが効いていない
```

`journalctl --list-boots` の最終エントリと、タスクスケジューラのイベント id=201
(アクション終了) の時刻が一致していたら、distro が落ちて `sleep infinity` も
道連れになった回。

なお `unattended-upgrades` が openssh-server を更新すると sshd が数秒落ちる。
これは distro の停止とは別件で、`journalctl -u ssh` に再起動の記録が残る。
