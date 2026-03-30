# REACTION POINT INDICATOR — IMPLEMENTATION PROMPTS
## Thực thi từng phần, mỗi prompt 1 session riêng

**Thứ tự bắt buộc:** P1 > P2 > P3 > P4 > P5 > P6 > P7
(P1-P3 có thể song song, P4 cần P3, P5 cần P1+P2+P3, P6+P7 cần tất cả)

---

## PROMPT 1: RP_Confluence.mqh (Module D)

```
Tạo file MQL5/Include/ReactionPoint/RP_Confluence.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_CONFLUENCE_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs cần khai báo:
  extern bool Use_Confluence_Zones;

FILE NÀY DÙNG CÁC GLOBALS ĐÃ KHAI BÁO TRONG RP_Utils.mqh:
  - g_rp_array[], g_rp_count (SReactionPoint array)
  - g_confluence_array[], g_confluence_count, g_next_confluence_id (SConfluenceZone array)
  - g_htf_bars_to_scan, g_confluence_merge_pips
  - g_htf_1, g_htf_2 (ENUM_TIMEFRAMES)
  - PipsToPrice(), PriceToPips(), PipValue()

STRUCTS ĐÃ DEFINED (trong RP_Defines.mqh):
  SReactionPoint { id, rp_type, price, zone_high, zone_low, source_tf, final_score, is_active, is_confluence, confluence_id, ... }
  SConfluenceZone { id, zone_high, zone_low, center_price, rp_count, rp_ids[10], zone_type, multiplier, bonus, final_score, tf_description, is_premium }

CONSTANTS: MAX_CONFLUENCE=50, MAX_HTF_RETRIES=3, SCORE_CAP=150.0

=== LOGIC CẦN IMPLEMENT ===

1. CollectHTFReactionPoints():
   - Scan HTF_1 và HTF_2 cho swing points (giống DetectSwingPoints nhưng trên HTF)
   - Dùng iHigh/iLow/iClose/iOpen với timeframe parameter
   - Retry tối đa MAX_HTF_RETRIES nếu data chưa ready (Bars() < minimum)
   - Fallback: chỉ dùng current TF nếu fail

2. MergeClusterZones():
   - Reset confluence arrays
   - Gộp tất cả active RP (current TF + HTF)
   - 2 RP cách nhau <= g_confluence_merge_pips → merge vào 1 zone
   - Zone = range bao trùm tất cả RP trong group
   - zone_type = majority vote (đếm RP_SUPPORT vs RP_RESISTANCE)
   - final_score = highest score trong group
   - tf_description = "H1+H4+D1" (nối tên các TF)

   Multiplier & Bonus:
   - 2 RP: multiplier=1.3, bonus=10
   - 3 RP: multiplier=1.5, bonus=25
   - 4+ RP: multiplier=1.8, bonus=40, is_premium=true

   Cập nhật mỗi RP trong group:
   - rp.is_confluence = true
   - rp.confluence_id = zone.id

3. ApplyConfluenceScoring():
   - Cho mỗi confluence zone, apply lên RP có highest score:
   - adjusted = rp.final_score * zone.multiplier + zone.bonus
   - rp.final_score = MathMin(adjusted, SCORE_CAP)
   - Re-classify RP level

4. HandlePartialBreakout(int rp_id):
   - Khi 1 RP bị breakout → tách khỏi zone
   - rp.is_confluence = false, rp.confluence_id = -1
   - Giảm zone.rp_count
   - Recalc multiplier: 3→2: mult 1.5→1.3, bonus 25→10
   - Nếu còn 1 RP → giải tán zone hoàn toàn (is_confluence=false cho RP còn lại)

Lưu ý:
- Chỉ merge RP cùng type HOẶC gần nhau (khác type nhưng cùng giá thì KHÔNG merge)
- Confluence zone phải cập nhật khi RP mới được detect
```

---

## PROMPT 2: RP_EntrySetup.mqh (Module C)

```
Tạo file MQL5/Include/ReactionPoint/RP_EntrySetup.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_ENTRYSETUP_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs:
  extern bool   Show_Entry_Setup;
  extern double Min_RR_Ratio;

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - g_setup_array[], g_setup_count (SEntrySetup array)
  - g_current_regime, g_news_blackout, g_spread_blocked
  - g_sl_buffer_pips, g_entry_buffer_pips, g_max_setup_age_bars, g_min_score_to_show
  - PipsToPrice(), PriceToPips(), GetATR14()
  - MAX_SETUPS=10

STRUCTS (RP_Defines.mqh):
  SEntrySetup { rp_id, direction, entry_price, sl_price, tp1_price, tp2_price, rr_ratio1, rr_ratio2, sl_pips, tp1_pips, tp2_pips, bar_created, time_created, is_active, is_invalidated, is_triggered }
  ENUM_MARKET_REGIME: REGIME_CHOPPY

=== LOGIC ===

1. CheckEntryConditions():
   - Loop tất cả active RP có score >= g_min_score_to_show
   - Trigger conditions (TẤT CẢ phải true):
     a) Giá hiện tại (bar[1] close) trong zone (zone_low..zone_high)
     b) Bar[1] có candle pattern hợp lệ (gọi DetectCandlePattern(1) - extern function)
     c) g_current_regime != REGIME_CHOPPY (trừ Premium Confluence >=110)
     d) g_spread_blocked == false
     e) g_news_blackout == false
   - Nếu tất cả pass → gọi CreateEntrySetup()

2. CreateEntrySetup(int rp_index):
   - BUY (RP_SUPPORT):
     entry = iHigh(1) + PipsToPrice(g_entry_buffer_pips)
     sl = iLow(1) - PipsToPrice(g_sl_buffer_pips)
   - SELL (RP_RESISTANCE):
     entry = iLow(1) - PipsToPrice(g_entry_buffer_pips)
     sl = iHigh(1) + PipsToPrice(g_sl_buffer_pips)

   - TP1 = RP gần nhất phía trước (cùng chiều trade) có R:R >= Min_RR_Ratio
     Fallback: entry ± ATR(14)*2
   - TP2 = RP thứ 2 phía trước, fallback entry ± ATR(14)*4

   - Tính rr_ratio1, rr_ratio2, sl_pips, tp1_pips, tp2_pips

   - Max đồng thời: MAX_SETUPS. Khi đầy → thay setup có score thấp nhất
   - 2 setup cùng hướng → tag "PREFERRED" cho score cao hơn
   - 2 setup ngược hướng → warning "Conflicting setups"

3. UpdateSetups():
   - Gọi mỗi tick
   - Tự ẩn (is_active=false) khi:
     a) Quá g_max_setup_age_bars bars
     b) SL bị phá (giá close vượt sl_price)
     c) Entry triggered (giá chạm entry_price → is_triggered=true)
   - is_invalidated=true khi SL phá

4. FindNearestRPInDirection(double from_price, ENUM_RP_TYPE direction, int skip_count):
   - Tìm RP active gần nhất theo hướng trade
   - BUY: tìm RP_RESISTANCE phía trên from_price
   - SELL: tìm RP_SUPPORT phía dưới from_price
   - skip_count: 0=gần nhất, 1=thứ 2
   - Return price hoặc 0 nếu không tìm thấy

Lưu ý: Anti-repainting - chỉ dùng bar[1] đã đóng, KHÔNG BAO GIỜ bar[0]
```

---

## PROMPT 3: RP_Stats.mqh (Module Performance)

```
Tạo file MQL5/Include/ReactionPoint/RP_Stats.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_STATS_MQH / #define / #endif
Include: "RP_Utils.mqh"

GLOBALS TỪ RP_Utils.mqh:
  - g_stats (SRPStats)
  - g_rp_array[], g_rp_count
  - g_current_session

STRUCT SRPStats { total_formed, total_reacted, total_broken, premium_formed, premium_reacted, level1_formed, level1_reacted, level2_formed, level2_reacted, london_formed, london_reacted, ny_formed, ny_reacted, asian_formed, asian_reacted, tracking_start }

=== LOGIC ===

1. InitStats():
   - Gọi g_stats.Init()
   - tracking_start = TimeCurrent()

2. OnRPFormed(int rp_index):
   - g_stats.total_formed++
   - Theo level: premium_formed++ / level1_formed++ / level2_formed++
   - Theo session formed: london_formed++ / ny_formed++ / asian_formed++

3. OnRPReacted(int rp_index):
   - Khi giá phản ứng >= min_move tại RP (bounce, không phá)
   - total_reacted++, theo level và session tương tự

4. OnRPBroken(int rp_index):
   - Khi RP bị breakout confirmed
   - total_broken++

5. UpdateStats():
   - Gọi mỗi nến mới
   - Scan tất cả active RP, check xem bar[1] có phản ứng hay phá không
   - Phản ứng = bar touch zone + close theo hướng phản ứng + move >= min_move
   - Phá = close vượt zone >= breakout_confirm_pips

6. GetHitRate(): double
   - return total_reacted / (total_reacted + total_broken)
   - Guard division by zero → return 0

7. GetLevelHitRate(ENUM_RP_LEVEL level): double
8. GetBestSession(): string + hit rate
9. GetWorstSession(): string + hit rate

10. FormatStatsString(): string
   - Format cho dashboard:
   "PERFORMANCE (since [date])
     Hit Rate: 67% (42/63)
     Premium: 78% (7/9) | Lv1: 64% (18/28)
     Best: London Open 74% | Worst: Asian 41%"

KHÔNG lưu file. Reset khi indicator reload. Chỉ track bars đã chạy.
```

---

## PROMPT 4: RP_Drawing.mqh (UI Zones & Labels)

```
Tạo file MQL5/Include/ReactionPoint/RP_Drawing.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DRAWING_MQH / #define / #endif
Include: "RP_Defines.mqh"
Include: "RP_Utils.mqh"

Extern inputs:
  extern color Color_Premium, Color_Level1, Color_Level2, Color_Level3;
  extern color Color_Confluence, Color_RoleReversal;
  extern color Color_EntryBuy, Color_EntrySell;
  extern int   Label_Font_Size;

GLOBALS: g_rp_array[], g_rp_count, g_confluence_array[], g_confluence_count, g_object_count
CONSTANTS: OBJECT_PREFIX="RP_", MAX_CHART_OBJECTS=250

=== FUNCTIONS ===

1. GetRPColor(int rp_index): color
   - Role reversed → Color_RoleReversal
   - Confluence → Color_Confluence
   - Theo level: PREMIUM→Color_Premium, L1→Color_Level1, L2→Color_Level2, L3→Color_Level3

2. DrawRPZone(int rp_index):
   - OBJ_RECTANGLE, FILL=true, BACK=true, SELECTABLE=false
   - Từ time_formed đến TimeCurrent()+PeriodSeconds()*20
   - Border: STYLE_SOLID (Premium+L1), STYLE_DOT (L2+L3)
   - Opacity từ rp.display_opacity (dùng ColorWithOpacity)
   - Object name: OBJECT_PREFIX + "ZONE_" + IntegerToString(rp.id)

3. DrawConfluenceGlow(int conf_index):
   - Chỉ cho confluence có 3+ RP
   - 3 rectangle chồng:
     - Outer: zone ± 2pip, opacity 14% (86% transparent)
     - Middle: zone ± 1pip, opacity 30%
     - Core: zone gốc, opacity 50%
   - Color: Color_Confluence
   - Name prefix: OBJECT_PREFIX + "GLOW_"

4. DrawRPLabel(int rp_index):
   - OBJ_LABEL hoặc OBJ_TEXT
   - 2 dòng:
     Dòng 1: [icon] [score] [progress_bar] [TYPE]
     Dòng 2: [TF] | Tested:[n]x | [session] | [status]

   Icon: Premium="*", L1=hình vuông, L2=tam giác, L3=tròn
   Progress bar: score/150 * 12 chars (dùng ký tự block █ và ░)
   TYPE: SUPPORT/RESISTANCE/CONFLUENCE
   Status: Fresh / Decay:-N / RoleRev

   - Resistance: label TRÊN zone. Support: label DƯỚI zone
   - Chống chồng: offset 20px nếu 2 label quá gần (cùng price ± 30 pips)
   - Name: OBJECT_PREFIX + "LBL_" + IntegerToString(rp.id)

5. DrawEntrySetupPanel(int setup_index):
   - Vẽ panel entry trên chart (OBJ_RECTANGLE_LABEL + nhiều OBJ_LABEL)
   - Layout:
     ┌─────────────────────────────┐
     │  SELL SETUP  Score: 87      │
     │  Entry: 1.2752              │
     │  SL:    1.2770  (18 pip)    │
     │  TP1:   1.2709  (43 pip)    │
     │  TP2:   1.2620  (132 pip)   │
     │  R:R1 = 1:2.4  R:R2 = 1:7.3│
     │  Expires in 7 bars          │
     └─────────────────────────────┘
   - Nền: C'30,15,15' (SELL) / C'15,30,15' (BUY), opacity 85%
   - Vẽ TP/SL lines trên chart (OBJ_HLINE hoặc OBJ_TREND)

6. DrawSLTPLines(int setup_index):
   - SL: clrFireBrick, STYLE_DASH
   - TP1: clrKhaki, STYLE_DOT
   - TP2: clrDarkKhaki, STYLE_DOT
   - Entry: Color_EntryBuy/Sell, STYLE_SOLID

7. RedrawChangedRP():
   - Chỉ vẽ lại RP có score thay đổi so với lần draw trước
   - Lưu previous_score per RP để so sánh

8. DeleteRPObjects(int rp_id):
   - Xóa tất cả objects của 1 RP: zone + label + glow

9. DeleteAllObjects():
   - ObjectsDeleteAll(0, OBJECT_PREFIX)
   - g_object_count = 0

10. EnforceObjectLimit():
    - Nếu g_object_count > MAX_CHART_OBJECTS → xóa objects của RP có score thấp nhất

11. UpdateFontSizes():
    - Detect CHART_SCALE → adjust font ±2, min font 6
```

---

## PROMPT 5: RP_Alerts.mqh (Alert System)

```
Tạo file MQL5/Include/ReactionPoint/RP_Alerts.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_ALERTS_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs:
  extern bool Alert_Only_Active_Sessions;

GLOBALS: g_rp_array[], g_rp_count, g_current_session, g_news_blackout, g_spread_blocked
         g_proximity_alert_pips, g_reset_alert_pips

SReactionPoint fields dùng: alert_sent[4], alert_reset_time, price, zone_high, zone_low,
  rp_type, final_score, is_active, is_role_reversed, is_confluence, candle_pattern, rp_level

ENUM_SESSION: SESSION_DEAD, SESSION_ASIAN

=== 4 CẤP ALERT ===

| Cấp | Trigger | Format |
|-----|---------|--------|
| 1 | Giá cách RP <= Proximity_Alert_Pips VÀ đang đi VỀ PHÍA RP | "Approaching [PAIR] [TF] | [price] | Score:[n] | Dist:[n]p" |
| 2 | Bar[1] đóng = pattern hợp lệ tại RP zone | "RP REACTION [PAIR] [TF] | [pattern]@[price] | Score:[n] | R:R=[n]" |
| 3 | Role Reversal confirmed | "ROLE REVERSAL [PAIR] [TF] | [price] -> [new_type] | Score:[n]" |
| 4 | Confluence Premium (score >=110) | "PREMIUM [PAIR] | [range] | Score:[n] | [n]TF aligned" |

=== FUNCTIONS ===

1. CheckAllAlerts():
   - Gọi mỗi tick trong OnCalculate
   - Loop tất cả active RP
   - Cho mỗi RP, check 4 cấp alert theo thứ tự
   - Filter: Session (nếu Alert_Only_Active_Sessions && session==DEAD → skip)
   - Filter: News blackout → KHÔNG trigger cấp 1-2
   - Filter: Spread blocked → KHÔNG trigger cấp 2
   - Exception: Premium Confluence (>=110) LUÔN alert kể cả Choppy/News

2. CheckProximityAlert(int rp_index): bool
   - Tính distance = |current_price - rp.price| (dùng SymbolInfoDouble SYMBOL_BID)
   - Nếu distance <= Proximity_Alert_Pips:
     - Check hướng: so sánh close[1] vs close[2] → đang tiến về RP?
     - BUY: price đang giảm về Support
     - SELL: price đang tăng về Resistance
   - Return true nếu cần alert

3. CheckReactionAlert(int rp_index): bool
   - Bar[1] đã đóng, nằm trong zone, có pattern hợp lệ
   - Anti-repainting: CHỈX bar[1]

4. CheckRoleReversalAlert(int rp_index): bool
   - rp.is_role_reversed == true VÀ alert_sent[2] == false

5. CheckPremiumAlert(int rp_index): bool
   - rp.final_score >= 110 VÀ rp.is_confluence VÀ alert_sent[3] == false

6. SendRPAlert(int level, string message):
   - Alert(message)
   - SendNotification(message) — push notification
   - Print("RP_ALERT[" + level + "]: " + message)

7. ResetAlertIfDistant(int rp_index):
   - Khi giá rời xa >= Reset_Alert_Pips → reset alert_sent[] = false
   - Cho phép alert lại khi giá quay lại

Anti-spam: alert_sent[4] per RP. Mỗi zone chỉ 1 alert mỗi lần tiếp cận.
Dùng Alert() + SendNotification() của MQL5.
```

---

## PROMPT 6: RP_Dashboard.mqh (Dashboard UI)

```
Tạo file MQL5/Include/ReactionPoint/RP_Dashboard.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DASHBOARD_MQH / #define / #endif
Include: "RP_Defines.mqh"
Include: "RP_Utils.mqh"

Extern inputs:
  extern bool             Show_Dashboard;
  extern bool             Show_Performance_Stats;
  extern ENUM_DASH_CORNER Dashboard_Corner;
  extern int              Dashboard_Font_Size;
  extern bool             Show_HTF_1, Show_HTF_2;

GLOBALS DÙNG:
  - g_rp_array[], g_rp_count, g_confluence_count
  - g_current_regime, g_current_trend, g_current_adx
  - g_current_session, g_current_spread_pips, g_average_spread_pips
  - g_news_status_text, g_news_status_color
  - g_spread_blocked, g_spread_warning
  - g_setup_array[], g_setup_count
  - g_object_count, g_stats
  - DashCornerToAnchor(), TFToString(), SessionToString(), RegimeToString()
  - GetSpreadColor(), GetHitRate() (from RP_Stats.mqh - extern)
  - FormatStatsString() (from RP_Stats.mqh - extern)

COLORS: Nền C'20,25,32' 90% opacity, border C'60,65,75', text White/DarkGray/Lime/Tomato

=== DASHBOARD LAYOUT ===

╔══════════════════════════════════════════════════╗
║  REACTION POINT v3.0           Preset: H4       ║
║  GBPUSD  │  H4  │  London-NY Overlap             ║
╠══════════════════════════════════════════════════╣
║  REGIME   STRONG DOWNTREND    ADX: 32.4          ║
║  BIAS     SELL preferred                          ║
║  ATR: 42p  │  Spread: 1.2p  │  NEWS: clear       ║
╠══════════════════════════════════════════════════╣
║  RES  1.2750  Score:87   23p  Conf  Fresh        ║
║  SUP  1.2620  Score:65   41p  Decay:-12          ║
╠══════════════════════════════════════════════════╣
║  RADAR  (top 5 nearest)                          ║
║  1.2750 23p 87  │ 1.2620 41p 65                  ║
╠══════════════════════════════════════════════════╣
║  Zones:8  Conf:2  Setups:1  Obj:142/250          ║
║  HTF: D1 W1  │  Hit Rate: 67% (42/63)            ║
╠══════════════════════════════════════════════════╣
║  SELL@1.2752  SL:18p  TP1:43p  R:R=1:2.4         ║
╚══════════════════════════════════════════════════╝

=== FUNCTIONS ===

1. CreateDashboard():
   - Tạo background rectangle (OBJ_RECTANGLE_LABEL)
   - Tạo tất cả text labels (OBJ_LABEL)
   - Đặt tại Dashboard_Corner
   - Name prefix: OBJECT_PREFIX + "DASH_"

2. UpdateDashboard():
   - Gọi mỗi nến mới
   - Cập nhật tất cả text values
   - Section ẩn/hiện theo context:
     - Entry Setup line: chỉ khi có active setup
     - NEWS: đổi theo g_news_status_text/color
     - Spread: đổi màu theo GetSpreadColor()
     - CHOPPY → regime section nền đỏ
     - Hit Rate: chỉ khi Show_Performance_Stats=true

3. UpdateRadar():
   - Top 5 RP gần nhất (sort theo khoảng cách từ current price)
   - Hiện: price, distance (pips), score
   - RES phía trên, SUP phía dưới

4. RepositionDashboard():
   - Gọi khi CHARTEVENT_CHART_CHANGE
   - Recalc vị trí theo Dashboard_Corner + chart size

5. DeleteDashboard():
   - ObjectsDeleteAll(0, OBJECT_PREFIX + "DASH_")

6. GetBiasString(): string
   - Dựa trên regime + trend → "BUY preferred" / "SELL preferred" / "Neutral"
   - CHOPPY → "Avoid trading"

Font scaling: detect CHART_SCALE → adjust font ±2. Min font 6.
Dùng OBJ_RECTANGLE_LABEL cho background, OBJ_LABEL cho text.
Mỗi row là 1 OBJ_LABEL riêng, xdistance/ydistance tính từ corner.
```

---

## PROMPT 7: RP_Main.mq5 (Main Indicator File)

```
Tạo file MQL5/Indicators/ReactionPoint/RP_Main.mq5 — main file cho Reaction Point Indicator v3.0.

INDICATOR PROPERTIES:
  #property indicator_chart_window
  #property indicator_buffers 0
  #property indicator_plots   0

INCLUDES (theo thứ tự):
  #include <ReactionPoint/RP_Defines.mqh>
  #include <ReactionPoint/RP_Utils.mqh>
  #include <ReactionPoint/RP_RegimeFilter.mqh>
  #include <ReactionPoint/RP_Session.mqh>
  #include <ReactionPoint/RP_DynamicDecay.mqh>
  #include <ReactionPoint/RP_NewsFilter.mqh>
  #include <ReactionPoint/RP_SpreadFilter.mqh>
  #include <ReactionPoint/RP_Detection.mqh>
  #include <ReactionPoint/RP_Scoring.mqh>
  #include <ReactionPoint/RP_Confluence.mqh>
  #include <ReactionPoint/RP_EntrySetup.mqh>
  #include <ReactionPoint/RP_Stats.mqh>
  #include <ReactionPoint/RP_Drawing.mqh>
  #include <ReactionPoint/RP_Dashboard.mqh>
  #include <ReactionPoint/RP_Alerts.mqh>

=== INPUT PARAMETERS (khai báo đầy đủ) ===

// PRESET
input ENUM_TF_PRESET TF_Preset = PRESET_AUTO;

// SWING
input int    Swing_Lookback           = 3;
input int    Min_RP_Distance_Pips     = 20;
input int    Min_Reaction_Move_Pips   = 15;
input int    Initial_Bars_To_Scan     = 500;
input bool   Use_Adaptive_Reaction    = true;
input double Reaction_ATR_Multiplier  = 0.5;

// BREAKOUT
input int    Breakout_Confirm_Pips    = 5;
input int    Max_Retest_Bars          = 50;

// REGIME (Module A)
input int    ADX_Period               = 14;
input double ADX_Strong_Threshold     = 25.0;
input double ADX_Weak_Threshold       = 20.0;
input bool   Use_Regime_Filter        = true;

// DECAY (Module B)
input int    Decay_Interval_Bars      = 20;
input int    Decay_Points_Per_Interval= 2;
input int    Max_RP_Age_Bars          = 300;
input bool   Use_Dynamic_Score        = true;

// ENTRY (Module C)
input bool   Show_Entry_Setup         = true;
input int    SL_Buffer_Pips           = 5;
input int    Entry_Buffer_Pips        = 2;
input double Min_RR_Ratio             = 1.5;
input int    Max_Setup_Age_Bars       = 10;

// CONFLUENCE (Module D)
input int    Confluence_Merge_Pips    = 10;
input bool   Use_Confluence_Zones     = true;
input int    HTF_Bars_To_Scan         = 200;

// SESSION (Module E)
input int    UTC_Offset               = 3;
input bool   Alert_Only_Active_Sessions = true;
input bool   Show_Session_Background  = true;

// FIBONACCI
input int    Fibo_Lookback_Bars       = 100;
input int    Fibo_Tolerance_Pips      = 5;

// CANDLE
input int    Min_Candle_Size_Pips     = 3;

// NEWS (Module F)
input bool   Use_News_Filter          = true;
input int    News_Blackout_Minutes    = 30;
input bool   News_Filter_High_Only    = false;

// SPREAD (Module G)
input bool   Use_Spread_Filter        = true;
input double Spread_Alert_Multiplier  = 2.0;
input double Spread_Block_Multiplier  = 3.0;

// MULTI-TIMEFRAME
input bool             Show_HTF_1     = true;
input ENUM_TIMEFRAMES  HTF_1          = PERIOD_H4;
input bool             Show_HTF_2     = true;
input ENUM_TIMEFRAMES  HTF_2          = PERIOD_D1;

// DISPLAY
input int              Zone_Width_Pips          = 4;
input int              Min_Score_To_Show        = 40;
input bool             Show_Dashboard           = true;
input bool             Show_Performance_Stats   = true;
input int              Proximity_Alert_Pips     = 20;
input int              Reset_Alert_Pips         = 30;
input ENUM_DASH_CORNER Dashboard_Corner         = DASH_TOP_LEFT;
input int              Dashboard_Font_Size      = 9;
input int              Label_Font_Size          = 8;

// COLORS
input color  Color_Premium       = clrGold;
input color  Color_Level1        = clrCrimson;
input color  Color_Level2        = clrOrange;
input color  Color_Level3        = clrSkyBlue;
input color  Color_Confluence    = clrMediumPurple;
input color  Color_RoleReversal  = clrMagenta;
input color  Color_EntryBuy      = clrLimeGreen;
input color  Color_EntrySell     = clrRed;

=== OnInit() ===
1. ApplyTFPreset():
   - Nếu TF_Preset == PRESET_CUSTOM → copy input vào g_ globals
   - Nếu PRESET_AUTO → detect Period() → áp preset (M30/H1/H4/D1)
   - Áp tất cả giá trị từ bảng TF Preset (Section 5 của spec)
2. ValidateInputs():
   - Clamp tất cả input về range hợp lệ, print warning nếu cần
   - Validate HTF hierarchy: HTF_1 > Period(), HTF_2 > HTF_1
3. ArrayResize(g_rp_array, MAX_RP_COUNT)
   ArrayResize(g_confluence_array, MAX_CONFLUENCE)
   ArrayResize(g_setup_array, MAX_SETUPS)
4. InitIndicatorHandles()
5. InitStats()
6. CreateDashboard()
7. EventSetTimer(1) — cho flash management
8. Return INIT_SUCCEEDED

=== OnCalculate() ===
// MỖI TICK:
CheckAllAlerts();
UpdateSetups();
UpdateSpreadFilter();

// MỖI NẾN MỚI (IsNewBar()):
UpdateNewsFilter();
UpdateCurrentSession();
UpdateMarketRegime();
DetectSwingPoints(g_initial_bars_to_scan);  // Chỉ lần đầu scan full, sau đó scan ít bars
CheckBreakoutsAndRetests();
for(i = 0..g_rp_count):
   CalcFinalScore(i);
UpdateAllDecay();
if(Use_Confluence_Zones):
   CollectHTFReactionPoints();
   MergeClusterZones();
   ApplyConfluenceScoring();
if(Show_Entry_Setup):
   CheckEntryConditions();
RedrawChangedRP();
if(Show_Session_Background):
   DrawSessionBackgrounds(visible_bars);
UpdateDashboard();
EnforceObjectLimit();
UpdateStats();
return rates_total;

=== OnDeinit(reason) ===
- EventKillTimer()
- DeleteAllObjects()
- DeleteDashboard()
- ReleaseIndicatorHandles()
- REASON_PARAMETERS → xóa objects, giữ RP data, recalculate
- REASON_CHARTCHANGE/REASON_RECOMPILE/REASON_REMOVE → full reset

=== OnChartEvent(id, lparam, dparam, sparam) ===
- CHARTEVENT_CHART_CHANGE → RepositionDashboard() + UpdateFontSizes()

=== OnTimer() ===
- Flash management: toggle visibility cho RP đang flash
- Decrement flash_count, kill timer khi xong

=== ApplyTFPreset() — TF PRESET TABLE ===
Param                    M30    H1    H4     D1
Swing_Lookback            5      4     3      3
Min_RP_Distance_Pips     25     20    20     40
Min_Reaction_Move_Pips   12     15    20     40
Initial_Bars_To_Scan    600    500   300    200
Breakout_Confirm_Pips     3      5     8     15
Max_Retest_Bars          40     50    40     30
Decay_Interval_Bars      15     20    25     10
Decay_Points_Per_Interval 3      2     2      3
Max_RP_Age_Bars         200    300   200    100
SL_Buffer_Pips            3      5     8     15
Entry_Buffer_Pips         1      2     3      5
Max_Setup_Age_Bars        8     10    10      5
Confluence_Merge_Pips     8     10    15     25
HTF_Bars_To_Scan        200    200   150    100
Fibo_Lookback_Bars       80    100   100     60
Fibo_Tolerance_Pips       3      5     8     12
Min_Candle_Size_Pips      2      3     5     10
Zone_Width_Pips           3      4     6     10
Min_Score_To_Show        50     40    40     35
Proximity_Alert_Pips     15     20    30     50
Reset_Alert_Pips         20     30    40     60
HTF_1                    H1     H4    D1     W1
HTF_2                    H4     D1    W1    MN1

PRESET_AUTO: Period()<=M30→M30, <=H1→H1, <=H4→H4, else→D1
```

---

## THỨ TỰ THỰC THI

```
Session 1: PROMPT 1 (Confluence)    — độc lập, không phụ thuộc
Session 2: PROMPT 2 (EntrySetup)    — độc lập
Session 3: PROMPT 3 (Stats)         — độc lập
Session 4: PROMPT 4 (Drawing)       — cần biết struct/globals
Session 5: PROMPT 5 (Alerts)        — cần biết struct/globals
Session 6: PROMPT 6 (Dashboard)     — cần Stats, Drawing
Session 7: PROMPT 7 (Main)          — tổng hợp tất cả, làm cuối cùng
```

Mỗi session, chỉ cần paste prompt tương ứng. Không cần đọc lại spec.
