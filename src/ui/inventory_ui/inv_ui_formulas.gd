## #23 Inventory UI — formulas(story 004;GDD Formulas F1 + F2-M + Rules 7/8)。
##
## #23 係 thin browse surface — 呢度只有:F1 retention date、F2-M mailbox
## comparator、slot filter predicate、INVENTORY sort identity seam。
## Bulk yield / shortfall 直接 render #17 return(Rule 11/15 — 唔係 formula)。
extends RefCounted

## #22 F3 comparator(referenced,唔 fork — GDD Rule 7;AC-03 identity assert)。
const CharScreenFormulas := preload("res://src/ui/character_screen/char_screen_formulas.gd")
## TTL source of truth(#17 own,#23 referenced — 禁 hardcode 7)。
const InventoryScript := preload("res://src/autoload/inventory_system.gd")

## INVENTORY section sort = #22 F3 同一 code(rarity desc → acquired desc →
## item_id asc)。Const seam — story 006 binding 用;AC-03 assert 佢恆等
## Callable(CharScreenFormulas, "picker_before")(fork 必不等)。
const SORT_COMPARATOR := Callable(CharScreenFormulas, "picker_before")

## Filter sentinel(coordinator SlotFilter.ALL 喺 binding 層 map 落呢度;
## 非 ALL chips map 到 EquipmentEnums.EquipSlot ordinal — 避免 formula 層
## 同 coordinator enum 雙向 coupling)。
const FILTER_ALL: int = -1


## ---- F1 — Mailbox retention date(最後完整保證日;D2/D3) ----
## retention_date = date_local(acquired_at_unix + TTL×86400 − 86400)
## −86400(−1 day)= 顯示最後一個完整保證日:sweep 條件係 now − acquired >
## ttl_sec(#17 L948+),件喺 acquired+7日 嗰一刻起可被食 — 顯示第 8 日 =
## over-promise。承諾必兌現;date-only(附時刻 = 半個 countdown)。
##
## Returns「M月D日」display string;**"" = 唔 render retention 行**(render
## guards:receipt 件 [sweep 免疫 — 顯示限期 = 講大話] / acquired <= 0
## [persist 壞數據 — 寧願唔講,唔好講 1970])。
## 過去日期照 render 唔改寫(D2)— 賬簿唔改寫事實,過期可見性係 EC-15。
##
## tz_offset_sec: injected tz seam(production 傳 device offset —
## Time.get_time_zone_from_system().bias × 60;tests 傳固定值 — AC-01
## determinism,CI UTC vs 本機 HKT 同一條 code path)。
static func retention_date_text(
		acquired_at_unix: int, item_has_receipt: bool, tz_offset_sec: int) -> String:
	if item_has_receipt:
		return ""  # receipt 件唔會被 sweep — 無 retention 行(EC-08)
	if acquired_at_unix <= 0:
		return ""  # 壞數據 guard
	var last_full_day_unix: int = acquired_at_unix \
			+ InventoryScript.OVERFLOW_MAILBOX_TTL_DAYS * 86400 - 86400
	var d: Dictionary = Time.get_date_dict_from_unix_time(last_full_day_unix + tz_offset_sec)
	return "%d月%d日" % [int(d["month"]), int(d["day"])]


## ---- F2-M — Mailbox sort comparator(#23-owned;D8) ----
## acquired asc — TTL 食最舊,FIFO expiry queue 用 FIFO 順序(最需決策嘅件
## 喺最頂);同秒 tie 常態(unix seconds)→ item_id asc 保 strict total order
## (store-wide unique;String() 顯式 — StringName `<` 唔係字典序)。
static func mailbox_before(a, b) -> bool:
	if a.acquired_at_unix != b.acquired_at_unix:
		return a.acquired_at_unix < b.acquired_at_unix  # acquired asc
	return String(a.item_id) < String(b.item_id)        # tie → item_id asc(final)


## ---- Rule 8 — slot chip filter(view predicate only) ----
## 單一 equality predicate:唔改 sort、唔 re-read、唔 mutate 任何值。
## filter_slot = FILTER_ALL → 全 pass;否則 EquipSlot ordinal equality。
static func matches_filter(slot_affinity: int, filter_slot: int) -> bool:
	return filter_slot == FILTER_ALL or slot_affinity == filter_slot
