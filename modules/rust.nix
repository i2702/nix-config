{ pkgs, ... }:
{
  # Rust ツールチェーン一式を nixpkgs から供給する。
  #
  # rustup にしない理由:
  #   - rustup はツールチェーン本体を実行時に rust-lang.org から落とす。
  #     herdr 配下では名前解決が壊れることがあり、実行時ダウンロードに
  #     依存するツールはその巻き添えを食う。nix 供給なら hms の時点で
  #     実体が揃い、以後ネットワークに依存しない。
  #   - マシンごとに rustup-init を手で叩く手順が残り、「すべてのマシンで
  #     cargo が動く」を宣言的に保証できない。
  #
  # cargo install したバイナリ (zellij 等) は従来どおり ~/.cargo/bin に
  # 入る。PATH への追加は zsh.nix が行う。
  home.packages = with pkgs; [
    cargo
    rustc
    rustfmt # cargo fmt
    clippy # cargo clippy
  ];

  # mac では neovim.nix が入れる pkgs.gcc が PATH 上の cc を握るが、
  # nix の gcc は macOS SDK のライブラリパスを知らないため、rustc の
  # リンク段階で `ld: library not found for -liconv` の形で失敗する
  # (aws-lc-sys 等の C 依存を含むクレートで顕在化)。cargo 側で
  # Apple clang を明示してこれを回避する。
  #
  # gcc 側を直さない理由: gcc は telescope-fzf-native 等のビルド用で、
  # 用途ごとに正しいコンパイラが違う。PATH の順序で解決しようとすると
  # どちらかが壊れる。
  #
  # 全設定を aarch64-apple-darwin にスコープしてあるので、このファイルを
  # linux ホストに置いても無害 (linux の cc→gcc は正常に動く)。
  # CC_<target> 形式は cc クレートが CC より優先して参照する変数。
  home.file.".cargo/config.toml".text = ''
    [env]
    CC_aarch64_apple_darwin = "/usr/bin/clang"
    CXX_aarch64_apple_darwin = "/usr/bin/clang++"

    [target.aarch64-apple-darwin]
    linker = "/usr/bin/clang"
  '';
}
