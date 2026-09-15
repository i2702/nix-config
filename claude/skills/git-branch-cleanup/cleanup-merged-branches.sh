#!/usr/bin/env bash
#
# 派生元(既定 origin/main)へ取り込み済みのブランチと、そのワークツリーを片付ける。
#
# 「取り込み済み」は3段で突合する(上から順に判定し、当たった時点で確定):
#   1. ancestor  … ブランチ先端が base の祖先。マージコミット/早送り/リベースマージ。
#                   git rev-list --ancestry-path で「base 側で最初に取り込んだコミット」を出す
#   2. patch-id  … git cherry が全行 '-'。squash / cherry-pick で SHA は変わったが同じ変更が base にある
#   3. pr        … gh で head=<branch> の merged PR がある。複数コミットの squash はここでしか当たらない
#
# 既定は dry-run。--apply を付けたときだけ実際に削除する。
set -euo pipefail

BASE=""
APPLY=0
REMOTE=0
FETCH=1
KEEP_WORKTREE=0
PATTERNS=()
PROTECTED_DEFAULT=(main master develop)

usage() {
  cat <<'USAGE'
使い方: cleanup-merged-branches.sh [オプション]

  --base <ref>      取り込み先(既定: origin/main があればそれ、無ければ main)
  --pattern <glob>  対象ブランチの glob。繰り返し指定可(既定: 'merge/*' 'sub/*')
                    wip/* は glob では拾わず、--pattern wip/foo のように名指ししたときだけ対象
  --apply           実際に削除する(既定は dry-run で一覧を出すだけ)
  --remote          リモート(origin)側の同名ブランチも削除する
  --keep-worktree   ワークツリーを消さない(ワークツリーを持つブランチは対象外になる)
  --no-fetch        実行前の git fetch --prune を省く
  -h, --help        この使い方

判定と削除の対応:
  ancestor / patch-id / pr のいずれかで取り込み済みと確認できたブランチだけを消す。
  削除は常に git branch -D。-d は --base ではなく HEAD を基準に判定するため、
  --base に HEAD 以外を渡すと取り込み済みでも拒む(取り込み確認はスクリプト側で済んでいる)。

  1 件の失敗で残りを放置しないよう、ブランチごとに独立して処理する。
  失敗があった場合は末尾に一覧を出し、終了コード 1 で終わる。
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    --pattern) PATTERNS+=("$2"); shift 2 ;;
    --apply) APPLY=1; shift ;;
    --remote) REMOTE=1; shift ;;
    --keep-worktree) KEEP_WORKTREE=1; shift ;;
    --no-fetch) FETCH=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "不明なオプション: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ ${#PATTERNS[@]} -eq 0 ]; then
  PATTERNS=('merge/*' 'sub/*')
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "git リポジトリの中で実行してください" >&2; exit 2; }

if [ "$FETCH" -eq 1 ] && git remote get-url origin >/dev/null 2>&1; then
  git fetch --prune --quiet
fi

if [ -z "$BASE" ]; then
  if git rev-parse --verify --quiet origin/main >/dev/null; then BASE=origin/main
  elif git rev-parse --verify --quiet main >/dev/null; then BASE=main
  else echo "base を特定できません。--base で指定してください" >&2; exit 2; fi
fi
git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "base が見つかりません: $BASE" >&2; exit 2; }

CURRENT="$(git branch --show-current || true)"

# <branch> をチェックアウトしているワークツリーのパス(無ければ空)
worktree_of() {
  git worktree list --porcelain | awk -v want="refs/heads/$1" '
    /^worktree /{ path = substr($0, 10) }
    /^branch /   { if (substr($0, 8) == want) { print path; exit } }'
}

# gh で head=<branch> の merged PR を探し "<番号> <マージコミット>" を返す
merged_pr_of() {
  command -v gh >/dev/null 2>&1 || return 1
  gh pr list --state merged --head "$1" --limit 1 \
    --json number,mergeCommit --jq '.[] | "\(.number) \(.mergeCommit.oid)"' 2>/dev/null
}

# 絞り込みは bash の case で行う。git for-each-ref のパターンは `*` がスラッシュを跨がず、
# 'sub/*' が sub/fix/xxx(3階層)を拾えないため
matches_pattern() {
  local name="$1" p
  for p in "${PATTERNS[@]}"; do
    # shellcheck disable=SC2254 -- $p は glob として評価させる
    case "$name" in $p) return 0 ;; esac
  done
  return 1
}

# パターンにブランチ名がそのまま渡されているか。glob として一致しただけでは名指しとみなさない
named_explicitly() {
  local name="$1" p
  for p in "${PATTERNS[@]}"; do
    [ "$p" = "$name" ] && return 0
  done
  return 1
}

BRANCHES=""
while IFS= read -r ref; do
  matches_pattern "$ref" && BRANCHES="${BRANCHES}${ref}"$'\n'
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)
[ -n "$BRANCHES" ] || { echo "対象パターン(${PATTERNS[*]})に一致するブランチはありません"; exit 0; }

DELETE_LIST=()   # "branch<TAB>方法<TAB>ワークツリー"
printf '%s\n' "base: $BASE ($(git rev-parse --short "$BASE"))"
printf '%s\n' "----------------------------------------------------------------"

while IFS= read -r b; do
  [ -n "$b" ] || continue
  sha="$(git rev-parse --short "$b")"
  wt="$(worktree_of "$b")"

  skip=""
  for p in "${PROTECTED_DEFAULT[@]}"; do [ "$b" = "$p" ] && skip="保護対象"; done
  # wip/ を glob の一致で拾わないのは、作業途中の置き場だから。コミットを積む前の wip は
  # 先端が base と同じ位置にあり、ancestor で取り込み済みと判定されてしまう
  case "$b" in wip/*) named_explicitly "$b" || skip="wip/ は名指し時のみ対象(--pattern $b)" ;; esac
  [ "$b" = "${BASE#origin/}" ] && skip="base 自身"
  [ "$b" = "$CURRENT" ] && skip="現在のワークツリーがチェックアウト中"
  if [ -n "$wt" ] && [ "$KEEP_WORKTREE" -eq 1 ]; then skip="ワークツリー有り(--keep-worktree)"; fi

  if [ -n "$skip" ]; then
    printf 'SKIP      %-34s %s  %s\n' "$b" "$sha" "$skip"
    continue
  fi

  method=""; evidence=""
  if git merge-base --is-ancestor "$b" "$BASE"; then
    method="ancestor"
    point="$(git rev-list --ancestry-path "$b..$BASE" 2>/dev/null | tail -1)"
    if [ -n "$point" ]; then
      evidence="取り込み $(git rev-parse --short "$point") $(git log -1 --format=%s "$point" | cut -c1-48)"
    else
      evidence="base と同一"
    fi
  else
    cherry="$(git cherry "$BASE" "$b" || true)"
    if [ -n "$cherry" ] && ! printf '%s\n' "$cherry" | grep -q '^+'; then
      method="patch-id"
      evidence="同じ変更が base に $(printf '%s\n' "$cherry" | grep -c '^-') 件"
    else
      pr="$(merged_pr_of "$b" || true)"
      if [ -n "$pr" ]; then
        method="pr"
        evidence="PR #${pr%% *} マージコミット $(git rev-parse --short "${pr##* }" 2>/dev/null || echo "${pr##* }")"
      fi
    fi
  fi

  if [ -z "$method" ]; then
    ahead="$(git rev-list --count "$BASE..$b")"
    printf 'KEEP      %-34s %s  未取り込み(base より %s コミット先行)\n' "$b" "$sha" "$ahead"
    continue
  fi

  printf 'DELETE    %-34s %s  [%s] %s\n' "$b" "$sha" "$method" "$evidence"
  [ -n "$wt" ] && printf '          %-34s        worktree: %s\n' "" "$wt"
  DELETE_LIST+=("$b	$method	$wt")
done <<< "$BRANCHES"

printf '%s\n' "----------------------------------------------------------------"

if [ ${#DELETE_LIST[@]} -eq 0 ]; then
  echo "削除対象はありません"
  exit 0
fi

if [ "$APPLY" -eq 0 ]; then
  echo "dry-run: ${#DELETE_LIST[@]} 件が削除対象。実行するには --apply を付けてください"
  exit 0
fi

# 登録の外れたワークツリーの残骸だけを消す。
# 「.git がファイルで、その gitdir 先が既に無い」= git から切り離された残骸、という
# 検証できる条件を満たすときしか rm しない(通常のリポジトリや作業中ディレクトリを守る)
remove_orphan_dir() {
  local dir="$1" gitdir
  [ -n "$dir" ] && [ -d "$dir" ] || return 0
  if [ ! -f "$dir/.git" ]; then
    echo "warning  ワークツリーの実体が残っています(手動で確認): $dir" >&2
    return 0
  fi
  gitdir="$(sed -n 's/^gitdir: //p' "$dir/.git")"
  if [ -n "$gitdir" ] && [ ! -d "$gitdir" ]; then
    rm -rf "$dir"
    echo "removed  worktree(残骸)   $dir"
  else
    echo "warning  ワークツリーの実体が残っています(手動で確認): $dir" >&2
  fi
}

# ブランチ 1 本を片付ける。ワークツリー → ブランチ → origin の順。
# 呼び出し側が成否を見るので、途中で失敗したらそこで戻る(set -e はこの関数内では効かない)。
delete_one() {
  local b="$1" wt="$2"

  if [ -n "$wt" ]; then
    # ワークツリーの管理主体は gwq に一本化する([[git-worktree]])。ただし gwq は
    # 途中で失敗しても 0 を返し、登録・ディレクトリ・ブランチが中途半端に残ることがある。
    # 成否は戻り値ではなく、この後の実地確認で判定する
    if command -v gwq >/dev/null 2>&1; then
      command gwq remove -b "$b" >/dev/null 2>&1 || true
    fi
    if [ -n "$(worktree_of "$b")" ]; then
      git worktree remove --force "$wt" || return 1
    fi
    git worktree prune
    if [ -d "$wt" ]; then
      remove_orphan_dir "$wt"
    else
      echo "removed  worktree         $wt"
    fi
  fi

  if git show-ref --verify --quiet "refs/heads/$b"; then
    # 常に -D を使う。-d は「HEAD(かその upstream)に入っているか」を見るので、
    # --base に HEAD 以外を渡すと取り込み済みでも "not fully merged" で拒む。
    # 見るべきは --base への取り込みで、それは上の 3 段の突合で確定済みである。
    git branch -D "$b" >/dev/null || return 1
    echo "removed  branch           $b"
  else
    echo "removed  branch           $b (gwq が削除済み)"
  fi

  if [ "$REMOTE" -eq 1 ] && git rev-parse --verify --quiet "origin/$b" >/dev/null; then
    git push --quiet origin --delete "$b" || return 1
    echo "removed  origin           $b"
  fi
  return 0
}

# 1 本の失敗で残りを放置しない。ワークツリーだけ消えてブランチが残る、といった
# 中途半端な状態を作らないため、失敗は記録して次のブランチへ進む
FAILED=()
for entry in "${DELETE_LIST[@]}"; do
  b="${entry%%	*}"; rest="${entry#*	}"
  wt="${rest#*	}"

  if delete_one "$b" "$wt"; then
    :
  else
    echo "failed   branch           $b (手動で確認してください)" >&2
    FAILED+=("$b")
  fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
  # 「完了 N 件」だと何も起きなかったように読めるので、最後まで片付いた数と
  # 手当てが要るブランチを分けて出す(途中まで進んでいることがある)
  echo "最後まで片付いたのは $(( ${#DELETE_LIST[@]} - ${#FAILED[@]} ))/${#DELETE_LIST[@]} 件" >&2
  echo "手動で確認: ${FAILED[*]}" >&2
  exit 1
fi

echo "完了: ${#DELETE_LIST[@]} 件"
