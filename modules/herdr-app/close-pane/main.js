// フォーカス中のペインを確認ダイアログ無しで閉じる。keys.json の "alt-q": "mod.open:close-pane" で開かれる。
// pane.close が確認を求めるのは、タブ最後のペインで space ごと消えるときだけ(他のペインがあれば確認無しで閉じる)。
// pane.close には confirmed 引数が無いので、タブ最後のペインなら tab.close {confirmed: true} で閉じる
// (最後のタブなら space も閉じる)。開き方と閉じ方は autotile と同じ。
import { View, div } from "gpui-kit";
import { closeOverlay, focused, props, run, spaces } from "herdr";

export default class ClosePane extends View {
  init() {
    // オーバーレイ以外(herdr-app check など)で読み込まれたときは何もしない
    const overlay = props()?.overlay;
    if (!overlay) return;
    const f = focused();
    closeOverlay(overlay);
    if (!f?.pane) return;
    const tab = spaces()
      .find((s) => s.id === f.space)
      ?.tabs.find((t) => t.id === f.tab);
    if (tab?.panes === 1) run("tab.close", { id: f.tab, confirmed: true });
    else run("pane.close", { pane: f.pane });
  }

  render() {
    return div();
  }
}
