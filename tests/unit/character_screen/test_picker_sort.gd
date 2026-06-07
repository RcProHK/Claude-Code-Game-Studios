## #22 F3 picker sort comparator — unit suite (story 005; GDD AC-07).
extends GutTest

const F := preload("res://src/ui/character_screen/char_screen_formulas.gd")


class StubItem:
	var rarity: int
	var acquired_at_unix: int
	var item_id: StringName

	func _init(r: int, t: int, id: StringName) -> void:
		rarity = r
		acquired_at_unix = t
		item_id = id


## GDD golden vector:(EPIC=3,t=1000,sword_a)(EPIC,1000,axe_b)(RARE=2,2000,bow_c)
## → [axe_b, sword_a, bow_c](EPIC 同秒 "axe_b"<"sword_a" 字典序;RARE 雖新 rarity 行先)

func test_ac07_golden_vector() -> void:
	var sword := StubItem.new(3, 1000, &"sword_a")
	var axe := StubItem.new(3, 1000, &"axe_b")
	var bow := StubItem.new(2, 2000, &"bow_c")
	var items := [sword, axe, bow]
	items.sort_custom(F.picker_before)
	assert_eq(items[0].item_id, &"axe_b")
	assert_eq(items[1].item_id, &"sword_a")
	assert_eq(items[2].item_id, &"bow_c")


func test_ac07_byte_identical_determinism() -> void:
	# 任意初始排列 → 同一結果(strict total order,zero residual tie)
	var permutations := [
		[&"sword_a", &"axe_b", &"bow_c"],
		[&"bow_c", &"sword_a", &"axe_b"],
		[&"axe_b", &"bow_c", &"sword_a"],
	]
	var meta := {&"sword_a": [3, 1000], &"axe_b": [3, 1000], &"bow_c": [2, 2000]}
	for perm in permutations:
		var items := []
		for id in perm:
			items.append(StubItem.new(meta[id][0], meta[id][1], id))
		items.sort_custom(F.picker_before)
		var ids := items.map(func(i): return i.item_id)
		assert_eq(ids, [&"axe_b", &"sword_a", &"bow_c"], "byte-identical from %s" % str(perm))


func test_edge_rarity_dominates_recency() -> void:
	var old_epic := StubItem.new(3, 1, &"old_epic")
	var new_common := StubItem.new(0, 99999, &"new_common")
	assert_true(F.picker_before(old_epic, new_common), "rarity desc 行先")


func test_edge_acquired_desc_within_rarity() -> void:
	var newer := StubItem.new(2, 2000, &"z_newer")
	var older := StubItem.new(2, 1000, &"a_older")
	assert_true(F.picker_before(newer, older), "同 rarity 新先(desc — intentional divergence from #17 asc)")


func test_edge_zero_and_negative_timestamps_robust() -> void:
	# acquired_at_unix 0/負數(corrupt persist class)照 strict total order
	var a := StubItem.new(1, 0, &"a")
	var b := StubItem.new(1, -5, &"b")
	var items := [b, a]
	items.sort_custom(F.picker_before)
	assert_eq(items[0].item_id, &"a", "0 > −5 → a 先(int 比較 robust,零 degenerate)")


func test_edge_empty_and_single() -> void:
	var empty := []
	empty.sort_custom(F.picker_before)
	assert_eq(empty.size(), 0)
	var one := [StubItem.new(0, 1, &"only")]
	one.sort_custom(F.picker_before)
	assert_eq(one[0].item_id, &"only")
