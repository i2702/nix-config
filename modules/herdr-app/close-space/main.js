// 表示中の space を確認ダイアログ無しで閉じる。keys.json の "alt-w": "mod.open:close-space" で開かれる。
// mod を挟む理由: キー割り当ては `name:value` でコマンドの最初の引数(space.close なら id)しか渡せず、
// 確認を飛ばす confirmed: true を指定できない。開き方と閉じ方は autotile と同じ。
import { View, div } from "gpui-kit";
import { closeOverlay, focused, props, run } from "herdr";

export default class CloseSpace extends View {
  init() {
    // オーバーレイ以外(herdr-app check など)で読み込まれたときは何もしない
    const overlay = props()?.overlay;
    if (!overlay) return;
    const space = focused()?.space;
    closeOverlay(overlay);
    if (space) run("space.close", { id: space, confirmed: true });
  }

  render() {
    return div();
  }
}
