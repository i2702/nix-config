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
// exec に標準入力を渡す手段が無いので、シェルのパイプで流し込む。
//
// オーバーレイとして開く理由: `<mod>.<command>` のキー割り当ては表示中の mod にしか届かず、
// 常駐させるにはレイアウトに場所を取るブロックが要る。mod.open なら開いたときだけ動ける。
import { View, div } from "gpui-kit";
import { closeOverlay, exec, focused, notify, props, run, spaces, window } from "herdr";

const THRESHOLD = 0.6;

// Windows の手元で hc connect に1行送って1行受け取る PowerShell スクリプト。
// パイプ(`'...' | hc connect`)にしない理由: Windows 版の hc connect は標準入力が EOF になると
// 応答を書く前に終了し、出力が空になる(Linux 版は応答してから終わる)。応答を読むまで stdin を開けておく。
// 応答は UTF-8 のバイト列のまま stdout へ書く。Console 経由だと CP932 に変換され、日本語の space 名が化ける。
function powershellDocGet(req) {
  return [
    "$s = New-Object System.Diagnostics.ProcessStartInfo 'hc', 'connect'",
    "$s.UseShellExecute = $false",
    "$s.RedirectStandardInput = $true",
    "$s.RedirectStandardOutput = $true",
    "$s.StandardOutputEncoding = [System.Text.Encoding]::UTF8",
    "$p = [System.Diagnostics.Process]::Start($s)",
    `$p.StandardInput.WriteLine('${req}')`,
    "$p.StandardInput.Flush()",
    "$b = [System.Text.Encoding]::UTF8.GetBytes($p.StandardOutput.ReadLine() + \"`n\")",
    "$p.StandardInput.Close()",
    "$p.WaitForExit()",
    "$o = [Console]::OpenStandardOutput()",
    "$o.Write($b, 0, $b.Length)",
    "$o.Flush()",
  ].join("\n");
}

// -EncodedCommand に渡す形(UTF-16LE を base64 にしたもの)。-Command に文字列で渡さない理由:
// 引数のクォートが exec と powershell.exe の2段で解釈され、JSON の " が崩れるおそれがあるため。
function encodePowerShell(script) {
  const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  const bytes = [];
  for (let i = 0; i < script.length; i++) {
    const c = script.charCodeAt(i);
    bytes.push(c & 0xff, c >> 8);
  }
  let out = "";
  for (let i = 0; i < bytes.length; i += 3) {
    const n = (bytes[i] << 16) | ((bytes[i + 1] ?? 0) << 8) | (bytes[i + 2] ?? 0);
    out += B64[n >> 18] + B64[(n >> 12) & 63];
    out += i + 1 < bytes.length ? B64[(n >> 6) & 63] : "=";
    out += i + 2 < bytes.length ? B64[n & 63] : "=";
  }
  return out;
}

// 別マシンの space でも hc connect は手元で動かし、params.on で手元の core から中継させる。
// exec の on でそのマシン上の sh に hc connect させない理由: core 経由の sh は PATH に
// ~/.local/bin(hc の置き場)を含まず、hc が見つからない。
// 手元に sh の無い Windows は PowerShell で送る(JSON に ' は含まれないので '...' に埋め込める)。
async function readLayoutDoc(machine) {
  const params = { name: "herdr-app" };
  if (machine) params.on = machine;
  const req = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "doc.get", params });
  const r =
    window().platform === "windows"
      ? await exec("powershell", ["-NoProfile", "-NonInteractive", "-EncodedCommand", encodePowerShell(powershellDocGet(req))])
      : await exec("sh", ["-c", 'printf "%s\\n" "$1" | hc connect', "sh", req]);
  const last = r.stdout.trim().split("\n").pop();
  if (!last) throw new Error(`hc connect の応答が空 (exit ${r.code}): ${r.stderr.trim()}`);
  const res = JSON.parse(last);
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
