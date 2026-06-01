class_name ParticleHandle
extends RefCounted
## A lightweight, fire-and-forget reference to a particle burst issued via
## `ParticleSystemWrapper.play()`. RefCounted — the caller drops the reference and
## it frees automatically; the wrapper holds NO strong reference to the handle
## (GDD Rule 3). The pool slot only records `generation` + `is_emitting`.
##
## Generation counter prevents the stale-handle bug: each pool slot owns a
## monotonic `generation`; `play()` bumps it on acquire and snapshots it into the
## handle. After a slot is reused (stop/reclaim or LRU evict in Story 004) the
## snapshot no longer matches the live slot generation, so `alive()` returns false
## even though the slot now drives a different preset.
##
## Story 001 — play() API + ParticleHandle contract. Governing ADR-0001 / ADR-0006.
## Driving GDD: design/gdd/particle-system-wrapper.md (Rule 1/2/3, Approved 2026-05-26).

## Singleton sentinel returned by `play()` on ANY rejection (invalid args, pool full,
## non-Active lifecycle). `alive()` is always false; it never drives a real slot.
## `static var` (not `const`) because a RefCounted instance is not a constant
## expression — defaults make it dead: `_slot == null`, `_pool_index == -1`.
static var INVALID: ParticleHandle = ParticleHandle.new()

## Monotonic id assigned by the wrapper on a successful play(); the CPU ledger key
## (Story 003) and the re-entry PENDING marker base (Story 006). -1 on INVALID.
var handle_id: int = -1

## PresetId value (`ParticleSystemWrapper.PresetId`) this burst was issued for.
## Typed `int` to keep this value type decoupled from the wrapper's inner enum
## (untyped-seam convention). -1 on INVALID.
var preset_id: int = -1

## `Time.get_ticks_msec()` captured at the `play()` call. 0 on INVALID.
var spawn_time_ms: int = 0

## True if the burst count was auto-downscaled. Always false in v1 (Tier-1
## auto-downscale rejected per GDD Rule 9). Reserved for forward compatibility.
var was_downscaled: bool = false

## Index into the wrapper pool. -1 = INVALID, or a PENDING re-entry placeholder
## (Story 006 re-entry guard).
var _pool_index: int = -1

## Generation snapshot taken when the slot was acquired.
var _generation: int = 0

## Back-reference to the owning pool slot (`ParticleSystemWrapper.PoolSlot` — held
## untyped per the DI-seam convention so this value type stays decoupled from the
## wrapper's inner class). null on INVALID / PENDING.
var _slot = null


## True only while this handle's generation snapshot still matches the live slot
## generation. Returns false for INVALID, PENDING, and any slot reused since acquire.
func alive() -> bool:
	return _slot != null and _slot.generation == _generation


## Last emit position recorded on the owning slot (GDD Rule 3). Zero on INVALID.
func position() -> Vector2:
	if _slot == null:
		return Vector2.ZERO
	return _slot.last_position


## Actively stop this burst. `fade == true` lets existing particles decay
## naturally (stops new emission); `fade == false` is treated the same in v1
## (hard-clear refinement deferred). No-op if not alive. Releasing the slot back
## to the free list is handled lazily by the wrapper on next acquire (Story 001);
## forced eviction is Story 004.
func stop(_fade: bool = true) -> void:
	if not alive():
		return
	_slot.is_emitting = false
	if _slot.node != null:
		_slot.node.emitting = false
