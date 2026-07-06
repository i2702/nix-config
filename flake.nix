{
  description = "m1205062 home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # herdr は nixpkgs 未収録のため、公式リポジトリの flake から取得する
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, herdr, ... }:
    let
      # herdr の overlay を適用し、各モジュールから pkgs.herdr として参照できるようにする
      pkgsFor = system: import nixpkgs {
        inherit system;
        overlays = [ herdr.overlays.default ];
      };
    in
    {
      homeConfigurations."linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor "x86_64-linux";
        modules = [ ./home.nix ./hosts/linux.nix ];
      };

      homeConfigurations."mac" = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgsFor "aarch64-darwin";
        modules = [ ./home.nix ./hosts/mac.nix ];
      };
    };
}
