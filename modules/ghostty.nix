{ ... }:
{
  # Ghostty 本体は GUI アプリのため nix では管理せず(/Applications/Ghostty.app)、
  # 設定ファイル ~/.config/ghostty/config の配置のみ行う。
  xdg.configFile."ghostty/config".text = ''
    # フォント。HackGen Console NF (Nerd Font 版) を使用。
    font-family = HackGen Console NF

    # フォントサイズ (pt)。Ghostty のデフォルトは 13。
    font-size = 18

    # Option キーを Alt(Meta)として送る。
    # これが無いと macOS では Option が特殊文字入力になり、
    # tmux の M-t / M-s / M-v / M-h,j,k,l 等の Alt バインドが効かない。
    macos-option-as-alt = true

    # --- タブ機能の無効化 ---
    # Ghostty のネイティブタブは macOS の Window API 上「別ウィンドウ」として見える。
    # そのため AeroSpace がタブ毎に別ウィンドウ・別ワークスペースとして扱い、
    # タブ切り替えのたびに別領域へフォーカスが飛ぶ。専用の無効化オプションは無いので、
    # タブを「作る/切り替える」キーバインドを潰して実質使わなくする。
    # タブの代替は AeroSpace のタイル配置か tmux のウィンドウ/ペインで行う。
    keybind = cmd+t=unbind
    keybind = cmd+shift+]=unbind
    keybind = cmd+shift+[=unbind
    keybind = ctrl+tab=unbind
    keybind = ctrl+shift+tab=unbind

    # cmd+[ / cmd+] は Ghostty デフォルトで split 移動(goto_split:previous/next)だが、
    # ペイン管理は herdr が行うため未使用。誤爆で Ghostty 側の split が動かないよう unbind のまま。
    # (herdr の space 切替は Alt 系に統一済みのため、cmd 系を herdr へ回す用途は無い。)
    keybind = cmd+[=unbind
    keybind = cmd+]=unbind
  '';
}
