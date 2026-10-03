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
