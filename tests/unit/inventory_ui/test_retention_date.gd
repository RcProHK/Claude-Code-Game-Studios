## #23 F1 retention date — unit suite(story 004;AC-01)。
## 兩條腿:fixed-tz golden + formatter round-trip;render guards;D2 過去日期。
extends GutTest

const InvUiFormulas := preload("res://src/ui/inventory_ui/inv_ui_formulas.gd")

const TZ_HKT: int = 8 * 3600  # UTC+8(本機 dev tz)
const TZ_UTC: int = 0         # CI tz — 同一 code path,injected seam(AC-01)


func _unix_utc(y: int, mo: int, d: int, h: int, mi: int = 0) -> int:
	return int(Time.get_unix_time_from_datetime_dict(
		{"year": y, "month": mo, "day": d, "hour": h, "minute": mi, "second": 0}))


## ============ AC-01: fixed-tz goldens(GDD F1 example) ============

func test_retention_golden_hkt_june1_0900_yields_june7() -> void:
	# Arrange: acquired 6月1日 09:00 HKT = 01:00 UTC。
	var acquired: int = _unix_utc(2026, 6, 1, 1)
	# Act + Assert: −1 day = 最後完整保證日 6月7日(expiry instant = 6月8日 09:00)。
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_HKT), "6月7日")


func test_retention_golden_utc_same_wall_clock() -> void:
	# Arrange: acquired 6月1日 09:00 UTC(injected tz=0 — CI 腿)。
	var acquired: int = _unix_utc(2026, 6, 1, 9)
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_UTC), "6月7日")


func test_retention_tz_offset_changes_local_date() -> void:
	# Arrange: acquired 6月1日 18:00 UTC — HKT 已係 6月2日 02:00。
	var acquired: int = _unix_utc(2026, 6, 1, 18)
	# Assert: 同一 unix,tz seam 決定 local 日期(AC-01 determinism 機制)。
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_UTC), "6月7日")
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_HKT), "6月8日")


func test_retention_cross_day_boundary_2359() -> void:
	# Arrange: acquired 6月1日 23:59 local(tz=0)— 邊界跨日 case。
	var acquired: int = _unix_utc(2026, 6, 1, 23, 59)
	# Assert: retention = local date of acquired+6d(23:59 都仲係 6月7日)。
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_UTC), "6月7日")


func test_retention_formatter_round_trip() -> void:
	# Arrange: round-trip 腿 — expected 由 engine date dict 直接重derive。
	var acquired: int = _unix_utc(2026, 6, 1, 1)
	var ttl_days: int = InvUiFormulas.InventoryScript.OVERFLOW_MAILBOX_TTL_DAYS
	var d: Dictionary = Time.get_date_dict_from_unix_time(
		acquired + ttl_days * 86400 - 86400 + TZ_HKT)
	# Assert: formula output == 同一 dict 嘅 format(無 off-by-one drift)。
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_HKT),
		"%d月%d日" % [int(d["month"]), int(d["day"])])


## ============ AC-01: render guards ============

func test_receipt_item_renders_no_retention_line() -> void:
	var acquired: int = _unix_utc(2026, 6, 1, 9)
	assert_eq(InvUiFormulas.retention_date_text(acquired, true, TZ_UTC), "",
		"receipt 件 sweep 免疫 — 顯示限期 = 講大話(EC-08)")


func test_zero_or_negative_acquired_renders_no_retention_line() -> void:
	assert_eq(InvUiFormulas.retention_date_text(0, false, TZ_UTC), "",
		"persist 壞數據 — 寧願唔講,唔好講 1970")
	assert_eq(InvUiFormulas.retention_date_text(-5, false, TZ_UTC), "")


func test_past_date_still_renders_verbatim_d2() -> void:
	# Arrange: acquired 1月1日 — retention date 遠在過去(grace / mid-session 過界)。
	var acquired: int = _unix_utc(2026, 1, 1, 9)
	# Assert: 過去日期照 render 唔改寫(D2 — 賬簿唔改寫事實;EC-15 過期可見)。
	assert_eq(InvUiFormulas.retention_date_text(acquired, false, TZ_UTC), "1月7日")
