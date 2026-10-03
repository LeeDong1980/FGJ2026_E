# Prototype 美術交接清單

2026-10-03，美術總監整理。使用者要求本輪先收尾；停止新增製作與配置，保存已完成成果及未完成事項。**本輪沒有 commit／push，也尚未取得完整任務完成確認。**

## 專案狀態與檢視入口

- 工作目錄：`C:/UnityProject/FGJ2026_E`。
- 收尾時分支：`master`；HEAD：`4a87107`（art: track concept image imports and complete changes cleanup）。本輪成果仍在工作目錄中。
- Godot：專案規格 4.7，驗證執行檔 4.7.2；Forward Plus／D3D12、Jolt。
- 整體畫面：開 `project.godot`，F5 執行 `scenes/main/main.tscn`。
- 特效：開 `scenes/vfx/vfx_preview.tscn`，F6；1 吸取、2 噴火、Space 停止、Tab 切目標、+／- 調射程、PageUp／PageDown 切展示高度。
- 詳細驗收操作：`docs/prototype_art_acceptance.md`。
- 最新主鏡頭預覽：`docs/prototype_main_preview.png`；整合證據：`docs/prototype_art_review.md`。

## 已定案且須保留

- 使用 Godot 名詞記錄：可重用子場景（PackedScene）、Node3D、Marker3D、AnimationPlayer；Unity 用語先轉換再記錄。
- 主場景先三層，沿 Y 垂直排列，樓層高度 0／5／10；左勇者挑戰房、右幼龍哺育房，保留每層鍋子。未來層數由程式讀取關卡設定生成。
- 房間前側 +Z 朝攝影機開放；通用天花板可逐房隱藏，預設隱藏且停用其碰撞。
- 主龍使用者新構圖：根倍率 5、位置 `(0, 6.4, -16.018951)`、基礎動畫 fly。不要還原倍率 2 或強制對齊 MiddleFloor 的 DragonAnchor。
- 攝影機以 Blender Perspective／150mm 換算，Godot 俯視 5°，垂直 FOV 約 7.7232°；36mm 水平感光元件與 16:9 為換算假設，展示 rig 依房間邊界重新構圖。細節見攝影機文件。
- 吸取為收束到嘴的氣流，噴火為清楚、節制的短錐暖色火焰；主場景預設停止，未自行將 atk／roar 對應到玩法。
- 育幼核心素材由使用者提供；不以小型成年龍、幾何巢或其它代用品補齊尚缺素材。
- **兩類房間要用不同素材；kitkayDungeon 用哪一類尚未決定，暫不配置此批地牢物件。人物模型先放挑戰房，但人物檔案尚未找到。**

## 已完成交付與負責人

| Session | 完成成果與可編輯範圍 | 接口／文件 |
|---|---|---|
| 場景美術 | `scenes/rooms/`：兩類房間、通用天花板、樓層、三種蛋、幼龍；`scenes/main/main.tscn`：三層、主龍與 Effects 接入 | `docs/prototype_rooms.md` |
| 動畫師 | `scenes/red_dragon/`：七個既有動畫、實例獨立資源、循環／轉場、嘴部骨架掛點 | `docs/dragon_animation_api.md` |
| 合成師 | `scenes/main/prototype_presentation.tscn` 及專用腳本：攝影機、燈光、WorldEnvironment | `docs/prototype_camera.md` |
| 技術美術與特效 | `scenes/vfx/`：程序粒子、三個 shader、連續火焰核心、控制器、獨立展示、QA 圖片及驗證工具 | `docs/dragon_vfx_api.md` |
| 美術總監 | 共用設計／分工／素材／任務文件、驗收清單、最新預覽及整合驗證 | 本文件、`docs/art_asset_needs.md`、`docs/prototype_art_review.md` |

場景歸屬以 `docs/conventions.md` 為準，其他 session 不直接修改負責人的 .tscn。

### 現有接口

- 樓層：`get_room(left/right)`、`get_anchor(name)`、`set_ceilings_visible(enabled)`、Inspector `floor_index`／`ceilings_visible`。
- 房間：`get_anchor(name)`、Inspector `ceiling_visible`；天花板開關同步控制可見性與碰撞。
- 定位點：Dragon、QueueSpawn、QueueFront、Pot、Nest、Hatchling、Egg，以及各房 Ceiling。讀取 global_position 取得世界座標；不要將展示龍根節點直接套回舊定位點。
- 紅龍：`play_animation(name, restart, use_original_attack_motion)`、`set_base_animation(name)`、`stop_animation(keep_pose)`、`get_animation_names()`、`get_mouth_anchor()`，並提供 started／finished／interrupted 訊號。
- 主場景 `%Effects`：`bind_dragon(dragon)`、`play_suction(target_global_position, duration)`、`play_fire(...)`、`set_target_global_position(...)`、`stop_effects()`。來源為骨架 MouthAnchor，大小採世界單位。
- 展示 rig：`configure_for_layers()`、`reframe()`、`get_framing_settings()`；新增樓層後由程式呼叫重算鏡頭。

### 驗證與限制

- 總監獨立 Jolt 整合檢查：`INTEGRATION_FAILURES 0`。三層索引／高度、通道、天花板碰撞、主龍新變換、蛋與幼龍尺寸落地、Effects 預設停止及播放接口通過。
- 動畫／嘴部：180 項檢查通過，包含七動作、根倍率 1／2／5、位移／旋轉及真實上唇追蹤。
- 特效：64 項檢查通過；Forward Plus 真實 shader 編譯與畫面擷取通過。停止後圖片與待機圖片一致，沒有殘留特效。
- 三種龍蛋高 0.9；幼龍高 1.15、原貼圖正常、靜態站姿，沒有附動畫。三層主鏡頭均可讀。
- 主龍部分 fly 姿勢會讓翼端或頭頂超出畫面；保留使用者構圖。fall 保留原始下降，根倍率 5 會放大位移，不能直接視為玩法降落。
- 嘴部不等於根節點的樓層高度；目前效果會斜向左房目標。預設視覺射程 6，超界截短，只控制視覺，不代表命中。轉頭、同層口部對位、專用動作與作用時刻待整合。
- 尚未實作關卡完整生成、麥克風、食材、鍋子規則或勝敗邏輯；未驗證匯出平台與目標裝置效能。

## 新素材與本輪盤點

| 來源 | 狀態 |
|---|---|
| `Models/dragonEggs/` | 三種原始 GLB 與匯入檔保留，已製作三個蛋子場景並配置 |
| `Models/dragonBabies/` | GLB、三張 PNG 及既有匯入檔保留，已製作幼龍子場景並配置 |
| `Models/kitkayDungeon/` | 185 個 GLB，先盤點不配置；總監初步 JSON 全部可讀、無骨架／動畫及外部圖片引用。場景美術回報 185 個實際載入與 10 頁視覺核對完成，正在保存分類交接文件 |

kitkay 盤點文件由場景美術維護：`docs/kitkay_dungeon_inventory.md`。已回報鐵門、鐵柵牆、空武器架、兩種木桶；未見人物、吊燈、鎖鏈、暖爐、巢穴或軟墊。部分藥瓶內液體顏色目前不易辨識，選用前需處理，不在收尾時修正。

## 待辦與缺素材

| 優先事項 | 下一步／負責 |
|---|---|
| 人物模型位置 | 等使用者提供實際檔案；場景美術確認內容、材質、原點與尺寸後先放挑戰房。未認定為企劃六種食材，也尚未擺放 |
| kitkayDungeon 分配 | 使用者決定用於挑戰房或哺育房；再規劃另一類房間的不同素材及重排範圍 |
| 巢穴、稻草／軟墊 | 核心仍缺；等使用者提供位置後完成哺育房。NestAnchor 保留空，不放替代物 |
| 次要概念陳設 | 鐵門／武器架／木桶有已盤點候選；鎖鏈／吊燈／暖爐等仍缺或待決定簡化方式 |
| 專用動作與玩法串接 | 決定 atk／roar 或新動畫對應、轉頭、觸發時機、食材目標點及視覺射程。六種食材角色素材仍待確認 |
| 素材署名與另行改動 | `docs/asset_credits.md` 仍有待補欄位；`scenes/dungeon_room/dungeon_room_dev.tscn` 為另外出現的場景，需核對來源／歸屬後再決定提交範圍 |
| 完整驗收與提交 | 補素材／定案後只重驗相關變更；使用者確認完整任務完成，再由總監分批 commit／push |

## 未提交範圍與提交順序

以重新執行 `git status --short` 的結果為準；目前主要範圍：

1. 使用者提供模型：`Models/dragonEggs/`、`Models/dragonBabies/`、`Models/kitkayDungeon/`，及 .import。
2. 房間／樓層／育幼陳設：`scenes/rooms/`、`scenes/main/main.tscn`、`docs/prototype_rooms.md`。
3. 紅龍動畫／嘴部：`scenes/red_dragon/red_dragon.tscn`、控制腳本、驗證腳本與 .uid、動畫接口文件。
4. 構圖／燈光：`scenes/main/prototype_presentation.*`、專用腳本 .uid、攝影機文件。
5. 特效：`scenes/vfx/` 的場景、腳本、shader、.uid、QA 圖／.import 及特效接口文件。
6. 共用文件與預覽：`AGENTS.md`、`docs/conventions.md`、`design.md`、`tasks.md`、`room_concepts_v1.md`、素材表、驗收／整合／交接文件、參考圖及主場景預覽／.import。
7. `dungeon_room_dev.tscn`、`asset_credits.md`：先核對來源與歸屬，勿混入其他人的改動。

此列表是交接後的建議分組，**不是提交授權**。每組 .uid／.import 隨資源保存，.godot 快取不提交；不要移動或重新命名來源模型。沒有清除、還原或暫存使用者改動。

## Session 接續位置

- 場景美術：`01a10081-9bc7-7c82-8c12-4295ae71f90b`。
- 動畫師：`01a10085-51de-7a93-a817-ef0f4fc7f715`。
- 合成師：`01a10087-79f5-7ef3-b633-c2fcd076490b`。
- 技術美術與特效：`01a100b6-d238-7a52-adef-0497a4ed4f66`。
- 本輪結束後各 session 待命，後續由美術總監依使用者的新定案派工。

## 暫存驗證資料

- 總監副本／腳本／log：`C:/Users/LeeDong/AppData/Local/Temp/fgj_prototype_art_director_qa/`，含 kitkay 初步 manifest；這些不在 Git 中，不能作為唯一交接來源。
- 總監其他 GPU 圖：`C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-5594-79b3-b9ec-39574beee96d/`。主場景預覽已另存 docs，VFX QA 圖已保存 scenes/vfx/qa。
- 所有驗證在獨立副本進行；來源模型與使用者的 Godot 程序保留。環境憑證與副本貼圖 UID 快取訊息未阻止驗證，細節見整合文件。
- Git read 若遇工作目錄擁有者檢查，使用單次 `git -c safe.directory=C:/UnityProject/FGJ2026_E status --short`；沒有改動全域 Git 設定。
