## #22 Character Screen — F2/F3/F4 + Per-stat Format Table (story 005).
##
## GDD: design/gdd/character-screen.md §Formulas。
## 「Formatter 就係 epsilon」統一原則:所有 visibility/animation predicate
## 比較 formatted display 值 — F1(stat_tween.gd)/ F4 / zero-delta guard
## 全部建基於呢套 formatter。
##
## Pinned constants(明文非 knob):F2 1% quantize grid(label bijectivity)/
## F3 comparator 鏈(determinism)/ keyboard step 10 pct(P-07 binding)。
extends RefCounted

## ---- Per-stat Format Table (F1 fmt_s / F4 disp 嘅 shared dependency) ----
## STR/DEX/VIT/max_hp/attack_power/move_speed → roundi int;
## crit_chance → "%d%%" % roundi(x×100)。
## Sub-display-unit 變化由 formatter guard 自然吸收(零 phantom arrow)。

static func fmt_int(v: float) -> String:
	return str(roundi(v))


static func fmt_pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## stat_id → formatter Callable(story 009 binding 用).
static func formatter_for(stat_id: StringName) -> Callable:
	if stat_id == &"crit_chance":
		return fmt_pct
	return fmt_int


## ---- F2 — Settings slider quantization + percentage label ----
## guard: 非 (float|int) 或 !is_finite → default 1.0(sd B-2 — NaN 穿透
## clampf(IEEE 比較全 false)→ roundi(NaN) WASM trap;#6 boot self-read 係
## reject-and-retain,冇 guard 嘅話 label 同 consumer 實際值背離)。
## pct(int 0-100)係 UI canonical state — keyboard ±10 永不累積 float drift。

static func quantize(v_raw: Variant) -> Dictionary:
	var v: float
	var t: int = typeof(v_raw)
	if t == TYPE_FLOAT or t == TYPE_INT:
		v = float(v_raw)
		if not is_finite(v):
			v = 1.0  # documented default (Rule 28)
	else:
		v = 1.0  # corrupt persist class (String 等) — documented default
	var pct: int = roundi(clampf(v, 0.0, 1.0) * 100.0)
	return {
		"pct": pct,
		"store": float(pct) / 100.0,
		"label": "%d%%" % pct,
	}


## keyboard ±0.1 step(P-07 binding)— clamp no-op 唔 wrap(EC-28).
static func keyboard_step(pct: int, direction: int) -> int:
	return clampi(pct + (10 * signi(direction)), 0, 100)


## ---- F3 — Picker sort comparator(strict total order)----
## rarity desc → acquired desc(新先 — browse recency;**intentional
## divergence** from #17 _candidate_beats 嘅 asc 舊先 L786-796,兩個
## comparator 服務唔同目的)→ item_id asc final tie-break(同秒 batch
## grant 係常態,item_id unique ⇒ byte-identical determinism)。
## 對任意 int acquired_at_unix robust(0/負數照 strict total order)。

static func picker_before(a, b) -> bool:
	if a.rarity != b.rarity:
		return a.rarity > b.rarity                      # 1. rarity desc
	if a.acquired_at_unix != b.acquired_at_unix:
		return a.acquired_at_unix > b.acquired_at_unix  # 2. acquired desc(新先)
	return String(a.item_id) < String(b.item_id)        # 3. item_id asc(final)


## ---- F4 — AntiSnowball badge visibility predicate ----
## disp = roundi(badge 文案同一個 formatter — formatter 就係 epsilon)。
## clamp + roundi monotonic ⇒ disp(effective) ≤ disp(raw) 永真;
## badge 出現 ⇔ 文案兩個數字唔同 ⇔ 文案有意義(構造等價)。

static func badge_visible(raw: float, effective: float) -> bool:
	return roundi(raw) > roundi(effective)


static func badge_text(raw: float, effective: float) -> String:
	return "+%d / +%d(受真身上限約束)" % [roundi(effective), roundi(raw)]


## ---- AC-43a — CJK font floor guard ----
## accessibility-requirements.md L87:CJK body 12px Zpix floor。
## UI theme resource 未起(visual skin 隨 /asset-spec → UI build,#21 先例)—
## 呢個 guard 係 build 時嘅 single source;theme 落地後 AC-43a test 擴展到
## introspect theme resource 每個 font size 經呢個 clamp。

const CJK_FONT_FLOOR_PX: int = 12


static func clamp_font_size(requested_px: int) -> int:
	return maxi(requested_px, CJK_FONT_FLOOR_PX)


## ---- AC-45a — touch target floor(UI Requirements ≥48px)----
## Skin/scene 落地後(/asset-spec → UI build)AC-45a test 擴展 walk 全
## interactive Control tree assert custom_minimum_size ≥ 呢個 const;
## guard 係 build 時 single source(AC-43a 同款 pattern)。

const MIN_TAP_TARGET_PX: int = 48


static func clamp_tap_target(requested_px: int) -> int:
	return maxi(requested_px, MIN_TAP_TARGET_PX)
