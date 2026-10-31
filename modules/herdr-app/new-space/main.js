// 表示中の space と同じマシンに新しい space を作る。keys.json の "alt-n": "mod.open:new-space" で開かれる。
// mod を挟む理由: space.new を引数なしで呼ぶと常に手元(This computer)に作られ、WSL などのマシンの
// space で作業していても手元に作ってしまう。キー割り当ては最初の引数(name)しか渡せず machine を指定できない。
// 表示中の space が手元なら手元に作る(space が無いときも手元)。開き方と閉じ方は autotile と同じ。
import { View, div } from "gpui-kit";
import { closeOverlay, focused, props, run, spaces } from "herdr";

export default class NewSpace extends View {
  init() {
    // オーバーレイ以外(herdr-app check など)で読み込まれたときは何もしない
    const overlay = props()?.overlay;
    if (!overlay) return;
    const machine = spaces().find((s) => s.id === focused()?.space)?.machine;
    closeOverlay(overlay);
    run("space.new", machine ? { machine } : {});
  }

  render() {
    return div();
  }
}
