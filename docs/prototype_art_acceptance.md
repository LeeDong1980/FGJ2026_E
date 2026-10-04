# Prototype 成果檢視與驗收清單

2026-10-03，美術總監整理。首版七項成果已由使用者確認，並由團隊提交至 718d62b、2497e5d、bec1096；本清單保留作為首版檢視入口。

使用者要求恢復工作後，更誇張的吸取／噴火加寬及寬度接口（ART-07／ART-08）已完成、獲使用者驗收並授權提交 PR。紅龍原點問題（ART-09／ART-10）其後由使用者解決並撤回，本輪未改動畫；素材分配、人物位置與育幼缺件仍待處理。

## 兩項緊急任務的確認入口

| 任務 | 確認方式 | 目前狀態 |
|---|---|---|
| 加寬吸取／噴火 | 開 `scenes/vfx/vfx_preview.tscn`，F6；1 吸取、2 噴火、Space 停止。Q／A 調吸取寬度、W／S 調噴火寬度；畫面即時顯示數值 | 寬度接口、GPU 對比與整合檢查通過；使用者已驗收，授權提交 PR |
| 紅龍動畫原點跑位 | 使用者表示已解決，不需繼續處理 | ART-09／ART-10 已撤回結案；未修改動畫，不宣稱本輪已修正 |

在 `scenes/main/art_prev.tscn` 選 `Effects`，Inspector 的 **Effect Widths** 可設定 `Suction Width`（預設 4）與 `Fire Width`（預設 3），合法範圍皆為 0.1～8。寬度是最寬截面的完整世界直徑，與 `Effect Range` 射程分開；程式可用 `set_effect_widths(4.0, 3.0)`，播放中也能即時修改。獨立 F6 預覽則選自己的 `DragonEffects` 節點設定。完整接口與相容規則見 `dragon_vfx_api.md`。

目前主龍嘴部距隊首常大於預設射程 6，因此效果可能截短；要連到目標須另調射程。最大寬度 8 有意提供誇張範圍，會跨層並遮住部分左房陳設。F5 主場景的效果預設停止；F6 預覽尚未串接麥克風或胃袋吐食材玩法。

## 先看整體畫面

用 Godot 開啟 project.godot，開啟 scenes/main/art_prev.tscn 按 F6（F5 現在是遊戲主選單）。

- [ ] 三層沿 Y 軸垂直排列，左挑戰房、右哺育房，中央紅龍。
- [ ] 主龍保留已確認的倍率 5、位置約 (0, 6.4, -16.019)，播放 fly。
- [ ] 前牆開放，主要陳設可見；每層鍋子、三種龍蛋與藍色幼龍分開可辨識。
- [ ] 房間比例、石造風格、燈光與長焦透視符合概念圖方向。

主龍部分 fly 姿勢的翼端／頭頂會超出畫面；目前保留使用者指定構圖。

## 逐項確認

| 項目 | Godot 檢視位置 | 確認重點 | 接口／驗證文件 |
|---|---|---|---|
| 勇者挑戰房、幼龍哺育房 | scenes/rooms/hero_challenge_room.tscn、dragon_nursery_room.tscn 的 3D 編輯視圖；主場景 F5 | 石牆／家具、朝鏡頭開口、左房隊伍空間、右房鍋子及育幼陳設 | prototype_rooms.md |
| 通用天花板 | 開兩類房間，選根節點，切換 Inspector 的 Ceiling Visible；room_ceiling.tscn 可單獨查看 | 開／關是否獨立、封頂形狀，隱藏時碰撞同步停用 | prototype_rooms.md |
| 樓層及主構圖 | scenes/rooms/prototype_floor.tscn、scenes/main/art_prev.tscn；F6 | 三層高低、左右配置、中央通道、主龍新變換、預留定位點 | prototype_rooms.md、prototype_camera.md |
| 三種龍蛋與幼龍 | scenes/rooms/dragon_egg.tscn、dragon_egg_lowpoly.tscn、stylized_dragon_egg.tscn、baby_dragon.tscn；主場景 F5 | 貼圖、顏色、尺寸、落地、與鍋子分開；幼龍為原始靜態站姿，未附動畫 | prototype_rooms.md |
| 紅龍動畫與嘴部掛點 | 主場景 F5 觀察 fly；開 scenes/red_dragon/red_dragon.tscn，選 Model/AnimationPlayer，在動畫面板預覽七個動作 | 動作姿勢、飛行循環、嘴部掛點；編輯器動畫面板檢查姿勢，程式循環／轉場規則見文件 | dragon_animation_api.md（180 項檢查通過） |
| 攝影機／燈光／環境 | 主場景 F5；scenes/main/prototype_presentation.tscn | 長焦透視、俯視角、三層可讀性、明暗及主角／房間關係 | prototype_camera.md |
| 吸取／噴火 | 開 scenes/vfx/vfx_preview.tscn，按 F6 | 1 吸取、2 噴火、Space 停止；Q／A 與 W／S 分別調寬，檢視最小／預設／最大寬度及停止無殘留 | dragon_vfx_api.md |

特效展示還可用 Tab 切換目標、+／- 調整射程、PageUp／PageDown 切換展示高度。這些只作用於獨立展示，沒有串接麥克風或食材玩法。預設射程 6 會截短遠於 6 的目標；若要檢查連到左房標記，可在展示內增加射程。主場景 F5 的特效預設停止。

## 共用文件與素材

- [ ] AGENTS.md：總監派工、缺件回報、使用者確認後才提交，以及 Godot 名詞規則。
- [ ] docs/design.md、room_concepts_v1.md：已確認的房間、三層、攝影機換算、新主龍構圖與特效方向。
- [ ] docs/conventions.md：新子場景歸屬與編輯範圍。
- [ ] docs/tasks.md、art_asset_needs.md：完成狀態與缺件追蹤。
- [ ] docs/prototype_art_review.md、prototype_main_preview.png：總監整合紀錄與主鏡頭預覽。
- [ ] Models/dragonEggs/、Models/dragonBabies/：使用者提供的原始模型、貼圖與匯入檔。
- [ ] Models/kitkayDungeon/：185 個 GLB 的分類、全部載入及外觀盤點完成，尚未配置到本版房間，索引見 docs/kitkay_dungeon_inventory.md。兩類房間使用不同素材，本批分配哪類房間待決定；人物先放挑戰房，但人物檔案位置仍待確認。

以上首版檢視項目已獲使用者確認並提交，保留操作清單方便複查，不表示全部再次待驗收。本輪 PR 範圍為已驗收的加寬特效及相關文件，原點修正已撤回；圖形匯入快取 .godot/ 不列入提交。

## 尚未完成與另外出現的改動

- 育幼核心仍缺巢穴、稻草／軟墊；尚未完成整體美術驗收。幼龍與龍蛋已完成配置。
- 次要概念道具目前以既有道具簡化，是否補鐵門、鎖鏈、暖爐等仍待檢視。
- 專用吸取／噴火動畫、atk／roar 對應、轉頭及作用時刻未定案；食材、關卡生成、麥克風、鍋子與勝敗邏輯由後續程式接入。
- scenes/dungeon_room/dungeon_room_dev.tscn、docs/asset_credits.md 已隨首版團隊提交，不是本輪緊急修改範圍。前者可開啟後 F6 查看，後者核對素材來源與署名欄位；兩者維持原樣。
