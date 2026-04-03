//+------------------------------------------------------------------+
//|                                                    RP_Utils.mqh  |
//|                        Reaction Point Indicator v3.0              |
//|                        Globals & Utility Functions                |
//+------------------------------------------------------------------+
#ifndef RP_UTILS_MQH
#define RP_UTILS_MQH

#include "RP_Defines.mqh"

//+------------------------------------------------------------------+
//| Global Variables — RP Data                                       |
//+------------------------------------------------------------------+
SReactionPoint g_rp_array[];
int            g_rp_count    = 0;
int            g_next_rp_id  = 0;

SConfluenceZone g_confluence_array[];
int             g_confluence_count    = 0;
int             g_next_confluence_id  = 0;

SEntrySetup    g_setup_array[];
int            g_setup_count = 0;

SRPStats       g_stats;

//+------------------------------------------------------------------+
//| Global Variables — Market State                                  |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME   g_current_regime    = REGIME_RANGING;
ENUM_TREND_DIR       g_current_trend     = TREND_NONE;
double               g_current_adx       = 0.0;
ENUM_SESSION         g_current_session   = SESSION_DEAD;

// Market Structure (Module H)
ENUM_STRUCTURE_STATE g_current_structure = STRUCTURE_NONE;
bool                 g_choch_detected    = false;
int                  g_last_bos_bar      = 0;
int                  g_last_choch_bar    = 0;

//+------------------------------------------------------------------+
//| Global Variables — Filters                                       |
//+------------------------------------------------------------------+
bool           g_news_blackout       = false;
bool           g_news_available      = true;
string         g_news_status_text    = "clear";
color          g_news_status_color   = clrLime;
bool           g_spread_blocked      = false;
bool           g_spread_warning      = false;
double         g_current_spread_pips = 0.0;
double         g_average_spread_pips = 0.0;

//+------------------------------------------------------------------+
//| Global Variables — Display & Handles                             |
//+------------------------------------------------------------------+
int            g_object_count   = 0;
int            g_handle_adx     = INVALID_HANDLE;
int            g_handle_atr     = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Global Variables — Input-derived (set by ApplyTFPreset in Main)  |
//+------------------------------------------------------------------+
int    g_swing_lookback           = 3;
int    g_min_rp_distance_pips     = 20;
int    g_min_reaction_move_pips   = 15;
int    g_initial_bars_to_scan     = 500;
int    g_breakout_confirm_pips    = 5;
int    g_max_retest_bars          = 50;
int    g_decay_interval_bars      = 20;
int    g_decay_points_per_interval= 2;
int    g_max_rp_age_bars          = 300;
int    g_sl_buffer_pips           = 5;
int    g_entry_buffer_pips        = 2;
int    g_max_setup_age_bars       = 10;
int    g_confluence_merge_pips    = 10;
int    g_htf_bars_to_scan         = 200;
int    g_fibo_lookback_bars       = 100;
int    g_fibo_tolerance_pips      = 5;
int    g_min_candle_size_pips     = 3;
int    g_zone_width_pips          = 4;
int    g_min_score_to_show        = 40;
ENUM_RP_LEVEL g_show_min_level    = RP_PREMIUM;  // Backward compat — computed from toggles
bool   g_show_premium             = true;         // Show Premium zones
bool   g_show_level1              = false;        // Show Level 1 zones
bool   g_show_level2              = false;        // Show Level 2 zones
bool   g_show_level3              = false;        // Show Level 3 zones
bool   g_enable_system_alert       = false;
bool   g_enable_push_notify       = false;
int    g_proximity_alert_pips     = 20;
int    g_reset_alert_pips         = 30;
ENUM_TIMEFRAMES g_htf_1           = PERIOD_H4;
ENUM_TIMEFRAMES g_htf_2           = PERIOD_D1;
double g_reaction_atr_multiplier  = 0.5;
bool   g_use_adaptive_reaction    = true;

//+------------------------------------------------------------------+
//| Global Variables — Module toggles (from inputs via Main)         |
//+------------------------------------------------------------------+
// Module A — Regime
int    g_adx_period              = 14;
double g_adx_strong_threshold    = 25.0;
double g_adx_weak_threshold      = 20.0;
bool   g_use_regime_filter       = true;

// Module B — Decay
bool   g_use_dynamic_score       = true;

// Module C — Entry
bool   g_show_entry_setup        = true;
double g_min_rr_ratio            = 1.5;

// Module D — Confluence
bool   g_use_confluence_zones    = true;

// Module E — Session
int    g_utc_offset              = 3;
bool   g_show_session_background = true;

// Module F — News
bool   g_use_news_filter         = true;
int    g_news_blackout_minutes   = 30;
bool   g_news_filter_high_only   = false;

// Module G — Spread
bool   g_use_spread_filter       = true;
double g_spread_alert_multiplier = 2.0;
double g_spread_block_multiplier = 3.0;

// Module H — Market Structure
bool   g_use_market_structure    = true;
int    g_structure_lookback_bars = 50;

// Clean Chart Mode
bool   g_clean_chart_mode           = true;

// Pair detection (P22)
bool   g_is_jpy_pair   = false;
bool   g_is_gbp_pair   = false;
bool   g_is_cross_pair = false;

// Alerts
bool   g_alert_only_active_sessions = true;

// Display / UI
bool             g_show_dashboard         = true;
bool             g_show_performance_stats  = true;
ENUM_DASH_CORNER g_dashboard_corner       = DASH_TOP_LEFT;
int              g_dashboard_font_size    = 9;
bool             g_show_htf_1             = true;
bool             g_show_htf_2             = true;
int              g_label_font_size        = 8;

// Colors
// P28: Color palette — visible on dark backgrounds, type-differentiated
color  g_color_premium       = C'255,210,80';    // Gold accent — only for confluence/special
color  g_color_level1        = C'180,180,180';   // Neutral gray
color  g_color_level2        = C'140,140,140';   // Dim gray
color  g_color_level3        = C'110,110,110';   // Faint gray
color  g_color_confluence    = C'200,180,80';    // Muted gold — confluence accent
color  g_color_role_reversal = C'180,140,60';    // Warm amber — reversal accent
color  g_color_entry_buy     = C'60,200,120';    // Mint green
color  g_color_entry_sell    = C'220,70,70';     // Soft red
color  g_color_support       = C'50,160,220';    // Clean blue — demand zones
color  g_color_resistance    = C'220,80,80';     // Clean red — supply zones

//+------------------------------------------------------------------+
//| Global Variables — Performance Cache                             |
//+------------------------------------------------------------------+
double g_cached_atr14         = 0.0;
double g_cached_atr14_smooth  = 0.0;  // EMA-smoothed ATR14 for scoring (spike-resistant)
double g_cached_atr14_ma50    = 0.0;
double g_cached_volume_ma20   = 0.0;
int    g_cached_bar_index     = -1;

// Fibo cache (backward compatible — populated from best fibo leg)
double g_cached_fibo_high     = 0.0;
double g_cached_fibo_low      = 0.0;
double g_cached_fibo_786      = 0.0;
double g_cached_fibo_618      = 0.0;
double g_cached_fibo_500      = 0.0;
double g_cached_fibo_382      = 0.0;

// Fibo swing-to-swing legs (Phase 7 — P19)
SFiboLeg g_fibo_legs[];       // ArrayResize(MAX_FIBO_LEGS) in OnInit
int      g_fibo_leg_count     = 0;

// HTF trend alignment (Phase 7 — P20)
SHTFTrend g_htf_trends[3];    // [0]=current TF, [1]=HTF_1, [2]=HTF_2
bool      g_use_trend_alignment = true;

// RP ID → array index map for O(1) lookup (replaces O(N) linear scan)
#define MAX_RP_ID_MAP 500
int    g_rp_id_to_index[];   // ArrayResize(MAX_RP_ID_MAP) in OnInit, init to -1

// Dirty flags
bool   g_rp_dirty[];
int    g_last_calc_bar[];

// HTF cache
bool   g_htf1_cache_valid     = false;
bool   g_htf2_cache_valid     = false;
int    g_htf1_cached_swing_count = 0;
int    g_htf2_cached_swing_count = 0;

// Confluence update flag
bool   g_confluence_needs_update = false;
bool   g_confluence_needs_redraw = false;

// Alert throttle
double g_last_alert_check_price = 0.0;

//+------------------------------------------------------------------+
//| Anti-repainting access wrappers                                  |
//| All modules MUST use these instead of raw iClose/iHigh/iLow      |
//+------------------------------------------------------------------+
double RP_Close(int shift)
{
   if(shift < RP_SHIFT_MIN)
   {
      Print("WARNING: RP_Close bar[0] access blocked");
      return 0.0;
   }
   return iClose(_Symbol, PERIOD_CURRENT, shift);
}

double RP_High(int shift)
{
   if(shift < RP_SHIFT_MIN)
   {
      Print("WARNING: RP_High bar[0] access blocked");
      return 0.0;
   }
   return iHigh(_Symbol, PERIOD_CURRENT, shift);
}

double RP_Low(int shift)
{
   if(shift < RP_SHIFT_MIN)
   {
      Print("WARNING: RP_Low bar[0] access blocked");
      return 0.0;
   }
   return iLow(_Symbol, PERIOD_CURRENT, shift);
}

//+------------------------------------------------------------------+
//| PipValue — never returns 0                                       |
//+------------------------------------------------------------------+
double PipValue()
{
   //--- Cache pip value: symbol digits/point never change during session
   static double s_cached_pip = 0.0;
   if(s_cached_pip > 0.0) return s_cached_pip;

   double pip_val;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(digits == 3 || digits == 5)
      pip_val = point * 10.0;
   else
      pip_val = point;

   if(pip_val <= 0.0)
      pip_val = (point > 0.0) ? point : 0.0001;

   s_cached_pip = pip_val;
   return pip_val;
}

//+------------------------------------------------------------------+
//| PipsToPrice                                                      |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
   return pips * PipValue();
}

//+------------------------------------------------------------------+
//| PriceToPips — guarded against division by zero                   |
//+------------------------------------------------------------------+
double PriceToPips(double price_diff)
{
   double pv = PipValue();
   if(pv <= 0.0) return 0.0;
   return price_diff / pv;
}

//+------------------------------------------------------------------+
//| CalcATR — raw CopyBuffer call, guarded                           |
//+------------------------------------------------------------------+
double CalcATR(int period, int shift)
{
   if(g_handle_atr == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   int copied = CopyBuffer(g_handle_atr, 0, shift, 1, buf);
   if(copied <= 0)
      return 0.0;

   return buf[0];
}

//+------------------------------------------------------------------+
//| SafeATR — cached for period=14, shift<=1                         |
//+------------------------------------------------------------------+
double SafeATR(int period, int shift = 0)
{
   if(period == 14 && shift <= 1 && g_cached_atr14 > 0.0)
      return g_cached_atr14;

   double atr = CalcATR(period, shift);
   if(atr <= 0.0 || atr != atr)
      return PipsToPrice(10);

   return atr;
}

//+------------------------------------------------------------------+
//| GetATR14 — fast wrapper                                          |
//+------------------------------------------------------------------+
double GetATR14(int shift = 0)
{
   if(shift <= 1 && g_cached_atr14 > 0.0)
      return g_cached_atr14;
   return SafeATR(14, shift);
}

//+------------------------------------------------------------------+
//| UpdateFiboCache — Swing-to-Swing Fibonacci Engine (P19)          |
//| Finds completed swing legs and calculates fib retracement levels |
//| Only legs >= 2*ATR where price is actively retracing are valid   |
//+------------------------------------------------------------------+
void UpdateFiboCache()
{
   if(g_fibo_lookback_bars <= 0) return;

   int bars_avail = Bars(_Symbol, PERIOD_CURRENT);
   int lookback = MathMin(g_fibo_lookback_bars, bars_avail - 1);
   if(lookback < 10) return;

   int N = MathMin(g_swing_lookback, 3); // Smaller N for faster fibo swing detection
   if(lookback < N * 2 + 3) return;

   //--- STEP 1: Batch copy price data ONCE (replaces 540+ iHigh/iLow calls)
   double highs[], lows[];
   int copied_h = CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback + 1, highs);
   int copied_l = CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback + 1, lows);
   if(copied_h <= 0 || copied_l <= 0) return;
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   //--- Find swing points in bars[1..lookback] (anti-repainting)
   double swing_prices[];
   int    swing_bars[];
   int    swing_types[];   // 1=High, -1=Low
   int    swing_count = 0;

   ArrayResize(swing_prices, MAX_FIBO_SWINGS);
   ArrayResize(swing_bars,   MAX_FIBO_SWINGS);
   ArrayResize(swing_types,  MAX_FIBO_SWINGS);

   int scan_limit = MathMin(lookback - N, copied_h - 1);

   for(int i = N + 1; i <= scan_limit && swing_count < MAX_FIBO_SWINGS; i++)
   {
      //--- Check swing high (use strict < to allow flat-topped swings)
      bool is_high = true;
      for(int j = 1; j <= N; j++)
      {
         if(highs[i] < highs[i - j] || highs[i] < highs[i + j])
         {
            is_high = false;
            break;
         }
      }

      //--- Check swing low (use strict > to allow flat-bottomed swings)
      bool is_low = true;
      for(int j = 1; j <= N; j++)
      {
         if(lows[i] > lows[i - j] || lows[i] > lows[i + j])
         {
            is_low = false;
            break;
         }
      }

      if(is_high)
      {
         swing_prices[swing_count] = highs[i];
         swing_bars[swing_count]   = i;
         swing_types[swing_count]  = 1;
         swing_count++;
      }
      else if(is_low)
      {
         swing_prices[swing_count] = lows[i];
         swing_bars[swing_count]   = i;
         swing_types[swing_count]  = -1;
         swing_count++;
      }
   }

   if(swing_count < 2)
   {
      g_fibo_leg_count   = 0;
      g_cached_fibo_786  = 0.0;
      g_cached_fibo_618  = 0.0;
      g_cached_fibo_500  = 0.0;
      g_cached_fibo_382  = 0.0;
      g_cached_fibo_high = 0.0;
      g_cached_fibo_low  = 0.0;
      return;
   }

   //--- STEP 2: Build fibo legs from adjacent swing pairs
   g_fibo_leg_count = 0;
   double current = iClose(_Symbol, PERIOD_CURRENT, 1); // Anti-repainting: bar[1]

   for(int i = 0; i < swing_count - 1 && g_fibo_leg_count < MAX_FIBO_LEGS; i++)
   {
      //--- Only pair different swing types (High+Low or Low+High)
      if(swing_types[i] == swing_types[i + 1]) continue;

      // swing_bars sorted ascending by bar index (nearest first)
      // i+1 has larger bar index = further back in time = older swing = leg start
      // i   has smaller bar index = more recent = newer swing = leg end
      double a_price = swing_prices[i + 1]; // Older swing (further back) = leg start
      double b_price = swing_prices[i];     // Newer swing (more recent) = leg end
      int    a_bar   = swing_bars[i + 1];
      int    b_bar   = swing_bars[i];

      double leg_size = MathAbs(b_price - a_price);

      //--- FILTER: Leg must be >= 2x ATR to be meaningful
      double min_leg = g_cached_atr14 * 2.0;
      if(min_leg <= 0.0) min_leg = PipsToPrice(20); // Fallback
      if(leg_size < min_leg) continue;

      //--- FILTER: Price must be RETRACING, not extending
      bool is_bullish = (b_price > a_price); // Low→High leg

      if(is_bullish)
      {
         // Bullish leg: price must be below swing B (retracing down)
         if(current >= b_price) continue; // Extending, not retracing
         if(current <= a_price) continue; // Broken past swing A, fibo invalid
      }
      else
      {
         // Bearish leg: price must be above swing B (retracing up)
         if(current <= b_price) continue; // Extending
         if(current >= a_price) continue; // Broken past swing A
      }

      //--- Build fibo leg
      SFiboLeg leg;
      leg.Init();
      leg.swing_a_price  = a_price;
      leg.swing_b_price  = b_price;
      leg.swing_a_bar    = a_bar;
      leg.swing_b_bar    = b_bar;
      leg.is_bullish_leg = is_bullish;
      leg.is_valid       = true;

      double range = MathAbs(b_price - a_price);

      if(is_bullish)
      {
         // Retracement from High down: buy-the-dip levels
         leg.fibo_382 = b_price - range * 0.382;
         leg.fibo_500 = b_price - range * 0.500;
         leg.fibo_618 = b_price - range * 0.618;
         leg.fibo_786 = b_price - range * 0.786;
      }
      else
      {
         // Retracement from Low up: sell-the-rally levels
         leg.fibo_382 = b_price + range * 0.382;
         leg.fibo_500 = b_price + range * 0.500;
         leg.fibo_618 = b_price + range * 0.618;
         leg.fibo_786 = b_price + range * 0.786;
      }

      g_fibo_legs[g_fibo_leg_count] = leg;
      g_fibo_leg_count++;
   }

   //--- STEP 3: Update backward-compatible cache from best leg (leg[0])
   if(g_fibo_leg_count > 0)
   {
      g_cached_fibo_786  = g_fibo_legs[0].fibo_786;
      g_cached_fibo_618  = g_fibo_legs[0].fibo_618;
      g_cached_fibo_500  = g_fibo_legs[0].fibo_500;
      g_cached_fibo_382  = g_fibo_legs[0].fibo_382;
      g_cached_fibo_high = MathMax(g_fibo_legs[0].swing_a_price, g_fibo_legs[0].swing_b_price);
      g_cached_fibo_low  = MathMin(g_fibo_legs[0].swing_a_price, g_fibo_legs[0].swing_b_price);
   }
   else
   {
      g_cached_fibo_786  = 0.0;
      g_cached_fibo_618  = 0.0;
      g_cached_fibo_500  = 0.0;
      g_cached_fibo_382  = 0.0;
      g_cached_fibo_high = 0.0;
      g_cached_fibo_low  = 0.0;
   }
}

//+------------------------------------------------------------------+
//| UpdateBarCache — call ONCE per new bar at start of OnCalculate   |
//+------------------------------------------------------------------+
void UpdateBarCache()
{
   int current_bar = Bars(_Symbol, PERIOD_CURRENT);
   if(current_bar == g_cached_bar_index)
      return;
   g_cached_bar_index = current_bar;

   //--- ATR(14) at bar[1]
   g_cached_atr14 = CalcATR(14, 1);
   if(g_cached_atr14 <= 0.0 || g_cached_atr14 != g_cached_atr14)
      g_cached_atr14 = PipsToPrice(10);

   //--- ATR14 smoothed (EMA, period=10) — spike-resistant for scoring
   //    EMA formula: smooth = alpha * raw + (1-alpha) * prev_smooth
   //    alpha = 2/(period+1) = 2/11 ≈ 0.1818
   {
      static const double ema_alpha = 2.0 / 11.0;  // EMA period 10
      if(g_cached_atr14_smooth <= 0.0)
         g_cached_atr14_smooth = g_cached_atr14;    // Seed with first value
      else
         g_cached_atr14_smooth = ema_alpha * g_cached_atr14 + (1.0 - ema_alpha) * g_cached_atr14_smooth;
   }

   //--- ATR MA50 rolling buffer
   static double atr_buf[50];
   static int    atr_idx  = 0;
   static int    atr_fill = 0;

   atr_buf[atr_idx % 50] = g_cached_atr14;
   atr_idx++;
   if(atr_fill < 50) atr_fill++;

   double atr_sum = 0.0;
   for(int i = 0; i < atr_fill; i++)
      atr_sum += atr_buf[i];
   g_cached_atr14_ma50 = atr_sum / atr_fill;

   //--- Volume MA20 rolling buffer
   static double vol_buf[20];
   static int    vol_idx  = 0;
   static int    vol_fill = 0;

   vol_buf[vol_idx % 20] = (double)iVolume(_Symbol, PERIOD_CURRENT, 1);
   vol_idx++;
   if(vol_fill < 20) vol_fill++;

   double vol_sum = 0.0;
   for(int i = 0; i < vol_fill; i++)
      vol_sum += vol_buf[i];
   g_cached_volume_ma20 = vol_sum / vol_fill;

   //--- Fibo levels
   UpdateFiboCache();
}

//+------------------------------------------------------------------+
//| IsNewBar — current timeframe                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime cur_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_time != last_time)
   {
      last_time = cur_time;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| IsNewBarHTF — detect new bar on higher timeframe                 |
//+------------------------------------------------------------------+
bool IsNewBarHTF(ENUM_TIMEFRAMES tf)
{
   static datetime htf_times[];
   static bool     initialized = false;

   if(!initialized)
   {
      ArrayResize(htf_times, 16);
      ArrayInitialize(htf_times, 0);
      initialized = true;
   }

   //--- Map ENUM_TIMEFRAMES to unique slot (avoids hash collisions like M5/H1)
   int idx;
   switch(tf)
   {
      case PERIOD_M1:   idx = 0;  break;
      case PERIOD_M5:   idx = 1;  break;
      case PERIOD_M15:  idx = 2;  break;
      case PERIOD_M30:  idx = 3;  break;
      case PERIOD_H1:   idx = 4;  break;
      case PERIOD_H4:   idx = 5;  break;
      case PERIOD_D1:   idx = 6;  break;
      case PERIOD_W1:   idx = 7;  break;
      case PERIOD_MN1:  idx = 8;  break;
      default:          idx = 9 + ((int)tf % 6); break;
   }

   datetime cur_time = iTime(_Symbol, tf, 0);

   if(cur_time != htf_times[idx])
   {
      htf_times[idx] = cur_time;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| TFToString                                                       |
//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:   return "M1";
      case PERIOD_M5:   return "M5";
      case PERIOD_M15:  return "M15";
      case PERIOD_M30:  return "M30";
      case PERIOD_H1:   return "H1";
      case PERIOD_H4:   return "H4";
      case PERIOD_D1:   return "D1";
      case PERIOD_W1:   return "W1";
      case PERIOD_MN1:  return "MN1";
      default:          return "??";
   }
}

//+------------------------------------------------------------------+
//| SessionToString                                                  |
//+------------------------------------------------------------------+
string SessionToString(ENUM_SESSION s)
{
   switch(s)
   {
      case SESSION_ASIAN:       return "Asian";
      case SESSION_LONDON_OPEN: return "London Open";
      case SESSION_LONDON:      return "London";
      case SESSION_NY_OPEN:     return "NY Open";
      case SESSION_NY:          return "NY";
      case SESSION_OVERLAP:     return "London-NY Overlap";
      case SESSION_DEAD:        return "Dead Zone";
      default:                  return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| RegimeToString                                                   |
//+------------------------------------------------------------------+
string RegimeToString(ENUM_MARKET_REGIME r)
{
   switch(r)
   {
      case REGIME_STRONG_TREND: return "STRONG TREND";
      case REGIME_WEAK_TREND:   return "WEAK TREND";
      case REGIME_RANGING:      return "RANGING";
      case REGIME_CHOPPY:       return "CHOPPY";
      default:                  return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| DashCornerToAnchor                                               |
//+------------------------------------------------------------------+
ENUM_ANCHOR_POINT DashCornerToAnchor(ENUM_DASH_CORNER c)
{
   switch(c)
   {
      case DASH_TOP_LEFT:     return ANCHOR_LEFT_UPPER;
      case DASH_TOP_RIGHT:    return ANCHOR_RIGHT_UPPER;
      case DASH_BOTTOM_LEFT:  return ANCHOR_LEFT_LOWER;
      case DASH_BOTTOM_RIGHT: return ANCHOR_RIGHT_LOWER;
      default:                return ANCHOR_LEFT_UPPER;
   }
}

//+------------------------------------------------------------------+
//| GetSpreadColor                                                   |
//+------------------------------------------------------------------+
color GetSpreadColor(double current, double average)
{
   if(average <= 0.0) return clrWhite;
   if(current > average * 3.0) return clrRed;
   if(current > average * 2.0) return clrYellow;
   return clrWhite;
}

//+------------------------------------------------------------------+
//| ClassifyRPLevel                                                  |
//+------------------------------------------------------------------+
ENUM_RP_LEVEL ClassifyRPLevel(double score)
{
   if(score >= 120.0) return RP_PREMIUM;   // Was 110 — raised for better differentiation with cap 200
   if(score >= 85.0)  return RP_LEVEL1;    // Was 80
   if(score >= 60.0)  return RP_LEVEL2;
   if(score >= 40.0)  return RP_LEVEL3;
   return RP_HIDDEN;
}

//+------------------------------------------------------------------+
//| IsLevelVisible — check if a level is enabled via toggle inputs    |
//+------------------------------------------------------------------+
bool IsLevelVisible(ENUM_RP_LEVEL level)
{
   switch(level)
   {
      case RP_PREMIUM: return g_show_premium;
      case RP_LEVEL1:  return g_show_level1;
      case RP_LEVEL2:  return g_show_level2;
      case RP_LEVEL3:  return g_show_level3;
      default:         return false;
   }
}

//+------------------------------------------------------------------+
//| InitIndicatorHandles                                             |
//+------------------------------------------------------------------+
bool InitIndicatorHandles()
{
   g_handle_adx = iADX(_Symbol, PERIOD_CURRENT, g_adx_period);
   g_handle_atr = iATR(_Symbol, PERIOD_CURRENT, 14);

   if(g_handle_adx == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ADX handle");
      return false;
   }
   if(g_handle_atr == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR handle");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| ReleaseIndicatorHandles                                          |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
{
   if(g_handle_adx != INVALID_HANDLE)
   {
      IndicatorRelease(g_handle_adx);
      g_handle_adx = INVALID_HANDLE;
   }
   if(g_handle_atr != INVALID_HANDLE)
   {
      IndicatorRelease(g_handle_atr);
      g_handle_atr = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| RevalidateHandles — call every ~100 bars                         |
//+------------------------------------------------------------------+
bool RevalidateHandles()
{
   static int bar_counter = 0;
   bar_counter++;
   if(bar_counter < 100)
      return true;
   bar_counter = 0;

   bool ok = true;

   if(g_handle_adx == INVALID_HANDLE)
   {
      g_handle_adx = iADX(_Symbol, PERIOD_CURRENT, g_adx_period);
      if(g_handle_adx == INVALID_HANDLE)
      {
         Print("WARNING: Cannot re-create ADX handle");
         ok = false;
      }
   }

   if(g_handle_atr == INVALID_HANDLE)
   {
      g_handle_atr = iATR(_Symbol, PERIOD_CURRENT, 14);
      if(g_handle_atr == INVALID_HANDLE)
      {
         Print("WARNING: Cannot re-create ATR handle");
         ok = false;
      }
   }

   return ok;
}

//+------------------------------------------------------------------+
//| BlendColor — simulate alpha for rectangles                       |
//+------------------------------------------------------------------+
color BlendColor(color fg, color bg, int alpha_pct)
{
   if(alpha_pct >= 100) return fg;
   if(alpha_pct <= 0)   return bg;

   int r = ((int)(fg & 0xFF)         * alpha_pct + (int)(bg & 0xFF)         * (100 - alpha_pct)) / 100;
   int g = ((int)((fg >> 8) & 0xFF)  * alpha_pct + (int)((bg >> 8) & 0xFF)  * (100 - alpha_pct)) / 100;
   int b = ((int)((fg >> 16) & 0xFF) * alpha_pct + (int)((bg >> 16) & 0xFF) * (100 - alpha_pct)) / 100;

   r = MathMax(0, MathMin(255, r));
   g = MathMax(0, MathMin(255, g));
   b = MathMax(0, MathMin(255, b));

   return (color)((b << 16) | (g << 8) | r);
}

//+------------------------------------------------------------------+
//| GetChartBackground                                               |
//+------------------------------------------------------------------+
color GetChartBackground()
{
   return (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
}

//+------------------------------------------------------------------+
//| DetectPairType — identify pair characteristics from symbol (P22)  |
//+------------------------------------------------------------------+
void DetectPairType()
{
   string symbol = _Symbol;

   g_is_jpy_pair = (StringFind(symbol, "JPY") >= 0);
   g_is_gbp_pair = (StringFind(symbol, "GBP") >= 0);

   g_is_cross_pair = !(
      StringFind(symbol, "EURUSD") >= 0 || StringFind(symbol, "GBPUSD") >= 0 ||
      StringFind(symbol, "USDJPY") >= 0 || StringFind(symbol, "USDCHF") >= 0 ||
      StringFind(symbol, "AUDUSD") >= 0 || StringFind(symbol, "USDCAD") >= 0 ||
      StringFind(symbol, "NZDUSD") >= 0
   );

   Print("RP: Pair=", symbol,
         " | JPY=", g_is_jpy_pair,
         " | GBP=", g_is_gbp_pair,
         " | Cross=", g_is_cross_pair);
}

//+------------------------------------------------------------------+
//| ApplyVolatilityScaling — scale params by ATR ratio (P22)          |
//| Called ONCE after first UpdateBarCache when ATR is available       |
//+------------------------------------------------------------------+
void ApplyVolatilityScaling()
{
   if(g_cached_atr14 <= 0.0) return;

   //--- ATR baseline per TF (typical EURUSD values)
   double atr_baseline;
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();

   if(tf <= PERIOD_M15)      atr_baseline = PipsToPrice(10);
   else if(tf <= PERIOD_M30) atr_baseline = PipsToPrice(15);
   else if(tf <= PERIOD_H1)  atr_baseline = PipsToPrice(25);
   else if(tf <= PERIOD_H4)  atr_baseline = PipsToPrice(50);
   else                      atr_baseline = PipsToPrice(100);

   if(atr_baseline <= 0.0) atr_baseline = PipsToPrice(25);

   double ratio = g_cached_atr14 / atr_baseline;
   ratio = MathMax(0.7, MathMin(ratio, 2.5)); // Clamp

   //--- Scale distance parameters
   g_min_rp_distance_pips   = (int)MathRound(g_min_rp_distance_pips * ratio);
   g_min_reaction_move_pips = (int)MathRound(g_min_reaction_move_pips * ratio);
   g_breakout_confirm_pips  = (int)MathRound(g_breakout_confirm_pips * ratio);
   g_confluence_merge_pips  = (int)MathRound(g_confluence_merge_pips * ratio);
   g_fibo_tolerance_pips    = (int)MathRound(g_fibo_tolerance_pips * ratio);
   g_proximity_alert_pips   = (int)MathRound(g_proximity_alert_pips * ratio);
   g_reset_alert_pips       = (int)MathRound(g_reset_alert_pips * ratio);
   g_sl_buffer_pips         = (int)MathRound(g_sl_buffer_pips * ratio);
   g_zone_width_pips        = (int)MathMax(MathRound(g_zone_width_pips * ratio), 3);   // P22 fix: scale zone min width
   g_min_candle_size_pips   = (int)MathMax(MathRound(g_min_candle_size_pips * ratio), 2); // P22 fix: scale candle filter

   //--- Cross pairs: relax spread filter
   if(g_is_cross_pair)
   {
      if(g_spread_alert_multiplier < 2.5) g_spread_alert_multiplier = 2.5;
      if(g_spread_block_multiplier < 4.0) g_spread_block_multiplier = 4.0;
   }

   Print("RP: ATR ratio=", DoubleToString(ratio, 2),
         " | MinDist=", g_min_rp_distance_pips,
         " | BreakConf=", g_breakout_confirm_pips,
         " | MergePips=", g_confluence_merge_pips);
}

//+------------------------------------------------------------------+
//| InitRPIDMap — call in OnInit after array allocation               |
//+------------------------------------------------------------------+
void InitRPIDMap()
{
   ArrayResize(g_rp_id_to_index, MAX_RP_ID_MAP);
   ArrayInitialize(g_rp_id_to_index, -1);
}

//+------------------------------------------------------------------+
//| RebuildRPIDMap — full rebuild, call after bulk changes             |
//+------------------------------------------------------------------+
void RebuildRPIDMap()
{
   ArrayInitialize(g_rp_id_to_index, -1);
   for(int i = 0; i < g_rp_count; i++)
   {
      int id = g_rp_array[i].id;
      if(id >= 0 && id < MAX_RP_ID_MAP)
         g_rp_id_to_index[id] = i;
   }
}

//+------------------------------------------------------------------+
//| SetRPIDMap — update single entry                                   |
//+------------------------------------------------------------------+
void SetRPIDMap(int rp_id, int array_index)
{
   if(rp_id >= 0 && rp_id < MAX_RP_ID_MAP)
      g_rp_id_to_index[rp_id] = array_index;
   else if(rp_id >= MAX_RP_ID_MAP)
   {
      //--- ID overflow: rebuild map with modular IDs
      //    Reset g_next_rp_id and reassign all active RPs
      g_next_rp_id = 0;
      ArrayInitialize(g_rp_id_to_index, -1);
      for(int i = 0; i < g_rp_count; i++)
      {
         if(g_rp_array[i].is_active)
         {
            g_rp_array[i].id = g_next_rp_id;
            g_rp_id_to_index[g_next_rp_id] = i;
            g_next_rp_id++;
         }
      }
      //--- Assign new ID for current RP
      if(g_next_rp_id < MAX_RP_ID_MAP && array_index >= 0 && array_index < g_rp_count)
      {
         g_rp_array[array_index].id = g_next_rp_id;
         g_rp_id_to_index[g_next_rp_id] = array_index;
         g_next_rp_id++;
      }
      Print("RP: ID overflow — reassigned ", g_next_rp_id, " IDs");
   }
}

//+------------------------------------------------------------------+
//| ClearRPIDMap — remove single entry                                 |
//+------------------------------------------------------------------+
void ClearRPIDMap(int rp_id)
{
   if(rp_id >= 0 && rp_id < MAX_RP_ID_MAP)
      g_rp_id_to_index[rp_id] = -1;
}

//+------------------------------------------------------------------+
//| FindRPIndexByID — O(1) lookup with fallback to O(N) scan          |
//+------------------------------------------------------------------+
int FindRPIndexByID(int rp_id)
{
   //--- Fast path: direct map lookup
   if(rp_id >= 0 && rp_id < MAX_RP_ID_MAP)
   {
      int idx = g_rp_id_to_index[rp_id];
      if(idx >= 0 && idx < g_rp_count && g_rp_array[idx].id == rp_id)
         return idx;
   }

   //--- Fallback: linear scan (handles ID >= MAX_RP_ID_MAP or stale map)
   for(int r = 0; r < g_rp_count; r++)
   {
      if(g_rp_array[r].id == rp_id)
      {
         SetRPIDMap(rp_id, r);  // Update map for next time
         return r;
      }
   }
   return -1;
}

#endif // RP_UTILS_MQH
