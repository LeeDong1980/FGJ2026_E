class_name IngredientType
extends RefCounted
## 食材種類與各種類的顯示資料。

enum Type { HUMAN, ELF, DWARF, SLIME, ORC, BAT }

const NAMES: Dictionary = {
	Type.HUMAN: "人類",
	Type.ELF: "精靈",
	Type.DWARF: "矮人",
	Type.SLIME: "史萊姆",
	Type.ORC: "獸人",
	Type.BAT: "蝙蝠",
}

## 暫時模型用的顏色，換成正式模型後可以移除。
const COLORS: Dictionary = {
	Type.HUMAN: Color(0.95, 0.75, 0.6),
	Type.ELF: Color(0.45, 0.85, 0.4),
	Type.DWARF: Color(0.6, 0.4, 0.25),
	Type.SLIME: Color(0.3, 0.8, 0.95),
	Type.ORC: Color(0.4, 0.5, 0.2),
	Type.BAT: Color(0.5, 0.3, 0.7),
}
