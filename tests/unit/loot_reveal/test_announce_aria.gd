extends GutTest
## Story 025 (G-LM-6) — announce_aria gateway + AC-77 once-only + variants.
##
## GDD: design/gdd/loot-drop-modal.md G-LM-6 / UI §B slot 7 / §E Accessibility.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const PlatformScript := preload("res://src/autoload/platform_detect.gd")

const S := CoordinatorScript.ModalState


class FakePlatform:
	extends Node
	var announcements: Array[String] = []
	func announce_aria(text: String) -> void:
		announcements.append(text)


class MockGsm:
	extends Node
	signal state_changed(from_state, to_state, payload)
	var current_state: int = 2
	func get_current_state() -> int:
		return current_state
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func go(to_state: int) -> void:
		var from: int = current_state
		current_state = to_state
		state_changed.emit(from, to_state, null)


class MockLootSystem:
	extends Node
	signal loot_dropped(drop_id: String, rarity_tier: String, item_type: String, transition_id: String)
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending


var _gsm: MockGsm
var _loot: MockLootSystem
var _platform: FakePlatform


func _drop(id: String, tier_name: String, name_str: String = "Test Item") -> LootDrop:
	var d := LootDrop.new()
	d.drop_id = id
	d.rarity_tier = tier_name
	d.source_event_kind = "MINI_BOSS"
	d.item_metadata = {"item_name": name_str}
	return d


func _make() -> Node:
	_gsm = MockGsm.new()
	_loot = MockLootSystem.new()
	_platform = FakePlatform.new()
	for n: Node in [_gsm, _loot, _platform]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = _gsm
	c._loot_system = _loot
	c._platform = _platform
	add_child_autofree(c)
	return c


# --- Gateway(native no-op + append-log) ---

func test_gateway_logs_announcements_native_noop() -> void:
	var p: Node = PlatformScript.new()
	add_child_autofree(p)
	p.announce_aria("hello")
	assert_eq(p.get_aria_announcements(), ["hello"], "headless/native — append-log,零 JS eval")


# --- AC-77: S3 exactly-once;fast-complete 唔 double ---

func test_natural_s3_announces_exactly_once() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("a1", "RARE", "Iron Blade")]
	_gsm.go(7)
	for i: int in range(3):
		c._process(0.5)
	assert_eq(c.get_fsm_state(), S.STEADY)
	assert_eq(_platform.announcements.size(), 1, "S3 entry fire 一次")
	assert_string_contains(_platform.announcements[0], "RARE loot: Iron Blade", "格式:[Rarity] loot: [Name]")
	c._process(1.0)
	assert_eq(_platform.announcements.size(), 1, "S3 期間唔重播")


func test_fast_complete_does_not_double_announce() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("a2", "LEGENDARY")]
	_gsm.go(7)
	c._process(0.5)
	c.handle_tap()   # fast-complete
	c._process(0.1)  # → S3
	assert_eq(_platform.announcements.size(), 1, "fast-complete 入 S3 唔 double-announce")


# --- intra-queue short variant ---

func test_second_reveal_in_chain_uses_short_variant() -> void:
	var c: Node = _make()
	_loot.pending = [_drop("c1", "COMMON", "First"), _drop("c2", "RARE", "Second")]
	_gsm.go(7)
	c._process(0.25)  # S3 件 1(full format)
	c._process(0.3)
	c.handle_tap()
	c._process(0.2)   # S4 → gap
	c._process(0.3)   # gap → 件 2 ENTRY
	for i: int in range(3):
		c._process(0.5)  # 件 2 S3
	assert_eq(_platform.announcements.size(), 2)
	assert_string_contains(_platform.announcements[0], "loot:", "首件 full read")
	assert_eq(_platform.announcements[1], "RARE:Second", "第二件 short variant(assertive 互斬)")


# --- catch-up: stream 零 announce,grid aggregate 一次 ---

func test_catchup_stream_silent_grid_aggregates_once() -> void:
	var c: Node = _make()
	for i: int in range(6):
		_loot.pending.append(_drop("s%d" % i, "COMMON"))
	_gsm.go(7)
	c.handle_tap()   # reveal-all → stream(6 sub-RARE,零 RARE+)
	c._process(0.3)
	for i: int in range(8):
		c._process(0.15)
	assert_eq(c.get_fsm_state(), S.CATCHUP_GRID, "全 sub-RARE → grid")
	assert_eq(_platform.announcements.size(), 1, "stream 逐件零 announce;grid 一次 aggregate")
	assert_string_contains(_platform.announcements[0], "件 loot 已收", "aggregate 格式")
