# REACTION POINT INDICATOR v3.0 — IMPLEMENTATION PROMPTS
## Chuẩn hóa từ RP_FINAL_SPEC.md | 17 files | 7 phases

**Tổng:** 1 main `.mq5` + 16 `.mqh` includes
**Mỗi prompt = 1 session riêng. Paste prompt, không cần đọc lại spec.**

### Dependency Graph

```
Phase 1: P1 → P2                    (Foundation)
Phase 2: P3, P4, P5, P6, P7         (Independent — có thể song song)
Phase 3: P8 → P17 → P9              (Core Logic + Market Structure)
Phase 4: P10, P11, P12              (Advanced — cần Phase 2+3)
Phase 5: P13, P14, P15              (UI — cần Phase 4)
Phase 6: P16                        (Main — tổng hợp tất cả)
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

struct SConfluenceZone {
   int              id;
   double           zone_high, zone_low, center_price;
   int              rp_count;
   int              rp_ids[];            // DYNAMIC array — không giới hạn cứng
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

=== UTILITY FUNCTIONS ===

1. PipValue(): double
   - Tự detect pip value cho mọi pair
   - 5-digit broker: Point()*10 cho major pairs
   - JPY pairs: Point()*100 (hoặc detect từ Digits())
   - Digits()==3 hoặc 5 → PipValue = Point()*10
   - Digits()==2 hoặc 4 → PipValue = Point()

2. PipsToPrice(int pips): double
   - return pips * PipValue()

3. PriceToPips(double price_diff): double
   - return price_diff / PipValue()

4. SafeATR(int period, int shift=0): double
   - double atr = CalcATR(period, shift)
   - return (atr > 0 && atr == atr) ? atr : PipsToPrice(10)
   - Guard NaN và zero

5. GetATR14(int shift=0): double
   - Wrapper: return SafeATR(14, shift)

6. CalcATR(int period, int shift): double
   - Dùng g_handle_atr, CopyBuffer

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

14. InitIndicatorHandles():
    - g_handle_adx = iADX(_Symbol, PERIOD_CURRENT, adx_period)
    - g_handle_atr = iATR(_Symbol, PERIOD_CURRENT, 14)
    - Check INVALID_HANDLE → Print error

15. ReleaseIndicatorHandles():
    - IndicatorRelease cho tất cả handles

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

Extern inputs cần khai báo:
  extern int    ADX_Period;
  extern double ADX_Strong_Threshold;
  extern double ADX_Weak_Threshold;
  extern bool   Use_Regime_Filter;

GLOBALS TỪ RP_Utils.mqh:
  - g_current_regime, g_current_trend, g_current_adx
  - g_handle_adx
  - SafeATR(), GetATR14()

=== LOGIC ===

1. UpdateMarketRegime():
   - Đọc ADX value từ g_handle_adx (CopyBuffer)
   - g_current_adx = adx_value
   - Phân loại:
     ADX > ADX_Strong_Threshold (25) → REGIME_STRONG_TREND
     ADX >= ADX_Weak_Threshold (20) AND <= Strong → REGIME_WEAK_TREND
     ADX < ADX_Weak_Threshold:
       ATR(14) < ATR_MA50 * 0.7 → REGIME_CHOPPY
       Else → REGIME_RANGING
   - ATR_MA50: trung bình ATR(14) của 50 bars gần nhất

   Detect trend direction (cho STRONG/WEAK):
   - So sánh HH/HL trên bars gần nhất (hoặc dùng +DI/-DI từ ADX)
   - +DI > -DI → TREND_UP
   - -DI > +DI → TREND_DOWN
   - Else → TREND_NONE

2. GetRegimeScoreAdj(ENUM_RP_TYPE rp_type): double
   - Nếu Use_Regime_Filter == false → return 0
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

Extern inputs:
  extern int  UTC_Offset;
  extern bool Show_Session_Background;

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
   - utc_hour = (TimeCurrent() - UTC_Offset * 3600) → extract hour + minute
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
   - int dow = TimeDayOfWeek(TimeCurrent())
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

Extern inputs:
  extern int  Decay_Interval_Bars;
  extern int  Decay_Points_Per_Interval;
  extern int  Max_RP_Age_Bars;
  extern bool Use_Dynamic_Score;

GLOBALS: g_rp_array[], g_rp_count, g_decay_interval_bars, g_decay_points_per_interval, g_max_rp_age_bars

=== FUNCTIONS ===

1. CalcDecayPenalty(int rp_index): double
   - Nếu Use_Dynamic_Score == false → return 0
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

Extern inputs:
  extern bool Use_News_Filter;
  extern int  News_Blackout_Minutes;
  extern bool News_Filter_High_Only;

GLOBALS: g_news_blackout, g_news_available, g_news_status_text, g_news_status_color

=== LOGIC ===

1. UpdateNewsFilter():
   - Nếu Use_News_Filter == false → g_news_blackout = false; return
   - Dùng MQL5 Calendar API (MT5 build 2085+):

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values,
      TimeCurrent() - News_Blackout_Minutes*60,
      TimeCurrent() + News_Blackout_Minutes*60);

   - Lọc theo impact:
     CALENDAR_IMPACT_HIGH → luôn blackout
     CALENDAR_IMPACT_MEDIUM → blackout nếu News_Filter_High_Only == false
     CALENDAR_IMPACT_LOW → bỏ qua

   - Lọc theo currency: chỉ lấy news liên quan đến _Symbol
     GBPUSD → GBP news + USD news
     CADJPY → CAD news + JPY news
     (Extract base/quote currency từ _Symbol)

   - Nếu có tin trong window:
     g_news_blackout = true
     Tính thời gian còn lại/đã qua:
       Trước tin: g_news_status_text = "NFP in 12min", g_news_status_color = clrRed
       Sau tin: g_news_status_text = "CPI 8min ago", g_news_status_color = clrYellow
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

Extern inputs:
  extern bool   Use_Spread_Filter;
  extern double Spread_Alert_Multiplier;
  extern double Spread_Block_Multiplier;

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
   - Nếu Use_Spread_Filter == false → g_spread_blocked = false; g_spread_warning = false; return
   - g_current_spread_pips = GetCurrentSpreadPips()
   - Update rolling buffer → g_average_spread_pips = GetAverageSpread()

   - if cur > avg * Spread_Block_Multiplier (3.0):
       g_spread_blocked = true; g_spread_warning = false
       // Block entry, block alert cấp 2
   - elif cur > avg * Spread_Alert_Multiplier (2.0):
       g_spread_blocked = false; g_spread_warning = true
       // Score -10 tạm thời, entry vẫn hoạt động với warning
   - else:
       g_spread_blocked = false; g_spread_warning = false

Dashboard hiển thị: Normal=clrWhite, Warning=clrYellow, Blocked=clrRed
(Dùng GetSpreadColor() từ RP_Utils.mqh)
```

---
---

## PHASE 3: CORE LOGIC + MARKET STRUCTURE

---

## PROMPT 8: RP_Detection.mqh (Swing Detection, Candle, Momentum, Breakout)

```
Tạo file MQL5/Include/ReactionPoint/RP_Detection.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_DETECTION_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs:
  extern int    Swing_Lookback;
  extern int    Min_RP_Distance_Pips;
  extern int    Min_Reaction_Move_Pips;
  extern int    Initial_Bars_To_Scan;
  extern bool   Use_Adaptive_Reaction;
  extern double Reaction_ATR_Multiplier;
  extern int    Breakout_Confirm_Pips;
  extern int    Max_Retest_Bars;
  extern int    Min_Candle_Size_Pips;

GLOBALS: g_rp_array[], g_rp_count, g_next_rp_id
         g_swing_lookback, g_min_rp_distance_pips, g_min_reaction_move_pips
         g_initial_bars_to_scan, g_breakout_confirm_pips, g_max_retest_bars
         g_min_candle_size_pips, g_use_adaptive_reaction, g_reaction_atr_multiplier
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
   - day_of_week_formed = TimeDayOfWeek(iTime(_Symbol, PERIOD_CURRENT, bar_index))
   - candle_pattern = pattern
   - initial_reaction_pips = reaction_pips
   - is_active = true, is_fresh = true, test_count = 0
   - confluence_id = -1
   - display_opacity = opacity theo level (PREMIUM=80, L1=70, L2=50, L3=35)
   - Array overflow: nếu g_rp_count >= MAX_RP_COUNT → evict:
     1st: inactive RP
     2nd: lowest score non-confluence RP
     3rd: oldest RP

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
   - Dùng bar[1] close (closed bar, anti-repainting)

   Breakout check:
   - SUPPORT: close[1] < rp.zone_low - PipsToPrice(g_breakout_confirm_pips)
   - RESISTANCE: close[1] > rp.zone_high + PipsToPrice(g_breakout_confirm_pips)
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

Lưu ý quan trọng: Anti-repainting — tất cả logic chỉ dùng bar[1] trở về trước.
```

---

## PROMPT 9: RP_Scoring.mqh (Base Score + Final Score)

```
Tạo file MQL5/Include/ReactionPoint/RP_Scoring.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_SCORING_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs:
  extern int Fibo_Lookback_Bars;
  extern int Fibo_Tolerance_Pips;

GLOBALS: g_rp_array[], g_rp_count, SafeATR(), PriceToPips(), PipsToPrice()
         g_fibo_lookback_bars, g_fibo_tolerance_pips
         ClassifyRPLevel()

FILE NÀY GỌI EXTERN FUNCTIONS TỪ CÁC MODULE KHÁC:
  - GetRegimeScoreAdj(rp_type) — từ RP_RegimeFilter.mqh
  - CalcDecayPenalty(rp_index) — từ RP_DynamicDecay.mqh
  - CalcRecentBonus(rp_index) — từ RP_DynamicDecay.mqh
  - GetSessionScoreAdj(session) — từ RP_Session.mqh
  - GetDayOfWeekAdj() — từ RP_Session.mqh
  - GetStructureScoreAdj(rp_index) — từ RP_MarketStructure.mqh
  - GetLiquiditySweepBonus(rp_index) — từ RP_MarketStructure.mqh

=== 9.1 BASE SCORE (0-100) ===

1. CalcBaseScore(int rp_index): double
   Tính tổng 6 thành phần:

   a) Reaction Strength (max 25):
      score = min((rp.initial_reaction_pips / PriceToPips(SafeATR(14))) * 25, 25)

   b) Test Count (max 20):
      1 test → 5
      2 tests → 12
      3 tests → 20
      >3 tests → max(20 - (n-3)*5, 5)  // Diminishing returns, floor 5

   c) Candle Pattern (max 20):
      PINBAR=20, ENGULFING=15, OUTSIDE_BAR=12, LARGE_WICK=10, NONE=0

   d) Fibonacci Alignment (max 15):
      - Tìm Swing High/Low trong g_fibo_lookback_bars
      - Uptrend: retracement từ Low→High
      - Downtrend: retracement từ High→Low
      - Ranging: High→Low default
      - Check RP price vs Fibo levels (tolerance: g_fibo_tolerance_pips):
        61.8% → 15
        50.0% → 10
        38.2% → 7

   e) Volume (max 10):
      tick_volume[swing_bar] vs MA20 tick_volume:
      > MA20 * 1.5 → 10
      > MA20 * 1.2 → 5
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

   return tổng (capped tại 100)

=== 9.2 FINAL SCORE ===

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

## PROMPT 17: RP_MarketStructure.mqh (Module H — BOS, CHoCH, Liquidity Sweep)

```
Tạo file MQL5/Include/ReactionPoint/RP_MarketStructure.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_MARKETSTRUCTURE_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs:
  extern bool Use_Market_Structure;
  extern int  Structure_Lookback_Bars;   // default 50, số bars scan HH/HL/LL/LH

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - PipsToPrice(), PriceToPips()

THÊM GLOBALS MỚI:
  ENUM_STRUCTURE_STATE g_current_structure = STRUCTURE_NONE;
  bool                 g_choch_detected    = false;
  int                  g_last_bos_bar      = 0;
  int                  g_last_choch_bar    = 0;

ENUM MỚI (thêm vào RP_Defines.mqh):
  enum ENUM_STRUCTURE_STATE {
     STRUCTURE_BULLISH,    // HH + HL liên tục
     STRUCTURE_BEARISH,    // LL + LH liên tục
     STRUCTURE_NONE        // Chưa xác định
  };

THÊM FIELDS vào SReactionPoint (RP_Defines.mqh):
  bool has_liquidity_sweep;   // true nếu RP được hình thành sau sweep

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
   - Scan closed bars [1..Structure_Lookback_Bars]
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
   - Nếu Use_Market_Structure == false → return 0

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
---

## PHASE 4: ADVANCED MODULES

---

## PROMPT 10: RP_Confluence.mqh (Module D — Multi-TF Confluence)

```
Tạo file MQL5/Include/ReactionPoint/RP_Confluence.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_CONFLUENCE_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern input:
  extern bool Use_Confluence_Zones;

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - g_confluence_array[], g_confluence_count, g_next_confluence_id
  - g_htf_bars_to_scan, g_confluence_merge_pips
  - g_htf_1, g_htf_2 (ENUM_TIMEFRAMES)
  - PipsToPrice(), PriceToPips(), PipValue()

STRUCTS (RP_Defines.mqh):
  SReactionPoint — fields: is_confluence, confluence_id, final_score, ...
  SConfluenceZone — fields: rp_ids[] (DYNAMIC array), rp_count, multiplier, bonus, ...

CONSTANTS: MAX_CONFLUENCE=50, MAX_HTF_RETRIES=3, SCORE_CAP=150.0

=== LOGIC ===

1. CollectHTFReactionPoints():
   - Scan g_htf_1 và g_htf_2 cho swing points (giống DetectSwingPoints nhưng trên HTF)
   - Dùng iHigh/iLow/iClose/iOpen với timeframe parameter
   - Retry tối đa MAX_HTF_RETRIES nếu data chưa ready (Bars() < minimum)
   - Fallback: chỉ dùng current TF nếu HTF data fail

2. MergeClusterZones():
   - Reset confluence arrays (g_confluence_count = 0)
   - Gộp tất cả active RP (current TF + HTF)
   - 2 RP cách nhau <= g_confluence_merge_pips → merge vào 1 zone
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

3. ApplyConfluenceScoring():
   - Cho mỗi confluence zone, apply lên RP có highest score trong zone:
   - adjusted = rp.final_score * zone.multiplier + zone.bonus
   - rp.final_score = MathMin(adjusted, SCORE_CAP)
   - Re-classify RP level: rp.rp_level = ClassifyRPLevel(rp.final_score)

4. HandlePartialBreakout(int rp_id):
   - Khi 1 RP trong zone bị breakout → tách khỏi zone
   - rp.is_confluence = false, rp.confluence_id = -1
   - Giảm zone.rp_count, remove rp_id từ zone.rp_ids[]
   - Recalc multiplier/bonus:
     3→2: multiplier 1.5→1.3, bonus 25→10
     2→1: giải tán zone hoàn toàn
       - RP còn lại: is_confluence = false, confluence_id = -1
       - Remove zone từ g_confluence_array

Lưu ý:
- Confluence zone phải cập nhật khi RP mới được detect
- rp_ids[] là DYNAMIC array, dùng ArrayResize khi thêm/xóa
```

---

## PROMPT 11: RP_EntrySetup.mqh (Module C — Entry Setup)

```
Tạo file MQL5/Include/ReactionPoint/RP_EntrySetup.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_ENTRYSETUP_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern inputs:
  extern bool   Show_Entry_Setup;
  extern double Min_RR_Ratio;

GLOBALS TỪ RP_Utils.mqh:
  - g_rp_array[], g_rp_count
  - g_setup_array[], g_setup_count
  - g_current_regime, g_news_blackout, g_spread_blocked
  - g_sl_buffer_pips, g_entry_buffer_pips, g_max_setup_age_bars, g_min_score_to_show
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
     entry = iHigh(_Symbol, PERIOD_CURRENT, 1) + PipsToPrice(g_entry_buffer_pips)
     sl = iLow(_Symbol, PERIOD_CURRENT, 1) - PipsToPrice(g_sl_buffer_pips)
   - SELL (RP_RESISTANCE):
     entry = iLow(_Symbol, PERIOD_CURRENT, 1) - PipsToPrice(g_entry_buffer_pips)
     sl = iHigh(_Symbol, PERIOD_CURRENT, 1) + PipsToPrice(g_sl_buffer_pips)

   - TP1 = FindNearestRPInDirection(entry, direction, 0)
     Nếu TP1 == 0 hoặc R:R < Min_RR_Ratio → fallback: entry ± GetATR14()*2
   - TP2 = FindNearestRPInDirection(entry, direction, 1)
     Nếu TP2 == 0 → fallback: entry ± GetATR14()*4

   - sl_pips = PriceToPips(|entry - sl|)
   - tp1_pips = PriceToPips(|tp1 - entry|)
   - tp2_pips = PriceToPips(|tp2 - entry|)
   - rr_ratio1 = tp1_pips / sl_pips
   - rr_ratio2 = tp2_pips / sl_pips

   - Max đồng thời: MAX_SETUPS. Khi đầy → thay setup có score thấp nhất
   - 2 setup cùng hướng → tag "PREFERRED" cho score cao hơn
   - 2 setup ngược hướng → warning "Conflicting setups"

3. UpdateSetups():
   - Gọi mỗi tick
   - Tự ẩn (is_active=false) khi:
     a) Quá g_max_setup_age_bars bars kể từ bar_created
     b) SL bị phá (giá close[1] vượt sl_price) → is_invalidated = true
     c) Entry triggered (giá chạm entry_price) → is_triggered = true

4. FindNearestRPInDirection(double from_price, ENUM_RP_TYPE direction, int skip_count): double
   - Tìm RP active gần nhất theo hướng trade
   - BUY: tìm RP_RESISTANCE phía trên from_price
   - SELL: tìm RP_SUPPORT phía dưới from_price
   - skip_count: 0=gần nhất, 1=thứ 2
   - Return price hoặc 0 nếu không tìm thấy

Anti-repainting: chỉ dùng bar[1] đã đóng, KHÔNG BAO GIỜ bar[0]
```

---

## PROMPT 12: RP_Stats.mqh (Performance Tracker)

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

## PHASE 5: UI

---

## PROMPT 13: RP_Drawing.mqh (Zones, Labels, Session BG, Entry Panel)

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

GLOBALS: g_rp_array[], g_rp_count, g_confluence_array[], g_confluence_count
         g_setup_array[], g_setup_count, g_object_count
CONSTANTS: OBJECT_PREFIX="RP_", MAX_CHART_OBJECTS=250

=== COLOR SYSTEM (Spec Section 17.1) ===

Opacity theo level:
  PREMIUM=80%, L1=70%, L2=50%, L3=35%
  Confluence=50%, RoleRev=60%
  Entry BUY/SELL=25%
  SL=clrFireBrick 30%, TP1=clrKhaki 20%, TP2=clrDarkKhaki 20%

Decay visual: opacity giảm tuyến tính theo tuổi, floor 30%

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
   - 3 rectangle chồng:
     Outer: zone ± 2pip, opacity 14% (86% transparent)
     Middle: zone ± 1pip, opacity 30% (70% transparent)
     Core: zone gốc, opacity 50%
   - Color: Color_Confluence
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

7. DrawSessionBackgrounds(int visible_bars):
   - Vẽ nền session trên chart (OBJ_RECTANGLE)
   - Colors (8-10% opacity):
     Asian = LightCyan
     London = Lavender
     NY = LemonChiffon
     Overlap = MistyRose
     Dead = Gainsboro
   - Name prefix: OBJECT_PREFIX + "SESS_"

8. RedrawChangedRP():
   - Chỉ vẽ lại RP có score thay đổi so với lần draw trước
   - Lưu previous_score per RP để so sánh

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

## PROMPT 14: RP_Alerts.mqh (Alert System — 4 Levels)

```
Tạo file MQL5/Include/ReactionPoint/RP_Alerts.mqh cho Reaction Point Indicator v3.0.

Include guard: #ifndef RP_ALERTS_MQH / #define / #endif
Include: "RP_Utils.mqh"

Extern input:
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

=== FILTERS ===

- Session: nếu Alert_Only_Active_Sessions && session==DEAD → skip
- News blackout → KHÔNG trigger cấp 1-2
- Spread blocked → KHÔNG trigger cấp 2
- NGOẠI LỆ: Premium Confluence (score >=110) LUÔN alert kể cả Choppy/News

=== FUNCTIONS ===

1. CheckAllAlerts():
   - Gọi mỗi tick trong OnCalculate
   - Loop tất cả active RP
   - Cho mỗi RP, check 4 cấp alert theo thứ tự ưu tiên (4→3→2→1)
   - Apply filters ở trên

2. CheckProximityAlert(int rp_index): bool
   - distance = |SymbolInfoDouble(_Symbol, SYMBOL_BID) - rp.price|
   - Nếu PriceToPips(distance) <= g_proximity_alert_pips:
     Check hướng: so sánh close[1] vs close[2] → đang tiến về RP?
     SUPPORT: price đang giảm về RP (close[1] < close[2])
     RESISTANCE: price đang tăng về RP (close[1] > close[2])
   - Return true nếu cần alert VÀ alert_sent[0] == false

3. CheckReactionAlert(int rp_index): bool
   - Bar[1] đã đóng, close nằm trong zone, có pattern hợp lệ
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

7. ResetAlertIfDistant(int rp_index):
   - Khi PriceToPips(|giá - rp.price|) >= g_reset_alert_pips:
     Reset alert_sent[0..3] = false
   - Cho phép alert lại khi giá quay lại

Anti-spam: alert_sent[4] per RP. Mỗi zone chỉ 1 alert mỗi lần tiếp cận.
```

---

## PROMPT 15: RP_Dashboard.mqh (Dashboard UI)

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
   - Hiện: price, distance (pips), score
   - RES phía trên, SUP phía dưới

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

## PHASE 6: INTEGRATION

---

## PROMPT 16: RP_Main.mq5 (Main Indicator File)

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
   - Clamp tất cả input về range hợp lệ, Print warning nếu cần
   - Validate HTF hierarchy: HTF_1 > Period(), HTF_2 > HTF_1
   - Clamp Initial_Bars_To_Scan nếu > available bars

3. ArrayResize:
   ArrayResize(g_rp_array, MAX_RP_COUNT)
   ArrayResize(g_confluence_array, MAX_CONFLUENCE)
   ArrayResize(g_setup_array, MAX_SETUPS)

4. InitIndicatorHandles()
5. InitStats()
6. CreateDashboard()
7. EventSetTimer(1)  // Flash management
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
UpdateMarketStructure();

// Lần đầu scan full bars, sau đó chỉ scan ít bars gần nhất
static bool first_run = true;
int scan_bars = first_run ? g_initial_bars_to_scan : g_swing_lookback*2+5;
DetectSwingPoints(scan_bars);
first_run = false;

CheckBreakoutsAndRetests();
for(int i = 0; i < g_rp_count; i++)
   CalcFinalScore(i);
UpdateAllDecay();

if(Use_Confluence_Zones) {
   CollectHTFReactionPoints();
   MergeClusterZones();
   ApplyConfluenceScoring();
}
if(Show_Entry_Setup)
   CheckEntryConditions();

RedrawChangedRP();
if(Show_Session_Background)
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
- REASON_CHARTCHANGE / REASON_RECOMPILE / REASON_REMOVE → full reset

=== OnChartEvent(id, lparam, dparam, sparam) ===

- CHARTEVENT_CHART_CHANGE → RepositionDashboard() + UpdateFontSizes()

=== OnTimer() ===

- Flash management: toggle visibility cho RP đang flash
- Decrement flash_count, kill timer khi xong
- Max flash: MAX_FLASH_RP = 3

=== ERROR HANDLING (Spec Section 16) ===

- Division by zero: dùng SafeATR() everywhere
- HTF data: retry MAX_HTF_RETRIES lần, fallback current TF
- Array overflow: evict RP → inactive first → lowest score non-confluence → oldest
- Empty history: bars < Swing_Lookback*2+5 → warning, return
- Broker disconnect: gap > 5 bars → rescan all RP, reset alert cooldowns

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

PHASE 3 — Core Logic + Market Structure (tuần tự):
  P8:  RP_Detection.mqh     ← cần P1+P2
  P17: RP_MarketStructure.mqh (Module H — BOS/CHoCH/Sweep) ← cần P8
  P9:  RP_Scoring.mqh       ← cần P3+P4+P5+P17 (gọi extern functions)

PHASE 4 — Advanced Modules (cần Phase 2+3):
  P10: RP_Confluence.mqh    (Module D)
  P11: RP_EntrySetup.mqh    (Module C)
  P12: RP_Stats.mqh

PHASE 5 — UI (cần Phase 4):
  P13: RP_Drawing.mqh
  P14: RP_Alerts.mqh
  P15: RP_Dashboard.mqh     ← cần P12+P13

PHASE 6 — Integration:
  P16: RP_Main.mq5          ← LÀM CUỐI CÙNG, tổng hợp tất cả
```

Mỗi session, chỉ cần paste prompt tương ứng. Không cần đọc lại spec.
