# 電腦版輸出與上傳

輸出設定存在 `export_presets.cfg`（Windows Desktop、macOS 兩個預設），已納入 git。

## 輸出前置
1. **Editor → Manage Export Templates…** 安裝與編輯器同版本的輸出範本。
2. 專案設定 **Rendering → Textures → VRAM Compression → Import ETC2 ASTC** 已開啟（macOS Universal／arm64 需要；已寫入 `project.godot`）。
3. 預設的 **Filters to export non-resource files** 必須是 `*.html`，否則 `phone_mic.html`（手機麥克風網頁）不會被打包。
4. macOS 預設已開啟麥克風權限（`audio_input`）與用途說明，不要關掉，否則輸出後麥克風沒有聲音。

## 輸出
- Project → Export…，選預設後按 **Export Project**，取消勾選 Export With Debug。
- 輸出路徑是個人設定，各人可自行改。預設輸出到 `releases/`（已被 `.gitignore` 排除，輸出檔不要 commit）。
- Windows 用 Embed PCK，輸出單一 exe；macOS 輸出 zip（內含 `.app`）。
- 指令輸出：`godot --headless --export-release "Windows Desktop" releases/FGJ2026E_Game.exe`

## 輸出後檢查
在乾淨資料夾直接開啟輸出的執行檔，確認：主選單、BGM 與音效、麥克風、區網與遠端連線、手機麥克風網頁。macOS 首次進入遊戲時會跳出麥克風授權。

## macOS 的 Gatekeeper 警告
匯出時會看到「已停用公證」與「使用 ad-hoc 簽名」兩個警告，可以忽略。沒有 Apple Developer 帳號（美金 99 元／年）就無法簽章與公證，所以從瀏覽器下載的 Mac 版第一次開啟會被 Gatekeeper 擋下。上傳頁面要附上下方說明。

## 上傳頁面說明文字（可直接貼）

### macOS 玩家第一次開啟的方法
本遊戲沒有 Apple 開發者簽章，macOS 第一次開啟時會顯示「無法打開」，請用下列任一方式開啟（只需做一次）：

1. 解壓縮後，對 App 按**右鍵（或 Control＋點擊）→ 打開**，再按對話框的「打開」。
2. 若沒有「打開」按鈕（macOS 15 以上）：先雙擊 App 一次，到**系統設定 → 隱私權與安全性**，捲到下方按**仍要打開**。
3. 或在終端機執行（路徑換成你的 App 位置）：
   `xattr -cr /路徑/FGJ2026E_Game.app`

第一次使用麥克風時，請在跳出的視窗按「好」允許。

### Windows 玩家
若出現「Windows 已保護您的電腦」，按**其他資訊 → 仍要執行**。首次連線時，請允許 Windows 防火牆的網路存取。
