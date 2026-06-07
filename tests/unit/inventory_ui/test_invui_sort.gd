## #23 sort — unit suite(story 004;AC-03)。
## SORT_COMPARATOR identity seam(= #22 F3 同一 code,fork 必不等)+
## F2-M golden vectors(acquired asc → item_id asc;shuffle 收斂)。
extends GutTest

const InvUiFormulas := preload("res://src/ui/inventory_ui/inv_ui_formulas.gd")
const CharScreenFormulas := preload("res://src/ui/character_screen/char_screen_formulas.gd")


## Comparator field stub(picker_before 讀 rarity/acquired_at_unix/item_id;
## mailbox_before 讀 acquired_at_unix/item_id)。
class StubItem:
	var item_id: StringName
	var rarity: int
	var acquired_at_unix: int

	func _init(id: StringName, r: int, acq: int) -> void:
		item_id = id
		rarity = r
		acquired_at_unix = acq


func _ids(items: Array) -> Array[String]:
	var out: Array[String] = []
	for item in items:
		out.append(String(item.item_id))
	return out


## ============ AC-03: SORT_COMPARATOR identity seam ============

func test_sort_comparator_is_identity_with_picker_before() -> void:
	# Assert: 同一 Callable(referenced 唔 fork)— fork 出嚟嘅 Callable 必不等。
	assert_eq(InvUiFormulas.SORT_COMPARATOR,
		Callable(CharScreenFormulas, "picker_before"),
		"INVENTORY sort = #22 F3 同一 code(GDD Rule 7 identity assert)")


func test_sort_comparator_fixture_byte_identical_to_picker_before() -> void:
	# Arrange: 混 rarity / acquired / id 嘅 fixture。
	var fixture: Array = [
		StubItem.new(&"c", 0, 300),
		StubItem.new(&"a", 2, 100),
		StubItem.new(&"b", 2, 100),
		StubItem.new(&"d", 1, 200),
	]
	# Act: 兩個 callable 各 sort 一份 copy。
	var via_seam: Array = fixture.duplicate()
	via_seam.sort_custom(InvUiFormulas.SORT_COMPARATOR)
	var via_direct: Array = fixture.duplicate()
	via_direct.sort_custom(CharScreenFormulas.picker_before)
	# Assert: byte-identical 序。
	assert_eq(_ids(via_seam), _ids(via_direct))
	assert_eq(_ids(via_seam), ["a", "b", "d", "c"] as Array[String],
		"rarity desc → acquired desc → id asc(F3 golden)")


## ============ AC-03: F2-M golden vectors ============

func test_mailbox_sort_acquired_asc_with_id_tiebreak() -> void:
	# Arrange: acquired {50, 100×2(tie), 200} — tie 同秒常態。
	var fixture: Array = [
		StubItem.new(&"newest", 0, 200),
		StubItem.new(&"tie_b", 0, 100),
		StubItem.new(&"oldest", 0, 50),
		StubItem.new(&"tie_a", 0, 100),
	]
	# Act
	fixture.sort_custom(InvUiFormulas.mailbox_before)
	# Assert: acquired asc(FIFO expiry — 就嚟過期排最頂);tie → item_id asc。
	assert_eq(_ids(fixture),
		["oldest", "tie_a", "tie_b", "newest"] as Array[String])


func test_mailbox_sort_ignores_rarity() -> void:
	# Arrange: rarity 反向 — F2-M 唔睇 rarity(同 F3 嘅本質 divergence)。
	var fixture: Array = [
		StubItem.new(&"legendary_new", 4, 200),
		StubItem.new(&"common_old", 0, 100),
	]
	fixture.sort_custom(InvUiFormulas.mailbox_before)
	assert_eq(_ids(fixture), ["common_old", "legendary_new"] as Array[String],
		"acquired asc 唯一主軸 — rarity 完全唔入 comparator")


func test_mailbox_sort_shuffle_convergence_strict_total_order() -> void:
	# Arrange: 3 個手寫 permutation(deterministic — 禁 RNG)同一 fixture。
	var golden: Array[String] = ["w", "x", "y", "z"]
	var perms: Array = [
		[StubItem.new(&"z", 0, 400), StubItem.new(&"w", 0, 100),
			StubItem.new(&"y", 0, 300), StubItem.new(&"x", 0, 200)],
		[StubItem.new(&"x", 0, 200), StubItem.new(&"z", 0, 400),
			StubItem.new(&"w", 0, 100), StubItem.new(&"y", 0, 300)],
		[StubItem.new(&"y", 0, 300), StubItem.new(&"x", 0, 200),
			StubItem.new(&"z", 0, 400), StubItem.new(&"w", 0, 100)],
	]
	# Act + Assert: 任意輸入序收斂同一 golden(strict total order — unique tie-break)。
	for perm: Array in perms:
		perm.sort_custom(InvUiFormulas.mailbox_before)
		assert_eq(_ids(perm), golden, "shuffle 收斂 byte-identical(AC-03)")
