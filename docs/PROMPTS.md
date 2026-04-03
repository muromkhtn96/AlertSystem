# REACTION POINT INDICATOR v3.3 — IMPLEMENTATION PROMPTS (Optimized)

**19 files (1 main `.mq5` + 18 `.mqh`) | 8 phases | 37 prompts**
**Mỗi prompt = 1 session riêng. Paste prompt + HEADER nếu cần.**

---

## § HEADER — Shared Conventions (đọc 1 lần, áp dụng TẤT CẢ prompts)

### MQL5 Rules
1. **KHÔNG `extern`** → dùng `input`/`sinput` trong `RP_Main.mq5`. Modules đọc `g_` globals (set bởi `ApplyTFPreset()`).
2. **KHÔNG `TimeDayOfWeek()`** → `MqlDateTime dt; TimeToStruct(time, dt); int dow = dt.day_of_week;`
3. **Opacity** → `BlendColor(fg, bg, alpha_pct)` helper. MQL5 `OBJ_RECTANGLE` không có native alpha.
4. **Include guard** → mỗi `.mqh`: `#ifndef X_MQH / #define / #endif`. Globals chỉ trong `RP_Utils.mqh`.
5. **`#property strict`** trong `RP_Main.mq5`.

### Common Patterns (mỗi module đều tuân thủ)
- **Include**: mọi `.mqh` include `"RP_Utils.mqh"` (trừ P1 `RP_Defines.mqh`)
- **Inputs**: khai báo trong `RP_Main.mq5`, Main copy vào `g_` globals trong `ApplyTFPreset()`. Modules CHỈ đọc globals.
- **Anti-repainting**: dùng `RP_Close(1)/RP_High(1)/RP_Low(1)` — KHÔNG BAO GIỜ bar[0]
- **Dirty flag**: mọi state change phải set `g_rp_dirty[i] = true`

### Dependency Graph
```
Phase 1: P1 → P2                    (Foundation)
Phase 2: P3, P4, P5, P6, P7         (Independent — song song)
Phase 3: P8 → P9A → P10             (Core Logic + Market Structure)
Phase 4: P11, P12, P13              (Advanced — cần Phase 2+3)
Phase 5: P14, P15, P16              (UI — cần Phase 4)
Phase 6: P17                        (Main — tổng hợp)
Phase 7: P18+P19 → P20 → P21 → P22 → P23 → P24 → P25 → P26 → P27 → P28
Phase 8: P29 → P30 → P32 → P33 → P34(FVG) → P35(Mitigation) → P36(Imbalance) → P37(Breaker)
```

---

## § ALL GLOBALS REGISTRY (consolidated — thay vì rải ra 16 prompts)

Tất cả globals khai báo trong `RP_Utils.mqh`, modules đọc trực tiếp.
Ngoại lệ: FVG globals (`g_fvg_array`, `g_fvg_count`, `SFVG`) khai báo trong `RP_FVG.mqh`.

### RP Data
```cpp
SReactionPoint g_rp_array[];  int g_rp_count = 0;  int g_next_rp_id = 0;
SConfluenceZone g_confluence_array[];  int g_confluence_count = 0;  int g_next_confluence_id = 0;
SEntrySetup g_setup_array[];  int g_setup_count = 0;
SRPStats g_stats;
```

### Market State
```cpp
ENUM_MARKET_REGIME g_current_regime = REGIME_RANGING;
ENUM_TREND_DIR     g_current_trend  = TREND_NONE;
double             g_current_adx    = 0;
ENUM_SESSION       g_current_session = SESSION_DEAD;
ENUM_STRUCTURE_STATE g_current_structure = STRUCTURE_NONE;
bool g_choch_detected = false;  int g_last_bos_bar = 0;  int g_last_choch_bar = 0;
```

### Filters
```cpp
bool g_news_blackout = false;  bool g_news_available = true;
string g_news_status_text = "clear";  color g_news_status_color = clrLime;
bool g_spread_blocked = false;  bool g_spread_warning = false;
double g_current_spread_pips = 0;  double g_average_spread_pips = 0;
```

### Display & Handles
```cpp
int g_object_count = 0;
int g_handle_adx = INVALID_HANDLE;  int g_handle_atr = INVALID_HANDLE;
```

### Input Globals (set bởi ApplyTFPreset)
```cpp
int    g_swing_lookback, g_min_rp_distance_pips, g_min_reaction_move_pips;
int    g_initial_bars_to_scan, g_breakout_confirm_pips, g_max_retest_bars;
int    g_decay_interval_bars, g_decay_points_per_interval, g_max_rp_age_bars;
int    g_sl_buffer_pips, g_entry_buffer_pips, g_max_setup_age_bars;
int    g_confluence_merge_pips, g_htf_bars_to_scan;
int    g_fibo_lookback_bars, g_fibo_tolerance_pips, g_min_candle_size_pips;
int    g_zone_width_pips, g_min_score_to_show;
ENUM_RP_LEVEL g_show_min_level = RP_PREMIUM;  // Backward compat — computed from toggles
bool   g_show_premium = true, g_show_level1 = false, g_show_level2 = false, g_show_level3 = false;
int    g_proximity_alert_pips, g_reset_alert_pips;
ENUM_TIMEFRAMES g_htf_1, g_htf_2;
double g_reaction_atr_multiplier;
bool   g_use_adaptive_reaction;
```

### Module Feature Flags (tất cả default values)
```cpp
int    g_adx_period = 14;  double g_adx_strong_threshold = 25.0;  double g_adx_weak_threshold = 20.0;
bool   g_use_regime_filter = true;  bool g_use_dynamic_score = true;
int    g_utc_offset = 3;  bool g_show_session_background = true;
bool   g_use_news_filter = true;  int g_news_blackout_minutes = 30;  bool g_news_filter_high_only = false;
bool   g_use_spread_filter = true;  double g_spread_alert_multiplier = 2.0;  double g_spread_block_multiplier = 3.0;
bool   g_use_market_structure = true;  int g_structure_lookback_bars = 50;
bool   g_use_confluence_zones = true;
bool   g_show_entry_setup = true;  double g_min_rr_ratio = 1.5;
bool   g_enable_system_alert = false;  bool g_enable_push_notify = false;
bool   g_alert_only_active_sessions = true;  bool g_clean_chart_mode = false;
bool   g_show_dashboard = true;  bool g_show_performance_stats = true;
ENUM_DASH_CORNER g_dashboard_corner = DASH_TOP_LEFT;  int g_dashboard_font_size = 9;
bool   g_show_htf_1 = true, g_show_htf_2 = true;
int    g_label_font_size = 8;
bool   g_use_trend_alignment = true;  // P20
bool   g_is_jpy_pair = false, g_is_gbp_pair = false, g_is_cross_pair = false;  // P22
```

### Display Colors (v3.3: 2-color system — blue demand, red supply)
```cpp
color g_color_support = C'50,160,220';      // Blue — all demand zones
color g_color_resistance = C'220,80,80';    // Red — all supply zones
color g_color_premium = C'255,210,80';      // Gold accent (unused in zone fill)
color g_color_level1 = C'180,180,180';      // Neutral gray
color g_color_level2 = C'140,140,140';      // Dim gray
color g_color_level3 = C'110,110,110';      // Faint gray
color g_color_confluence = C'200,180,80';   // Muted gold
color g_color_role_reversal = C'180,140,60';// Warm amber
color g_color_entry_buy = C'60,200,120';    // Mint green
color g_color_entry_sell = C'220,70,70';    // Soft red
```

### Cached Values (update 1 lần/bar)
```cpp
double g_cached_atr14 = 0, g_cached_atr14_smooth = 0, g_cached_atr14_ma50 = 0, g_cached_volume_ma20 = 0;
int    g_cached_bar_index = -1;
double g_cached_fibo_high = 0, g_cached_fibo_low = 0;
double g_cached_fibo_618 = 0, g_cached_fibo_500 = 0, g_cached_fibo_382 = 0;
bool   g_rp_dirty[];  int g_last_calc_bar[];
bool   g_htf1_cache_valid = false, g_htf2_cache_valid = false;
int    g_htf1_cached_swing_count = 0, g_htf2_cached_swing_count = 0;
bool   g_confluence_needs_update = false;
double g_last_alert_check_price = 0;
```

### P19 Fibo Legs
```cpp
struct SFiboLeg { double swing_a_price, swing_b_price; int swing_a_bar, swing_b_bar;
   bool is_bullish_leg, is_valid; double fibo_382, fibo_500, fibo_618, fibo_786;
   void Init() { ZeroMemory(this); } };
#define MAX_FIBO_LEGS 3
SFiboLeg g_fibo_legs[];  int g_fibo_leg_count = 0;
```

### P20 HTF Trends
```cpp
struct SHTFTrend { ENUM_TIMEFRAMES tf; ENUM_TREND_DIR trend; bool is_valid; datetime last_updated;
   void Init() { ZeroMemory(this); } };
SHTFTrend g_htf_trends[3];  // [0]=current, [1]=HTF_1, [2]=HTF_2
```

### P29 ID Map (v3.0.1)
```cpp
int g_rp_id_to_index[];  // O(1) lookup, maintain in CreateRP/EvictRP
```

---

## PHASE 1: FOUNDATION

---

### P1: RP_Defines.mqh — Enums, Constants, Structs

```
=== ENUMS ===
ENUM_RP_TYPE        { RP_SUPPORT, RP_RESISTANCE }
ENUM_RP_LEVEL       { RP_PREMIUM, RP_LEVEL1, RP_LEVEL2, RP_LEVEL3, RP_HIDDEN }
ENUM_MARKET_REGIME  { REGIME_STRONG_TREND, REGIME_WEAK_TREND, REGIME_RANGING, REGIME_CHOPPY }
ENUM_TREND_DIR      { TREND_UP, TREND_DOWN, TREND_NONE }
ENUM_SESSION        { SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON,
                      SESSION_NY_OPEN, SESSION_NY, SESSION_OVERLAP, SESSION_DEAD }
ENUM_CANDLE_PATTERN { PATTERN_NONE, PATTERN_PINBAR, PATTERN_ENGULFING,
                      PATTERN_OUTSIDE_BAR, PATTERN_LARGE_WICK }
ENUM_TF_PRESET      { PRESET_AUTO, PRESET_M15, PRESET_M30, PRESET_H1, PRESET_H4, PRESET_D1, PRESET_CUSTOM }
ENUM_DASH_CORNER    { DASH_TOP_LEFT, DASH_TOP_RIGHT, DASH_BOTTOM_LEFT, DASH_BOTTOM_RIGHT }
ENUM_STRUCTURE_STATE { STRUCTURE_BULLISH, STRUCTURE_BEARISH, STRUCTURE_NONE }

=== CONSTANTS ===
#define MAX_RP_COUNT 200 | MAX_CHART_OBJECTS 250 | MAX_CONFLUENCE 50
#define MAX_SETUPS 10 | MAX_FLASH_RP 3 | MAX_HTF_RETRIES 3
#define OBJECT_PREFIX "RP_" | SCORE_CAP 200.0 | MAX_ZONE_RPS 8

=== STRUCTS ===

SReactionPoint {
   int id;  ENUM_RP_TYPE rp_type;  ENUM_RP_LEVEL rp_level;
   ENUM_TIMEFRAMES source_tf;  ENUM_SESSION session_formed;  ENUM_CANDLE_PATTERN candle_pattern;
   double price, zone_high, zone_low;
   datetime time_formed, time_last_tested;  int bar_formed, bar_last_tested;
   double base_score, final_score, initial_reaction_pips;
   int test_count;
   bool is_role_reversed, is_active, is_confluence, is_fresh;
   int confluence_id;  // -1 nếu không thuộc confluence
   bool alert_sent[4];  datetime alert_reset_time;
   bool is_flashing;  int flash_count;  double display_opacity;
   int day_of_week_formed;  bool has_liquidity_sweep;
   // P24:
   double zone_high_original, zone_low_original;  bool has_wick_filter;
   // P25:
   int strong_test_count, weak_test_count;
   double test_volumes[4];  int test_vol_index;
   // P29:
   bool is_order_block;  int ob_bar_index;  // -1 nếu không tìm thấy
   // P34:
   bool has_fvg;  bool has_fvg_bullish;  // FVG overlap detection
   // P36:
   bool has_imbalance;  // Imbalance candle at zone formation
   // P37:
   bool is_breaker_block;  // OB broken by impulse + retested from opposite side

   Init(): ZeroMemory + confluence_id=-1, ob_bar_index=-1,
           zone_high_original=0, zone_low_original=0, has_wick_filter=false,
           strong_test_count=0, weak_test_count=0, test_vol_index=0,
           is_order_block=false, ArrayInitialize(test_volumes,0),
           has_fvg=false, has_fvg_bullish=false, has_imbalance=false, is_breaker_block=false
}

SConfluenceZone {
   int id;  double zone_high, zone_low, center_price;
   int rp_count;  int rp_ids[MAX_ZONE_RPS];  // FIXED array
   ENUM_RP_TYPE zone_type;  // Majority vote
   double multiplier, bonus, final_score;
   string tf_description;  bool is_premium;  // true khi 4+ RP
}

SEntrySetup {
   int rp_id;  ENUM_RP_TYPE direction;
   double entry_price, sl_price, tp1_price, tp2_price;
   double rr_ratio1, rr_ratio2, sl_pips, tp1_pips, tp2_pips;
   int bar_created;  datetime time_created;
   bool is_active, is_invalidated, is_triggered, is_preferred;
}

SRPStats {
   int total_formed, total_reacted, total_broken;
   int premium_formed, premium_reacted;
   int level1_formed, level1_reacted;  int level2_formed, level2_reacted;
   int london_formed, london_reacted;  int ny_formed, ny_reacted;
   int asian_formed, asian_reacted;
   datetime tracking_start;
   void Init() { ZeroMemory(this); tracking_start = TimeCurrent(); }
}
```

---

### P2: RP_Utils.mqh — Globals & Utilities

Include: `"RP_Defines.mqh"`. Globals: xem § ALL GLOBALS REGISTRY ở trên.

```
=== ANTI-REPAINTING MACRO ===
#define RP_SHIFT_MIN 1
RP_Close(shift): if(shift<1) { Print warning; return 0; } return iClose(shift)
RP_High(shift):  tương tự iHigh
RP_Low(shift):   tương tự iLow
→ TẤT CẢ modules phải dùng thay vì iClose/iHigh/iLow trực tiếp.

=== UpdateBarCache() — gọi đầu OnCalculate khi IsNewBar() ===
- Guard: if(current_bar == g_cached_bar_index) return
- g_cached_atr14 = CalcATR(14,1). Guard NaN/zero → fallback PipsToPrice(10)
- g_cached_atr14_smooth: EMA(g_cached_atr14, period=10, alpha=2/11). Seed=first raw value. Dùng cho scoring
- g_cached_atr14_ma50: rolling buffer[50], SMA
- g_cached_volume_ma20: rolling buffer[20], dùng iVolume(1)
- UpdateFiboCache()

=== UTILITY FUNCTIONS ===

1.  PipValue(): Digits()==3||5 → Point()*10, Digits()==2||4 → Point(). Guard: KHÔNG BAO GIỜ return 0
2.  PipsToPrice(pips): pips * PipValue()
3.  PriceToPips(diff): if(pv<=0) return 0; diff / PipValue()
4.  SafeATR(period, shift=0): period==14 && shift<=1 → return g_cached_atr14. Else CalcATR. Guard NaN/zero
5.  GetATR14(shift=0): shift<=1 → g_cached_atr14. Else SafeATR(14,shift)
6.  CalcATR(period, shift): dùng g_handle_atr + CopyBuffer. Guard return value
6b. UpdateFiboCache(): → xem P19 (Swing-to-Swing engine thay thế)
7.  IsNewBar(): static datetime, so sánh iTime(0)
8.  TFToString(tf): PERIOD_M30→"M30", H1→"H1"...
9.  SessionToString(s): SESSION_OVERLAP→"London-NY Overlap"...
10. RegimeToString(r): REGIME_STRONG_TREND→"STRONG TREND"...
11. DashCornerToAnchor(c): → ENUM_ANCHOR_POINT
12. GetSpreadColor(cur, avg): >3x→clrRed, >2x→clrYellow, else→clrWhite
13. ClassifyRPLevel(score): >=120→PREMIUM, 85-119→L1, 60-84→L2, 40-59→L3, <40→HIDDEN
14. InitIndicatorHandles(): tạo g_handle_adx + g_handle_atr. Check INVALID_HANDLE
15. ReleaseIndicatorHandles(): IndicatorRelease cả 2
15b. RevalidateHandles(): mỗi 100 bars, re-create nếu invalid
16. BlendColor(fg, bg, alpha_pct): mix RGB channels. alpha_pct 0=bg, 100=fg
17. GetChartBackground(): ChartGetInteger(0, CHART_COLOR_BACKGROUND)

Lưu ý: File này KHÔNG chứa logic nghiệp vụ, chỉ globals + helpers.
```

---

## PHASE 2: INDEPENDENT MODULES (song song, chỉ cần P1+P2)

---

### P3: RP_RegimeFilter.mqh — Module A: Market Regime

```
=== FUNCTIONS ===

1. UpdateMarketRegime():
   - CopyBuffer từ g_handle_adx → g_current_adx
   - ADX > 25 → STRONG_TREND | ADX >= 20 → WEAK_TREND
   - ADX < 20: ATR14 < ATR_MA50*0.7 → CHOPPY, else → RANGING
   - Trend: +DI > -DI → UP, -DI > +DI → DOWN, else → NONE

2. GetRegimeScoreAdj(rp_type): double
   - if !g_use_regime_filter → return 0
   - Mapping: Uptrend+SUPPORT = cùng chiều, Uptrend+RESISTANCE = ngược chiều (vice versa)
   | Regime       | Cùng chiều | Ngược chiều |
   | STRONG_TREND | +20        | -30         |
   | WEAK_TREND   | +10        | -15         |
   | RANGING      | +15        | +15         |
   | CHOPPY       | -20        | -20         |

3. IsChoppyMarket(): return g_current_regime == REGIME_CHOPPY
   Khi CHOPPY: ẩn entry, không alert cấp 1-2, opacity -50%, "Avoid trading"
   NGOẠI LỆ: Premium Confluence (>=120) VẪN alert + hiển thị bình thường
```

---

### P4: RP_Session.mqh — Module E: Session & Day-of-Week

```
=== SESSION TABLE (UTC) ===
Asian=00:00-07:00 | LondonOpen=07:00-08:30 | London=07:00-16:00
NYOpen=13:00-14:30 | NY=13:00-22:00 | Overlap=13:00-16:00 | Dead=22:00-00:00
Ưu tiên: Overlap > LondonOpen > NYOpen > London > NY > Asian > Dead

=== FUNCTIONS ===

1. UpdateCurrentSession(): detect session từ UTC hour (adjusted by g_utc_offset)
2. GetSessionScoreAdj(session): Overlap+15, LondonOpen+10, NYOpen+10, London+5, NY+5, Asian-10, Dead-20
   P22 pair-adaptive: GBP→LondonOpen+5,London+3,Asian-5 | JPY→Asian+7,Dead+5 | Cross→Dead+5,Overlap-5
3. GetDayOfWeekAdj(): Mon-5, Tue-Wed 0, Thu+5, Fri(UTC<15)→0, Fri(UTC>=15)→-10
4. GetSessionForTime(datetime): detect session tại thời điểm bất kỳ
5. DrawSessionBackgrounds(visible_bars): OBJ_RECTANGLE, colors blend 10% opacity
   Asian=LightCyan, London=Lavender, NY=LemonChiffon, Overlap=MistyRose, Dead=Gainsboro
```

---

### P5: RP_DynamicDecay.mqh — Module B: Score Decay

```
=== FUNCTIONS ===

1. CalcDecayPenalty(rp_index): double
   - if !g_use_dynamic_score → return 0
   - penalty = (bars_since_last_event / g_decay_interval_bars) * g_decay_points_per_interval
   - bars > g_max_rp_age_bars → penalty += 10
   - bars > 2×max_age AND score < 80 → is_active = false

2. CalcRecentBonus(rp_index): double — CHỈ closed bars [1..N]
   - Phản ứng xác nhận bars[1..5] → +15
   - Test không phá bars[1..10] → +8
   - Else → 0

3. UpdateAllDecay(): loop active RP, update display_opacity tuyến tính, floor 30%

Lưu ý: penalty/bonus dùng trong CalcFinalScore, KHÔNG apply trực tiếp tại đây.
```

---

### P6: RP_NewsFilter.mqh — Module F: News Filter

```
PERFORMANCE: gọi mỗi 5 phút (300s), KHÔNG mỗi bar. Exponential backoff khi API fail.

=== FUNCTIONS ===

1. UpdateNewsFilter():
   - if !g_use_news_filter → g_news_blackout=false; return
   - MQL5 Calendar API: extract base/quote currency từ _Symbol
   - CalendarValueHistory(from=now-blackout, to=now+blackout)
   - Filter CalendarEventById → check currency match + importance
   - CALENDAR_IMPORTANCE_HIGH → luôn blackout
   - CALENDAR_IMPORTANCE_MODERATE → blackout nếu !g_news_filter_high_only
   - Set g_news_blackout, g_news_status_text ("NFP in 12min"), g_news_status_color
   - Fallback khi API fail: g_news_available=false, exponential backoff (5→10→20→cap 30min)

2. Khi g_news_blackout: KHÔNG alert cấp 1-2, KHÔNG entry, RP zones+"PAUSED", score tạm -15
3. 30 phút SAU tin: rescan all active RP, resume alerts
4. Medium impact (khi !High_Only): warning dashboard, score -10, KHÔNG block entry
5. GetNewsTempScoreAdj(): High→-15, Medium→-10, Clear→0
```

---

### P7: RP_SpreadFilter.mqh — Module G: Spread Filter

```
=== FUNCTIONS ===

1. GetCurrentSpreadPips(): SYMBOL_SPREAD * SYMBOL_POINT / PipValue()
2. GetAverageSpread(): rolling buffer[100] ticks, return average
3. UpdateSpreadFilter():
   - if !g_use_spread_filter → clear flags, return
   - cur > avg × g_spread_block_multiplier (3.0) → g_spread_blocked=true
   - cur > avg × g_spread_alert_multiplier (2.0) → g_spread_warning=true, score -10
   - else → clear
   Dashboard: Normal=White, Warning=Yellow, Blocked=Red (via GetSpreadColor)
```

---

## PHASE 3: CORE LOGIC + MARKET STRUCTURE (tuần tự P8→P9A→P10)

---

### P8: RP_Detection.mqh — Swing Detection, Candle, Momentum, Breakout

```
=== 8.1 SWING DETECTION ===

1. DetectSwingPoints(bars_to_scan):
   - Scan bar[N+1..bars_to_scan], N=g_swing_lookback. KHÔNG bar[0]
   - Safety: bars < N*2+5 → warning, return
   - Swing High bar[i]: high[i] > high[i-N..i-1] AND high[i] > high[i+1..i+N]
   - Swing Low: tương tự với low
   - Khoảng cách tối thiểu: < g_min_rp_distance_pips → skip
   - Match → check Candle Pattern → check Momentum → CreateRP

2. CreateRP(type, bar_index, price, pattern, reaction_pips):
   - **Session gate (v3.2)**: M15/M30 reject zones formed during SESSION_DEAD
   - **Adaptive reaction floor (v3.2)**: M15/M30 enforce min reaction = max(preset, 0.6×ATR)
   - id = g_next_rp_id++, source_tf = Period(), session_formed = g_current_session
   - day_of_week_formed từ MqlDateTime
   - P29 OB detection: ob_bar = FindOrderBlockBar(bar_index, rp_type, 5)
     ob_valid = (ob_bar >= RP_SHIFT_MIN && ob_bar < available_bars)
     zone_bar = ob_valid ? ob_bar : bar_index
   - Zone boundaries:
     OB found → zone = body range (institutional standard), is_order_block=true
     Fallback → P21 logic: SUPPORT=bar_low..body_top, RESISTANCE=body_bottom..bar_high
   - P30: ExpandZoneWithBase(rp, zone_bar, 3) — multi-candle base
   - P24a Wick filter (v3.2 TF-adaptive):
     M15/M30: wick>=50% range → zone=25% range (stricter)
     H1+: wick>=60% range → zone=30% range (standard)
   - v3.3 ATR-adaptive proximity: effective_min_dist = max(fixed_pips, ATR×mult)
     M15/M30: mult=0.4, H1+: mult=0.6. Zone replacement: new reaction > 1.5× existing → replace weak zone
   - P24b ATR cap: M15-=0.5×ATR, M30=0.6×ATR, H1=0.55×ATR, H4=0.7×ATR, D1+=1.0×ATR
   - P24c: zone_high_original/zone_low_original lưu sau safety clamps
   - Min width floor: PipsToPrice(g_zone_width_pips/2)
   - P36 Imbalance detection: scan zone_bar±1, body>=70% + vol>1.5×MA20 → has_imbalance=true
   - is_active=true, is_fresh=true, confluence_id=-1
   - opacity: PREMIUM=80, L1=70, L2=50, L3=35
   - Array overflow → evict: inactive → lowest score non-conf → oldest → oldest conf(force, v3.0.2)
   - g_rp_dirty[idx]=true, SetRPIDMap (v3.0.1)

=== 8.2 CANDLE PATTERN ===

3. DetectCandlePattern(bar_index): ENUM_CANDLE_PATTERN
   - range=H-L, body=|O-C|, upper_wick=H-max(O,C), lower_wick=min(O,C)-L
   a) range < MinCandleSize → NONE
   b) body < range*0.10 (doji) → NONE
   c) Pinbar: wick>=60% range AND body<=25% range AND body ở 1/3 đối diện
   d) Engulfing: body[i]>body[i+1]*1.5 AND khác hướng
   e) Outside Bar: H[i]>H[i+1] AND L[i]<L[i+1] AND không Engulfing
   f) Large Wick: wick>=40% range AND close ngược hướng
   g) NONE

4. GetCandlePatternScore(pattern): P18 weights: PINBAR=12, ENGULFING=10, OUTSIDE=8, LARGE_WICK=6, NONE=0

=== 8.3 MOMENTUM ===

5. CheckMomentum(swing_bar, type): bool + reaction_pips
   - min_move = adaptive ? ATR14×g_reaction_atr_multiplier : PipsToPrice(g_min_reaction_move_pips)
   - Scan closed bars sau swing, tìm max move ngược hướng
   - max_move >= min_move → true

=== 8.4 BREAKOUT & ROLE REVERSAL ===

6. CheckBreakoutsAndRetests():
   - Loop active RP, dùng RP_Close(1)
   - Breakout: SUPPORT close < zone_low - breakout_confirm, RESISTANCE ngược lại
   - Gap qua RP: tính breakout (mạnh), KHÔNG tính test
   - Retest (sau breakout, trong max_retest_bars) → Role Reversal:
     flip type, +15 score, is_role_reversed=true, tách khỏi confluence, alert cấp 3
     P37: if is_order_block + breakout body >= 0.8×ATR → is_breaker_block=true, +10 bonus thêm
   - Test: touch zone + no breakout → test_count++
     P25a classify: body entered zone → strong_test_count++, else weak_test_count++
     P25b track volume: test_volumes[test_vol_index%4] = iVolume(1)
     P24c zone refinement: weighted average 60/40, expand nếu sâu hơn, min width guard
   - is_fresh=false sau test đầu, g_rp_dirty[i]=true

P29: FindOrderBlockBar(swing_bar, rp_type, max_scan=5):
  - Scan swing_bar..swing_bar+5, tìm nến NGƯỢC HƯỚNG cuối trước impulse
  - Body>=30% range, nến tiếp theo là impulse cùng hướng (body >= 0.5× OB body)
  - Return bar index hoặc -1

P30: ExpandZoneWithBase(rp, zone_bar, max=3):
  - Scan 1-2 nến adjacent tìm body overlap >= 50% zone width → mở rộng zone
```

---

### P9A: RP_MarketStructure.mqh — Module H: BOS, CHoCH, Liquidity Sweep

```
Concept: BOS=phá swing cũ (trend tiếp), CHoCH=phá swing ngược (trend đảo), 
Liquidity Sweep=vượt swing rồi close quay lại (trap signal)

=== FUNCTIONS ===

1. UpdateMarketStructure(): gọi mỗi IsNewBar
   - Scan bar[1..g_structure_lookback_bars], tìm 4 swing points gần nhất (2H+2L)
   - Bullish: H[0]>H[1] AND L[0]>L[1] → STRUCTURE_BULLISH
   - Bearish: H[0]<H[1] AND L[0]<L[1] → STRUCTURE_BEARISH, else NONE
   - BOS: close[1] > last_swing_high → bullish BOS. Ngược lại bearish
   - CHoCH: trong BULLISH, close[1] < last_higher_low → CHoCH bearish. Ngược lại
   - Reset g_choch_detected=false sau 10 bars

2. CheckLiquiditySweep(bar_index): bool
   - H>prev_swing_high (hoặc L<prev_swing_low) + close quay lại + wick>=40% range
   - True → đánh dấu RP gần nhất: has_liquidity_sweep=true

3. GetStructureScoreAdj(rp_index):
   - if !g_use_market_structure → return 0
   | RP cùng chiều BOS | +15 | RP ngược chiều (chưa CHoCH) | -20 |
   | RP ngược chiều + CHoCH (<10 bars) | +10 | STRUCTURE_NONE | 0 |

4. GetLiquiditySweepBonus(rp_index): has_liquidity_sweep → +20, else 0
```

---

### P10: RP_Scoring.mqh — Base Score + Final Score

```
GỌI FUNCTIONS TỪ: RegimeFilter(P3), DynamicDecay(P5), Session(P4), MarketStructure(P9A)
Include order trong Main phải đảm bảo các module trên include TRƯỚC.

PERFORMANCE: CalcBaseScore CHỈ gọi khi g_rp_dirty[rp_index]==true. Dùng cached values.

=== 10.1 BASE SCORE (0-100) — P18 rebalanced weights ===

CalcBaseScore(rp_index): tổng 6+2 thành phần:

  a) Reaction Strength (max 35): MathMin((reaction_pips / atr_smooth_pips) * 35.0, 35.0)
     Dùng g_cached_atr14_smooth (EMA) thay vì raw ATR — tránh spike penalty
  b) Test Quality ([-15, +12]): P25a+P35 CalcTestQualityScore — mitigation-aware
     weighted = strong×1.0 + weak×0.5
     <0.1→+10 (fresh premium) | <1.5→+12 (confirmed) | <2.5→+5 (depleting) | 3+→5-excess×5 (floor -15)
  c) Candle Pattern (max 12): P27a CalcPatternDirectionScore — aligned=100%, misaligned=30%,
     OutsideBar=75% (direction-neutral), Unknown=50%. Base: Pinbar=12,Engulf=10,Outside=8,Wick=6
  d) Fibonacci (max 13): P19 CalcFibonacciScore — scan g_fibo_legs[],
     618→10, 786→8, 500→7, 382→4. Fibo confluence (2+ legs)→+3. Cap 13
  e) Volume (max 15): P27c CalcVolumeScore(bar, session_formed)
     adjusted_ma20 = g_cached_volume_ma20 × GetSessionVolumeMultiplier(session)
     (Overlap/LondonOpen/NYOpen=1.0, London/NY=1.05, Asian=0.70, Dead=0.60)
     vol_ratio: >2.0→15, >1.5→12, >1.2→8, >1.0→3, else→0
  f) Round Number (max 8): major(000): <=10p→8, <=20p→5 | minor(500): <=10p→5, <=20p→3 | else→0
  g) Volume Delta (±5): SUPPORT + bullish candle→+5, bearish→-5 | RESISTANCE ngược lại
  h) P24d CalcZonePrecisionScore ([-5,+13]): P27b linear gradient (dùng g_cached_atr14_smooth):
     width_ratio <= 0.15→+5 | ≤0.30→5→2 | ≤0.55→2→0 | ≤0.80→0→-2 | ≤1.20→-2→-5 | >1.20→-5
     + retest-refined (shrunk>=15%): +5 | + wick_filter: +3
  i) P36 Imbalance candle (+8): has_imbalance → +8. Detected in CreateRP: body>=70% range + vol>1.5×MA20

  return MathMin(tổng, 100.0)

=== 10.2 FINAL SCORE ===

CalcFinalScore(rp_index):
  rp = g_rp_array[rp_index]  // local copy
  rp.base_score = CalcBaseScore(rp_index)
  CheckZoneFVGOverlap(rp_index)  // writes has_fvg to g_rp_array directly
  rp.has_fvg = g_rp_array[rp_index].has_fvg  // sync FVG flags to local copy (v3.3 fix)
  rp.has_fvg_bullish = g_rp_array[rp_index].has_fvg_bullish

  adjusted = base_score
    + GetRegimeScoreAdj(rp_type)           // A: [-30, +20]
    - CalcDecayPenalty(rp_index)            // B: [0, -35+]
    + CalcRecentBonus(rp_index)             // B: [0, +15]
    + GetSessionScoreAdj(session_formed)    // E: [-20, +15]
    + GetDayOfWeekAdj()                     // [-10, +5]
    + GetStructureScoreAdj(rp_index)        // H: [-20, +15]
    + GetLiquiditySweepBonus(rp_index)      // H: [0, +20]
    + GetTrendAlignmentScore(rp_type)       // P20: [-25, +20]
    + CalcHTFNestingBonus(rp_index)         // v3.2: [0, +30] HTF zone nesting
    + CalcAbsorptionAdj(rp_index)           // P25b: [-10, +5]
    + CalcFVGBonus(rp_index)               // P34: [0, +15] FVG overlap
    + (is_role_reversed ? 15.0 : 0.0)
    + (is_breaker_block && is_role_reversed ? 10.0 : 0.0)  // P37: Breaker Block bonus
    // NOTE: First touch bonus removed — CalcTestQualityScore handles fresh premium (+10) via P35

  rp.final_score = MathMax(0, MathMin(adjusted, SCORE_CAP))
  rp.rp_level = ClassifyRPLevel(rp.final_score)
  g_rp_array[rp_index] = rp  // write back (FVG flags preserved)

P25b CalcAbsorptionAdj(rp_index):
  - Cần >=2 tests recorded. So sánh volume nửa đầu vs nửa sau
  - change > 0.50 → -10 (absorb) | > 0.20 → -5 | < -0.30 → +5 (hold) | else 0
```

---

## PHASE 4: ADVANCED MODULES (cần Phase 2+3)

---

### P11: RP_Confluence.mqh — Module D: Multi-TF Confluence

```
PERFORMANCE: CollectHTF CHỈ khi IsNewBarHTF(). MergeCluster sort-based O(N log N).
HTF data: CopyHigh/CopyLow batch (6 calls total thay vì 400+)

=== FUNCTIONS ===

1. CollectHTFReactionPoints():
   - CHỈ gọi khi htf_cache_valid==false hoặc IsNewBarHTF()
   - Scan g_htf_1/g_htf_2 swing points, batch CopyHigh/CopyLow/CopyClose
   - Retry MAX_HTF_RETRIES, fallback current TF

2. MergeClusterZones():
   - Reset confluence arrays. Gộp active RP (current+HTF)
   - P23: pre-allocate entries[] 1 lần. Sort by price → linear scan:
     gap <= merge_pips → add to zone, gap > merge_pips → start new
   - zone_type = majority vote, tf_description = "H1+H4+D1"
   | RP count | Multiplier | Bonus | Premium |
   | 2        | 1.3        | 10    | false   |
   | 3        | 1.5        | 25    | false   |
   | 4+       | 1.8        | 40    | true    |
   - Update: is_confluence=true, confluence_id=zone.id, g_rp_dirty=true
   - Cap: MAX_ZONE_RPS=8, giữ 8 score cao nhất
   - v3.0.1: merge loop MAX_MERGE_ITERATIONS=10

3. ApplyConfluenceScoring():
   - RP highest score trong zone: adjusted = score × multiplier + bonus
   - Clamp [0, SCORE_CAP], re-classify level

4. HandlePartialBreakout(rp_id):
   - Tách RP khỏi zone, g_confluence_needs_update=true
   - Remove rp_id từ zone.rp_ids[] (shift left, bounds-safe)
   - 3→2: 1.5→1.3, 2→1: giải tán zone

P20: UpdateHTFTrends():
   - Current TF: g_htf_trends[0] = g_current_trend
   - HTF_1/HTF_2: CopyClose 21 bars, compare close[1] vs close[10] vs close[20]
     up1&&up2→UP, down1&&down2→DOWN, else NONE

P20: GetTrendAlignmentScore(rp_type):
   - if !g_use_trend_alignment → 0. Count aligned/counter across 3 TFs
   - all aligned → +20 | 2/3 → +10 | all counter → -25 | else → -15
   - CHoCH exception: penalty×0.5

P20: IsTrendAligned(rp_type): return GetTrendAlignmentScore >= 0

v3.2: CalcHTFNestingBonus(rp_index): [0, +30]
   - Check if zone is confirmed by HTF swing points (same type: support↔support)
   - HTF1 nesting (within 1.0×ATR): +12 (e.g. H1 confirms M15)
   - HTF2 nesting (within 1.5×ATR): +20 (e.g. H4 confirms M15)
   - Both HTF1+HTF2 confirmed: +30 (full chain: M15→H1→H4)
   - Enables top-down workflow: H4 zone → H1 confirm → M15 entry
```

---

### P12: RP_EntrySetup.mqh — Module C: Entry Setup

```
=== FUNCTIONS ===

1. CheckEntryConditions(): loop active RP (score >= g_min_score_to_show)
   ALL must true:
   a) Close[1] trong zone
   b) Bar[1] pattern hợp lệ (DetectCandlePattern(1))
   c) !CHOPPY (ngoại lệ: Premium >=120)
   d) !g_spread_blocked
   e) !g_news_blackout
   f) P20: IsTrendAligned (ngoại lệ: Premium >=120)
   → CreateEntrySetup()

2. CreateEntrySetup(rp_index):
   - BUY: entry=RP_High(1)+buffer, sl=RP_Low(1)-buffer
   - SELL: entry=RP_Low(1)-buffer, sl=RP_High(1)+buffer
   - TP1=FindNearestRPInDirection(skip=0), fallback ATR×2
   - TP2=FindNearestRPInDirection(skip=1), fallback ATR×4
   - Guard: sl_pips < 0.1 → 0.1
   - Max: MAX_SETUPS=10, thay lowest score. 2 cùng hướng→"PREFERRED", ngược→warning

3. UpdateSetups(): per-bar: age check + entry trigger (RP_Close(1))
4. FindNearestRPInDirection(from, dir, skip): BUY→tìm RESISTANCE trên, SELL→SUPPORT dưới
   Performance: g_rp_count>30 → binary search trên sorted cache
```

---

### P13: RP_Stats.mqh — Performance Tracker

```
=== FUNCTIONS ===
1. InitStats(): ZeroMemory + tracking_start
2. OnRPFormed(rp_index): total_formed++, theo level + session
3. OnRPReacted(rp_index): total_reacted++, theo level + session
4. OnRPBroken(rp_index): total_broken++
5. UpdateStats(): mỗi nến, check bar[1] phản ứng/phá
6. GetHitRate(): reacted / (reacted + broken)
7. GetLevelHitRate(level): theo level
8. GetBestSession()/GetWorstSession(): so sánh hit rate
9. FormatStatsString(): "Hit Rate: 67% (42/63) | Premium: 78% | Best: London 74%"
KHÔNG lưu file. Reset khi reload.
```

---

## PHASE 5: UI (cần Phase 4)

---

### P14: RP_Drawing.mqh — Zones, Labels, Session BG

```
=== COLOR SYSTEM ===
BlendColor(fg, bg, alpha_pct) cho OBJ_RECTANGLE.
P28 alpha: PREMIUM=45, LV1=30, LV2=20, LV3=15 (v3.3: subtle fill, edges carry visual weight)

=== FUNCTIONS ===

1. GetRPColor(rp_index): role_rev→amber | else→type color
   P28: GetZoneBaseColor: Support→blue(50,160,220), Resistance→red(220,80,80)
   v3.3: All levels same color per type — differentiation via alpha/edge, not color

2. DrawRPZone(rp_index):
   - **Level toggle (v3.2→v3.3)**: IsLevelVisible(rp_level) — 4 individual toggles, default: only Premium ON
   - OBJ_RECTANGLE FILL+BACK, time_formed→now+20bars
   - P28: +2 OBJ_TREND edge lines (EDGE_H_{id}, EDGE_L_{id}), width theo level
   - P23: lazy update — static props 1 lần, chỉ update time_end. Color/price CHỈ khi dirty

3. DrawConfluenceGlow(conf_index): 3+ RP → 3 chồng rectangles (14%, 30%, 50%)
   - **v3.2**: skip glow if all component RPs are display-suppressed

4. DrawRPLabel(rp_index): v3.3 minimal format
   - Format: "S 142 FVG" or "R 128 BB" (direction + score + tag)
   - Tags: BB=Breaker, RR=RoleRev, FVG=FairValueGap, C=Confluence, ""=normal
   - Font: Arial Bold, size=g_label_font_size+1
   - **v3.2**: label positioned at right edge of zone (+21 bars, ANCHOR_LEFT)
   - v3.0.2: collision tracking — nudge nếu < 1.5× zone_width_pips

5. DrawEntrySetupPanel(setup_index): panel BUY/SELL trên chart
6. DrawSLTPLines(setup_index): SL=FireBrick dash, TP=Khaki dot, Entry=solid
7. CreateSessionObjects(): 1 LẦN trong OnInit, colors blend 10%
7b. UpdateSessionVisibility(): mỗi bar, chỉ update OBJPROP_TIME
8. RedrawChangedRP():
   - **v3.3 SuppressOverlappingZones()**: ATR×0.8 margin (same-type: ATR×1.2), keep strongest
     g_rp_display_suppressed[] + g_prev_suppressed[] for state change detection
     Suppressed zones: objects deleted, auto-restored when winner expires
     v3.3: zones suppressed 50+ bars → permanently deactivated (free slots)
   - **v3.3 Zone visual**: time_start = max(time_formed, now-100bars) — no long trailing zones
   - **v3.3 Glow skip**: Premium-only mode → confluence glow disabled (clean chart)
   - **v3.3 Edge width**: Premium=2px (was 3), softer fill alpha
   - CHỈ vẽ lại RP có state thay đổi (static prev arrays compare)
9. DeleteRPObjects(rp_id): zone + label + glow + edges
10. DeleteAllObjects(): ObjectsDeleteAll(0, OBJECT_PREFIX)
11. EnforceObjectLimit(): v3.0.1 batch delete — tính N upfront, 1 pass collect lowest, batch delete
12. UpdateFontSizes(): detect CHART_SCALE → adjust ±2, min 6

v3.0.1: ObjectCreate/Delete counter chỉ +/- khi return true
```

---

### P15: RP_Alerts.mqh — 4 Levels

```
PERFORMANCE: CheckAllAlerts CHỈ khi giá di chuyển >=2 pips. Cấp 2-4 per-bar only.
Early exit: skip RP nếu all alert_sent[]==true.

=== 4 CẤP ===
| Cấp | Trigger | Format |
| 1 | Giá cách RP <= proximity_pips VÀ đang đi VỀ PHÍA RP | "Approaching [PAIR]..." |
| 2 | Bar[1] pattern tại zone | "RP REACTION..." |
| 3 | Role Reversal confirmed | "ROLE REVERSAL..." |
| 4 | Confluence Premium >=120 | "PREMIUM..." |

Filters: Dead session→skip(if flag), News→block cấp 1-2, Spread→block cấp 2
NGOẠI LỆ: Premium >=120 LUÔN alert

=== FUNCTIONS ===
1. CheckAllAlerts(): loop active RP, early exit, check 4→3→2→1
2. CheckProximityAlert(rp): distance + direction check (close[1] vs close[2])
3. CheckReactionAlert(rp): bar[1] trong zone + pattern (dùng cached, KHÔNG re-detect)
4. CheckRoleReversalAlert(rp): is_role_reversed && !alert_sent[2]
5. CheckPremiumAlert(rp): score>=120 && is_confluence && !alert_sent[3]
6. SendRPAlert(level, msg): Alert + SendNotification + Print + set alert_sent
7. ResetAlertIfDistant(rp): distance >= reset_pips → reset alert_sent[0..3]
```

---

### P16: RP_Dashboard.mqh — Dashboard UI

```
P28 layout compact:
  Row 0: "RP v3.0  EURUSD  H1"
  Row 1: "London Open │ TREND 28 │ BUY preferred"
  Row 2: "ATR 12.4p  Sprd 1.2p  News clear"
  Row 3-4: Nearest RP (▲ S / ▼ R)
  Row 5-6: Radar top 5 (partial sort O(N), KHÔNG full sort)
  Row 7: "12z  3c  1rr  1s │ Hit 72%"
  Row 8: "► BUY 1.09650  SL:35  R:R 1:2.1" (if active)

  P20: thêm dòng "TREND CTF:↑ H4:↑ D1:→ ALIGNED"
  RevR count = số RP có is_role_reversed==true

BG: C'16,20,28' 90%, border C'40,48,62'
v3.0.2: SafeUnicode(code, fallback) cho VPS/Wine compatibility

=== FUNCTIONS ===
1. CreateDashboard(): OBJ_RECTANGLE_LABEL + OBJ_LABEL, prefix DASH_
2. UpdateDashboard(): mỗi nến, sections ẩn/hiện theo context
3. UpdateRadar(): top 5 nearest, MathMin(5, g_rp_count)
4. GetBiasString(): STRONG+UP→"BUY preferred", CHOPPY→"Avoid trading"
5. RepositionDashboard(): on CHARTEVENT_CHART_CHANGE
6. DeleteDashboard(): ObjectsDeleteAll(0, OBJECT_PREFIX+"DASH_")
```

---

## PHASE 6: INTEGRATION

---

### P17: RP_Main.mq5 — Main Indicator File

```
#property strict | indicator_chart_window | buffers 0 | plots 0

INCLUDES (theo thứ tự):
  RP_Defines → RP_Utils → RP_RegimeFilter → RP_Session → RP_DynamicDecay
  → RP_NewsFilter → RP_SpreadFilter → RP_Detection → RP_MarketStructure
  → RP_FVG → RP_Confluence → RP_Scoring → RP_EntrySetup → RP_Stats
  → RP_Drawing → RP_Dashboard → RP_Alerts → RP_Logger

=== INPUT PARAMETERS (đầy đủ) ===

// PRESET
ENUM_TF_PRESET TF_Preset = PRESET_AUTO;

// SWING
Swing_Lookback=3[1-10], Min_RP_Distance_Pips=20[5-100], Min_Reaction_Move_Pips=15[5-100]
Initial_Bars_To_Scan=500[50-2000], Use_Adaptive_Reaction=true, Reaction_ATR_Multiplier=0.5

// BREAKOUT
Breakout_Confirm_Pips=5[1-50], Max_Retest_Bars=50[10-200]

// REGIME (A)
ADX_Period=14, ADX_Strong_Threshold=25.0, ADX_Weak_Threshold=20.0, Use_Regime_Filter=true

// DECAY (B)
Decay_Interval_Bars=20, Decay_Points_Per_Interval=2, Max_RP_Age_Bars=300, Use_Dynamic_Score=true

// ENTRY (C)
Show_Entry_Setup=true, SL_Buffer_Pips=5, Entry_Buffer_Pips=2, Min_RR_Ratio=1.5, Max_Setup_Age_Bars=10

// CONFLUENCE (D)
Confluence_Merge_Pips=10, Use_Confluence_Zones=true, HTF_Bars_To_Scan=200

// SESSION (E)
UTC_Offset=3, Alert_Only_Active_Sessions=true, Show_Session_Background=true

// FIBO
Fibo_Lookback_Bars=100, Fibo_Tolerance_Pips=5

// CANDLE
Min_Candle_Size_Pips=3

// NEWS (F)
Use_News_Filter=true, News_Blackout_Minutes=30, News_Filter_High_Only=false

// SPREAD (G)
Use_Spread_Filter=true, Spread_Alert_Multiplier=2.0, Spread_Block_Multiplier=3.0

// MARKET STRUCTURE (H)
Use_Market_Structure=true, Structure_Lookback_Bars=50[20-100]

// MULTI-TF
Show_HTF_1=true, HTF_1=PERIOD_H4, Show_HTF_2=true, HTF_2=PERIOD_D1

// TREND ALIGNMENT (P20)
Use_Trend_Alignment=true

// DISPLAY
Zone_Width_Pips=4, Min_Score_To_Show=40
Show_Premium=true, Show_Level1=false, Show_Level2=false, Show_Level3=false  // v3.3: individual toggles
Show_Dashboard=true, Show_Performance_Stats=true
Proximity_Alert_Pips=20, Reset_Alert_Pips=30
Dashboard_Corner=DASH_TOP_LEFT, Dashboard_Font_Size=9, Label_Font_Size=8

// COLORS
Color_Premium=clrGold, Color_Level1=clrCrimson, Color_Level2=clrOrange, Color_Level3=clrSkyBlue
Color_Confluence=clrMediumPurple, Color_RoleReversal=clrMagenta
Color_EntryBuy=clrLimeGreen, Color_EntrySell=clrRed

// LOGGER (P26)
Enable_Logger=false, Outcome_Measure_Bars=20

=== OnInit() ===
1. ApplyTFPreset(): PRESET_AUTO detect Period(), copy input→globals
2. ValidateInputs(): clamp ranges, validate HTF hierarchy
3. DetectPairType() // P22
4. ArrayResize: g_rp_array(MAX_RP_COUNT), g_confluence_array(MAX_CONFLUENCE),
   g_setup_array(MAX_SETUPS), g_rp_dirty(MAX_RP_COUNT), g_last_calc_bar(MAX_RP_COUNT),
   g_fibo_legs(MAX_FIBO_LEGS). ArrayInitialize(dirty=true, last_calc=-1)
5. InitRPIDMap() // v3.0.1
6. if(!InitIndicatorHandles()) return INIT_FAILED
7. InitStats()
8. if(g_show_dashboard) CreateDashboard()
9. if(g_show_session_background) CreateSessionObjects()
10. EventSetTimer(1)
11. Return INIT_SUCCEEDED

=== OnCalculate() — PERFORMANCE-OPTIMIZED ===

// === PER-TICK (<1ms) ===
UpdateSpreadFilter();

if(MathAbs(bid - g_last_alert_check_price) >= PipsToPrice(2)) {
   CheckAllAlerts();
   g_last_alert_check_price = bid;
}

UpdateSetupInvalidation();  // Chỉ check SL hit, loop 10 setups

// === PER-BAR (IsNewBar()) ===
if(!IsNewBar()) return rates_total;

// STEP 0: Cache
UpdateBarCache();  RevalidateHandles(); // mỗi 100 bars

// P22: first-run volatility scaling
static bool scaling_applied = false;
if(!scaling_applied && g_cached_atr14 > 0) { ApplyVolatilityScaling(); scaling_applied = true; }

// STEP 1: Market Context
UpdateCurrentSession();  UpdateMarketRegime();
if(g_use_trend_alignment) UpdateHTFTrends(); // P20

// STEP 2: News (throttled 5 min)
static datetime last_news_check = 0;
if(TimeCurrent() - last_news_check >= 300) { UpdateNewsFilter(); last_news_check = TimeCurrent(); }

// STEP 3: Market Structure
if(g_use_market_structure) UpdateMarketStructure();

// STEP 4: RP Detection
static bool first_run = true;
int scan_bars = first_run ? g_initial_bars_to_scan : g_swing_lookback*2+5;
int prev_rp_count = g_rp_count;
DetectSwingPoints(scan_bars);  first_run = false;

// STEP 4b: FVG Detection (P34)
DetectFVG(scan_bars);

// STEP 5: Breakout & Retest
CheckBreakoutsAndRetests();

// STEP 6: Scoring — CHỈ DIRTY RPs
for(i = prev_rp_count; i < g_rp_count; i++) g_rp_dirty[i] = true;
for(i = 0; i < g_rp_count; i++) {
   if(!g_rp_array[i].is_active) continue;
   if(bars_since >= g_decay_interval_bars) g_rp_dirty[i] = true;
   if(!g_rp_dirty[i]) continue;
   CalcFinalScore(i);  g_rp_dirty[i] = false;  g_last_calc_bar[i] = current_bars;
}
UpdateAllDecay();

// STEP 7: Confluence — CHỈ khi có RP mới hoặc breakout
if(g_use_confluence_zones && (rp_count_changed || g_confluence_needs_update)) {
   if(IsNewBarHTF(g_htf_1) || !g_htf1_cache_valid) { CollectHTFReactionPoints(); g_htf1_cache_valid=true; }
   if(IsNewBarHTF(g_htf_2) || !g_htf2_cache_valid) { CollectHTFReactionPoints(); g_htf2_cache_valid=true; }
   MergeClusterZones();  ApplyConfluenceScoring();  g_confluence_needs_update=false;
}

// STEP 8: Entry Setup
if(g_show_entry_setup) CheckEntryConditions();

// STEP 9: UI — chỉ redraw thay đổi
RedrawChangedRP();
if(g_show_session_background) UpdateSessionVisibility();
if(g_show_dashboard) UpdateDashboard();
EnforceObjectLimit();  UpdateStats();

// P26: if(g_use_logger) CheckPendingOutcomes(g_outcome_measure_bars);

// Broker disconnect: gap > 5 bars → rescan + reset alerts
static int last_bar_count = 0;
if(last_bar_count > 0 && current_bars - last_bar_count > 5) { first_run=true; reset alerts; }
last_bar_count = current_bars;
return rates_total;

=== IsNewBarHTF(tf) === static datetime, compare iTime
=== UpdateSetupInvalidation() === per-tick: loop setups, check SL hit only

=== OnDeinit(reason) ===
EventKillTimer, DeleteAllObjects, DeleteDashboard, ReleaseIndicatorHandles
REASON_PARAMETERS → xóa objects, giữ data, first_run=true
REASON_CHARTCHANGE/RECOMPILE/REMOVE → full reset

=== OnChartEvent === CHARTEVENT_CHART_CHANGE → RepositionDashboard + UpdateFontSizes
=== OnTimer === Flash toggle, decrement flash_count

=== TF PRESET TABLE (v3.3: M15 entry-optimized, H1+H4 clean premium) ===
Param                    M15    M30    H1    H4     D1
Swing_Lookback            5      5     5      4      3
Min_RP_Distance_Pips     20     25    40     50     40
Min_Reaction_Move_Pips   15     12    20     25     40
Initial_Bars_To_Scan    800    600   500    300    200
Breakout_Confirm_Pips     3      3     7     10     15
Max_Retest_Bars          40     40    50     40     30
Decay_Interval_Bars      30     15    15     15     10
Decay_Points/Interval     2      3     3      3      3
Max_RP_Age_Bars         300    200   250    180    100
SL_Buffer_Pips            2      3     5      8     15
Entry_Buffer_Pips         1      1     2      3      5
Max_Setup_Age_Bars        8      8    10     10      5
Confluence_Merge_Pips    10      8    15     20     25
HTF_Bars_To_Scan        200    200   200    150    100
Fibo_Lookback_Bars       80     80   100    100     60
Fibo_Tolerance_Pips       3      3     5      8     12
Min_Candle_Size_Pips      4      2     5      8     10
Zone_Width_Pips           3      3     4      6     10
Min_Score_To_Show        75     50    80     80     35
Proximity_Alert_Pips     10     15    20     30     50
Reset_Alert_Pips         15     20    30     40     60
Structure_Lookback       40     30    50     50     80
HTF_1                    H1     H1    H4     D1     W1
HTF_2                    H4     H4    D1     W1    MN1

ATR Baseline: M15=10p, M30=15p, H1=25p, H4=50p, D1=100p

PRESET_AUTO: Period()<=M15→M15, <=M30→M30, <=H1→H1, <=H4→H4, else→D1
```

---

## PHASE 7: RELIABILITY + PERFORMANCE UPGRADES

---

### P19: Fibonacci Swing-to-Swing Engine (sửa RP_Utils.mqh)

```
THAY THẾ UpdateFiboCache() — Fibo chỉ valid từ swing leg hoàn chỉnh (A→B).

UpdateFiboCache():
  STEP 1: Batch CopyHigh/CopyLow (P23). Tìm max 6 swing points trong bars[1..lookback]
  STEP 2: Ghép cặp swing types khác nhau (H+L). Filter: leg >= 2×ATR, price đang retrace
  STEP 3: Tính fibo levels: bullish leg→retracement từ B xuống, bearish→từ B lên
    fibo_382 = B ± range×0.382, _500 = ×0.500, _618 = ×0.618, _786 = ×0.786
  STEP 4: Update backward-compatible cache (g_cached_fibo_*) từ leg[0]
  - Max MAX_FIBO_LEGS=3 legs

CalcFibonacciScore(price): scan legs, 618→10, 786→8, 500→7, 382→4.
  Fibo confluence (trùng 2+ legs) → +3. Cap 13.
```

---

### P22: Pair-Adaptive Parameters (sửa RP_Utils.mqh + RP_Session.mqh + RP_Main.mq5)

```
1. DetectPairType(): gọi OnInit
   - g_is_jpy_pair = StringFind("JPY")>=0
   - g_is_gbp_pair = StringFind("GBP")>=0
   - g_is_cross_pair = not in [EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD,NZDUSD]

2. ApplyVolatilityScaling(): gọi 1 LẦN khi first_run && g_cached_atr14>0
   - ratio = ATR14 / baseline (M15=10p, M30=15p, H1=25p, H4=50p, D1=100p). Clamp [0.7, 2.5]
   - Scale: min_rp_dist, min_reaction, breakout_confirm, confluence_merge, fibo_tolerance,
     proximity_alert, reset_alert, sl_buffer, zone_width(min 3), min_candle_size(min 2)
   - Cross pairs: spread thresholds nới (alert≥2.5, block≥4.0)

3. Session scoring pair-adaptive: xem P4 (đã tích hợp)
```

---

### P23: Performance Optimization (batch copy + UI efficiency)

```
FIX 1: UpdateFiboCache → CopyHigh/CopyLow batch (540 calls → 2)
FIX 2: DetectSwingPoints → CopyHigh/CopyLow batch (9,900 calls → 2)
FIX 3: MergeClusterZones → pre-allocate entries[] 1 lần (50+ allocs → 1)
FIX 4: DrawRPZone → lazy property update (700 calls/bar → 100 when clean)
```

---

### P26: Zone Data Logger (tạo RP_Logger.mqh)

```
3 CSV files trong MQL5/Files/RP_Logs/:
1. {SYMBOL}_{TF}_zones.csv — mỗi zone tạo (timestamp, id, type, price, zone, pattern, score...)
2. {SYMBOL}_{TF}_tests.csv — mỗi test (timestamp, id, is_body_test, volume, zone_width before/after...)
3. {SYMBOL}_{TF}_outcomes.csv — reaction sau N bars (max_favorable, max_adverse, outcome classification)

Outcome: STRONG_REACT(>=1xATR), WEAK_REACT(>=0.5x), FAILED(adverse>=0.5x), NEUTRAL, BROKEN

Functions: InitLogger, DeinitLogger, LogZoneCreated, LogZoneTest, LogZoneBroken,
  RegisterPendingOutcome, CheckPendingOutcomes
- Input: Enable_Logger(false), Outcome_Measure_Bars(20)
- v3.0.2: ArrayResize trước check g_use_logger, bool return + GetLastError
- APPEND mode, header 1 lần, auto rotation 10MB
```

---

### P34: RP_FVG.mqh — Fair Value Gap Detection (v3.3)

```
FVG = khoảng trống giữa high[i+1] và low[i-1] (3-candle pattern).
Zone overlap với FVG = institutional imbalance → tăng accuracy.

=== DATA STRUCTURES ===
#define MAX_FVG_COUNT 50
SFVG { double high, low; datetime time_formed; int bar_formed;
       bool is_bullish, is_filled, is_active; }
SFVG g_fvg_array[MAX_FVG_COUNT];  int g_fvg_count = 0;

=== FUNCTIONS ===

1. DetectFVG(bars_to_scan): scan bar[2..limit] (anti-repainting)
   - Bullish FVG: high[i+1] < low[i-1] → gap = [high[i+1], low[i-1]]
   - Bearish FVG: low[i+1] > high[i-1] → gap = [high[i-1], low[i+1]]
   - Min gap size: 0.30 × ATR14 (filter micro-gaps)
   - Gọi AddFVG() + CheckFVGFilled()

2. AddFVG(gap_low, gap_high, bar_idx, is_bullish):
   - Duplicate check by time_formed + direction
   - Eviction: inactive first → oldest active

3. CheckFVGFilled(): mỗi bar, check bar[1]
   - Bullish FVG filled: low[1] <= gap_low
   - Bearish FVG filled: high[1] >= gap_high
   - Filled → is_active=false

4. CheckZoneFVGOverlap(rp_index): bool
   - Check zone[high,low] vs tất cả active FVG
   - Overlap → set rp.has_fvg=true, rp.has_fvg_bullish
   - Gọi trong CalcFinalScore (trước scoring aggregation)

5. CalcFVGBonus(rp_index): [0, +15]
   - Aligned (SUPPORT+bullish FVG / RESISTANCE+bearish FVG): +15
   - Misaligned (still institutional imbalance): +5
   - No FVG: 0

Integration: RP_Main.mq5 STEP 4b: DetectFVG(scan_bars) SAU DetectSwingPoints
Include order: RP_FVG trước RP_Confluence (FVG data cần trước scoring)
```

---

### P35: Multi-Touch Mitigation (sửa RP_Scoring.mqh CalcTestQualityScore)

```
ICT Concept: mỗi touch DRAIN liquidity từ zone. Zone mạnh nhất khi chưa test hoặc test 1 lần.
Thay thế scoring tăng dần (v3.2) bằng mitigation-aware curve.

CalcTestQualityScore(rp_index): [-15, +12]
  weighted = strong_test_count × 1.0 + weak_test_count × 0.5

  | Weighted | Score | Lý do |
  |----------|-------|-------|
  | < 0.1    | +10   | Fresh premium — untested supply/demand |
  | < 1.5    | +12   | Confirmed — zone validated by price action |
  | < 2.5    | +5    | Depleting — liquidity draining |
  | 3+       | 5 - (excess×5), floor -15 | Mitigated — zone likely exhausted |

Impact: Zone 3+ test bị penalty → ít zone cũ/yếu hiển thị → chart sạch hơn.
First touch bonus (+10 trong CalcFinalScore cũ) đã tích hợp vào weighted<0.1 case.
```

---

### P36: Imbalance Candle Bonus (sửa RP_Detection.mqh + RP_Scoring.mqh)

```
Imbalance candle = nến có body >= 70% range VÀ volume > 1.5× MA20.
Cho thấy institutional urgency — zone tạo bởi/gần imbalance candle đáng tin hơn.

Detection (trong CreateRP, sau zone width clamp):
  - Scan zone_bar ± 1 (3 nến: trước, tại, sau zone bar)
  - Nếu bất kỳ nến nào có body >= 70% range + vol > 1.5× g_cached_volume_ma20:
    rp.has_imbalance = true, break

Scoring (trong CalcBaseScore):
  - has_imbalance → +8 điểm (base score component)
  - Không cần direction alignment — imbalance bất kỳ hướng nào đều cho thấy institutional interest

Range: [0, +8]
```

---

### P37: Breaker Block Detection (sửa RP_Detection.mqh + RP_Scoring.mqh)

```
ICT Concept: Breaker Block = Order Block bị phá bởi impulse mạnh, sau đó được retest từ phía đối diện.
Khác role reversal thường: (1) phải là OB zone, (2) breakout phải impulsive (body >= 0.8×ATR).
Breaker Block có xác suất reversal cao hơn role reversal thường ~5-10%.

Detection (2 bước):
  STEP 1 — HandleBreakout (khi OB zone bị phá):
    if is_order_block AND breakout candle body >= 0.8 × g_cached_atr14:
      rp.is_breaker_block = true  // candidate
      Keep zone active (không deactivate) để chờ retest

  STEP 2 — CheckRoleReversalRetest (khi price quay lại retest):
    Role reversal confirmed → is_role_reversed = true
    is_breaker_block vẫn giữ true → scoring áp dụng bonus

Scoring (trong CalcFinalScore):
  - Role reversal: +15 (existing)
  - Breaker Block (is_breaker_block && is_role_reversed): +10 thêm
  - Tổng cho Breaker Block: +25 (15 + 10)

Range: [0, +10] (trên cơ sở role reversal)
```

---

### P32: Adaptive Swing Lookback (sửa RP_Detection.mqh)

```
AdaptiveSwingLookback(bar_idx):
  ATR > 1.5× MA50 (high vol): lookback = base + 2
  ATR < 0.7× MA50 (low vol): lookback = base - 1 (min 2)
  Normal: lookback = base (g_swing_lookback)
```

---

### P33: Volume-Weighted Zone Center (sửa RP_Detection.mqh)

```
ShiftZoneToVolume(rp, zone_bar, base_size):
  - Tìm bar có tick volume cao nhất trong base
  - weighted center = Σ(price_i × vol_i) / Σ(vol_i)
  - Shift zone 20% về phía weighted center. Không vượt ATR cap
```

---

## STABILITY PATCHES

---

### v3.0.1 (5 Critical Fixes)

| # | File | Fix |
|---|------|-----|
| 1 | Drawing, Dashboard | ObjectCreate/Delete counter chỉ +/- khi return true (12+1 vị trí) |
| 2 | Confluence | MergeOverlapping while(merged) → MAX_MERGE_ITERATIONS=10 |
| 3 | Utils+Confluence+Detection+Drawing | O(N²)→O(1) RP ID lookup: g_rp_id_to_index[] + FindRPIndexByID(), 7 linear scan thay thế |
| 4 | Drawing | EnforceObjectLimit batch delete: tính N upfront, 1 pass collect, batch delete |
| 5 | Detection | OB bounds: `bool ob_valid = (ob_bar >= RP_SHIFT_MIN && ob_bar < available_bars)` |

OnInit: thêm `InitRPIDMap()` sau ArrayResize.

### v3.0.2 (4 Additional Fixes)

| # | File | Fix |
|---|------|-----|
| 6 | Logger | ArrayResize trước g_use_logger check, ArraySize guard, bool return + GetLastError |
| 7 | Detection | EvictRP priority 4: force-evict oldest confluence (gọi HandlePartialBreakout trước) |
| 8 | Dashboard | SafeUnicode(code, fallback) cho VPS/Wine (8 vị trí + DashSep) |
| 9 | Drawing | Label collision: g_label_placed_prices[], AdjustLabelPrice(), nudge max 3 lần |

### v3.1.0 — Accuracy & Performance Review (16 fixes)

#### Accuracy Fixes (ảnh hưởng chất lượng tín hiệu)

| # | File | Fix | Impact |
|---|------|-----|--------|
| 1 | Scoring | `bar_formed` drift → dùng `iBarShift(time_formed)` cho Volume, Pattern, VolumeDelta | **CRITICAL**: score tính từ bar sai khi RP tồn tại lâu |
| 2 | Scoring | Pinbar alignment dùng wick direction thay vì body direction | **HIGH**: pinbar hợp lệ bị mất 70% score |
| 3 | Scoring | Fibo confluence bonus +3 apply vào `best_score` sau loop thay vì trong loop | **MEDIUM**: bonus bị mất nếu leg ordering không đúng |
| 4 | Scoring | Round number phân biệt major (000, +8) vs minor (500, +5) | **LOW**: cải thiện phân loại |
| 5 | Alerts | Re-read RP SAU `ResetAlertIfDistant()` (stale local copy) | **HIGH**: alert không fire lại sau reset |
| 6 | Utils | `IsNewBarHTF` dùng switch-case mapping thay vì `%30` (M5/H1 collision) | **CRITICAL**: HTF confluence không cập nhật trên M5+H1 |
| 7 | Detection | `HandleBreakout` deactivate RP bị phá (trừ confluence zones) | **MEDIUM**: broken zones tiếp tục tạo signals |
| 8 | Detection | Momentum scan giới hạn 50 bars thay vì scan toàn bộ | **MEDIUM**: giảm noise RPs từ swings cũ |
| 9 | Detection | Role reversal scan chỉ bars SAU RP formation (`iBarShift`) | **MEDIUM**: tránh false role reversal |
| 10 | DynamicDecay | `CalcDecayPenalty` + `UpdateAllDecay` dùng `iBarShift(time_formed)` | **HIGH**: decay age tính sai do bar_formed drift |

#### Performance Fixes (tối ưu CPU/rendering)

| # | File | Fix | Impact |
|---|------|-----|--------|
| 11 | Main | `ChartRedraw(0)` chỉ gọi khi `flashing_count > 0` | **HIGH**: tiết kiệm full repaint mỗi giây |
| 12 | Drawing | Confluence glow chỉ redraw khi `g_confluence_needs_redraw` | **MEDIUM**: tránh vẽ lại mỗi bar |
| 13 | Drawing | Xóa unused `vis_start`/`visible_bars` trong `UpdateSessionVisibility` | **LOW**: dead code |
| 14 | Utils | `PipValue()` cache static (digits/point không đổi trong session) | **MEDIUM**: giảm hàng chục SymbolInfo calls/tick |
| 15 | Utils | `SetRPIDMap` xử lý ID overflow: reassign IDs khi `>= MAX_RP_ID_MAP` | **MEDIUM**: tránh O(1)→O(N) degradation |
| 16 | EntrySetup | Thay linear scan bằng `FindRPIndexByID()` (2 vị trí) | **LOW**: O(N²)→O(1) |

#### Code Cleanup

| # | File | Fix |
|---|------|-----|
| 17 | Session | Xóa `DrawSessionBackgrounds()` dead code |
| 18 | Utils | Thêm `g_confluence_needs_redraw` flag |

### v3.2.0 — Lower TF Accuracy + Zone Display Optimization

#### Zone Display Optimization

| # | File | Fix | Impact |
|---|------|-----|--------|
| 1 | Drawing | **SuppressOverlappingZones()**: ATR×0.5 margin, giữ zone mạnh nhất (Premium ưu tiên) | **HIGH**: loại bỏ chồng chéo zone trên chart |
| 2 | Drawing | g_rp_display_suppressed[] + g_prev_suppressed[] cho state change tracking | **HIGH**: zone tự phục hồi khi winner hết hạn |
| 3 | Drawing | Confluence glow skip khi tất cả component RPs bị suppressed | **MEDIUM**: glow không hiện cho zone ẩn |
| 4 | Drawing | Label di chuyển sang bên phải zone (+21 bars, ANCHOR_LEFT) | **LOW**: UI sạch hơn |
| 5 | Drawing | Xóa "Tested:Nx" khỏi label → format: `PRE \| TYPE SCORE \| TF \| Status` | **LOW**: label ngắn gọn |
| 6 | Drawing | Level icon: PREMIUM → "PRE" | **LOW**: compact |
| 7 | Drawing | **Level toggle**: 4 inputs Show_Premium/Level1/Level2/Level3 + IsLevelVisible() | **HIGH**: bật/tắt từng level riêng |
| 8 | Drawing | g_prev_types[] thêm ArrayInitialize(RP_SUPPORT) | **LOW**: tránh unnecessary redraw frame đầu |

#### M15 Preset & Lower TF Accuracy

| # | File | Fix | Impact |
|---|------|-----|--------|
| 9 | Defines | Thêm PRESET_M15 vào ENUM_TF_PRESET | **HIGH**: M15 có bộ tham số riêng |
| 10 | Main | PRESET_M15: swing=7, reaction=15, decay_interval=60, max_age=500, candle_min=3 | **HIGH**: lọc noise M15 |
| 11 | Main | PRESET_AUTO: Period()<=M15 → PRESET_M15 (trước đây map sang M30) | **HIGH**: auto-detect đúng |
| 12 | Utils | ATR baseline M15=10 pips (tách khỏi M30=15) | **MEDIUM**: volatility scaling chính xác |

#### Zone Creation Hardening (M15/M30)

| # | File | Fix | Impact |
|---|------|-----|--------|
| 13 | Detection | **Session gate**: reject zone formed during SESSION_DEAD trên M15/M30 | **HIGH**: loại ~70% false zones |
| 14 | Detection | **Adaptive reaction floor**: min reaction = max(preset, 0.6×ATR) trên M15/M30 | **HIGH**: chặn sub-5-pip reactions |
| 15 | Detection | **Wick filter TF-adaptive**: M15/M30 threshold 50%/25% (vs H1+ 60%/30%) | **MEDIUM**: zone chính xác hơn |
| 16 | Detection | Xóa variable shadowing: `tf` → reuse `tf_cur` trong ATR width cap | **LOW**: code quality |

#### HTF Nesting Bonus (Multi-TF Top-Down)

| # | File | Fix | Impact |
|---|------|-----|--------|
| 17 | Confluence | **CalcHTFNestingBonus()**: [0, +30] — reward zones confirmed by HTF zones | **HIGH**: H4→H1→M15 workflow |
| 18 | Scoring | Tích hợp CalcHTFNestingBonus vào CalcFinalScore | **HIGH**: zone M15 có HTF confirm lên Premium |

HTF Nesting Bonus chi tiết:
- HTF1 only (e.g. H1 confirms M15): +12
- HTF2 only (e.g. H4 confirms M15): +20
- Both HTF1+HTF2 (full chain): +30
- Requires same type match (support↔support, resistance↔resistance)
- ATR-based margin: HTF1 within 1.0×ATR, HTF2 within 1.5×ATR

---

### v3.3.0 — FVG Detection + Multi-Touch Mitigation + Zone Accuracy

#### New Module: RP_FVG.mqh (P34)

| # | File | Feature | Impact |
|---|------|---------|--------|
| 1 | RP_FVG.mqh | **DetectFVG()**: 3-candle gap detection, min 0.3×ATR, anti-repainting | **HIGH**: institutional imbalance confirmation |
| 2 | RP_FVG.mqh | **CheckZoneFVGOverlap()**: zone↔FVG overlap check with direction alignment | **HIGH**: +15 bonus for aligned FVG |
| 3 | RP_FVG.mqh | **CheckFVGFilled()**: auto-deactivate filled FVGs | **MEDIUM**: prevent stale FVG matches |
| 4 | Defines | SReactionPoint: +has_fvg, +has_fvg_bullish | **LOW**: data structure |
| 5 | Main | STEP 4b: DetectFVG(scan_bars) after swing detection | **HIGH**: FVG data ready for scoring |
| 6 | Scoring | CalcFinalScore: +CalcFVGBonus() [0, +15] + FVG flag sync fix | **HIGH**: FVG-confirmed zones score higher |

#### Multi-Touch Mitigation (P35)

| # | File | Feature | Impact |
|---|------|---------|--------|
| 7 | Scoring | **CalcTestQualityScore rewrite**: mitigation-aware curve [-15, +12] | **CRITICAL**: 3+ touch zones penalized |
| 8 | Scoring | Fresh zone premium (+10) built into test score, removed duplicate from CalcFinalScore | **MEDIUM**: cleaner scoring logic |

#### Zone Quality & Display

| # | File | Feature | Impact |
|---|------|---------|--------|
| 9 | Drawing | **Level toggles**: Show_Premium/Level1/Level2/Level3 inputs replace dropdown | **HIGH**: independent level control |
| 10 | Utils | **IsLevelVisible()**: check level toggle state | **MEDIUM**: clean filter API |
| 11 | Drawing | **Overlap margin**: ATR×0.5 → ATR×0.8, same-type: ATR×1.2 | **HIGH**: fewer overlapping zones |
| 12 | Detection | **ATR-adaptive proximity**: max(fixed_pips, ATR×mult) M15/M30=0.4, H1+=0.6 | **HIGH**: volatility-aware spacing |
| 13 | Detection | **Zone replacement**: new zone with 1.5× reaction replaces weak nearby zone | **MEDIUM**: better zone selection |
| 14 | Detection | **H1 ATR width cap**: 0.7 → 0.55 (thinner zones) | **MEDIUM**: cleaner chart |
| 15 | Main | **H1 preset optimized**: swing=5, dist=40, reaction=20, decay=15/3, score=80 | **HIGH**: premium-only H1 zones |

#### Imbalance Candle Bonus (P36)

| # | File | Feature | Impact |
|---|------|---------|--------|
| 16 | Defines | SReactionPoint: +has_imbalance | **LOW**: data structure |
| 17 | Detection | **Imbalance detection** in CreateRP: body>=70% + vol>1.5×MA20 at zone_bar±1 | **HIGH**: institutional urgency |
| 18 | Scoring | CalcBaseScore: +8 pts for has_imbalance | **MEDIUM**: better zone differentiation |

#### ATR Smoothing (spike-resistant scoring)

| # | File | Feature | Impact |
|---|------|---------|--------|
| 19 | Utils | **g_cached_atr14_smooth**: EMA(period=10) of ATR14, updated per bar | **HIGH**: stable scoring baseline |
| 20 | Scoring | CalcBaseScore reaction strength uses smoothed ATR | **HIGH**: no spike-induced score swing |
| 21 | Scoring | CalcZonePrecisionScore width_ratio uses smoothed ATR | **HIGH**: consistent zone quality grading |

#### Score Cap & Level Thresholds

| # | File | Feature | Impact |
|---|------|---------|--------|
| 22 | Defines | **SCORE_CAP**: 150 → 200 — more headroom for differentiation | **HIGH**: confluence zones no longer cluster at cap |
| 23 | Utils | **ClassifyRPLevel**: Premium >=120 (was 110), LV1 >=85 (was 80) | **MEDIUM**: proportional threshold adjustment |

#### Breaker Block Detection (P37)

| # | File | Feature | Impact |
|---|------|---------|--------|
| 24 | Defines | SReactionPoint: +is_breaker_block | **LOW**: data structure |
| 25 | Detection | **HandleBreakout**: OB + body>=0.8×ATR → breaker candidate, keep active | **HIGH**: institutional reversal signal |
| 26 | Detection | **CheckRoleReversalRetest**: breaker flag preserved on role reversal confirm | **MEDIUM**: flow integration |
| 27 | Scoring | CalcFinalScore: +10 bonus for confirmed breaker block (on top of +15 role reversal) | **HIGH**: +25 total reversal score |

---

## THỨ TỰ THỰC THI

```
PHASE 1: P1 → P2
PHASE 2: P3, P4, P5, P6, P7 (song song) → compile test P1-P7
PHASE 3: P8 → P9A → P10 → compile test P1-P10
PHASE 4: P11, P12, P13
PHASE 5: P14, P15, P16 → compile test P1-P16
PHASE 6: P17
PHASE 7: P18+P19 → P20 → P21 → P22 → P23 → P24 → P25 → P26 → P27 → P28
PHASE 8: P29 → P30 → P32 → P33 → P34(FVG) → P35(Mitigation) → P36(Imbalance) → P37(Breaker)
```

---

### Convention reminder (paste đầu mỗi prompt nếu cần)
- MQL5: KHÔNG `extern`, dùng `g_` globals (set bởi Main)
- KHÔNG `TimeDayOfWeek()` → MqlDateTime
- Opacity: `BlendColor(fg, bg, alpha_pct)`
- Anti-repainting: chỉ bar[1]+, KHÔNG BAO GIỜ bar[0]
