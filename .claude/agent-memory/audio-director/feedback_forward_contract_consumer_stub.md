---
name: forward-contract-consumer-stub
description: forward-contract 把 co-design 推去未來時,若決定會改變 consumer 實作形狀(如 CR-11 同幀假設 vs correlation-key 匹配),consumer GDD 須留 conditional handling stub,否則 = 不可實作 = BLOCKING
metadata:
  type: feedback
---

review consumer-side audio GDD(如 #20 Gym-Mode HUD)嘅 forward-contract 時:當一個 Open Question 用 forward-contract「co-design 須包含 X requirement」推去未來,**唔可只 spec upstream(#8)側 requirement 而留空 consumer(#20)側**——若該 co-design 決定會**改變 consumer 實作形狀**,consumer GDD 必須留 conditional handling stub(if-route-A-then-X / if-route-B-then-Y)。

**Why**:#20 R7 Q-OQ1 補咗 forward-contract「#8 須帶 correlation key OR 承諾同幀 emit」,但 CR-11(L121)只 spec「同幀並存 → defer streak_chime」,假設咗「同幀」前提。若 #8 揀 correlation-key 路線,CR-11 同幀假設失效:streak_chime 可能遲一 polling cycle 到,#20 要按 key 匹配返 source set_complete,但 GDD 冇講匹配窗口 / unmatched key / set_complete 已播完後 chime 先到嘅 stagger 仲成唔成立。EC-A2 只 cover 單獨 chime 即播,唔 cover 帶 key 延遲到達。forward-contract 把會改變 #20 實作分叉嘅決定推去未來但 consumer 側零 conditional spec = dev 入 sprint 無法實作 CR-11(BLOCKING AC)= 真不可實作。

**How to apply**:任何 forward-contract 推遲 co-design 嘅 audio Q,問:「呢個 co-design 嘅兩條路線會唔會令 consumer 寫唔同 code?」若會 → consumer GDD 須有 conditional stub 覆蓋每條路線,否則升 BLOCKING(若卡住 BLOCKING AC)。對照:純 upstream-shape 決定(如 #8 內部點計 streak)consumer 唔使分叉,forward-contract 足夠 = ADVISORY。關聯 [[consumer-forward-contract]](consumer 可 own 淨效果斷言)嘅另一面:own 淨效果唔代表可以唔 spec 實作分叉。

關聯 [[audio-manager-priority-steal]]、[[resolved-ref-sweep]]。
