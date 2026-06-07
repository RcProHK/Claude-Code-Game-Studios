## SfxCatalog — #4 AudioManager cue registry carrier (story 023 / G-LM-8).
##
## AudioManager._build_catalog_dict consumes `entries`: an Array of
## { event_id: String, priority: int (SfxPriority ordinal), channels: String,
##   duck: String, stream: AudioStream }.
## The BINDING cue freeze table (event ids / priorities / duck classes) lives
## in design/gdd/audio-manager.md (G-LM-8 appendix); the .tres instance is
## produced by /asset-spec once the audio assets exist — shipping a streamless
## catalog would flip #4 out of safe no-op mode for nothing.
class_name SfxCatalog
extends Resource

@export var entries: Array[Dictionary] = []
