#!/usr/bin/env python3
"""mdp のプレビューサーバ。

Markdown → HTML の変換はブラウザ側 (markdown-it) が担当する。このサーバは
「本文を配るだけ」に徹しており、見た目に関する調整は template.html の変更だけで
完結する。

ドキュメントルートを対象 Markdown と同じディレクトリに置いているため、
本文中の相対パス画像やリンクがそのまま解決できる。

ブラウザからのポーリングが途切れたら自身を終了する。タブを閉じれば片付くので、
プレビューのたびにプロセスが残り続けることがない。
"""

from __future__ import annotations

import hashlib
import http.server
import json
import os
import sys
import threading
import time
import urllib.parse

# ポーリングが途切れてから終了するまでの猶予。
# ブラウザは背面のタブのタイマーを最大 60 秒まで間引くため、それより十分長く取る。
# 短くするとタブを切り替えて戻ってきただけでサーバが落ちる。
IDLE_TIMEOUT = 90.0
# 最初のポーリングが届くまでの猶予。Windows 側のブラウザは初回起動が遅いので長めに取る。
STARTUP_GRACE = 180.0
# ブラウザ側のポーリング間隔 (秒)。template.html と揃える。
POLL_INTERVAL = 1.0


class Document:
    """プレビュー対象の Markdown ファイル。

    内容が変わったかどうかは mtime ではなく本文のハッシュで判定する。
    エディタによる保存は mtime を動かさずに書き換えることがあるうえ、
    保存し直しただけの再描画も避けたいため。
    """

    def __init__(self, path: str) -> None:
        self.path = os.path.abspath(path)

    @property
    def name(self) -> str:
        return os.path.basename(self.path)

    @property
    def directory(self) -> str:
        return os.path.dirname(self.path) or "."

    def snapshot(self) -> dict[str, str]:
        with open(self.path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        return {
            "name": self.name,
            "text": text,
            "digest": hashlib.sha256(text.encode("utf-8")).hexdigest(),
        }


class Watchdog:
    """一定時間ポーリングが無ければサーバを止める見張り役。"""

    def __init__(self, server: http.server.HTTPServer) -> None:
        self._server = server
        self._lock = threading.Lock()
        self._deadline = time.monotonic() + STARTUP_GRACE

    def beat(self) -> None:
        with self._lock:
            self._deadline = time.monotonic() + IDLE_TIMEOUT

    def run(self) -> None:
        while True:
            with self._lock:
                remaining = self._deadline - time.monotonic()
            if remaining <= 0:
                self._server.shutdown()
                return
            time.sleep(min(remaining, POLL_INTERVAL))


class Handler(http.server.SimpleHTTPRequestHandler):
    """テンプレート・本文・同階層の静的ファイルの3つだけを返す。

    document / template / watchdog はサブクラス生成時に注入する
    (SimpleHTTPRequestHandler はリクエストごとにインスタンス化されるため、
     コンストラクタ引数で状態を渡せない)。
    """

    document: Document
    template: bytes
    watchdog: Watchdog

    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, directory=self.document.directory, **kwargs)

    def do_GET(self) -> None:  # noqa: N802 (基底クラスの命名に従う)
        route = urllib.parse.urlparse(self.path)
        if route.path == "/":
            self._send(200, "text/html; charset=utf-8", self.template)
        elif route.path == "/__mdp/src":
            self.watchdog.beat()
            self._send_source(urllib.parse.parse_qs(route.query))
        else:
            super().do_GET()

    def _send_source(self, query: dict[str, list[str]]) -> None:
        try:
            snapshot = self.document.snapshot()
        except OSError as e:
            self._send_json({"error": f"{self.document.name}: {e.strerror}"})
            return

        # ブラウザが持っている版と同じなら本文を送り返さない。
        # ポーリングの大半はこの分岐に落ちる。
        if query.get("digest", [""])[0] == snapshot["digest"]:
            self._send_json({"unchanged": True})
        else:
            self._send_json(snapshot)

    def _send_json(self, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self._send(200, "application/json; charset=utf-8", body)

    def _send(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args) -> None:
        """アクセスログは出さない。毎秒のポーリングで端末が埋まるため。"""


def main(argv: list[str]) -> int:
    md_path, port, template_path = argv[1], int(argv[2]), argv[3]

    document = Document(md_path)
    with open(template_path, "rb") as f:
        template = f.read()

    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    watchdog = Watchdog(server)
    # 型としては Handler のサブクラスを都度作るのが素直だが、
    # ThreadingHTTPServer に渡す時点で1種類しか要らないので直接属性を差す。
    Handler.document = document
    Handler.template = template
    Handler.watchdog = watchdog

    threading.Thread(target=watchdog.run, daemon=True).start()
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
