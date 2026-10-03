# 紅龍動畫接口

動畫師交付：既有 `RedDragon` 子場景、具型別的 GDScript 控制接口、嘴部掛點及驗證腳本。此接口處理視覺動畫與特效定位；換層、食材、鍋子與聲音操作由玩法程式控制。

## 檔案與節點

- `res://scenes/red_dragon/red_dragon.tscn`：可重用子場景，根節點 `RedDragon` 掛載 `RedDragon` 類別。
- `res://scenes/red_dragon/red_dragon.gd`：控制腳本；對外透過根節點呼叫，不需要取得匯入模型內部節點。
- `res://scenes/red_dragon/verify_dragon_animations.gd`：可重跑的 Godot 無視窗功能驗證。
- 兩個 `.gd.uid` 隨腳本保存。
- 來源 `res://Models/dragon/Red_dragon.glb` 及其 `.import` 保持不變。

```text
RedDragon (Node3D + RedDragon)
└─ Model (匯入場景實例，原有位置與 0.05 比例保留)
   ├─ Armature
   │  └─ Skeleton3D（111 根骨骼）
   │     ├─ mesh
   │     └─ MouthAttachment (BoneAttachment3D，head2)
   │        └─ MouthAnchor (Marker3D，局部 -Z 朝嘴外)
   └─ AnimationPlayer
```

AnimationPlayer 的動畫位於預設 AnimationLibrary，因此使用名稱 `idle`，不需要庫名前綴。

## 動畫播放策略

| 呼叫名稱 | 長度（秒，播放速度 1） | 行為 |
|---|---:|---|
| `idle` | 6.667 | 循環；子場景預設自動播放 |
| `fly` | 6.667 | 循環；主場景可指定為基礎動畫 |
| `atk` | 3.750 | 單次，完成後返回目前基礎動畫；預設原地水平位移 |
| `roar` | 4.583 | 單次，完成後返回目前基礎動畫 |
| `fall` | 4.583 | 單次，保持最後姿勢，直到明確呼叫其他動畫 |
| `pose` | 6.667 | 原始素材為靜態姿勢，單次時間軸結束後保持 |
| `pose2` | 6.667 | 原始素材為靜態姿勢，單次時間軸結束後保持 |

`idle`、`fly` 自然循環時不發出完成訊號。`pose`、`pose2` 雖然畫面靜止，完成訊號仍在其原始時間軸結束時發出。

## Inspector 設定

| 屬性 | 型別／預設 | 用途 |
|---|---|---|
| `base_animation` | `StringName`，`idle` | 可選 `idle` 或 `fly`；場景實例在進入 SceneTree 前設定。無效初始設定會警告並改用 `idle` |
| `blend_time` | `float`，0.2 秒 | 動畫切換的混合時間；0 表示立即切換 |
| `attack_in_place` | `bool`，`true` | 下次播放 `atk` 時固定根骨骼水平位置；`false` 使用原始位移 |
| `fly_loop_blend_time` | `float`，0.2 秒 | 初始化時修正飛行首尾接縫的區段長度，Inspector 範圍 0.05～1 秒；初始化後更改不會重新建立動畫副本 |

執行期間變更基礎動畫使用 `set_base_animation()`；不要以直接寫入屬性取代它的驗證與播放切換。

## 程式接口

```gdscript
play_animation(
    animation_name: StringName,
    restart: bool = false,
    use_original_attack_motion: bool = false
) -> bool

set_base_animation(animation_name: StringName) -> bool
stop_animation(keep_pose: bool = true) -> void
get_animation_names() -> PackedStringArray
get_mouth_anchor() -> Marker3D
```

- `play_animation()`：明確呼叫可中斷目前動作。未知名稱（含空字串）或節點尚未 ready 時回傳 `false`，不改變狀態也不發出訊號。相同動畫仍在播放或自然完成後保持姿勢時，預設回傳 `true` 並保持原狀；`restart=true` 才從頭重播。若要改變同一次 `atk` 的位移模式，也需使用 `restart=true`。
- `set_base_animation()`：只接受 `idle`／`fly`，其他名稱回傳 `false`。可在加入 SceneTree 前呼叫。正在播放基礎動畫時立即切換；正在播放單次動作、保持姿勢或已停止時，只更新返回目標，不強制開始播放。
- `stop_animation()`：停止並發出未完成動作的中斷訊號。預設保持當下所有骨骼姿勢；`keep_pose=false` 套用基礎動畫第一幀後停止。停止後再次 `play_animation()` 可正常開始播放。
- `get_animation_names()`：ready 後回傳 `atk`、`fall`、`fly`、`idle`、`pose`、`pose2`、`roar`；ready 前為空陣列。
- `get_mouth_anchor()`：ready 後回傳本實例的嘴部 Marker3D，ready 前為 `null`。位置與方向隨骨架及角色根節點變換更新，特效程式使用此接口取得世界定位。
- `use_original_attack_motion=true`：只對 `atk` 有效，這次呼叫使用原始水平位移，即使 `attack_in_place=true`。下一次一般呼叫會恢復 Inspector 的設定。

## 訊號

```gdscript
signal animation_started(animation_name: StringName)
signal animation_finished(animation_name: StringName)
signal animation_interrupted(animation_name: StringName)
```

| 事件 | 訊號順序 |
|---|---|
| 初始播放 | `animation_started(base)` |
| 明確切換／重播未完成的動畫 | `animation_interrupted(old)` → `animation_started(new)` |
| `atk`／`roar` 自然完成 | `animation_finished(action)` → `animation_started(base)` |
| `fall`／`pose`／`pose2` 自然完成 | `animation_finished(name)`，保持結尾 |
| `stop_animation()` 停止未完成動畫 | 只有 `animation_interrupted(name)` |
| 重複停止、同名不重播、無效請求 | 不發訊號 |

已自然完成的動畫被切換時，不再發出中斷訊號。訊號處理函式可以明確播放或停止其他動畫；較新的請求優先，控制器不會再用自動返回或原先切換請求覆蓋它。

`animation_finished` 表示視覺時間軸結束，並未定義吸取／噴火的玩法觸發時刻。循環與原生訊號語義參考 [Godot AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html)。

## 呼叫示例

主場景在 Inspector 將紅龍實例的 `base_animation` 設為 `fly`，或生成時先指定：

```gdscript
const DRAGON_SCENE: PackedScene = preload("res://scenes/red_dragon/red_dragon.tscn")

func spawn_dragon(parent: Node3D) -> RedDragon:
    var dragon: RedDragon = DRAGON_SCENE.instantiate() as RedDragon
    dragon.set_base_animation(&"fly")
    parent.add_child(dragon)
    return dragon
```

控制既有實例，需在其 ready 後呼叫：

```gdscript
@onready var dragon: RedDragon = $RedDragon

func _ready() -> void:
    dragon.animation_finished.connect(_on_dragon_animation_finished)
    dragon.set_base_animation(&"fly")

func show_roar() -> void:
    dragon.play_animation(&"roar") # 完成後返回 fly

func replay_attack() -> void:
    dragon.play_animation(&"atk", true) # 原地攻擊，強制重播

func preview_original_attack() -> void:
    dragon.play_animation(&"atk", true, true) # 僅此播放保留原始位移

func show_pose() -> void:
    dragon.play_animation(&"pose2") # 保持姿勢，直到其他明確呼叫

func stop_visuals() -> void:
    dragon.stop_animation() # 保留當下姿勢

func _on_dragon_animation_finished(animation_name: StringName) -> void:
    print("紅龍視覺動畫完成：", animation_name)
```

樓層移動請調整 `RedDragon` 根節點位置；不要移動 `Model` 或直接寫入骨骼來控制樓層。原生 AnimationPlayer 的直接播放會繞過位移模式及控制器狀態，因此遊戲程式使用上述接口。

## 嘴部掛點與特效定位

固定接口為 `get_mouth_anchor() -> Marker3D`，實際節點路徑：

```text
RedDragon/Model/Armature/Skeleton3D/MouthAttachment/MouthAnchor
```

- `MouthAttachment`：Skeleton3D 的子節點，綁定實際骨骼 `head2`（目前索引 17）；`override_pose=false`，只跟隨上顎，不寫入骨骼姿勢。此骨骼的父骨骼為 `head1`。
- `MouthAnchor`：位置 `(-0.057775, 4.813392, -0.658379)`，屬於上顎骨骼的局部座標；旋轉 `(90°, 0°, 0°)`，即弧度 `(1.5707963, 0, 0)`。
- 掛點局部 `-Z` 朝嘴外，對應 `head2` 的局部 `+Y`；掛點 `+Y` 對應上顎局部 `+Z`。這是龍頭的實際朝向，不保證指向某個食材或世界軸。
- 嘴部位置由匯入網格第 0 個表面的上唇中心頂點 3122 量測（網格共有 4836 個頂點）；該頂點對 `head2` 的權重為 1。頂點在網格座標為 `(0, 3.690212, 15.738758)`，經 Skin 的 inverse bind 轉成上顎局部座標約 `(-0.057775, 4.613392, -0.458379)`。
- 在量測點加局部 `(0, 0.2, -0.2)`：向嘴外稍移並略低於上唇邊緣，使特效出口不藏在唇面中。子場景模型比例 0.05、根倍率 1 時，距該唇點約 0.01414 個 Godot 單位；倍率 2 時約 0.02828，倍率 5 時約 0.07071。
- 位置與朝向已以實際網格、骨架、七個動畫及口部前／側近景驗證；沒有用鼻角最前端代替嘴部。這是跟隨上唇的固定出口，張嘴時不會重新取上下顎中點。

ready 後取得世界位置與方向：

```gdscript
var mouth: Marker3D = dragon.get_mouth_anchor()
var origin: Vector3 = mouth.global_position
var outward: Vector3 = -mouth.global_basis.z.normalized()
var world_transform: Transform3D = mouth.global_transform
```

掛點繼承 `Model` 的 0.05 比例與紅龍實例根倍率。讀取方向應 normalize，不能直接把帶比例的 Basis 當單位方向。若特效以世界單位製作，使用位置與方向，或將所讀取 Transform3D 的 Basis orthonormalize；若直接把特效加入 MouthAnchor，其尺寸也會跟隨這個比例。掛點已含角色根節點的位置、旋轉與比例，不應再次乘上紅龍根變換。

已用主場景的最新構圖驗證：根倍率 5、位置 `(0, 6.4, -16.018951)`，保持原有主場景與攝影機。以 `fly` 第 2 秒的測試畫面為例，嘴部世界位置約 `(0.560259, 11.609980, -4.672791)`，朝外單位方向約 `(0.093134, -0.413635, 0.905667)`；這些數值隨動畫改變，特效應逐幀跟隨接口，不寫死座標。

BoneAttachment3D 的原生跟隨行為參考 [Godot BoneAttachment3D](https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html)。

## 動畫副本與修正方法

每個紅龍實例初始化時，建立自己的 AnimationLibrary，對每個 Animation 使用 `duplicate(true)`。循環與接縫只修改副本；來源 GLB、匯入設定與其他實例不受影響。

`fly` 的原始 `arm3.R` 旋轉首尾相差約 31.126°。已在獨立預覽中比對原始首尾畫面，再只修改副本的該旋轉軌道：保留前段，最後 0.2 秒以起點旋轉接回第一幀；使用六段 Quaternion slerp，權重採 smoothstep。修正區段起點保留原曲線值，結尾與第一幀一致，沒有改動其他骨骼軌道。

`atk` 原地模式只修改 `root` 骨骼的 POSITION_3D 軌道：所有 X、Z 值固定為來源第一幀，Y 值保留。每次播放均從來源讀取原值，因此可以反覆切換原地／原始模式，而不會累積修改。這是視覺修正，未實作 Root Motion 的物理驅動。

## 驗證紀錄

2026-10-03，使用 Godot 4.7.2，在 Windows Temp 的獨立專案副本驗證；載入共享專案既有匯入資源，來源 GLB 的 MD5 與匯入紀錄相符。

- 無視窗功能驗證：`RESULT checks=180 failures=0`；原有 89 項動畫檢查仍全部通過。
- 覆蓋七個動畫、三次循環後持續播放、自然完成／明確中斷／強制重播訊號順序、保持結尾、停止姿勢、基礎動畫切換、無效名稱、訊號回呼的較新請求優先，以及 0.2 秒實際混合。
- 兩個實例的 AnimationLibrary 與所有 Animation 資源均隔離；切換一個實例的攻擊位移不影響另一個實例；來源動畫維持未循環及原始飛行接縫。
- 修正後 `fly` 的右臂首尾旋轉角差小於 0.001 rad；修正段起點與原曲線連續。
- GPU 畫面驗證使用 Compatibility／OpenGL：在飛行循環邊界前後以 30 FPS 各擷取原始與修正版 25 幀，檢查接縫與材質，並保存七個動畫中段的姿勢圖。這些是獨立測試畫面，尚未代表主場景的美術驗收；`fall` 原始高度位移也會超出固定預覽鏡頭。主場景 Forward Plus 的最終構圖由整合驗收確認。
- 嘴部新增驗證：ready 前後接口、節點歸屬、綁定骨骼與非覆寫模式、兩個實例隔離、量測頂點的實際蒙皮權重、停止後保持、根倍率 1／2／5、非零根位置與旋轉。
- 每個倍率下，七個動畫各取時間軸 0%、25%、50%、75%、99.9%（共 105 個姿勢）。以原生骨架更新驗證掛點世界 Transform3D，並以真實上唇網格頂點的蒙皮位置核對出口間距；各姿勢位置追蹤誤差在測試輸出中為 0。所有動態動畫均確認嘴部會移動，兩個靜態姿勢亦維持正確定位。
- 另擷取七個動畫中段的口部前／側近景，以及最新根倍率 5 主場景視角，使用青色點標出口、黃色箭頭標局部 -Z；這些偵錯幾何只存在於 Temp 預覽腳本，不包含在交付場景。

可在完成匯入的獨立專案副本重跑：

```powershell
& "<Godot 執行檔路徑>" --headless --path "<獨立專案副本>" --script "res://scenes/red_dragon/verify_dragon_animations.gd"
```

請確認輸出有 `RESULT checks=180 failures=0`，不要只憑 Godot 程序退出碼判斷腳本是否成功載入。測試環境的憑證／使用者設定存取警告未阻止動畫載入或 GPU 畫面擷取。

## ART-09：遊戲換層對齊診斷紀錄（修正已撤回）

2026-10-03，使用者表示已自行解決並撤回此修正；未套用動畫修正，以下資料僅供參考。原問題範圍為 `scenes/game/game.tscn` 按 1／2／3 換層後可見模型未對齊目標。以下是磁碟上原始遊戲場景的量測；未修改動畫控制器、模型來源、遊戲包裝或主場景構圖。

- 當前遊戲使用 `Game/Dragon/Model` 的紅龍接口；包裝倍率為 1、基礎動畫為 `idle`。這與展示主場景的倍率 5／`fly` 不同。
- 已以專案的 Input Map 注入真正的 `InputEventKey`，經 `KeyboardInput._unhandled_input()`、`Dragon.set_target_lane()`，以固定 1/60 秒推進到完全到位。六次換層（1、2、3、1、3、2）中，`Dragon.position.y` 分別到達 -3、0、3，`current_lane` 與目標一致。`KEYBOARD_ORIGIN failures=0` 只證明輸入與角色原點到位，不表示可見模型已滿足使用者的對齊要求。
- 在相同 `idle` 第 2 秒姿勢下，GPU 三層對照使用實際遊戲攝影機及額外的側面正交診斷鏡頭。各層嘴部相對 `(0, lane_y, 0)` 為 `(0.147513, 0.249276, 2.302880)`；骨骼 `root` 相對位置為 `(0, 0.005511, 0.554037)`。固定姿勢下三層偏差相同。
- 嘴部與食材／鍋子所在 Z=0 平面有深度差。在遊戲透視攝影機下，最低層嘴部可投影在層水平線下方，最高層則在上方，即使角色原點恰好位於該層。世界座標的 Y 到位不能取代畫面對齊驗收。
- 未 ready 的匯入模型共 111 根骨骼，其預設 pose 均等於 rest。未播放時，實際蒙皮網格的 Z 範圍為 `[-2.471678, 2.471678]`；既有 `Model.position.z=1.488613` 已使這個範圍置中。直接將該位移歸零會破壞目前置中。
- `idle` 第一幀的實際蒙皮網格中心平均值為 `(0.042821, 0.585733, 1.048778)`，未播放時為 `(0, 0.530603, 1.001987)`；包圍盒及嘴部會隨姿勢改變。網格頂點平均值不是新定義的玩法定位點。
- 七個動畫各 201 個時間點、根倍率 1／5 的節點變換量測、120 次含 0.2 秒混合的切換、開局／換層／重開，都未觀察到場景節點變換被動畫改寫或累積漂移。回到相同 `idle` 姿勢後，網格包圍盒與中心平均值完全一致。這些結果不排除可見模型與目標的定位定義不一致。

診斷腳本、JSON、日誌與對照圖片保留在 Windows Temp 的 `fgj_dragon_contract_c2336adf048b44bcb626e82d7817f0d9` 獨立專案，未放入交付場景。主要腳本為 `origin_baseline.gd`、`origin_detail.gd`、`origin_keyboard.gd`、`origin_lanes_preview.gd`，對照圖為 `origin_lanes_contact_sheet.png`。上述結果使用 Godot 4.7.2；GPU 對照使用 Compatibility／OpenGL，原專案設定不變。

撤回前尚未確認對齊依據或是否存在未儲存的編輯器實例設定，未宣稱找到根因，也未刪除 `fly` 起伏或 `fall` 原始下降。此任務不再等待對齊基準、不新增回歸或套用定位方案；既有嘴部掛點與動畫 API 契約保留。

## 限制與缺件

- 原始 `atk` 在模型比例 0.05 下，根骨骼 Z 軸位移範圍約 10.10 個 Godot 單位；原地模式消除此水平位移，但保留約 1.73 單位的 Y 軸起伏與其他骨骼動作。
- `fall` 保留原始動畫，其 Y 軸位移範圍約 4.93 單位，首尾下降約 4.43 單位，可能穿越 prototype 樓層。它未處理碰撞、降落高度、根節點位移或遊戲失敗判定，使用前需由玩法／美術整合決定時機。
- `fly` 保留原始懸浮起伏（根骨骼 Y 軸範圍約 0.52 單位）；根節點位置與動畫中的視覺高度不完全相同。
- 上述動畫位移以子場景根倍率 1 為基準；實例根倍率會再乘上世界位移。例如主場景倍率 5，原始 `fall` 的 Y 軸位移範圍約為 24.66 個 Godot 單位，使用前仍需另外處理玩法與場景界限。
- 七個動畫中沒有明確命名的吸取或噴火動作。`atk`、`roar` 的玩法對應尚未確認，不提供假定的吸取／噴火別名。
- 火焰粒子與吸取特效已由技術美術與特效交付，透過本文件的嘴部掛點定位；播放接口與驗證紀錄見 [紅龍特效接口](dragon_vfx_api.md)。特效模組由技術美術與特效維護。
- 食材進鍋表現、動作作用時刻與音效尚未確認；既有動畫與吸取／噴火的對應仍由總監另行定案。
- 已交付嘴部 Marker3D 與定位接口，尚未將 `atk`／`roar` 映射為吸取／噴火，也沒有新增玩法或特效觸發訊號。
