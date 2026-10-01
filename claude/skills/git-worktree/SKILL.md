---
name: git-worktree
description: >-
  Gitでワークツリーを作成・削除するときに使う
---

Gitのワークツリーを操作するときはgwqコマンドを使う

- ワークツリーを作成するときは `gwq add -b {ブランチ名}`
- ワークツリーを削除するときは `gwq remove -b {ブランチ名}`

ブランチ名はグローバル CLAUDE.md「作業分割の手順」に従う。

`[種別]` は `feature|bugfix|fix|chore|refactor|docs|test` のいずれか。

| 種類 | 名前 | 例 |
|---|---|---|
| 親ブランチ | `[名前]/[種別]` | `gwq add -b branch-cleanup/docs` |
| サブブランチ | `[親の名前]/sub/[種別]/[名前]` | `gwq add -b branch-cleanup/sub/fix/pattern` |
| spike | `spike/[名前]/[種別]`、`spike/[親の名前]/sub/[種別]/[名前]` | `gwq add -b spike/try-extglob/chore` |

マージ済みのブランチとワークツリーをまとめて片付けるときは [[git-branch-cleanup]] を使う。
