# Prototype 未提交成果檢視清單

2026-10-03，美術總監整理。下列成果均未 commit／push；規格方向已確認，不等於使用者已驗收實際成果。使用者確認完整任務完成後才提交。

使用者後續要求本輪先收尾，接續清單見 `prototype_art_handoff.md`，此清單繼續供成果檢視。

## 先看整體畫面

用 Godot 開啟 project.godot，按 F5 執行 scenes/main/main.tscn。

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
| 樓層及主構圖 | scenes/rooms/prototype_floor.tscn、scenes/main/main.tscn；F5 | 三層高低、左右配置、中央通道、主龍新變換、預留定位點 | prototype_rooms.md、prototype_camera.md |
| 三種龍蛋與幼龍 | scenes/rooms/dragon_egg.tscn、dragon_egg_lowpoly.tscn、stylized_dragon_egg.tscn、baby_dragon.tscn；主場景 F5 | 貼圖、顏色、尺寸、落地、與鍋子分開；幼龍為原始靜態站姿，未附動畫 | prototype_rooms.md |
| 紅龍動畫與嘴部掛點 | 主場景 F5 觀察 fly；開 scenes/red_dragon/red_dragon.tscn，選 Model/AnimationPlayer，在動畫面板預覽七個動作 | 動作姿勢、飛行循環、嘴部掛點；編輯器動畫面板檢查姿勢，程式循環／轉場規則見文件 | dragon_animation_api.md（180 項檢查通過） |
| 攝影機／燈光／環境 | 主場景 F5；scenes/main/prototype_presentation.tscn | 長焦透視、俯視角、三層可讀性、明暗及主角／房間關係 | prototype_camera.md |
| 吸取／噴火 | 開 scenes/vfx/vfx_preview.tscn，按 F6 | 1 吸取、2 噴火、Space 停止；氣流收束、短錐火焰、停止無殘留、避免遮擋 | dragon_vfx_api.md |

特效展示還可用 Tab 切換目標、+／- 調整射程、PageUp／PageDown 切換展示高度。這些只作用於獨立展示，沒有串接麥克風或食材玩法。預設射程 6 會截短遠於 6 的目標；若要檢查連到左房標記，可在展示內增加射程。主場景 F5 的特效預設停止。

## 共用文件與素材

- [ ] AGENTS.md：總監派工、缺件回報、使用者確認後才提交，以及 Godot 名詞規則。
- [ ] docs/design.md、room_concepts_v1.md：已確認的房間、三層、攝影機換算、新主龍構圖與特效方向。
- [ ] docs/conventions.md：新子場景歸屬與編輯範圍。
- [ ] docs/tasks.md、art_asset_needs.md：完成狀態與缺件追蹤。
- [ ] docs/prototype_art_review.md、prototype_main_preview.png：總監整合紀錄與主鏡頭預覽。
- [ ] Models/dragonEggs/、Models/dragonBabies/：使用者提供的原始模型、貼圖與匯入檔。
- [ ] Models/kitkayDungeon/：新提供批次，目前 185 個 GLB；分類及實物驗證進行中，尚未配置到本版房間，後續檢視 docs/kitkay_dungeon_inventory.md。兩類房間使用不同素材，本批分配哪類房間待決定；人物先放挑戰房，但人物檔案位置仍待確認。

各模組的腳本、shader、驗證工具、.uid／.import 也在未提交範圍內；圖形匯入快取 .godot/ 不列入提交。

## 尚未完成與另外出現的改動

- 育幼核心仍缺巢穴、稻草／軟墊；尚未完成整體美術驗收。幼龍與龍蛋已完成配置。
- 次要概念道具目前以既有道具簡化，是否補鐵門、鎖鏈、暖爐等仍待檢視。
- 專用吸取／噴火動畫、atk／roar 對應、轉頭及作用時刻未定案；食材、關卡生成、麥克風、鍋子與勝敗邏輯由後續程式接入。
- scenes/dungeon_room/dungeon_room_dev.tscn、docs/asset_credits.md 也尚未提交，但不是本輪指派 session 的交付；提交前需核對來源與歸屬。前者可開啟後 F6 查看，後者核對素材來源與署名欄位。兩者目前原樣保留。
