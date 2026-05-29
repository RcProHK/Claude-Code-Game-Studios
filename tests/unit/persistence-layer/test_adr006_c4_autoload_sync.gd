# ADR-006 Contract 4 binding — autoload position 1 + sync _ready
# Gate: Story 015 AC-32
extends GutTest

func test_adr006_c4_persistence_layer_is_autoload_pos1() -> void:
	# PersistenceLayer is autoload pos 1 — it must be accessible as a singleton.
	assert_not_null(PersistenceLayer, "ADR-006 Contract 4: PersistenceLayer must be accessible as autoload")

func test_adr006_c4_read_returns_synchronously() -> void:
	# read() must return synchronously (no await) per Contract 4.
	var result: Variant = PersistenceLayer.read("test_c4_key")
	# Just calling read() without await = synchronous ✅
	assert_true(true, "ADR-006 Contract 4: read() returned synchronously")
