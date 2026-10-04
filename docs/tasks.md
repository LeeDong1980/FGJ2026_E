# 任務清單

格式：一個任務佔一行，`- [ ] 編號 任務內容 @負責人`。開始做時標上負責人，完成後打勾。
新任務加到對應區塊的最後面，不要重新排序，以減少 merge conflict。

編號規則：
- 編號是「區塊代號-兩位數流水號」，例如 `GM-03`。新任務取該區塊目前最大的號碼 +1。
- 編號給出後就不再更動；任務刪除或取消，編號也不再使用。
- 區塊代號：`DES` 設計、`SET` 專案設定、`MIC` 麥克風輸入、`GM` 遊戲機制、`UI` UI 程式、`NET` 區網連線、`ART` 美術與關卡、`SND` 音效與 UI 素材、`EX` 有時間再做。

2026-10-03：首版收尾後使用者已確認七項成果；素材／場景／特效已由團隊提交至 718d62b、2497e5d、bec1096。ART-07／ART-08 特效加寬已於 2026-10-03 獲使用者驗收，授權提交並建立 PR；ART-09／ART-10 已撤回，素材分配與缺件待辦保留。

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
- [ ] MIC-11 手機網頁麥克風：兩位玩家各用一支 Android 手機開網頁收音，網頁端用 JS 算好數值，透過 WebSocket 傳給 Godot；用 Cloudflare Tunnel 提供 HTTPS（現場 Wi-Fi 有用戶端隔離）；`PhoneMic` autoload，`PitchLaneInput`／`VoiceActionInput` 手機有連上就讀手機（玩家 1 音高、玩家 2 吸吐） @露柑
- [ ] MIC-12 手機麥克風真機遊玩測試：兩支 Android 手機實際玩遊戲場景（scenes/game/main.tscn），確認音高換層與語音吸吐的手感，必要時調整預設參數
- [ ] MIC-13 手機連線流程：Godot 自動啟動 cloudflared（exe 隨遊戲附帶）並讀出網址，在主選單或等候頁顯示 QR code；網址加隨機房間碼，只接受碼正確的連線（等主選單拆出 main_menu.tscn）
- [ ] MIC-14 匯出設定：匯出篩選加入 `*.html`，否則匯出版讀不到手機網頁
- [ ] MIC-15 UI 的音量條與吸吐顯示（`ui_game_bridge.gd`）目前只讀 MicInput，改成手機有連上時讀 `PhoneMic`（GMF 負責的檔案，需協調）

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
- [x] GM-16 game.tscn 接入原型美術：LaneLayout 改為產生 prototype_floor、隊伍與鍋子位置讀房間定位點、龍沿用展示倍率、改用 PrototypePresentation 鏡頭燈光（特效之後再接） @露柑
- [x] GM-17 game.tscn 接入吸取與噴火特效：`EffectsView` 依 GameManager 事件播放，吞下或吸空時吸取、胃空喊「吐」期間持續噴火，目標為所在層隊伍最前端；吐進鍋子暫無特效 @露柑
- [ ] GM-18 ART-14 特效交付後，將 ingredient_spat 事件接至吐食材接口，使用當層 PotAnchor、食材外觀與清場事件；維持立即入鍋判定 @露柑
- [ ] GM-19 ART-17 比例定案後，將左側食材角色顯示高度調至房間高度的 1/2～2/3，配合隊伍間隔、標籤及噴火目標高度，維持腳底落地 @露柑
- [x] GM-18 隊伍節奏：開場排滿後，有空位時每層各自等生成間隔（`@export`，預設 3 秒）才補一個；移動速度改由「走過來的時間」（出生點到最前端秒數，預設 4 秒）換算 @露柑
- [x] GM-19 食材攻擊：每層最前端食材蓄力（每次隨機 10～20 秒），蓄滿攻擊龍（任何層都打得到），攻擊後重新蓄力；龍暈眩 1.5 秒（不能換層、吸、吐、噴火），醒來後無敵 2 秒，暈眩或無敵時攻擊打空；新增 signal 並更新 api.md @露柑
- [x] GM-20 攻擊測試畫面：食材上顯示蓄力條；main.tscn 的 `StunBanner` 在螢幕上方（上方資訊列下面）顯示暈眩／無敵倒數，暈眩時文字晃動、被打中時放大彈出 @露柑
- [x] GM-21 難度：開場每層 1 個食材、上限改 6 個；生成間隔隨完成鍋數變短（8 秒起每鍋 -1 秒，最短 3 秒，`@export`），蓄力與走路時間不變 @露柑
- [x] GM-22 轉頭：龍頭分左（食材）右（鍋子），玩家 B 大叫（音量 > 50%，`ShoutTurnInput`）或按 L 切換，門檻在麥克風設定面板調整並存檔；面向左才能吸、噴火，面向右才能吐進鍋子；暈眩不能轉頭；畫面下方 `FacingIndicator` 框框顯示目前朝向（模型暫不轉）；連線局 Client 用字音 `turn` 傳給 Host；更新 design.md、api.md @露柑
- [ ] GM-23 轉頭動畫：龍的模型依 `game_manager.facing`（`facing_changed`）轉向左／右，完成後可移除或保留 `FacingIndicator` 框框
- [x] GM-24 煮鍋子：鍋子加滿後不直接完成，面向右、胃空時對鍋子持續噴火累計 1 秒（`cook_time`，中斷保留進度）才完成；滿鍋時再吐食材沒有效果；噴火特效改朝鍋子；PotsDebugView 顯示煮的進度；更新 design.md、api.md @露柑
- [x] GM-25 無效指令提示：吸／吐沒有效果時不播特效（吸空不吸、空層不噴火），`action_missed(lane, reason)` 附原因，main.tscn 的 `ActionHintBanner` 在上方顯示原因後淡出；更新 design.md、api.md @露柑
- [x] GM-26 火與冰：玩家 1 大叫（`ShoutElementInput`，原大叫轉頭改用）或按 4 切換火／冰；轉頭改成只有玩家 2 按 L；冰凍住最前端食材 1 秒並歸零攻擊蓄力；鍋子食譜隨機要火或冰，用錯元素煮會倒退進度並提示；FacingIndicator 顯示元素；鍋子底下 `PotElementView` 發光圈顯示食譜（橘火、藍冰）；連線局依座位傳 `turn`／`element` 字音；更新 design.md、api.md、voice-input.md @露柑
- [x] GM-27 冰的專用特效：新增 `scenes/vfx/ice_breath_effect.tscn`（沿用噴火的 shader，冰藍配色、冰晶與白霧），`DragonEffects.play_ice()`（冰息子場景在腳本建立，不改 dragon_effects.tscn）；flame_core／flow_surface shader 加顏色參數，預設值維持原本火焰顏色；EffectsView 依元素播火或冰 @露柑
- [x] GM-28 食材正式模型接入遊戲：IngredientModel 依種類換成 ART-20 的人類／史萊姆／蝙蝠角色子場景（精靈、矮人、獸人仍為膠囊），斜 60 度面向龍；走路播 Walk、停下播 Idle、攻擊播 Atk；凍住時動畫停住並蓋冰藍色；史萊姆 0.65 倍、蝙蝠 1.8 倍配合隊伍間隔（比例定案後再調） @露柑
- [x] GM-29 通關改成完成 3 鍋；新增分數：每鍋 100 分，距上一鍋完成（或開局）60 秒內完成再加 50 分（全場一個計時），`score_changed` signal，main.tscn 的 `ScoreBanner` 在右上角顯示分數、快速加分倒數與加分提示；更新 design.md、api.md @露柑
- [x] GM-30 轉頭與換元素對調：玩家 1 大叫或按 4 轉頭（`ShoutTurnInput`），玩家 2 按 L 換元素；連線局字音依座位對調；更新 design.md、api.md、voice-input.md @露柑
- [x] GM-31 食材放大：IngredientModel `body_scale` 2 倍（膠囊與角色模型，名稱與進度條跟著上移、字不放大），隊伍間隔 0.6→1.2，噴吐瞄準高度 0.4→0.8；排滿 6 個仍在出生點內 @露柑
- [x] GM-32 矮人、獸人模型接入遊戲：IngredientModel 的 CHARACTER_SCENES 加入 ART-20 的 `dwarf_character`／`orc_character`（兩者都沒有動畫，只顯示靜態模型，凍住時同樣蓋冰藍色）；沒有動畫的角色不再跳「找不到 AnimationPlayer」警告 @露柑
- [x] GM-33 精靈模型接入遊戲：IngredientModel 的 CHARACTER_SCENES 加入 `elf_character.tscn`（弓箭掛在手上，走路／待機／攻擊動畫），修正精靈原本在遊戲中完全看不到（膠囊預設隱藏） @露柑
- [x] GM-34 食材再放大：IngredientModel `body_scale` 2→2.4，隊伍間隔 1.2→1.4（排滿 6 個仍在出生點內），噴吐瞄準高度 0.8→1.0 @露柑

#### UI（GMF）
- [x] UI-01 建立 UI 根場景，依遊戲狀態（開始 / 遊玩中 / 結束）開關三個介面元件 @GMF
- [x] UI-02 製作遊戲開始介面：「開始遊戲」按鍵，按下時通知立即校正聲音並開始遊玩 @GMF
- [x] UI-03 製作遊玩狀態介面：每一層鍋子的禁止食材圖示（1～3 種）與鍋子進度（例如 3 / 5） @GMF
- [x] UI-04 遊玩狀態介面：顯示完成鍋數（例如 2 / 6）與清空次數（例如 1 / 3） @GMF
- [x] UI-05 遊玩狀態介面：玩家 A 音量條，標出各層門檻線 @GMF
- [x] UI-06 遊玩狀態介面：顯示玩家 B 最後辨識到的字音（「吸」或「吐」） @GMF
- [x] UI-07 製作遊戲結束介面：依成功 / 失敗與是否為最後一關，顯示「下一關」「關閉遊戲」或「重新遊玩」 @GMF
- [x] UI-08 準備支援繁體中文的字型與 UI Theme：`scenes/ui/ui_theme.tres`（Changa 粗體＋系統中文粗體、文字描邊、金框按鍵） @GMF
- [x] UI-09 和遊戲機制、麥克風輸入確認 UI 需要的 signal 與資料（鍋子狀態、勝敗、音量、辨識結果） @GMF
- [ ] UI-10 請主場景負責人把 UI 根場景放進 main.tscn
- [x] UI-11 建立 UI 測試場景 `ui_test.tscn` 與測試控制中心：依階段切換介面、測試用倒數計時（時間到算失敗）、Ctrl+Shift+W／L 強制成功或失敗（可在 Inspector 開關） @GMF
- [x] UI-12 擴充 UI 測試快捷鍵：Ctrl+Shift+1／2 增加完成數或清空次數（達到上限跳出結束介面）、4／5／6 重新隨機上／中／下層禁止食材、↑／←／↓ 龍高度顯示、I／O 顯示吸／吐 @GMF
- [x] UI-13 UI 測試快捷鍵：按住 Ctrl+Shift+I 再按 3／4／5，上／中／下層鍋子增加一個原料，收集滿算完成一鍋並換新鍋子 @GMF
- [x] UI-14 主選單拆出遊戲場景：StartScreen 搬出 UIRoot 成為獨立的 `scenes/main_menu/main_menu.tscn`（進入遊戲／離開，呼叫 `RoomManager`，取代暫用主選單 temp_menu）；遊戲場景載入後自動開始並校正（連線局由 NetworkGameBridge 開局） @露柑
- [x] UI-15 ResultScreen 不再 `quit()`：最後一關成功改顯示「回主選單」，UIRoot 發 `back_requested`，由 UIGameBridge 呼叫 `RoomManager.return_to_menu()` @露柑
- [x] UI-16 專案主場景改成主選單 main_menu.tscn；遊戲場景 game.tscn 改名為 `scenes/game/main.tscn`（根節點 Main），原美術展示 `scenes/main/main.tscn` 改名為 `art_prev.tscn`（根節點 ArtPrev，F6 預覽） @露柑
- [ ] UI-17 連線局結束改用正式的 ResultScreen（目前是 NetworkGameBridge 的臨時「回到房間」畫面，需與 Samuel 協調）
- [x] UI-18 修正 PotInfo 換小龍後面板永久變寬：`set_forbidden()` 舊圖示先移出再釋放（同一幀 `pot_changed`＋`baby_arrived` 呼叫兩次時會疊在一起），並在更新後 `reset_size()` 縮回 @露柑
- [x] UI-33 （原 UI-18，與 PotInfo 修正的 UI-18 重號而改號）UI 對接遊戲機制：`UIGameBridge`（`scenes/ui/game_ui.tscn`）依 docs/api.md 接上完成鍋數、清空次數、各層鍋子、龍所在層、音量、吸吐、開始／結束／重新遊玩 @GMF
- [x] UI-19 把 `scenes/ui/game_ui.tscn` 實例化進 game.tscn（GameManager 的子節點 `GameUI`），（之後 UI-14 已把開始介面改成獨立主選單，game.tscn 也改名為 scenes/game/main.tscn）。經使用者同意由 GMF 直接修改，已通知露柑：GM-16 改 game.tscn 時請保留 `GameUI` 節點 @GMF
- [ ] UI-20 遊玩狀態介面顯示胃袋裡的食材（`stomach_changed`）與換小龍中的狀態（`PotState.has_baby`），設計確定後再做
- [x] UI-21 依 Logo 風格製作暫時美術：開始介面（現為主選單）改用 Logo 當背景；遊戲結束背景（Logo 加工）、資訊面板（九宮格石板火焰框）、龍洞穴 2D 背景（`scenes/backdrop/`，已換成正式美術 FGJ2026TeamE_GameSceneBG），並寫生圖提示詞 `docs/ui_art_prompts.md` @GMF
- [ ] UI-22 用 `docs/ui_art_prompts.md` 生成遊戲結束背景的正式美術，覆蓋 `result_background.png`（龍洞穴背景已完成；資訊面板改用 UI 素材包，不再需要）
- [x] UI-23 介面改版：遊玩狀態介面、鍋子資訊、音量條、禁止圖示、遊戲結束介面改用 UI 素材包 `scenes/ui/UI/`（石框、金框按鍵、圖示、VICTORY／DEFEAT 橫幅），說明見 design.md 6.9；修正龍洞穴背景在新鏡頭下擋住 3D 場景 @GMF
- [x] UI-24 請露柑讓主選單 `main_menu.tscn` 套用 `scenes/ui/ui_theme.tres` 與相同的石框卡片、金框按鍵（設計見 design.md 6.9）（經使用者同意由 GMF 直接修改，見 UI-27） @GMF
- [x] UI-25 真正遊戲裡的 Ctrl+Shift 測試快捷鍵：`scenes/ui/game_debug_hotkeys.gd`（`game_ui.tscn` 的 DebugHotkeys 節點），按鍵同 ui_test；只在除錯版本、單機局、遊玩中有效 @GMF
- [ ] UI-26 請露柑在 GameManager 提供測試用接口（設定完成鍋數／清空次數、強制勝敗、換某層禁止清單），讓 UI-25 不必直接改 GameManager 的資料
- [x] UI-27 主選單：玩家 A 說明改為「對麥克風發聲，音量大小決定龍的高度」；新增「遊玩方式」「雙人合作」說明卡；套用 ui_theme 與石框卡片、金框按鍵。主選單是露柑的場景，經使用者同意由 GMF 直接修改，節點名稱與腳本接口不變 @GMF
- [x] UI-28 修正龍洞穴背景遮住龍模型：背景改用深度一律寫成最遠的著色器（`cave_backdrop.gdshader`），所有 3D 物件都畫在背景前面 @GMF
- [ ] UI-29 鍋子資訊顯示「已收滿，對鍋子吐火」的提示（煮鍋子已由 GM-24 實作，確認 GameManager 提供的狀態與 signal 後再做）
- [x] UI-30 連線等候頁改版：`lobby_theme.tres` 改用 UI 素材包（一般按鍵木框、主要按鍵金框、座位灰／橘金石框、輸入框石條、Changa＋中文字型與描邊）；`room_lobby.tscn` 卡片改石框並加寬、`player_input_panels.tscn` 面板改石框。場景與主題是 Samuel 的，經使用者同意由 GMF 直接修改，節點與腳本接口不變 @GMF
- [x] UI-31 Esc 暫停選單改版：`pause_menu.tscn` 外層加金角石框與「遊戲暫停」木製橫幅、背景加深，麥克風設定面板套用新的小字主題 `scenes/ui/panel_theme.tres`（mic_settings_panel.tscn 本身沒改）。場景是山雷的，經使用者同意由 GMF 直接修改，節點與腳本接口不變 @GMF
- [x] UI-32 連線等候頁隱藏玩家音高／吸吐側邊面板（`room_lobby.tscn` 的 PlayerPanels 設為不顯示，腳本照常運作）；九宮格面板與按鍵的最小高度不小於圖片上下邊框，延展時邊角不變形；主選單與 design.md 改為「音高控制高度（高音飛高、低音飛低）」；遊戲背景換成新版圖 FGJ2026TeamE_GameBg2 @GMF
- [x] UI-36 關閉遊戲畫面上的測試用元件：`game_ui.tscn` 的 DebugHotkeys 關閉（Hotkeys Enabled、Show Indicator 取消勾選）；`main.tscn` 左下角語音開關面板 VoiceTogglePanel 設為不顯示（開關狀態仍照 MicInput 存檔生效）。main.tscn 是露柑的場景，經使用者同意由 GMF 直接修改 @GMF
- [ ] UI-34 （原 GM 區塊的 UI-19，與既有 UI-19 重號而改號）遊戲結束介面（ResultScreen）顯示最終分數（`game_manager.score`）
- [ ] UI-35 主選單「雙人合作」卡寫「完成 6 鍋料理就成功」，與 GM-29 的通關 3 鍋不一致，需改成 3 鍋（main_menu.tscn 與 design.md 6.4 一起改）

#### 區網連線（Samuel）
- [x] NET-01 建立 `autoload/network_manager.gd`（ENet 建立房間／加入、連線 signal）與 `scenes/lobby/lobby.tscn`（輸入 IP 加入、顯示本機 IP） @Samuel
- [x] NET-04 語音封包傳輸測試：Client 傳音量與「吸／吐」封包給 Host，兩邊畫面顯示收發狀態與錯誤（掉包、無回應、斷線） @Samuel
- [ ] NET-02 雙機同步骨架：MultiplayerSpawner／Synchronizer 同步龍的所在層，Server 權威，樓層產生用同一個 seed（等 GM-01、GM-02 完成）
- [ ] NET-03 雙機分工：Host 與 Client 各自負責移動／動作其中一項輸入（等 DES 決定操作方式）
- [x] NET-10 `NetworkManager` 房間擴充：加入逾時 20 秒、拒絕原因（房間已滿／對方遊戲中）、房主關房通知、開始／結束連線局 RPC、Client 吸吐「開始／結束」封包 @Samuel（編號原為 NET-05～09，與手機備案撞號，改為 NET-10～14，之前的 commit 訊息仍是舊編號）
- [x] NET-11 新增 autoload `RoomManager`（`autoload/room_manager.gd`）：依 docs/lobby-flow.md 實作房間狀態機與換場景（單機、加入、開始、斷線、離開） @Samuel
- [x] NET-12 新增 `scenes/lobby/room_lobby.tscn`（Host／Client 共用等候頁，獨立可 F6 測試）與暫用主選單 `temp_menu.tscn` @Samuel
- [x] NET-13 新增 `NetworkGameBridge` 串接 game.tscn：依 `RoomManager` 模式切換輸入、直接開局、遊戲結束回房間（game.tscn 加節點需 @露柑 同意） @Samuel
- [x] NET-14 新增 `scenes/game/client_play.tscn`：Client 遊玩畫面，只顯示麥克風狀態並傳送吸／吐封包 @Samuel
- [ ] NET-15 連線局暫停：Host 按 Esc 只凍結 Host 的遊戲並通知 Client（畫面顯示「房主已暫停」，暫停中 Client 的吸／吐不生效，繼續後接上）；Client 的 Esc 只疊出設定選單、不凍結，可繼續回報吸／吐；等候頁與連線中也不凍結；換場景前一律解除暫停（改動 `pause_menu.gd` 需告知 @山雷） @Samuel
- [x] NET-16 連線局結束時，Client 也顯示成功／失敗並等房主回到房間（由 NET-19 的畫面同步一併完成，`ClientViewBridge`） @Samuel
- [x] NET-17 單機局結束後回主選單：結果畫面改為「回主選單」，呼叫 `RoomManager.return_to_menu()`（隨 UI-14、UI-15 完成） @露柑
- [x] NET-18 房間等候頁介面優化：沿用主選單視覺（logo 背景、深色卡片、橘色按鈕，主題 `lobby_theme.tres`）；顯示玩家 1／2 欄位；左下玩家 1 音高條、右下玩家 2 吸／吐（沿用遊玩介面樣式），讓兩位玩家進遊戲前先測試；Host 的音高經 `send_lobby_pitch` 同步給 Client；吸／吐本機輸入抽成 `PlayerActionInput`（client_play 共用） @Samuel
- [x] NET-19 Client 畫面同步顯示遊戲：連線局 Client 載入同一個遊戲場景，GameManager 為副本，由 Host 的事件、快照與完整狀態填入，畫面元件不用改（做法見 docs/lobby-flow.md「畫面同步」）。已完成四階段：①龍、計數、勝敗 ②鍋子、小龍、胃袋、噴吐狀態 ③食材與特效事件 ④HUD 音高、掉包與斷線測試 @Samuel
- [x] NET-20 等候頁自選座位：點選「玩家 1」「玩家 2」切換角色（不需對方同意、不需準備）；`RoomManager.host_slot`；音高與吸／吐改為雙向傳輸；`NetworkGameBridge` 與 `client_play` 依座位切換（Client 可坐玩家 1 以音高換層）；遊玩 HUD 的音高條改讀音高並可讀對方傳來的音高；介面「玩家 A／B」統一改為「玩家 1／2」 @Samuel
- [x] NET-21 遠端連線中繼伺服器：`relay_server/`（Cloudflare Worker + Durable Object，WebSocket 轉送，房間代碼配對），部署到 workers.dev，附 `/health`、`/echo`；已部署 `https://fgj2026-relay.fgj2026-relay.workers.dev`，本機與雲端都用 headless 雙程序測試通過 @Samuel
- [x] NET-22 Godot 端中繼連線：`scenes/relay/relay_multiplayer_peer.gd`（`MultiplayerPeerExtension`，兩端都只做出站 wss），`NetworkManager` 支援公開房間與用代碼加入，F6 測試場景 `scenes/relay/relay_test.tscn` @Samuel
- [x] NET-23 等候頁「公開房間」按鈕、房間代碼顯示與複製、用代碼加入（`RoomManager.publish_room()`／`unpublish_room()`）；更新 docs/lobby-flow.md；2026-10-04 兩台電腦用輸出版實測，透過房間代碼連線並完成遊玩 @Samuel
- [x] NET-24 連線診斷（HTTPS、WebSocket 握手、echo 來回時間，失敗時顯示白話原因）；兩台電腦實機測試通過（家用、手機熱點、學校網路等其他網路環境有機會再測）@Samuel
- [ ] NET-25 降低遠端連線延遲（2026-10-04 實測遊玩延遲可接受，暫不處理）：workers.dev 被導到美國，台灣玩家對玩家來回約 290 ms；原因是 workers.dev 子網域的 IP 區段（104.21／172.67）在台灣走美國；同一個 Worker 走台北區段實測約 110 ms。選項：自有網域加 Pro、cloudflared Quick Tunnel 加 Worker 當目錄、WebRTC（Cloudflare STUN／TURN）。見 docs/relay.md @Samuel

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
- [x] 逐一盤點 Models/kitkayDungeon 模型的實際內容、材質、尺寸與動畫，分類並提出房間補件及人物用途建議 @場景美術
- [ ] 確認 kitkayDungeon 配置範圍與人物用途，定案後派工並驗證房間遮擋及通道 @美術總監
- [ ] 決定 kitkayDungeon 用於勇者挑戰房或幼龍哺育房；兩類房間須使用不同素材，定案前不配置這批地牢物件 @待使用者決定
- [ ] 確認人物模型位置與內容後先配置勇者挑戰房，驗證尺寸、材質與主鏡頭可見性 @場景美術
- [x] ART-07 [緊急] 加寬吸取／噴火，提供分別可調整的世界寬度參數、上下界及執行時接口，完成展示與設定文件（使用者已驗收，授權提交 PR） @技術美術與特效
- [x] ART-08 驗證加寬特效的最小／預設／最大表現、即時調整、停止清場與三層遮擋，統整設定方式供使用者驗收（使用者已驗收，授權提交 PR） @美術總監
- [x] ART-09 [緊急] game.tscn 按 1／2／3 換層後紅龍模型不對齊目標（使用者表示已解決並撤回修正；本輪未改動畫，診斷資料保留供參考） @動畫師
- [x] ART-10 統整兩項緊急任務進度與確認方式（使用者撤回 ART-09，沒有本輪動畫修正須交叉回歸；特效檢查已完成於 ART-08） @美術總監
- [ ] ART-11 套用紅龍龍頭左右轉動動畫，評估 Godot AnimationTree 的加法動畫混合（additive）與骨骼過濾可行性，確認既有動畫及嘴部掛點的相容方式 @動畫師
- [ ] ART-12 為中央紅龍所在區域配置洞穴背景；使用者計畫提供洞穴模型，先確認所需尺寸、開口與掛載位置，模型到位後配置 @場景美術
- [ ] ART-13 左右樓層拼接完成後對齊 Camera3D 的可見畫面邊界，確認拼接範圍與攝影機構圖的配合方式 @合成師
- [ ] ART-14 製作吐出食材／進鍋特效，與胃袋空時的噴火特效分開；吐出內容、軌跡、目標及觸發時機待確認 @技術美術與特效
- [ ] ART-15 左側房間延伸至畫面左邊界、右側房間延伸至畫面右邊界，整體採左右通道加中央紅龍巢穴的布局概念；與 ART-12／ART-13 一起定案 @場景美術
- [ ] ART-16 製作或套用幼龍走動與待機（idle）動畫，先盤點現有模型的骨架與動畫；缺少時回報所需素材，不擅自替代 @動畫師
- [ ] ART-17 放大左右出現的角色，使角色可見高度約佔目前房間高度的 1/2～2/3；房間幼龍由場景美術調整，左側角色交付程式負責人串接規格 @場景美術
- [ ] ART-18 增加噴火特效發射的粒子數量，調整畫面密度並檢查遮擋及效能 @技術美術與特效
- [ ] ART-19 評估以單一 0～1 參數控制左右擺頭動畫，確認左右端點、中立值及與 ART-11 的動畫混合接口 @動畫師
- [x] ART-20 匯入人類（hero.glb）、史萊姆、蝙蝠三種食材模型，建立 `human_character`／`slime_character`／`bat_character` 子場景與共用腳本 `ingredient_character.gd`，設定動畫循環與播放接口，並提供 `ingredient_preview.tscn` 展示；蝙蝠改用 bat.glb，`fly` 為整段飛行、`attack` 擷取自 Armature.006 第 76～105 格（`scenes/ingredient/build_bat_animations.gd` 產生 `Models/bat/bat_animations.tres`）；待使用者驗收，尺寸與朝向待確認，GM 串接另行處理 @素材整合
- [x] ART-21 勇者挑戰房往左加長到超出畫面左緣（實作 ART-15 的左側延伸，整體布局待場景美術與 ART-12／ART-13 一起定案）：`hero_challenge_room.tscn` 複製地板、背牆模組到 x = -16（新增 3 段 4 單位），地基與上方飾帶加長，左端外牆、柱子、飾帶移到新左端，加 2 支壁掛火把；隊伍定位點不變。房間是場景美術的場景，經使用者同意由 GMF 直接修改 @GMF
- [x] ART-22 幼龍哺育房往右加長到超出畫面右緣（實作 ART-15 的右側延伸，做法同 ART-21）：`dragon_nursery_room.tscn` 複製地板、背牆模組到 x = 16（新增 3 段 4 單位），地基與上方飾帶加長，右端外牆（前後兩段）、柱子、飾帶移到新右端，加 2 支壁掛火把；鍋子、小龍、龍蛋等定位點不變。房間是場景美術的場景，經使用者同意由 GMF 直接修改 @GMF

2026-10-04：使用者再次授權接續 ART-11～ART-19，上輪因用量中斷，已重新派工。擺頭映射確認為 0＝左、0.5＝前、1＝右，先交接口與展示，玩法自動轉頭另接。吐出軌跡、角色比例與接邊基準討論中；洞穴模型及幼龍動畫素材待提供。本輪成果待使用者驗收後才 commit／push。

### 音效與 UI
- [x] SND-01 音量設定：新增 `default_bus_layout.tres`（Master、Music、SFX，Music／SFX 送到 Master）與 autoload `AudioSettings`（`autoload/audio_settings.gd`，0～1 音量、存 `user://audio_settings.cfg`）；共用面板 `scenes/pause_menu/audio_settings_panel.tscn` 放進暫停選單（麥克風設定下方）與主選單（「音量」按鈕開視窗）；之後加音樂、音效的 AudioStreamPlayer 要把 bus 設成 `Music`／`SFX`。改動 `pause_menu.tscn` 需告知 @山雷 @露柑
- [x] SND-02 套用音樂與音效：autoload `Sound`（`autoload/sound.gd`）循環播放 `SFX/BGM.mp3`（全程同一首，換場景、暫停不中斷）；所有按鈕自動加滑過與按下音效（依節點名稱分確認／取消／點擊，可用 metadata `ui_sound` 指定）；暫停選單與主選單音量視窗開關音效；main.tscn 新增 `GameSounds` 播遊戲事件音效（開局、完成一鍋、打翻、無效指令、轉頭、換元素、快速加分、勝敗） @露柑
- [ ] SND-03 遊戲動作專用音效（吸、噴火、冰息、吐進鍋子、食材攻擊、龍暈眩）：目前音效庫只有 UI 音效，需要素材
- [ ] SND-04 `SFX/` 的音效與 BGM 來源與授權補進 docs/asset_credits.md

## 有時間再做
