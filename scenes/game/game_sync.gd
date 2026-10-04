class_name GameSync
extends RefCounted
## 畫面同步的共用常數：Host 的 GameStateSender 與 Client 的 GameStateReceiver 都用這裡的名稱。
##
## 三種封包（NetworkManager.send_state_*）：
## - full（可靠）：完整的離散狀態，Client 載入完成時、開局時、之後每隔 FULL_INTERVAL 秒補送，用來對帳。
## - event（可靠、依序）：單一事件，Dictionary，"t" 是事件類型（EV_*），其餘欄位依類型。
## - snapshot（不可靠）：連續變動的值（龍的位置、暈眩時間…），每 SNAPSHOT_INTERVAL 秒一次，掉包由下一個補上。
##   快照不放離散狀態（計數、朝向、勝敗），避免舊快照蓋掉較新的事件。

## 快照的間隔（秒），20 次／秒。
const SNAPSHOT_INTERVAL: float = 0.05
## 完整狀態定期補送的間隔（秒）。
const FULL_INTERVAL: float = 3.0
## 龍的位置和快照差超過這麼多（世界座標）才硬拉過去，平時靠本機移動預測。
const DRAGON_SNAP_DISTANCE: float = 0.5

# 事件類型
const EV_STARTED: String = "started"
const EV_COMPLETED: String = "completed"  # v: 完成鍋數
const EV_CLEARED: String = "cleared"  # v: 清空次數
const EV_FACING: String = "facing"  # v: GameManager.Facing
const EV_ELEMENT: String = "element"  # v: GameManager.Element
const EV_TARGET: String = "target"  # v: 龍的目標層
const EV_STUNNED: String = "stunned"
const EV_RECOVERED: String = "recovered"
const EV_WON: String = "won"
const EV_LOST: String = "lost"
