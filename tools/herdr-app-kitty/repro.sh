#!/bin/sh
# herdr-app に報告した Kitty graphics の問い合わせ順序の再現。応答を cat -v でそのまま表示する。
# ratatui-image 11 の Picker::from_query_stdio と同じ順番で問い合わせる (a=q, DA1, 16t, DSR)
stty -echo -icanon min 0 time 30; printf '\033_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\033\\\033[c\033[16t\033[5n'; cat -v; stty sane; echo; echo "rows cols: $(stty size)"
