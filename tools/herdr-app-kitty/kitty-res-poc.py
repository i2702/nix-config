#!/usr/bin/env python3
"""Kitty graphics の解像度を端末ごとに比べる PoC。

調べること:
  1. 端末が申告するピクセル寸法 (CSI 14t / 16t / TIOCGWINSZ)。プログラムはこれを見て
     画像を何ピクセルで作るか決める。Retina で論理ピクセルを申告していれば、
     どのプログラムも半分の解像度で画像を作る。
  2. 自然サイズ配置 (c/r 無し) で画像が何セル占めるか。端末が「画像 1px = 何デバイスpx」
     と解釈しているかが分かる。
  3. 同じセル範囲に 1x / 2x / 3x の画像を c/r 指定で並べる。端末が物理ピクセルで
     描いていれば 2x 以上で縞が潰れずに見え、論理ピクセルへ縮めてから描いていれば
     1x と見分けがつかない。

使い方: python3 kitty-res-poc.py [--json out.json]
Ghostty と herdr-app で実行し、表示と JSON を突き合わせる。
"""
import base64
import fcntl
import json
import os
import re
import select
import struct
import sys
import termios
import tty
import zlib

ESC = "\x1b"
ST = ESC + "\\"


def png(width, height, pixel):
    """pixel(x, y) -> (r, g, b) から RGB PNG を作る。"""
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


def stripes(width, height, border=1):
    """画像 1px 幅の縞。左: 縦縞 / 中: 横縞 / 右: 市松。"""
    def pixel(x, y):
        third = x * 3 // width
        if third == 0:
            on = x % 2
        elif third == 1:
            on = y % 2
        else:
            on = (x + y) % 2
        # 外周の赤枠で画像の端がどこまで描かれているか分かるようにする。
        # 太さは倍率と同じ画像px にし、縮小後も 1 物理px 残るようにする
        if min(x, y, width - 1 - x, height - 1 - y) < border:
            return (255, 0, 0)
        return (255, 255, 255) if on else (0, 0, 0)
    return pixel


def grid(x, y):
    """10px 格子。自然サイズ配置の占有セル数を測るのに使う。"""
    if x % 10 == 0 or y % 10 == 0:
        return (0, 200, 255)
    return (30, 30, 30)


def send_image(data, image_id, cols=None, rows=None, keep_cursor=False):
    """PNG を直接送信 (t=d) で転送して即配置する。4096 バイトごとに分割する。"""
    b64 = base64.standard_b64encode(data).decode()
    keys = f"a=T,f=100,i={image_id},q=2"
    if cols:
        keys += f",c={cols},r={rows}"
    if keep_cursor:
        keys += ",C=1"
    chunks = [b64[i:i + 4096] for i in range(0, len(b64), 4096)]
    out = []
    for n, part in enumerate(chunks):
        more = 1 if n < len(chunks) - 1 else 0
        head = keys + f",m={more}" if n == 0 else f"m={more}"
        out.append(f"{ESC}_G{head};{part}{ST}")
    sys.stdout.write("".join(out))
    sys.stdout.flush()


def query(fd, seq, timeout=1.0, linger=0.0):
    """問い合わせを送り、DA1 の応答が返るまで読む。DA1 は全端末が返すので終端の目印にする。

    linger 秒は DA1 の後も読み続ける。DA1 より後に返す端末 (herdr-app の a=q) の
    応答を拾い、順序の誤りとして判定できるようにするため。
    """
    os.write(fd, (seq + ESC + "[c").encode())
    buf = b""
    while not re.search(rb"\x1b\[\?[\d;]*c", buf):
        r, _, _ = select.select([fd], [], [], timeout)
        if not r:
            break
        buf += os.read(fd, 4096)
    while linger and select.select([fd], [], [], linger)[0]:
        buf += os.read(fd, 4096)
    return buf.decode(errors="replace")


def cursor_row(fd):
    m = re.search(r"\x1b\[(\d+);(\d+)R", query(fd, ESC + "[6n"))
    return int(m.group(1)) if m else None


def main():
    fd = sys.stdin.fileno()
    report = {"TERM": os.environ.get("TERM"), "TERM_PROGRAM": os.environ.get("TERM_PROGRAM")}

    ws = struct.unpack("HHHH", fcntl.ioctl(fd, termios.TIOCGWINSZ, b"\0" * 8))
    report["winsize"] = {"rows": ws[0], "cols": ws[1], "xpixel": ws[2], "ypixel": ws[3]}

    old = termios.tcgetattr(fd)
    tty.setcbreak(fd)
    try:
        ans = query(fd, f"{ESC}_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA{ST}"
                        f"{ESC}[14t{ESC}[16t{ESC}[18t", linger=3.0)
        report["raw"] = ans.encode("unicode_escape").decode()
        report["kitty_graphics"] = "OK" in ans if "_Gi=31" in ans else None
        # ratatui-image などは最後に送った DA1/DSR の応答で読み終えるので、それより後の応答は無いのと同じ
        da1 = re.search(r"\x1b\[\?[\d;]*c", ans)
        report["kitty_reply_after_da1"] = bool(da1 and "_Gi=31" in ans and ans.index("_Gi=31") > da1.start())
        for name, code in (("window_px", "4"), ("cell_px", "6"), ("cells", "8")):
            m = re.search(rf"\x1b\[{code};(\d+);(\d+)t", ans)
            report[name] = {"h": int(m.group(1)), "w": int(m.group(2))} if m else None

        if report["cell_px"]:
            cw, ch = report["cell_px"]["w"], report["cell_px"]["h"]
        elif ws[2]:
            cw, ch = ws[2] // ws[1], ws[3] // ws[0]
        else:
            cw, ch = 10, 20
        report["cell_px_used"] = {"w": cw, "h": ch}

        # --- 判定できる項目は自動で判定する (プログラムが画像の解像度を決める材料)
        ok, ng = "\x1b[32m OK \x1b[0m", "\x1b[41;97m NG \x1b[0m"
        print("\n=== 1. 端末の申告 (自動判定) ===")
        print("  画像を表示するプログラムは、ここで返る値を見て画像を何ピクセルで作るか決める。")
        print(f"  [{ok if report['kitty_graphics'] else ng}] Kitty graphics の対応問い合わせ (a=q) に応答する"
              f"  → 応答なし: 問い合わせるプログラム (yazi, ratatui-image 等) は非対応と見てブロック文字表示に落ちる")
        if report["kitty_graphics"]:
            print(f"  [{ng if report['kitty_reply_after_da1'] else ok}] a=q の応答が後続の DA1 の応答より先に返る"
                  f"  → 後: DA1/DSR の応答で読み終えるプログラムは取りこぼし、応答なしと同じになる")
        print(f"  [{ok if ws[2] else ng}] TIOCGWINSZ のピクセル寸法 = {ws[2]}x{ws[3]}"
              f"  → 0: chafa/timg/viu 等はフォント寸法を仮定し、小さい画像を作って拡大表示する (ぼやける)")
        print(f"  [{ok if report['cell_px'] else ng}] CSI 16t のセル寸法 = "
              f"{f'{cw}x{ch}px' if report['cell_px'] else '応答なし'}")
        print(f"  [ i ] TERM={report['TERM']} TERM_PROGRAM={report['TERM_PROGRAM']}"
              f"  → 端末名で能力を決めるプログラムはこれを見る")

        # --- 2. 自然サイズ配置: 200x(ch*5)px の画像は申告どおりなら 5 行を占め、カーソルは最終行に残る
        print(f"\n=== 2. 自然サイズ配置 (c/r 指定なし) 200x{ch * 5}px ===")
        print(f"  見ること: 格子が幅 {200 / cw:.1f} 列 x 高さ 5 行に収まる。水色の線 (10px 間隔) が 1px でくっきり見える。")
        before = cursor_row(fd)
        send_image(png(200, ch * 5, grid), 1)
        after = cursor_row(fd)
        print()
        if before and after:
            report["natural_rows"] = after - before
            print(f"  [{ok if after - before == 4 else ng}] 配置後のカーソル移動 = {after - before} 行 (期待 4 行: 画像の最終行に残る)"
                  f"  → 0: カーソルが画像の下へ進まず、後続の文字が画像に重なるおそれ")

        # --- 3. 同じ 12x6 セルに 1x / 2x / 3x を横に並べる (C=1 でカーソルを動かさず、右へずらして置く)
        cols, rows = 12, 6
        print(f"\n=== 3. 同じ {cols}x{rows} セルに 1x / 2x / 3x の 1px 縞を並べる (各画像: 縦縞 | 横縞 | 市松, 赤枠) ===")
        print("  見ること (拡大鏡 or 等倍スクショで):")
        print("    - 1x が白黒の縞としてくっきり見える → 端末は申告どおり物理ピクセルで描いている (正常)")
        print("    - 2x / 3x は 1 物理px より細い縞なので、面積平均で縮小すれば一様な灰色になるのが正しい")
        print("      3x が白黒の縞のまま見える → 縮小が 1 点サンプリング (ミップマップ無しのバイリニア等) で、")
        print("      画素を間引いている。細い線が消え、縮小表示した写真やスクショがギザついて粗く見える原因になる")
        print("    - 1x まで灰色/ぼやけ → 端末が画像を論理ピクセルへ縮めてから描いている (herdr-app 側の問題)")
        print("    - 赤枠 (どの倍率でも縮小後 1 物理px の太さ) が四辺とも見える → 画像の端が切れていない")
        print("      欠ける辺があれば、縮小時に端の行・列を落としている (セル境界への丸めか、サンプリング位置のずれ)")
        print()
        print("".join(f"{f' {s}x: {cols * cw * s}x{rows * ch * s}px':<{cols + 4}}" for s in (1, 2, 3)))
        # C=1 ではスクロールしないので、画面下端でも収まるよう先に行を空けておく
        sys.stdout.write("\n" * rows + f"\x1b[{rows}A")
        for i, s in enumerate((1, 2, 3)):
            w, h = cols * cw * s, rows * ch * s
            sys.stdout.write("\x1b[s")
            send_image(png(w, h, stripes(w, h, s)), 10 + i, cols, rows, keep_cursor=True)
            sys.stdout.write(f"\x1b[u\x1b[{cols + 4}C" if i < 2 else "")
        sys.stdout.write("\r" + "\n" * (rows + 1))
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

    if "--json" in sys.argv:
        with open(sys.argv[sys.argv.index("--json") + 1], "w") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
