# REACTION POINT INDICATOR v3.0 — IMPLEMENTATION PROMPTS
## Chuẩn hóa từ RP_FINAL_SPEC.md | 17 files | 7 phases

**Tổng:** 1 main `.mq5` + 16 `.mqh` includes
**Mỗi prompt = 1 session riêng. Paste prompt, không cần đọc lại spec.**

### MQL5 Convention Notes (áp dụng cho TẤT CẢ prompts)

1. **KHÔNG dùng `extern`** — MQL5 chỉ có `input`/`sinput`. Tất cả `input` khai báo trong `RP_Main.mq5`. Các `.mqh` modules đọc biến `g_` globals (được set bởi Main trong `ApplyTFPreset()`).
2. **KHÔNG dùng `TimeDayOfWeek()`** — Deprecated. Dùng: `MqlDateTime dt; TimeToStruct(time, dt); int dow = dt.day_of_week;`
3. **Opacity/Alpha** — MQL5 OBJ_RECTANGLE không hỗ trợ alpha channel. Dùng `ColorToARGB(color, alpha_0_255)` với `OBJPROP_COLOR` cho text/label. Cho rectangle zones, dùng color blending thủ công: `BlendColor(fg, bg, alpha_pct)` = mix RGB channels. Hoặc chấp nhận dùng `OBJPROP_FILL` on/off + màu nhạt thay opacity.
4. **Include guard** — Mỗi `.mqh` dùng `#ifndef` / `#define` / `#endif`. Globals chỉ khai báo 1 lần trong `RP_Utils.mqh`, các module khác include `RP_Utils.mqh` qua guard nên không bị duplicate.
5. **Thêm `#property strict`** vào `RP_Main.mq5`.

### Dependency Graph

```
Phase 1: P1 → P2                    (Foundation)
Phase 2: P3, P4, P5, P6, P7         (Independent — có thể song song)
Phase 3: P8 → P9A → P10             (Core Logic + Market Structure)
Phase 4: P11, P12, P13              (Advanced — cần Phase 2+3)
Phase 5: P14, P15, P16              (UI — cần Phase 4)
Phase 6: P17                        (Main — tổng hợp tất cả)
```

---
---

## PHASE 1: FOUNDATION

---

## PROMPT 1: RP_Defines.mqh (Enums, Constants, Structs)

```
Tạo file MQL5/Include/ReactionPoint/RP_Defines.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DEFINES_MQH / #define / #endif

=== ENUMS ===

enum ENUM_RP_TYPE        { RP_SUPPORT, RP_RESISTANCE };
enum ENUM_RP_LEVEL       { RP_PREMIUM, RP_LEVEL1, RP_LEVEL2, RP_LEVEL3, RP_HIDDEN };
enum ENUM_MARKET_REGIME  { REGIME_STRONG_TREND, REGIME_WEAK_TREND, REGIME_RANGING, REGIME_CHOPPY };
enum ENUM_TREND_DIR      { TREND_UP, TREND_DOWN, TREND_NONE };
enum ENUM_SESSION        { SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON,
                           SESSION_NY_OPEN, SESSION_NY, SESSION_OVERLAP, SESSION_DEAD };
enum ENUM_CANDLE_PATTERN { PATTERN_NONE, PATTERN_PINBAR, PATTERN_ENGULFING,
                           PATTERN_OUTSIDE_BAR, PATTERN_LARGE_WICK };
enum ENUM_TF_PRESET      { PRESET_AUTO, PRESET_M30, PRESET_H1, PRESET_H4, PRESET_D1, PRESET_CUSTOM };
enum ENUM_DASH_CORNER    { DASH_TOP_LEFT, DASH_TOP_RIGHT, DASH_BOTTOM_LEFT, DASH_BOTTOM_RIGHT };
enum ENUM_STRUCTURE_STATE { STRUCTURE_BULLISH, STRUCTURE_BEARISH, STRUCTURE_NONE };

=== CONSTANTS ===

#define MAX_RP_COUNT       200
#define MAX_CHART_OBJECTS   250
#define MAX_CONFLUENCE      50
#define MAX_SETUPS          10
#define MAX_FLASH_RP        3
#define MAX_HTF_RETRIES     3
#define OBJECT_PREFIX       "RP_"
#define SCORE_CAP           150.0

=== STRUCTS ===

struct SReactionPoint {
   int              id;
   ENUM_RP_TYPE     rp_type;
   ENUM_RP_LEVEL    rp_level;
   ENUM_TIMEFRAMES  source_tf;
   ENUM_SESSION     session_formed;
   ENUM_CANDLE_PATTERN candle_pattern;
   double           price, zone_high, zone_low;
   datetime         time_formed, time_last_tested;
   int              bar_formed, bar_last_tested;
   double           base_score, final_score, initial_reaction_pips;
   int              test_count;
   bool             is_role_reversed, is_active, is_confluence, is_fresh;
   int              confluence_id;       // -1 nếu không thuộc confluence
   bool             alert_sent[4];       // 4 cấp alert
   datetime         alert_reset_time;
   bool             is_flashing;
   int              flash_count;
   double           display_opacity;
   int              day_of_week_formed;  // 0=Sun, 1=Mon...5=Fri
   bool             has_liquidity_sweep; // true nếu RP hình thành sau liquidity sweep
};

#define MAX_ZONE_RPS 8  // Max RP per confluence zone (tránh dynamic array)

struct SConfluenceZone {
   int              id;
   double           zone_high, zone_low, center_price;
   int              rp_count;
   int              rp_ids[MAX_ZONE_RPS]; // FIXED array — tránh ArrayResize runtime
   ENUM_RP_TYPE     zone_type;           // Majority vote (đếm SUPPORT vs RESISTANCE)
   double           multiplier, bonus, final_score;
   string           tf_description;      // "H1+H4+D1"
   bool             is_premium;          // true khi 4+ RP
};

struct SEntrySetup {
   int              rp_id;
   ENUM_RP_TYPE     direction;
   double           entry_price, sl_price, tp1_price, tp2_price;
   double           rr_ratio1, rr_ratio2;
   double           sl_pips, tp1_pips, tp2_pips;
   int              bar_created;
   datetime         time_created;
   bool             is_active, is_invalidated, is_triggered;
};

struct SRPStats {
   int    total_formed, total_reacted, total_broken;
   int    premium_formed, premium_reacted;
   int    level1_formed, level1_reacted;
   int    level2_formed, level2_reacted;
   int    london_formed, london_reacted;
   int    ny_formed, ny_reacted;
   int    asian_formed, asian_reacted;
   datetime tracking_start;
   void Init() { ZeroMemory(this); tracking_start = TimeCurrent(); }
};

Mỗi struct thêm method Init() để zero-initialize tất cả fields.
SReactionPoint.Init() phải set confluence_id = -1.
```

---

## PROMPT 2: RP_Utils.mqh (Globals & Utilities)

```
Tạo file MQL5/Include/ReactionPoint/RP_Utils.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_UTILS_MQH / #define / #endif
Include: "RP_Defines.mqh"

=== GLOBAL VARIABLES (tất cả module dùng chung) ===

// RP Data
SReactionPoint g_rp_array[];
int            g_rp_count = 0;
int            g_next_rp_id = 0;

// Confluence Data
SConfluenceZone g_confluence_array[];
int             g_confluence_count = 0;
int             g_next_confluence_id = 0;

// Entry Setup Data
SEntrySetup    g_setup_array[];
int            g_setup_count = 0;

// Stats
SRPStats       g_stats;

// Market State
ENUM_MARKET_REGIME g_current_regime = REGIME_RANGING;
ENUM_TREND_DIR     g_current_trend  = TREND_NONE;
double             g_current_adx    = 0;
ENUM_SESSION       g_current_session = SESSION_DEAD;

// Market Structure (Module H)
ENUM_STRUCTURE_STATE g_current_structure = STRUCTURE_NONE;
bool                 g_choch_detected    = false;
int                  g_last_bos_bar      = 0;
int                  g_last_choch_bar    = 0;

// Filters
bool           g_news_blackout     = false;
bool           g_news_available    = true;
string         g_news_status_text  = "clear";
color          g_news_status_color = clrLime;
bool           g_spread_blocked    = false;
bool           g_spread_warning    = false;
double         g_current_spread_pips = 0;
double         g_average_spread_pips = 0;

// Display
int            g_object_count = 0;

// Indicator Handles
int            g_handle_adx = INVALID_HANDLE;
int            g_handle_atr = INVALID_HANDLE;

// Globals cho input values (set bởi ApplyTFPreset trong Main)
int    g_swing_lookback, g_min_rp_distance_pips, g_min_reaction_move_pips;
int    g_initial_bars_to_scan, g_breakout_confirm_pips, g_max_retest_bars;
int    g_decay_interval_bars, g_decay_points_per_interval, g_max_rp_age_bars;
int    g_sl_buffer_pips, g_entry_buffer_pips, g_max_setup_age_bars;
int    g_confluence_merge_pips, g_htf_bars_to_scan;
int    g_fibo_lookback_bars, g_fibo_tolerance_pips, g_min_candle_size_pips;
int    g_zone_width_pips, g_min_score_to_show;
int    g_proximity_alert_pips, g_reset_alert_pips;
ENUM_TIMEFRAMES g_htf_1, g_htf_2;
double g_reaction_atr_multiplier;
bool   g_use_adaptive_reaction;

=== ANTI-REPAINTING MACRO ===

#define RP_SHIFT_MIN 1
// Macro bảo vệ: dùng thay iClose/iHigh/iLow trực tiếp
// Nếu shift < 1 → Print warning + return 0 (debug mode)
double RP_Close(int shift) { if(shift < RP_SHIFT_MIN) { Print("WARNING: bar[0] access blocked"); return 0; } return iClose(_Symbol, PERIOD_CURRENT, shift); }
double RP_High(int shift)  { if(shift < RP_SHIFT_MIN) { Print("WARNING: bar[0] access blocked"); return 0; } return iHigh(_Symbol, PERIOD_CURRENT, shift); }
double RP_Low(int shift)   { if(shift < RP_SHIFT_MIN) { Print("WARNING: bar[0] access blocked"); return 0; } return iLow(_Symbol, PERIOD_CURRENT, shift); }
// TẤT CẢ modules phải dùng RP_Close/RP_High/RP_Low thay vì gọi iClose/iHigh/iLow trực tiếp.

=== CACHED VALUES (update 1 lần/bar trong OnCalculate, trước khi gọi modules) ===

// Tránh CopyBuffer 200+ lần/bar. Tính 1 lần, cache cho toàn bộ bar.
double g_cached_atr14 = 0;          // ATR(14) bar[1], update mỗi bar
double g_cached_atr14_ma50 = 0;     // SMA(ATR14, 50), update mỗi bar
double g_cached_volume_ma20 = 0;    // SMA(tick_volume, 20), update mỗi bar
int    g_cached_bar_index = -1;     // Bar index lần cuối cache, detect stale

// Fibo cache — tính 1 lần/bar
double g_cached_fibo_high = 0;      // Swing High trong fibo_lookback
double g_cached_fibo_low = 0;       // Swing Low trong fibo_lookback
double g_cached_fibo_618 = 0;       // 61.8% level
double g_cached_fibo_500 = 0;       // 50.0% level
double g_cached_fibo_382 = 0;       // 38.2% level

// Dirty flags cho scoring optimization
bool   g_rp_dirty[];                // ArrayResize(MAX_RP_COUNT) trong OnInit
int    g_last_calc_bar[];           // Bar index lần cuối recalc per RP

// HTF cache — chỉ update khi có bar mới trên HTF
bool   g_htf1_cache_valid = false;
bool   g_htf2_cache_valid = false;
int    g_htf1_cached_swing_count = 0;
int    g_htf2_cached_swing_count = 0;

// Confluence update flag — set bởi HandlePartialBreakout()
bool   g_confluence_needs_update = false;

// Alert throttle
double g_last_alert_check_price = 0; // Cache giá lần cuối check alert

void UpdateBarCache():
  // GỌI ĐẦU TIÊN trong OnCalculate khi IsNewBar()
  int current_bar = Bars(_Symbol, PERIOD_CURRENT);
  if(current_bar == g_cached_bar_index) return; // Đã cache bar này
  g_cached_bar_index = current_bar;

  // ATR14
  g_cached_atr14 = CalcATR(14, 1);  // 1 CopyBuffer call thay vì 200+
  if(g_cached_atr14 <= 0 || g_cached_atr14 != g_cached_atr14) g_cached_atr14 = PipsToPrice(10);

  // ATR MA50 — rolling buffer
  static double atr_buffer[50]; static int atr_idx = 0; static int atr_fill = 0;
  atr_buffer[atr_idx % 50] = g_cached_atr14; atr_idx++; atr_fill = MathMin(atr_fill+1, 50);
  double sum = 0; for(int i=0; i<atr_fill; i++) sum += atr_buffer[i];
  g_cached_atr14_ma50 = sum / atr_fill;

  // Volume MA20 — rolling buffer
  static double vol_buffer[20]; static int vol_idx = 0; static int vol_fill = 0;
  // MQL5: iVolume() tồn tại nhưng chậm hơn array parameter từ OnCalculate
  // Nếu có tick_volume[] từ OnCalculate → dùng tick_volume[1]
  // Fallback: iVolume(_Symbol, PERIOD_CURRENT, 1)
  vol_buffer[vol_idx % 20] = (double)iVolume(_Symbol, PERIOD_CURRENT, 1);
  vol_idx++; vol_fill = MathMin(vol_fill+1, 20);
  sum = 0; for(int i=0; i<vol_fill; i++) sum += vol_buffer[i];
  g_cached_volume_ma20 = sum / vol_fill;

  // Fibo levels
  UpdateFiboCache();

=== UTILITY FUNCTIONS ===

1. PipValue(): double
   - Tự detect pip value cho mọi pair
   - 5-digit broker: Point()*10 cho major pairs
   - JPY pairs: Point()*100 (hoặc detect từ Digits())
   - Digits()==3 hoặc 5 → PipValue = Point()*10
   - Digits()==2 hoặc 4 → PipValue = Point()
   - GUARD: if(pip_val <= 0) pip_val = Point() > 0 ? Point() : 0.0001;
   - KHÔNG BAO GIỜ return 0

2. PipsToPrice(int pips): double
   - return pips * PipValue()

3. PriceToPips(double price_diff): double
   - double pv = PipValue();
   - if(pv <= 0) return 0;  // Guard division by zero
   - return price_diff / pv

4. SafeATR(int period, int shift=0): double
   - NẾU period==14 && shift<=1 → return g_cached_atr14 (dùng cache, KHÔNG gọi CopyBuffer)
   - Else: double atr = CalcATR(period, shift)
   - return (atr > 0 && atr == atr) ? atr : PipsToPrice(10)
   - Guard NaN và zero

5. GetATR14(int shift=0): double
   - if(shift <= 1) return g_cached_atr14;  // Fast path — cache hit
   - Else: return SafeATR(14, shift)

6. CalcATR(int period, int shift): double
   - if(g_handle_atr == INVALID_HANDLE) return 0;  // Guard null handle
   - Dùng g_handle_atr, CopyBuffer
   - Guard CopyBuffer return value: if(copied <= 0) return 0;

6b. UpdateFiboCache(): void
   - Tìm Swing High/Low trong g_fibo_lookback_bars (1 lần/bar)
   - Tính 3 Fibo levels: 61.8%, 50%, 38.2%
   - Lưu vào g_cached_fibo_high/low/618/500/382
   - Modules khác đọc cache thay vì scan lại 100 bars

7. IsNewBar(): bool
   - Static datetime last_time
   - So sánh iTime(_Symbol, PERIOD_CURRENT, 0) với last_time

8. TFToString(ENUM_TIMEFRAMES tf): string
   - PERIOD_M30→"M30", PERIOD_H1→"H1", PERIOD_H4→"H4", v.v.

9. SessionToString(ENUM_SESSION s): string
   - SESSION_OVERLAP→"London-NY Overlap", v.v.

10. RegimeToString(ENUM_MARKET_REGIME r): string
    - REGIME_STRONG_TREND→"STRONG TREND", v.v.

11. DashCornerToAnchor(ENUM_DASH_CORNER c): ENUM_ANCHOR_POINT

12. GetSpreadColor(double current, double average): color
    - current > average * 3.0 → clrRed
    - current > average * 2.0 → clrYellow
    - else → clrWhite

13. ClassifyRPLevel(double score): ENUM_RP_LEVEL
    - >=110 → RP_PREMIUM
    - 80-109 → RP_LEVEL1
    - 60-79 → RP_LEVEL2
    - 40-59 → RP_LEVEL3
    - <40 → RP_HIDDEN

14. InitIndicatorHandles(): bool
    - g_handle_adx = iADX(_Symbol, PERIOD_CURRENT, g_adx_period)
    - g_handle_atr = iATR(_Symbol, PERIOD_CURRENT, 14)
    - Check INVALID_HANDLE → Print error, return false
    - return true nếu cả 2 handle valid

15. ReleaseIndicatorHandles():
    - if(g_handle_adx != INVALID_HANDLE) IndicatorRelease(g_handle_adx); g_handle_adx = INVALID_HANDLE;
    - if(g_handle_atr != INVALID_HANDLE) IndicatorRelease(g_handle_atr); g_handle_atr = INVALID_HANDLE;

15b. RevalidateHandles(): bool
    - Gọi mỗi 100 bars (static counter)
    - Nếu handle == INVALID_HANDLE → thử re-create
    - Return false nếu không recover được → Print warning
    - Dùng trong OnCalculate: if(!RevalidateHandles()) { /* skip modules cần ADX/ATR */ }

16. BlendColor(color fg, color bg, int alpha_pct): color
    - Simulate transparency cho OBJ_RECTANGLE (MQL5 không hỗ trợ native alpha)
    - alpha_pct: 0=fully transparent (=bg), 100=fully opaque (=fg)
    - int r = (ColorGetRed(fg)*alpha_pct + ColorGetRed(bg)*(100-alpha_pct)) / 100;
    - Tương tự cho g, b
    - return (color)((b<<16) | (g<<8) | r);

17. GetChartBackground(): color
    - return (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

Lưu ý: File này KHÔNG chứa logic nghiệp vụ, chỉ globals + helpers.
```

---
---

## PHASE 2: INDEPENDENT MODULES (có thể song song, chỉ cần P1+P2)

---

## PROMPT 3: RP_RegimeFilter.mqh (Module A — Market Regime)

```
Tạo file MQL5/Include/ReactionPoint/RP_RegimeFilter.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_REGIMEFILTER_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input int    ADX_Period;
  input double ADX_Strong_Threshold;
  input double ADX_Weak_Threshold;
  input bool   Use_Regime_Filter;
  → Main copy vào g_ globals trong ApplyTFPreset(). Module này đọc globals.

GLOBALS TỪ RP_Utils.mqh:
  - g_current_regime, g_current_trend, g_current_adx
  - g_handle_adx
  - SafeATR(), GetATR14()

THÊM GLOBALS vào RP_Utils.mqh (để module đọc):
  int    g_adx_period = 14;
  double g_adx_strong_threshold = 25.0;
  double g_adx_weak_threshold = 20.0;
  bool   g_use_regime_filter = true;

=== LOGIC ===

1. UpdateMarketRegime():
   - Đọc ADX value từ g_handle_adx (CopyBuffer)
   - g_current_adx = adx_value
   - Phân loại:
     ADX > g_adx_strong_threshold (25) → REGIME_STRONG_TREND
     ADX >= g_adx_weak_threshold (20) AND <= Strong → REGIME_WEAK_TREND
     ADX < g_adx_weak_threshold:
       ATR(14) < ATR_MA50 * 0.7 → REGIME_CHOPPY
       Else → REGIME_RANGING
   - ATR_MA50: trung bình ATR(14) của 50 bars gần nhất

   Detect trend direction (cho STRONG/WEAK):
   - So sánh HH/HL trên bars gần nhất (hoặc dùng +DI/-DI từ ADX)
   - +DI > -DI → TREND_UP
   - -DI > +DI → TREND_DOWN
   - Else → TREND_NONE

2. GetRegimeScoreAdj(ENUM_RP_TYPE rp_type): double
   - Nếu g_use_regime_filter == false → return 0
   - Mapping chiều:
     Uptrend + SUPPORT = cùng chiều
     Uptrend + RESISTANCE = ngược chiều
     Downtrend + SUPPORT = ngược chiều
     Downtrend + RESISTANCE = cùng chiều

   Bảng score adjustment:
   | Regime       | Cùng chiều | Ngược chiều |
   |--------------|-----------|-------------|
   | STRONG_TREND | +20       | -30         |
   | WEAK_TREND   | +10       | -15         |
   | RANGING      | +15       | +15         |
   | CHOPPY       | -20       | -20         |

3. IsChoppyMarket(): bool
   - return g_current_regime == REGIME_CHOPPY

Hành vi khi CHOPPY:
- Ẩn entry setup (không tạo mới)
- Không alert cấp 1-2
- RP display_opacity giảm 50%
- Dashboard: "CHOPPY — Avoid trading"
- NGOẠI LỆ: Premium Confluence (score >=110) VẪN alert + hiển thị bình thường
```

---

## PROMPT 4: RP_Session.mqh (Module E — Session & Day-of-Week)

```
Tạo file MQL5/Include/ReactionPoint/RP_Session.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_SESSION_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input int  UTC_Offset;
  input bool Show_Session_Background;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  int  g_utc_offset = 3;
  bool g_show_session_background = true;

GLOBALS: g_current_session, SessionToString()

=== SESSION DEFINITIONS (UTC) ===

| Session       | Start | End   |
|---------------|-------|-------|
| Asian         | 00:00 | 07:00 |
| London Open   | 07:00 | 08:30 |
| London        | 07:00 | 16:00 |
| NY Open       | 13:00 | 14:30 |
| NY            | 13:00 | 22:00 |
| Overlap       | 13:00 | 16:00 |
| Dead Zone     | 22:00 | 00:00 |

Ưu tiên (khi overlap): Overlap > London Open > NY Open > London > NY > Asian > Dead

=== FUNCTIONS ===

1. UpdateCurrentSession():
   - MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   - utc_hour = (dt.hour - g_utc_offset + 24) % 24; utc_min = dt.min;
   - Detect session theo bảng trên, ưu tiên từ cao xuống thấp
   - g_current_session = detected session

2. GetSessionScoreAdj(ENUM_SESSION session): double
   | Overlap     | +15 |
   | London Open | +10 |
   | NY Open     | +10 |
   | London      | +5  |
   | NY          | +5  |
   | Asian       | -10 |
   | Dead Zone   | -20 |

3. GetDayOfWeekAdj(): double
   - MqlDateTime dt; TimeToStruct(TimeCurrent(), dt); int dow = dt.day_of_week;
   - Monday (1): -5
   - Tue-Wed (2-3): 0
   - Thursday (4): +5
   - Friday (5):
     UTC hour < 15 → 0
     UTC hour >= 15 → -10

4. GetSessionForTime(datetime time): ENUM_SESSION
   - Detect session tại thời điểm bất kỳ (cho tracking stats)

5. DrawSessionBackgrounds(int visible_bars):
   - Vẽ OBJ_RECTANGLE cho mỗi session trên chart
   - Colors (8-10% opacity):
     Asian = LightCyan
     London = Lavender
     NY = LemonChiffon
     Overlap = MistyRose
     Dead = Gainsboro
   - Chỉ vẽ nếu Show_Session_Background == true
   - Name prefix: OBJECT_PREFIX + "SESS_"
```

---

## PROMPT 5: RP_DynamicDecay.mqh (Module B — Score Decay)

```
Tạo file MQL5/Include/ReactionPoint/RP_DynamicDecay.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DYNAMICDECAY_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input int  Decay_Interval_Bars;
  input int  Decay_Points_Per_Interval;
  input int  Max_RP_Age_Bars;
  input bool Use_Dynamic_Score;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool g_use_dynamic_score = true;

GLOBALS: g_rp_array[], g_rp_count, g_decay_interval_bars, g_decay_points_per_interval, g_max_rp_age_bars, g_use_dynamic_score

=== FUNCTIONS ===

1. CalcDecayPenalty(int rp_index): double
   - Nếu g_use_dynamic_score == false → return 0
   - bars_since = current_bar - rp.bar_formed (hoặc dùng bar_last_tested nếu có test)
   - bars_since_last_event = bars kể từ lần cuối (formed hoặc tested)
   - penalty = (bars_since_last_event / g_decay_interval_bars) * g_decay_points_per_interval
   - Nếu bars_since > g_max_rp_age_bars → penalty += 10
   - Nếu bars_since > 2 * g_max_rp_age_bars AND score < 80 → set rp.is_active = false (ẩn RP)
   - return penalty

2. CalcRecentBonus(int rp_index): double
   - CHỈ dùng closed bars [1..N], KHÔNG BAO GIỜ bar[0]
   - Phản ứng xác nhận trong bars[1..5] → return +15
     (phản ứng = nến touch zone + close theo hướng phản ứng + move >= min_move)
   - Test không phá trong bars[1..10] → return +8
     (test = giá chạm zone nhưng close không vượt breakout threshold)
   - Else → return 0

3. UpdateAllDecay():
   - Loop tất cả active RP
   - Tính decay cho mỗi RP
   - Cập nhật display_opacity tuyến tính theo tuổi, floor 30%:
     opacity = max(30, initial_opacity - (bars_since / max_age) * (initial_opacity - 30))

Lưu ý: decay_penalty và recent_bonus được dùng trong CalcFinalScore (RP_Scoring.mqh),
KHÔNG apply trực tiếp vào final_score tại đây.
```

---

## PROMPT 6: RP_NewsFilter.mqh (Module F — News Filter)

```
Tạo file MQL5/Include/ReactionPoint/RP_NewsFilter.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_NEWSFILTER_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool Use_News_Filter;
  input int  News_Blackout_Minutes;
  input bool News_Filter_High_Only;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool g_use_news_filter = true;
  int  g_news_blackout_minutes = 30;
  bool g_news_filter_high_only = false;

GLOBALS: g_news_blackout, g_news_available, g_news_status_text, g_news_status_color

=== PERFORMANCE NOTE ===
- UpdateNewsFilter() KHÔNG gọi mỗi bar
- Main OnCalculate throttle: gọi mỗi 5 phút (300 giây)
- Kết quả cache trong globals, valid cho 5 phút
- Nếu Calendar API fail → exponential backoff retry: 5min → 15min → 30min

=== LOGIC ===

1. UpdateNewsFilter():
   - Nếu g_use_news_filter == false → g_news_blackout = false; return
   - Dùng MQL5 Calendar API (MT5 build 2085+):

   Extract currencies từ _Symbol:
     string base_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);   // "GBP"
     string quote_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT); // "USD"

   Scan cho mỗi currency riêng:
     MqlCalendarValue values[];
     datetime from_time = TimeCurrent() - g_news_blackout_minutes*60;
     datetime to_time   = TimeCurrent() + g_news_blackout_minutes*60;

     // Lấy country code từ currency (helper function)
     // Dùng CalendarValueHistory(values, from_time, to_time, country_code, currency)
     // HOẶC dùng CalendarValueHistoryByEvent cho event cụ thể

     Cách đơn giản hơn (recommended):
       MqlCalendarEvent events[];
       MqlCalendarValue values[];
       int total = CalendarValueHistory(values, from_time, to_time);
       // Sau đó filter: CalendarEventById(values[i].event_id, event)
       // Check event.currency == base_currency || event.currency == quote_currency

   - Lọc theo impact (từ MqlCalendarEvent.importance):
     CALENDAR_IMPORTANCE_HIGH → luôn blackout
     CALENDAR_IMPORTANCE_MODERATE → blackout nếu g_news_filter_high_only == false
     CALENDAR_IMPORTANCE_LOW → bỏ qua

   LƯU Ý: MQL5 Calendar dùng CALENDAR_IMPORTANCE_HIGH/MODERATE/LOW (không phải IMPACT)

   - Nếu có tin trong window:
     g_news_blackout = true
     Tính thời gian còn lại/đã qua (dùng values[i].time - TimeCurrent()):
       Trước tin: g_news_status_text = "NFP in 12min", g_news_status_color = clrRed
       Sau tin: g_news_status_text = "CPI 8min ago", g_news_status_color = clrYellow
     LƯU Ý: Calendar time đã là server time, cần convert nếu UTC_Offset khác server timezone.
       Dùng TimeGMT() thay TimeCurrent() nếu muốn UTC-based, hoặc tính offset:
       datetime adjusted = values[i].time + (TimeGMT() - TimeCurrent());
   - Nếu không có tin:
     g_news_blackout = false
     g_news_status_text = "clear"
     g_news_status_color = clrLime

2. Hành vi khi g_news_blackout == true:
   - KHÔNG trigger alert cấp 1-2
   - KHÔNG kích hoạt entry setup
   - RP zones vẫn hiển thị, thêm label "PAUSED"
   - Score tạm -15 cho tất cả RP (chỉ hiển thị, KHÔNG lưu vĩnh viễn)

3. Hành vi 30 phút SAU tin:
   - Rescan tất cả active RP (breakout check)
   - Resume alerts

4. Medium Impact (khi News_Filter_High_Only == false):
   - Chỉ warning dashboard
   - Score -10 tạm thời
   - KHÔNG block entry

5. Fallback khi Calendar API fail:
   - g_news_available = false
   - Dashboard: "NEWS: unavailable"
   - Bỏ qua filter hoàn toàn
   - Exponential backoff retry:
     static int fail_count = 0;
     static datetime next_retry = 0;
     if(TimeCurrent() < next_retry) return;  // Chưa đến lúc retry
     fail_count++;
     int wait_seconds = MathMin(300 * (int)MathPow(2, fail_count-1), 1800); // 5min → 10min → 20min → cap 30min
     next_retry = TimeCurrent() + wait_seconds;
     // Reset fail_count = 0 khi API success lại

6. GetNewsTempScoreAdj(): double
   - Blackout (High) → return -15
   - Warning (Medium) → return -10
   - Clear → return 0
```

---

## PROMPT 7: RP_SpreadFilter.mqh (Module G — Spread Filter)

```
Tạo file MQL5/Include/ReactionPoint/RP_SpreadFilter.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_SPREADFILTER_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool   Use_Spread_Filter;
  input double Spread_Alert_Multiplier;
  input double Spread_Block_Multiplier;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool   g_use_spread_filter = true;
  double g_spread_alert_multiplier = 2.0;
  double g_spread_block_multiplier = 3.0;

GLOBALS: g_spread_blocked, g_spread_warning, g_current_spread_pips, g_average_spread_pips
         PipValue()

=== FUNCTIONS ===

1. GetCurrentSpreadPips(): double
   - return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / PipValue()

2. GetAverageSpread(): double
   - Rolling buffer 100 ticks:
     static double spread_buffer[100]
     static int spread_idx = 0
     static int spread_count = 0
   - Mỗi tick: spread_buffer[spread_idx % 100] = current_spread; spread_idx++; spread_count = min(spread_count+1, 100)
   - return sum / spread_count

3. UpdateSpreadFilter():
   - Nếu g_use_spread_filter == false → g_spread_blocked = false; g_spread_warning = false; return
   - g_current_spread_pips = GetCurrentSpreadPips()
   - Update rolling buffer → g_average_spread_pips = GetAverageSpread()

   - if cur > avg * g_spread_block_multiplier (3.0):
       g_spread_blocked = true; g_spread_warning = false
       // Block entry, block alert cấp 2
   - elif cur > avg * g_spread_alert_multiplier (2.0):
       g_spread_blocked = false; g_spread_warning = true
       // Score -10 tạm thời, entry vẫn hoạt động với warning
   - else:
       g_spread_blocked = false; g_spread_warning = false

Dashboard hiển thị: Normal=clrWhite, Warning=clrYellow, Blocked=clrRed
(Dùng GetSpreadColor() từ RP_Utils.mqh)
```

---
---

## PHASE 3: CORE LOGIC + MARKET STRUCTURE (P8 → P9A → P10, tuần tự)

---

## PROMPT 8: RP_Detection.mqh (Swing Detection, Candle, Momentum, Breakout)

```
Tạo file MQL5/Include/ReactionPoint/RP_Detection.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DETECTION_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  Tất cả input values đã được Main copy vào g_ globals trong ApplyTFPreset().
  Module này chỉ đọc globals.

GLOBALS: g_rp_array[], g_rp_count, g_next_rp_id
         g_swing_lookback, g_min_rp_distance_pips, g_min_reaction_move_pips
         g_initial_bars_to_scan, g_breakout_confirm_pips, g_max_retest_bars
         g_min_candle_size_pips, g_use_adaptive_reaction, g_reaction_atr_multiplier
         g_zone_width_pips, g_current_session
         PipsToPrice(), PriceToPips(), SafeATR()

=== 8.1 SWING DETECTION ===

1. DetectSwingPoints(int bars_to_scan):
   - Scan từ bar[N+1] đến bar[bars_to_scan] (N = g_swing_lookback)
   - KHÔNG BAO GIỜ bar[0] (anti-repainting)
   - Chỉ confirm trên closed bars: i >= g_swing_lookback + 1

   Swing High bar[i]: high[i] > high[i-N..i-1] AND high[i] > high[i+1..i+N]
   (high[i] lớn hơn N bars bên trái VÀ N bars bên phải)

   Swing Low bar[i]: low[i] < low[i-N..i-1] AND low[i] < low[i+1..i+N]

   - Khoảng cách tối thiểu: 2 RP không được cách nhau < g_min_rp_distance_pips
   - Khi tìm thấy swing → check Candle Pattern → check Momentum → tạo RP

   Safety: if Bars(_Symbol, PERIOD_CURRENT) < g_swing_lookback*2+5 → Print warning, return

2. CreateRP(ENUM_RP_TYPE type, int bar_index, double price, ENUM_CANDLE_PATTERN pattern, double reaction_pips):
   - Tạo SReactionPoint mới
   - id = g_next_rp_id++
   - zone_high = price + PipsToPrice(g_zone_width_pips/2)
   - zone_low = price - PipsToPrice(g_zone_width_pips/2)
   - source_tf = Period()
   - session_formed = g_current_session
   - MqlDateTime dt; TimeToStruct(iTime(_Symbol, PERIOD_CURRENT, bar_index), dt);
     day_of_week_formed = dt.day_of_week
   - candle_pattern = pattern
   - initial_reaction_pips = reaction_pips
   - is_active = true, is_fresh = true, test_count = 0
   - confluence_id = -1
   - display_opacity = opacity theo level (PREMIUM=80, L1=70, L2=50, L3=35)
   - Array overflow: nếu g_rp_count >= MAX_RP_COUNT → evict:
     1st: inactive RP (scan → tìm first inactive)
     2nd: lowest score non-confluence RP
     3rd: oldest RP
     BOUNDS GUARD: nếu không tìm được candidate (all active + confluence) → Print error, return
     Eviction: overwrite slot → g_rp_dirty[evict_idx] = true

=== 8.2 CANDLE PATTERN ===

3. DetectCandlePattern(int bar_index): ENUM_CANDLE_PATTERN
   - Check theo thứ tự, dừng khi match đầu tiên.
   - range = high[i] - low[i]
   - body = |open[i] - close[i]|
   - upper_wick = high[i] - max(open[i], close[i])
   - lower_wick = min(open[i], close[i]) - low[i]

   a) Size filter: range < PipsToPrice(g_min_candle_size_pips) → PATTERN_NONE, dừng
   b) Doji: body < range * 0.10 → PATTERN_NONE, dừng
   c) Pinbar: 1 wick >= 60% range AND body <= 25% range AND body ở 1/3 đối diện → PATTERN_PINBAR
   d) Engulfing: body[i] bao trùm body[i+1] AND khác hướng AND body[i] >= 1.5 * body[i+1] → PATTERN_ENGULFING
   e) Outside Bar: high[i]>high[i+1] AND low[i]<low[i+1] AND không phải Engulfing → PATTERN_OUTSIDE_BAR
   f) Large Wick: 1 wick >= 40% range AND close ngược hướng wick → PATTERN_LARGE_WICK
   g) Else → PATTERN_NONE

4. GetCandlePatternScore(ENUM_CANDLE_PATTERN pattern): double
   - PINBAR=20, ENGULFING=15, OUTSIDE_BAR=12, LARGE_WICK=10, NONE=0

=== 8.3 MOMENTUM CONFIRMATION ===

5. CheckMomentum(int swing_bar, ENUM_RP_TYPE type): bool + double& reaction_pips
   - Nếu g_use_adaptive_reaction:
       min_move = SafeATR(14) * g_reaction_atr_multiplier
     Ngược lại:
       min_move = PipsToPrice(g_min_reaction_move_pips)

   - Sau khi swing hình thành, scan closed bars phía sau (bars nhỏ hơn swing_bar)
   - Tìm max move ngược hướng swing:
     SUPPORT: tìm giá tăng lên cao nhất sau swing low
     RESISTANCE: tìm giá giảm xuống thấp nhất sau swing high
   - Nếu max_move >= min_move → return true, reaction_pips = PriceToPips(max_move)
   - Else → return false (KHÔNG tạo RP)

=== 8.4 BREAKOUT & ROLE REVERSAL ===

6. CheckBreakoutsAndRetests():
   - Loop tất cả active RP
   - Dùng RP_Close(1) (closed bar, anti-repainting enforced by macro)

   Breakout check:
   - SUPPORT: RP_Close(1) < rp.zone_low - PipsToPrice(g_breakout_confirm_pips)
   - RESISTANCE: RP_Close(1) > rp.zone_high + PipsToPrice(g_breakout_confirm_pips)
   - Nếu breakout → bắt đầu tracking retest

   Gap qua RP (close vượt RP mà không touch zone):
   - Tính breakout (gap = breakout mạnh)
   - KHÔNG tính "test", KHÔNG trigger proximity alert

   Retest check (sau breakout):
   - Nếu giá quay lại zone trong g_max_retest_bars → Role Reversal:
     a) Flip type: SUPPORT ↔ RESISTANCE
     b) +15 điểm vào final_score (role_rev_bonus)
     c) is_role_reversed = true
     d) Đổi màu → Color_RoleReversal
     e) Nếu RP trong confluence → tách khỏi zone, re-check confluence
     f) Alert cấp 3

   Test count:
   - Mỗi lần giá chạm zone nhưng không breakout → test_count++
   - is_fresh = false sau lần test đầu tiên
   - g_rp_dirty[rp_index] = true  // Trigger re-score khi breakout/test/role reversal

Lưu ý quan trọng:
- Anti-repainting: dùng RP_Close(1)/RP_High(1)/RP_Low(1) — macro chặn bar[0]
- Dirty flag: mọi state change phải set g_rp_dirty[i] = true
```

---

## PROMPT 9A: RP_MarketStructure.mqh (Module H — BOS, CHoCH, Liquidity Sweep)

```
Tạo file MQL5/Include/ReactionPoint/RP_MarketStructure.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_MARKETSTRUCTURE_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool Use_Market_Structure;
  input int  Structure_Lookback_Bars;   // default 50
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool g_use_market_structure = true;
  int  g_structure_lookback_bars = 50;

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - g_current_structure, g_choch_detected, g_last_bos_bar, g_last_choch_bar
  - PipsToPrice(), PriceToPips()

LƯU Ý: ENUM_STRUCTURE_STATE và has_liquidity_sweep field ĐÃ ĐƯỢC khai báo
trong P1 (RP_Defines.mqh). KHÔNG cần thêm lại ở đây.

=== CONCEPT (chỉ dùng price action, không thêm indicator) ===

Break of Structure (BOS):
  Bullish BOS = giá phá High trước đó (HH mới) → trend UP tiếp tục
  Bearish BOS = giá phá Low trước đó (LL mới) → trend DOWN tiếp tục

Change of Character (CHoCH):
  Trong uptrend (HH+HL): giá phá HL gần nhất → CHoCH bearish
  Trong downtrend (LL+LH): giá phá LH gần nhất → CHoCH bullish
  = Tín hiệu ĐẦU TIÊN rằng trend có thể đảo chiều

Liquidity Sweep:
  Giá vượt qua swing high/low (quét stop loss) rồi ĐÓNG CỬA quay lại
  = Trap signal, xác suất reversal rất cao

=== FUNCTIONS ===

1. UpdateMarketStructure():
   - Gọi mỗi nến mới (IsNewBar)
   - Scan closed bars [1..g_structure_lookback_bars]
   - Xây dựng chuỗi swing points: HH, HL, LH, LL

   Xác định structure:
   a) Tìm 4 swing points gần nhất (2 high + 2 low)
   b) Bullish: swing_high[0] > swing_high[1] AND swing_low[0] > swing_low[1]
      → g_current_structure = STRUCTURE_BULLISH
   c) Bearish: swing_high[0] < swing_high[1] AND swing_low[0] < swing_low[1]
      → g_current_structure = STRUCTURE_BEARISH
   d) Else → STRUCTURE_NONE

   BOS detection (trên bar[1], anti-repainting):
   - Bullish BOS: close[1] > last_swing_high → g_last_bos_bar = 1
   - Bearish BOS: close[1] < last_swing_low → g_last_bos_bar = 1

   CHoCH detection:
   - Trong BULLISH: close[1] < last_higher_low → CHoCH bearish
     g_choch_detected = true, g_last_choch_bar = 1
   - Trong BEARISH: close[1] > last_lower_high → CHoCH bullish
     g_choch_detected = true, g_last_choch_bar = 1
   - Reset g_choch_detected = false sau 10 bars (hết hiệu lực)

2. CheckLiquiditySweep(int bar_index): bool
   - Điều kiện (tất cả phải true):
     a) Bar[i] high > previous swing high (hoặc low < previous swing low)
     b) Bar[i] ĐÓNG CỬA quay lại bên trong (close < swing high hoặc close > swing low)
     c) Wick phía sweep >= 40% range bar (có rejection rõ)
   - Nếu true → đánh dấu RP gần nhất: rp.has_liquidity_sweep = true
   - Return true/false

3. GetStructureScoreAdj(int rp_index): double
   - Nếu g_use_market_structure == false → return 0

   | Tình huống | Adj | Lý do |
   |-----------|-----|-------|
   | RP SUPPORT + STRUCTURE_BULLISH (cùng chiều BOS) | +15 | Buy tại support trong uptrend = high probability |
   | RP RESISTANCE + STRUCTURE_BEARISH (cùng chiều BOS) | +15 | Sell tại resistance trong downtrend |
   | RP ngược chiều BOS (chưa có CHoCH) | -20 | Counter-trend nguy hiểm |
   | RP ngược chiều BOS + CHoCH vừa xảy ra (<10 bars) | +10 | Reversal play hợp lệ |
   | STRUCTURE_NONE | 0 | Không đủ data |

4. GetLiquiditySweepBonus(int rp_index): double
   - rp.has_liquidity_sweep == true → return +20
   - Else → return 0
   - Đây là bonus mạnh nhất vì sweep + RP = institutional trap

Lưu ý:
- Tất cả logic chỉ dùng HIGH/LOW/CLOSE, không thêm indicator nào
- Anti-repainting: chỉ dùng bar[1] trở về trước
- CHoCH tự reset sau 10 bars để không ảnh hưởng dài hạn
- Logic đơn giản: chỉ cần 4 swing points + 2 comparisons
```

---

## PROMPT 10: RP_Scoring.mqh (Base Score + Final Score)

```
Tạo file MQL5/Include/ReactionPoint/RP_Scoring.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_SCORING_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS: Không có. Dùng g_fibo_lookback_bars, g_fibo_tolerance_pips từ globals.

GLOBALS: g_rp_array[], g_rp_count, SafeATR(), PriceToPips(), PipsToPrice()
         g_fibo_lookback_bars, g_fibo_tolerance_pips
         ClassifyRPLevel(), SCORE_CAP

FILE NÀY GỌI FUNCTIONS TỪ CÁC MODULE KHÁC (đã include trước nó trong Main):

  Từ RP_RegimeFilter.mqh:
    double GetRegimeScoreAdj(ENUM_RP_TYPE rp_type);
      // Return [-30, +20]. Điều chỉnh score theo regime + direction alignment.

  Từ RP_DynamicDecay.mqh:
    double CalcDecayPenalty(int rp_index);
      // Return [0, +35+]. Penalty tăng theo tuổi RP. Trừ vào score.
    double CalcRecentBonus(int rp_index);
      // Return [0, +15]. Bonus nếu RP vừa phản ứng gần đây.

  Từ RP_Session.mqh:
    double GetSessionScoreAdj(ENUM_SESSION session);
      // Return [-20, +15]. Điều chỉnh theo session formed.
    double GetDayOfWeekAdj();
      // Return [-10, +5]. Điều chỉnh theo ngày trong tuần.

  Từ RP_MarketStructure.mqh:
    double GetStructureScoreAdj(int rp_index);
      // Return [-20, +15]. Điều chỉnh theo BOS/CHoCH alignment.
    double GetLiquiditySweepBonus(int rp_index);
      // Return 0 hoặc +20. Bonus nếu RP có liquidity sweep.

  LƯU Ý: MQL5 không cần forward declaration nếu include order đúng trong Main.
  Thứ tự include trong Main phải đảm bảo các module trên được include TRƯỚC RP_Scoring.mqh.

=== 10.1 BASE SCORE (0-100) ===

PERFORMANCE NOTE: CalcBaseScore chỉ được gọi khi g_rp_dirty[rp_index] == true.
Dùng cached values (g_cached_atr14, g_cached_fibo_*, g_cached_volume_ma20) thay vì tính lại.

1. CalcBaseScore(int rp_index): double
   Tính tổng 6 thành phần:

   a) Reaction Strength (max 25):
      // Dùng g_cached_atr14 — KHÔNG gọi SafeATR() lại
      double atr_pips = PriceToPips(g_cached_atr14);
      if(atr_pips < 0.1) atr_pips = 10;  // Guard div by zero
      score = MathMin((rp.initial_reaction_pips / atr_pips) * 25.0, 25.0)

   b) Test Count (max 20):
      1 test → 5
      2 tests → 12
      3 tests → 20
      >3 tests → MathMax(20 - (n-3)*5, 5)  // Diminishing returns, floor 5

   c) Candle Pattern (max 20):
      // Pattern đã lưu trong rp.candle_pattern lúc detect — KHÔNG gọi DetectCandlePattern lại
      PINBAR=20, ENGULFING=15, OUTSIDE_BAR=12, LARGE_WICK=10, NONE=0

   d) Fibonacci Alignment (max 15):
      // DÙG CACHE: g_cached_fibo_618, g_cached_fibo_500, g_cached_fibo_382
      // KHÔNG scan lại g_fibo_lookback_bars mỗi RP
      double tolerance = PipsToPrice(g_fibo_tolerance_pips);
      if(MathAbs(rp.price - g_cached_fibo_618) <= tolerance) → 15
      elif(MathAbs(rp.price - g_cached_fibo_500) <= tolerance) → 10
      elif(MathAbs(rp.price - g_cached_fibo_382) <= tolerance) → 7
      else → 0

   e) Volume (max 10):
      // DÙNG CACHE: g_cached_volume_ma20
      // Chỉ cần 1 lookup iVolume tại swing_bar (đã lưu trong RP)
      double vol = (double)iVolume(_Symbol, PERIOD_CURRENT, rp.bar_formed);
      if(vol > g_cached_volume_ma20 * 1.5) → 10
      elif(vol > g_cached_volume_ma20 * 1.2) → 5
      else → 0

   f) Round Number (max 10):
      Distance từ RP.price đến nearest x.x000 hoặc x.x500:
      <= 10 pips → 10
      <= 20 pips → 5
      else → 0

   BONUS: Volume Delta:
   - Tại SUPPORT: close>open (buying) volume > close<open (selling) volume * 1.3 → +5
   - Ngược lại (buying < selling tại support) → -5
   - Tại RESISTANCE: ngược lại

   return MathMin(tổng, 100.0)  // Cap tại 100

=== 10.2 FINAL SCORE ===

2. CalcFinalScore(int rp_index):
   - Tính base_score nếu chưa có
   - rp.base_score = CalcBaseScore(rp_index)

   double adjusted = rp.base_score
      + GetRegimeScoreAdj(rp.rp_type)      // Module A: [-30, +20]
      - CalcDecayPenalty(rp_index)           // Module B: [0, -35+]
      + CalcRecentBonus(rp_index)            // Module B: [0, +15]
      + GetSessionScoreAdj(rp.session_formed) // Module E: [-20, +15]
      + GetDayOfWeekAdj()                    // [-10, +5]
      + GetStructureScoreAdj(rp_index)       // Module H: [-20, +15]
      + GetLiquiditySweepBonus(rp_index)     // Module H: [0, +20]
      + (rp.is_role_reversed ? 15.0 : 0.0)  // Role reversal bonus
      + (rp.is_fresh ? 10.0 : 0.0);         // First touch bonus

   adjusted = MathMax(adjusted, 0.0);

   // Confluence (sẽ được apply từ RP_Confluence.mqh)
   // Nếu rp.is_confluence == true → multiplier + bonus từ confluence zone
   // Ở đây chỉ tính adjusted, confluence apply SAU

   rp.final_score = MathMin(adjusted, SCORE_CAP);

   // Phân loại level
   rp.rp_level = ClassifyRPLevel(rp.final_score);

Lưu ý: First Touch bonus: test_count == 0 AND is_fresh == true → +10, tag "FRESH"
```

---
---

## PHASE 4: ADVANCED MODULES (P11, P12, P13 — cần Phase 2+3)

---

## PROMPT 11: RP_Confluence.mqh (Module D — Multi-TF Confluence)

```
Tạo file MQL5/Include/ReactionPoint/RP_Confluence.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_CONFLUENCE_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool Use_Confluence_Zones;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool g_use_confluence_zones = true;

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - g_confluence_array[], g_confluence_count, g_next_confluence_id
  - g_htf_bars_to_scan, g_confluence_merge_pips
  - g_htf_1, g_htf_2 (ENUM_TIMEFRAMES)
  - PipsToPrice(), PriceToPips(), PipValue()

STRUCTS (RP_Defines.mqh):
  SReactionPoint — fields: is_confluence, confluence_id, final_score, ...
  SConfluenceZone — fields: rp_ids[MAX_ZONE_RPS] (FIXED array), rp_count, multiplier, bonus, ...
    THAY ĐỔI: rp_ids[] FIXED size = 8. KHÔNG dùng dynamic array.
    #define MAX_ZONE_RPS 8  // Max RP per confluence zone

CONSTANTS: MAX_CONFLUENCE=50, MAX_HTF_RETRIES=3, SCORE_CAP=150.0

=== PERFORMANCE NOTES ===
- CollectHTFReactionPoints: CHỈ gọi khi IsNewBarHTF() = true (từ OnCalculate)
- MergeClusterZones: Sort-based O(N log N) thay vì brute-force O(N²)
- HTF data: dùng CopyHigh/CopyLow batch thay vì iHigh/iLow per-bar

=== LOGIC ===

1. CollectHTFReactionPoints():
   - CHỈ gọi khi g_htf1_cache_valid == false hoặc IsNewBarHTF() (từ Main)
   - Scan g_htf_1 và g_htf_2 cho swing points (giống DetectSwingPoints nhưng trên HTF)

   HIỆU NĂNG — dùng batch copy thay vì iHigh/iLow per-bar:
     double htf_high[], htf_low[], htf_close[];
     CopyHigh(_Symbol, g_htf_1, 0, g_htf_bars_to_scan, htf_high);   // 1 call = N bars
     CopyLow(_Symbol, g_htf_1, 0, g_htf_bars_to_scan, htf_low);     // 1 call = N bars
     CopyClose(_Symbol, g_htf_1, 0, g_htf_bars_to_scan, htf_close); // 1 call = N bars
     // Tổng: 6 CopyBuffer calls (2 TF × 3) thay vì 400+ iHigh/iLow calls

   - Retry tối đa MAX_HTF_RETRIES nếu CopyHigh return <= 0
   - Fallback: chỉ dùng current TF nếu HTF data fail
   - Kết quả cache trong static arrays; valid cho đến khi IsNewBarHTF() = true

2. MergeClusterZones():
   - Reset confluence arrays (g_confluence_count = 0)
   - Gộp tất cả active RP (current TF + HTF)

   HIỆU NĂNG — sort-based clustering thay vì O(N²) pair comparison:
     a) Sort RPs by price ascending (O(N log N))
     b) Linear scan: nếu rp[i+1].price - rp[i].price <= PipsToPrice(g_confluence_merge_pips)
        → add to current zone
     c) Close zone khi gap > merge_pips → start new zone
     // Tổng: O(N log N) thay vì O(N²)

   - Zone = range bao trùm tất cả RP trong group (min zone_low, max zone_high)
   - zone_type = majority vote (đếm RP_SUPPORT vs RP_RESISTANCE)
   - final_score = highest score trong group
   - tf_description = "H1+H4+D1" (nối tên các TF có RP trong group)

   Multiplier & Bonus theo số RP:
   | RP count | Multiplier | Bonus | Premium? |
   |----------|-----------|-------|----------|
   | 2        | 1.3       | 10    | false    |
   | 3        | 1.5       | 25    | false    |
   | 4+       | 1.8       | 40    | true     |

   Cập nhật mỗi RP trong group:
   - rp.is_confluence = true
   - rp.confluence_id = zone.id
   - g_rp_dirty[rp_index] = true  // Trigger re-score

   Bounds: zone.rp_count capped at MAX_ZONE_RPS (8). Nếu >8 RP → chỉ giữ 8 score cao nhất.

3. ApplyConfluenceScoring():
   - Cho mỗi confluence zone, apply lên RP có highest score trong zone:
   - adjusted = rp.final_score * zone.multiplier + zone.bonus
   - rp.final_score = MathMax(0, MathMin(adjusted, SCORE_CAP))  // Clamp cả 2 phía
   - Re-classify RP level: rp.rp_level = ClassifyRPLevel(rp.final_score)

4. HandlePartialBreakout(int rp_id):
   - Khi 1 RP trong zone bị breakout → tách khỏi zone
   - g_confluence_needs_update = true  // Trigger recalc trong Main OnCalculate
   - rp.is_confluence = false, rp.confluence_id = -1
   - Giảm zone.rp_count

   Remove rp_id từ zone.rp_ids[] — BOUNDS-SAFE:
     bool found = false;
     for(int j = 0; j < zone.rp_count; j++) {
        if(zone.rp_ids[j] == rp_id) {
           // Shift remaining left
           for(int k = j; k < zone.rp_count - 1; k++)
              zone.rp_ids[k] = zone.rp_ids[k+1];
           zone.rp_count--;
           found = true;
           break;
        }
     }
     if(!found) Print("WARNING: rp_id ", rp_id, " not found in zone");

   - Recalc multiplier/bonus:
     3→2: multiplier 1.5→1.3, bonus 25→10
     2→1: giải tán zone hoàn toàn
       - RP còn lại: is_confluence = false, confluence_id = -1
       - Remove zone từ g_confluence_array
   - g_rp_dirty[affected_rp_indices] = true  // Trigger re-score

Lưu ý:
- rp_ids[] là FIXED array[8], KHÔNG dùng ArrayResize runtime
- Confluence chỉ update khi OnCalculate detect need_confluence_update == true
```

---

## PROMPT 12: RP_EntrySetup.mqh (Module C — Entry Setup)

```
Tạo file MQL5/Include/ReactionPoint/RP_EntrySetup.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_ENTRYSETUP_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool   Show_Entry_Setup;
  input double Min_RR_Ratio;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool   g_show_entry_setup = true;
  double g_min_rr_ratio = 1.5;

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - g_setup_array[], g_setup_count
  - g_current_regime, g_news_blackout, g_spread_blocked
  - g_sl_buffer_pips, g_entry_buffer_pips, g_max_setup_age_bars, g_min_score_to_show
  - g_min_rr_ratio
  - PipsToPrice(), PriceToPips(), GetATR14()
  - MAX_SETUPS=10

STRUCTS (RP_Defines.mqh):
  SEntrySetup { rp_id, direction, entry_price, sl_price, tp1_price, tp2_price,
                rr_ratio1, rr_ratio2, sl_pips, tp1_pips, tp2_pips,
                bar_created, time_created, is_active, is_invalidated, is_triggered }
  ENUM_MARKET_REGIME: REGIME_CHOPPY

=== FUNCTIONS ===

1. CheckEntryConditions():
   - Loop tất cả active RP có score >= g_min_score_to_show
   - Trigger conditions (TẤT CẢ phải true):
     a) Giá hiện tại (bar[1] close) trong zone (zone_low..zone_high)
     b) Bar[1] có candle pattern hợp lệ (gọi DetectCandlePattern(1))
     c) g_current_regime != REGIME_CHOPPY
        NGOẠI LỆ: Premium Confluence (score >=110) → bỏ qua check này
     d) g_spread_blocked == false
     e) g_news_blackout == false
   - Nếu tất cả pass → gọi CreateEntrySetup()

2. CreateEntrySetup(int rp_index):
   - BUY (RP_SUPPORT):
     entry = RP_High(1) + PipsToPrice(g_entry_buffer_pips)
     sl = RP_Low(1) - PipsToPrice(g_sl_buffer_pips)
   - SELL (RP_RESISTANCE):
     entry = RP_Low(1) - PipsToPrice(g_entry_buffer_pips)
     sl = RP_High(1) + PipsToPrice(g_sl_buffer_pips)

   - TP1 = FindNearestRPInDirection(entry, direction, 0)
     Nếu TP1 == 0 hoặc R:R < g_min_rr_ratio → fallback: entry ± g_cached_atr14*2
   - TP2 = FindNearestRPInDirection(entry, direction, 1)
     Nếu TP2 == 0 → fallback: entry ± g_cached_atr14*4

   - sl_pips = PriceToPips(MathAbs(entry - sl))
   - tp1_pips = PriceToPips(MathAbs(tp1 - entry))
   - tp2_pips = PriceToPips(MathAbs(tp2 - entry))

   GUARD DIVISION BY ZERO:
   - if(sl_pips < 0.1) sl_pips = 0.1;  // Minimum 0.1 pip SL
   - rr_ratio1 = tp1_pips / sl_pips
   - rr_ratio2 = tp2_pips / sl_pips

   - Max đồng thời: MAX_SETUPS. Khi đầy → thay setup có score thấp nhất
   - 2 setup cùng hướng → tag "PREFERRED" cho score cao hơn
   - 2 setup ngược hướng → warning "Conflicting setups"

3. UpdateSetups():
   - ĐÃ TÁCH: per-tick phần nhẹ (SL invalidation) vào UpdateSetupInvalidation() trong Main
   - Phần nặng (age check, entry trigger) → gọi per-bar only:
     a) Quá g_max_setup_age_bars bars kể từ bar_created → is_active = false
     b) Entry triggered (RP_Close(1) chạm entry_price) → is_triggered = true

4. FindNearestRPInDirection(double from_price, ENUM_RP_TYPE direction, int skip_count): double
   - Tìm RP active gần nhất theo hướng trade
   - BUY: tìm RP_RESISTANCE phía trên from_price
   - SELL: tìm RP_SUPPORT phía dưới from_price
   - skip_count: 0=gần nhất, 1=thứ 2
   - Return price hoặc 0 nếu không tìm thấy

   HIỆU NĂNG: Nếu g_rp_count > 30, dùng sorted price cache:
   - Maintain static g_rp_sorted_by_price[] (update mỗi bar khi RP thay đổi)
   - Binary search thay vì linear: O(log N) thay vì O(N)

Anti-repainting: dùng RP_Close(1), RP_High(1), RP_Low(1) — KHÔNG BAO GIỜ shift=0
```

---

## PROMPT 13: RP_Stats.mqh (Performance Tracker)

```
Tạo file MQL5/Include/ReactionPoint/RP_Stats.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_STATS_MQH / #define / #endif
Include: "RP_Utils.mqh"

GLOBALS TỪ RP_Utils.mqh:
  - g_stats (SRPStats)
  - g_rp_array[], g_rp_count
  - g_current_session

STRUCT SRPStats {
  total_formed, total_reacted, total_broken,
  premium_formed, premium_reacted,
  level1_formed, level1_reacted,
  level2_formed, level2_reacted,
  london_formed, london_reacted,
  ny_formed, ny_reacted,
  asian_formed, asian_reacted,
  tracking_start
}

=== FUNCTIONS ===

1. InitStats():
   - g_stats.Init()  // ZeroMemory + tracking_start = TimeCurrent()

2. OnRPFormed(int rp_index):
   - g_stats.total_formed++
   - Theo level: premium/level1/level2_formed++
   - Theo session formed: london/ny/asian_formed++

3. OnRPReacted(int rp_index):
   - Khi giá phản ứng >= min_move tại RP (bounce, không phá)
   - g_stats.total_reacted++
   - Theo level + session tương tự

4. OnRPBroken(int rp_index):
   - Khi RP bị breakout confirmed
   - g_stats.total_broken++

5. UpdateStats():
   - Gọi mỗi nến mới
   - Scan tất cả active RP
   - Check bar[1] (closed bar only):
     Phản ứng = bar touch zone + close theo hướng phản ứng + move >= min_move
     Phá = close vượt zone >= breakout_confirm_pips
   - Gọi OnRPReacted hoặc OnRPBroken tương ứng

6. GetHitRate(): double
   - denom = total_reacted + total_broken
   - return (denom > 0) ? (double)total_reacted / denom : 0.0

7. GetLevelHitRate(ENUM_RP_LEVEL level): double
   - Tương tự, theo level

8. GetBestSession(): string
   - So sánh hit rate London vs NY vs Asian
   - Return tên session + hit rate (e.g., "London Open 74%")

9. GetWorstSession(): string
   - Ngược lại

10. FormatStatsString(): string
   - Format cho dashboard:
   "PERFORMANCE (since [date])
     Hit Rate: 67% (42/63)
     Premium: 78% (7/9) | Lv1: 64% (18/28)
     Best: London Open 74% | Worst: Asian 41%"

KHÔNG lưu file. Reset khi indicator reload. Chỉ track bars đã chạy.
```

---
---

## PHASE 5: UI (P14, P15, P16 — cần Phase 4)

---

## PROMPT 14: RP_Drawing.mqh (Zones, Labels, Session BG, Entry Panel)

```
Tạo file MQL5/Include/ReactionPoint/RP_Drawing.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DRAWING_MQH / #define / #endif
Include: "RP_Defines.mqh"
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input color Color_Premium, Color_Level1, Color_Level2, Color_Level3;
  input color Color_Confluence, Color_RoleReversal;
  input color Color_EntryBuy, Color_EntrySell;
  input int   Label_Font_Size;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  color g_color_premium = clrGold, g_color_level1 = clrCrimson;
  color g_color_level2 = clrOrange, g_color_level3 = clrSkyBlue;
  color g_color_confluence = clrMediumPurple, g_color_role_reversal = clrMagenta;
  color g_color_entry_buy = clrLimeGreen, g_color_entry_sell = clrRed;
  int   g_label_font_size = 8;

GLOBALS: g_rp_array[], g_rp_count, g_confluence_array[], g_confluence_count
         g_setup_array[], g_setup_count, g_object_count
CONSTANTS: OBJECT_PREFIX="RP_", MAX_CHART_OBJECTS=250

=== COLOR SYSTEM (Spec Section 17.1) ===

MQL5 OBJ_RECTANGLE không hỗ trợ alpha trực tiếp.
Giải pháp: Dùng helper BlendColor() để mix foreground color với chart background.

color BlendColor(color fg, color bg, int alpha_pct):
  // alpha_pct: 0=transparent (bg), 100=opaque (fg)
  int r = (ColorGetRed(fg)*alpha_pct + ColorGetRed(bg)*(100-alpha_pct)) / 100;
  int g = (ColorGetGreen(fg)*alpha_pct + ColorGetGreen(bg)*(100-alpha_pct)) / 100;
  int b = (ColorGetBlue(fg)*alpha_pct + ColorGetBlue(bg)*(100-alpha_pct)) / 100;
  return (color)((b<<16) | (g<<8) | r);

Lấy chart background: ChartGetInteger(0, CHART_COLOR_BACKGROUND)

Alpha theo level (truyền vào BlendColor):
  PREMIUM=80%, L1=70%, L2=50%, L3=35%
  Confluence=50%, RoleRev=60%
  Entry BUY/SELL=25%
  SL=clrFireBrick 30%, TP1=clrKhaki 20%, TP2=clrDarkKhaki 20%

Cho OBJ_LABEL text: dùng ColorToARGB(color, alpha_0_255) với OBJPROP_COLOR.

Decay visual: alpha_pct giảm tuyến tính theo tuổi, floor 30%

=== FUNCTIONS ===

1. GetRPColor(int rp_index): color
   - is_role_reversed → Color_RoleReversal
   - is_confluence → Color_Confluence
   - Theo level: PREMIUM→Color_Premium, L1→Color_Level1, L2→Color_Level2, L3→Color_Level3

2. DrawRPZone(int rp_index):
   - OBJ_RECTANGLE, FILL=true, BACK=true, SELECTABLE=false
   - Từ time_formed đến TimeCurrent() + PeriodSeconds()*20
   - Border: STYLE_SOLID (Premium+L1), STYLE_DOT (L2+L3)
   - Opacity từ rp.display_opacity
   - Name: OBJECT_PREFIX + "ZONE_" + IntegerToString(rp.id)

3. DrawConfluenceGlow(int conf_index):
   - Chỉ cho confluence có 3+ RP
   - 3 rectangle chồng, dùng BlendColor() để simulate glow:
     color bg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
     Outer: zone ± 2pip, color = BlendColor(g_color_confluence, bg, 14)
     Middle: zone ± 1pip, color = BlendColor(g_color_confluence, bg, 30)
     Core: zone gốc, color = BlendColor(g_color_confluence, bg, 50)
   - OBJPROP_FILL = true cho cả 3
   - Name prefix: OBJECT_PREFIX + "GLOW_"

4. DrawRPLabel(int rp_index):
   - OBJ_LABEL hoặc OBJ_TEXT, 2 dòng:

   Dòng 1: [icon] [score] [progress_bar] [TYPE]
   Dòng 2: [TF] | Tested:[n]x | [session] | [status]

   Icons: Premium="⭐", L1="🔴", L2="🟠", L3="🔵"
   Progress bar: score/150 * 12 chars (dùng ký tự block █ và ░)
   TYPE: SUPPORT / RESISTANCE / CONFLUENCE
   Status: Fresh / Decay:-N / RoleRev

   - Resistance: label TRÊN zone. Support: label DƯỚI zone
   - Chống chồng: offset 20px nếu 2 label cùng price ± 30 pips
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

6. DrawSLTPLines(int setup_index):
   - SL: clrFireBrick, STYLE_DASH
   - TP1: clrKhaki, STYLE_DOT
   - TP2: clrDarkKhaki, STYLE_DOT
   - Entry: Color_EntryBuy/Sell, STYLE_SOLID

7. CreateSessionObjects():
   - GỌI 1 LẦN trong OnInit. Tạo OBJ_RECTANGLE cho mỗi session visible.
   - KHÔNG tạo lại mỗi bar. Chỉ update time range.
   - Colors — dùng BlendColor(session_color, bg, 10):
     Asian = BlendColor(clrLightCyan, bg, 10)
     London = BlendColor(clrLavender, bg, 10)
     NY = BlendColor(clrLemonChiffon, bg, 10)
     Overlap = BlendColor(clrMistyRose, bg, 10)
     Dead = BlendColor(clrGainsboro, bg, 10)
   - Name prefix: OBJECT_PREFIX + "SESS_"

7b. UpdateSessionVisibility():
   - GỌI MỖI BAR (nhẹ — chỉ update OBJPROP_TIME properties)
   - Di chuyển rectangle time range theo visible bars
   - KHÔNG xóa/tạo mới objects

8. RedrawChangedRP():
   - Chỉ vẽ lại RP có STATE thay đổi so với lần draw trước
   - Track per RP: previous_score, previous_type, previous_active, previous_confluence
   - Redraw nếu BẤT KỲ field nào thay đổi (score, rp_type, is_active, is_confluence, is_role_reversed, display_opacity)
   - Static array: double prev_scores[]; ENUM_RP_TYPE prev_types[]; bool prev_active[]; bool prev_conf[];
   - So sánh current vs previous, chỉ gọi DrawRPZone + DrawRPLabel cho RP đã thay đổi

9. DeleteRPObjects(int rp_id):
   - Xóa tất cả objects của 1 RP: zone + label + glow

10. DeleteAllObjects():
    - ObjectsDeleteAll(0, OBJECT_PREFIX)
    - g_object_count = 0

11. EnforceObjectLimit():
    - Nếu g_object_count > MAX_CHART_OBJECTS → xóa objects của RP có score thấp nhất

12. UpdateFontSizes():
    - Detect CHART_SCALE → adjust font ±2, min font 6
```

---

## PROMPT 15: RP_Alerts.mqh (Alert System — 4 Levels)

```
Tạo file MQL5/Include/ReactionPoint/RP_Alerts.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_ALERTS_MQH / #define / #endif
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool Alert_Only_Active_Sessions;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool g_alert_only_active_sessions = true;

GLOBALS: g_rp_array[], g_rp_count, g_current_session, g_news_blackout, g_spread_blocked
         g_proximity_alert_pips, g_reset_alert_pips, g_alert_only_active_sessions

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

=== FILTERS ===

- Session: nếu g_alert_only_active_sessions && session==DEAD → skip
- News blackout → KHÔNG trigger cấp 1-2
- Spread blocked → KHÔNG trigger cấp 2
- NGOẠI LỆ: Premium Confluence (score >=110) LUÔN alert kể cả Choppy/News

=== FUNCTIONS ===

PERFORMANCE NOTE:
  - CheckAllAlerts() CHỈ gọi khi giá di chuyển >= 2 pips (throttled bởi Main)
  - Cấp 2-4 CHỈ check per-bar (dùng bar[1] closed)
  - Cấp 1 (proximity) là duy nhất cần check per-"tick" (nhưng đã throttled)
  - Early exit: skip RP nếu tất cả alert_sent[] == true

=== FUNCTIONS ===

1. CheckAllAlerts():
   - Gọi từ OnCalculate KHI giá di chuyển >= 2 pips (Main throttle)
   - Loop tất cả active RP

   EARLY EXIT per RP:
     if(rp.alert_sent[0] && rp.alert_sent[1] && rp.alert_sent[2] && rp.alert_sent[3])
        continue;  // Tất cả alerts đã gửi, skip

   - Cho mỗi RP, check 4 cấp alert theo thứ tự ưu tiên (4→3→2→1)
   - Apply filters ở trên

2. CheckProximityAlert(int rp_index): bool
   - distance = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - rp.price)
   - Nếu PriceToPips(distance) <= g_proximity_alert_pips:
     Check hướng: so sánh RP_Close(1) vs RP_Close(2) → đang tiến về RP?
     SUPPORT: price đang giảm về RP (close[1] < close[2])
     RESISTANCE: price đang tăng về RP (close[1] > close[2])
   - Return true nếu cần alert VÀ alert_sent[0] == false

3. CheckReactionAlert(int rp_index): bool
   - Bar[1] đã đóng (RP_Close(1)), close nằm trong zone, có pattern hợp lệ
   - Dùng rp.candle_pattern đã cache — KHÔNG gọi DetectCandlePattern lại
   - VÀ alert_sent[1] == false

4. CheckRoleReversalAlert(int rp_index): bool
   - rp.is_role_reversed == true VÀ alert_sent[2] == false

5. CheckPremiumAlert(int rp_index): bool
   - rp.final_score >= 110 VÀ rp.is_confluence VÀ alert_sent[3] == false

6. SendRPAlert(int level, string message):
   - Alert(message)
   - SendNotification(message)  // Push notification
   - Print("RP_ALERT[" + IntegerToString(level) + "]: " + message)
   - Set alert_sent[level-1] = true cho RP tương ứng

   HIỆU NĂNG: Pre-build message string chỉ khi alert thực sự fire.
   KHÔNG concatenate string trong check phase — chỉ trong send phase.

7. ResetAlertIfDistant(int rp_index):
   - CHỈ gọi bên trong CheckAllAlerts() per-RP — KHÔNG loop riêng
   - Khi PriceToPips(distance) >= g_reset_alert_pips:
     Reset alert_sent[0..3] = false
   - Cho phép alert lại khi giá quay lại

Anti-spam: alert_sent[4] per RP. Mỗi zone chỉ 1 alert mỗi lần tiếp cận.
Alert throttle: Main chỉ gọi CheckAllAlerts khi giá di chuyển >= 2 pips.
```

---

## PROMPT 16: RP_Dashboard.mqh (Dashboard UI)

```
Tạo file MQL5/Include/ReactionPoint/RP_Dashboard.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DASHBOARD_MQH / #define / #endif
Include: "RP_Defines.mqh"
Include: "RP_Utils.mqh"

INPUTS (khai báo trong RP_Main.mq5, KHÔNG khai báo ở đây):
  input bool             Show_Dashboard;
  input bool             Show_Performance_Stats;
  input ENUM_DASH_CORNER Dashboard_Corner;
  input int              Dashboard_Font_Size;
  input bool             Show_HTF_1, Show_HTF_2;
  → Main copy vào g_ globals. Module này đọc globals.

THÊM GLOBALS vào RP_Utils.mqh:
  bool             g_show_dashboard = true;
  bool             g_show_performance_stats = true;
  ENUM_DASH_CORNER g_dashboard_corner = DASH_TOP_LEFT;
  int              g_dashboard_font_size = 9;
  bool             g_show_htf_1 = true, g_show_htf_2 = true;

GLOBALS DÙNG:
  - g_rp_array[], g_rp_count, g_confluence_count
  - g_current_regime, g_current_trend, g_current_adx
  - g_current_session, g_current_spread_pips, g_average_spread_pips
  - g_news_status_text, g_news_status_color
  - g_spread_blocked, g_spread_warning
  - g_setup_array[], g_setup_count
  - g_object_count, g_stats
  - DashCornerToAnchor(), TFToString(), SessionToString(), RegimeToString()
  - GetSpreadColor()
  - GetHitRate(), FormatStatsString() — extern từ RP_Stats.mqh

COLORS: Nền C'20,25,32' 90% opacity, border C'60,65,75'
        Text: White/DarkGray/Lime/Tomato

=== DASHBOARD LAYOUT (Spec Section 17.5) ===

╔══════════════════════════════════════════════════╗
║  REACTION POINT v3.0           Preset: H4        ║
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
║  Zones:8  Conf:2  RevR:1  Setups:1  Obj:142/250 ║
║  HTF: D1 W1  │  Hit Rate: 67% (42/63)            ║
╠══════════════════════════════════════════════════╣
║  SELL@1.2752  SL:18p  TP1:43p  R:R=1:2.4         ║
╚══════════════════════════════════════════════════╝

LƯU Ý: Dòng status PHẢI có RevR (Role Reversal count) — đếm số RP có is_role_reversed==true

=== FUNCTIONS ===

1. CreateDashboard():
   - Tạo background: OBJ_RECTANGLE_LABEL, nền C'20,25,32'
   - Tạo tất cả text labels: OBJ_LABEL
   - Đặt tại Dashboard_Corner (dùng DashCornerToAnchor)
   - Name prefix: OBJECT_PREFIX + "DASH_"

2. UpdateDashboard():
   - Gọi mỗi nến mới
   - Cập nhật tất cả text values
   - Sections ẩn/hiện theo context:
     Entry Setup line: chỉ khi có active setup
     NEWS: đổi text + color theo g_news_status_text / g_news_status_color
       "clear" (green) / "NFP in 12min" (red) / "unavailable" (gray)
     Spread: đổi màu theo GetSpreadColor()
     CHOPPY → regime section nền đỏ + "CHOPPY — Avoid trading"
     Hit Rate: chỉ khi Show_Performance_Stats == true

3. UpdateRadar():
   - Top 5 RP gần nhất (sort theo khoảng cách từ current price)
   - BOUNDS: int radar_count = MathMin(5, g_rp_count);  // Guard < 5 RPs
   - Hiện: price, distance (pips), score
   - RES phía trên, SUP phía dưới
   - HIỆU NĂNG: Dùng partial sort (selection of top-5), KHÔNG full sort 200 RPs
     // Loop 5 lần, mỗi lần tìm nearest chưa selected → O(5N) = O(N) thay O(N log N)

4. GetBiasString(): string
   - STRONG_TREND + UP → "BUY preferred"
   - STRONG_TREND + DOWN → "SELL preferred"
   - WEAK_TREND + UP → "BUY preferred"
   - WEAK_TREND + DOWN → "SELL preferred"
   - RANGING → "Neutral"
   - CHOPPY → "Avoid trading"

5. RepositionDashboard():
   - Gọi khi CHARTEVENT_CHART_CHANGE
   - Recalc vị trí theo Dashboard_Corner + chart size

6. DeleteDashboard():
   - ObjectsDeleteAll(0, OBJECT_PREFIX + "DASH_")

Font scaling: detect CHART_SCALE → adjust font ±2. Min font 6.
Mỗi row = 1 OBJ_LABEL riêng, vị trí tính bằng xdistance/ydistance từ corner.
```

---
---

## PHASE 6: INTEGRATION (P17 — làm cuối cùng)

---

## PROMPT 17: RP_Main.mq5 (Main Indicator File)

```
Tạo file MQL5/Indicators/ReactionPoint/RP_Main.mq5 — main file cho Reaction Point Indicator v3.0.

INDICATOR PROPERTIES:
  #property strict
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
  #include <ReactionPoint/RP_MarketStructure.mqh>
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
input int    Swing_Lookback           = 3;      // [1-10]
input int    Min_RP_Distance_Pips     = 20;     // [5-100]
input int    Min_Reaction_Move_Pips   = 15;     // [5-100]
input int    Initial_Bars_To_Scan     = 500;    // [50-2000]
input bool   Use_Adaptive_Reaction    = true;
input double Reaction_ATR_Multiplier  = 0.5;

// BREAKOUT
input int    Breakout_Confirm_Pips    = 5;      // [1-50]
input int    Max_Retest_Bars          = 50;     // [10-200]

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

// MARKET STRUCTURE (Module H)
input bool   Use_Market_Structure     = true;
input int    Structure_Lookback_Bars  = 50;    // [20-100]

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
   - PRESET_CUSTOM → copy input values trực tiếp vào g_ globals
   - PRESET_AUTO → detect Period():
     <=PERIOD_M30 → áp M30 preset
     <=PERIOD_H1 → áp H1 preset
     <=PERIOD_H4 → áp H4 preset
     else → áp D1 preset
   - Áp tất cả giá trị từ TF Preset Table (bảng bên dưới)

2. ValidateInputs():
   - Clamp tất cả input về range hợp lệ, Print warning nếu cần:
     Swing_Lookback: MathMax(1, MathMin(Swing_Lookback, 10))
     Min_RP_Distance_Pips: MathMax(5, MathMin(Min_RP_Distance_Pips, 100))
     Min_Reaction_Move_Pips: MathMax(5, MathMin(Min_Reaction_Move_Pips, 100))
     Initial_Bars_To_Scan: MathMax(50, MathMin(Initial_Bars_To_Scan, Bars(_Symbol, PERIOD_CURRENT)-10))
     Breakout_Confirm_Pips: MathMax(1, MathMin(Breakout_Confirm_Pips, 50))
     Structure_Lookback_Bars: MathMax(20, MathMin(Structure_Lookback_Bars, 100))
   - Validate HTF hierarchy: HTF_1 > Period(), HTF_2 > HTF_1
     Nếu vi phạm → Print warning + set Show_HTF_1/2 = false
   - Nếu bars < Swing_Lookback*2+5 → return INIT_FAILED + Print error

3. ArrayResize (pre-allocate TẤT CẢ arrays 1 lần, KHÔNG resize runtime):
   ArrayResize(g_rp_array, MAX_RP_COUNT);
   ArrayResize(g_confluence_array, MAX_CONFLUENCE);
   ArrayResize(g_setup_array, MAX_SETUPS);
   ArrayResize(g_rp_dirty, MAX_RP_COUNT);       // Dirty flags
   ArrayResize(g_last_calc_bar, MAX_RP_COUNT);   // Last calc bar per RP
   ArrayInitialize(g_rp_dirty, true);            // Force first calc
   ArrayInitialize(g_last_calc_bar, -1);

4. if(!InitIndicatorHandles()) return INIT_FAILED;
5. InitStats()
6. if(g_show_dashboard) CreateDashboard();
7. if(g_show_session_background) CreateSessionObjects();  // Tạo 1 lần, update visibility sau
8. EventSetTimer(1)  // Flash management
9. Return INIT_SUCCEEDED

=== OnCalculate() — PERFORMANCE-OPTIMIZED ===

// ╔══════════════════════════════════════════════════════╗
// ║  PHÂN TẦNG: per-tick (nhẹ) vs per-bar (nặng)       ║
// ║  Target: <2ms per tick, <50ms per bar               ║
// ╚══════════════════════════════════════════════════════╝

// === PER-TICK (chỉ operations nhẹ, <1ms) ===

// Spread: rolling buffer 100 tick, rất nhẹ
UpdateSpreadFilter();

// Alert: CHỈ check proximity khi giá di chuyển đủ xa (>2 pips từ lần check cuối)
double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
if(MathAbs(current_bid - g_last_alert_check_price) >= PipsToPrice(2)) {
   CheckAllAlerts();    // 200 RP × distance calc, nhưng chỉ khi giá đi 2+ pips
   g_last_alert_check_price = current_bid;
}

// Setup: CHỈ check invalidation (SL hit) per tick, KHÔNG tạo mới
// Tạo mới chỉ khi IsNewBar()
UpdateSetupInvalidation();  // Lightweight: loop 10 setups, check SL only

// === PER-BAR (IsNewBar()) — TOÀN BỘ LOGIC NẶNG ===
if(!IsNewBar()) return rates_total;

// ── STEP 0: Cache & Revalidation ──
UpdateBarCache();     // ATR14, Volume MA20, Fibo levels — 1 lần/bar
RevalidateHandles();  // Mỗi 100 bars, check handle validity

// ── STEP 1: Market Context (nhẹ, ~1ms) ──
UpdateCurrentSession();   // Cache session, chỉ update nếu hour thay đổi
UpdateMarketRegime();     // 1 CopyBuffer ADX + compare

// ── STEP 2: News Filter (throttled, ~0ms most bars) ──
// CHỈ gọi API mỗi 5 phút (khoảng 5-15 bars tùy TF), KHÔNG mỗi bar
static datetime last_news_check = 0;
if(TimeCurrent() - last_news_check >= 300) {  // 300 seconds = 5 minutes
   UpdateNewsFilter();
   last_news_check = TimeCurrent();
}

// ── STEP 3: Market Structure (moderate, ~2ms) ──
if(g_use_market_structure)
   UpdateMarketStructure();  // Scan 50 bars, find 4 swing points

// ── STEP 4: RP Detection (heavy on first run, ~5-20ms) ──
static bool first_run = true;
int scan_bars = first_run ? g_initial_bars_to_scan : g_swing_lookback*2+5;
int prev_rp_count = g_rp_count;
DetectSwingPoints(scan_bars);
first_run = false;

// ── STEP 5: Breakout & Retest (~2ms) ──
CheckBreakoutsAndRetests();
// Breakout/retest sets g_rp_dirty[i] = true cho RP bị ảnh hưởng

// ── STEP 6: Scoring — CHỈ DIRTY RPs (~1-5ms thay vì 50ms) ──
// Mark dirty: mới tạo, vừa test, role reversed, hoặc decay interval đến
for(int i = prev_rp_count; i < g_rp_count; i++)
   g_rp_dirty[i] = true;  // RP mới tạo

for(int i = 0; i < g_rp_count; i++) {
   if(!g_rp_array[i].is_active) continue;
   // Decay check: dirty mỗi g_decay_interval_bars
   int bars_since = Bars(_Symbol, PERIOD_CURRENT) - g_last_calc_bar[i];
   if(bars_since >= g_decay_interval_bars) g_rp_dirty[i] = true;

   if(!g_rp_dirty[i]) continue;  // SKIP — không thay đổi
   CalcFinalScore(i);
   g_rp_dirty[i] = false;
   g_last_calc_bar[i] = Bars(_Symbol, PERIOD_CURRENT);
}
UpdateAllDecay();  // Update opacity cho tất cả active RP

// ── STEP 7: Confluence — CHỈ khi có RP mới hoặc breakout ──
if(g_use_confluence_zones) {
   // g_confluence_needs_update: set = true bởi HandlePartialBreakout() khi RP tách zone
   bool need_confluence_update = (g_rp_count != prev_rp_count) || g_confluence_needs_update;
   if(need_confluence_update) {
      // HTF: CHỈ update khi có bar mới trên HTF
      bool htf1_new = IsNewBarHTF(g_htf_1);
      bool htf2_new = IsNewBarHTF(g_htf_2);
      if(htf1_new || !g_htf1_cache_valid) {
         CollectHTFReactionPoints();  // CopyHigh/CopyLow batch
         g_htf1_cache_valid = true;
      }
      if(htf2_new || !g_htf2_cache_valid) {
         CollectHTFReactionPoints();  // CHỈ cho HTF_2
         g_htf2_cache_valid = true;
      }
      MergeClusterZones();
      ApplyConfluenceScoring();
      g_confluence_needs_update = false;  // Reset flag
   }
}

// ── STEP 8: Entry Setup — tạo mới chỉ per-bar ──
if(g_show_entry_setup)
   CheckEntryConditions();

// ── STEP 9: UI — chỉ redraw thay đổi ──
RedrawChangedRP();   // Chỉ RP có state thay đổi
if(g_show_session_background)
   UpdateSessionVisibility();  // Update visibility, KHÔNG tạo mới objects
if(g_show_dashboard)
   UpdateDashboard();
EnforceObjectLimit();
UpdateStats();

// ── Broker disconnect detection ──
static int last_bar_count = 0;
int current_bars = Bars(_Symbol, PERIOD_CURRENT);
if(last_bar_count > 0 && current_bars - last_bar_count > 5) {
   Print("RP: Gap detected (", current_bars - last_bar_count, " bars). Rescanning...");
   first_run = true;  // Force full rescan next bar
   // Reset alert cooldowns
   for(int i = 0; i < g_rp_count; i++)
      ArrayInitialize(g_rp_array[i].alert_sent, false);
}
last_bar_count = current_bars;

return rates_total;

=== IsNewBarHTF(ENUM_TIMEFRAMES tf): bool ===
// Detect bar mới trên Higher Timeframe
static datetime htf_last_time[];  // Indexed by tf
datetime htf_time = iTime(_Symbol, tf, 0);
if(htf_time != htf_last_time[tf_index]) {
   htf_last_time[tf_index] = htf_time;
   return true;
}
return false;

=== UpdateSetupInvalidation() ===
// Lightweight per-tick: chỉ check SL/TP hit, KHÔNG tạo mới
for(int i = 0; i < g_setup_count; i++) {
   if(!g_setup_array[i].is_active) continue;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // SL hit check
   if(g_setup_array[i].direction == RP_SUPPORT && bid <= g_setup_array[i].sl_price)
      g_setup_array[i].is_invalidated = true, g_setup_array[i].is_active = false;
   if(g_setup_array[i].direction == RP_RESISTANCE && bid >= g_setup_array[i].sl_price)
      g_setup_array[i].is_invalidated = true, g_setup_array[i].is_active = false;
}

=== OnDeinit(reason) ===

- EventKillTimer()
- DeleteAllObjects()
- DeleteDashboard()
- ReleaseIndicatorHandles()
- REASON_PARAMETERS → xóa objects, giữ RP data, set first_run=true (recalculate)
- REASON_CHARTCHANGE / REASON_RECOMPILE / REASON_REMOVE → full reset

=== OnChartEvent(id, lparam, dparam, sparam) ===

- CHARTEVENT_CHART_CHANGE → RepositionDashboard() + UpdateFontSizes()

=== OnTimer() ===

- Flash management: toggle visibility cho RP đang flash
- Decrement flash_count, kill timer khi xong
- Max flash: MAX_FLASH_RP = 3

=== ERROR HANDLING (Spec Section 16) ===

- Division by zero: PipValue() KHÔNG BAO GIỜ return 0, SafeATR() cached + fallback
- RR ratio: if(sl_pips < 0.1) sl_pips = 0.1 trước khi chia
- Score: MathMax(0, MathMin(adjusted, SCORE_CAP)) — clamp cả 2 phía
- HTF data: retry MAX_HTF_RETRIES lần, fallback current TF, cache valid results
- Handle invalid: RevalidateHandles() mỗi 100 bars, auto-recreate
- Array overflow: evict RP → inactive first → lowest score non-confluence → oldest
  + Track evictable_count; Assert > 0 trước khi evict
- Array bounds: radar_count = MathMin(5, g_rp_count); loop chỉ đến radar_count
- Empty history: bars < Swing_Lookback*2+5 → warning, return (không crash)
- Broker disconnect: gap > 5 bars → rescan all RP, reset alert cooldowns
- Confluence rp_ids remove: bounds-check loop, guard khi rp_id không tìm thấy

=== TF PRESET TABLE ===

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
Structure_Lookback       30     50    50     80
HTF_1                    H1     H4    D1     W1
HTF_2                    H4     D1    W1    MN1

PRESET_AUTO: Period()<=M30→M30, <=H1→H1, <=H4→H4, else→D1
```

---
---

## PHASE 7: RELIABILITY UPGRADES (P18, P19, P20 — cải thiện xác suất tín hiệu)

### Dependency Graph bổ sung
```
Phase 7: P18 (scoring) + P19 (fibo) song song → P20 (trend alignment, cần P18+P19)
Tất cả cần Phase 1-6 đã hoàn thành.
```

---

## PROMPT 18: Rebalance Scoring Weights (Sửa RP_Scoring.mqh)

```
Sửa file MQL5/Include/ReactionPoint/RP_Scoring.mqh — Rebalance trọng số Base Score.

MỤC ĐÍCH: Trọng số hiện tại quá "phẳng" — candle pattern (20) gần bằng reaction strength (25).
Trader kinh nghiệm coi reaction strength là yếu tố quan trọng nhất (institutional interest),
trong khi candle pattern chỉ là confirmation thứ yếu. Volume cũng cần tăng tầm quan trọng.

=== THAY ĐỔI TRỌNG SỐ BASE SCORE ===

| Component         | Cũ  | Mới  | Lý do                                           |
|-------------------|-----|------|--------------------------------------------------|
| Reaction Strength | 25  | 35   | Yếu tố #1 — reaction mạnh = institutional money |
| Test Count        | 20  | 20   | Giữ nguyên — logic diminishing returns tốt       |
| Candle Pattern    | 20  | 12   | Chỉ là confirmation, không phải driver           |
| Fibonacci         | 15  | 10   | Giảm — sẽ chính xác hơn sau P19 (swing-to-swing)|
| Volume            | 10  | 15   | Tăng — volume confirmation quan trọng hơn pattern|
| Round Number      | 10  | 8    | Giảm nhẹ — ít impact thực tế                    |
| Volume Delta      | ±5  | ±5   | Giữ nguyên                                       |
| TỔNG MAX          | 105 | 105  | Giữ tổng không đổi, cap vẫn = 100               |

=== CHI TIẾT SỬA ===

1. CalcBaseScore(int rp_index): sửa các hệ số

   a) Reaction Strength (max 35, cũ 25):
      score += MathMin((rp.initial_reaction_pips / atr_pips) * 35.0, 35.0)

   b) Candle Pattern (max 12, cũ 20):
      PINBAR=12, ENGULFING=10, OUTSIDE_BAR=8, LARGE_WICK=6, NONE=0

   c) Fibonacci Alignment (max 10, cũ 15):
      618 → 10, 500 → 7, 382 → 4

   d) Volume (max 15, cũ 10):
      >1.5x MA20 → 15, >1.2x MA20 → 8, else → 0

   e) Round Number (max 8, cũ 10):
      <= 10 pips → 8, <= 20 pips → 4, else → 0

   f) Test Count, Volume Delta: KHÔNG ĐỔI

2. CalcFibonacciScore(double price): sửa return values
   618 → return 10.0 (cũ 15.0)
   500 → return 7.0  (cũ 10.0)
   382 → return 4.0  (cũ 7.0)

3. CalcVolumeScore(int bar_shift): sửa return values
   >1.5x → return 15.0 (cũ 10.0)
   >1.2x → return 8.0  (cũ 5.0)

4. RoundNumberScore(double price): sửa return values
   <= 10 pips → return 8.0  (cũ 10.0)
   <= 20 pips → return 4.0  (cũ 5.0)

5. GetCandlePatternScore() (nếu tồn tại trong RP_Detection.mqh):
   Cập nhật tương ứng: PINBAR=12, ENGULFING=10, OUTSIDE_BAR=8, LARGE_WICK=6

KHÔNG SỬA: CalcFinalScore, các module adjustments, SCORE_CAP.
CalcBaseScore cap vẫn = MathMin(score, 100.0)
```

---

## PROMPT 19: Fibonacci Swing-to-Swing Engine (Sửa RP_Utils.mqh)

```
Sửa file MQL5/Include/ReactionPoint/RP_Utils.mqh — Thay thế UpdateFiboCache() bằng
Fibonacci Swing-to-Swing engine chính xác hơn.

MỤC ĐÍCH: Fibo hiện tại tìm high/low TUYỆT ĐỐI trong N bars lookback → vô nghĩa về
mặt technical analysis. Fibo chỉ có ý nghĩa khi tính TỪ một swing leg hoàn chỉnh
(swing high → swing low hoặc ngược lại).

=== CONCEPT ===

Swing Leg = một chuyển động giá rõ ràng từ swing point A đến swing point B.
Fibonacci retracement chỉ valid khi:
1. Leg đã hoàn thành (swing B confirmed bằng N bars)
2. Giá đang retrace (quay lại) chứ không extend
3. Leg đủ lớn (>= 2x ATR) để có ý nghĩa

Ví dụ Uptrend:
  Swing Low (A) → Swing High (B) = completed leg
  Fibo 38.2%, 50%, 61.8% tính từ B xuống A = buy-the-dip levels

Ví dụ Downtrend:
  Swing High (A) → Swing Low (B) = completed leg
  Fibo 38.2%, 50%, 61.8% tính từ B lên A = sell-the-rally levels

=== THÊM STRUCT VÀ GLOBALS (trong RP_Utils.mqh) ===

// Thêm vào RP_Defines.mqh hoặc đầu RP_Utils.mqh (trước UpdateFiboCache)
struct SFiboLeg {
   double    swing_a_price;    // Điểm bắt đầu leg
   double    swing_b_price;    // Điểm kết thúc leg
   int       swing_a_bar;      // Bar index swing A
   int       swing_b_bar;      // Bar index swing B
   bool      is_bullish_leg;   // true = A(low)→B(high), false = A(high)→B(low)
   bool      is_valid;         // true nếu leg >= 2*ATR và confirmed
   double    fibo_382;         // Level 38.2%
   double    fibo_500;         // Level 50.0%
   double    fibo_618;         // Level 61.8%
   double    fibo_786;         // Level 78.6% (thêm mới — institutional level)
   void Init() { ZeroMemory(this); }
};

#define MAX_FIBO_LEGS 3
SFiboLeg g_fibo_legs[];       // ArrayResize(MAX_FIBO_LEGS) trong OnInit
int      g_fibo_leg_count = 0;

// GIỮ LẠI g_cached_fibo_618/500/382 cho backward compatibility
// Nhưng giá trị giờ lấy từ fibo leg GẦN NHẤT (leg[0])

=== THAY THẾ UpdateFiboCache() ===

void UpdateFiboCache():
  // STEP 1: Tìm swing points trong lookback
  int lookback = MathMin(g_fibo_lookback_bars, Bars(_Symbol, PERIOD_CURRENT) - 1);
  if(lookback < 10) return;
  int N = MathMin(g_swing_lookback, 3); // N nhỏ hơn cho fibo swing detection
  
  // Tìm swing highs/lows trong bars[1..lookback] — anti-repainting
  // Lưu max 6 swing points gần nhất, sắp theo bar index tăng dần (gần nhất = index nhỏ)
  #define MAX_FIBO_SWINGS 6
  double swing_prices[MAX_FIBO_SWINGS];
  int    swing_bars[MAX_FIBO_SWINGS];
  int    swing_types[MAX_FIBO_SWINGS]; // 1=High, -1=Low
  int    swing_count = 0;
  
  for(int i = N + 1; i <= lookback - N && swing_count < MAX_FIBO_SWINGS; i++):
    // Check swing high
    bool is_high = true;
    for(int j = 1; j <= N; j++):
      if(iHigh(_Symbol, PERIOD_CURRENT, i) <= iHigh(_Symbol, PERIOD_CURRENT, i-j) ||
         iHigh(_Symbol, PERIOD_CURRENT, i) <= iHigh(_Symbol, PERIOD_CURRENT, i+j)):
        is_high = false; break;
    
    // Check swing low
    bool is_low = true;
    for(int j = 1; j <= N; j++):
      if(iLow(_Symbol, PERIOD_CURRENT, i) >= iLow(_Symbol, PERIOD_CURRENT, i-j) ||
         iLow(_Symbol, PERIOD_CURRENT, i) >= iLow(_Symbol, PERIOD_CURRENT, i+j)):
        is_low = false; break;
    
    if(is_high):
      swing_prices[swing_count] = iHigh(_Symbol, PERIOD_CURRENT, i);
      swing_bars[swing_count] = i;
      swing_types[swing_count] = 1;
      swing_count++;
    elif(is_low):
      swing_prices[swing_count] = iLow(_Symbol, PERIOD_CURRENT, i);
      swing_bars[swing_count] = i;
      swing_types[swing_count] = -1;
      swing_count++;
  
  if(swing_count < 2):
    // Không đủ swing → reset cache
    g_fibo_leg_count = 0;
    g_cached_fibo_618 = 0.0;
    g_cached_fibo_500 = 0.0;
    g_cached_fibo_382 = 0.0;
    return;
  
  // STEP 2: Xây dựng fibo legs từ swing pairs liền kề
  g_fibo_leg_count = 0;
  double current = RP_Close(1);
  
  for(int i = 0; i < swing_count - 1 && g_fibo_leg_count < MAX_FIBO_LEGS; i++):
    // Chỉ ghép cặp swing types khác nhau (High+Low hoặc Low+High)
    if(swing_types[i] == swing_types[i+1]) continue;
    
    double a_price = swing_prices[i+1]; // Swing cũ hơn = start
    double b_price = swing_prices[i];   // Swing mới hơn = end
    int    a_bar   = swing_bars[i+1];
    int    b_bar   = swing_bars[i];
    
    double leg_size = MathAbs(b_price - a_price);
    
    // FILTER: Leg >= 2x ATR
    if(leg_size < g_cached_atr14 * 2.0) continue;
    
    // FILTER: Price đang retrace, không extend
    bool is_bullish = (b_price > a_price);
    if(is_bullish):
      if(current >= b_price || current <= a_price) continue;
    else:
      if(current <= b_price || current >= a_price) continue;
    
    // Build fibo leg
    SFiboLeg leg;
    leg.Init();
    leg.swing_a_price  = a_price;
    leg.swing_b_price  = b_price;
    leg.swing_a_bar    = a_bar;
    leg.swing_b_bar    = b_bar;
    leg.is_bullish_leg = is_bullish;
    leg.is_valid       = true;
    
    double range = MathAbs(b_price - a_price);
    if(is_bullish):
      leg.fibo_382 = b_price - range * 0.382;
      leg.fibo_500 = b_price - range * 0.500;
      leg.fibo_618 = b_price - range * 0.618;
      leg.fibo_786 = b_price - range * 0.786;
    else:
      leg.fibo_382 = b_price + range * 0.382;
      leg.fibo_500 = b_price + range * 0.500;
      leg.fibo_618 = b_price + range * 0.618;
      leg.fibo_786 = b_price + range * 0.786;
    
    g_fibo_legs[g_fibo_leg_count] = leg;
    g_fibo_leg_count++;
  
  // STEP 3: Update backward-compatible cache từ leg[0]
  if(g_fibo_leg_count > 0):
    g_cached_fibo_618  = g_fibo_legs[0].fibo_618;
    g_cached_fibo_500  = g_fibo_legs[0].fibo_500;
    g_cached_fibo_382  = g_fibo_legs[0].fibo_382;
    g_cached_fibo_high = MathMax(g_fibo_legs[0].swing_a_price, g_fibo_legs[0].swing_b_price);
    g_cached_fibo_low  = MathMin(g_fibo_legs[0].swing_a_price, g_fibo_legs[0].swing_b_price);
  else:
    g_cached_fibo_618 = 0.0;
    g_cached_fibo_500 = 0.0;
    g_cached_fibo_382 = 0.0;
    g_cached_fibo_high = 0.0;
    g_cached_fibo_low  = 0.0;

=== SỬA CalcFibonacciScore() (RP_Scoring.mqh) ===

double CalcFibonacciScore(double price):
  double best_score = 0.0;
  double tolerance = PipsToPrice(g_fibo_tolerance_pips);
  bool   found_in_another_leg = false;
  
  for(int i = 0; i < g_fibo_leg_count; i++):
    if(!g_fibo_legs[i].is_valid) continue;
    double score = 0.0;
    
    if(MathAbs(price - g_fibo_legs[i].fibo_618) <= tolerance)      score = 10.0;
    else if(MathAbs(price - g_fibo_legs[i].fibo_786) <= tolerance) score = 8.0;
    else if(MathAbs(price - g_fibo_legs[i].fibo_500) <= tolerance) score = 7.0;
    else if(MathAbs(price - g_fibo_legs[i].fibo_382) <= tolerance) score = 4.0;
    
    // Fibo confluence: RP trùng level từ 2+ legs → +3
    if(score > 0.0 && found_in_another_leg) score += 3.0;
    if(score > 0.0) found_in_another_leg = true;
    
    if(score > best_score) best_score = score;
  
  return MathMin(best_score, 13.0); // Cap: 10 base + 3 confluence bonus

=== THAY ĐỔI TRONG OnInit (RP_Main.mq5) ===

Thêm: ArrayResize(g_fibo_legs, MAX_FIBO_LEGS);

LƯU Ý:
- Anti-repainting: chỉ dùng bars[1..N]
- Performance: tính 1 lần/bar, max 6 swing points scan
- Backward compatible: g_cached_fibo_* vẫn hoạt động
```

---

## PROMPT 20: Multi-TF Trend Alignment Filter (Sửa RP_Confluence.mqh + RP_Scoring.mqh)

```
Sửa RP_Confluence.mqh, RP_Scoring.mqh, RP_EntrySetup.mqh, RP_Main.mq5 — Thêm Multi-TF
Trend Alignment filter.

MỤC ĐÍCH: Kiểm tra trend direction alignment giữa current TF + HTF_1 + HTF_2.
RP SUPPORT trong uptrend trên tất cả TFs = high probability.
RP SUPPORT counter-trend trên tất cả TFs = extremely risky.

=== THÊM GLOBALS (trong RP_Utils.mqh) ===

struct SHTFTrend {
   ENUM_TIMEFRAMES  tf;
   ENUM_TREND_DIR   trend;
   bool             is_valid;
   datetime         last_updated;
   void Init() { ZeroMemory(this); }
};

SHTFTrend g_htf_trends[3];        // [0]=current TF, [1]=HTF_1, [2]=HTF_2
bool      g_use_trend_alignment = true;

=== THÊM FUNCTIONS (trong RP_Confluence.mqh, sau ApplyConfluenceScoring) ===

1. UpdateHTFTrends():
   - Gọi per-bar trong Main OnCalculate, STEP 1 (sau UpdateMarketRegime)
   
   // Current TF — đã có sẵn
   g_htf_trends[0].tf    = Period();
   g_htf_trends[0].trend = g_current_trend;
   g_htf_trends[0].is_valid = true;
   g_htf_trends[0].last_updated = TimeCurrent();
   
   // HTF_1 và HTF_2
   ENUM_TIMEFRAMES tfs[2] = {g_htf_1, g_htf_2};
   for(int t = 0; t < 2; t++):
     int idx = t + 1;
     g_htf_trends[idx].tf = tfs[t];
     
     double htf_close[];
     int copied = CopyClose(_Symbol, tfs[t], 0, 21, htf_close);
     if(copied < 21):
       g_htf_trends[idx].is_valid = false;
       continue;
     
     ArraySetAsSeries(htf_close, true);
     
     // Trend detection: HH+HL vs LH+LL trên 20 bars
     // Đơn giản: so sánh close[1] vs close[10] vs close[20]
     bool up1   = htf_close[1] > htf_close[10];
     bool up2   = htf_close[10] > htf_close[20];
     bool down1 = htf_close[1] < htf_close[10];
     bool down2 = htf_close[10] < htf_close[20];
     
     if(up1 && up2)        g_htf_trends[idx].trend = TREND_UP;
     else if(down1 && down2) g_htf_trends[idx].trend = TREND_DOWN;
     else                    g_htf_trends[idx].trend = TREND_NONE;
     
     g_htf_trends[idx].is_valid = true;
     g_htf_trends[idx].last_updated = TimeCurrent();

2. GetTrendAlignmentScore(ENUM_RP_TYPE rp_type): double
   - if(!g_use_trend_alignment) return 0.0;
   
   int aligned = 0, counter = 0, total = 0;
   
   for(int i = 0; i < 3; i++):
     if(!g_htf_trends[i].is_valid) continue;
     total++;
     
     bool is_aligned;
     if(rp_type == RP_SUPPORT):
       is_aligned = (g_htf_trends[i].trend == TREND_UP || g_htf_trends[i].trend == TREND_NONE);
     else:
       is_aligned = (g_htf_trends[i].trend == TREND_DOWN || g_htf_trends[i].trend == TREND_NONE);
     
     if(is_aligned) aligned++; else counter++;
   
   if(total == 0) return 0.0;
   
   if(aligned == total)     return 20.0;   // Tất cả đồng thuận
   if(aligned >= total - 1) return 10.0;   // 2/3 aligned
   
   double penalty = (counter == total) ? -25.0 : -15.0;
   
   // CHoCH exception: giảm penalty 50% nếu vừa có CHoCH
   if(g_choch_detected && g_last_choch_bar <= 10)
     penalty *= 0.5;
   
   return penalty;

3. IsTrendAligned(ENUM_RP_TYPE rp_type): bool
   - return GetTrendAlignmentScore(rp_type) >= 0.0;

=== TÍCH HỢP VÀO CalcFinalScore (RP_Scoring.mqh) ===

double adjusted = rp.base_score
   + GetRegimeScoreAdj(rp.rp_type)
   - CalcDecayPenalty(rp_index)
   + CalcRecentBonus(rp_index)
   + GetSessionScoreAdj(rp.session_formed)
   + GetDayOfWeekAdj()
   + GetStructureScoreAdj(rp_index)
   + GetLiquiditySweepBonus(rp_index)
   + GetTrendAlignmentScore(rp.rp_type)    // ← THÊM MỚI: [-25, +20]
   + (rp.is_role_reversed ? 15.0 : 0.0)
   + ((rp.is_fresh && rp.test_count == 0) ? 10.0 : 0.0);

=== TÍCH HỢP VÀO CheckEntryConditions (RP_EntrySetup.mqh) ===

Thêm filter (f) sau các check hiện tại:
  // f) Trend alignment
  if(g_use_trend_alignment && !IsTrendAligned(rp.rp_type)):
    if(rp.final_score < 110) continue; // Skip — counter-trend without premium
    // Premium (>=110): vẫn cho phép entry counter-trend

=== TÍCH HỢP VÀO OnCalculate (RP_Main.mq5) ===

// STEP 1 — sau UpdateMarketRegime():
if(g_use_trend_alignment)
   UpdateHTFTrends();

=== INPUT MỚI (RP_Main.mq5) ===

// TREND ALIGNMENT
input bool Use_Trend_Alignment = true;

ApplyTFPreset: g_use_trend_alignment = Use_Trend_Alignment;

=== DASHBOARD (RP_Dashboard.mqh) ===

// Thêm dòng sau REGIME:
// "TREND   CTF:↑  H4:↑  D1:→   ALIGNED"     (clrLime)
// "TREND   CTF:↑  H4:↓  D1:↓   COUNTER ⚠"   (clrTomato)
string GetTrendArrow(ENUM_TREND_DIR t):
  if(t == TREND_UP) return "↑";
  if(t == TREND_DOWN) return "↓";
  return "→";

LƯU Ý:
- Performance: CopyClose 21 bars × 2 TFs = rất nhẹ, 1 lần/bar
- Anti-repainting: detect trend trên closed bars[1..20]
- CHoCH exception: reversal play hợp lệ khi structure vừa đổi
- Premium exception: score >=110 vẫn cho phép entry counter-trend
```

## PROMPT 21: Dynamic Zone Width (Sửa RP_Detection.mqh)

```
Sửa file MQL5/Include/ReactionPoint/RP_Detection.mqh — Zone width dựa trên candle thực tế
thay vì cố định g_zone_width_pips.

MỤC ĐÍCH: Zone width cố định (VD: 4 pips mỗi bên) gây 2 vấn đề:
- Candle rejection lớn (20 pips body) → zone 4 pips = quá hẹp → giá "miss" zone
- Candle nhỏ (3 pips body) tại ranging → zone 4 pips = quá rộng → false signal
Zone phải khớp kích thước thực tế của phản ứng giá tại swing point.

=== CONCEPT ===

Zone = vùng mà institutional money đã phản ứng, xác định bởi candle tại swing point:

SUPPORT zone:
  zone_low  = low của swing candle (đáy phản ứng)
  zone_high = MathMax(open, close) của swing candle (body top)
  → Zone bao trùm TOÀN BỘ body + lower wick = vùng mà buyer đã mua

RESISTANCE zone:
  zone_high = high của swing candle (đỉnh phản ứng)
  zone_low  = MathMin(open, close) của swing candle (body bottom)
  → Zone bao trùm TOÀN BỘ body + upper wick = vùng mà seller đã bán

=== SAFETY CLAMPS ===

Zone quá hẹp hoặc quá rộng đều không tốt:
  double zone_range = zone_high - zone_low;
  double min_width  = PipsToPrice(g_zone_width_pips / 2.0);  // Floor: nửa width cũ
  double max_width  = g_cached_atr14 * 1.5;                  // Ceiling: 1.5x ATR

  if(zone_range < min_width):
    // Candle quá nhỏ → pad đều 2 bên bằng min_width
    double center = (zone_high + zone_low) / 2.0;
    zone_high = center + min_width / 2.0;
    zone_low  = center - min_width / 2.0;

  if(zone_range > max_width):
    // Candle quá lớn (news spike) → clamp về max_width, giữ từ edge phản ứng
    if(rp_type == RP_SUPPORT):
      zone_high = zone_low + max_width;  // Giữ đáy, cắt trên
    else:
      zone_low = zone_high - max_width;  // Giữ đỉnh, cắt dưới

=== SỬA CreateRP() ===

void CreateRP(ENUM_RP_TYPE rp_type, int bar_index, double price,
              ENUM_CANDLE_PATTERN pattern, double reaction_pips):

  // THAY THẾ 2 dòng cũ:
  //   rp.zone_high = price + PipsToPrice(g_zone_width_pips / 2.0);
  //   rp.zone_low  = price - PipsToPrice(g_zone_width_pips / 2.0);

  // BẰNG:
  double bar_open  = iOpen(_Symbol, PERIOD_CURRENT, bar_index);
  double bar_close = iClose(_Symbol, PERIOD_CURRENT, bar_index);
  double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, bar_index);
  double bar_low   = iLow(_Symbol, PERIOD_CURRENT, bar_index);

  if(rp_type == RP_SUPPORT):
    rp.zone_low  = bar_low;
    rp.zone_high = MathMax(bar_open, bar_close);  // Body top
  else: // RP_RESISTANCE
    rp.zone_high = bar_high;
    rp.zone_low  = MathMin(bar_open, bar_close);  // Body bottom

  // Safety clamps
  double zone_range = rp.zone_high - rp.zone_low;
  double min_width  = PipsToPrice(g_zone_width_pips / 2.0);
  double max_width  = (g_cached_atr14 > 0) ? g_cached_atr14 * 1.5 : PipsToPrice(30);

  if(zone_range < min_width):
    double center = (rp.zone_high + rp.zone_low) / 2.0;
    rp.zone_high = center + min_width / 2.0;
    rp.zone_low  = center - min_width / 2.0;

  if(zone_range > max_width):
    if(rp_type == RP_SUPPORT):
      rp.zone_high = rp.zone_low + max_width;
    else:
      rp.zone_low = rp.zone_high - max_width;

  // rp.price giữ nguyên = swing point gốc (dùng cho scoring/distance calc)

KHÔNG SỬA gì khác. Scoring, alerts, confluence vẫn dùng rp.price để tính khoảng cách.
Zone_high/zone_low chỉ dùng cho:
- Drawing (DrawRPZone)
- Breakout check (close < zone_low hoặc close > zone_high)
- Entry trigger (close trong zone)
- Test count (giá chạm zone)

LƯU Ý:
- g_zone_width_pips giờ chỉ dùng làm FLOOR (minimum width), không phải fixed width
- Anti-repainting: iOpen/iClose/iHigh/iLow tại bar_index (confirmed bar, không phải bar[0])
- ATR clamp ngăn news spike tạo zone quá lớn (vô nghĩa)
```

---

## THỨ TỰ THỰC THI TÓM TẮT

```
PHASE 1 — Foundation (tuần tự):
  P1:  RP_Defines.mqh       ← BẮT ĐẦU TỪ ĐÂY
  P2:  RP_Utils.mqh         ← cần P1

PHASE 2 — Independent Modules (song song, chỉ cần P1+P2):
  P3:  RP_RegimeFilter.mqh  (Module A)
  P4:  RP_Session.mqh       (Module E)
  P5:  RP_DynamicDecay.mqh  (Module B)
  P6:  RP_NewsFilter.mqh    (Module F)
  P7:  RP_SpreadFilter.mqh  (Module G)

  → SAU PHASE 2: Compile test P1-P7 cùng nhau (tạo dummy Main), fix errors.

PHASE 3 — Core Logic + Market Structure (tuần tự):
  P8:  RP_Detection.mqh     ← cần P1+P2
  P9A: RP_MarketStructure.mqh (Module H — BOS/CHoCH/Sweep) ← cần P8
  P10: RP_Scoring.mqh       ← cần P3+P4+P5+P9A (gọi functions từ các module đó)

  → SAU PHASE 3: Compile test P1-P10 cùng nhau.

PHASE 4 — Advanced Modules (cần Phase 2+3):
  P11: RP_Confluence.mqh    (Module D)
  P12: RP_EntrySetup.mqh    (Module C)
  P13: RP_Stats.mqh

PHASE 5 — UI (cần Phase 4):
  P14: RP_Drawing.mqh
  P15: RP_Alerts.mqh
  P16: RP_Dashboard.mqh     ← cần P13+P14

  → SAU PHASE 5: Compile test P1-P16 cùng nhau.

PHASE 6 — Integration:
  P17: RP_Main.mq5          ← LÀM CUỐI CÙNG, tổng hợp tất cả
```

Mỗi session, chỉ cần paste prompt tương ứng. Không cần đọc lại spec.

### Convention reminder (copy vào đầu mỗi prompt nếu cần)

- MQL5: KHÔNG dùng `extern`, dùng `g_` globals (set bởi Main)
- KHÔNG dùng `TimeDayOfWeek()`, dùng `MqlDateTime dt; TimeToStruct(time, dt); dt.day_of_week`
- Opacity: dùng `BlendColor(fg, bg, alpha_pct)` helper, không có native alpha cho rectangles
- Anti-repainting: chỉ dùng bar[1] trở về trước, KHÔNG BAO GIỜ bar[0]
