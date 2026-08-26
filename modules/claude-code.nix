{ config, ... }:
let
  # home.nix と同じ導出。ghq root がホストごとに違う (linux: ~/reporepo,
  # mac: ~/Repository) ため、パスをハードコードしない。
  ghqRoot = builtins.replaceStrings [ "~" ] [ config.home.homeDirectory ]
    config.programs.git.settings.ghq.root;
  repo = "${ghqRoot}/github.com/i2702/nix-config";
in
{
  # skill と共通 CLAUDE.md をマシン間で共有する。
  #
  # nix store へのコピー (source = ./claude/skills) にしないのは、skill が
  # 「使いながら書き足す」ファイルだから。store 実体は read-only なので
  # ~/.claude/skills/*/SKILL.md への編集は permission denied で弾かれ、
  # Claude Code 自身も symlink 越しの書き込みを拒否する。編集のたびに repo 側の
  # パスへ回り道して hms を挟むことになり、その場で書き足す運用ができない。
  # mkOutOfStoreSymlink なら作業ツリーを直接指すので、編集がそのまま git 差分に
  # なり switch も要らない (symlink になるのは親ディレクトリだけで、その下の
  # 実体ファイルは普通に書き込める)。
  #
  # 代償として中身は nix 管理外になり、ホストごとの出し分けと世代ロールバックは
  # 効かない。skill 単位で配り分けたくなったら .claude/skills/<name> 単位の
  # symlink に切り替える。
  home.file = {
    ".claude/skills".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/claude/skills";
    ".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${repo}/claude/CLAUDE.md";
  };

  # settings.json は意図的に管理しない。Claude Code が theme / enabledPlugins /
  # autoMode.environment を実行時に自分で書き換えるため、read-only symlink を
  # 張ると書き込みが失敗するか、実体ファイルに置換されて次の switch で
  # 「is in the way of」→ .backup 送りになる。プラグインは新しいマシンで
  # claude plugin marketplace add / claude plugin install を手で叩いて揃える。
}
