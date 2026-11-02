// サイドバーの表示順で次の space へ移る。keys.json の "alt-p": "mod.open:space-next" で開かれる。
// next と prev で mod を分ける理由: キー割り当ての mod.open は mod 名しか渡せず、向きを引数で指定できない。
// step.js は modules/herdr-app/space-step.js を modules/herdr-app.nix が配置したもの。
import { spaceStepView } from "./step.js";

export default spaceStepView(1, "space-next");
