# 任務清單

格式：一個任務佔一行，`- [ ] 編號 任務內容 @負責人`。開始做時標上負責人，完成後打勾。
新任務加到對應區塊的最後面，不要重新排序，以減少 merge conflict。

編號規則：
- 編號是「區塊代號-兩位數流水號」，例如 `GM-03`。新任務取該區塊目前最大的號碼 +1。
- 編號給出後就不再更動；任務刪除或取消，編號也不再使用。
- 區塊代號：`DES` 設計、`SET` 專案設定、`MIC` 麥克風輸入、`GM` 遊戲機制、`UI` UI 程式、`ART` 美術與關卡、`SND` 音效與 UI 素材、`EX` 有時間再做。

## 必做

### 設計
- [ ] DES-01 決定遊戲概念與核心玩法，寫進 design.md
- [ ] DES-02 決定操作方式與勝敗條件，寫進 design.md
- [ ] DES-03 確定成員分工，並調整本文件的區塊

### 專案設定
- [x] SET-01 建立主場景並設為 main scene @Codex
- [ ] SET-02 在 Input Map 設定操作按鍵（等操作方式確定）
- [ ] SET-03 匯出 Windows 與 Web 版本測試效能，決定目標平台（Web 版可能要改用 Compatibility 渲染器）
- [x] SET-04 整理目前未提交改動，依功能分批 commit 並 push @Codex

### 程式

#### 麥克風輸入（山雷）

#### 遊戲機制（露柑）
- [x] GM-01 建立 `scenes/game/game.tscn` 與獨立的 LaneLayout 節點：依 `@export` 的層數與層距產生各層左右平台（實例化 cube_platform.tscn），提供 `get_lane_position(i)`、`get_lane_at(y)` @露柑
- [x] GM-02 建立 `scenes/dragon/dragon.tscn`（實例化紅龍模型）與控制腳本：`move_toward` 等速飛向目標層，速度用 `@export`，所在層改變時發出 signal @露柑
- [x] GM-03 鍵盤測試輸入：Input Map 加入 1／2／3 設定目標層 @露柑
- [x] GM-04 食材種類 enum（6 種）與暫時食材模型（不同顏色膠囊＋名稱 Label3D） @露柑
- [x] GM-05 資料類別 `LaneState`、`IngredientState`（RefCounted） @露柑
- [x] GM-06 GameManager 隊伍邏輯：開場排滿、每幀推進 x 並在前一個食材後停下、有空間時隨機產生，發出 `ingredient_spawned`、`ingredient_removed`；速度、間隔、上限、出生點、停止點用 `@export` @露柑
- [x] GM-07 IngredientsView：依 signal 建立或刪除食材模型，每幀依 x 與 LaneLayout 層高擺放 @露柑
- [x] GM-08 吸與吐：`suck(lane)`、`burn(lane)` 只作用在已到最前端的食材，沒有食材時發出吸空或吐空的 signal；鍵盤 J 吸、K 吐（鍋子完成前吸入的食材直接消失） @露柑
- [x] GM-09 `PotState` 資料類別：禁止清單、需求數量、目前數量、小龍是否到位，並隨機產生要求（禁止 1～3 種、需求 2～5 個） @露柑
- [x] GM-10 胃袋：`suck` 改為吞進胃袋（胃滿發出 `suck_missed`）；`burn` 改為 `spit`，胃有食材吐進鍋子、胃空噴火，小龍未到位時發出 `spit_missed` @露柑
- [x] GM-11 鍋子判定與勝敗：完成／踢翻、換小龍空窗（時間 `@export`）、累計完成鍋數與清空次數、`game_won`／`game_lost`（目標數 `@export`），遊戲結束後不再接受輸入 @露柑
- [x] GM-12 UI 接口：實作 `get_pot()`、`pot_changed`、`baby_left`、`baby_arrived`、`stomach_changed`、完成鍋數與清空次數的 signal、`game_won`、`game_lost`，並寫進 `docs/api.md` @露柑
- [x] GM-13 測試用暫時畫面：右平台暫時鍋子、Label3D 顯示禁止清單與進度、龍身上顯示胃袋食材 @露柑
- [x] GM-14 噴火改為按住累計：胃空時持續吐 1 秒（`@export`）才燒掉，進度存在食材上、中斷保留，食材上顯示進度條；接口改為 `spit_pressed()`／`spit_released()` 並更新 api.md @露柑

#### UI（GMF）
- [ ] UI-01 建立 UI 根場景，依遊戲狀態（開始 / 遊玩中 / 結束）開關三個介面元件 @GMF
- [ ] UI-02 製作遊戲開始介面：「開始遊戲」按鍵，按下時通知立即校正聲音並開始遊玩 @GMF
- [ ] UI-03 製作遊玩狀態介面：每一層鍋子的禁止食材圖示（1～3 種）與鍋子進度（例如 3 / 5） @GMF
- [ ] UI-04 遊玩狀態介面：顯示完成鍋數（例如 2 / 6）與清空次數（例如 1 / 3） @GMF
- [ ] UI-05 遊玩狀態介面：玩家 A 音量條，標出各層門檻線 @GMF
- [ ] UI-06 遊玩狀態介面：顯示玩家 B 最後辨識到的字音（「吸」或「吐」） @GMF
- [ ] UI-07 製作遊戲結束介面：依成功 / 失敗與是否為最後一關，顯示「下一關」「關閉遊戲」或「重新遊玩」 @GMF
- [ ] UI-08 準備支援繁體中文的字型與 UI Theme
- [ ] UI-09 和遊戲機制、麥克風輸入確認 UI 需要的 signal 與資料（鍋子狀態、勝敗、音量、辨識結果）
- [ ] UI-10 請主場景負責人把 UI 根場景放進 main.tscn

### 美術與關卡

- [x] ART-01 將 Red_dragon.glb 放入主場景，設定展示比例、地面、燈光與攝影機 @Codex
- [x] ART-02 修正模型搬移後的紅龍場景引用，使用 Models/dungeon/Red_dragon.glb @Codex
- [x] ART-03 依參考圖在主場景排列左右各五個 Cube 平台，保留中央紅龍通道 @Codex
- [x] ART-04 更新紅龍搬至 Models/dragon 後的場景及貼圖引用，檢查主場景與素材載入 @Codex
- [x] ART-05 使用 Models/dungeon 素材建立參考圖風格的地牢房間，配置家具、燈光與攝影機 @Codex
- [x] ART-06 製作地下城與龍族撫育幼龍房的概念美術供確認 @Codex

### 音效與 UI

## 有時間再做
