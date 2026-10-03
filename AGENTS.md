# FGJ2026E_Game

Game Jam 3D 遊戲專案（玩法與已定案美術規格見 docs/design.md）。多人協作，進度透過 git 同步。

## 環境
- Godot 4.7，Forward Plus 渲染器，3D 物理用 Jolt
- 執行：用 Godot 編輯器開啟 `project.godot`，按 F5 執行主場景，按 F6 執行目前開啟的場景。

## 資料夾結構
- `scenes/main/`：主場景。
- `scenes/dungeon_room/`：地牢房間，包含 dungeon 模型實例、材質、碰撞、燈光與攝影機。
- `scenes/game/`：遊戲場景，含 GameManager（遊戲狀態）、樓層產生（LaneLayout）、食材畫面與鍵盤測試輸入。
- `scenes/dragon/`：可操控的龍（移動腳本＋紅龍模型）。
- `scenes/ingredient/`：食材種類、食材資料與暫時食材模型。
- `scenes/red_dragon/`：紅龍模型子場景。
- `scenes/platforms/`：Cube 平台、左右排列子場景與棋盤格材質。
- `scenes/lobby/`：區網連線大廳（建立房間／輸入 IP 加入）。
- `scenes/network_test/`：雙機語音封包傳輸測試場景（內含大廳）。
- `autoload/`：全域單例，目前有 `network_manager.gd`（ENet 連線與語音封包收發，autoload 名稱 `NetworkManager`）。 `mic_controller.gd` 是麥克風輸入控制器（autoload 名稱 `MicInput`，音量、音高、吸/吐三種輸出，設定存在 `user://mic_settings.cfg`）。
- `scenes/pause_menu/`：暫停選單（autoload `PauseMenu`，Esc 開關）、麥克風設定面板 `mic_settings_panel.tscn`、可拖曳區間的觀察條 `range_meter.gd`。
- `scenes/mic_test/`：麥克風輸入實驗場景，只實例化設定面板，F6 單獨執行用。
- `scenes/rooms/`：prototype 勇者挑戰房、幼龍哺育房、通用天花板與垂直樓層子場景。
- `scenes/vfx/`：吸取、噴火的程序材質、粒子子場景、控制接口與獨立展示。
- `Models/`：模型與貼圖素材。
- `docs/`：設計、開發慣例與任務清單。

新資料夾依 docs/conventions.md 的規則建立，建好後更新這一節。

## 文件
- `docs/tasks.md`：任務清單。**每次開始任務前都要讀**。
- `docs/design.md`：玩法、操作、勝敗條件、範圍。實作遊戲功能前先讀。
- `docs/conventions.md`：命名、資料夾、場景歸屬規則。新增或修改檔案、場景前先讀。
- `docs/voice-input.md`：聲音輸入系統（`MicInput`）的使用方法與串接方式。接聲音輸入前先讀。
- `docs/web-mic.md`：手機網頁收音備案（經 Cloudflare Tunnel 連回電腦）的規劃。
- `docs/api.md`：遊戲機制對外的函式與 signal（給 UI 與麥克風輸入）。
- `docs/art_asset_needs.md`：prototype 缺素材表、派工進度與模組接口。美術總監在素材到位、交付及進度回報時更新。
- `docs/asset_credits.md`：第三方資源清單。記錄模型、素材的來源連結與授權。

## 工作規則
1. 開始任務前先讀 `docs/tasks.md`，在任務後面標上自己的負責人（`@名字`）。美術總監統籌分工、場景歸屬及進度。
2. 完成實作與驗證後打勾 `[x]`，向美術總監回報檔案路徑、成果、接口、驗證結果與缺件。使用者確認任務完成後，由美術總監統一安排 commit 與 push；認領與進度更新也遵循此流程。
3. 過程中發現新的待辦事項，就加到 `docs/tasks.md` 對應的區塊，一個任務佔一行。
4. 設計有變動就更新 `docs/design.md`。文件只寫已經確定的事。
5. 不要修改其他人負責的場景（.tscn），規則見 docs/conventions.md。
6. 這份檔案是共用入口，要修改請改 `AGENTS.md`。`CLAUDE.md` 只負責 import 這份檔案，不要在裡面加內容。
7. 討論中出現 Unity 用語時，轉換為 Godot 名詞再記錄，例如 prefab 記為可重用子場景（PackedScene）。缺少美術素材時，先回報用途與需求，待使用者提供位置或同意替代方式後再使用。
