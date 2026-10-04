# Team E 單機 / 雙機連線流程

Faust Game Jam 2026 · 主題 Breath

進入遊戲即在區網自動開房，從房間等候頁決定單機、加入他人或等人開局。Host（房主）與 Client（加入者）共用同一個等候頁，箭頭上標示誰能操作。

## 流程圖

```mermaid
flowchart TD
    A([主選單]) --> B[進入遊戲]
    B --> C[自動在區網建立房間<br/>自己為 Host]
    C --> R[房間等候頁<br/>Host / Client 共用]

    %% 單機
    R -->|Host：以單機遊玩<br/>僅限房內只有自己| E[關閉區網房間]
    E --> F[單機遊戲] --> G[遊戲結束] --> A

    %% 加入別人
    R -->|Host：加入別人房間<br/>僅限房內只有自己| H[嘗試連線他人房間]
    H --> I{連線成功？}
    I -->|否：保留自己的房間| R
    I -->|是| J[關閉自己的房間]
    J -->|以 Client 身份進入對方房間| R

    %% 開始連線局
    R -->|Host：開始遊戲<br/>滿 2 人才可按| N[連線遊戲]
    N -->|遊戲結束| R

    %% 斷線
    N -->|Host 偵測斷線| R
    N -->|Client 偵測斷線| C
    R -->|Client 偵測斷線| C

    %% 離開
    R -->|Host：離開| P[關閉整個房間]
    P --> A
    P -.->|Client 被強制退出| A
    R -->|Client：離開<br/>Host 留在房內| A
```

## 流程規則

1. 進入遊戲時自動在區網建立房間，自己為 Host，進入房間等候頁。
2. **以單機遊玩**：關閉區網房間，開始單機遊戲；結束後回主選單。
3. **加入別人房間**：嘗試連線他人房間。
   - 成功：關閉自己的房間，以 Client 身份進入對方房間（顯示同一個等候頁）。
   - 失敗：保留自己的房間，留在原等候頁。
4. **開始遊戲**：滿 2 人時 Host 可按開始，進入連線遊戲；結束後回到同一個等候頁，方便繼續下一局。
5. **斷線**：回到房間等候頁。
6. **離開**：
   - Host 離開：關閉整個房間，Client 被強制退出回主選單，Host 也回主選單。
   - Client 離開：回主選單，Host 留在房內。

## 等候頁按鈕

| 按鈕 | Host | Client |
|---|---|---|
| 以單機遊玩 | 房內只有自己時可按 | 不顯示 |
| 加入別人房間 | 房內只有自己時可按 | 不顯示 |
| 開始遊戲 | 滿 2 人才可按 | 顯示「等待房主開始」 |
| 離開 | 關閉房間，Client 一起退回主選單 | 自己回主選單，Host 留在房內 |

## 已確認

- **Client 斷線後去哪**：原房間屬於對方，已連不上，重新建立自己的房間。
- **加入失敗的原因**：房間已滿、對方遊戲中，都當作連線失敗，退回自己房間並顯示原因。
- **找房方式**：手動輸入 IP。
- **連線逾時**：「嘗試連線」上限 20 秒。

兩天 jam 建議優先順序：按鈕限制、Client 的等候提示，其次才是逾時。

## 實作對應

- `autoload/room_manager.gd`（`RoomManager`）：狀態機與換場景。等候頁、遊戲、主選單都只呼叫它，不自己換場景。
- `autoload/network_manager.gd`（`NetworkManager`）：連線、20 秒逾時、拒絕原因、關房通知、開始／結束連線局、斷線判定（約 6 秒）。
- `scenes/lobby/room_lobby.tscn`：Host／Client 共用等候頁，可單獨 F6 執行。
- `scenes/lobby/temp_menu.tscn`：暫用主選單，主選單從 game.tscn 拆出後（UI-14）由正式版取代。
- `scenes/game/client_play.tscn`：Client 連線局畫面，只回報吸／吐（麥克風或 J／K）。Host 端收 `NetworkManager.voice_action_received`：`inhale` 呼叫 `suck()`、`exhale` 開始噴火／吐、`none` 放開。
- 「嘗試連線」期間會先關掉自己的房間（ENet 一次只能是 Server 或 Client），失敗後重新建立，效果等同流程圖的「保留自己的房間」。
- 遊戲端要回到房間時呼叫 `RoomManager.finish_match()`（Host）；單機結束呼叫 `RoomManager.return_to_menu()`。
