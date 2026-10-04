extends Control
## 手機麥克風連線測試：顯示兩位玩家的連線狀態與收到的原始數值。
## 手機按「按我測延遲」時，這邊對應的半邊畫面會閃一下（玩家 1 左、玩家 2 右）。
## 執行後在終端機跑 cloudflared tunnel --url http://localhost:8080，手機開它給的 https 網址。

@onready var _server: PhoneMicServer = PhoneMic
@onready var _info: Label = %Info
@onready var _flashes: Dictionary = {1: %Flash1, 2: %Flash2}

const WARN_ONE_WAY_MSEC := 150.0

## player -> {db, zcr, hz, count, rate, last_msec, rtt}
var _stats: Dictionary = {}
var _rate_timer: float = 0.0


func _ready() -> void:
	for player in [1, 2]:
		_stats[player] = {"db": MicController.MIN_DB, "zcr": 0.0, "hz": 0.0, "count": 0, "rate": 0, "last_msec": -1, "rtt": -1.0}
	_server.sample_received.connect(_on_sample_received)
	_server.tap_received.connect(_on_tap_received)
	_server.latency_reported.connect(func(player: int, rtt: float) -> void: _stats[player].rtt = rtt)


func _on_tap_received(player: int) -> void:
	var flash: ColorRect = _flashes[player]
	flash.modulate.a = 1.0
	flash.color.a = 1.0
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.3)


func _on_sample_received(player: int, db: float, zcr: float, hz: float, _seconds: float) -> void:
	var stat: Dictionary = _stats[player]
	stat.db = db
	stat.zcr = zcr
	stat.hz = hz
	stat.count += 1
	stat.last_msec = Time.get_ticks_msec()


func _process(delta: float) -> void:
	_rate_timer += delta
	if _rate_timer >= 1.0:
		_rate_timer -= 1.0
		for stat: Dictionary in _stats.values():
			stat.rate = stat.count
			stat.count = 0

	var lines: PackedStringArray = [
		"手機麥克風測試（port %d）" % _server.port,
		"1. 終端機執行：cloudflared tunnel --url http://localhost:%d" % _server.port,
		"2. 手機開啟它印出的 https://….trycloudflare.com 網址，選玩家後按「開始收音」",
		"3. 手機按「按我測延遲」，這邊對應的半邊畫面會閃一下；精確的來回時間顯示在手機上",
		"",
	]
	for player in [1, 2]:
		var stat: Dictionary = _stats[player]
		if not _server.is_player_connected(player):
			lines.append("玩家 %d：未連線" % player)
			continue
		var age: int = Time.get_ticks_msec() - stat.last_msec if stat.last_msec >= 0 else -1
		lines.append("玩家 %d：已連線　%3d 則/秒　最後封包 %d ms 前　%s" % [player, stat.rate, age, _latency_text(stat.rtt)])
		lines.append("　　音量 %6.1f dB　音高 %s　zcr %.3f" % [stat.db, ("%4.0f Hz" % stat.hz) if stat.hz > 0.0 else "  -- Hz", stat.zcr])
	_info.text = "\n".join(lines)


func _latency_text(rtt: float) -> String:
	if rtt < 0.0:
		return "延遲 測量中"
	var one_way: float = rtt / 2.0
	return "延遲（單程）約 %d ms%s" % [roundi(one_way), "　⚠ 太慢" if one_way > WARN_ONE_WAY_MSEC else ""]
