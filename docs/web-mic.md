# 手機網頁收音備案（Web Mic）

> 狀態：**規劃中，尚未實作**。對應 tasks.md 的 NET-05～NET-09。

本文件說明現場區網連不上時的備案：兩位玩家各拿一支手機，用瀏覽器收音，經 Cloudflare Tunnel 連回一台電腦。
主要方案仍是 design.md 3.3 的雙機 ENet 連線。

## 1. 為什麼需要備案

- 示範場地在地下室，手機熱點沒有訊號，無法讓兩台電腦透過熱點上網。
- 現場 Wi-Fi 需要登入，常開啟用戶端隔離（client isolation）：裝置都能上網，彼此卻連不到。ENet 是電腦對電腦直連，會被擋。
- 手機和電腦都能連上現場 Wi-Fi 並上網，所以改成兩邊都只「往外連」到 Cloudflare，就不受用戶端隔離影響。

> 熱點即使沒有行動訊號仍可建立區網，區網內的裝置仍能互連。現場若能開熱點，ENet 主要方案在熱點內也能用，可以先試。

## 2. 設備配置

- **一台電腦**：執行遊戲（Host），顯示遊戲畫面。
- **兩支 Android 手機**：玩家 A 的手機只傳音量，玩家 B 的手機只傳「吸／吐」。電腦的麥克風不使用，避免同時收到兩位玩家的聲音。
- 只支援 Android Chrome；iOS 未測試。

## 3. 架構

```
手機 A 瀏覽器 ─┐                                 ┌─ Godot：WebMicServer（127.0.0.1:8765）
               ├─ HTTPS / WSS ─▶ Cloudflare ◀── cloudflared（電腦主動連出）
手機 B 瀏覽器 ─┘                                 └─ 發出與 ENet 相同的 voice_* signal
```

- 電腦執行 `cloudflared tunnel --url http://localhost:8765`（Quick Tunnel，不需帳號），取得 `https://xxxx.trycloudflare.com`。
- 瀏覽器只允許 HTTPS 頁面使用麥克風；Cloudflare 提供正式憑證，不需要自簽憑證。
- Godot 只聽 `127.0.0.1`，不對區網開放，只給本機的 cloudflared 連。
- Quick Tunnel 一次只能轉一個 port，所以同一個 port 同時提供網頁（`GET /`）和 WebSocket（`GET /ws?player=a|b`）。
- 預估延遲：台灣有 Cloudflare 節點，正常 Wi-Fi 約多 20～60 ms，需現場實測。
- 現場若擋 UDP 7844，cloudflared 加上 `--protocol http2` 改走 443。

## 4. 接入點：沿用 ENet 的 signal

手機在 JS 裡自己算出音量與吸／吐，電腦端收到後發出跟 `NetworkManager` 相同格式的 signal：

| signal | 來源 | 內容 |
|---|---|---|
| `voice_volume_received(peer_id, seq, volume)` | 手機 A | 音量 0～1，20 Hz |
| `voice_word_received(peer_id, seq, word)` | 手機 B | `"吸"` 或 `"吐"` |

- 兩支手機各用一個固定的假 `peer_id`，區分玩家 A、B（數值實作時決定，避開 ENet 的 peer id）。
- 遊戲端切到備案時不需要改程式；但遊戲端的輸入橋接要能讓「移動」「動作」兩邊都改從 signal 取得（見 NET-03）。
- 優點：不動 `MicInput`（MIC 區塊）與 `NetworkManager` 的程式。
- 代價：JS 要另寫一套較簡單的音量與吸／吐判斷，靈敏度可能和電腦版不同。

## 5. 手機與電腦之間的訊息

WebSocket 文字訊息，內容是 JSON：

| 方向 | 訊息 | 說明 |
|---|---|---|
| 手機 → 電腦 | `{"t":"vol","s":序號,"v":0~1}` | 音量 |
| 手機 → 電腦 | `{"t":"word","s":序號,"w":"吸"}` | 字音 |
| 手機 → 電腦 | `{"t":"ping","c":手機時間,"rtt":上次延遲}` | 每秒一次，量延遲 |
| 電腦 → 手機 | `{"t":"pong","c":原樣回傳}` | 手機據此算來回延遲 |

- 手機收音要關掉 `autoGainControl`、`noiseSuppression`、`echoCancellation`，否則音量被自動拉平，無法用音量控制高度。
- 手機頁面要用 Wake Lock 保持螢幕開啟，螢幕關掉時瀏覽器會停止收音。
- 斷線後每秒自動重連；同一位玩家重新整理網頁時，舊連線作廢。

## 6. 預計檔案

依 conventions.md，放在 `scenes/web_mic/`（實作時建立，並更新 AGENTS.md 資料夾結構與 conventions.md 歸屬表）：

| 檔案 | 用途 |
|---|---|
| `web_mic_server.gd` | `WebMicServer` 節點：HTTP＋WebSocket server，發出 signal |
| `web_mic_page.html` | 手機頁面：收音、算音量、吸／吐、延遲顯示 |
| `web_mic_test.tscn` / `.gd` | 連線測試場景（F6）：兩支手機的連線狀態、音量、字音、掉包與延遲 |

Godot 內建的 `WebSocketPeer` 不能和網頁共用同一個 port，所以 WebSocket 握手與封包格式自己處理（只需支援手機送來的短訊息）。

## 7. 實作步驟

1. **NET-05 連線測試**：Godot 開 server，cloudflared 轉出，一支 Android 手機打開網頁，Godot 畫面顯示音量與延遲。確認 Cloudflare 在現場網路可通、延遲可接受。
2. **NET-06 接上 signal**：`WebMicServer` 發出與 `NetworkManager` 相同的 `voice_*` signal，並確認遊戲端可切換輸入來源（依賴 NET-03）。
3. **NET-07 手機端吸／吐辨識**：JS 版字音判斷取代測試用按鈕，參考 `MicInput` 的過零率＋音量做法。
4. **NET-08 啟動流程**：Godot 自動啟動 cloudflared、讀出網址，畫面顯示兩個 QR code（`?player=a`、`?player=b`）。
5. **NET-09 匯出設定**：匯出 preset 的 include filter 加上 `*.html`，確認匯出版也能提供網頁。

## 8. 待確認

- 現場 Wi-Fi 是否允許 cloudflared 連出（UDP 7844 或 TCP 443）。
- 實際延遲是否可接受，尤其是「吐」的按住與放開。
- 「吐」需要開始與結束（`spit_pressed()`／`spit_released()`），ENet 版字音目前是單一事件；兩邊要一起決定格式。
