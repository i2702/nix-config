// 表示中の space と同じマシンに新しい space を作る。keys.json の "alt-n": "mod.open:new-space" で開かれる。
// mod を挟む理由: space.new を引数なしで呼ぶと常に手元(This computer)に作られ、WSL などのマシンの
// space で作業していても手元に作ってしまう。キー割り当ては最初の引数(name)しか渡せず machine を指定できない。
// 開き方と閉じ方は autotile と同じ。
//
// Windows では手元をサイドバーに出さない(spaces-remote 参照)ので、表示中の space が手元のときや
// space が無いときも手元には作らず、最初のマシンに作る。
import { View, div } from "gpui-kit";
import { closeOverlay, focused, machines, props, run, spaces, window } from "herdr";

function targetMachine() {
  const space = spaces().find((s) => s.id === focused()?.space);
  if (space?.machine) return space.machine;
  if (window().platform !== "windows") return null;
  return machines().find((m) => m.name && m.layout === "ready")?.name ?? null;
}

export default class NewSpace extends View {
  init() {
    // オーバーレイ以外(herdr-app check など)で読み込まれたときは何もしない
    const overlay = props()?.overlay;
    if (!overlay) return;
    const machine = targetMachine();
    closeOverlay(overlay);
    run("space.new", machine ? { machine } : {});
  }

  render() {
    return div();
  }
}
