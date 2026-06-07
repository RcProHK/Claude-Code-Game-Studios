extends GutTest
## Story 022 (G-LM-2) — #5 LOOT pool reparent + PROCESS_MODE_ALWAYS handshake.
## Covers AC-75(property assert — visual 半邊 AC-87 @ 027)。
##
## GDD: design/gdd/loot-drop-modal.md G-LM-2 / Interactions #5 row.

const CoordinatorScript := preload("res://src/autoload/loot_reveal_coordinator.gd")
const WrapperScript := preload("res://src/autoload/particle_system_wrapper.gd")


class StubParticleNode:
	extends Node2D
	var amount: int = 0
	var emitting: bool = false


var _wrapper: Node


func _make_wrapper() -> Node:
	_wrapper = WrapperScript.new()
	_wrapper._node_factory = func() -> Node:
		return StubParticleNode.new()
	add_child_autofree(_wrapper)
	return _wrapper


func _large_nodes() -> Array:
	var out: Array = []
	for slot in _wrapper._pool:
		if slot.tier == "LARGE" and slot.node is Node:
			out.append(slot.node)
	return out


# --- AC-75: parent == CelebrationVFXLayer + PROCESS_MODE_ALWAYS(freeze 下) ---

func test_handshake_reparents_large_tier_with_always_mode() -> void:
	_make_wrapper()
	var c: Node = CoordinatorScript.new()
	c._particles = _wrapper
	add_child_autofree(c)  # _ready → register_celebration_layer
	var layer: CanvasLayer = c.get_celebration_vfx_layer()
	var nodes: Array = _large_nodes()
	assert_eq(nodes.size(), 2, "LOOT 專用 LARGE tier ×2")
	get_tree().paused = true  # freeze active(ceremony_freeze 語意)
	for n: Node in nodes:
		assert_eq(n.get_parent(), layer, "parent == CelebrationVFXLayer(>100 — saturation/shake immune)")
		assert_eq(n.process_mode, Node.PROCESS_MODE_ALWAYS, "freeze 期間 burst 照行")
	get_tree().paused = false
	# combat tiers 唔郁(deliberate 明度尺):
	for slot in _wrapper._pool:
		if slot.tier != "LARGE" and slot.node is Node:
			assert_eq((slot.node as Node).get_parent(), _wrapper, "SMALL/MEDIUM 留 layer 0")


func test_handshake_is_idempotent() -> void:
	_make_wrapper()
	var c: Node = CoordinatorScript.new()
	c._particles = _wrapper
	add_child_autofree(c)
	var layer: CanvasLayer = c.get_celebration_vfx_layer()
	_wrapper.register_celebration_layer(layer)  # 重複 register
	_wrapper.register_celebration_layer(layer)
	for n: Node in _large_nodes():
		assert_eq(n.get_parent(), layer, "repeat register = no-op,零 reparent churn")


func test_lazy_built_large_tier_lands_on_the_layer() -> void:
	_make_wrapper()
	# 模擬 EC1 deferred LARGE:清走 LARGE slots 再 lazy build
	_wrapper._skip_tier_for_test = "LARGE"
	_wrapper._teardown_pool_for_test() if _wrapper.has_method("_teardown_pool_for_test") else null
	_wrapper._build_pool()
	var c: Node = CoordinatorScript.new()
	c._particles = _wrapper
	add_child_autofree(c)  # handshake while LARGE absent
	_wrapper._lazy_build_tier_if_absent("LARGE")
	for n: Node in _large_nodes():
		assert_eq(n.get_parent(), c.get_celebration_vfx_layer(),
			"post-handshake lazy build 都落 layer(EC1 covered)")
		assert_eq(n.process_mode, Node.PROCESS_MODE_ALWAYS)
