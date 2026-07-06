{ ... }:
{
  # batを home-manager で入れることで brew(bat) / apt(batcat) のバイナリ名の差を吸収する
  programs.bat = {
    enable = true;
    config = {
      # --search-options=W: 検索を先頭↔末尾で回り込ませる（n/N のサイクル）
      pager = "less -RFM --search-options=W";
    };
  };
}
