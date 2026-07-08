{ pkgs, ... }:
{
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    ripgrep
  ];

  imports = [
    ./modules/bat.nix
    ./modules/zsh.nix
    ./modules/git.nix
    ./modules/herdr.nix
    ./modules/tmux.nix
    ./modules/vim.nix
    ./modules/neovim.nix
    ./modules/gh.nix
    ./modules/ghq.nix
    ./modules/gwq.nix
    ./modules/fzf.nix
    ./modules/lazygit.nix
    ./modules/alacritty.nix
    ./modules/ghostty.nix
    ./modules/zed.nix
  ];

  programs.home-manager.enable = true;
}
