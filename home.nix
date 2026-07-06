{ pkgs, ... }:
{
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ripgrep
  ];

  imports = [
    ./modules/zsh.nix
    ./modules/git.nix
    ./modules/tmux.nix
    ./modules/herdr.nix
    ./modules/vim.nix
    ./modules/neovim.nix
    ./modules/gh.nix
    ./modules/helix.nix
    ./modules/zellij.nix
    ./modules/lazygit.nix
    ./modules/alacritty.nix
    ./modules/aerospace.nix
    ./modules/ghostty.nix
  ];

  programs.home-manager.enable = true;
}
