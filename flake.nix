{
  description = "m1205062 home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      pkgsFor = system: import nixpkgs { inherit system; };
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
