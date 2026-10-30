// 自動タイル分割。keys.json の "alt-s": "mod.open:autotile" で開かれ、分割したらすぐ閉じる。
// フォーカス中のペインを起点に 2x2 グリッドを作る:
//   タブの全幅を占めている(まだ縦に割られていない)なら右へ、全幅は無いが全高を占めているなら下へ割る。
//   フォーカス中が既に 1/4 サイズなら、まだ 1/4 でない他のペインのうち最大のものを代わりに割り、
//   全部 1/4(= 4分割済み)なら何もしない。
// 「全幅/全高を占めるか」を分割ツリーの形ではなく面積比(0.6 超)で見る理由: 4分割済みかどうかは
// 面積の話で、左右と上下のどちらを先に割ったかとは独立に決まるため。
//
// ペインの大きさは herdr-core の "herdr-app" ドキュメント(space > tab > row/column の分割ツリー)から
// 求める。mod の API(panes())はペインの位置も大きさも返さないため。
// ドキュメントは hc CLI に取得コマンドが無く、`hc connect`(API を stdin/stdout で話す)に doc.get を送る。
//
// オーバーレイとして開く理由: `<mod>.<command>` のキー割り当ては表示中の mod にしか届かず、
// 常駐させるにはレイアウトに場所を取るブロックが要る。mod.open なら開いたときだけ動ける。
import { View, div } from "gpui-kit";
import { closeOverlay, exec, focused, notify, props, run, spaces } from "herdr";

const THRESHOLD = 0.6;

async function readLayoutDoc(machine) {
  const params = { name: "herdr-app" };
  if (machine) params.on = machine;
  const req = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "doc.get", params });
  const r = await exec("sh", ["-c", 'printf "%s\\n" "$1" | hc connect', "sh", req]);
  const res = JSON.parse(r.stdout.trim().split("\n").pop());
  if (res.error) throw new Error(res.error.message);
  return res.result.value;
}

// 分割ツリーを辿り、各ペイン(block)がタブ全体に占める幅と高さの比を求める。
// weight の無い子は 1 として兄弟と按分する(1子だけの row は size を持たない)。
function blockRects(node, w, h, out) {
  if (node.type === "block") {
    out.push({ pane: node.id, w, h });
    return out;
  }
  const children = node.children ?? [];
  const weights = children.map((c) => c.size?.weight ?? 1);
  const total = weights.reduce((a, b) => a + b, 0) || 1;
  children.forEach((c, i) => {
    const f = weights[i] / total;
    if (node.type === "row") blockRects(c, w * f, h, out);
    else if (node.type === "column") blockRects(c, w, h * f, out);
    // stack などは子が重なって表示されるので、どの子もそのままの大きさ
    else blockRects(c, w, h, out);
  });
  return out;
}

function directionOf(r) {
  if (r.w > THRESHOLD) return "right";
  if (r.h > THRESHOLD) return "down";
  return null;
}

async function autotile() {
  const f = focused();
  if (!f?.pane) return;
  const space = spaces().find((s) => s.id === f.space);
  // 別マシンの space は id に "<machine>/" が付くが、ドキュメント内は素の id
  const bare = (id) => id.slice(id.lastIndexOf("/") + 1);
  const doc = await readLayoutDoc(space?.machine);
  const tab = doc.spaces
    .find((s) => s.id === bare(f.space))
    ?.tabs.find((t) => t.id === bare(f.tab));
  if (!tab) return;

  const rects = blockRects(tab.root, 1, 1, []).map((r) => ({ ...r, dir: directionOf(r) }));
  const target =
    rects.find((r) => r.pane === bare(f.pane) && r.dir) ??
    rects.filter((r) => r.dir).sort((a, b) => b.w * b.h - a.w * a.h)[0];
  if (!target) return;
  const prefix = f.pane.slice(0, f.pane.length - bare(f.pane).length);
  run("pane.split", { pane: prefix + target.pane, direction: target.dir });
}

export default class AutoTile extends View {
  init(_props, cx) {
    // オーバーレイ以外(herdr-app check など)で読み込まれたときは何もしない
    const overlay = props()?.overlay;
    if (!overlay) return;
    // 閉じるのは分割の後。先に閉じるとこの mod が破棄され、走り始めた処理ごと打ち切られる。
    cx.spawn(async () => {
      try {
        await autotile();
      } catch (e) {
        notify({ title: "autotile", body: String(e), level: "error" });
      } finally {
        closeOverlay(overlay);
      }
    });
  }

  render() {
    return div();
  }
}
