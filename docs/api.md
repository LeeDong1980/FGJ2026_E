# 遊戲機制接口

遊戲機制對外提供的函式與 signal，給 UI 與麥克風輸入使用。遊戲規則見 design.md。
接口有變動時由遊戲機制負責人（露柑）更新本文件。

## 取得節點

`scenes/game/main.tscn`（遊戲場景）的根節點是 `GameManager`，龍是 `Dragon` 節點：

```gdscript
@export var game_manager: GameManager
@export var dragon: Dragon
```

## 給麥克風輸入：操作龍

| 呼叫 | 用途 |
|---|---|
| `dragon.set_target_lane(lane: int)` | 設定目標層，龍會等速飛過去。0 是最低層 |
| `game_manager.suck()` | 玩家 B 喊「吸」 |
| `game_manager.spit_pressed()` | 玩家 B 開始喊「吐」 |
| `game_manager.spit_released()` | 玩家 B 停止喊「吐」 |
| `game_manager.turn_head()` | 玩家 B 大叫或按 L：龍頭左右切換 |

- 吸和吐一律作用在龍目前位置所在的層（`dragon.current_lane`），不需要傳層的編號。
- 「吐」要回報開始和結束：胃袋有食材時，`spit_pressed()` 一呼叫就吐進鍋子；胃袋空著時是噴火，要持續到 `spit_released()`，累計 `burn_time` 秒（預設 1 秒）才燒掉一個食材。
- 層數：`game_manager.lane_layout.lane_count`。
- 樓層位置：`lane_layout.get_lane_position(lane)` 是該層地板頂面的 Y（LaneLayout 本地座標，層距 5）；`lane_layout.get_anchor_position(lane, name)` 取房間定位點（`QueueSpawnAnchor`、`QueueFrontAnchor`、`PotAnchor` 等，名稱見 `docs/prototype_rooms.md`），例如 UI 跟隨鍋子用 `PotAnchor`。
- 龍暈眩時（`game_manager.is_stunned()`）龍停在原地，`suck()`、`spit_pressed()` 沒有效果，也不會發出 `suck_missed`／`spit_missed`。`set_target_lane()` 照常記錄，醒來後才飛過去；`spit_pressed()` 仍會記錄正在喊「吐」，持續喊到醒來會接著噴火。
- 朝向：`game_manager.facing` 是 `GameManager.Facing.LEFT`（面向食材）時 `suck()` 與噴火有效；`RIGHT`（面向鍋子）時 `spit_pressed()` 才會吐進鍋子；胃袋空著且鍋子已滿（`PotState.is_full()`）時，持續喊「吐」是對鍋子噴火煮，累計 `cook_time` 秒（預設 1 秒）才完成一鍋。鍋子已滿時吐食材沒有效果。沒有效果時發出 `suck_missed`／`spit_missed`，同時發出 `action_missed(lane, reason)` 附上原因。暈眩中 `turn_head()` 沒有效果，每局開始時面向左。
- 大叫轉頭由 `scenes/game/shout_turn_input.gd`（`ShoutTurnInput`）處理：讀玩家 B 的音量（手機 2 有連上讀手機，否則讀電腦麥克風），`volume_value` 超過 `MicInput.shout_threshold`（預設 50）呼叫一次 `turn_head()`，降到 `MicInput.shout_release`（預設 35）以下才能再觸發；兩個門檻在麥克風設定面板調整並存進 `user://mic_settings.cfg`。偵測邏輯在 `ShoutDetector`，Client 的 `ClientPlay` 共用，連線局用 `NetworkManager.send_voice_word(WORD_TURN)` 傳給 Host。
- 鍵盤測試輸入 `scenes/game/keyboard_input.gd` 就是用這些呼叫（按住 K 噴火、L 轉頭），可以當作範例。

## 給 UI：遊戲流程

| 呼叫 | 用途 |
|---|---|
| `game_manager.start_game()` | 開始遊戲，也用於「重新遊玩」 |

- 開啟場景時是 `WAITING`：每層最前端有 1 個食材、小龍到位、龍在中間層，但靜止不動，吸吐沒有作用。
- 第一次呼叫 `start_game()` 直接沿用擺好的場景開始；之後再呼叫會原地重置隊伍、鍋子、胃袋、完成鍋數、清空次數與龍的位置，再開始。重置時會發出對應的 signal（`pot_changed`、`stomach_changed`、`completed_count_changed` 等），UI 照常更新即可。
- 遊戲場景載入後由 `UIGameBridge` 自動呼叫 `start_game()`，第一局開始時呼叫麥克風輸入的校正（主選單是獨立場景，見 design.md 6.1）。
- 「下一關」要等關卡資料完成後才會提供。

## 給 UI：查詢資料

| 屬性 / 函式 | 型別 | 內容 |
|---|---|---|
| `game_manager.get_pot(lane)` | `PotState` | 某一層的鍋子與小龍 |
| `PotState.forbidden` | `Array[IngredientType.Type]` | 禁止食材（1～3 種） |
| `PotState.required` | `int` | 需求數量 |
| `PotState.count` | `int` | 目前數量 |
| `PotState.is_full()` | `bool` | 數量已達需求，等待噴火煮好（還沒完成） |
| `PotState.cook_progress` | `float` | 對已滿鍋子噴火煮的進度，0～1；每幀變動，不會發 `pot_changed`，要自己每幀讀 |
| `PotState.has_baby` | `bool` | 小龍是否到位；`false` 表示正在換小龍，這時不能吐入 |
| `game_manager.stomach` | `IngredientState` | 胃袋裡的食材，胃空時為 `null`；種類是 `.type` |
| `game_manager.completed_count` / `pots_to_win` | `int` | 完成鍋數 / 成功需要的鍋數 |
| `game_manager.cleared_count` / `clears_to_lose` | `int` | 清空次數 / 失敗需要的次數 |
| `game_manager.state` | `GameManager.GameState` | `WAITING`（等待開始）、`PLAYING`（遊玩中）、`ENDED`（已分出勝敗） |
| `game_manager.is_spitting` | `bool` | 玩家 B 正在持續喊「吐」 |
| `game_manager.is_breathing_fire()` / `is_cooking()` | `bool` | 正在噴火燒食材 / 正在對已滿的鍋子噴火煮 |
| `IngredientState.burn_progress` | `float` | 食材被燒的進度，0～1；中途停止噴火不會歸零 |
| `IngredientState.attack_progress` | `float` | 攻擊蓄力進度，0～1；只有隊伍最前端的食材會蓄力，攻擊後歸零 |
| `game_manager.get_spawn_interval()` | `float` | 目前的食材生成間隔（秒），隨完成鍋數變短 |
| `game_manager.get_front(lane)` | `IngredientState` | 某一層已到最前端的食材，沒有則為 `null` |
| `game_manager.is_stunned()` / `stun_remaining` | `bool` / `float` | 龍是否暈眩 / 剩餘暈眩秒數 |
| `game_manager.is_invincible()` / `invincible_remaining` | `bool` / `float` | 龍是否在暈眩後的無敵時間 / 剩餘秒數 |
| `dragon.current_lane` | `int` | 龍目前所在的層 |
| `game_manager.facing` | `GameManager.Facing` | 龍頭朝向：`LEFT` 面向食材、`RIGHT` 面向鍋子 |
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
| `game_started` | `start_game()` 完成重置並開始遊玩 |
| `game_won` / `game_lost` | 遊戲成功 / 失敗，之後不再接受吸吐，`state` 變為 `ENDED` |
| `ingredient_swallowed(lane, ingredient)` | 食材被吞進胃袋 |
| `ingredient_spat(lane, ingredient)` | 胃裡的食材吐進鍋子 |
| `ingredient_burned(lane, ingredient)` | 食材被噴火燒掉 |
| `ingredient_attacked(lane, ingredient, hit)` | 最前端食材蓄滿出手。`hit` 為 `false` 表示龍正在暈眩或無敵，這次打空 |
| `dragon_stunned` | 龍被打中開始暈眩 |
| `dragon_recovered` | 龍暈眩結束，接著進入無敵時間（`invincible_remaining` 秒） |
| `facing_changed(facing)` | 龍頭朝向改變（`GameManager.Facing.LEFT`／`RIGHT`），重置時轉回左邊也會發出 |
| `suck_missed(lane)` / `spit_missed(lane)` | 喊了吸或吐但沒有效果。噴火時只在一開始沒有可燒的食材才會發出。遊戲場景不再為此播放特效 |
| `action_missed(lane, reason)` | 和 `suck_missed`／`spit_missed` 一起發出。`reason` 是 `GameManager.MissReason`：`NO_INGREDIENT`、`STOMACH_FULL`、`FACING_RIGHT`、`SPIT_FACING_LEFT`、`NOTHING_TO_SPIT`、`POT_FULL`、`NO_BABY`；`ActionHintBanner` 用它在畫面上方顯示提示 |

`Dragon`：

| signal | 時機 |
|---|---|
| `current_lane_changed(lane)` | 龍目前所在的層改變 |

## 注意

- 開場的 `baby_arrived`、`pot_changed` 在 `GameManager._ready()` 發出。UI 如果是遊戲場景 `scenes/game/main.tscn` 的子節點，在自己的 `_ready()` 連接就不會漏接；如果放在別的場景，連接後請先主動用 `get_pot()` 等查詢讀一次目前狀態。
- 不要直接修改 `GameManager` 或 `PotState` 的資料，只讀取。
