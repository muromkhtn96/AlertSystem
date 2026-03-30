# REACTION POINT INDICATOR — FINAL SPEC
## MetaTrader 5 | MQL5 | Version 3.0

---

## 1. TỔNG QUAN

Indicator phát hiện và chấm điểm **Điểm Phản Ứng (RP)** trên Forex. Hoạt động trên mọi pair, tự detect pip value. Không repainting. Chart window, 0 buffers, 0 plots.

**13 files:** 1 main `.mq5` + 12 `.mqh` includes.

---

## 2. ENUMS & CONSTANTS

```mql5
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

#define MAX_RP_COUNT      200
#define MAX_CHART_OBJECTS  250
#define MAX_CONFLUENCE     50
#define MAX_SETUPS         10
#define MAX_FLASH_RP       3
#define MAX_HTF_RETRIES    3
#define OBJECT_PREFIX      "RP_"
#define SCORE_CAP          150.0
```

---

## 3. STRUCTS

```mql5
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
   int              confluence_id;       // -1 nếu không
   bool             alert_sent[4];
   datetime         alert_reset_time;
   bool             is_flashing;
   int              flash_count;
   double           display_opacity;
   int              day_of_week_formed;  // 0=Sun, 1=Mon...5=Fri
};

struct SConfluenceZone {
   int              id;
   double           zone_high, zone_low, center_price;
   int              rp_count;
   int              rp_ids[];
   ENUM_RP_TYPE     zone_type;           // Majority vote
   double           multiplier, bonus, final_score;
   string           tf_description;      // "H1+H4+D1"
   bool             is_premium;          // 4+ RP
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
};
```

---

## 4. INPUT PARAMETERS

```mql5
// === PRESET ===
input ENUM_TF_PRESET  TF_Preset = PRESET_AUTO;

// === SWING ===
input int    Swing_Lookback           = 3;      // [1–10]
input int    Min_RP_Distance_Pips     = 20;     // [5–100]
input int    Min_Reaction_Move_Pips   = 15;     // [5–100]
input int    Initial_Bars_To_Scan     = 500;    // [50–2000]
input bool   Use_Adaptive_Reaction    = true;   // true=dùng ATR×multiplier thay pip cố định
input double Reaction_ATR_Multiplier  = 0.5;    // Move ≥ 50% ATR = phản ứng thực

// === BREAKOUT ===
input int    Breakout_Confirm_Pips    = 5;      // [1–50]
input int    Max_Retest_Bars          = 50;     // [10–200]

// === REGIME (Module A) ===
input int    ADX_Period               = 14;
input double ADX_Strong_Threshold     = 25.0;
input double ADX_Weak_Threshold       = 20.0;
input bool   Use_Regime_Filter        = true;

// === DECAY (Module B) ===
input int    Decay_Interval_Bars      = 20;
input int    Decay_Points_Per_Interval= 2;
input int    Max_RP_Age_Bars          = 300;
input bool   Use_Dynamic_Score        = true;

// === ENTRY (Module C) ===
input bool   Show_Entry_Setup         = true;
input int    SL_Buffer_Pips           = 5;
input int    Entry_Buffer_Pips        = 2;
input double Min_RR_Ratio             = 1.5;
input int    Max_Setup_Age_Bars       = 10;

// === CONFLUENCE (Module D) ===
input int    Confluence_Merge_Pips    = 10;
input bool   Use_Confluence_Zones     = true;
input int    HTF_Bars_To_Scan         = 200;

// === SESSION (Module E) ===
input int    UTC_Offset               = 3;
input bool   Alert_Only_Active_Sessions = true;
input bool   Show_Session_Background  = true;

// === FIBONACCI ===
input int    Fibo_Lookback_Bars       = 100;
input int    Fibo_Tolerance_Pips      = 5;

// === CANDLE ===
input int    Min_Candle_Size_Pips     = 3;

// === NEWS FILTER (Module F) ===
input bool   Use_News_Filter          = true;
input int    News_Blackout_Minutes    = 30;     // Trước + sau tin High Impact
input bool   News_Filter_High_Only    = false;  // true=chỉ lọc High Impact

// === SPREAD FILTER (Module G) ===
input bool   Use_Spread_Filter        = true;
input double Spread_Alert_Multiplier  = 2.0;    // Warning khi spread > avg × N
input double Spread_Block_Multiplier  = 3.0;    // Block entry khi > avg × N

// === MULTI-TIMEFRAME ===
input bool             Show_HTF_1     = true;
input ENUM_TIMEFRAMES  HTF_1          = PERIOD_H4;
input bool             Show_HTF_2     = true;
input ENUM_TIMEFRAMES  HTF_2          = PERIOD_D1;

// === DISPLAY ===
input int              Zone_Width_Pips          = 4;
input int              Min_Score_To_Show        = 40;
input bool             Show_Dashboard           = true;
input bool             Show_Performance_Stats   = true;
input int              Proximity_Alert_Pips     = 20;
input int              Reset_Alert_Pips         = 30;
input ENUM_DASH_CORNER Dashboard_Corner         = DASH_TOP_LEFT;
input int              Dashboard_Font_Size      = 9;
input int              Label_Font_Size          = 8;

// === COLORS ===
input color  Color_Premium       = clrGold;
input color  Color_Level1        = clrCrimson;
input color  Color_Level2        = clrOrange;
input color  Color_Level3        = clrSkyBlue;
input color  Color_Confluence    = clrMediumPurple;
input color  Color_RoleReversal  = clrMagenta;
input color  Color_EntryBuy      = clrLimeGreen;
input color  Color_EntrySell     = clrRed;
```

---

## 5. TF PRESET TABLE

Khi `TF_Preset != PRESET_CUSTOM`, override các input tương ứng. Params không trong bảng (colors, booleans, ADX, UTC) giữ nguyên input gốc.

`PRESET_AUTO`: detect `Period()` → áp preset phù hợp (≤M30→M30, ≤H1→H1, ≤H4→H4, else→D1).

```
Param                    M30    H1    H4     D1
─────────────────────────────────────────────────
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
HTF_1 (auto)             H1     H4    D1     W1
HTF_2 (auto)             H4     D1    W1    MN1
```

---

## 6. RP DETECTION LOGIC (File: RP_Detection.mqh)

### 6.1 Swing Detection

- Swing High bar[i]: `high[i] > high[i±1..N]` cho cả trái và phải
- Swing Low: ngược lại
- Chỉ confirm trên closed bars: `i ≥ Swing_Lookback + 1` (không bao giờ bar[0])
- Khoảng cách tối thiểu giữa 2 RP: `Min_RP_Distance_Pips`

### 6.2 Candle Pattern (tại swing bar)

Check theo thứ tự, dừng khi match. Range = high−low.

| Pattern | Điều kiện | Score |
|---|---|---|
| Size filter | range < Min_Candle_Size_Pips → NONE, dừng | 0 |
| Doji | \|open−close\| < range×0.10 → NONE, dừng | 0 |
| Pinbar | 1 wick ≥ 60% range, body ≤ 25% range, body ở 1/3 đối diện | 20 |
| Engulfing | Body[i] bao trùm body[i+1], khác hướng, body[i] ≥ 1.5×body[i+1] | 15 |
| Outside Bar | high[i]>high[i+1] AND low[i]<low[i+1], không phải Engulfing | 12 |
| Large Wick | 1 wick ≥ 40% range, close ngược hướng wick | 10 |

### 6.3 Momentum Confirmation

```
Nếu Use_Adaptive_Reaction:
  min_move = ATR(14) × Reaction_ATR_Multiplier
Ngược lại:
  min_move = PipsToPrice(Min_Reaction_Move_Pips)

Sau khi swing hình thành, giá phải di chuyển ≥ min_move
(tính trên closed bars) trước khi quay lại → RP confirmed.
Nếu không đủ momentum → KHÔNG tạo RP.
```

### 6.4 Role Reversal

```
1. Nến ĐÓNG CỬA vượt RP ≥ Breakout_Confirm_Pips (closed bar only)
2. Giá retest về zone trong Max_Retest_Bars
→ Flip type: SUPPORT ↔ RESISTANCE
→ +15 điểm vào final score
→ Đổi màu → Color_RoleReversal
→ Nếu RP trong confluence → tách, re-check confluence với type mới
→ Alert cấp 3
```

### 6.5 Gap qua RP

```
Close vượt RP ≥ Breakout_Confirm_Pips mà không touch zone:
→ Tính breakout (gap = breakout mạnh), kích hoạt Role Reversal logic
→ KHÔNG tính "test", KHÔNG trigger proximity alert
```

---

## 7. SCORING (File: RP_Scoring.mqh)

### 7.1 Base Score (0–100)

| Tiêu chí | Max | Logic |
|---|---|---|
| Reaction strength | 25 | `min((pip_move / SafeATR(14)) × 25, 25)` |
| Test count | 20 | 1→5, 2→12, 3→20, >3→`max(20-(n-3)×5, 5)` |
| Candle pattern | 20 | Pinbar=20, Engulf=15, Outside=12, Wick=10 |
| Fibonacci | 15 | 61.8%=15, 50%=10, 38.2%=7 (tolerance: Fibo_Tolerance_Pips) |
| Volume | 10 | tick_vol > MA20_vol×1.5 → 10, >1.2 → 5 |
| Round number | 10 | RP cách x.x000/x.x500 ≤10pip→10, ≤20pip→5 |

**Fibonacci:** Swing High/Low trong Fibo_Lookback_Bars. Uptrend: Low→High retracement. Downtrend: High→Low. Ranging: High→Low default.

**Volume delta bonus:** Tại RP Support, buying_vol > selling_vol×1.3 → +5đ. Ngược lại −5đ. (Proxy: close>open = buying, close<open = selling.)

**First Touch bonus:** `test_count == 0 AND giá tiếp cận` → +10đ, tag "FRESH".

**SafeATR:** `ATR ≤ 0 → fallback PipsToPrice(10)`.

### 7.2 Final Score Formula

```mql5
double adjusted = base_score
   + regime_adj          // Module A: [−30, +20]
   - decay_penalty       // Module B: [0, −35+]
   + recent_bonus        // Module B: [0, +15]
   + session_adj         // Module E: [−20, +15]
   + day_of_week_adj     // [−10, +5]
   + role_rev_bonus      // 0 hoặc +15
   + first_touch_bonus;  // 0 hoặc +10

adjusted = MathMax(adjusted, 0.0);

double final_score = adjusted * conf_multiplier + conf_bonus; // Module D
final_score = MathMin(final_score, SCORE_CAP);

// Phân loại:
// ≥110 PREMIUM | 80–109 LEVEL1 | 60–79 LEVEL2 | 40–59 LEVEL3 | <40 HIDDEN
```

---

## 8. MODULE A — MARKET REGIME (File: RP_RegimeFilter.mqh)

```
ADX > 25 → STRONG_TREND (HH+HL trên HTF → UP/DOWN)
ADX 20–25 → WEAK_TREND
ADX < 20 + ATR < ATR_avg50 × 0.7 → CHOPPY
ADX < 20 + ATR bình thường → RANGING
```

**Score adjustment:**

| Regime | RP cùng chiều | RP ngược chiều | RP ranging |
|---|---|---|---|
| Strong Trend | +20 | −30 | — |
| Weak Trend | +10 | −15 | — |
| Ranging | — | — | +15 |
| Choppy | −20 tất cả | −20 tất cả | −20 tất cả |

**Mapping chiều:** Uptrend+Support = cùng, Uptrend+Resistance = ngược. Downtrend ngược lại.

**Choppy:** ẩn entry setup, không alert cấp 1–2, RP mờ 50%. Dashboard: "CHOPPY — Avoid trading". Ngoại lệ: Premium Confluence (≥110) VẪN alert.

---

## 9. MODULE B — DYNAMIC DECAY (File: RP_DynamicDecay.mqh)

```
decay_penalty = (bars_since_last_event / Decay_Interval) × Decay_Points
if bars_since_formed > Max_RP_Age → thêm −10
if bars_since_formed > 2×Max_RP_Age AND score < 80 → ẩn RP

recent_bonus (CHỈ closed bars [1..N], KHÔNG bar[0]):
  Phản ứng (nến xác nhận) trong bars[1..5] → +15
  Test không phá trong bars[1..10] → +8
```

---

## 10. MODULE C — ENTRY SETUP (File: RP_EntrySetup.mqh)

**Trigger:** Giá trong zone + bar[1] là pattern hợp lệ + score ≥ Min_Score_To_Show + regime ≠ Choppy + spread ≤ block threshold + không trong news blackout.

```
BUY:  entry = high[1] + Entry_Buffer, SL = low[1] − SL_Buffer
SELL: entry = low[1] − Entry_Buffer, SL = high[1] + SL_Buffer

TP1 = RP gần nhất phía trước (R:R ≥ Min_RR_Ratio), fallback ATR×2
TP2 = RP thứ 2, fallback ATR×4

Tự ẩn sau Max_Setup_Age_Bars hoặc khi SL bị phá hoặc khi entry triggered.
Max đồng thời: MAX_SETUPS (10). Khi đầy → thay setup score thấp nhất.
2 setup cùng hướng → highlight score cao nhất ("PREFERRED").
2 setup ngược hướng → warning "Conflicting setups".
```

---

## 11. MODULE D — CONFLUENCE (File: RP_Confluence.mqh)

```
Gộp RP từ current TF + HTF_1 + HTF_2.
2 RP cách ≤ Confluence_Merge_Pips → merge.
Zone = range bao trùm, score = highest_score trong group.

2 RP: ×1.3 + 10 bonus
3 RP: ×1.5 + 25 bonus
4+RP: ×1.8 + 40 bonus → PREMIUM ZONE

Partial breakout: RP bị phá → tách khỏi zone, giảm multiplier.
3→2: mult 1.5→1.3, bonus 25→10. Còn 1 RP → giải tán zone.
```

---

## 12. MODULE E — SESSION (File: RP_Session.mqh)

**Định nghĩa (UTC):** Asian 00–07, London Open 07–08:30, London 07–16, NY Open 13–14:30, NY 13–22, Overlap 13–16, Dead 22–00.

**Ưu tiên:** Overlap > London Open > NY Open > London > NY > Asian > Dead.

**UTC convert:** `utc_time = TimeCurrent() − UTC_Offset × 3600`

| Phiên | Score adj |
|---|---|
| Overlap | +15 |
| London/NY Open | +10 |
| London/NY Session | +5 |
| Asian | −10 |
| Dead Zone | −20 |

**Day-of-Week adjustment:**

| Ngày | Adj | Lý do |
|---|---|---|
| Monday | −5 | Institutional chờ, range nhỏ |
| Tue–Thu | 0 | Baseline |
| Thursday | +5 | Continuation, test lại mạnh |
| Friday <15h UTC | 0 | — |
| Friday ≥15h UTC | −10 | Profit-taking, false moves |

---

## 13. MODULE F — NEWS FILTER (File: RP_NewsFilter.mqh)

```mql5
// Dùng MQL5 Calendar API (MT5 build 2085+)
MqlCalendarValue values[];
int count = CalendarValueHistory(values,
   TimeCurrent() - News_Blackout_Minutes*60,
   TimeCurrent() + News_Blackout_Minutes*60);

// Lọc theo impact:
// CALENDAR_IMPACT_HIGH   → luôn blackout
// CALENDAR_IMPACT_MEDIUM → blackout nếu News_Filter_High_Only==false
// CALENDAR_IMPACT_LOW    → bỏ qua

// Lọc theo country: chỉ lấy currency liên quan đến _Symbol
// GBPUSD → GBP news + USD news
// CADJPY → CAD news + JPY news
```

**Khi trong blackout period:**
- `g_news_blackout = true`
- Dashboard: "NEWS: NFP in 12min" (đỏ) hoặc "NEWS: CPI 8min ago" (vàng)
- KHÔNG trigger alert cấp 1–2
- KHÔNG kích hoạt entry setup
- RP zones vẫn hiển thị, thêm label "PAUSED"
- Score tạm −15 cho tất cả RP (chỉ hiển thị, không lưu vĩnh viễn)

**30 phút SAU tin:** rescan tất cả active RP (breakout check), resume alerts.

**Medium Impact:** chỉ warning dashboard, score −10 tạm thời, KHÔNG block entry.

**Fallback khi Calendar API fail:** `g_news_available = false`, Dashboard hiện "NEWS: unavailable", bỏ qua filter.

---

## 14. MODULE G — SPREAD FILTER (File: RP_SpreadFilter.mqh)

```mql5
double GetCurrentSpreadPips() {
   return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / PipValue();
}

// Cache average spread (rolling 100 ticks)
static double spread_buffer[100];
static int spread_idx = 0;
// Update mỗi tick: spread_buffer[spread_idx++ % 100] = current_spread;
// avg = sum / min(count, 100)

double avg_spread = GetAverageSpread();
double cur_spread = GetCurrentSpreadPips();

if(cur_spread > avg_spread * Spread_Block_Multiplier) {
   g_spread_blocked = true;
   // Block entry, block alert cấp 2
}
else if(cur_spread > avg_spread * Spread_Alert_Multiplier) {
   g_spread_warning = true;
   // Score −10 tạm thời, entry vẫn hoạt động với warning
}
```

**Dashboard:** Spread luôn hiển thị. Normal=trắng, ×2=vàng, ×3+=đỏ.

---

## 15. PERFORMANCE TRACKER (File: RP_Stats.mqh)

**Logic tracking (trên closed bars):**

```
Khi RP mới confirmed → stats.total_formed++, stats.[level]_formed++
Khi giá phản ứng ≥ min_move tại RP → stats.total_reacted++, stats.[level]_reacted++
Khi RP bị breakout confirmed → stats.total_broken++

Hit rate = reacted / (reacted + broken)
```

**Dashboard section (khi Show_Performance_Stats=true):**
```
PERFORMANCE (since [date])
  Hit Rate: 67% (42/63)
  Premium: 78% (7/9) | Lv1: 64% (18/28)
  Best: London Open 74% | Worst: Asian 41%
```

**Không lưu file.** Reset khi indicator reload. Chỉ track bars đã chạy.

---

## 16. ERROR HANDLING

### OnInit validation

Clamp tất cả input về range hợp lệ. Print warning nếu phải clamp. Validate HTF hierarchy (HTF_1 > Period(), HTF_2 > HTF_1). Clamp `Initial_Bars_To_Scan` nếu > available bars.

### Runtime safety

```mql5
// Division by zero
double SafeATR(int period, int shift) {
   double atr = CalcATR(period, shift);
   return (atr > 0 && atr == atr) ? atr : PipsToPrice(10);
}

// HTF data: retry MAX_HTF_RETRIES lần, fallback dùng current TF only
// Array overflow: evict RP → inactive first → lowest score non-confluence → oldest
// Empty history: if bars < Swing_Lookback*2+5 → warning, return
// Broker disconnect: gap > 5 bars → rescan all RP, reset alert cooldowns
```

### OnDeinit

```mql5
// REASON_CHARTCHANGE / REASON_RECOMPILE / REASON_REMOVE → full reset
// REASON_PARAMETERS → xóa objects, giữ RP data, recalculate
// Luôn: EventKillTimer() + ObjectsDeleteAll(0, OBJECT_PREFIX)
```

---

## 17. UI DESIGN

### 17.1 Color System

```
PREMIUM:     clrGold         80% opacity
Cấp 1:      clrCrimson       70%
Cấp 2:      clrOrange        50%
Cấp 3:      clrSkyBlue       35%
Confluence:  clrMediumPurple  50%
Role Rev:    clrMagenta       60%
Entry BUY:   clrLimeGreen     25%
Entry SELL:  clrRed           25%
SL zone:     clrFireBrick     30%
TP1:         clrKhaki         20%
TP2:         clrDarkKhaki     20%
Session BG:  8–10% opacity (Lavender/MistyRose/LightCyan/LemonChiffon/Gainsboro)
Dashboard:   Nền C'20,25,32' 90%, border C'60,65,75', text White/DarkGray/Lime/Tomato
```

**Decay visual:** opacity giảm tuyến tính theo tuổi, floor 30%.

### 17.2 RP Zone

```mql5
OBJ_RECTANGLE, FILL=true, BACK=true, SELECTABLE=false
Kéo từ time_formed đến TimeCurrent()+PeriodSeconds()*20
Border: STYLE_SOLID (Cấp 1+Premium), STYLE_DOT (Cấp 2–3)
```

**Pseudo-glow (Confluence 3+ RP):** 3 rectangle chồng: outer (+2pip, 86% transparent), middle (+1pip, 70%), core (50%).

### 17.3 RP Label (2 dòng)

```
Dòng 1: [icon] [score] [████░░░░] [TYPE]
Dòng 2: [TF] | Tested:[n]x | [session] | [status]

Ví dụ:
  ⭐ 124 ████████████░ CONFLUENCE
    H1+H4+D1 | Tested:3x | London | Fresh

  🔴 87 ████████░░ RESISTANCE
    H1 | Tested:2x | NY Open | Decay:−6
```

Resistance: label phía trên zone. Support: phía dưới. Chống chồng: offset 20px nếu quá gần.

### 17.4 Entry Setup Panel (trên chart)

```
┌─────────────────────────────┐
│  SELL SETUP  Score: 87 🔴   │
│  Entry: 1.2752              │
│  SL:    1.2770  (18 pip)    │
│  TP1:   1.2709  (43 pip)    │
│  TP2:   1.2620  (132 pip)   │
│  R:R₁ = 1:2.4  R:R₂ = 1:7.3│
│  Expires in 7 bars          │
└─────────────────────────────┘
```

Nền: `C'30,15,15'` (SELL) / `C'15,30,15'` (BUY), 85% opacity.

### 17.5 Dashboard Layout

```
╔══════════════════════════════════════════════════╗
║  REACTION POINT v3.0           Preset: H4 ✓     ║
║  GBPUSD  │  H4  │  🟢 London-NY Overlap         ║
╠══════════════════════════════════════════════════╣
║  REGIME   🔴 STRONG DOWNTREND    ADX: 32.4       ║
║  BIAS     ▼ SELL preferred                       ║
║  ATR: 42p  │  Spread: 1.2p  │  NEWS: clear 🟢   ║
╠══════════════════════════════════════════════════╣
║  ▲ RES  1.2750  Score:87 🔴  23p  ⭐Conf  Fresh  ║
║  ▼ SUP  1.2620  Score:65 🟠  41p  Decay:−12      ║
╠══════════════════════════════════════════════════╣
║  RADAR  (top 5 nearest)                          ║
║  1.2750 ▼23p 🔴87  │ 1.2620 ▲41p 🟠65           ║
║  1.2800 ▼73p 🔵52  │ 1.2580 ▲81p 🟠71           ║
║  1.2850 ▼98p 🔵48  │                             ║
╠══════════════════════════════════════════════════╣
║  Zones:8  Conf:2  RevR:1  Setups:1  Obj:142/250 ║
║  HTF: ✓D1 ✓W1  │  Hit Rate: 67% (42/63)         ║
╠══════════════════════════════════════════════════╣
║  ⚠ SELL@1.2752  SL:18p  TP1:43p  R:R=1:2.4      ║
╚══════════════════════════════════════════════════╝

Sections ẩn/hiện theo context:
- Entry Setup line: chỉ khi có active setup
- NEWS: "clear 🟢" / "⚠NFP 12min 🔴" / "unavailable ⚪"
- Spread: đổi màu khi bất thường
- CHOPPY → toàn bộ regime section nền đỏ
- Hit Rate: chỉ khi Show_Performance_Stats=true
```

**Font scaling:** detect `CHART_SCALE` → adjust font ±2. Min font 6.

---

## 18. ALERT SYSTEM (File: RP_Alerts.mqh)

Check trong `OnCalculate()` mỗi tick. Session filter + News filter + Spread filter áp dụng.

| Cấp | Trigger | Format |
|---|---|---|
| 1 | Giá cách RP ≤ Proximity_Alert_Pips, đang đi VỀ PHÍA RP | `"⚠ Approaching [PAIR] [TF] | [price] | Score:[n] | Dist:[n]p"` |
| 2 | Bar[1] đóng = pattern hợp lệ tại RP zone | `"🎯 RP REACTION [PAIR] [TF] | [pattern]@[price] | Score:[n] | R:R=[n]"` |
| 3 | Role Reversal confirmed | `"⚡ ROLE REVERSAL [PAIR] [TF] | [price] → [new_type] | Score:[n]"` |
| 4 | Confluence Premium (score ≥110) | `"⭐ PREMIUM [PAIR] | [range] | Score:[n] | [n]TF aligned"` |

**Anti-spam:** alert_sent[4] per RP. Reset khi giá rời ≥ Reset_Alert_Pips. Mỗi zone 1 alert/tiếp cận.

---

## 19. FILE ARCHITECTURE

```
MQL5/Indicators/ReactionPoint/RP_Main.mq5
MQL5/Include/ReactionPoint/
  ├── RP_Defines.mqh       → Mục 2+3 (enums, structs, constants)
  ├── RP_Utils.mqh          → PipValue, PipsToPrice, SafeATR, IsNewBar, TimeToSession
  ├── RP_Detection.mqh      → Mục 6 (swing, pattern, momentum, breakout, role reversal)
  ├── RP_Scoring.mqh        → Mục 7 (base score, final score formula)
  ├── RP_RegimeFilter.mqh   → Mục 8 (ADX, trend direction, regime classification)
  ├── RP_DynamicDecay.mqh   → Mục 9 (decay, age penalty, recent bonus)
  ├── RP_EntrySetup.mqh     → Mục 10 (entry/SL/TP calc, draw, invalidate)
  ├── RP_Confluence.mqh     → Mục 11 (collect, merge, score, partial breakout)
  ├── RP_Session.mqh        → Mục 12 (session detect, weight, day-of-week, background)
  ├── RP_NewsFilter.mqh     → Mục 13 (calendar API, blackout logic)
  ├── RP_SpreadFilter.mqh   → Mục 14 (spread monitoring, block/warning)
  ├── RP_Drawing.mqh        → Mục 17.1–17.3 (zones, labels, glow, objects)
  ├── RP_Dashboard.mqh      → Mục 17.4–17.5 (dashboard, entry panel, font scaling)
  ├── RP_Alerts.mqh         → Mục 18 (4 cấp alert, anti-spam)
  └── RP_Stats.mqh          → Mục 15 (performance tracking)
```

**Include guards:** `#ifndef RP_XXX_MQH / #define / #endif`

**Dependency flow:**
```
Defines ← Utils ← Detection, RegimeFilter, Session, SpreadFilter, NewsFilter
Scoring ← Defines + RegimeFilter + DynamicDecay + Session
Confluence ← Defines + Utils
EntrySetup ← Defines + Utils + Drawing
Drawing ← Defines
Dashboard ← Defines + Drawing + Stats
Alerts ← Defines + Session + NewsFilter + SpreadFilter
Main ← tất cả
```

---

## 20. MAIN FILE FLOW (RP_Main.mq5)

```mql5
OnInit():
  ApplyTFPreset() → ValidateInputs() → ArrayResize() → return INIT_SUCCEEDED

OnCalculate():
  // MỖI TICK:
  CheckAllAlerts()
  UpdateSetups()        // Check invalidation
  UpdateSpreadFilter()  // Update rolling average

  // MỖI NẾN MỚI (IsNewBar()):
  UpdateNewsFilter()    // Check calendar
  DetectSwingPoints()   // Scan new bars
  for(tất cả active RP):
     CalcFinalScore()   // Gọi module A+B+E+F+G
  UpdateAllDecay()
  MergeClusterZones()   // Module D
  CheckEntryConditions()
  RedrawChangedRP()     // Chỉ vẽ lại RP có score thay đổi
  UpdateDashboard()
  EnforceObjectLimit()
  UpdateStats()
  return rates_total

OnDeinit(reason):
  EventKillTimer() → DeleteAllObjects() → ResetIfNeeded(reason)

OnChartEvent(id):
  CHARTEVENT_CHART_CHANGE → RepositionDashboard() + UpdateFontSizes()

OnTimer():
  Flash management (toggle visibility, decrement count, kill timer khi xong)
```

---

## 21. EDGE CASES

| Case | Xử lý |
|---|---|
| RP trùng giá khác type | Giữ cả 2, không gộp confluence (khác type) |
| Gap qua RP | Tính breakout, không tính test/touch |
| Doji tại RP | PATTERN_NONE, đợi nến tiếp |
| ATR = 0 | SafeATR fallback 10 pip |
| HTF data chưa ready | Retry 3 lần, fallback current TF only |
| Array đầy | Evict: inactive → lowest score non-confluence → oldest |
| Broker disconnect (gap>5 bars) | Rescan all RP, reset alert cooldowns |
| Confluence partial breakout | Tách RP bị phá, giảm multiplier, giải tán nếu còn 1 |
| Calendar API fail | `g_news_available=false`, bỏ qua filter |
| 2 setup ngược hướng | Hiện cả 2 + warning "Conflicting" |

---

## 22. ANTI-REPAINTING RULES

```
1. RP chỉ confirm trên bar ≥ Swing_Lookback+1 (KHÔNG BAO GIỜ bar[0])
2. Entry Setup chỉ trigger trên bar[1] đã đóng
3. Recent Bonus chỉ dùng bars[1..N]
4. Score thay đổi → chỉ đổi màu/opacity, KHÔNG dịch chuyển vị trí RP
5. Comment trong code: // Anti-repainting: confirmed on closed bars only
```
