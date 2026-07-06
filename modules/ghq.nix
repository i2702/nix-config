{ pkgs, ... }:
{
  home.packages = [ pkgs.ghq ];

  # クローン配置先(ghq.root)はホストごとに異なるため hosts/*.nix で設定する。
}
