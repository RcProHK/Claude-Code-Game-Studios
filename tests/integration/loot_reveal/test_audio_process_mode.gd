extends GutTest
## Story 023 (G-LM-8+9) — #4 fanfare caller + toast tick + process-mode property.
## Covers AC-76 / AC-76b(perceptual 半邊 AC-88 @ 027)。

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const AudioManagerScript := preload("res://src/autoload/audio_manager.gd")


class FakeAudio:
	extends Node
	var sfx_calls: Array = []
	func play_sfx(event_id: StringName) -> void:
		sfx_calls.append(event_id)


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
	signal loot_micro_ack(drop_id: String)
	var drops: Dictionary = {}
	var pending: Array = []
	func get_pending_drops() -> Array:
		return pending
	func get_drop(drop_id: String) -> LootDrop:
		return drops.get(drop_id)


class FakeInventory:
	extends Node
	func receive_loot(_record) -> int:
		return EquipmentEnums.ReceiveResult.OK


# --- AC-76b: property assert — engine pause 唔殺 audio/coordinator ---

func test_audio_manager_and_coordinator_are_process_mode_always() -> void:
	var audio: Node = AudioManagerScript.new()
	add_child_autofree(audio)
	assert_eq(audio.process_mode, Node.PROCESS_MODE_ALWAYS,
		"AudioManager ALWAYS — fanfare 喺 ceremony_freeze 期間唔俾 engine pause(G-LM-9)")
	var c: Node = CoordinatorScript.new()
	add_child_autofree(c)
	assert_eq(c.process_mode, Node.PROCESS_MODE_ALWAYS, "Coordinator ALWAYS")


# --- AC-76: fanfare caller = #21 @ S0;toast flush 配 tick 零 fanfare ---

func test_fanfare_at_s0_then_toast_flush_uses_tick_only() -> void:
	var gsm := MockGsm.new()
	var loot := MockLootSystem.new()
	var audio := FakeAudio.new()
	var inv := FakeInventory.new()
	for n: Node in [gsm, loot, audio, inv]:
		add_child_autofree(n)
	var c: Node = CoordinatorScript.new()
	c._gsm = gsm
	c._loot_system = loot
	c._audio = audio
	c._inventory = inv
	add_child_autofree(c)
	var d := LootDrop.new()
	d.drop_id = "fan_1"
	d.rarity_tier = "LEGENDARY"
	loot.pending = [d]
	gsm.go(7)
	assert_eq(audio.sfx_calls[0], &"loot_fanfare_legendary",
		"caller = #21 coordinator @ S0 frame(EG-1 — #15 唔 call play_sfx)")
	# micro_ack → deferred → safe-state flush 配 tick:
	gsm.current_state = 7
	var m := LootDrop.new()
	m.drop_id = "m_1"
	m.rarity_tier = "COMMON"
	loot.drops["m_1"] = m
	loot.loot_micro_ack.emit("m_1")
	# close modal(natural → dismiss → terminal):
	for i: int in range(4):
		c._process(0.5)
	c._process(0.3)
	c.handle_tap()
	c._process(0.2)
	gsm.current_state = 2  # safe
	var calls_before_flush: int = audio.sfx_calls.size()
	c._process(0.15)  # FLUSH_DELAY → toast + tick
	var new_calls: Array = audio.sfx_calls.slice(calls_before_flush)
	assert_true(&"loot_toast_tick" in new_calls, "toast flush 配 tick(low/mono)")
	for ev: StringName in new_calls:
		assert_false(String(ev).begins_with("loot_fanfare"),
			"零 fanfare/sting call — fanfare 家族 modal 獨家(#15 L204 erratum)")
