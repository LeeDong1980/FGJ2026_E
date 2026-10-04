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

## 網頁版（Web）
已實測：單機流程可在瀏覽器執行（Chrome 內測）。限制與設定如下。

**輸出設定**（Project → Export → Add… → Web；`export_presets.cfg` 因各人輸出路徑不同，Web 預設請自行建立）
- Filters 填 `*.html`，**取消** Thread Support（單執行緒，不需要特殊伺服器標頭，itch.io 可直接用）。
- 輸出到 `builds/web/index.html`（`builds/` 已被 `.gitignore` 排除）。
- 渲染器不用改：網頁版自動使用 Compatibility，專案維持 Forward Plus。
- 本機測試：`python3 -m http.server 8060 --bind 127.0.0.1`，瀏覽器開 `http://127.0.0.1:8060/index.html`（直接開檔案無法執行）。
- 輸出約 150 MB（pck 約 110 MB、wasm 約 40 MB），首次載入較慢。

**網頁版的差異**
- 沒有區網房間（瀏覽器不能開 ENet），等候頁只留「單機」「公開房間」與輸入房間代碼加入；程式用 `OS.has_feature("web")` 判斷。
- 沒有手機麥克風（瀏覽器不能開 TCP server），`PhoneMic` 在網頁版直接略過。
- 麥克風需要 HTTPS（itch.io 本身是 HTTPS）、玩家先點擊網頁，並允許瀏覽器的麥克風權限。
- 瀏覽器沒有系統字型，中文靠內嵌的 `NotoSansTC-Bold.ttf`（專案預設字型 `gui/theme/custom_font` 與三個主題的備援字型）。**新的主題或字型不要只用 SystemFont。**

**尚未驗證**：真實麥克風（吸／吐、音高）、公開房間經中繼的連線、手機瀏覽器、效能與音訊延遲。

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
