## #22 Rule 31 watermark — unit suite (story 006; GDD AC-55 四翼).
extends GutTest

const Watermark := preload("res://src/ui/character_screen/stat_watermark.gd")
const F := preload("res://src/ui/character_screen/char_screen_formulas.gd")


## Dictionary-backed #3 mock(write fail 模式 = Private Mode class).
class MockPersistence:
	extends RefCounted
	var store: Dictionary = {}
	var fail_writes: bool = false
	var write_count: int = 0

	func read(key: String):
		return store.get(key, null)

	func write(key: String, value, _flush: bool = false) -> bool:
		write_count += 1
		if fail_writes:
			return false
		store[key] = value
		return true


var _mock: MockPersistence


func before_each() -> void:
	_mock = MockPersistence.new()


## --- AC-55 翼 1:write-once ---

func test_first_read_writes_once() -> void:
	var wm = Watermark.new(_mock)
	var rec: Dictionary = wm.ensure(&"STR", 30.0, "1月12日")
	assert_eq(rec["value"], 30.0)
	assert_eq(rec["date"], "1月12日")
	assert_true(_mock.store.has("charscreen.stat_watermark.STR"))


func test_existing_watermark_never_overwritten() -> void:
	var wm = Watermark.new(_mock)
	wm.ensure(&"STR", 30.0, "1月12日")
	var writes_after_first: int = _mock.write_count
	# 第二次 open,stat 已升到 47 — watermark 必須保留第一格
	var rec: Dictionary = wm.ensure(&"STR", 47.0, "6月7日")
	assert_eq(rec["value"], 30.0, "write-once:原值保留")
	assert_eq(rec["date"], "1月12日", "原日期保留")
	assert_eq(_mock.write_count, writes_after_first, "零額外 write")


## --- AC-55 翼 2:suppress predicate(formatter epsilon)---

func test_suppress_when_formatted_equal() -> void:
	var rec: Dictionary = {"value": 47.0, "date": "6月7日"}
	assert_false(Watermark.should_render(rec, 47.0, F.fmt_int),
		"新帳號當日:fmt(current)==fmt(watermark) → 唔 render 廢話行")
	assert_false(Watermark.should_render(rec, 47.4, F.fmt_int),
		"sub-display-unit 差異照 suppress(formatter epsilon)")


func test_render_when_diverged() -> void:
	var rec: Dictionary = {"value": 30.0, "date": "1月12日"}
	assert_true(Watermark.should_render(rec, 47.0, F.fmt_int))
	assert_eq(Watermark.render_text(rec, F.fmt_int), "⌜1月12日:30⌟")


## --- AC-55 翼 3:persist fail → 唔 render 唔 fabricate ---

func test_persist_fail_returns_empty_no_fabrication() -> void:
	_mock.fail_writes = true
	var wm = Watermark.new(_mock)
	var rec: Dictionary = wm.ensure(&"STR", 30.0, "6月7日")
	assert_eq(rec, {}, "fail → {} — 零 session-only fabrication")
	assert_false(Watermark.should_render(rec, 47.0, F.fmt_int), "{} 永不 render")
	assert_false(_mock.store.has("charscreen.stat_watermark.STR"))


func test_null_persistence_seam_safe() -> void:
	var wm = Watermark.new(null)
	assert_eq(wm.ensure(&"STR", 30.0, "6月7日"), {})


## --- 翼 4:crit_chance pct formatter 路徑 ---

func test_pct_stat_watermark() -> void:
	var wm = Watermark.new(_mock)
	var rec: Dictionary = wm.ensure(&"crit_chance", 0.03, "1月12日")
	assert_false(Watermark.should_render(rec, 0.034, F.fmt_pct), "3%→3.4% same bucket suppress")
	assert_true(Watermark.should_render(rec, 0.07, F.fmt_pct))
	assert_eq(Watermark.render_text(rec, F.fmt_pct), "⌜1月12日:3%⌟")
