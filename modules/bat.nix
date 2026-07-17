{ pkgs, ... }:
{
  # batを home-manager で入れることで brew(bat) / apt(batcat) のバイナリ名の差を吸収する
  programs.bat = {
    enable = true;
    config = {
      # --search-options=W: 検索を先頭↔末尾で回り込ませる（n/N のサイクル）
      pager = "less -RFM --search-options=W";
      theme = "Catppuccin Mocha";
    };
    # Catppuccin Mocha は bat 同梱テーマに無いため nix で供給する(実行時ダウンロードはしない)。
    # delta の syntax-theme もここで入れたテーマを参照する
    # (delta は bat のテーマキャッシュ ~/.cache/bat を読む。キャッシュ再構築は
    #  home-manager の bat モジュールが activation 時に `bat cache --build` で行う)。
    themes."Catppuccin Mocha" = {
      src = pkgs.fetchFromGitHub {
        owner = "catppuccin";
        repo = "bat";
        rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
        hash = "sha256-lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
      };
      file = "themes/Catppuccin Mocha.tmTheme";
    };
  };
}
