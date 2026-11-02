// サイドバーの表示順で space を前後へ移動する。space-next / space-prev の共通部分。
// 組み込みの space.next / space.prev は space の登録順で動くが、同梱の spaces mod は worktree の space を
// 本体の space の直下へ移して表示するため、ネストがあると両者の順番がずれる。
//
// 表示順を組み込みコマンドへ渡す手段が無い(agent.next の setAgentOrder に当たる API が space には無い)ので、
// この mod が space.select で移動先を直接選ぶ。
// spaces mod を複製して順番を共有しない理由(Why not): 同梱 mod を更新のたびに取り込み直す必要が生まれる。
// space.move で実際の並びを揃えない理由(Why not): ターミナルが worktree に出入りするだけで、
// 利用者が決めた並びが書き換わったまま戻らなくなる。
import { View, div } from "gpui-kit";
import { closeOverlay, exec, focused, notify, panes, props, run, spaces } from "herdr";

// 接続が切れたマシンの応答を待ち続けてキー操作を止めないための上限。手元と WSL の git は 20ms 程度で返る。
const GIT_TIMEOUT_MS = 800;

// 判定は同梱の spaces mod(0.1.11)の place() / check() / ordered() に合わせている。
// 表示順がずれるようになったら、まず同 mod の変更を確認する。
function place(space, allPanes) {
  const tabs = new Set((space.tabs ?? []).map((tab) => tab.id));
  return allPanes.find((pane) => tabs.has(pane.tab) && pane.cwd)?.cwd || space.folder;
}

async function readGit(on, cwd) {
  const r = await exec("git", ["rev-parse", "--show-toplevel", "--path-format=absolute", "--git-common-dir"], { cwd, on });
  if (r.code !== 0) return null;
  const [top, repo] = r.stdout.trim().split("\n");
  return { repo: JSON.stringify([on, repo]), linked: repo !== `${top}/.git` };
}

// git に答えてもらえなかった space は repo 外と同じ扱いにする(ネストせず登録順の位置に置く)。
function readGitWithin(cx, on, cwd) {
  const expired = new Promise((resolve) => cx.timer.after(GIT_TIMEOUT_MS, () => resolve(null)));
  return Promise.race([readGit(on, cwd).catch(() => null), expired]);
}

async function displayOrder(cx) {
  const allSpaces = spaces();
  const allPanes = panes();
  const queries = new Map();
  const list = allSpaces.map((space) => {
    const on = space.machine ?? null;
    const cwd = place(space, allPanes);
    const key = JSON.stringify([on, cwd]);
    if (!queries.has(key)) queries.set(key, readGitWithin(cx, on, cwd));
    return { space, git: queries.get(key) };
  });
  const rows = await Promise.all(list.map(async ({ space, git }) => ({ space, git: await git })));

  const mains = new Set(rows.filter((r) => r.git && !r.git.linked).map((r) => r.git.repo));
  const nested = (r) => r.git?.linked && mains.has(r.git.repo);
  const placed = new Set();
  const order = [];
  for (const r of rows) {
    if (nested(r)) continue;
    order.push(r.space.id);
    if (!r.git || r.git.linked || placed.has(r.git.repo)) continue;
    placed.add(r.git.repo);
    for (const kid of rows) if (nested(kid) && kid.git.repo === r.git.repo) order.push(kid.space.id);
  }
  return order;
}

async function step(direction, cx) {
  const order = await displayOrder(cx);
  const current = order.indexOf(focused()?.space);
  if (current < 0) return;
  const next = (current + direction + order.length) % order.length;
  run("space.select", { id: order[next] });
}

export function spaceStepView(direction, name) {
  return class SpaceStep extends View {
    init(_props, cx) {
      // オーバーレイ以外(herdr-app check など)で読み込まれたときは何もしない
      const overlay = props()?.overlay;
      if (!overlay) return;
      // 閉じるのは移動の後。先に閉じるとこの mod が破棄され、走り始めた処理ごと打ち切られる。
      cx.spawn(async (cx) => {
        try {
          await step(direction, cx);
        } catch (e) {
          notify({ title: name, body: String(e), level: "error" });
        } finally {
          closeOverlay(overlay);
        }
      });
    }

    render() {
      return div();
    }
  };
}
