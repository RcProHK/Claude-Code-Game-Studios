## StatWatermark — #22 Rule 31 first-seen watermark (story 006; CD 裁決 1).
##
## 「可見時間線」嘅 MVP 兌現:每個 stat 第一次被 #22 讀到嗰刻 write-once
## persist {value, date} — 門框第一格刻度。**永不覆寫**。
##
## Render suppress(formatter 就係 epsilon):只喺 fmt(current) != fmt(watermark)
## 時 render —「STR 47 ⌜今日:47⌟」廢話行由構造上消滅。
##
## Persist fail(Private Mode,ADR-0003 detect-and-gate)→ 唔 render、唔
## fabricate session-only watermark(session 記錄會喺下次 session 講大話)。
##
## 冇 history array、冇 graph — v0.2 #28(Q-CS5)。
## 老玩家 first-seen = #22 上線日(誠實:你幾時量,刻度幾時刻)。
## Date = device local(EC-15 provenance 同款)— caller 注入 date string
## (binding 層用 Time.get_date_string_from_system(false) — local)。
extends RefCounted

const KEY_PREFIX: String = "charscreen.stat_watermark."

## untyped DI seam(#3 PersistenceLayer 或 test mock — read(key)/write(key, value)).
var _persistence


func _init(persistence) -> void:
	_persistence = persistence


## Open-time first read 入口(Rule 7 sequence 內逐 stat call)。
## Returns 生效嘅 watermark {value, date};persist 不可用 → {}(零 render)。
func ensure(stat_id: StringName, current_value: float, date_str: String) -> Dictionary:
	if _persistence == null:
		return {}
	var key: String = KEY_PREFIX + String(stat_id)
	var existing = _persistence.read(key)
	if existing is Dictionary and existing.has("value") and existing.has("date"):
		return existing  # write-once:已有刻度永不覆寫
	var record: Dictionary = {"value": current_value, "date": date_str}
	var ok: bool = _persistence.write(key, record)
	if not ok:
		return {}  # Private Mode persist fail — 唔 fabricate
	return record


## Suppress predicate:watermark 行只喺 formatted 值唔同時出現。
static func should_render(watermark: Dictionary, current_value: float, fmt: Callable) -> bool:
	if watermark.is_empty():
		return false
	return fmt.call(current_value) != fmt.call(float(watermark["value"]))


## dim 行文案:「⌜[date]:[fmt(value)]⌟」(L0 static ink — Visual 表).
static func render_text(watermark: Dictionary, fmt: Callable) -> String:
	return "⌜%s:%s⌟" % [watermark["date"], fmt.call(float(watermark["value"]))]
