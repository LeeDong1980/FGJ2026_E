# 食材模型通用動畫規範

所有食材角色（人類、精靈、矮人、史萊姆、獸人、蝙蝠）都使用相同的標準動畫名稱，程式端不需要知道各模型原本的動畫名。

## 標準名稱

| 名稱 | 用途 | 播放方式 |
|---|---|---|
| `Idle` | 待機（隊伍中站著等待） | 循環，場景載入後自動播放 |
| `Walk` | 移動（隊伍前進） | 循環 |
| `Atk` | 攻擊／反應動作 | 播放一次，播完回到 `Idle` |

- 名稱大小寫固定為 `Idle`、`Walk`、`Atk`。
- 缺少某個動畫時：`Walk` 退回播 `Idle`，`Atk` 不播放。

## 程式接口

每個角色場景的根節點掛 `scenes/ingredient/ingredient_character.gd`（`IngredientCharacter`）：

- `play_idle()`、`play_move()`（播 `Walk`）、`play_action()`（播 `Atk`）
- `play_animation(name)`：播模型內其他動畫
- `get_animation_names()`
- Inspector 欄位 `idle_animation`／`move_animation`／`action_animation` 預設就是 `Idle`／`Walk`／`Atk`，一般不用改。
- `extra_library`：標準名稱動畫庫（`.tres`），載入時併入模型的 AnimationPlayer，同名時覆蓋模型原動畫。

## 目前對應

| 角色 | 場景 | Idle | Walk | Atk |
|---|---|---|---|---|
| 人類 | `human_character.tscn` | `Idle_001` | `walk` | `attack` |
| 精靈 | `elf_character.tscn` | `Idle.fbx` | `Walk.fbx` | `Atk.fbx`（皆為 `mixamo_com`，已移除作用在 metarig 根節點的軌道） |
| 史萊姆 | `slime_character.tscn` | `Idle` | `Scoot_Move` | `Emote_Anger` |
| 蝙蝠 | `bat_character.tscn` | `Armature.006` 第 2～36 格 | 同 Idle（第 2～36 格） | `Armature.006` 第 76～105 格 |

蝙蝠的格數以 24 fps 換算（時間 = 格數 ÷ 24），擷取後從 0 秒開始。

## 新增或修改角色的流程

1. 將模型放入 `Models/<名稱>/`，用 Godot 匯入。注意匯入時動畫名稱裡的 `.` 會被換成 `_`。
2. 在 `scenes/ingredient/build_ingredient_animations.gd` 的 `SETS` 加入模型、輸出路徑與標準名稱的對應（整段複製原動畫，或指定 `[起始格, 結束格]` 擷取）。
3. 執行：`Godot --headless --path . -s res://scenes/ingredient/build_ingredient_animations.gd`，產生 `<名稱>_animations.tres`。
4. 建立 `<名稱>_character.tscn`：根節點 Node3D 掛 `ingredient_character.gd`，子節點實例化模型，`extra_library` 設為產生的 `.tres`。
5. 用 `ingredient_preview.tscn`（F6，按 1／2／3 切換 Idle／Walk／Atk）驗證，並更新上方對應表。

## 待確認

- 史萊姆 `Atk` 暫用 `Emote_Anger`，可在 `SETS` 改為其他動畫（如 `Emote_Excite`、`Wiggle`）。
- 矮人、獸人尚未有模型。
- 精靈的 `elf.glb`（含貼圖）只有骨架與網格、沒有 AnimationPlayer，`IngredientCharacter` 會自動建立；動畫來自三個獨立 FBX。縮放 0.39（高約 0.8），朝向待在畫面確認。
