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
}
