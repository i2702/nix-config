# コミットルール
- 複合的な更新でければ、各アプリケーションごとにコミットは分割する
- コミットメッセージのプレフィクスは各アプリケーションの名前にする (ex. "git: ", "zsh: ", "neovim: ")

# home-managerの適用
適用は必ず `hms` (= `home-manager switch -b backup --flake ~/nix-config#linux` / macでは `#mac`) を使うこと。
`-b backup` を省略した素の `home-manager switch` は禁止。

- 理由: 管理対象パスに実体ファイル (nix管理外のファイル) が居座っていると activation の `linkGeneration` が中断する。このときビルド自体は成功して profile に新世代が登録されるため、コマンドは一見成功したように見えるが、`~/.zshrc` などのsymlinkは古い世代を指したまま放置される。「追加したはずのaliasが効かない」という形で表面化し、原因が非常に見えにくい。
- `-b backup` があれば衝突ファイルを `.backup` へ退避して最後まで通る。

適用後は以下の検証を必ず行い、結果を報告すること。省略しない。

1. 世代の整合を確認する。2つがズレていたら activation が失敗している。
   ```sh
   readlink ~/.local/state/home-manager/gcroots/current-home
   readlink ~/.local/state/nix/profiles/home-manager
   ```
2. switch の出力に `is in the way of` の行が出ていないか確認する。出ていた場合は退避されたファイルをユーザーに報告する。
3. 今回変更した設定が実際に反映されているかを、ライブのsymlink先または新しいシェルで確認する (ex. `zsh -i -c 'alias <名前>'`)。
4. herdr のサーバを新しいバイナリへ引き継ぐ。
```sh
   herdr server live-handoff --import-exe ~/.nix-profile/bin/herdr
```
   - `--import-exe` は省略しない。省略するとサーバが自分の旧 store パスを再実行して更新されない。
   - `herdr server stop` は使わない。ペインのプロセス (作業中のエージェント含む) を全部殺す。
   - herdr のサーバが起動していない環境ではエラーになるだけなので無視してよい。
   - 引き継ぎ後に `herdr pane list` が `protocol_mismatch` でなく結果を返すことを確認して報告する。詳細は `claude/skills/herdr/SKILL.md`。

# よく使う命令
- 現在の変更について、home-managerでの適用 → コミット → push を行うことを「いつもの」と呼ぶ。適用は上記「home-managerの適用」に従うこと (適用後の検証 1〜4、herdr の live-handoff を含む)
