class_name PixelArtImportPreset extends Resource
## Canonical pixel-art texture import settings for Mirror Hero (art-bible §8.D D.1, HARD).
## ALL sprite `.png` imports MUST match these four values.
##
## This Resource is the single documented source-of-truth for the preset. It does NOT
## auto-apply to imports by itself — Godot's actual reusable-import mechanism is the
## Import dock ("Preset ▾ → Save as Default for PNG") which writes `[importer_defaults]`
## into `project.godot`. Workflow: open any sprite `.png` in the Import dock, set the
## four values below, then "Save as Default for PNG" so every subsequent sprite inherits
## them. `tools/ci/asset_validator.gd` checks (Warning tier) that imported sprites carry
## these settings, and references this file as the canonical spec.
##
## Rationale per art-bible §8.D:
##   Filter = Nearest      → Linear filter makes pixel art blurry → reject
##   Mipmaps = Off         → 2D doesn't need them; wastes 33% VRAM
##   Compression = Lossless→ "VRAM Compressed" has artifacts under Web Compatibility renderer
##   Fix Alpha Border = On → prevents atlas texture bleeding
##
## Governing: design/art/art-bible.md §8.D D.1; ADR-0001 (web export budget caps).

@export var texture_filter: String = "Nearest"     ## Import dock → "Filter": Nearest (NOT Linear)
@export var mipmaps_generate: bool = false          ## Import dock → "Mipmaps/Generate": Off
@export var compression_mode: String = "Lossless"   ## Import dock → "Compress/Mode": Lossless
@export var fix_alpha_border: bool = true           ## Import dock → "Process/Fix Alpha Border": On
