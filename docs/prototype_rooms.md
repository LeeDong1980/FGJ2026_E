# Prototype 房間與樓層接口

本文件記錄場景美術交付的第一版配置。三種龍蛋與幼龍素材已到位並配置。巢穴及稻草／軟墊仍待使用者提供；NestAnchor 定位點不代表巢穴已完成。美術總監負責最終畫面驗證與驗收。

## 場景位置

| 場景 | 用途 |
|---|---|
| `res://scenes/rooms/hero_challenge_room.tscn` | 左側勇者挑戰房：石牆、柱子、煉金桌、書瓶、木箱及火把；隊伍行進區保持開放 |
| `res://scenes/rooms/dragon_nursery_room.tscn` | 右側幼龍哺育房：石造外殼、照護用品、獨立玩法鍋子、幼龍及蛋組；巢穴與鋪墊待補 |
| `res://scenes/rooms/room_ceiling.tscn` | 8 × 8 通用封頂，石板厚 0.3，石地板模型翻轉作底面 |
| `res://scenes/rooms/baby_dragon.tscn` | 原材質的藍色幼龍，安定靜態站姿，展示高 1.15 |
| `res://scenes/rooms/dragon_egg.tscn` | 保留原材質的棕金龍蛋，展示高 0.9 |
| `res://scenes/rooms/dragon_egg_lowpoly.tscn` | 保留原材質的黑紅鱗片龍蛋，展示高 0.9 |
| `res://scenes/rooms/stylized_dragon_egg.tscn` | 保留原材質的綠色龍蛋，展示高 0.9 |
| `res://scenes/rooms/prototype_floor.tscn` | 包含左右房間及中央 `DragonAnchor` 的可重用樓層 |
| `res://scenes/main/main.tscn` | 三層靜態試排、中央一隻紅龍與合成師提供的展示子場景 |

原有 dungeon_room、dragon_platform_showcase、platform_layout 場景保留。完整關卡生成、麥克風控制、食材生成及鍋子規則由程式接入。

## 尺寸與構圖

- 房間原點：地板上表面中心；Y 向上，+Z 為面向攝影機的開放前側。
- 每房平面 8 × 8、室內高 4；地板基座厚 0.25，範圍 Y = −0.25～0。石牆局部厚度約 0.194。
- 樓層原點：中央升降通道的地板高度。左右房間中心 X = −8／+8，房間範圍分別 X = −12～−4／4～12。
- 中央通道淨寬 8，在互動線 Z = 1.1 沒有跨越通道的地板或牆體。
- 房間 +Z 整面開放。靠中央的側牆只覆蓋後半部，Z = 0～4 留出大開口。左房外側也留出前半部入口，讓隊伍可由畫面左方進入。
- `LowFloor`／`MiddleFloor`／`HighFloor` 的 Y = 0／5／10，`floor_index` = 0／1／2。天花板上表面比下一層地板底面低 0.45。
- 使用者確認後的主龍展示根節點位於 `(0, 6.4, -16.018951)`，`base_animation = &"fly"`。沿用模型既有正面方向，朝 +Z 攝影機展示；玩法朝左的方向切換由程式後續接入。
- 主場景紅龍實例 `scale = Vector3(5, 5, 5)`，採用使用者已確認的新構圖。紅龍子場景來源尺寸及 DragonAnchor 保持原值。展示變換與玩法升降定位點分開，不再要求紅龍展示根節點等於中層 DragonAnchor；切換到玩法布局時由程式處理兩者的對應。嘴部世界變換包含根倍率 5 及模型倍率 0.05，特效透過嘴部接口取得實際位置，不另外乘以展示倍率。
- 共用 Camera3D、WorldEnvironment 與主燈光由 `PrototypePresentation` 管理；房間各只有兩盞低能量、無陰影的局部火把光。

## Marker3D 定位點

下表座標為樓層局部座標；使用 `marker.global_position` 可取得堆疊後的世界座標。所有房間定位點位於各自場景根節點，並設為場景唯一名稱。

| 定位點 | 樓層局部位置 | 所屬與用途 |
|---|---|---|
| `DragonAnchor` | `(0, 1.4, 1.1)` | 樓層根節點，紅龍根節點升降位置 |
| `QueueSpawnAnchor` | `(-12, 0, 1.1)` | 左房入口，隊伍生成方向為 +X |
| `QueueFrontAnchor` | `(-4.6, 0, 1.1)` | 左房靠龍的隊伍最前端 |
| `PotAnchor` | `(5.65, 0, 1.1)` | 右房獨立 `Pot_01` 鍋子底部中心 |
| `NestAnchor` | `(9, 0, 0.1)` | 右房預留巢穴中心 |
| `HatchlingAnchor` | `(8.7, 0, 0.3)` | 右房幼龍地面定位點，已有 BabyDragon 實例 |
| `EggAnchor` | `(10.2, 0, 2.4)` | 右房前側蛋組中心，已有三種龍蛋實例 |
| `DragonSideAnchor` | 左房 `(-4, 0, 1.1)`；右房 `(4, 0, 1.1)` | 通道側開口位置 |
| `CeilingAnchor` | 左房 `(-8, 4, 0)`；右房 `(8, 4, 0)` | 通用天花板底面中心 |

`NestAnchor` 目前僅為空的 Marker3D，未放置幾何巢穴。`HatchlingAnchor` 下已有原素材幼龍，`EggAnchor` 下已有三種龍蛋；待巢穴與鋪墊到位後須量測外框並安排幼龍落座高度，避免與蛋組、鍋子相交。

## 程式與 Inspector 使用方式

`prototype_floor.gd` 提供：

- `get_room(&"left")`／`get_room(&"right") -> Node3D`；其他名稱回傳 null。
- `get_anchor(name: StringName) -> Marker3D`：支援 Dragon、QueueSpawn、QueueFront、Pot、Nest、Hatchling、Egg 的定位點；其他名稱回傳 null。
- `set_ceilings_visible(enabled: bool)`：切換兩房天花板的可見性與碰撞。
- Inspector：`floor_index` 供程式識別；`ceilings_visible` 預設 false。
- `ROOM_SIZE = Vector3(8, 4, 8)`、`CHANNEL_WIDTH = 8`、`FLOOR_SPACING = 5` 為製作基準。

房間的 `room_module.gd` 提供 `get_anchor(name)`；可取得房間根節點下的定位點（包含 CeilingAnchor、DragonSideAnchor）。房間 Inspector 的 `ceiling_visible` 預設 false，可逐房設定。

```gdscript
const FLOOR_SCENE: PackedScene = preload("res://scenes/rooms/prototype_floor.tscn")

func add_floor(index: int, parent: Node3D) -> Node3D:
	var floor_node: Node3D = FLOOR_SCENE.instantiate()
	floor_node.set("floor_index", index)
	floor_node.position.y = index * 5.0
	parent.add_child(floor_node)
	return floor_node
```

玩法升降可使用 `floor_node.get_anchor(&"DragonAnchor").global_position` 作為定位基準，但不要直接覆寫已確認的展示布局；目前主龍使用獨立展示變換。新增樓層後，亦需呼叫展示子場景的 `configure_for_layers()` 調整攝影機，參數見合成師的 `docs/prototype_camera.md`。

天花板切換會一併切換其 CollisionShape3D，碰撞變更採 deferred，下一個更新週期生效。直接勾選 Node3D 的 Visible 只會改變視覺；請使用上述 Inspector 屬性或方法。主場景預設六個天花板皆隱藏，碰撞亦停用，避免影響內部觀看。

## 碰撞與材質

每房地板、石牆、柱子、大型桌椅、木箱和玩法鍋子使用 StaticBody3D + BoxShape3D。牆面與家具碰撞依量測外框配置；柱子與鍋子的碰撞為保守盒形。瓶罐、書、布旗、小岩石等裝飾不阻擋隊伍。

共用 dungeon 圖集及頂點色材質，材質覆寫位於模型實例下，不修改來源 FBX 或其匯入設定。基座、簷帶與天花板本體使用粗糙石色；火把火焰採獨立發光材質。

## FBX 尺寸量測

使用 Godot 4.7.2，在獨立暫存專案讀取既有匯入模型，實例進入 SceneTree 後合併各 MeshInstance3D 的變換 AABB。以下為未套用房間實例縮放的 X × Y × Z；不同模型匯入單位不同，不能統一乘以 100。

| 模型 | 原始實例 AABB 尺寸 |
|---|---|
| `Book_09.fbx` | 0.00266946 × 0.000684645 × 0.0036018 |
| `Bottle_05.fbx` | 0.00155817 × 0.00252837 × 0.00155817 |
| `Box_02.fbx` | 0.00916302 × 0.00916626 × 0.00913222 |
| `Candle_01.fbx` | 0.000992609 × 0.00166523 × 0.00114617 |
| `Chair_05.fbx` | 0.483362 × 0.879036 × 0.441463 |
| `Column_01.fbx` | 0.00784957 × 0.04 × 0.00784957 |
| `Ground_01.fbx` | 0.04 × 1e-05 × 0.04 |
| `Ground_03.fbx` | 0.02 × 0.00692941 × 0.02 |
| `Jug_02.fbx` | 0.00400972 × 0.00498022 × 0.00400972 |
| `Light_08.fbx` | 0.211619 × 0.648673 × 0.25535 |
| `Mud_04.fbx` | 0.0201767 × 0.00369937 × 0.0209475 |
| `Pot_01.fbx` | 0.0126803 × 0.00835221 × 0.0126803 |
| `Rock_01.fbx` | 0.0132854 × 0.0142196 × 0.012422 |
| `Table_01.fbx` | 0.0202391 × 0.00891011 × 0.012415 |
| `WallDecor_05.fbx` | 0.00815793 × 0.0186816 × 0.00182745 |
| `Wall_27.fbx` | 4 × 4 × 0.193972 |
| `Wood_02.fbx` | 0.00335386 × 0.000436453 × 0.0218013 |

每件實例採等比例縮放，以目標寬度或高度換算倍率，並校正模型外框的底部與 XZ 中心。地板單片寬 4、柱高 4、後牆寬 4；鍋寬 1.6，挑戰房桌寬 2.4、哺育房桌寬 2.2。

## 驗證紀錄

- 獨立 Godot 4.7.2 headless 專案完成四個子場景載入、腳本解析及素材引用驗證。
- 三層主場景整合驗證通過：六個房間、索引 0／1／2、Y = 0／5／10、唯一主龍保留已確認的 `(0, 6.4, -16.018951)`、展示倍率 5、啟動播放 fly，展示子場景成功實例化。
- 每層七種主要定位點皆可取得。Physics ray 檢查入口至隊伍最前端及中央通道，在 Y = 地板高 + 0.75、Z = 1.1 的行進線沒有阻擋碰撞。
- 六個天花板預設隱藏且碰撞停用；切換開啟後可見且碰撞啟用，關閉可恢復。
- 模型外框檢查未發現超大實例。檢查使用暫存專案，未改共享匯入設定。
- 暫存執行環境有系統憑證存放區讀取訊息；編輯器初始化亦有使用者設定目錄權限訊息，實際載入與接口斷言均通過。
- 最後一輪獨立 headless 整合使用 Jolt Physics，三層定位、主龍倍率與 fly、隊伍及中央通道碰撞、天花板切換全部通過。
- 美術總監已回報 1600 × 900 Forward Plus 首輪渲染確認：三層、開放前牆及鍋子可讀；倍率 2 為當時首版試排的歷史值，後續已採用使用者確認的倍率 5 與 Z = −16.018951。最終共享專案渲染截圖與完整美術驗收仍由總監統整。

## 龍蛋匯入與配置交付

2026-10-03 使用 Godot 4.7.2，在獨立暫存專案匯入 `Models/dragonEggs/` 三個 GLB，保留來源檔名、資料夾與 GLB 位元組。來源只新增 Godot 生成的三個 `.glb.import`。採 `gltf/embedded_image_handling=3`（Embed as Uncompressed），將原有貼圖內嵌於匯入場景，避免在來源資料夾抽出額外影像；材質未覆寫。其他匯入參數保持 Godot 預設：root_scale=1、apply_root_scale=true、generate_lods=true、create_shadow_meshes=true、materials/extract=0。選項說明：[Godot GLTFState](https://docs.godotengine.org/en/4.7/classes/class_gltfstate.html)。

| 來源模型 | 實際匯入 AABB（X × Y × Z） | 子場景等比倍率 | 模型位置校正 | 材質檢查 |
|---|---|---|---|---|
| dragon_egg.glb | 0.644445 × 0.912524 × 0.644445 | 0.986275703 | 約 (0, 0, 0) | 原有 1024 × 1024 色彩貼圖，含法線材質 |
| dragon_egg_lowpoly.glb | 2 × 2.321746 × 2 | 0.387639284 | (0, 0.45, 0) | 原有 1024 × 1024 色彩貼圖，含法線材質 |
| stylized_dragon_egg.glb | 17.889557 × 28.032133 × 17.613644 | 0.032106012 | (3.057123228, 0.000208496, 0.001027716) | 原有 1024 × 1024 色彩貼圖 |

每個子場景根節點均為地面底部中心，模型展示高 0.9，不新增碰撞。三種均具蛋形與龍鱗表現，保留棕金、黑紅、綠色差異，組成小型孵育陳設；原材質與造型可在各子場景獨立重用。綠色模型來源內含底座，原樣保留。

三個實例掛於哺育房 `EggAnchor` 下，相對位置依序為 `(-0.5, 0, -0.25)`、`(0.5, 0, -0.1)`、`(0, 0, 0.65)`。房間局部中心為 `(1.7, 0, 2.15)`、`(2.7, 0, 2.3)`、`(2.2, 0, 3.05)`；移動 FeedingJug 至 `(3, 0, 0.7)` 避免與蛋組相交。NestAnchor、HatchlingAnchor 與 PotAnchor 不變。

三層共九顆蛋已通過地面對齊、0.9 高度、AABB 不互相重疊與主鏡頭投影範圍檢查，蛋中心距預留 NestAnchor 均超過 1.9。獨立 Forward Plus／D3D12、1600 × 900 主鏡頭截圖確認蛋組與鍋子分開可見，不阻擋食材隊伍或中央通道。檢查圖：`C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/main_eggs_review.png`。

## 主場景特效接入

主場景新增根節點下的 `Effects`，實例化技術美術的 `res://scenes/vfx/dragon_effects.tscn`，`dragon_path = NodePath("../RedDragon")`。Effects 與 RedDragon 皆設為主場景唯一名稱，可透過 `%Effects`／`%RedDragon` 取得。Effects 位於紅龍節點之後，ready 時取得已就緒的嘴部接口，無需另加主場景腳本。

特效預設停止，不自動循環、不綁定 roar／atk，不新增輸入按鍵或玩法操作。F5 仍展示原有主場景；獨立特效展示由技美的 `scenes/vfx/vfx_preview.tscn` 提供，操作與完整事件見 `docs/dragon_vfx_api.md`。

```gdscript
@onready var effects: DragonEffects = %Effects
@onready var dragon: RedDragon = %RedDragon

func show_suction(target: Node3D) -> bool:
	return effects.play_suction(target.global_position, 0.6)

func show_fire(target: Node3D) -> bool:
	return effects.play_fire(target.global_position, 0.6)
```

ready 後，控制器已綁唯一主龍；可用 `bind_dragon(dragon) -> bool` 重新綁定。`set_target_global_position(position)` 更新目標，`stop_effects()` 停止並清場。`get_active_effect()` 預設為空字串，播放後為 suction／fire。目標均使用世界座標；播放回傳 false 時讀取 `last_error`。

控制器取得 `RedDragon.get_mouth_anchor() -> Marker3D`，跟隨骨架與根變換，粒子以世界單位處理。`effect_range` 預設 6，超出範圍的目標只控制方向，視覺終點會截至 6 單位；目前展示龍與左房實際距離可能超過此範圍，程式需依視覺需求設定，不能將粒子終點當成玩法命中或吸取完成。

獨立暫存專案驗證通過：新版 shader 解析、Effects 綁定唯一主龍、取得同一 MouthAnchor、預設所有粒子停止且隱藏、吸取／噴火播放、目標更新、移動龍後更新嘴部來源座標、停止清場與 fly 動畫保持播放。Jolt 回歸通過三層索引、主要定位點、隊伍／通道碰撞及天花板可見性與碰撞切換。未執行共享來源專案匯入。最終特效外觀與動畫觸發對應由總監統整。

## 幼龍匯入與配置交付

2026-10-03 在獨立暫存專案，以 Godot 4.7.2 驗證 `Models/dragonBabies/baby_dragon.glb` 及既有三張貼圖，沿用現有 `.import`（root_scale=1、apply_root_scale=true、gltf/embedded_image_handling=1）。未修改來源 GLB、PNG、`.import`，亦未改舊 dragon／dungeon 匯入設定。

原材質 `standardSurface1` 成功連結：`baby_dragon_0.png` 為色彩貼圖、`baby_dragon_1.png` 為金屬／粗糙度貼圖、`baby_dragon_2.png` 為法線貼圖，三張皆為 1024 × 1024，法線功能已啟用。原材質顯示藍色皮膚、白色腹部及黃色耳翼，不需要材質覆寫。

- 完整場景變換後 AABB：最小點 `(-0.037484091, 0.000075886, -0.112346329)`，尺寸 `(0.074968182, 0.132875502, 0.175864697)`。
- 子場景 `baby_dragon.tscn` 根節點為 `BabyDragon`，原點為底部的 XZ 外框中心；Model 等比倍率 `8.654718001`，位置校正 `(0, -0.000656770, 0.211296117)`。
- 最終外框約 `0.648829 × 1.15 × 1.522059`。高度為蛋的 0.9 高約 1.28 倍，保留尾巴完整造型並讓臉部在主鏡頭可讀。
- GLB 及 Godot 匯入結果都沒有動畫；無 AnimationPlayer，採原有安定站姿，沒有捏造 idle 動畫或新增玩法控制腳本。
- 每層哺育房在 `HatchlingAnchor/BabyDragon` 實例化一隻，保持定位點房間局部 `(0.7, 0, 0.3)`，面向 +Z 攝影機，三層共三隻。
- `NestAnchor` 維持空定位點，等待巢穴素材；幼龍置於既有育幼定位區，未新增巢或稻草替代物。未新增幼龍碰撞。

Jolt headless 整合檢查通過：三隻幼龍皆高 1.15、底部對齊各層地板，不與鍋子／龍蛋 AABB 相交，沒有進入中央通道；主攝影機投影在畫面內，NestAnchor 無子節點。主龍保持使用者確認的 scale5 與 `(0, 6.4, -16.018951)`，Effects 保持停止且粒子隱藏。

Forward Plus／D3D12、1600 × 900 真實主鏡頭確認：幼龍、蛋組與鍋子分開可讀，三層配置皆可見，未調整主鏡頭或主龍構圖。檢查圖：`C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/main_hatchlings_review.png`。獨立比例圖：`C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/baby_dragon_review.png`。

素材 GLB 內含的作者／授權中繼資料：Baby dragon，Kanna-Nakajima，CC-BY-4.0；來源連結為 [Sketchfab Baby dragon](https://sketchfab.com/3d-models/baby-dragon-8ebffa958b6247d09b0c40f33f03bbae)。此處記錄檔案內資訊，供總監統整素材署名。

## 特效加寬後的主鏡頭只讀檢視

2026-10-03 恢復工作後，以 `master def2614` 的房間／主場景及技美正在交付的加寬版特效做獨立副本檢視。使用者已選擇「更誇張、覆蓋更大的範圍」，本輪保留 `suction_width=4.0`、`fire_width=3.0`，沒有縮小預設，也沒有修改共享 Effects、主龍、攝影機或 GM 場景。寬度表示最寬截面的完整直徑，合法上下界及設定接口由 `docs/dragon_vfx_api.md` 說明。

### 取樣方法與證據

- Godot 4.7.2、Forward Plus／D3D12、RTX 4070 Laptop GPU、1600 × 900。獨立載入 `scenes/main/main.tscn`，保持主龍倍率 5、位置 `(0, 6.4, -16.018951)` 及目前主攝影機。
- 凍結一次 fly 姿勢，嘴部約 `(-0.4154, 11.2851, -4.8817)`；依序指向低／中／高層 `QueueFrontAnchor + Vector3.UP`。保持目前主龍位置，不虛構主場景已接換層或朝左動畫。
- 每層吸取與噴火各比較三種設定：寬度預設 4／3、射程 6；相同寬度、射程上限 20；完整寬度 8／8、射程上限 20。共 18 張效果圖及 1 張待機圖，全部 PNG 保存回傳 0，程序正常退出。
- 射程 20 是允許連到各層真實目標的上限，不會把距離較近的目標向外推到 20。此取樣嘴部到低／中／高目標距離約 12.612／9.012／7.306。
- 載入／GPU 日誌沒有 script／shader 解析錯誤。獨立副本仍有使用者快取／憑證存放區權限訊息及 ground UID 快取未註冊警告，後者回退既有文字路徑正常；沒有更動共享來源資源。

### 可讀性與建議

| 設定 | 實際觀察 | 建議 |
|---|---|---|
| 吸取 4、噴火 3 | 藍色氣流幅寬與暖色火焰錐形明顯；三層右側鍋子、藍色幼龍及三種蛋均可各自辨識。效果主要位於中央至左房，沒有覆蓋右側育幼陳設 | 保留指定預設供使用者驗收；沒有理由由場景美術縮回舊窄版 |
| 射程預設 6 | 本次三層目標距離均大於 6，效果會在中央通道或左房入口前截短，尤其低層看起來與目標分離 | 若要求效果連到隊首，呼叫端須另設射程；本次上限 20 可連到三層，14 也足夠本姿勢，但不能以此保證所有動畫姿勢 |
| 寬度 8、射程 20 | 吸取散布更大，部分氣流覆過左房內側與上下邊界；火焰的亮粒子及連續核心遮住左房內側木箱／牆面，低層斜向效果同時覆過中層邊界。右側鍋子／幼龍／蛋仍可辨識 | 8 保留為可調最大值；須告知大範圍表現會降低左房陳設及作用樓層的辨識度，不代表技術接口失敗 |
| 固定展示龍指向低／中層 | 嘴部在高處，效果斜向穿過中間高度；加寬會放大跨層視覺，但這也來自既有展示龍與目標的對位 | 後續由總監與玩法／動畫負責人決定換層、口部對位或作用層提示，本輪不動已確認構圖 |

此檢視只涵蓋目前主鏡頭的一次固定姿勢與左側隊首目標，不是所有 fly 姿勢、轉頭、GM-16 遊戲場景或向鍋子吐食材的驗收。人物／六種食材模型仍未提供，不能宣稱已確認角色臉部、食材輪廓或 UI 進度的遮擋。巢穴與稻草／軟墊仍缺，沒有擅自新增替代物。

### 檢視輸出

- [吸取三層比較索引](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/width_suction_three_floor_index.png)。
- [噴火三層比較索引](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/width_fire_three_floor_index.png)。
- [取樣數值及右房物件投影外框](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/width_readability_metadata.json)。同目錄保留 `width_<lowfloor/middlefloor/highfloor>_<suction/fire>_<default/range20/maxwidth_range20>.png` 及 `width_scene_idle.png` 原圖。
- 暫存專案 `C:/Users/LeeDong/AppData/Local/Temp/fgj_main_effects_qa`，包含 `capture_width_readability.gd`、`width_review_sheets.py`、`width_source_snapshot.json` 與 `width_capture*.log`。截圖取樣後技美修改的 legacy radius 序列化與獨立預覽操作沒有改變此次主場景效果的寬度／渲染計算；若後續修改幅寬、shader 或主要場景變換，須重新取樣。

本 session 僅更新自己的兩份交付文件，未 commit／push；驗證程序已退出，使用者 Godot 保留。
