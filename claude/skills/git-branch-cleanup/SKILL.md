---
name: git-branch-cleanup
description: >-
  main へ取り込み済みの merge/ ・ sub/ ブランチとワークツリーを片付けるときに必ず使う。
  「マージ済みブランチを削除」「ブランチを掃除」「worktree を片付ける」「作業ブランチを整理」
  に言及されたときも、ユーザーが明示的に指示しなくても参照する。
---

# マージ済みブランチの片付け

作業分割で切った `sub/*` と `merge/*` は、最終確認が済むまで残す運用になっている
(グローバル CLAUDE.md「作業分割の手順」)。確認が済んだら本スキルで一括して片付ける。

判定は目視ではなく `cleanup-merged-branches.sh` に任せる。ブランチ名や PR の見た目ではなく
**コミットの突合**で「取り込み済み」を確定させるため。

```sh
# 一覧だけ出す(既定は dry-run)
~/.claude/skills/git-branch-cleanup/cleanup-merged-branches.sh

# 実際に削除する。リモート(origin)側も消すなら --remote
~/.claude/skills/git-branch-cleanup/cleanup-merged-branches.sh --apply --remote
```

## 取り込み済みの判定(3段)

上から順に判定し、当たった時点で確定する。どれにも当たらなければ `KEEP` で残す。

| 段 | 判定 | 当たるケース |
|---|---|---|
| `ancestor` | ブランチ先端が base の祖先(`git merge-base --is-ancestor`) | マージコミット / 早送り / リベースマージ |
| `patch-id` | `git cherry base branch` が全行 `-` | cherry-pick、単一コミットの squash |
| `pr` | `gh pr list --state merged --head <branch>` に該当あり | 複数コミットの squash マージ |

`ancestor` のときは `git rev-list --ancestry-path <branch>..<base> | tail -1` で
**base 側で最初にそのブランチを取り込んだコミット**を出し、根拠として表示する。
`pr` のときは PR 番号とマージコミットを表示する。

## 削除の順序と方法

1. ブランチがワークツリーにチェックアウトされていたら先にワークツリーを消す。
   `gwq` があれば `gwq remove -b <branch>` を使う
   (ワークツリーの管理主体を gwq に一本化するため。[[git-worktree]] と同じ理由)
2. `ancestor` は `git branch -d`、`patch-id` / `pr` は `git branch -D`。
   後者は `-d` が拒むが、取り込み確認はスクリプト側で済んでいる
3. `--remote` を付けたときだけ `git push origin --delete <branch>`

**gwq の戻り値を信用しない。** `gwq remove -b` は途中で失敗しても終了コード 0 を返し、
登録・ディレクトリ・ブランチが中途半端に残ることがある(実測: ワークツリー登録は外れたが
ディレクトリの一部とブランチが残った)。スクリプトは戻り値ではなく
「登録が消えたか」「ディレクトリが消えたか」「ブランチが消えたか」を実地で確認し、
残っていれば `git worktree remove --force` / `git branch -d|-D` で始末する。

ディレクトリの残骸を `rm -rf` するのは、**`.git` がファイルで、その `gitdir:` 先が既に無い**
(= git から切り離された残骸であることが検証できる)ときだけ。それ以外は警告を出して手を出さない。

## 対象から外れるもの

- `main` / `master` / `develop` と base 自身
- 実行中のワークツリーがチェックアウトしているブランチ(自分の足元は消せない)
- `--pattern` に一致しないブランチ。既定は `merge/*` と `sub/*` だけなので、
  `docs/*` や `feature/*` は明示しない限り触らない

## 注意

- リモート削除は取り消せない。`--remote` を付ける前に必ず dry-run の一覧を見せて合意を取る
- **実機確認が残っている作業のブランチは消さない**。main にマージ済みでも、
  VVD 反映などの検証が終わるまでは差し戻し先として残す運用になっている
