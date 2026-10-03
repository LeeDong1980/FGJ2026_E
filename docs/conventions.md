# 開發慣例

目前 repo 還沒有程式碼，以下以 Godot 官方 GDScript 風格為基礎。有了實際程式碼後，以程式碼為準修正這份文件。

## GDScript
- 檔名、資料夾名：`snake_case`（`player_controller.gd`）
- `class_name` 和節點型別：`PascalCase`
- 函式、變數、signal：`snake_case`；signal 用過去式（`health_changed`、`died`）
- 常數、enum 值：`CONSTANT_CASE`
- 私有成員加底線前綴：`_velocity`、`_update_state()`
- 盡量加上型別標註：`var speed: float = 5.0`、`func get_hp() -> int:`
- 縮排用 Tab（Godot 編輯器預設值）
- 會在 Inspector 調整的數值用 `@export`，不要寫死在程式碼裡

## 資料夾放置
依功能分資料夾，場景和它專用的腳本、素材放在一起：
```
scenes/<功能>/      場景 + 專用腳本，例如 scenes/player/player.tscn、player.gd
assets/models/     3D 模型
assets/textures/   貼圖
assets/audio/      音效、音樂
autoload/          全域單例
```
資料夾需要時再建立，不要預先建空資料夾。

## 場景與節點命名
- 場景檔名用 `snake_case`，並和根節點同名：`player.tscn` 的根節點叫 `Player`
- 節點名稱用 `PascalCase`，依用途命名：`HealthBar`，不要用 `Node3D2` 這種預設名稱
- 程式碼存取的節點，盡量用 `%UniqueName`（場景唯一名稱），不要寫長路徑

## 場景歸屬（避免 .tscn 合併衝突）
- 每個 `.tscn` 只有一位負責人，只有負責人可以修改它。
- 需要改別人的場景時，先告知負責人，或在 tasks.md 加一個任務交給對方。
- 大場景（例如關卡、主場景）要拆成可以獨立編輯的子場景（player、敵人、UI、地形區塊等），再實例化進來，讓不同人可以同時改不同檔案。
- 新建場景時，在下方歸屬表加一行。

### 歸屬表
<!-- 一行一個場景，格式：- `res://路徑.tscn` @負責人 -->
- `res://scenes/main/main.tscn` @Codex
- `res://scenes/red_dragon/red_dragon.tscn` @Codex
- `res://scenes/platforms/cube_platform.tscn` @Codex
- `res://scenes/platforms/platform_layout.tscn` @Codex
- `res://scenes/game/game.tscn` @露柑
- `res://scenes/dragon/dragon.tscn` @露柑
- `res://scenes/ingredient/ingredient_model.tscn` @露柑
- `res://scenes/dungeon_room/dungeon_room.tscn` @Codex
- `res://scenes/main/dragon_platform_showcase.tscn` @Codex
- `res://scenes/ui/ui_root.tscn` @GMF
- `res://scenes/ui/start_screen.tscn` @GMF
- `res://scenes/ui/play_hud.tscn` @GMF
- `res://scenes/ui/pot_info.tscn` @GMF
- `res://scenes/ui/result_screen.tscn` @GMF
- `res://scenes/ui/ui_preview.tscn` @GMF
- `res://scenes/ui/ui_test.tscn` @GMF

## Git
- `.import` 和 `.uid` 檔要 commit，`.godot/` 不要 commit
- 搬移或重新命名檔案時，要在 Godot 編輯器內操作，才不會弄斷引用
