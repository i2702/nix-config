{ pkgs, config, ... }:
{
  home.stateVersion = "24.11";

  # このリポジトリ自体への近道。実体は ghq 配下だがパスが長いので、
  # hms (home-manager switch) や cd から ~/nix-config で届くようにする。
  # mkOutOfStoreSymlink: nix store のコピーではなく作業ツリーを直接指すため、
  # 編集 → switch のループがそのまま回る。
  home.file."nix-config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/reporepo/github.com/i2702/nix-config";

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
    ./modules/mdp.nix
    ./modules/rust.nix
    ./modules/alacritty.nix
    ./modules/wezterm.nix
    ./modules/ghostty.nix
    ./modules/zed.nix
  ];

  programs.home-manager.enable = true;
}
