## SerializableResource — Tombstone envelope base class per ADR-0006 Contract 3
##
## ADR-0006 (Accepted 2026-05-28) Contract 3 (lines 172-270): any Resource that
## may be carried inside a `StateTransitionPayload.data` Dictionary AND therefore
## may end up serialized into `user://state.json` MUST extend this class and
## implement BOTH `to_dict()` AND `from_dict()`.
##
## WHY explicit dict envelope vs `var_to_bytes` + base64:
## IndexedDB devtools blob must remain human-readable for VS debugging — a binary
## payload turns schema migration into manual byte rewriting (ADR-0006 line 266).
##
## WHY keep Resource type in code (vs raw Dictionary throughout):
## Preserves IDE auto-complete + typed enum compare at call site (e.g.
## `outcome == BossOutcome.INTERRUPTED_WITH_CREDIT` instead of string compare
## with no IDE warning on typo — ADR-0006 line 268).
##
## Binding rule: subclasses MUST override BOTH methods. Default impls push_error
## so a missing override fails fast in debug builds rather than silently
## round-tripping to null.
##
## Static analyzer (ADR-0006 Contract 12, future) will scan `extends Resource`
## declarations reachable from `StateTransitionPayload.data` usage paths and
## flag any class missing a `to_dict` override.
class_name SerializableResource extends Resource


## Override in subclasses to convert this resource to a plain Dictionary
## suitable for `JSON.stringify` round-trip via PersistenceLayer.
##
## Implementations MUST emit enum values as their string name (use
## `MyEnum.find_key(value)` per Godot 4.4+ API — ADR-0006 line 205) so the
## tombstone JSON remains human-readable in IndexedDB devtools.
func to_dict() -> Dictionary:
	push_error("SerializableResource.to_dict() not overridden by %s" % get_class())
	return {}


## Override in subclasses. Reconstructs the resource from a Dictionary produced
## by `to_dict()`. MUST be defensive against missing keys (use
## `data.get(key, default)`) since tombstones may originate from older schema
## versions before migration completes.
static func from_dict(_data: Dictionary) -> SerializableResource:
	push_error("SerializableResource.from_dict() not overridden")
	return null
