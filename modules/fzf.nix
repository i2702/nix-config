{ ... }:
{
  # fzf: 汎用fuzzy finder
  # zsh統合で Ctrl-T(ファイル検索) / Ctrl-R(履歴検索) / Alt-C(ディレクトリ移動) が使える
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
