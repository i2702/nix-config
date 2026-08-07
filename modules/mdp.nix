{ pkgs, ... }:
{
  # mdp: Markdown をブラウザでプレビューする。
  #
  # 変換はブラウザ側の markdown-it が行い、nix が用意するのは
  # 「本文を配るサーバ (server.py)」と「描画するページ (template.html)」だけ。
  # そのため見た目の調整は template.html の書き換えだけで完結し、
  # Haskell や node のツールチェインを持ち込まずに GitHub 相当の表示ができる。
  #
  # CSS/JS は jsdelivr から読むためオフラインでは配色と図が崩れる。
  # バージョンは template.html 側で固定している。
  home.packages = [
    (pkgs.writeShellApplication {
      name = "mdp";
      runtimeInputs = [ pkgs.python3 pkgs.coreutils ];
      text = ''
        usage() {
          cat <<'HELP'
        mdp - Markdown をブラウザでプレビューする

          mdp [オプション] [ファイル]

        ファイルを省略すると README.md を開く。保存すると表示も追従する。
        ブラウザのタブを閉じるとサーバは自動で終了する。

        オプション:
          -p, --port PORT  ポートを固定する (既定: 空きポートを自動で選ぶ)
          -n, --no-open    ブラウザを開かず URL だけ表示する
          -h, --help       このヘルプを表示する
        HELP
        }

        file=README.md
        port=
        open_browser=1

        while [ $# -gt 0 ]; do
          case $1 in
            -p|--port)
              [ $# -ge 2 ] || { echo "mdp: $1 にはポート番号が必要 ⚠️" >&2; exit 2; }
              port=$2
              shift 2
              ;;
            -n|--no-open) open_browser=0; shift ;;
            -h|--help) usage; exit 0 ;;
            --) shift; break ;;
            -*) echo "mdp: 不明なオプション: $1 ⚠️" >&2; exit 2 ;;
            *) file=$1; shift ;;
          esac
        done
        [ $# -eq 0 ] || file=$1

        if [ ! -f "$file" ]; then
          echo "mdp: ファイルがない: $file ⚠️" >&2
          exit 1
        fi

        # ポート未指定なら空きを1つ借りて即座に返す。借りてから listen するまでの
        # 間に他プロセスに取られる可能性は残るが、実用上は無視できる。
        if [ -z "$port" ]; then
          port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')
        fi

        # ブラウザを閉じたらサーバも終わるので、端末は待たずに解放する。
        nohup python3 ${./mdp/server.py} "$file" "$port" ${./mdp/template.html} \
          >/dev/null 2>&1 &
        disown

        url="http://127.0.0.1:$port/"

        # listen 開始前にブラウザを開くと接続拒否になるので、繋がるまで待つ。
        ready=0
        for _ in {1..100}; do
          if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
            ready=1
            break
          fi
          sleep 0.05
        done
        if [ "$ready" -eq 0 ]; then
          echo "mdp: サーバが起動しない (port $port) ⚠️" >&2
          exit 1
        fi

        echo "📖 $(basename "$file")"
        echo "🌐 $url"

        if [ "$open_browser" -eq 1 ]; then
          if command -v wslview >/dev/null 2>&1; then
            wslview "$url"
          elif [ -x /mnt/c/Windows/explorer.exe ]; then
            # explorer.exe は正常に開いても終了コード 1 を返すことがある
            /mnt/c/Windows/explorer.exe "$url" >/dev/null 2>&1 || true
          elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$url" >/dev/null 2>&1
          elif command -v open >/dev/null 2>&1; then
            open "$url"
          else
            echo "mdp: ブラウザを開く方法が見つからない。上の URL を手で開くこと 💡" >&2
          fi
        fi
      '';
    })
  ];
}
