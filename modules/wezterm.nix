{ pkgs, lib, ... }:
let
  # WezTermはWindows側のアプリケーション(WSLのUbuntuを起動する端末)であり、
  # このLinux環境には本体をインストールしない。設定ファイルの配置のみ行う。
  # 内容がWSL/Windows前提のため、Mac側では無効化する(Macで使う端末は ghostty.nix)。
  #
  # 置き場所: Windows版 WezTerm の設定探索順は
  #   %WEZTERM_CONFIG_FILE% → exe と同じディレクトリ → %USERPROFILE%\.config\wezterm\wezterm.lua
  #   → %USERPROFILE%\.wezterm.lua
  # で、WSL側の ~/.config は読まれない。よって生成物を activation で Windows のパスへ直接
  # 書き出す。UNC(\\wsl.localhost\...)経由にしない理由は、home.file が張るのは nix store への
  # symlink であり、リンク先が Linux の絶対パスなので Windows 側から辿れないため。
  # 直接書き出しなら 9P を経由しないため、WezTerm の設定自動リロード
  # (automatically_reload_config)のファイル監視もそのまま効く。
  winHome = "/mnt/c/Users/m1205";

  configFile = pkgs.writeText "wezterm.lua" ''
    -- このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
    -- 変更は ~/nix-config/modules/wezterm.nix を編集して home-manager switch する。

    local wezterm = require 'wezterm'
    local act = wezterm.action
    local config = wezterm.config_builder()

    -- WSL の Ubuntu を既定の接続先にする。ただし wsl.exe は使わず SSH で入る。
    -- wsl.exe を起動すると間に Windows の ConPTY が挟まり、ConPTY が Kitty graphics の
    -- APC シーケンス(ESC _G ...)を捨てるため、端末画像が一切表示できない。
    -- SSH なら ConPTY を通らず、WezTerm 自身が端末エミュレーションを行うので画像が通る。
    -- 上流でも未解決の既知問題で、回避策として wezterm ssh が案内されている(wezterm#1673)。
    -- 実測と手順は reporepo/github.com/i2702/aoao/WEZTERM.md を参照。
    config.ssh_domains = {
      {
        name = 'WSL:SSH',
        -- localhost と書くと ::1 に先に解決されるが、networkingMode=Mirrored では
        -- Windows → WSL の IPv6 ループバックが通らず、バナー待ちでタイムアウトする。
        -- IPv4 で明示する。
        remote_address = '127.0.0.1:2222',
        username = 'm1205062',
        -- 既定の 'WezTerm' はリモートに wezterm-mux-server を立てる方式で、画像の扱いに
        -- 難がある(wezterm#1237)。素の SSH 接続にする。
        multiplexing = 'None',
        assume_shell = 'Posix',
        ssh_option = { identityfile = wezterm.home_dir .. '/.ssh/id_ed25519' },
      },
    }
    config.default_domain = 'WSL:SSH'

    -- SSH で入れないとき(WSL 未起動、sshd 停止、鍵の入れ替え中など)の逃げ道として残す。
    -- 使うときは Windows 側から wezterm start --domain WSL:Ubuntu と叩く。
    -- default_cwd を省くと Windows 側のカレント(/mnt/c/...)で開くので明示する。
    config.wsl_domains = {
      {
        name = 'WSL:Ubuntu',
        distribution = 'Ubuntu',
        default_cwd = '~',
      },
    }

    config.font = wezterm.font 'HackGen Console NF'
    config.font_size = 15

    -- ウィンドウ分割やタブは tmux 側で行うため、WezTerm のタブバーは場所を取るだけ。
    -- 単一タブのときは隠す。
    config.hide_tab_bar_if_only_one_tab = true

    -- 起動を既存ウィンドウのタブにまとめる prefer_to_spawn_tabs は設定しない。
    -- ホットキー(Raycast)から欲しいのはタブでも新しいウィンドウでもなく、既に開いている
    -- ウィンドウへのフォーカスだけだから。Raycast が叩くのは Start Menu の Wezterm.lnk
    -- (= wezterm-gui.exe を引数なしで起動)で、この経路では設定を入れても新しいウィンドウが
    -- 開いた。起動するかフォーカスするかの分岐は下の .wezterm-focus.vbs 側で行う。

    -- Kitty keyboard protocol は有効にしない(config.enable_kitty_keyboard は既定の無効のまま)。
    -- 有効にすると ATOK で確定した文字が「1文字のときだけ」消える。protocol が有効だと
    -- WezTerm は入力を文字列としてではなくキーイベントとしてエンコードして送るため、
    -- 1文字の確定が単一の文字キーへ正規化されて CSI u に化け、アプリに文字として届かない
    -- (2文字以上の確定は文字列のまま通るので消えない。この非対称が切り分けの決め手だった)。
    -- そもそもこの版はキー解決自体が壊れており(下の '/' の項を参照)、WezTerm の正式リリースは
    -- 20240203 で止まっているため上流の修正も待てない。
    --
    -- 代わりに、aoao が必要とするキーだけ CSI u を SendString で直接送る。protocol を切っても
    -- アプリ側は CSI u を解釈するので、日本語入力と Ctrl 系キーは両立する(実測)。
    -- 詳細は reporepo/github.com/i2702/aoao/WEZTERM.md を参照。
    config.keys = {
      { key = 'v', mods = 'CTRL', action = act.PasteFrom 'Clipboard' },

      -- aoao が見るキーを kitty keyboard protocol の形に組み立てて送る。
      -- 書式は CSI <codepoint>;<修飾> u で、修飾は 5 = Ctrl、6 = Ctrl+Shift。
      --   Ctrl+Enter(13)      = 投稿
      --   Ctrl+/(47)          = 検索窓
      --   Ctrl+Shift+/(47)    = キー一覧
      -- '/' だけ物理キー指定にするのは、この環境の WezTerm が Ctrl 修飾の付いた '/' の
      -- キー解決を誤るため。Ctrl+/ は codepoint 45('-')として、Ctrl+Shift+/ に至っては
      -- protocol を通さず伝統的な 0x7F(DEL)として送られ、どちらもアプリ側で '/' と判らない
      -- (実測は keyprobe による)。物理キーならレイアウトにも左右されない。
      { key = 'Enter', mods = 'CTRL', action = act.SendString '\x1b[13;5u' },
      { key = 'phys:Slash', mods = 'CTRL', action = act.SendString '\x1b[47;5u' },
      { key = 'phys:Slash', mods = 'CTRL|SHIFT', action = act.SendString '\x1b[47;6u' },
    }

    -- Windows の Win(Super)ショートカットを押すと、端末に文字が混入する問題への対処。
    -- 例: Win-V(クリップボード履歴)を押すと、履歴から選んだ文字列がペーストされる前に
    -- "v" が入力される。バインドに一致しないキーはそのまま文字として PTY へ書き込まれ、
    -- Super 修飾は文字生成に影響しないため素通りするのが原因。
    -- 何もしない Nop を割り当てて潰す。SUPER+英数字には既定バインド(SUPER-c=Copy、
    -- SUPER-t=SpawnTab、SUPER-1..9=タブ切替 など)があるが、Windows では Win+英数字は
    -- OS のショートカットに奪われて WezTerm まで届かないため、潰しても実質失うものは無い。
    -- どの文字に既定があるかはバージョンで変わるので、範囲を絞らず英数字を一律に潰す。
    -- Windows 側のショートカット動作自体は OS が処理するので、履歴からのペーストは
    -- Ctrl-V 送出として届き、上の PasteFrom バインドで従来どおり機能する。
    for key in ('abcdefghijklmnopqrstuvwxyz0123456789'):gmatch('.') do
      table.insert(config.keys, { key = key, mods = 'SUPER', action = act.Nop })
    end

    -- ローカル固有設定の読み込み(このマシン専用)。WezTerm は Windows アプリなので
    -- home_dir は %USERPROFILE% (= C:\Users\m1205)。設定テーブルを返すファイルを置くと
    -- その内容で上書きする。ファイルが無いときは黙って無視される。
    local ok, overrides = pcall(dofile, wezterm.home_dir .. '/.wezterm.local.lua')
    if ok and type(overrides) == 'table' then
      for k, v in pairs(overrides) do
        config[k] = v
      end
    end

    return config
  '';

  # Raycast のホットキーから呼ぶランチャ。WezTerm が起動済みなら既存ウィンドウを前面に出し
  # (Alt-Tab で切り替えたのと同じ状態にし)、起動していなければ新しいウィンドウで起動する。
  #
  # Raycast 側は「アプリを起動して、そのプロセスのメインウィンドウを探して前面に出す」しか
  # しない(ログの CreateProcess: activating ... → Failed to find main window)。wscript には
  # ウィンドウが無いので Raycast の前面化は空振りする。よって前面化は自前で行う。
  #
  # 前面化を2段構えにしているのは、速い方法が効くとは限らないため。
  #   1段目 (vbs): WScript.Shell.AppActivate。50ms 程度で済むが、Windows のフォアグラウンド
  #                ロックに阻まれると何も起きず、最小化されたウィンドウも復元しない。
  #                効いたかどうかを VBS 自身で確かめる手段が無い。
  #   2段目 (ps1): Win32 API を直接叩き、GetForegroundWindow で確認したうえで、必要なら
  #                最小化の復元 → AttachThreadInput 付き SetForegroundWindow →
  #                SwitchToThisWindow (Alt-Tab と同じ API) の順に試す。
  #                Add-Type のコンパイルで 1.5 秒ほどかかるので、1段目が効いた場合は
  #                何もせず終わる。
  # どちらが効いたかは %TEMP%\wezterm-focus.log に残る。
  #
  # Raycast からこれを呼ぶには Start Menu にショートカットが要る(Raycast のアプリ一覧は
  # Start Menu の .lnk を拾う)。.lnk はバイナリで nix からは書けないため、新しいマシンでは
  # 以下を一度だけ Windows 側で実行する:
  #   $s = (New-Object -ComObject WScript.Shell).CreateShortcut(
  #          "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\WezTerm Focus.lnk")
  #   $s.TargetPath   = "$env:SystemRoot\System32\wscript.exe"
  #   $s.Arguments    = '"' + $env:USERPROFILE + '\.wezterm-focus.vbs"'
  #   $s.IconLocation = "$env:USERPROFILE\scoop\apps\wezterm\current\wezterm-gui.exe,0"
  #   $s.Save()
  # そのうえで Raycast のホットキーを Wezterm ではなく WezTerm Focus に割り当てる。
  focusScriptBody = pkgs.writeText "wezterm-focus-body.vbs" ''
    ' このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
    ' 変更は ~/nix-config/modules/wezterm.nix を編集して home-manager switch する。
    '
    ' wscript (.vbs) を入口にしているのは、コンソールを一切出さずに 50ms 程度で起動できる
    ' 唯一の軽い方法だから。.cmd や powershell.exe を直接呼ぶとウィンドウが一瞬光る。
    Option Explicit

    Dim sh, fso, wmi, procs, proc, pid, exe, logPath, psPath, i, ok

    Set sh = CreateObject("WScript.Shell")
    Set fso = CreateObject("Scripting.FileSystemObject")
    logPath = sh.ExpandEnvironmentStrings("%TEMP%") & "\wezterm-focus.log"
    psPath = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\.wezterm-focus.ps1"

    ' 名前を Log にすると VBScript 組み込みの Log 関数(自然対数)と衝突する。
    Sub WriteLog(msg)
      Dim f
      Set f = fso.OpenTextFile(logPath, 8, True)
      f.WriteLine Now & "  vbs  " & msg
      f.Close
    End Sub

    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set procs = wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name = 'wezterm-gui.exe'")
    pid = 0
    For Each proc In procs
      pid = proc.ProcessId
      Exit For
    Next

    If pid = 0 Then
      exe = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\scoop\apps\wezterm\current\wezterm-gui.exe"
      WriteLog "not running -> start " & exe
      sh.Run Chr(34) & exe & Chr(34), 1, False
    Else
      ' 見つかったときは何があっても前面化だけ。起動へフォールバックはしない
      ' (ウィンドウを増やさないことがこのスクリプトの目的なので)。
      ok = False
      For i = 1 To 3
        ok = sh.AppActivate(pid)
        If ok Then Exit For
        WScript.Sleep 120
      Next
      ' 成功したときは黙る。ログは失敗の切り分けのためだけに残す。
      If Not ok Then WriteLog "pid=" & pid & " appactivate=False"
      ' AppActivate が True でも、Raycast が自分のウィンドウを閉じるときにフォーカスが
      ' 元のアプリへ戻ることがある。実際に前面に出たかの確認と取りこぼしの回収は
      ' PowerShell 側に任せる(最小化からの復元もそちらでしか出来ない)。
      sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & psPath & Chr(34), 0, False
    End If
  '';

  focusFallbackBody = pkgs.writeText "wezterm-focus-body.ps1" ''
    # このファイルは nix (home-manager) の生成物。直接編集しても switch で上書きされる。
    # 変更は ~/nix-config/modules/wezterm.nix を編集して home-manager switch する。
    #
    # .wezterm-focus.vbs から呼ばれる2段目。AppActivate で前に出せなかった場合の回収役。
    $log = Join-Path $env:TEMP 'wezterm-focus.log'
    function WriteLog($m) { Add-Content -Path $log -Value ("{0}  ps   {1}" -f (Get-Date), $m) }

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public class WezFocus {
      [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h, int c);
      [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
      [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr h, bool alt);
      [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
      [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
      [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
      [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
      [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
      [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
      [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
      public delegate bool EnumProc(IntPtr h, IntPtr p);
      // MainWindowHandle が 0 のときの保険。可視のトップレベルウィンドウを pid で探す。
      public static IntPtr Find(uint target) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr h, IntPtr p) {
          uint owner; GetWindowThreadProcessId(h, out owner);
          if (owner == target && IsWindowVisible(h)) { found = h; return false; }
          return true;
        }, IntPtr.Zero);
        return found;
      }
    }
    "@

    $p = Get-Process wezterm-gui -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $p) { WriteLog 'wezterm-gui process not found'; exit }

    $h = $p.MainWindowHandle
    if ($h -eq [IntPtr]::Zero) { $h = [WezFocus]::Find([uint32]$p.Id) }
    if ($h -eq [IntPtr]::Zero) { WriteLog 'window not found'; exit }

    $fg = [WezFocus]::GetForegroundWindow()
    $iconic = [WezFocus]::IsIconic($h)
    # 1段目が効いていれば何もせず黙って終わる(ログも残さない)。
    if (($fg -eq $h) -and (-not $iconic)) { exit }
    WriteLog "need activation hwnd=$h fg=$fg iconic=$iconic"

    # 最小化されているとフォーカスを移しても見えないので先に復元する。
    if ($iconic) { [void][WezFocus]::ShowWindowAsync($h, 9) }

    # 相手スレッドの入力キューに繋いでから SetForegroundWindow を呼ぶと、
    # フォアグラウンドロックの制限を受けにくい。
    $me = [WezFocus]::GetCurrentThreadId()
    $ownerPid = [uint32]0
    $target = [WezFocus]::GetWindowThreadProcessId($h, [ref]$ownerPid)
    [void][WezFocus]::AttachThreadInput($me, $target, $true)
    [void][WezFocus]::SetForegroundWindow($h)
    [void][WezFocus]::AttachThreadInput($me, $target, $false)
    Start-Sleep -Milliseconds 80

    # それでも駄目なら Alt-Tab と同じ API で切り替える。
    if ([WezFocus]::GetForegroundWindow() -ne $h) {
      [WezFocus]::SwitchToThisWindow($h, $true)
      Start-Sleep -Milliseconds 80
    }

    WriteLog ("result fg-is-wezterm=" + ([WezFocus]::GetForegroundWindow() -eq $h) + " iconic=" + [WezFocus]::IsIconic($h))
  '';
  # WSH (wscript) も BOM の無いファイルを ANSI(この環境では CP932)として読む。日本語の
  # コメントが化けた結果、行末が継続文字 _ になる並びが出ると次の行がコメントに飲まれて
  # 構文エラーになる(実測: Sub の直後の行で「ステートメントがありません」)。ps1 と違って
  # UTF-8 BOM は WSH 自身が受け付けない(1,1 で「文字が正しくありません」)ため、
  # CP932 に変換して置く。CP932 に無い文字をコメントに書くと iconv がビルド時に落ちる。
  focusScript = pkgs.runCommand "wezterm-focus.vbs" { nativeBuildInputs = [ pkgs.glibc.bin ]; } ''
    iconv -f UTF-8 -t CP932 ${focusScriptBody} > $out
  '';

  # PowerShell 5.1 は BOM の無いファイルを UTF-8 ではなく ANSI(この環境では CP932)として
  # 読む。日本語のコメントが化け、化けた結果に構文上意味のある文字が混じると
  # パースが壊れる(実測: 「'}' を使用できません」で起動しない)。BOM を付けて渡す。
  focusFallback = pkgs.runCommand "wezterm-focus.ps1" { } ''
    printf '\357\273\277' > $out
    cat ${focusFallbackBody} >> $out
  '';

in
{
  home.activation = lib.mkIf pkgs.stdenv.isLinux {
    weztermWindowsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "${winHome}" ]; then
        run install -m 644 ${configFile} "${winHome}/.wezterm.lua"
        run install -m 644 ${focusScript} "${winHome}/.wezterm-focus.vbs"
        run install -m 644 ${focusFallback} "${winHome}/.wezterm-focus.ps1"
      fi
    '';
  };
}
