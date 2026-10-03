# 聲音輸入系統（MicInput）

本文件說明麥克風輸入控制器的使用方法與串接方式。對應 tasks.md 的 MIC 區塊。
玩法對聲音操作的定義見 [design.md](design.md) 第 3 節。

## 1. 概覽

控制器是一個 autoload，全域名稱 **`MicInput`**（腳本 `autoload/mic_controller.gd`，類別名稱 `MicController`）。
遊戲程式只要讀它的輸出，不需要自己處理麥克風。

它把一支麥克風的聲音轉成三種輸出：

| 輸出 | 說明 | 對應玩法 |
|---|---|---|
| 音量 | 小聲～大聲 轉成 0～100 | 玩家 A：龍飛到哪一層 |
| 音高 | 低音～高音 轉成 0～100 | 目前沒有對應玩法，備用 |
| 吸／吐 | 辨認字音，輸出 `inhale` 或 `exhale` | 玩家 B：吸、噴火 |

三種輸出都是「按住」模式：聲音持續就持續輸出，聲音中斷才放開（見第 4 節）。
所有區間與閥值都能在遊戲中由玩家用暫停選單調整，設定會存檔（見第 6 節）。

> 目前只接一支麥克風。雙麥克風（玩家 A、玩家 B 各一支）是 MIC-03，還沒做。

## 2. 快速使用

`MicInput` 在任何場景都能直接用，不用實例化、不用 `get_node`。
遊戲端的呼叫對象見 [api.md](api.md)「給麥克風輸入：操作龍」；鍵盤版的接法可以參考 `scenes/game/keyboard_input.gd`，聲音輸入就是用同樣的呼叫取代按鍵。

### 音量 → 龍的目標層

層從 0（最低層）開始，音量大對應高層（design.md 3.1）。

```gdscript
@export var dragon: Dragon
@export var game_manager: GameManager

func _process(_delta: float) -> void:
	var lane_count: int = game_manager.lane_layout.lane_count
	var lane: int = clampi(int(MicInput.volume_value / 100.0 * lane_count), 0, lane_count - 1)
	dragon.set_target_lane(lane)
```

沒出聲時 `volume_value` 會維持最後的值，所以龍會停在最後的高度，不需要額外處理。

### 吸／吐 → 吸與吐

「吐」要回報開始和結束，剛好對應按住模式：`exhale` 開始時呼叫 `spit_pressed()`，放開時呼叫 `spit_released()`。

```gdscript
var _previous_action: StringName = &""

func _ready() -> void:
	MicInput.action_changed.connect(_on_action_changed)

func _on_action_changed(action: StringName) -> void:
	if _previous_action == MicController.EXHALE:
		game_manager.spit_released()
	match action:
		MicController.INHALE:   # &"inhale"
			game_manager.suck()
		MicController.EXHALE:   # &"exhale"
			game_manager.spit_pressed()
	_previous_action = action
```

`action_changed` 在「開始按住」和「放開」時各發一次（放開時 `action` 為 `&""`），所以：

- 每次發聲只要觸發一次動作（例如吸走一個食材）：在 `action_changed` 收到 `inhale` 時處理。
- 需要「按住期間持續作用」（例如噴火）：開始時呼叫 `spit_pressed()`，放開時呼叫 `spit_released()`，或在 `_process` 讀 `MicInput.action`。
- 遊戲狀態是 `WAITING` 或 `ENDED` 時，吸吐沒有作用，不需要自己擋。

## 3. 輸出（唯讀）

| 屬性 | 型別 | 說明 |
|---|---|---|
| `volume_value` | float 0～100 | 音量輸出。低於小音量時不更新，維持最後的值 |
| `volume_active` | bool | 音量是否按住中 |
| `volume_db` | float | 目前音量（dB，-60～0），即時值，供畫面或除錯用 |
| `pitch_value` | float 0～100 | 音高輸出（對數刻度）。沒有明確音高時維持最後的值 |
| `pitch_active` | bool | 音高是否按住中 |
| `pitch_hz` | float | 目前音高（Hz），沒有明確音高時為 0 |
| `action` | StringName | 目前按住的動作：`&"inhale"`、`&"exhale"`，沒有則 `&""` |
| `last_action` | StringName | 最後一次按住的動作，放開後仍保留；還沒有過則為 `&""`。給 UI 顯示「最後辨識到的字音」用 |
| `mic_status` | `MicController.MicStatus` | 麥克風收音狀態：`LISTENING` 收音中、`NO_SIGNAL` 一直收不到訊號而停止、`DISABLED` 已停用 |
| `mic_enabled` | bool | 麥克風開關（會存檔），用 `set_mic_enabled()` 切換 |
| `voicedness` | float 0～100 | 氣音軸即時值（0 = 嘶聲、100 = 母音），供畫面或除錯用 |

| Signal | 說明 |
|---|---|
| `action_changed(action: StringName)` | `action` 改變時發出，放開時 `action` 為 `&""` |
| `mic_status_changed(status)` | `mic_status` 改變時發出 |

常數：`MicController.INHALE`、`MicController.EXHALE`。

## 4. 運作規則

### 按住（持續按鍵）

聲音持續就持續輸出（`*_active` 為 true），中斷超過 `*_release_seconds` 才放開。
短暫中斷（例如換氣、說話停頓）不會放開。放開後數值維持最後的值，不會歸零，符合 design.md「沒出聲：停在最後的高度」。

### 音量

音量低於 `volume_min_db` 視為沒有聲音。`volume_min_db` ～ `volume_max_db` 線性轉成 0～100。

### 音高

用自相關法偵測，範圍 70～1000 Hz。`pitch_min_hz` ～ `pitch_max_hz` 以對數刻度轉成 0～100。
音量低於 `pitch_gate_db`，或沒有明確音高（自相關峰值低於 `min_correlation`）時不更新。

### 吸／吐

只有兩個字音要分，所以不用語音辨識套件，而是看聲音特徵：「吸 / shi / si」開頭是長的氣音（嘶），「吐 / tu」是短爆音接母音（嗚）。

1. 音量高於 `action_gate_db` 才判定。
2. 每段取樣用零交越率（ZCR）判斷是不是氣音；ZCR 高於 `noisy_zcr` 算氣音。
3. 氣音軸 `voicedness` 是氣音比例的反向、做過平滑（`analysis_seconds`）的 0～100：0 = 全是嘶聲，100 = 全是母音。
4. `voicedness <= inhale_max` 為吸區，輸出 `inhale`；`>= exhale_min` 為吐區，輸出 `exhale`；兩者之間不輸出。
5. 落在某一區至少 `action_min_seconds` 才輸出，用來忽略爆音和過短的聲音。
6. 同一次發音內，不會從吸切到吐（或反過來）。聲音中斷超過 `segment_gap_seconds` 才算新的一次發音。

## 4.1 麥克風無法使用時

開始收音後 1.5 秒（`NO_SIGNAL_TIMEOUT`）內一直收不到任何訊號（取樣全是 0），控制器會停止收音、發出一則 `push_warning`，並把 `mic_status` 改為 `NO_SIGNAL`。
設定面板這時會顯示警告文字；玩家可以換輸入裝置（自動重新收音）或按「重新偵測」。面板上的「啟用麥克風」開關可以完全停用麥克風，停用狀態會存檔。

相關函式：`start_microphone()`、`stop_microphone()`、`restart_microphone()`、`set_mic_enabled(enabled)`、`set_input_device(device)`。換輸入裝置請用 `set_input_device()`，不要直接改 `AudioServer.input_device`，否則不會重新收音。

### Windows 的「unsupported channel count in microphone!」

部分 Windows 裝置（例如多聲道的陣列麥克風、虛擬音效裝置）的聲道數 Godot 不支援，Godot 的 WASAPI 驅動會每個迴圈印一次 `thread_func: WASAPI: unsupported channel count in microphone!`，導致上萬則錯誤。這個訊息來自引擎 C++ 層，GDScript 無法關掉，所以做法是偵測到沒有訊號就停止收音，讓錯誤只出現很短一陣。
要真正解決，請換一個輸入裝置（例如耳機麥克風），或在 Windows「聲音」設定裡把該麥克風的預設格式改成 1 或 2 聲道。

## 5. 設定參數

這些是 `MicInput` 的 `@export` 變數，可以在程式裡直接改（改了立刻生效），玩家也能在暫停選單調整。
標「存檔」的會寫進存檔。

### 音量

| 參數 | 預設 | 存檔 | 說明 |
|---|---|---|---|
| `volume_min_db` | -45 | 是 | 小音量（輸出 0） |
| `volume_max_db` | -15 | 是 | 大音量（輸出 100） |
| `volume_release_seconds` | 0.1 | 是 | 聲音中斷多久才放開 |

### 音高

| 參數 | 預設 | 存檔 | 說明 |
|---|---|---|---|
| `pitch_min_hz` | 100 | 是 | 低音（輸出 0） |
| `pitch_max_hz` | 500 | 是 | 高音（輸出 100） |
| `pitch_release_seconds` | 0.1 | 是 | 放開延遲 |
| `pitch_gate_db` | -45 | 否 | 低於此音量不做音高判定 |
| `min_correlation` | 0.5 | 否 | 自相關峰值門檻，越高越嚴格 |

### 吸／吐

| 參數 | 預設 | 存檔 | 說明 |
|---|---|---|---|
| `action_gate_db` | -35 | 是 | 音量閥值，低於此音量不判定 |
| `inhale_max` | 50 | 是 | 氣音軸上，小於等於此值為吸區 |
| `exhale_min` | 75 | 是 | 氣音軸上，大於等於此值為吐區 |
| `action_release_seconds` | 0.1 | 是 | 放開延遲 |
| `noisy_zcr` | 0.12 | 否 | ZCR 高於此值算氣音 |
| `analysis_seconds` | 0.08 | 否 | 氣音軸平滑時間，越長越穩但反應越慢 |
| `action_min_seconds` | 0.08 | 否 | 落在吸／吐區多久才輸出 |
| `segment_gap_seconds` | 0.15 | 否 | 聲音中斷多久算新的一次發音 |

預設值是用合成資料調的，還沒用真人聲音長時間實測。
「tu」開頭的爆音（t）可能被誤判成吸，遇到時優先調 `action_min_seconds` 和 `noisy_zcr`。

## 6. 暫停選單與存檔

- **Esc 暫停選單**（autoload `PauseMenu`，`scenes/pause_menu/pause_menu.tscn`）：任何場景按 Esc 都會暫停場景（`get_tree().paused = true`）並顯示設定面板，再按 Esc 或「繼續遊戲」回到遊戲。
- 暫停時 `MicInput` 仍然運作（`process_mode` 為 Always），所以設定面板能即時回饋。遊戲節點照常被暫停。
- 設定面板左邊：觀察與拖曳設定區間（白線是即時值，拖曳把手調整）；右邊：目前輸出結果。
- **存檔**：設定存在 `user://mic_settings.cfg`（含選的輸入裝置）。在關閉選單、面板移除、關閉視窗時寫入，啟動時讀回。
- 存檔裡的值會蓋過程式碼裡的預設值。改了 `@export` 預設值後，已經有存檔的機器不會跟著變，要刪掉存檔才會套用新預設。

存檔的位置依平台不同：macOS 在 `~/Library/Application Support/Godot/app_userdata/FGJ2026E_Game/`，Windows 在 `%APPDATA%\Godot\app_userdata\FGJ2026E_Game\`。

## 7. 測試

- 單獨測試：在編輯器開啟 `scenes/mic_test/mic_test.tscn` 按 F6。這個場景只實例化設定面板，不含遊戲。
- 專案已啟用音訊輸入（`project.godot` 的 `audio/driver/enable_input`）。macOS 第一次執行會跳出麥克風權限，要允許 Godot。
- 在沒有麥克風的環境（headless、CI）不會有輸入，所有輸出維持初始值。要測邏輯，可以直接呼叫控制器內部的 `_on_chunk(zcr, db, seconds)` 和 `_update_outputs(delta)` 餵假資料。

## 8. 檔案對照

| 檔案 | 說明 |
|---|---|
| `autoload/mic_controller.gd` | 控制器本體：收音、音量、音高、吸／吐、按住、存檔 |
| `scenes/pause_menu/pause_menu.tscn`、`.gd` | Esc 暫停選單（autoload `PauseMenu`） |
| `scenes/pause_menu/mic_settings_panel.tscn`、`.gd` | 設定面板（左邊設定、右邊輸出），暫停選單與 mic_test 共用 |
| `scenes/pause_menu/range_meter.gd` | 可拖曳區間的橫條控制項（類別 `RangeMeter`） |
| `scenes/mic_test/mic_test.tscn` | 單獨測試用場景 |

## 9. 串接時的注意事項

- **不要自己建立第二個麥克風擷取。** 麥克風串流與 `MicInput` bus 由控制器管理，另外建立會互相干擾。要用聲音資料，都讀 `MicInput` 的輸出。
- **Esc 用的是內建的 `ui_cancel`。** 如果你的場景也用 Esc 做別的事（例如關閉自己的 UI），會和暫停選單衝突，要先協調。
- **場景要能被暫停。** 暫停選單用 `get_tree().paused`，遊戲節點預設會被暫停。需要在暫停時繼續跑的節點（例如動畫）要自己設 `process_mode`。
- **新增設定參數時：** 在 `mic_controller.gd` 加 `@export`，需要存檔就加進 `SAVED_PROPERTIES`，需要玩家調整就在 `mic_settings_panel` 加對應的控制項。
- **改 autoload 或設定面板的 .tscn 前**，依 [conventions.md](conventions.md) 先找負責人（歸屬表中 `pause_menu`、`mic_settings_panel`、`mic_test` 為山雷）。

## 10. 尚未完成

- 開局音量校正（design.md 3.1：以遊戲開始時測到的音量作為基準）。
- 雙麥克風（玩家 A、玩家 B）的裝置選擇與收音干擾處理（MIC-03）。
- 用真人聲音實測並調整吸／吐的預設參數。
- 單機保底版（鍵盤 1／2／3 控制龍、麥克風控制吸／吐）已接進 game.tscn：`scenes/game/voice_action_input.gd`。音量控制龍的移動（MIC-05）尚未接。
