# FGJ2026E_Game

Game Jam 3D 遊戲專案（玩法尚未決定，見 docs/design.md）。多人協作，進度透過 git 同步。

## 環境
- Godot 4.7，Forward Plus 渲染器，3D 物理用 Jolt
- 執行：用 Godot 編輯器開啟 `project.godot`，按 F5 執行主場景，按 F6 執行目前開啟的場景。

## 資料夾結構
- `scenes/main/`：主場景。
- `scenes/dungeon_room/`：地牢房間，包含 dungeon 模型實例、材質、碰撞、燈光與攝影機。
- `scenes/red_dragon/`：紅龍模型子場景。
- `scenes/platforms/`：Cube 平台、左右排列子場景與棋盤格材質。
- `Models/`：模型與貼圖素材。
- `docs/`：設計、開發慣例與任務清單。

新資料夾依 docs/conventions.md 的規則建立，建好後更新這一節。

## 文件
- `docs/tasks.md`：任務清單。**每次開始任務前都要讀**。
- `docs/design.md`：玩法、操作、勝敗條件、範圍。實作遊戲功能前先讀。
- `docs/conventions.md`：命名、資料夾、場景歸屬規則。新增或修改檔案、場景前先讀。

## 工作規則
1. 開始任務前先讀 `docs/tasks.md`，在任務後面標上自己的負責人（`@名字`），然後馬上 commit 並 push，讓其他人知道。
2. 完成任務後打勾 `[x]`。
3. 過程中發現新的待辦事項，就加到 `docs/tasks.md` 對應的區塊，一個任務佔一行。
4. 設計有變動就更新 `docs/design.md`。文件只寫已經確定的事。
5. 不要修改其他人負責的場景（.tscn），規則見 docs/conventions.md。
6. 這份檔案是共用入口，要修改請改 `AGENTS.md`。`CLAUDE.md` 只負責 import 這份檔案，不要在裡面加內容。
