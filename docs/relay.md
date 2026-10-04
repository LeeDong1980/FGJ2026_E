# 遠端連線（公開房間與中繼伺服器）

兩位玩家不在同一個網路時，Host 在等候頁按「公開房間」取得 6 碼房間代碼，對方在「加入別人房間」輸入代碼就能連上。
區網連線（輸入 IP）維持原樣，兩種方式並存。

## 運作方式

```
Host ──wss──▶ ┐                              ┌ ◀──wss── Client
              │  Cloudflare Worker（入口）     │
              └▶ Durable Object（一個房間一個）◀┘
                 只負責把一邊的封包轉給另一邊
```

- 兩邊都只對中繼做**出站** `wss://`（443）連線：不用開 port、不用 UPnP、不用安裝任何東西，也不會跳 Windows 防火牆視窗（只有「監聽」才會跳）。
- 中繼不理解遊戲內容，只轉送。所有遊戲邏輯與拒絕判斷（房間已滿、對方遊戲中）仍在 `NetworkManager`。
- ENet 是 UDP，過不了中繼，所以遠端模式改用 WebSocket（TCP）：`RelayMultiplayerPeer`（`scenes/relay/relay_multiplayer_peer.gd`）是 `MultiplayerPeerExtension`，`SceneMultiplayer` 與 RPC 的用法不變。代價是 `unreliable_ordered`（音高）也變成可靠有序，掉包時會稍微卡一下。
- Host 的 peer id 固定 1，Client 固定 2。一個房間最多 1 位 Client。
- Host 公開房間時，區網房間（ENet）會關閉，因為 `multiplayer` 一次只能有一個 peer；取消公開回到區網房間。只有房內沒有別人時才能切換。

## 玩家流程

1. Host 進房間等候頁，按「公開房間」→ 顯示房間代碼（可按「複製代碼」）。
2. Client 在「加入別人房間」輸入欄填房間代碼（不分大小寫），按「加入別人房間」。輸入 6 個英數字且不含 `.` 時視為代碼，否則視為區網 IP。
3. Host 按「取消公開」回到區網房間；Host 離開則 Client 一起退回主選單。
4. 連不上時按「連線診斷」，依步驟顯示哪裡不通與白話原因。

## 中繼伺服器（`relay_server/`）

| 路徑 | 說明 |
|---|---|
| `GET /health` | 回 `{"ok":true}`，診斷與監控用 |
| `WS /echo` | 收到什麼回什麼，診斷來回時間用 |
| `WS /host` | Host 建立房間。連上後中繼送 `{"type":"hosted","code":"K7QX3M"}` |
| `WS /join/<代碼>` | Client 加入。成功送 `{"type":"joined"}`，Host 收到 `{"type":"peer_joined"}` |

- 房間代碼 6 碼，字元集去掉容易混淆的 `I O 0 1`（32 個字元，約 10 億種）。
- 之後的二進位訊息原樣轉給另一邊（上限 64 KB）。文字訊息：`ping`（runtime 自動回 `pong`）、Host 送 `{"type":"kick"}` 踢掉 Client、中繼送 `{"type":"peer_left"}`。
- 被拒絕時先完成握手再用關閉碼說明原因（握手失敗只會看到一般錯誤）：`4004 room_not_found`、`4009 room_full`、`4001 host_left`（Host 離開，Client 被關閉）、`4002 kicked`。
- 二進位訊息第一個位元組是類型：`0` 遊戲封包、`1` ping（帶 8 位元組時間）、`2` pong。Host 與 Client 每秒互送 ping 量來回時間與確認對方還在；超過 6 秒沒收到視為斷線。對中繼本身每 4 秒送一次 `ping`，12 秒沒回應視為中繼斷線。
- 使用 Hibernation API：房間沒有訊息時 Durable Object 不計運算時間。

## 目前部署

- 網址：`https://fgj2026-relay.fgj2026-relay.workers.dev`（Cloudflare 帳號 stc.ntu@gmail.com，Worker 名稱 `fgj2026-relay`），已填入 `NetworkManager.DEFAULT_RELAY_URL`。
- 更新程式後重新部署：`cd relay_server && npx wrangler deploy`（需要 Node 20 以上；這台 Mac 的預設 node 是 16，用 `PATH=/usr/local/opt/node/bin:$PATH` 指定 brew 裝的新版）。

## 部署（第一次）

需求：Node 20 以上、Cloudflare 帳號。

1. 到 [dash.cloudflare.com](https://dash.cloudflare.com) 登入，左側選 **Workers & Pages**；第一次使用會要求設定 **workers.dev 子網域**（例如 `fgj2026`），之後網址是 `https://fgj2026-relay.<子網域>.workers.dev`。
2. 終端機：
   ```bash
   cd relay_server
   npm install
   npx wrangler login      # 會開瀏覽器，按「Allow」授權
   npx wrangler deploy     # 部署，最後會印出 Worker 網址
   ```
3. 把網址（改成 `wss://` 開頭）填進 `autoload/network_manager.gd` 的 `DEFAULT_RELAY_URL`。
4. 驗證：瀏覽器開 `https://…workers.dev/health` 看到 `{"ok":true…}`；在 Godot 開 `scenes/relay/relay_test.tscn` 按 F6，按「連線診斷」。

本機測試：`cd relay_server && npx wrangler dev`（預設 `http://127.0.0.1:8787`），Godot 命令列加 `-- --relay-url=ws://127.0.0.1:8787`，或在 `relay_test` 的網址欄填 `ws://127.0.0.1:8787`。

## 測試

`scenes/relay/relay_test.tscn`（F6）：一台按「公開房間」，另一台填代碼加入，雙方各送 20 個編號封包，檢查是否都收到且順序正確，並顯示來回時間。
自動模式（腳本用）：`godot --headless --path . res://scenes/relay/relay_test.tscn -- --auto=host`、`--auto=join --code=XXXXXX`、`--auto=diag`，加 `--relay-url=…` 指定中繼。

## 已知限制與費用

- **延遲（2026-10-04 實測，台灣）**：這個 workers.dev 網址的請求被導到美國聖荷西（回應標頭 `cf-ray` 結尾 `SJC`，TCP 連線約 138 ms），雖然同一台電腦連 Cloudflare 一般網站是台北（`colo=TPE`）。兩位玩家都在台灣時，玩家對玩家的來回時間約 **290 ms**（單向約 145 ms），診斷的「中繼來回」約 150 ms。可以玩，但吸／吐與音高會有明顯延遲感。
- **原因（2026-10-04 實驗）**：不是程式或 Worker 設定，而是 Cloudflare 依 IP 區段決定走哪個機房。`*.workers.dev` 的帳號子網域網址，DNS 給的是 `104.21.x`／`172.67.x` 這一組，在台灣會被導到美國 SJC（TCP 連線 138～210 ms）；同一個 Worker 改連 `104.16`～`104.20`、`162.159` 那幾組 IP（用 `curl --resolve` 或 Node 指定），則落在台北／高雄（連線約 10～20 ms），玩家對玩家來回從約 **296 ms 降到約 110 ms**。社群的說法是免費方案在亞洲的路由較差（非官方文件，我沒有找到免費方案能切換的設定）。
- 其他參考：`trycloudflare.com` 解析到 `104.16.x`（台北），與 MIC-11 實測單程約 17 ms 一致；`stun.cloudflare.com`、`turn.cloudflare.com` ping 約 8 ms。
- 可能的改善（細節見 tasks.md NET-25）：(1) 自己的網域加 Pro 方案，讓 Worker 拿到較近的 IP 區段（未驗證）；(2) Host 用 cloudflared Quick Tunnel 對外，Worker 只當「房間代碼→網址」的目錄，遊戲封包走台北；(3) WebRTC 點對點，Cloudflare 提供 STUN／TURN，桌面版要隨遊戲附帶 webrtc-native 的 GDExtension。
- Cloudflare 免費額度有限（Workers 每日請求數、Durable Object 每日運算時間，WebSocket 訊息以 20:1 換算請求數）。Jam 規模應該夠用，正式使用前請查 Cloudflare 當前的計費頁面。
- 目前沒有對房間建立做限流；網址與代碼不要公開張貼。
- 網頁版（itch.io）：協定只用 WebSocket，原則上可行，但專案目前用 Forward Plus 渲染器與 `TCPServer`（PhoneMic），網頁版匯出前要另外處理（見 tasks.md SET-03）。
