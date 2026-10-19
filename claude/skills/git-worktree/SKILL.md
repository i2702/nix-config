---
name: git-worktree
description: >-
  Gitでワークツリーを作成・削除するときに使う
---

Gitのワークツリーを操作するときはgwqコマンドを使う

- ワークツリーを作成するときは、ブランチを先に作ってから `gwq add {ブランチ名}` する (下記)
- ワークツリーを削除するときは `gwq remove -b {ブランチ名}`

## 派生元を指定して作成する

gwq には派生元を指定するオプションがない。次の手順で作る。

```sh
git branch {ブランチ名} {派生元}   # ex. git branch fix/foo origin/main
git branch --unset-upstream {ブランチ名}   # 派生元が origin/... のときだけ。origin/main を追跡させない
gwq add {ブランチ名}                # -b を付けない。既存ブランチのワークツリーを作る
```

- `gwq add` に2つ目の位置引数を渡さない。`gwq add [branch] [path]` の2つ目は派生元ではなく作成先のパスで、カレントディレクトリからの相対パスとして解釈される。`git worktree add` や `git switch -c` の感覚で派生元を渡すと、既存ワークツリーの中にワークツリーが作られる。
- `gwq add -b {ブランチ名}` は、カレントディレクトリのワークツリーの HEAD から新しいブランチを作る。どこで実行したかに結果が依存するため使わない。
- 作成後は `git -C "$(gwq get {ブランチ名})" log --oneline -1` で派生元のコミットになっているか確認する。
- サブブランチは親ブランチを派生元にする (ex. `git branch docs/foo/sub/fix/bar docs/foo/main`)。

ブランチ名はグローバル CLAUDE.md「作業分割の手順」に従う。

`[種別]` は `feature|bugfix|fix|chore|refactor|docs|test` のいずれか。

| 種類 | 名前 | 例 |
|---|---|---|
| 分割しない作業 | `[種別]/[名前]` | `docs/branch-cleanup` |
| 親ブランチ | `[種別]/[名前]/main` | `docs/branch-cleanup/main` |
| サブブランチ | `[種別]/[親の名前]/sub/[種別]/[名前]` | `docs/branch-cleanup/sub/fix/pattern` |
| 接頭辞 `spike/`・`wip/`・`archive/` | 上記の先頭に付ける | `spike/feature/red-dialog` |

マージ済みのブランチとワークツリーをまとめて片付けるときは [[git-branch-cleanup]] を使う。
