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
## 食材的位置和快照差超過這麼多（LaneLayout 的本地座標）才硬拉過去，平時靠本機沿隊伍走的預測。
const INGREDIENT_SNAP_DISTANCE: float = 0.3
## 龍的位置和快照差超過這麼多（世界座標）才硬拉過去，平時靠本機移動預測。
const DRAGON_SNAP_DISTANCE: float = 0.5

## 測試用：Client 隨機丟掉這個比例（0～1）的快照，模擬掉包，驗證狀態仍能靠事件與完整狀態對上。正式遊戲保持 0。
static var debug_snapshot_loss: float = 0.0

# 事件類型
const EV_STARTED: String = "started"
const EV_COMPLETED: String = "completed"  # v: 完成鍋數
const EV_CLEARED: String = "cleared"  # v: 清空次數
const EV_FACING: String = "facing"  # v: GameManager.Facing
const EV_ELEMENT: String = "element"  # v: GameManager.Element
const EV_TARGET: String = "target"  # v: 龍的目標層
const EV_STUNNED: String = "stunned"
const EV_RECOVERED: String = "recovered"
const EV_POT: String = "pot"  # lane、pot: 鍋子與小龍的資料（見 GameStateSender.pot_to_dict）
const EV_BABY_LEFT: String = "baby_left"  # lane、v: GameManager.BabyLeaveReason
const EV_BABY_ARRIVED: String = "baby_arrived"  # lane
const EV_STOMACH: String = "stomach"  # v: 胃裡食材的種類，胃空時是 -1
const EV_SPAT: String = "spat"  # lane、v: 吐進鍋子的食材種類
const EV_SPIT: String = "spit"  # v: [正在喊吐, 這次已經吐進鍋子]
const EV_SPAWN: String = "spawn"  # lane、id、type、x
const EV_REMOVED: String = "removed"  # lane、id（食材離開隊伍：被吞、被燒）
const EV_SWALLOWED: String = "swallowed"  # lane、v: 食材種類（吸取特效）
const EV_BURNED: String = "burned"  # lane、v: 食材種類
const EV_ATTACKED: String = "attacked"  # lane、id、hit
const EV_FROZEN: String = "frozen"  # lane、id
const EV_SUCK_MISSED: String = "suck_missed"  # lane
const EV_SPIT_MISSED: String = "spit_missed"  # lane
const EV_ACTION_MISSED: String = "action_missed"  # lane、v: GameManager.MissReason（畫面上方的提示）
const EV_SCORE: String = "score"  # v: 分數、gained: 這次得分、fast: 是否有快速加分
const EV_WON: String = "won"
const EV_LOST: String = "lost"
