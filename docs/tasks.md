# 任務清單

格式：一個任務佔一行，`- [ ] 編號 任務內容 @負責人`。開始做時標上負責人，完成後打勾。
新任務加到對應區塊的最後面，不要重新排序，以減少 merge conflict。

編號規則：
- 編號是「區塊代號-兩位數流水號」，例如 `GM-03`。新任務取該區塊目前最大的號碼 +1。
- 編號給出後就不再更動；任務刪除或取消，編號也不再使用。
- 區塊代號：`DES` 設計、`SET` 專案設定、`MIC` 麥克風輸入、`GM` 遊戲機制、`UI` UI 程式、`NET` 區網連線、`ART` 美術與關卡、`SND` 音效與 UI 素材、`EX` 有時間再做。

2026-10-03：使用者要求本輪先收尾，停止新增製作／配置，待辦保留；接續狀態見 `docs/prototype_art_handoff.md`。尚未完整驗收，未 commit／push。

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
- [x] MIC-01 玩家 A 麥克風音量輸入：取樣音量、開局校正、輸出層級（高／中／低） @山雷
- [x] MIC-02 玩家 B 字音辨識：辨識「吸」「吐」並發出對應 signal @山雷
- [ ] MIC-03 雙麥克風裝置選擇與收音干擾處理 @山雷
- [ ] MIC-04 開局音量校正：提供 `MicInput.calibrate()` 給 UI-02 的「開始遊戲」呼叫，依校正結果設定音量區間（校正方式見 design.md 未定事項） @山雷
- [ ] MIC-05 輸入橋接：寫橋接腳本，音量換算成層呼叫 `dragon.set_target_lane()`（換算函式放在 `MicInput`，供 UI-05 畫門檻線共用），`inhale` 呼叫 `suck()`，`exhale` 開始與放開呼叫 `spit_pressed()`、`spit_released()`；放進 game.tscn 需請露柑處理 @山雷
- [ ] MIC-06 換層防抖：音量在層界線附近時不來回換層（例如遲滯），確定後更新 design.md 未定事項 @山雷
- [ ] MIC-07 用真人聲音實測，調整音量、音高、吸/吐的預設參數（尤其「吐」開頭爆音被誤判成吸） @山雷
- [x] MIC-08 修正 Windows 部分裝置的 WASAPI「unsupported channel count in microphone!」錯誤洪水：偵測麥克風沒有訊號時自動停止收音（只留一則警告），設定面板加「啟用麥克風」開關與「重新偵測」按鈕 @山雷
- [x] MIC-09 單機保底版：game.tscn 加入 `PitchLaneInput` 橋接，玩家 1 的音高（`MicInput.pitch_value`）平均切成層數段，低中高音對應 1／2／3 層；玩家 2 用鍵盤 J／K 吸／吐（語音吸吐在實測中無法正確傳遞，已放棄） @Samuel
- [x] MIC-10 單機保底版語音開關：game.tscn 左下角「音高」「吸／吐」兩個 toggle（`VoiceTogglePanel`，狀態存在 `MicInput.pitch_input_enabled`／`action_input_enabled` 並存檔）；新增 `VoiceActionInput` 語音吸吐橋接（與鍵盤 J／K 各自獨立）；音高音量閥值 `pitch_gate_db` 可存檔、預設改 -35 dB（遊戲畫面不放滑桿，需調整時從 Inspector 或 `user://mic_settings.cfg` 改） @Samuel

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
- [x] GM-15 遊戲流程：GameManager 加入遊戲狀態（等待開始／遊玩中／結束），開場擺好但靜止，`start_game()` 原地重置並開始（開始遊戲與重新遊玩共用），發出 `game_started`；鍵盤 Enter 開始；更新 api.md @露柑
- [ ] GM-16 game.tscn 接入原型美術：LaneLayout 改為產生 prototype_floor、隊伍與鍋子位置讀房間定位點、龍沿用展示倍率、改用 PrototypePresentation 鏡頭燈光（特效之後再接） @露柑

#### UI（GMF）
- [x] UI-01 建立 UI 根場景，依遊戲狀態（開始 / 遊玩中 / 結束）開關三個介面元件 @GMF
- [x] UI-02 製作遊戲開始介面：「開始遊戲」按鍵，按下時通知立即校正聲音並開始遊玩 @GMF
- [x] UI-03 製作遊玩狀態介面：每一層鍋子的禁止食材圖示（1～3 種）與鍋子進度（例如 3 / 5） @GMF
- [x] UI-04 遊玩狀態介面：顯示完成鍋數（例如 2 / 6）與清空次數（例如 1 / 3） @GMF
- [x] UI-05 遊玩狀態介面：玩家 A 音量條，標出各層門檻線 @GMF
- [x] UI-06 遊玩狀態介面：顯示玩家 B 最後辨識到的字音（「吸」或「吐」） @GMF
- [x] UI-07 製作遊戲結束介面：依成功 / 失敗與是否為最後一關，顯示「下一關」「關閉遊戲」或「重新遊玩」 @GMF
- [ ] UI-08 準備支援繁體中文的字型與 UI Theme
- [ ] UI-09 和遊戲機制、麥克風輸入確認 UI 需要的 signal 與資料（鍋子狀態、勝敗、音量、辨識結果）
- [ ] UI-10 請主場景負責人把 UI 根場景放進 main.tscn
- [x] UI-11 建立 UI 測試場景 `ui_test.tscn` 與測試控制中心：依階段切換介面、測試用倒數計時（時間到算失敗）、Ctrl+Shift+W／L 強制成功或失敗（可在 Inspector 開關） @GMF
- [x] UI-12 擴充 UI 測試快捷鍵：Ctrl+Shift+1／2 增加完成數或清空次數（達到上限跳出結束介面）、4／5／6 重新隨機上／中／下層禁止食材、↑／←／↓ 龍高度顯示、I／O 顯示吸／吐 @GMF
- [x] UI-13 UI 測試快捷鍵：按住 Ctrl+Shift+I 再按 3／4／5，上／中／下層鍋子增加一個原料，收集滿算完成一鍋並換新鍋子 @GMF

#### 區網連線（Samuel）
- [x] NET-01 建立 `autoload/network_manager.gd`（ENet 建立房間／加入、連線 signal）與 `scenes/lobby/lobby.tscn`（輸入 IP 加入、顯示本機 IP） @Samuel
- [x] NET-04 語音封包傳輸測試：Client 傳音量與「吸／吐」封包給 Host，兩邊畫面顯示收發狀態與錯誤（掉包、無回應、斷線） @Samuel
- [ ] NET-02 雙機同步骨架：MultiplayerSpawner／Synchronizer 同步龍的所在層，Server 權威，樓層產生用同一個 seed（等 GM-01、GM-02 完成）
- [ ] NET-03 雙機分工：Host 與 Client 各自負責移動／動作其中一項輸入（等 DES 決定操作方式）

### 美術與關卡

- [x] 將 Red_dragon.glb 放入主場景，設定展示比例、地面、燈光與攝影機 @Codex
- [x] 修正模型搬移後的紅龍場景引用，使用 Models/dungeon/Red_dragon.glb @Codex
- [x] 依參考圖在主場景排列左右各五個 Cube 平台，保留中央紅龍通道 @Codex
- [x] 更新紅龍搬至 Models/dragon 後的場景及貼圖引用，檢查主場景與素材載入 @Codex
- [x] 使用 Models/dungeon 素材建立參考圖風格的地牢房間，配置家具、燈光與攝影機 @Codex
- [x] 製作地下城與龍族撫育幼龍房的概念美術供確認 @Codex
- [x] ART-01 將 Red_dragon.glb 放入主場景，設定展示比例、地面、燈光與攝影機 @Codex
- [x] ART-02 修正模型搬移後的紅龍場景引用，使用 Models/dungeon/Red_dragon.glb @Codex
- [x] ART-03 依參考圖在主場景排列左右各五個 Cube 平台，保留中央紅龍通道 @Codex
- [x] ART-04 更新紅龍搬至 Models/dragon 後的場景及貼圖引用，檢查主場景與素材載入 @Codex
- [x] ART-05 使用 Models/dungeon 素材建立參考圖風格的地牢房間，配置家具、燈光與攝影機 @Codex
- [x] ART-06 製作地下城與龍族撫育幼龍房的概念美術供確認 @Codex
- [ ] 統籌 prototype 美術規格、子場景歸屬、文件維護與成果驗收，使用者確認後才提交 @美術總監
- [x] 依概念圖建立勇者挑戰房、幼龍哺育房外殼與可獨立隱藏的通用天花板，朝攝影機側開放 @場景美術
- [x] 建立三層垂直主場景與可供程式生成的樓層子場景，左挑戰房、右哺育房並保留鍋子 @場景美術
- [x] 設定紅龍全部既有動畫、循環與轉場，提供程式呼叫接口及文件 @動畫師
- [x] 換算 Blender 攝影機，完成 prototype 構圖、燈光與後處理子場景 @合成師
- [ ] 補齊幼龍、龍蛋、巢穴與稻草／軟墊素材，或確認 prototype 替代方式 @待使用者提供
- [ ] 確認概念圖中鐵門、鎖鏈、武器架與暖爐等缺件是否補齊或簡化 @美術總監
- [ ] 使用者提供核心素材後，匯入幼龍、龍蛋、巢穴及稻草／軟墊並完成哺育房陳設 @場景美術
- [ ] 確認玩法吸取與噴火的動畫對應、嘴部掛點及觸發時機 @美術總監
- [ ] 玩法串接前確認六種食材角色模型與動畫的素材需求 @美術總監
- [x] 盤點吸取與噴火的特效需求、嘴部掛載方式及可重用接口，供使用者定案 @技術美術與特效
- [x] 特效方向定案後製作吸取與噴火 shader／粒子子場景，提供程式接口與驗證結果 @技術美術與特效
- [x] 建立並驗證跟隨紅龍骨架的嘴部掛點，提供特效定位接口 @動畫師
- [x] 將吸取與噴火特效接口接入主場景，保留獨立展示與程式控制方式 @場景美術
- [x] 驗證 Models/dragonEggs 三種龍蛋的匯入、材質及比例，建立可重用龍蛋子場景並配置哺育房 @場景美術
- [x] 驗證 Models/dragonBabies 幼龍模型與貼圖，建立可重用幼龍子場景並配置三層哺育房 @場景美術
- [ ] 逐一盤點 Models/kitkayDungeon 模型的實際內容、材質、尺寸與動畫，分類並提出房間補件及人物用途建議 @場景美術
- [ ] 確認 kitkayDungeon 配置範圍與人物用途，定案後派工並驗證房間遮擋及通道 @美術總監
- [ ] 決定 kitkayDungeon 用於勇者挑戰房或幼龍哺育房；兩類房間須使用不同素材，定案前不配置這批地牢物件 @待使用者決定
- [ ] 確認人物模型位置與內容後先配置勇者挑戰房，驗證尺寸、材質與主鏡頭可見性 @場景美術

### 音效與 UI

## 有時間再做
