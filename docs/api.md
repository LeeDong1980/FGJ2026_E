# 遊戲機制接口

遊戲機制對外提供的函式與 signal，給 UI 與麥克風輸入使用。遊戲規則見 design.md。
接口有變動時由遊戲機制負責人（露柑）更新本文件。

## 取得節點

`scenes/game/game.tscn` 的根節點是 `GameManager`，龍是 `Dragon` 節點：

```gdscript
@export var game_manager: GameManager
@export var dragon: Dragon
```

## 給麥克風輸入：操作龍

| 呼叫 | 用途 |
|---|---|
| `dragon.set_target_lane(lane: int)` | 設定目標層，龍會等速飛過去。0 是最低層 |
| `game_manager.suck(dragon.current_lane)` | 玩家 B 喊「吸」 |
| `game_manager.spit(dragon.current_lane)` | 玩家 B 喊「吐」 |

- 吸和吐一律傳 `dragon.current_lane`（龍目前位置所在的層），不是目標層。
- 層數：`game_manager.lane_layout.lane_count`。
- 鍵盤測試輸入 `scenes/game/keyboard_input.gd` 就是用這三個呼叫，可以當作範例。

## 給 UI：查詢資料

| 屬性 / 函式 | 型別 | 內容 |
|---|---|---|
| `game_manager.get_pot(lane)` | `PotState` | 某一層的鍋子與小龍 |
| `PotState.forbidden` | `Array[IngredientType.Type]` | 禁止食材（1～3 種） |
| `PotState.required` | `int` | 需求數量 |
| `PotState.count` | `int` | 目前數量 |
| `PotState.has_baby` | `bool` | 小龍是否到位；`false` 表示正在換小龍，這時不能吐入 |
| `game_manager.stomach` | `IngredientState` | 胃袋裡的食材，胃空時為 `null`；種類是 `.type` |
| `game_manager.completed_count` / `pots_to_win` | `int` | 完成鍋數 / 成功需要的鍋數 |
| `game_manager.cleared_count` / `clears_to_lose` | `int` | 清空次數 / 失敗需要的次數 |
| `game_manager.is_game_over` | `bool` | 遊戲是否已結束 |
| `dragon.current_lane` | `int` | 龍目前所在的層 |
| `IngredientType.NAMES[type]` | `String` | 食材的中文名稱 |

## 給 UI：signal

`GameManager`：

| signal | 時機 |
|---|---|
| `pot_changed(lane)` | 鍋子數量或要求改變（吐入、清空、換小龍）。收到後用 `get_pot(lane)` 重新讀取 |
| `baby_left(lane, reason)` | 小龍離開。`reason` 是 `GameManager.BabyLeaveReason.COMPLETED`（完成）或 `KICKED`（吐入禁止食材，踢翻鍋子） |
| `baby_arrived(lane)` | 新的小龍到位，禁止清單已更新。遊戲開始時每一層也會發一次 |
| `stomach_changed(ingredient)` | 胃袋內容改變，胃空時為 `null` |
| `completed_count_changed(count)` | 完成鍋數改變 |
| `cleared_count_changed(count)` | 清空次數改變 |
| `game_won` / `game_lost` | 遊戲成功 / 失敗，之後不再接受吸吐 |
| `ingredient_swallowed(lane, ingredient)` | 食材被吞進胃袋 |
| `ingredient_spat(lane, ingredient)` | 胃裡的食材吐進鍋子 |
| `ingredient_burned(lane, ingredient)` | 食材被噴火燒掉 |
| `suck_missed(lane)` / `spit_missed(lane)` | 喊了吸或吐但沒有效果（可以用來播放空動作） |

`Dragon`：

| signal | 時機 |
|---|---|
| `current_lane_changed(lane)` | 龍目前所在的層改變 |

## 注意

- 開場的 `baby_arrived`、`pot_changed` 在 `GameManager._ready()` 發出。UI 如果是 `game.tscn` 的子節點，在自己的 `_ready()` 連接就不會漏接；如果放在別的場景，連接後請先主動用 `get_pot()` 等查詢讀一次目前狀態。
- 不要直接修改 `GameManager` 或 `PotState` 的資料，只讀取。
