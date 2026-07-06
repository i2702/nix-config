# nix-config

[Nix Flakes](https://nixos.wiki/wiki/Flakes) + [home-manager](https://github.com/nix-community/home-manager) による、シェル・エディタ・ターミナル環境の宣言的な dotfiles 管理リポジトリ。

**macOS (Apple Silicon)** と **WSL (Ubuntu / x86_64)** の 2 環境を 1 つの flake で管理し、共通設定を `home.nix` + `modules/` に、環境差分を `hosts/` に分離している。

---

## 概要

- 各ツールの設定は `modules/*.nix` に 1 ファイル 1 ツールで分割し、`home.nix` から `imports` する。
- OS 依存の差分は `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` で分岐（`hosts/{mac,linux}.nix` はユーザー名とホームディレクトリのみ）。
- ほぼ全モジュールが **このマシン専用のローカル override**（`~/.zshrc.local`, `~/.config/nvim/init.lua.local`, `~/.vimrc.local` など）を末尾で読み込む構成になっており、公開リポジトリに載せたくない設定を各マシンで足せる。
- git の identity（name / email）は公開リポジトリに含めず、`~/.config/git/config.local`（リポジトリ管理外）から `include` で取り込む。

---

## セットアップ

前提: [Nix](https://nixos.org/download) がインストールされ、flakes が有効になっていること。

```bash
# 1. git identity をこのマシン用に用意（無いと activation が失敗して停止する）
cp templates/git-config.local.example ~/.config/git/config.local
#    → ~/.config/git/config.local を開き name / email を自分の値に書き換える

# 2. 適用（home-manager CLI 未導入なら nix run 版を使う）
#    macOS:
home-manager switch --flake .#mac
#    WSL (Ubuntu):
home-manager switch --flake .#linux

#    home-manager 未導入時:
nix run home-manager -- switch --flake .#mac   # または .#linux
```

---

## ディレクトリ構成

```
.
├── flake.nix              # inputs (nixpkgs / home-manager / herdr) と 2 つの homeConfiguration
├── flake.lock             # 依存の固定
├── home.nix               # 共通設定・全モジュールの imports
├── hosts/
│   ├── mac.nix            # macOS: username / homeDirectory
│   └── linux.nix          # WSL:   username / homeDirectory
├── modules/               # 1 ファイル = 1 ツールの設定
│   ├── zsh.nix            # Zsh / Oh My Zsh / alias / プロンプト / WSL 連携
│   ├── git.nix  gh.nix  lazygit.nix
│   ├── neovim.nix  vim.nix
│   ├── herdr.nix          # ターミナルマルチプレクサ（自動起動）
│   └── ghostty.nix  alacritty.nix
└── templates/
    └── git-config.local.example   # git identity のテンプレート
```

---

## 使用技術（カテゴリ別）

### Nix / 構成管理
| 技術 | 用途 |
| --- | --- |
| Nix Flakes | 依存の固定と再現可能なビルド |
| home-manager | ユーザー環境（dotfiles / パッケージ）の宣言的管理 |
| nixpkgs (`nixos-unstable`) | パッケージ供給元 |
| [herdr](https://herdr.dev) flake input | nixpkgs 未収録のため公式 flake を overlay で取り込み |

### シェル
| 技術 | 備考 |
| --- | --- |
| Zsh | メインシェル |
| Oh My Zsh | `half-life` テーマ（プロンプトを独自カスタマイズ）、`git` プラグイン |
| zsh-autosuggestion | 履歴補完 |

主なエイリアス: `h`=herdr, `p`=pnpm, `c`=claude, `lg`=lazygit, `v`/`nv`/`vim`=nvim, `z`=zed。空 Enter で `ls`、`less` は `bat` で置き換え。

### ターミナルマルチプレクサ
| 技術 | 位置づけ |
| --- | --- |
| [herdr](https://herdr.dev) | 新規シェルで自動起動・アタッチ。Alt キー中心のキーバインドと、自動タイル分割（4 ペインで 2×2）を独自スクリプトで実装 |

> herdr モジュールの詳細な内部仕様は開発メモに別途記録あり（カスタムコマンドの環境変数、`layout.apply` の破壊的挙動、agent rename の落とし穴など）。

### エディタ
| 技術 | 構成 |
| --- | --- |
| Neovim | `lazy.nvim`（プラグイン管理）/ Telescope（+ fzf-native）/ nvim-cmp / nvim-lspconfig（`ts_ls`）/ neo-tree / cyberdream テーマ。ビルド用に gcc・GNU Make を同梱 |
| Vim | `git core.editor` の実体として最小構成で保持（`habamax` テーマ） |

### Git ツール
| 技術 | 備考 |
| --- | --- |
| Git | 多数のエイリアス、[delta](https://github.com/dandavison/delta) で差分表示、identity は `config.local` から include |
| lazygit | 日本語 UI、delta 連携、独自 customCommands（push / fetch --prune） |
| GitHub CLI (`gh`) | HTTPS 認証。git の credential helper としても利用 |

### ターミナルエミュレータ
| 技術 | 環境 | 備考 |
| --- | --- | --- |
| [Ghostty](https://ghostty.org) | macOS | 本体は GUI アプリ（nix 管理外）、設定のみ配置。`macos-option-as-alt` 有効、ネイティブタブは herdr のワークスペース切替と競合するため無効化 |
| Alacritty | WSL | Windows 側アプリが `wsl.exe` 経由で Ubuntu を起動。設定ファイルのみ配置 |

### CLI ユーティリティ
| 技術 | 用途 |
| --- | --- |
| ripgrep | 高速 grep（Telescope の live_grep でも使用） |
| bat | `less` の代替ページャ |
| jq | herdr の自動タイル / フォーカス制御スクリプト |
| gcc / GNU Make | Neovim ネイティブプラグインのビルド |
| nkf | **WSL のみ**。クリップボード連携時の UTF-8 → Shift-JIS 変換 |

---

## Mac / WSL の違い

共通設定は `home.nix` + `modules/` にまとめ、差分は `pkgs.stdenv.isDarwin` / `isLinux` の分岐と `hosts/` で吸収している。

| 項目 | macOS (`hosts/mac.nix`, `aarch64-darwin`) | WSL / Ubuntu (`hosts/linux.nix`, `x86_64-linux`) |
| --- | --- | --- |
| homeConfiguration | `.#mac` | `.#linux` |
| ユーザー / ホーム | `ayumi` / `/Users/ayumi` | `m1205062` / `/home/m1205062` |
| ターミナルエミュレータ | Ghostty | Alacritty（Windows 側から `wsl.exe` 起動） |
| クリップボード | macOS ネイティブ | `clip.exe` + `nkf`（UTF-8 → Shift-JIS）でラップ |
| エディタ起動 | `zed` = `Zed.app` 同梱 CLI を直接指定 | `e` = `explorer.exe` |
| herdr space 切替 | `cmd` 系キー（macOS では cmd が herdr まで届く） | — |
| 追加パッケージ | — | `nkf` |

### WSL 固有の追加設定（`modules/zsh.nix` の `isLinux` 分岐）

- **`clip` 関数**: 標準入力を `nkf -s` で Shift-JIS 変換して `clip.exe` へ渡す。
- **`mmp` 関数**: Mermaid ファイルを `mmdc` で PNG 化し `explorer.exe` でプレビュー。
- **`PATH`**: `/snap/bin` を追加。
- **Claude Code の対処**: `CLAUDE_CODE_SKIP_WINDOWS_PROFILE=1` と `USERPROFILE=/mnt/c/Users/m1205`（powershell.exe の多重起動回避）。
- **Node.js**: `NODE_EXTRA_CA_CERTS` で社内 CA 証明書を追加。

### macOS 固有の設定

- **Ghostty**（`modules/ghostty.nix`）: `macos-option-as-alt` で Option を Alt として送出（herdr の Alt バインド用）。ネイティブタブ・split 系キー（`cmd+t` / `cmd+[` / `cmd+]` など）は herdr のワークスペース切替と競合するため `unbind`。
- **Zed CLI**: macOS では `zed` が PATH に無いため、`z` / `za` エイリアスを `Zed.app` 同梱 CLI の絶対パスに割り当て。

> `modules/alacritty.nix` は Linux（WSL）でのみ、`modules/ghostty.nix` は Darwin でのみ配置される。

---

## ローカル override / 秘匿設定

以下は**リポジトリ管理外**。各マシンで必要に応じて作成する。

| ファイル | 役割 |
| --- | --- |
| `~/.config/git/config.local` | git identity（name / email）。**必須**（無いと activation が失敗） |
| `~/.zshrc.local` | このマシン専用の zsh 設定 |
| `~/.config/nvim/init.lua.local` | このマシン専用の Neovim 設定 |
| `~/.vimrc.local` / `~/.alacritty.toml.local` | 同上（各ツール） |
