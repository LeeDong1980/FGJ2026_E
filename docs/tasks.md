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
- [ ] GM-01 建立 `scenes/game/game.tscn` 與獨立的 LaneLayout 節點：依 `@export` 的層數與層距產生各層左右平台（實例化 cube_platform.tscn），提供 `get_lane_position(i)`、`get_lane_at(z)` @露柑
- [ ] GM-02 建立 `scenes/dragon/dragon.tscn`（實例化紅龍模型）與控制腳本：`move_toward` 等速飛向目標層，速度用 `@export`，所在層改變時發出 signal @露柑
- [ ] GM-03 鍵盤測試輸入：Input Map 加入 1／2／3 設定目標層 @露柑

#### UI（GMF）

### 美術與關卡

- [x] ART-01 將 Red_dragon.glb 放入主場景，設定展示比例、地面、燈光與攝影機 @Codex
- [x] ART-02 修正模型搬移後的紅龍場景引用，使用 Models/dungeon/Red_dragon.glb @Codex
- [x] ART-03 依參考圖在主場景排列左右各五個 Cube 平台，保留中央紅龍通道 @Codex
- [x] ART-04 更新紅龍搬至 Models/dragon 後的場景及貼圖引用，檢查主場景與素材載入 @Codex
- [x] ART-05 使用 Models/dungeon 素材建立參考圖風格的地牢房間，配置家具、燈光與攝影機 @Codex
- [x] ART-06 製作地下城與龍族撫育幼龍房的概念美術供確認 @Codex

### 音效與 UI

## 有時間再做
