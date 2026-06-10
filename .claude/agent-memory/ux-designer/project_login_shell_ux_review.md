---
name: project-login-shell-ux-review
description: #24 Login/Shell GDD adversarial UX review — 3 BLOCKING; canvas-DOM-invisibility applies to ARIA not just autofill; Z5/Z6 collision verified real
metadata:
  type: project
---

#24 Login / GymSys Connection UI (`design/gdd/login-gymsys-connection-ui.md`) adversarial UX review，2026-06-08。Verdict: NEEDS REVISION — 3 BLOCKING / 5 RECOMMENDED / 5 NICE-TO-HAVE。

**BLOCKING（可複用 pattern）**:
- BF-1 Bottom-region 三方併發撞（#20 Z5 REST panel + Z6 silent toast + #24 banner）。defer 去 /ux-design 不足:缺 GDD-level 併發矩陣 + arbitration 原則。**Layer 111 ALWAYS = 隱性「#24 永遠 occlude #20 bottom」裁決冇人揀過**。讓位係 Pillar tension 抉擇(誠實 visibility vs glance protocol)屬 GDD/CD 唔屬 layout。
- BF-2 **canvas-DOM 隱形同樣適用 ARIA,唔淨係 password manager**。GDD 對 autofill 誠實(Rule 13 canvas 對 DOM 隱形)但對 ARIA live assertive/polite 假設一個無證據機制 = 雙標。Godot 4.5+ AccessKit web adapter post-cutoff 未證實;且 a11y 承諾**零 AC coverage**(AC-43..49 冇一條驗 SR/VoiceOver)。誠實 fantasy 系統反而對 SR user 失守。
- BF-3 directional debounce held-ENABLED window × EC-E4 reject × Honest Door Test 4 = 內部矛盾(防 flicker 嘅 debounce 親手整一道講大話嘅門)。reinforce systems/qa 雙命中。

**Verify lesson**: #24 cite「#20 Z5/Z6」—— #20 GDD 本體**冇** Z5/Z6 命名(L438 自己 defer region),但 #20 UX spec `design/ux/gym-mode-hud.md` L118(Z5 bottom slide-up)/L119(Z6 bottom-center toast)**真有**。citation source 係 ux spec 唔係 GDD,但 ground truth 存在 → citation 準確。**review presentation-tier GDD 嘅 region claim,要 grep 埋對應 ux spec 唔淨係 GDD**。

關聯: [[project_gym_mode_hud_ux_review]](#20 同源 bottom-region + glance protocol); [[project_character_screen_ux_review]](ARIA finding 先例)。
