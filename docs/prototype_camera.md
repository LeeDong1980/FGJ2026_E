# Prototype 攝影機、燈光與後處理

負責：@合成師。主場景與房間由場景美術整合；共用文件、最終畫面驗收與提交由美術總監管理。

## 交付檔案與整合

- `res://scenes/main/prototype_presentation.tscn`：可重用子場景，包含 `PresentationCamera`、`WorldEnvironment` 與 `LightRig`。
- `res://scenes/main/prototype_presentation.gd`：具 `@tool` 的專用腳本，依布局邊界及視窗比例調整構圖，提供樓層配置接口。
- `scenes/main/prototype_presentation.gd.uid`：由 Godot 4.7.2 在獨立驗證專案生成的腳本 UID。

在 Main 下實例化此子場景一次，保持其位置與旋轉為零、縮放為一。房間只保留局部燈光；主場景不要另外放置啟用的 Camera3D 或第二個 WorldEnvironment。PresentationCamera 預設為目前攝影機。

本次沒有修改主場景、房間、紅龍、來源模型、匯入設定或 project.godot。此子場景單獨執行只呈現背景，應搭配樓層與紅龍觀看。

## 來源相機換算與假設

來源資料：透視投影、焦距 150mm，來源位置 `(0, -280, 40)`，XYZ 歐拉角度 `(85, 0, 0)`。假設這是世界變換，沒有父節點變換、追蹤約束、鏡頭偏移或非方形像素。

- 座標映射：Godot `(x, y, z) = (來源 x, 來源 z, -來源 y)`。
- 原始未縮放的 Godot 相機位置為 `(0, 40, 280)`。
- 轉換相機基底後，Godot `rotation_degrees = (-5, 0, 0)`，沿 -Z 看入房間並俯視 5°。腳本及 tscn 的 `rotation` 使用弧度。
- 以水平感光元件寬 36mm、水平適配、參考比例 16:9 換算；來源感光元件資訊尚未提供，36mm 是明確的製作假設。
- 水平 FOV：`2 * atan(36 / (2 * 150)) = 13.6855468°`。
- 有效感光元件高度：`36 / (16 / 9) = 20.25mm`。
- 垂直 FOV：`2 * atan(20.25 / (2 * 150)) = 7.7232148°`。
- Godot 使用 `PROJECTION_PERSPECTIVE`、`KEEP_HEIGHT`，`fov = 7.7232148`。

使用 CameraAttributesPractical，明確關閉自動曝光及近／遠景深。沒有以 CameraAttributesPhysical 的焦距屬性取代 Camera3D FOV，避免其感光元件假設覆寫已換算的構圖。

來源說明：[Godot 座標慣例](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html)、[Camera3D FOV 與 Keep Aspect](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)、[感光元件適配](https://docs.blender.org/manual/ja/4.5/render/cameras.html)、[CameraAttributesPhysical 覆寫行為](https://docs.godotengine.org/en/stable/classes/class_cameraattributesphysical.html)。

## 三層布局的實際製作參數

房間基準：各 8 × 8、室內高 4；房間中心 X = ±8；樓層 Y = 0、5、10；前側 +Z 開放，天花板預設由房間端隱藏。

攝影機邊界不是只有房間中心點：橫向預留牆厚 0.3，深度預留 0.3，底部預留 0.25、頂部預留 0.3。默认 `layout_bounds` 為：

`AABB(Vector3(-12.3, -0.25, -4.3), Vector3(24.6, 14.55, 8.6))`

| 項目 | 1920 × 1080 驗證結果，約值 |
|---|---:|
| 構圖中心 | `(0, 7.025, 0)` |
| 每側安全邊界 | 畫面寬／高的 8% |
| 沿相機後向的距離 | `138.0779` |
| Camera3D 位置 | `(0, 19.05928, 137.5525)` |
| Rotation Degrees | `(-5, 0, 0)` |
| Near / Far | `0.5 / 150.9956` |
| 來源位置的統一倍率 | `0.49125885` |
| 倍率之後的整體構圖位移 | `(0, -0.59107, 0)` |

位置關係：`actual_position = Vector3(0, 40, 280) * source_scale + source_offset`。此倍率只描述相機相對於來源位置的製作調整，並不要求再縮放已量測好的房間或紅龍。它不是紅龍模型實例的 0.05 縮放值。

腳本將邊界的八個角點轉到相機基底，取能同時容納水平、垂直與深度的最小距離。令角點相對構圖中心的相機座標為 `(qx, qy, qz)`，內框係數 `u = 1 - 2 * safe_border`：

`D >= qz + max(abs(qx) / (tan(horizontal_fov / 2) * u), abs(qy) / (tan(vertical_fov / 2) * u))`

Far 包含最遠角點與額外 8 單位；主光陰影距離隨 Far 更新，避免遠距長焦鏡頭下沿用較短的陰影距離。窗寬改變時維持垂直 FOV，以實際視窗比例重新構圖。編輯器使用參考比例，避免其 3D 面板比例改動製作鏡頭。

本子場景不修改專案視窗或強制加黑邊。16:9 是製作基準；其他比例也會重排鏡頭距離保留內容。

## Inspector 與程式配置

| Export 屬性 | 用途 |
|---|---|
| `layout_bounds` | 此子場景局部座標中的完整可見布局邊界，應包含道具與動畫最大範圍 |
| `safe_border` | 四邊預留比例，預設每側 0.08 |
| `framing_offset` | 構圖中心的額外位移；角點仍會重新納入安全邊界 |
| `focal_length_mm` / `sensor_width_mm` | 來源鏡頭換算假設，預設 150 / 36 |
| `reference_aspect` | 水平感光元件換算垂直 FOV 的參考比例，預設 `(16, 9)` |
| `pitch_degrees` | 向下俯視角，預設 5° |
| `near_clip` / `far_padding` | 裁切近面及最遠邊界以外的餘量 |

在 presentation 加入場景樹並完成 ready 後呼叫：

```gdscript
var presentation: Node3D = $PrototypePresentation
# 關卡生成器完成房間擺放後，依實際樓層重新構圖。
presentation.configure_for_layers(3, 5.0, Vector3(8.0, 4.0, 8.0), 8.0)

# 不規則布局或動畫／道具超出房間邊界時，直接提供完整 AABB。
presentation.layout_bounds = actual_layout_bounds
presentation.reframe() # 需要立即生效時呼叫；export setter 也會延後重算。
print(presentation.get_framing_settings())
```

`configure_for_layers(layer_count, layer_spacing, room_size, room_center_x, floor_origin)` 只計算相機邊界，不生成房間、控制龍或執行玩法。room_size 為寬／高／深，floor_origin 使用 presentation 局部座標。無效樓層數或尺寸保留原設定並提示。`get_framing_settings()` 回報距離、來源倍率／偏移、位置、旋轉、FOV、裁切與視窗比例，供總監整合核對。

## 共用燈光與後處理

- WarmKey：正面略偏側的暖主光，色彩 `(1, 0.86, 0.72)`，energy 1.05，為唯一開啟陰影的共用 DirectionalLight3D。採單一正交陰影範圍，以免狹窄長焦畫面將陰影分配到大量空白的近距區域。
- CoolFill：另一側的冷補光，energy 0.38，不加陰影，保留石造與房間內部可讀性。
- CoolRim：後側冷輪廓光，energy 0.5，不加陰影，分離中央紅龍輪廓。局部火把、鍋子及育幼暖光由場景美術控制。
- 環境：深藍背景、`AMBIENT_SOURCE_COLOR`，環境光 energy 0.32。沒有依賴未配置的 Sky，天空反射關閉。
- 色調映射：Filmic、固定曝光 1.0；保留暖色主體與冷石背景。
- SSAO：radius 0.35、intensity 0.65、power 1.2、detail 0.35，提供輕量接觸感。
- Glow：intensity 0.22、HDR threshold 2.0、bloom 0、normalized 開啟；聚焦高亮火焰／藥液，減少大面積泛光。
- 近／遠景深與自動曝光關閉；沒有額外霧效、全畫面材質或自訂 Compositor。玩法物件保持清楚，局部材質是否達到 Glow 門檻由最終畫面確認。
- Environment 與 CameraAttributesPractical 都設定 `resource_local_to_scene`，實例間可獨立調整。

## 驗證紀錄與限制

2026-10-03 使用既有 Godot 4.7.2，在獨立臨時專案 `fgj2026e-presentation-validation` 驗證；沒有在共享專案執行匯入或改寫快取。

- Headless 編輯器匯入與場景／脚本載入完成，沒有解析錯誤。
- 執行驗證 exit code 0、failures 0。
- 1920 × 1080、1080 × 1920、2560 × 1080，以及一層、五層、位移後的布局共六組、48 個邊界角點均在視錐及四邊 8% 安全範圍內。視窗比例变化觸發重新構圖。
- 垂直 FOV、5° 俯視、目前攝影機、Near/Far、關閉景深／自動曝光均已檢查。
- 兩個實例的 Environment 與 CameraAttributes 資源不共用；第二個實例調 Glow 不影響第一個。
- 無效零層設定不改原布局。

Headless 驗證沒有評估 GPU 畫面、實際亮度、陰影品質或幀率。房間、紅龍與未到位的育幼素材由其他 session 製作；龍口、鍋子有無被道具／上層地板遮擋，以及動畫是否超出上述 AABB，須由美術總監在完整主場景最終驗證。新陳設超界時應擴大 layout_bounds 再 reframe，不能只依賴本次房間尺寸。

## 主龍倍率 5 與加寬特效的構圖協作

2026-10-03，依 master `def2614` 及總監接續指派檢查。首版已提交；本次僅增補本文件，不修改 Camera3D、WorldEnvironment、主場景、game 場景、模型或匯入設定，也不重新套用早期紅龍展示倍率。

目前 Main 主龍根節點 `scale = Vector3(5, 5, 5)`，位置 `(0, 6.4, -16.018951)`、base animation 為 fly；模型子節點仍採 0.05 縮放。攝影機仍為上述 150mm 等效、5° 俯視與 16:9 基準。中央通道是房間之間的 8 單位空間（X = −4～4），不是保證能容納所有姿勢的龍翼或斜向特效的盒形限制。

使用者已選擇更誇張、覆蓋更大的效果。構圖協作採用技術美術的初始規格：吸取完整寬度 4.0、噴火完整寬度 3.0，合法調整範圍 0.1～8.0。寬度指最寬截面的直徑，使用 Godot 世界單位，並非半徑或螢幕像素；不能再乘上主龍倍率 5。維持嘴端收束，射程為獨立參數。下列觀察不要求縮窄已定預設，也不要求擴大或重置使用者構圖。

### 幅寬與畫面尺度

以目前鏡頭、1600 × 900，以及既有預覽的中層左房目標 `QueueFrontAnchor + Vector3(0, 1, 0)`，世界位置 `(-4.6, 6, 1.1)` 量測。幅寬是端部截面投影到畫面中、垂直於作用方向的尺寸：

| 完整世界寬度 | 預覽中的端部投影寬度，約值 | 用途 |
|---|---:|---|
| 0.7 | 33～34px | 首版 radius 0.35 的幾何參照 |
| 3.0 | 143～146px | 已定噴火預設，約首版的 4.3 倍 |
| 4.0 | 191～195px | 已定吸取預設，約首版的 5.7 倍 |
| 8.0 | 382～389px | 已定可調上限，約首版的 11.4 倍 |

表中合併視覺射程 6 與 12 的觀察結果；12 僅是獨立比較案例，沒有改動預設射程。最小寬度 0.1 的純截面投影約 4.8px；實際 shader 的粒子尺寸、波動、透明度與 Glow 可能使可見輪廓不同，須由技術美術的 GPU 截圖驗收。其他解析度的像素值會隨畫面尺寸變化。

### 姿勢、射程與遮擋

在獨立臨時副本對 fly 的完整 6.6667 秒週期均勻取樣 61 個姿勢，使用目前主龍變換。取樣嘴部世界範圍約為 X = −0.676～0.997、Y = 9.220～15.309、Z = −5.332～−4.345。龍根節點在中層，嘴部卻會高於中層，斜向效果本身即會穿過其他層的畫面高度。

- 嘴部到上述中層目標距離為 8.45～12.16；射程 6 在所有取樣姿勢都會截短。加寬不會使軸線到達目標，亦不能作為玩法命中判定。不要為加寬自動延長射程。
- 以逐段截面建立的幾何包絡檢查，寬度 3／射程 6 會进入左側中層房間的名義空間；寬度 4／射程 6 在部分姿勢亦會進入左側高層房間空間。
- 上限寬度 8，無論測試射程 6 或 12，均在不同 fly 姿勢出現進入左側低／中／高層房間空間的樣點；這不是每一幀同時覆蓋三層的斷言。上限 8 是可調幅寬規格，不是全姿勢無遮擋的保證。
- 射程 12、寬度 4 的包絡最低約 Y = 4.15，寬度 8 最低約 Y = 2.30；加長射程的對照案例可能接近或跨過中層地板及相鄰樓層。實際石地板、牆柱、道具的遮挡需 GPU 確認，名義房間空間交會不等於可見像素必定被遮擋。
- 這組左房目標的包絡取樣沒有進入右房名義空間（X = 4～12、Z = −4～4、各層室內高度 4）。此結果不保證其他目標方向、右鍋目標或所有動畫下的鍋子／幼龍都可見。
- 已檢查的幾何樣點皆在完整視錐內，但包含首版寬度 0.7 在內，部分高姿勢樣點會進入原來的 8% 上側留白。原有安全邊界只依房間 AABB 構圖，沒有涵蓋目前倍率 5 的全部嘴部姿勢；本次保持鏡頭不變。

建議技術美術保留已定大幅寬與嘴端方向感，觀察最小／預設／最大三組 GPU 畫面中的粒子密度、核心透明度、地板截切、換層時的清場，以及真正食材的可辨識程度。幅寬接口仍以技術美術維護的 `docs/dragon_vfx_api.md` 為準。總監統整實際遮擋結果，不以本次幾何估算取代視覺驗收。

### 本次驗證範圍

臨時專案：`C:/Users/LeeDong/AppData/Local/Temp/fgj-camera-width-review-20261003`，量測腳本 `review_width.gd`。只複製 presentation、紅龍及其模型到副本，使用 Godot 4.7.2 headless 匯入與取樣；程式正常結束，沒有操作使用者 Godot 或共享快取。

檢查含四種寬度、兩種射程、61 個 fly 姿勢，每個姿勢以 11 個截面、各 32 個圓周點量測。幾何採嘴端 8%～外端完整半徑的包絡，供吸取／噴火共同比較；沒有執行正在修改的加寬 shader，因此不是其實際粒子輪廓、密度或 GPU 效能驗證。並已查看首版已提交的 `scenes/vfx/qa/vfx_fire.png` 與 `vfx_fire_range12.png`，確認原先窄效果與截短／延長表現。

目前 `game.tscn` 仍有自己的 Camera3D 及原 LaneLayout，GM-16 的美術接入由 @露柑 負責。本節只對現有 Main 展示構圖成立；遊戲接入不同層距、角色包裝變換或目標定位點後需重做投影與遮擋確認，合成師不在本次改動遊戲場景。

## ART-13：依現有鏡頭查詢通道外緣（2026-10-04）

本輪先交可測接口，供 ART-15 場景美術拼接外側通道。16:9 現有構圖是可檢視草案，最終接邊布局仍由總監與使用者確認。中央 RedDragon transform、攝影機既有焦距／俯角／安全留白、房間內側 X = −4／+4 與所有定位點維持原值。房間外緣的延伸幾何不得納入 `layout_bounds`；該 bounds 只包含原本房間核心，否則「延伸→鏡頭後退→再次延伸」會形成回授。

### 查詢與通知接口

- `get_visible_horizontal_span(world_y, world_z) -> Dictionary`：以世界 Y／Z 指定水平線，回傳目前 Camera3D 完整視窗左右邊界的世界 `Vector3`，鍵為 `valid`、`left`、`right`。這是純查詢，不取景，不移動鏡頭，不套用 8% `safe_border`；邊界是螢幕 X = 0／viewport width。
- `get_visible_floor_edges(floor_y, front_z, back_z) -> Dictionary`：回傳 `valid`、`front_left`、`front_right`、`back_left`、`back_right` 四個世界座標。天花板／牆頂另以 `floor_y + room_height` 查詢，不能直接沿用地板寬度。
- `framing_changed`：每次成功 `reframe()` 後發出；包含 viewport resize 及 `configure_for_layers()` 的取景更新。接收端只重建通道外緣，不能從回呼再次呼叫 `reframe()` 或改 `layout_bounds`。
- `valid = false` 時只回傳 `reason`，沒有邊界座標。原因包含未進入場景／尚未 ready、非有限輸入、水平線平行側視錐面、超出 near/far 或垂直畫框。編輯器下回傳 `runtime_viewport_required`：編輯器 3D 面板比例與基準構圖不同，本接口以執行時 viewport 為準。

左右點由 Camera3D 世界空間側視錐面與指定水平線求交，再檢查深度與垂直投影。若 Presentation 或房間有位移，傳入真正的世界 Y／Z；回傳點以房間 `to_local()` 換回本地座標後建立幾何。`configure_for_layers()` 的 `floor_origin` 則沿用原接口，屬 Presentation 本地空間。若外部單獨移動 Presentation transform，接收端需自行重新查詢；這種變換不會自動發出取景通知。

房間端接法示意（由場景美術實作，合成師沒有修改房間／Main／Game）：

```gdscript
func _ready() -> void:
	presentation.framing_changed.connect(_refresh_outer_corridors)
	# 等全部樓層建立及 configure_for_layers 完成後再讀第一組邊界。
	_refresh_outer_corridors.call_deferred()

func _refresh_outer_corridors() -> void:
	var edges: Dictionary = presentation.get_visible_floor_edges(floor_world_y, front_world_z, back_world_z)
	if not edges["valid"]:
		return
	# 將四角 to_local() 後只更新外側地板、後牆、屋頂與碰撞。
	# 牆頂／屋頂需以 floor_world_y + room_height 再查一次。
```

### 目前三層 16:9 的實測邊界

測量條件：1600×900、Presentation identity、三層、層距 5、前 Z = +4、後 Z = −4；目前 camera 本地位置約 `(0, 19.05928, 137.5525)`。以下為世界 X，完整座標為 `(X, 該列 Y, 指定 Z)`，單位均為 Godot 世界單位。

| 樓層 Y | 前緣左 X | 前緣右 X | 後緣左 X | 後緣右 X |
|---|---:|---:|---:|---:|
| 0 | −16.16465 | 16.16465 | −17.12099 | 17.12099 |
| 5 | −16.11235 | 16.11235 | −17.06870 | 17.06870 |
| 10 | −16.06006 | 16.06006 | −17.01641 | 17.01641 |

這些是接口驗證數值，不能硬寫成房間固定寬度。現有房間外緣 X = ±12，通道從外側向查詢邊界延伸，內側 ±4 保留。透視使後緣比前緣多伸約 0.956 單位，各層與牆頂也不同。矩形模組可取地板／牆頂所有前後角的最外 X 覆蓋，末段加約 0.05～0.1 世界單位越出畫框避免裂縫；或使用各角形成梯形外緣。保持道具原尺寸，不縮房間、不拉伸核心陳設。阻擋外側通道的原牆、地板／後牆／可隱藏屋頂及碰撞需由場景美術同步處理。

### 驗證與交付限制

獨立臨時專案 `C:/Users/LeeDong/AppData/Local/Temp/fgj-camera-edge-validation-20261004`，脚本 `verify_edges.gd`；只複製 presentation 子場景與腳本，沒有匯入共享專案或模型。Godot 4.7.2 headless 執行共 191 項檢查全部通過，取景通知觀察到 9 次：

- 三層各地板及室內頂部的前後四角，投影至螢幕左右邊緣，誤差小於 0.02px。
- 16:9、直向 900×1600、超寬 2400×900，以及 resize 恢復基準後的查詢。
- `configure_for_layers(1)`／`(5)`／回到三層後查詢；基準 camera transform 恢復，純查詢前後 transform 相同。
- Presentation 世界位移後的邊界查詢，以及未 ready、NaN、垂直畫外、鏡頭後方、超出 far 與退化朝向的拒絕處理。

執行退出碼 0。環境有 Windows 根憑證讀取警告，與相機幾何測試無關；本次沒有進行 GPU 房間拼接畫面驗收。ART-13 接口階段完成，完整任務仍待 ART-15 接入後檢查三層地板／牆／屋頂／碰撞接邊、縮放視窗及中央龍／食材／鍋子遮擋。沒有更動任何房間、樓層、Main、Game、模型或共享任務文件，沒有 commit／push。
