# 紅龍吸取與噴火特效

交付：@技術美術與特效，2026-10-03。此模組提供視覺效果，食材銷毀、進鍋、命中、換層及動畫作用時刻由玩法程式決定。使用者已確認氣流向嘴收束、暖色錐形火焰，並於 ART-07 緊急任務要求「更誇張、覆蓋更大的範圍」。本文件的「吐」指**胃袋空時噴火**，沒有製作新的胃袋吐食材表現。

## ART-07 加寬與設定方式

本輪在 `def2614` 的現有版本上新增分別可調的 **完整寬度（直徑）**：吸取預設 4.0、噴火預設 3.0 Godot 世界單位。相較原版直徑 0.7，分別約為 5.7 倍、4.3 倍；依使用者的新方向採較大的覆蓋面，而非恢復原版清淡預設。射程仍為 6.0，沒有隨加寬改動。

在 Godot 開啟 `scenes/main/main.tscn`，選取 **Main → Effects（`%Effects`）**，Inspector 的 **Effect Widths** 群組可設定 **Suction Width**／**Fire Width**。兩者皆為正的可調參數，合法範圍 **0.1～8.0**；Inspector 的 **Effect Range** 是另外的長度設定。獨立預覽则選取 `VfxPreview/DragonEffects` 的相同屬性。

寬度定義為錐形／收束流**最寬截面的基準直徑**，內部 `radius = width / 2`；嘴端仍收窄。粒子本體與錐形波動可略超出該基準輪廓，不代表玩法判定區域。角色根倍率 5 不會讓寬度再乘 5。

```gdscript
@onready var effects: DragonEffects = %Effects

func _ready() -> void:
	# 同時驗證兩個輸入；合法值會立即生效。
	if not effects.set_effect_widths(4.0, 3.0):
		print(effects.last_error)

func tune_during_playback() -> void:
	effects.suction_width = 5.0 # 只改吸取，完整直徑 5 世界單位。
	effects.fire_width = 4.0    # 只改噴火，不改射程。
```

執行前設定會用於下次播放；**播放中／尾端消散中設定也會立即更新**粒子 spread uniform、核心錐形及 `visibility_aabb`，下一次 GPU 更新顯示變化。調整寬度不重新啟動粒子，不發 started／interrupted 事件，不改 duration、射程、命中或食材處理。

`set_effect_widths(suction: float, fire: float) -> bool` 對兩個輸入先一起驗證：0、負數、NaN、Infinity 回傳 false，兩個寬度都保留；原因見 `last_error`。正數小於 0.1／大於 8.0 會 clamp 到 0.1／8.0 並回傳 true。分別寫入 `suction_width`／`fire_width` 也採同樣規則，非法值會被忽略。

### 舊 radius 相容規則

舊 `radius` **仍然是半徑，沒有改成直徑**。寫入時同步設定兩種效果為 `2 * radius`，讀取時回傳目前吸取寬度的一半；兩種寬度不同時，請直接讀各自的 width。

```gdscript
effects.radius = 0.35 # 舊寫法：兩種完整寬度都回到 0.7。
effects.set_effect_widths(4.0, 3.0) # 新寫法：分別控制。
```

radius 保留為程式與舊 `.tscn` 的相容屬性，不再在新 Inspector 顯示／存檔；新場景只保存各自的寬度，以免衍生 radius 在載入時覆蓋不同的寬度。舊場景已序列化的 radius 仍可正常載入，已做 round-trip 與舊場景載入驗證。舊 radius 的正數寫入 clamp 至 0.01～4.0；原先可設定的 0.01～1.5 全部保留其半徑語意。**舊相容特例**：radius=0.01 可得到完整寬度 0.02；新 width 接口仍嚴格 clamp 至 0.1～8.0。非法 radius 不更改設定。

## 檔案內容

| 檔案（`res://scenes/vfx/`） | 內容 |
|---|---|
| `dragon_effects.tscn`、`dragon_effects.gd` | `DragonEffects` 控制器；綁定嘴部接口、播放／中斷／完成事件、世界目標更新及視覺射程限制 |
| `suction_effect.tscn` | `SuctionEffect`；淡藍氣流由目標端收束至嘴部；透過控制器播放時預設 192 粒子 |
| `fire_breath_effect.tscn` | `FireBreathEffect`；連續錐形核心、暖色粒子、少量火星與淡煙；透過控制器播放時預設 192 + 16 + 12 粒子 |
| `directed_effect.gd` | 粒子資源隔離、世界端點與剔除邊界更新、發射／尾端消散／立即清場 |
| `endpoint_flow.gdshader` | `particles` shader；收束／向外流動、錐形展開、旋流、淡出，以及配合加寬的氣流筆畫與火焰粒子形狀 |
| `flow_surface.gdshader` | `spatial` shader；沿畫面作用方向排列粒子，以 UV 程序形狀產生氣流／火焰／火星／煙；不需要外部貼圖 |
| `flame_core.gdshader` | 低透明度錐形核心的程序起伏與流動紋理，填補粒子間隙，與尾端一併淡出 |
| `vfx_preview.tscn`、`vfx_preview.gd` | 實例化目前主場景的 F6 展示，保留使用者主龍變換；使用目標圓環，不生成食材 |
| `verify_dragon_vfx.gd` | 無視窗接口、資源隔離及實際嘴部／主場景整合驗證 |
| `capture_dragon_vfx.gd` | Forward Plus GPU 擷取工具；固定取樣的 fly 姿勢以比較特效，不修改來源場景 |
| `qa/*.png` | 同一主鏡頭、同一龍姿勢的原版／最小／預設／最大寬度、加長射程及停止對比畫面 |

腳本、shader 的 `.uid` 及 QA 圖片的 `.import` 一併交付。共享文件由總監維護，主場景接入由場景美術負責；本 session 沒有修改紅龍、主場景、來源模型、InputMap、攝影機或 Environment。

## 整合接口

根節點類別為 `DragonEffects`。在主場景實例化一次，Inspector 的 `dragon_path` 指向紅龍，例如 `../RedDragon`；或於 ready 後呼叫：

目前 Main 的 `RedDragon` 提供 `get_mouth_anchor() -> Marker3D`。未來接入 `game.tscn` 時，外層 `Game/Dragon` 是玩法移動包裝節點，**沒有此方法**；須綁定內層 **`Game/Dragon/Model`（RedDragon）**，例如在 Game 腳本呼叫 `effects.bind_dragon($Dragon/Model)`。本輪沒有修改 game／dragon 或接入玩法。

```gdscript
@onready var effects: DragonEffects = %Effects
@onready var dragon: Node3D = %RedDragon

func _ready() -> void:
	if not effects.bind_dragon(dragon):
		print(effects.last_error)

func show_suction(target_marker: Marker3D) -> void:
	effects.play_suction(target_marker.global_position, effects.default_duration)

func show_fire(target_marker: Marker3D) -> void:
	effects.play_fire(target_marker.global_position, 0.6)

func cancel_action() -> void:
	effects.stop_effects()
```

| 方法 | 行為 |
|---|---|
| `bind_dragon(dragon: Node3D) -> bool` | 綁定具 `get_mouth_anchor() -> Marker3D` 的角色；更換綁定會中斷舊效果。節點或掛點不可用時回傳 false |
| `play_suction(target_global_position: Vector3, duration: float = 0.6) -> bool` | 從目標端吸向嘴部；duration 是發射秒數。每次呼叫重新播放，並中斷既有效果 |
| `play_fire(target_global_position: Vector3, duration: float = 0.6) -> bool` | 從嘴部噴向目標端；參數及重播規則同上 |
| `set_target_global_position(position: Vector3) -> void` | 更新世界目標，可在效果播放時逐幀呼叫；不保存食材節點引用 |
| `stop_effects() -> void` | 立即停止發射並隱藏／清除尾端；無作用中的效果時不發事件 |
| `set_effect_widths(suction: float, fire: float) -> bool` | 同時設定完整寬度；非法輸入不修改任何一邊，正的超界值 clamp；播放中即時更新 |
| `get_active_effect() -> StringName` | 回傳 `suction`、`fire` 或空字串；消散期間仍算作用中 |
| `get_visual_end_global_position() -> Vector3` | 最近一次計算的視覺端點，供除錯或範圍提示使用；閒置時可能是前次端點 |

未 ready、未綁定、缺掛點、非有限座標／duration、非正 duration，或目標距嘴部小於 0.01 單位，播放會回傳 false；原因可讀 `last_error`。失敗的播放請求不替換既有效果。掛點於播放中被移除，或目標移到嘴部，則中斷並清場。非有限目標更新會被忽略。

不直接綁定 `roar`／`atk`，也不使用 `animation_finished` 作命中判定。現有專用吸取／噴火動畫及作用時刻尚未定案；玩法需在自己的作用時刻呼叫特效，在取消／切換樓層時明確停止。

## 事件與消散

```gdscript
signal effect_started(effect_name: StringName)
signal effect_finished(effect_name: StringName)
signal effect_interrupted(effect_name: StringName)
```

- 一般播放：`effect_started(new)`。
- 切換、同效果重播：`effect_interrupted(old)` → `effect_started(new)`。
- 自然結束：停止新粒子發射，保留尾端淡出，再發出 `effect_finished(name)`。
- 明確停止、重新綁定或掛點失效：立即清場，僅發出 `effect_interrupted(name)`。
- 事件回呼中發出的較新播放／停止請求優先，不被外層舊請求覆蓋。

預設吸取尾端最多 0.33 秒、噴火最多 0.43 秒；例如 duration=0.6 的完整視覺週期約為 0.93／1.03 秒。這是視覺完成事件，不代表食材命中或進鍋。

## Inspector、世界尺寸與預算

| 屬性 | 預設 | 說明 |
|---|---:|---|
| `dragon_path` | 空 | 相對控制器的角色節點路徑；空時由程式綁定 |
| `default_duration` | 0.6 秒 | 提供呼叫端與預覽使用；範例會明確傳入此值。省略函式 duration 參數時為簽名中的固定 0.6 秒 |
| `effect_range` | 6 單位 | 嘴部至視覺端點的最大距離；不改變遊戲作用範圍 |
| `suction_width` | 4.0 單位 | 收束氣流最寬截面的完整直徑；0.1～8.0 |
| `fire_width` | 3.0 單位 | 火焰錐形最寬截面的完整直徑；0.1～8.0 |
| 舊 `radius` 程式屬性 | 吸取寬度 / 2 | 相容半徑；寫入會同步兩種寬度，詳見上方規則 |
| `particle_count` | 192 | 主要氣流／火焰粒子數；火星 16、煙 12 於噴火子場景獨立設定 |
| 子場景 `particle_lifetime` | 0.28 秒 | 主要粒子最長生命週期；火星 0.25、煙 0.38 秒 |

全部距離、半徑、粒子大小與剔除邊界使用 Godot **世界單位**。嘴部掛點繼承角色的變換，特效子場景則隔離父節點變換，以世界座標更新 shader；角色根倍率 2、5 或旋轉／位移不會把火焰尺寸再乘上角色倍率。

預設主粒子由 96 增至 192，避免只擴大空間而氣流過於稀疏；筆畫寬度也隨分布加寬，在 shader 中限制放大倍率。兩種效果互斥播放，吸取可見預算 192、噴火 220；兩套主粒子均播放過後，最大配置合計 412，加上一個 12 邊錐形核心，最多 4 個繪製通道同時可見。每實例的 4 個粒子 process material、4 個繪製 material、核心 material 及 4 個 QuadMesh 均獨立；不可變的 shader 程式與核心 mesh 可共享。沒有新增粒子碰撞／吸引器／光源／Glow／景深。最大寬度 8 的覆蓋面是壓力展示，密度仍可由 particle_count 調整。

端點超界時，以 `(target - mouth).limit_length(effect_range)` 截短視覺長度，仍朝原目標方向。吸取粒子此時從截短端點收束，**不會在真正超界目標附近生成**；噴火也不會觸及真正超界目標。需完整連接兩點時，由呼叫端調整視覺 `effect_range`，不能據此判定玩法命中。

## 預覽

開啟 `res://scenes/vfx/vfx_preview.tscn` 按 F6：

- `1` 吸取、`2` 噴火、空白立即停止。
- **Q／A** 增加／減少吸取完整寬度，**W／S** 增加／減少噴火完整寬度；每次 0.25，clamp 至 0.1～8.0，可在播放中操作。
- Tab 在兩個左房目標間切換；`+`／`-` 每次增減視覺射程 1 單位（範圍 1～20）。
- PageUp／PageDown 在預覽內上下移動龍與目標，切層前清除特效；不改來源 main 的變換。
- 預覽即時顯示兩種寬度、射程、世界單位及完整直徑，繁中說明使用作業系統字型（Windows Microsoft JhengHei；無外部字型素材依賴）。
- 圓環及「特效目標」是效果定位提示，沒有食材、傷害或鍋子規則；這些按鍵不寫入 InputMap。

主場景保持預設不發射；如場景美術已接入 `%Effects`，預覽使用自己的控制器進行操作，主場景內控制器仍保持閒置。

## 驗證與目前限制

2026-10-03，在專用 Windows Temp 專案副本使用 Godot 4.7.2 驗證，未對共享專案執行匯入。寬度驗證以 def2614 為基礎；副本暫停音訊／網路／暫停選單 autoload，使檢查聚焦特效，沒有改共享 project.godot。

- 無視窗驗證：`VFX_RESULT checks=122 failures=0`。保留原 64 項接口／嘴部／停止／消散／兩實例檢查，新增最小／預設／最大寬度、shader 半徑、錐形世界尺寸、AABB、播放中即時變寬、非法數值與原子更新、clamp、舊 radius、獨立寬度存檔往返及舊場景載入，以及繁中預覽四個寬度按鍵與顯示值。
- 場景美術接入的 Main `%Effects` 已驗證自動綁定 `../RedDragon`、初始閒置及播放接受。
- GPU 使用 **D3D12／Forward Plus／RTX 4070 Laptop GPU**，1600 × 900；三個 shader 實際編譯，原版、最小／預設／最大寬度等 11 張 PNG 擷取成功。`INSTANCE_CUSTOM` 從 vertex 透過 varying 傳入 fragment；無 shader／script 解析錯誤。停止後圖片與待機圖片 SHA-256 相同，沒有殘留特效。
- 圖片取樣保留已確認的 root scale 5、position `(0, 6.4, -16.018951)`；固定當下 fly 姿勢後比較 VFX。取樣嘴部約 `(-0.38, 10.98, -4.95)`，目標 `(-4.6, 6, 1.1)`，該姿勢相距約 8.9 單位，故預設 6 單位會截短；另附 range=12 的連接目標畫面，沒有改攝影機或主龍布局。**8.9 是單次取樣，非全程固定距離**；fly 起伏、頭部動作及樓層切換都會改變嘴部至目標的距離，視覺端點逐幀重算。
- 目前龍面向攝影機，效果方向由世界目標計算，沒有替龍頭轉向；噴射方向可能與嘴部局部 -Z 不一致。自然的朝左動作仍需動畫／玩法整合決定，不私自改使用者構圖。
- 最終 GPU 圖片保留三種龍蛋及幼龍。新預設吸取 4／噴火 3 明顯擴大覆蓋，會局部蓋住龍爪及左房靠通道的邊緣，右側鍋子與育幼陳設仍可讀。**最大寬度 8 會跨到鄰層並遮住部分左房、龍爪與通道**；這是使用者要求的大覆蓋範圍，不是同層安全判定。遊戲目前使用暫時食材模型，但此輪未接 game；對實際隊伍與 UI 的遮擋須在 gameplay 接入後檢查。主龍倍率 5 的部分 fly 姿勢本身可能超出相機／房間邊界，本模組沒有擴大鏡頭。
- 龍根節點位於中層，不代表嘴部也位於中層；目前倍率與 fly 姿勢使嘴部高於中層目標，效果會由高處斜向中層。若玩法需要嚴格的同層水平口部表現，須由團隊另定角色／動畫對位策略，本控制器不自行校正龍的位置。
- 適用目前 Forward Plus。沒有驗證 Web／Compatibility、目標装置效能或所有動畫姿勢下的遮擋；平台變更需另驗證。
- 執行環境仍有 root certificate store 警告；獨立副本一度出現 `ground.tres` 引用的 UID 快取未完整註冊警告，回退有效文字路徑後正常載入。共享來源的 UID 與貼圖 `.import` 一致，沒有修改來源資源。

### 同姿勢、同射程的 GPU 寬度對比

以下全部使用本輪驗證時的主龍 fly 取樣、倍率 5、射程 6；固定種子，固定取樣姿勢。原版使用 96 主粒子，新版最小／預設／最大使用 192。圖片包含繁中即時寬度讀值，沒有替鏡頭或主龍重新構圖。

| 情境 | 吸取完整寬度 | 噴火完整寬度 | 吸取 | 噴火 |
|---|---:|---:|---|---|
| 原版 | 0.7 | 0.7 | [原版吸取](../scenes/vfx/qa/width_suction_before.png) | [原版噴火](../scenes/vfx/qa/width_fire_before.png) |
| 最小 | 0.1 | 0.1 | [最小吸取](../scenes/vfx/qa/width_suction_min.png) | [最小噴火](../scenes/vfx/qa/width_fire_min.png) |
| 新預設 | 4.0 | 3.0 | [預設吸取](../scenes/vfx/qa/vfx_suction.png) | [預設噴火](../scenes/vfx/qa/vfx_fire.png) |
| 最大 | 8.0 | 8.0 | [最大吸取](../scenes/vfx/qa/width_suction_max.png) | [最大噴火](../scenes/vfx/qa/width_fire_max.png) |

另附 [射程 12 的預設寬度噴火](../scenes/vfx/qa/vfx_fire_range12.png)，供射程與寬度的分別比較。本圖代表本輪取樣；ART-09 其後由使用者解決並撤回，本輪未改動畫，不另做撤回任務回歸。

![預設加寬吸取](../scenes/vfx/qa/vfx_suction.png)
![預設加寬噴火](../scenes/vfx/qa/vfx_fire.png)

重跑方式（先準備獨立匯入副本）：

```powershell
& "<Godot 執行檔>" --headless --path "<專案副本>" --script res://scenes/vfx/verify_dragon_vfx.gd
& "<Godot 執行檔>" --path "<專案副本>" --rendering-method forward_plus --rendering-driver d3d12 --script res://scenes/vfx/capture_dragon_vfx.gd -- --output=<絕對輸出目錄>
```

程序 shader 不需要新增外部素材。剩餘待團隊決定的是專用動作／作用時刻、轉頭呈現、實際食材效果目標點及視覺射程配置。首版已隨團隊提交；**本輪 ART-07 加寬於 2026-10-03 已獲使用者驗收，授權 commit／push 並建立 PR**。
