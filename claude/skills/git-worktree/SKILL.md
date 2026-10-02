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
| 分割しない作業 | `[種別]/[名前]` | `gwq add -b docs/branch-cleanup` |
| 親ブランチ | `[種別]/[名前]/main` | `gwq add -b docs/branch-cleanup/main` |
| サブブランチ | `[種別]/[親の名前]/sub/[種別]/[名前]` | `gwq add -b docs/branch-cleanup/sub/fix/pattern` |
| 接頭辞 `spike/`・`wip/` | 上記の先頭に付ける | `gwq add -b spike/feature/red-dialog` |

マージ済みのブランチとワークツリーをまとめて片付けるときは [[git-branch-cleanup]] を使う。
