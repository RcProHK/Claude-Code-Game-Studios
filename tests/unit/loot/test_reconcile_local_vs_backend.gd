## test_reconcile_local_vs_backend.gd — Story 006 AC-09
##
## Governing story: production/epics/loot-drop-system/story-006-formula-5-6-reconcile-catchup.md
## Governing ADR  : ADR-0003 (Accepted 2026-05-30) Save State Strategy
##
## AC-09: reconcile_local_vs_backend() must produce three pairwise-disjoint output
## sets (CF-4) from the GDD-specified 4-entry worked example and handle edge cases
## (empty inputs, fully matching inputs, etc.).
extends GutTest


# ── AC-09: GDD 4-entry worked example ─────────────────────────────────────────

func test_ac09_gdd_worked_example_to_enqueue() -> void:
	# GDD AC-09 canonical worked example.
	# local_pending=[T-103], local_revealed=[T-101], backend_pending=[T-100,T-101,T-102]
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		["T-103"],           # local_pending
		["T-101"],           # local_revealed
		["T-100", "T-101", "T-102"]  # backend_pending
	)
	var enqueue: Array = result["to_enqueue"]
	# T-100 and T-102 are in backend but neither pending nor revealed locally.
	assert_eq(enqueue.size(), 2, "to_enqueue must have 2 entries (T-100, T-102)")
	assert_true("T-100" in enqueue, "T-100 must be in to_enqueue")
	assert_true("T-102" in enqueue, "T-102 must be in to_enqueue")


func test_ac09_gdd_worked_example_to_ack_only() -> void:
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		["T-103"], ["T-101"], ["T-100", "T-101", "T-102"]
	)
	var ack_only: Array = result["to_ack_only"]
	# T-101 is in backend AND locally revealed → ACK only.
	assert_eq(ack_only.size(), 1, "to_ack_only must have 1 entry (T-101)")
	assert_true("T-101" in ack_only, "T-101 must be in to_ack_only")


func test_ac09_gdd_worked_example_to_discard_local() -> void:
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		["T-103"], ["T-101"], ["T-100", "T-101", "T-102"]
	)
	var discard: Array = result["to_discard_local"]
	# T-103 is locally pending but NOT in backend → discard.
	assert_eq(discard.size(), 1, "to_discard_local must have 1 entry (T-103)")
	assert_true("T-103" in discard, "T-103 must be in to_discard_local")


func test_ac09_cf4_pairwise_disjoint_no_overlap() -> void:
	# Verify the three sets share no transition_id (CF-4 invariant).
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		["T-103"], ["T-101"], ["T-100", "T-101", "T-102"]
	)
	var enqueue: Array = result["to_enqueue"]
	var ack_only: Array = result["to_ack_only"]
	var discard: Array = result["to_discard_local"]

	for t: String in enqueue:
		assert_false(t in ack_only,
			"CF-4: '%s' must not appear in both to_enqueue and to_ack_only" % t)
		assert_false(t in discard,
			"CF-4: '%s' must not appear in both to_enqueue and to_discard_local" % t)
	for t: String in ack_only:
		assert_false(t in discard,
			"CF-4: '%s' must not appear in both to_ack_only and to_discard_local" % t)


# ── Edge cases ────────────────────────────────────────────────────────────────

func test_empty_all_inputs_produce_empty_outputs() -> void:
	var result := LootReconcileCalc.reconcile_local_vs_backend([], [], [])
	assert_eq((result["to_enqueue"] as Array).size(), 0, "empty input → empty to_enqueue")
	assert_eq((result["to_ack_only"] as Array).size(), 0, "empty input → empty to_ack_only")
	assert_eq((result["to_discard_local"] as Array).size(), 0, "empty input → empty to_discard_local")


func test_backend_only_items_all_go_to_enqueue() -> void:
	# Nothing locally pending or revealed → everything backend has goes to enqueue.
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		[], [], ["T-A", "T-B", "T-C"]
	)
	var enqueue: Array = result["to_enqueue"]
	assert_eq(enqueue.size(), 3, "3 backend-only items → 3 in to_enqueue")
	assert_eq((result["to_ack_only"] as Array).size(), 0)
	assert_eq((result["to_discard_local"] as Array).size(), 0)


func test_local_pending_matches_backend_no_enqueue_no_discard() -> void:
	# local_pending = backend_pending → everything is already in sync.
	# Nothing to enqueue (client has it), nothing to discard (backend knows it),
	# nothing to ack_only (not in local_revealed).
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		["T-X", "T-Y"], [], ["T-X", "T-Y"]
	)
	assert_eq((result["to_enqueue"] as Array).size(), 0)
	assert_eq((result["to_ack_only"] as Array).size(), 0)
	assert_eq((result["to_discard_local"] as Array).size(), 0)


func test_local_pending_not_in_backend_all_discarded() -> void:
	# Client has pending items the server no longer knows about → discard all.
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		["T-orphan-1", "T-orphan-2"], [], []
	)
	var discard: Array = result["to_discard_local"]
	assert_eq(discard.size(), 2)
	assert_true("T-orphan-1" in discard)
	assert_true("T-orphan-2" in discard)


func test_local_revealed_in_backend_all_ack_only() -> void:
	# Client has already revealed everything backend lists → ACK only, no re-reveal.
	var result := LootReconcileCalc.reconcile_local_vs_backend(
		[], ["T-revealed-1", "T-revealed-2"], ["T-revealed-1", "T-revealed-2"]
	)
	var ack_only: Array = result["to_ack_only"]
	assert_eq(ack_only.size(), 2)
	assert_eq((result["to_enqueue"] as Array).size(), 0)
	assert_eq((result["to_discard_local"] as Array).size(), 0)


func test_result_dict_has_all_three_keys() -> void:
	var result := LootReconcileCalc.reconcile_local_vs_backend([], [], [])
	assert_true(result.has("to_enqueue"), "result must have key 'to_enqueue'")
	assert_true(result.has("to_ack_only"), "result must have key 'to_ack_only'")
	assert_true(result.has("to_discard_local"), "result must have key 'to_discard_local'")
