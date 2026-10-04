# Prototype 房間與樓層接口

本文件記錄場景美術交付的第一版配置。三種龍蛋與幼龍素材已到位並配置。巢穴及稻草／軟墊仍待使用者提供；NestAnchor 定位點不代表巢穴已完成。美術總監負責最終畫面驗證與驗收。

## 場景位置

| 場景 | 用途 |
|---|---|
| `res://scenes/rooms/hero_challenge_room.tscn` | 左側勇者挑戰房：石牆、柱子、煉金桌、書瓶、木箱及火把；隊伍行進區保持開放 |
| `res://scenes/rooms/dragon_nursery_room.tscn` | 右側幼龍哺育房：石造外殼、照護用品、獨立玩法鍋子、幼龍及蛋組；巢穴與鋪墊待補 |
| `res://scenes/rooms/room_ceiling.tscn` | 8 × 8 通用封頂，獨立使用石板厚 0.3；生成樓層時依上下層空帶調厚，石地板模型翻轉作底面 |
| `res://scenes/rooms/baby_dragon.tscn` | 原材質的藍色幼龍，安定靜態站姿，展示高 1.15 |
| `res://scenes/rooms/dragon_egg.tscn` | 保留原材質的棕金龍蛋，展示高 0.9 |
| `res://scenes/rooms/dragon_egg_lowpoly.tscn` | 保留原材質的黑紅鱗片龍蛋，展示高 0.9 |
| `res://scenes/rooms/stylized_dragon_egg.tscn` | 保留原材質的綠色龍蛋，展示高 0.9 |
| `res://scenes/rooms/prototype_floor.tscn` | 包含左右房間及中央 `DragonAnchor` 的可重用樓層 |
| `res://scenes/main/art_prev.tscn`（原 main.tscn） | 三層靜態試排、中央一隻紅龍與合成師提供的展示子場景 |

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
- `fit_ceilings_to_floor(upper_floor: Node3D)`：以左右上層地基的實際底面計算層間封板厚度；傳入 null 時移除層間封頂設定。`LaneLayout` 在生成全部樓層後自動呼叫，然後另配置外側封板。
- `configure_boundary_caps(top_enabled: bool, bottom_enabled: bool)`：標記最高層／最低層；最高層啟用既有天花板，最低層在兩房地基下實例化 `BottomCeiling`。單層時同時封上、封下。runtime 依視錐上下邊界調厚，並把水平延伸範圍納入計算，補滿畫面上下緣。
- `boundary_cap_min_height`：鏡頭尚未可用時與外側封板的最小厚度，預設 0.3；`edge_overscan` 同時作為封板超出畫框的餘量。
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

天花板切換會一併切換其 CollisionShape3D，碰撞變更採 deferred，下一個更新週期生效。直接勾選 Node3D 的 Visible 只會改變視覺；請使用上述 Inspector 屬性或方法。靜態美術展示 `art_prev.tscn` 預設六個天花板皆隱藏；遊戲 `LaneLayout` 生成的樓層會啟用上下層間的天花板，以及最高層上方與最低層下方的外側封板。

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

## 2026-10-04 ART-12／15／17 可逆草案交付

本節是總監授權先做的可檢視草案，**60% 角色比例與接邊方案仍待使用者正式驗收**。此前章節保留首版歷史結果；目前幼龍預設已改為 2.4，樓層在執行時依目前攝影機向外延伸。沒有修改主龍、攝影機、GM 場景、來源模型或 kitkay 配置，不 commit／push。ART-09 既有換層修正維持原狀。

### ART-15 房間向外接邊

修改 `room_module.gd`、`room_ceiling.gd`、`prototype_floor.gd` 及挑戰房的 `outward_direction=-1`。左房向 −X、右房向 +X 增接，原來的 8 × 4 × 8 是固定核心房間尺寸；房間原點、世界內側 X=−4／+4、中央通道、Props 及 Queue／Pot／Nest／Hatchling／Egg／Dragon 定位點均固定。

- `Room.set_outer_extension(distance)`：距離是房間局部單位，有限值限制在 0～40；0 恢復核心外殼。`outward_direction` 指定左／右，`outer_extension` 可在 Inspector 設定。
- 地基及背牆簷帶寬度重算為 `8 + outer_extension`，局部 X 中心重算為 `outward_direction * outer_extension / 2`；不沿用手動加長場景的 X = ±6 中心。地基以 `Foundation/Mesh` 與相同尺寸碰撞覆蓋全區域，其他直接掛在 Foundation 下的 MeshInstance3D 補片會隱藏以免重疊。
- 同步增接 4 單位地板及背牆片，末片僅縮窄建築片的 X 尺寸；延長 foundation、背簷及其碰撞。外牆、外簷、外側前後柱移到新外緣，內側後牆不動，+Z 視線開口保留，沒有拉伸核心道具。左側外牆仍保留既有前半段隊伍入口。
- `RoomCeiling.set_outer_extension(distance, direction)`：屋頂板、碰撞及下表面地板片同步延伸；仍由原 `set_enabled` 一起控制可見性與碰撞。各實例的 BoxMesh／BoxShape3D 先複製，修改一層不污染另一層。
- `PrototypeFloor.fit_screen_edges=true`：僅 runtime 生效。尋找祖先內的 `PrototypePresentation`，讀取合成師 `get_visible_horizontal_span(world_y, world_z)`；對地板與牆頂 Y，以及前 Z=4／後 Z=−4，共四組世界座標取樣，再轉回各房間局部 X。
- 左／右各取最外側值，另加 `edge_overscan=0.1`。三層在 1600 × 900 的延伸距離約 5.221／5.169／5.116；外緣為 ±17.221／±17.169／±17.116，各房寬約 13.221／13.169／13.116。矩形模組會在前緣比画面多延伸，避免深度造成邊緣空隙。
- `fit_to_presentation_edges() -> bool`：無效／非有限查詢保持既有幾何；相同數值不重建。不修改 `layout_bounds`、不呼叫 reframe；只監聽 `framing_changed` 並延後更新，避免房間延伸與攝影機取景互相擴大。
- `reset_outer_extensions()`：關閉自動接邊並恢復兩側 8 單位核心。重新設 `fit_screen_edges=true`，再呼叫 `fit_to_presentation_edges()` 即可恢復接邊。單獨 F6 房間沒有 Presentation 時不自動延伸，可直接設 `outer_extension` 預覽。

目前自動接邊適用專案既有 X 水平、Y 樓層、Z 深度的布局；任意旋轉／非等比縮放樓層尚未驗證。合成師的查詢接口仍可回傳世界點，但此整合沒有宣稱支援斜向通道。

### ART-17 幼龍高度與左側食材交接

新增 `baby_dragon.gd` 及 `.uid`，掛到既有 `baby_dragon.tscn`。`display_height` 預設 **2.4**，可調 0.2～3.0，代表包含耳翼的可見模型 AABB 高度；不是骨架高度、Label 高度或角色根倍率。只縮放並校正 Model，BabyDragon 根節點維持原點／scale1，HatchlingAnchor 保持原位置。原貼圖、静態站姿、不帶碰撞的配置維持；沒有代造 idle／走動動畫。

| 草案高度 | 房高占比 | 模型寬 × 高 × 深 | 空間檢查 |
|---|---:|---|---|
| 1.15（原首版） | 28.75% | 0.649 × 1.15 × 1.522 | 無鍋／蛋外框交疊 |
| 2.0 | 50% | 1.128 × 2.0 × 2.647 | 無鍋／蛋外框交疊 |
| 2.4（目前草案） | 60% | 1.354 × 2.4 × 3.176 | 三層底面誤差 <0.000001，無鍋／蛋／Props 外框交疊；原站位即可保留 |
| 2.667 | 2/3 | 1.505 × 2.667 × 3.529 | 與第一顆 DragonEgg 的保守 AABB 交疊；不採為目前預設 |

2.4 對來源 GLB 的 Model 倍率約 18.0620202，位置校正 `(0, −0.0013706507, 0.440965809)`。主鏡頭下低層投影約寬 75.5／高 134.6 像素；三層幼龍臉部、鍋子及三種蛋可分別辨識。參數大於 2.4 時仍應重查尾巴與蛋組，合法參數範圍不代表全部值都已保證適合此站位。

**GM-19／程式 owner 的食材待辦（本 session 未修改）**：現有食材是 CapsuleMesh，高 0.8、寬 0.4、底部在 root Y=0，六種真實角色素材仍缺。若採同一 60% 草案：

1. 僅讓身體 Mesh 等比 scale3，身體中心 Y 從 0.4 改 1.2；最後高 2.4、寬 1.2，腳底仍為 0。IngredientModel root、Label3D 與 BurnBar 不整體 scale3。
2. GameManager `ingredient_spacing` 原 0.6 小於新身寬，應至少 1.2＋間隙，建議首版 1.4；5 人列長（含半徑）約 6.8，可容納在現有 7.4 單位 spawn→front 距離內。保持 QueueSpawn／QueueFront 定位點，不由場景美術改隊列行為。
3. NameLabel 建議移到約 Y=2.6；字型大小與輪廓另行做主鏡頭核對。BurnBar 建議移到身體頂部附近、Z 向前避免嵌入，保留目前獨立寬度與進度計算。
4. `EffectsView.target_height` 原 0.4 對應舊身體中段；新高 2.4 建議改 1.2，與技美噴火密度及食材目標回歸一起驗證。真正角色到位時以各自可見 AABB 做縮放與腳底校正，不固定所有源模型都乘3。

### ART-12 洞穴需求與掛載規格

洞穴模型路徑仍未提供，沒有新造／替換模型、沒有放 kitkay，亦未新增假洞穴。預計採場景根下獨立洞穴背景子場景，與 Floors／RedDragon 平行；不能掛在動畫模型或骨架上繼承 fly 位移。主場景掛載由場景美術負責，game.tscn 掛載須交露柑；層數與層距應讀取樓層資料，不能只適合固定三層。

**請提供／核對的模型尺寸清單**：完整变換後外框寬高深、原點相對地面／洞口中心、洞口淨寬淨高、內部可用深度、正面 +Z 及左右側口位置、側口與三層入口高度、前後封閉面、背面材質／法線、材質與貼圖／授權、是否已有可拆屋頂與碰撞。光照及遠裁切在模型到位後由合成師檢視。

中央核心的世界 X=−4～+4，三層樓板 Y=0／5／10、房間頂 Y=4／9／14。這是通道與側向連接的既定布局，**不是整隻龍可以裝入的洞穴內空尺寸**。主龍 scale5、位置 `(0,6.4,−16.018951)` 的 fly 以 8 個時間點實際骨架烘焙量測，合併外框約寬 **26.789**、高 **21.418**、深 **24.017**，min `(-12.996,0.386,-27.688)`；翼展超過 8 寬通道。這是姿勢取樣，不包含所有動作、未來左右擺頭或 game 移動的全程外框。

因此素材需先選擇「中央開放背景」或「包覆完整龍體的洞穴」；前者要保留 +Z 觀看面及左右入口，不可讓岩壁／碰撞侵入公開定位點、嘴部射線或升降路徑；後者必須另按所有動作及 game 範圍量測內空，不能直接以 8 × 14 × 8 封閉。此選擇尚未定案。

若後壁放在本次尾部後方（例如 Z≈−28.688），目前合成師 camera API 回傳 `outside_clip_depth`。ART-13 需依實際洞穴位置核對／調整 far clip，而非讓場景美術私自改鏡頭或主龍。洞口遮擋、側門、尾部與牆的淨距及動畫餘量須等模型到位後驗證，現在不虛報已完成 ART-12。

### 驗證與檢視位置

- `EXTENDED_ROOMS_RESULT checks=109 failures=0`：三層六房的地板碰撞、舊外牆不阻通行、四組前後／頂部邊界覆蓋、屋頂尺寸與顯示／碰撞切換、anchor／主龍保持、幼龍落地及鍋／蛋間距、重複 fit、無效查詢保留、單層 reset 的資源隔離與執行時高度變更。
- 實際 `LaneLayout` 腳本的獨立 fixture 通過 3→2 層重建、1600 × 900→1280 × 800 resize 後自動接邊，QueueFront 仍為 `(-4.6, layerY, 1.1)`。不是整個 game／UI／語音流程驗收；總監另已 GPU 檢视 main／game，最終畫面交合成師確認。
- Forward Plus／D3D12、RTX 4070、1600 × 900：[延伸房間＋幼龍 2.4 草案](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/extended_rooms_baby_2_4_draft.png)。Godot 4.7.2，Jolt；截圖保存結果0、程序退出0，無 script／shader 解析錯誤。副本的使用者資料／憑證權限及 UID 快取回退訊息不影響結果，沒有重匯入共享專案。
- [幼龍四種高度量測](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/role_ratio_measurements.json)、[延伸尺寸與檢查數](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/extended_room_measurements.json)、[鏡頭邊界與主龍 fly 八姿勢外框](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/layout_requirements.json)。
- 暫存 `C:/Users/LeeDong/AppData/Local/Temp/fgj_main_effects_qa` 保存 `capture_role_ratios.gd`、`measure_layout_requirements.gd`、`verify_extended_rooms.gd`、`verify_generated_rooms.gd` 及 `role_ratio*`／`layout_requirements*`／`extended_rooms*`／`generated_rooms*` 日誌。所有本輪驗證程序已退出。

## 2026-10-04 ART-23 生成樓層補縫與 Z-fighting

- ART-23 首版：`LaneLayout` 生成全部樓層後，各層透過 `fit_ceilings_to_floor(upper_floor)` 配置既有左右 `room_ceiling`，不新增跨越中央通道的封板。當時最高層未封頂；目前已由 ART-25 加上外側上下封板。
- 封板從 CeilingAnchor（室內 Y = 4）接到上層 Foundation 的實際底面。預設層距 5、地基厚 0.25 時，封板厚 0.75；`RoomCeiling.set_fill_height(height)` 同步修改獨立 BoxMesh 與 BoxShape3D。沒有正空帶時停用該房天花板，非正／非有限厚度不修改幾何。
- 既有左右接邊接口維持：`set_outer_extension` 更新寬度時保留封板厚度，下表面石材與碰撞一併延伸。
- `RoomCeiling.underside_offset` 預設 0.01，將底面裝飾移到板底下；`Room.floor_surface_offset` 預設 0.01，將地板石材移到地基上表面上方。兩者可在 Inspector 調整 0.001～0.05，避免共面。
- `room_module.gd` 在建構程式延伸時停用舊 `FloorExt*`／`BackWallExt*` 的可見性與碰撞，以免與新段重複。沒有修改房間／樓層 `.tscn`、來源模型、Gameplay Marker 或攝影機。
- 獨立暫存專案 `C:/Users/LeeDong/AppData/Local/Temp/fgj-ceiling-validation-20261004` 的 `verify_ceiling.gd` 以 Godot 4.7.2／Jolt 完成 2813 項檢查，0 失敗：1／3／10 層、層距 4.25／4.3／5／6.5、左右末段延伸、碰撞／可見性、上層接縫、中央通道、底面分離與共用資源隔離。
- Forward Plus／D3D12 實際渲染檢查通過，圖存於 `C:/Users/LeeDong/.codex/visualizations/2026/10/04/01a105be-61de-7091-a0d7-fa2fc5732b55/floor_ceiling_preview.png`。Windows 憑證、Wacom 設定及沙箱外 shader cache 的訊息不影響本輪幾何與渲染驗證。該階段驗證時尚未提交；後續授權提交狀態見本文最後一節。

## 2026-10-04 ART-24 game.tscn 洞穴背景後移

- 修改 `scenes/game/game.tscn` 的場景實例設定：`GameUI/CaveBackdrop.depth_ratio = 0.95`、`PrototypePresentation.far_padding = 40.0`。背景由腳本逐幀定位，單改 transform 會被覆寫；上述設定讓背景在較遠的位置持續蓋滿畫面，並防止紅龍尾部被原遠裁切面切除。
- 未改紅龍根變換、共用背景 shader／腳本或其他遊戲場景。原有龍 Z = -15 與場景 UID 的使用者修改保留。
- 獨立暫存專案使用來源場景的 LaneLayout、Dragon、PrototypePresentation 及 CaveBackdrop 設定載入、實例化並渲染；僅排除 GameManager、UI 與輸入控制。Godot 4.7.2／Forward Plus／D3D12 檢查三層、左中右擺頭與九個 fly 動畫取樣，共 81 姿勢，0 失敗。以當前骨架姿勢烘焙的模型外框量測，背景比龍最後緣至少遠 8.29，背景与龍都在 far 內，畫面完整覆蓋。
- 1280×720 基準背景世界位置約 `(0, 3.905, -35.657)`，camera far 約 182.996；位置隨鏡頭取景自動計算，不寫死世界 Z。驗證腳本為暫存專案 `preview_backdrop.gd`；預覽圖 `C:/Users/LeeDong/.codex/visualizations/2026/10/04/01a105be-61de-7091-a0d7-fa2fc5732b55/game_backdrop_preview.png`。該階段驗證時尚未提交；後續授權提交狀態見本文最後一節。

## 2026-10-04 ART-25 畫面上下邊緣封板

- 使用者確認最高房間頂部至畫面上緣、最低房間地基底部至畫面下緣都補滿，中央龍通道保留。修改 `lane_layout.gd`、`prototype_floor.gd`、`room_module.gd`，未修改任何房間／樓層 `.tscn` 或攝影機。
- 最高層沿用 `CeilingAnchor/RoomCeiling`，最低層各房新增 runtime `BottomCeiling`，都使用既有 `room_ceiling.tscn`。封板只在外側樓層出現；中間層保留原先接到上層地基的封板。
- 封板高度依 Camera3D 視錐的上下邊界計算，前後深度角點取足夠的覆蓋量；較厚封板所需的水平覆蓋亦納入左右延伸。沿用 `framing_changed` 在 resize／層數變更後更新，保持原構圖與 Gameplay Marker。底部封板上表面與地基底面接齊，不重疊可見側面；石材下表面保留原防共面偏移。
- `Room.set_bottom_ceiling_height(height)` 同步定位、厚度、碰撞、左右延伸；非正高度移除底板，非有限值不修改。重建不會累積底板；手動恢復核心房間時外側封板也恢復最小厚度 0.3。
- Godot 4.7.2／Jolt 回歸 2973 項檢查、Forward Plus／D3D12 覆蓋及碰撞 297 項檢查皆 0 失敗。後者包含 1／3／5 層、1280×720／900×1600／2400×900 視窗、恢復尺寸、上下與水平角點、單層雙封板、底面接縫及中央通道。
- 暫存驗證 `verify_boundary_caps.gd`／`preview_boundary_caps.gd` 位於 `C:/Users/LeeDong/AppData/Local/Temp/fgj-ceiling-validation-20261004`；預覽 `C:/Users/LeeDong/.codex/visualizations/2026/10/04/01a105be-61de-7091-a0d7-fa2fc5732b55/room_boundary_caps_preview.png`。該階段驗證時尚未提交；後續授權提交狀態見本文最後一節。

## 2026-10-04 ART-26 地板空缺修正與調整位置

- 原因：左右房間子場景的 Foundation 仍保留手動延伸的中心 X = −6／+6，`room_module.gd` 卻把寬度改為 `8 + outer_extension`，造成核心地基偏離房間與天花板。後加的 Mesh2 只有外觀，沒有配對碰撞，且與程序地基重疊。
- 修正：`room_module.gd::_apply_extension()` 重算地基／背牆簷帶的中心，保留原 Y／Z；地基額外補片隱藏。地板石片維持在地基上方，避免原場景負 Y 偏移抵消表面間距。房間陳設與定位點不變。
- 調整：`prototype_floor.tscn` 根節點的 `Fit Screen Edges` 預設啟用，遊戲依鏡頭覆寫兩房 `Outer Extension`。需要手動設定寬度時，先關閉 `Fit Screen Edges`，再選 `LeftRoom`／`RightRoom` 調整 `Outer Extension`；`Floor Surface Offset` 控制石片與地基的間距。不要移動 Foundation 或複製 Mesh 補洞。
- `prototype_floor.tscn` 的左右房間 Transform 是房間整體位置，不能修正房間內地基的中心偏移。`game.tscn` 的 LaneLayout 使用 `Floor Scene` 指定的 PackedScene 重新生成 Floor0、Floor1 等節點；應編輯來源子場景，停止後重新 F6／F5 驗證。
- 回歸：`scenes/rooms/verify_room_floors.gd` 使用實際 LaneLayout 與房間來源，驗證單層／三層、延伸 0／2.5／12／0、完整碰撞、封板邊界、重複補板停用與石片間距，Jolt 616 項通過。以目前房間場景在隔離暫存專案執行，避免啟動網路／麥克風 autoload；Forward Plus 另驗證單層／三層／五層和橫向／直向／超寬視窗共 297 項通過。
- 預覽：`C:/Users/LeeDong/.codex/visualizations/2026/10/04/01a105be-61de-7091-a0d7-fa2fc5732b55/room_floor_gap_fixed.png`。缺件：無；後續授權提交狀態見本文最後一節。

## 2026-10-04 ART-27 遊戲龍深度與實際入口

- `dragon.gd::_ready()` 呼叫 `reset_position()`，重置與每幀換層只改 `position.y`；網路 `GameStateReceiver.apply_snapshot()` 也只同步 Y。Z 沿用場景 Transform，沒有改回 DragonAnchor 的 Z。
- F5 從主選單進入的場景由 `autoload/room_manager.gd::GAME_SCENE` 指定，實際為 `scenes/game/main.tscn`。另一份 `game.tscn` 的變更只在直接 F6 該場景時使用。
- 本次把 main.tscn 的 Dragon Z 從 −11.913324 同步為使用者 game.tscn 的 −25，PrototypePresentation 的 Far Padding 同步為 40；X、Y、倍率與玩法節點保留。
- 後續在 `scenes/game/main.tscn` 選 Dragon → Inspector → Transform → Position → Z 調整；負值越大越遠離目前位於 +Z 的鏡頭。例如 −25 → −28 往後 3 單位。停止後重新 F5／F6。修改來源 `dragon.tscn` 的 Transform 會被 main.tscn 的實例 Transform 蓋過。
- 驗證：使用正式場景的 LaneLayout、Dragon、PrototypePresentation 實例設定在隔離暫存專案執行 Forward Plus；生成、換層、重置、三層 × 三種擺頭 × 九個飛行時間點共 171 項檢查通過，Z 維持 −25，模型距遠裁切面至少 7.45。缺件：無；後續授權提交狀態見本文最後一節。

## 2026-10-04 使用者驗收後提交

- 使用者授權本輪修改 commit／push，目標分支 `fix/mainSceneView`。
- `a6c81c0`：樓層上下封板、地板與碰撞接邊、龍 Z = −25、遠裁切空間及地板回歸腳本；保留使用者已存檔的房間、角色倍率與燈光調整。
- `35e953a`：鍋子 UI 移除進度條、圖示與實際食譜收集數同列，腳本間距預設 48、場景覆寫 100；包含必要的 UI 資源／圖示匯入設定。
- 兩項提交已推送至 `origin/fix/mainSceneView`。提交前重跑 Jolt 地板 616 項、Forward Plus 龍深度 171 項及鍋子 UI 渲染檢查，皆通過；上下邊緣封板的 Forward Plus 297 項驗證已於 ART-26 完成。
- 後續場景儲存移除了 game.tscn 的背景 Depth Ratio = 0.95 覆寫，現沿用背景子場景值；最遠深度著色器與 Far Padding = 40 保留。ART-24 的背景位置數值為該階段驗證紀錄。