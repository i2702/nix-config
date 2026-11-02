// サイドバーの表示順で前の space へ移る。keys.json の "alt-o": "mod.open:space-prev" で開かれる。
// next と prev で mod を分ける理由は space-next 参照。
import { spaceStepView } from "./step.js";

export default spaceStepView(-1, "space-prev");
