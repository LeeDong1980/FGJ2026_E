class_name ShoutDetector
extends RefCounted
## 大叫偵測：音量（0～100）往上超過 threshold 的那一刻算一次大叫。
## 要先降到 release 以下才會再觸發，一直叫著不會連續觸發；兩次大叫至少間隔 cooldown 秒。

var threshold: float = 50.0
var release: float = 35.0
var cooldown: float = 0.4

var _armed: bool = true
var _since_shout: float = INF


## 每幀呼叫一次，這一幀剛開始大叫時回傳 true。
func update(volume_value: float, delta: float) -> bool:
	_since_shout += delta
	if volume_value < release:
		_armed = true
		return false
	if not _armed or volume_value <= threshold or _since_shout < cooldown:
		return false
	_armed = false
	_since_shout = 0.0
	return true
