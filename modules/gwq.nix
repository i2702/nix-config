{ pkgs, ... }:
let
  # gwq は nixpkgs 未収録かつ公式リポジトリに flake も無いため、
  # リリースタグから buildGoModule でソースビルドする
  gwq = pkgs.buildGoModule rec {
    pname = "gwq";
    version = "0.1.1";

    src = pkgs.fetchFromGitHub {
      owner = "d-kuro";
      repo = "gwq";
      rev = "v${version}";
      hash = "sha256-MfCYFbODWnfPxx+6sLlcMT6tqghgILHB13+ccYqVjBA=";
    };

    vendorHash = "sha256-4K01Xf1EXl/NVX1loQ76l1bW8QglBAQdvlZSo7J4NPI=";

    subPackages = [ "cmd/gwq" ];
    env.CGO_ENABLED = 0;
    ldflags = [ "-s" "-w" ];

    # テストは git 実環境前提のものがあるためスキップ
    doCheck = false;
  };
in
{
  home.packages = [ gwq ];
}
