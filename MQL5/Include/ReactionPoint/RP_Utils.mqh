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
color  g_color_premium       = clrGold;
color  g_color_level1        = clrCrimson;
color  g_color_level2        = clrOrange;
color  g_color_level3        = clrSkyBlue;
color  g_color_confluence    = clrMediumPurple;
color  g_color_role_reversal = clrMagenta;
color  g_color_entry_buy     = clrLimeGreen;
color  g_color_entry_sell    = clrRed;

//+------------------------------------------------------------------+
//| Global Variables — Performance Cache                             |
//+------------------------------------------------------------------+
double g_cached_atr14         = 0.0;
double g_cached_atr14_ma50    = 0.0;
double g_cached_volume_ma20   = 0.0;
int    g_cached_bar_index     = -1;

// Fibo cache
double g_cached_fibo_high     = 0.0;
double g_cached_fibo_low      = 0.0;
double g_cached_fibo_618      = 0.0;
double g_cached_fibo_500      = 0.0;
double g_cached_fibo_382      = 0.0;

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
   double pip_val;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(digits == 3 || digits == 5)
      pip_val = point * 10.0;
   else
      pip_val = point;

   if(pip_val <= 0.0)
      pip_val = (point > 0.0) ? point : 0.0001;

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
//| UpdateFiboCache — find swing H/L and calc fib levels once/bar    |
//+------------------------------------------------------------------+
void UpdateFiboCache()
{
   if(g_fibo_lookback_bars <= 0) return;

   int bars_avail = Bars(_Symbol, PERIOD_CURRENT);
   int lookback = MathMin(g_fibo_lookback_bars, bars_avail - 1);
   if(lookback < 5) return;

   double highest = -DBL_MAX;
   double lowest  = DBL_MAX;

   for(int i = 1; i <= lookback; i++)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(h > highest) highest = h;
      if(l < lowest)  lowest  = l;
   }

   g_cached_fibo_high = highest;
   g_cached_fibo_low  = lowest;

   double range = highest - lowest;
   if(range <= 0.0)
   {
      g_cached_fibo_618 = 0.0;
      g_cached_fibo_500 = 0.0;
      g_cached_fibo_382 = 0.0;
      return;
   }

   if(g_current_trend == TREND_UP)
   {
      // Retracement from low to high (buy dip)
      g_cached_fibo_618 = highest - range * 0.618;
      g_cached_fibo_500 = highest - range * 0.500;
      g_cached_fibo_382 = highest - range * 0.382;
   }
   else
   {
      // Retracement from high to low, or default
      g_cached_fibo_618 = lowest + range * 0.618;
      g_cached_fibo_500 = lowest + range * 0.500;
      g_cached_fibo_382 = lowest + range * 0.382;
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
      ArrayResize(htf_times, 30);
      ArrayInitialize(htf_times, 0);
      initialized = true;
   }

   int idx = (int)tf % 30;
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
   if(score >= 110.0) return RP_PREMIUM;
   if(score >= 80.0)  return RP_LEVEL1;
   if(score >= 60.0)  return RP_LEVEL2;
   if(score >= 40.0)  return RP_LEVEL3;
   return RP_HIDDEN;
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

   int r = ((int)ColorGetRed(fg)   * alpha_pct + (int)ColorGetRed(bg)   * (100 - alpha_pct)) / 100;
   int g = ((int)ColorGetGreen(fg) * alpha_pct + (int)ColorGetGreen(bg) * (100 - alpha_pct)) / 100;
   int b = ((int)ColorGetBlue(fg)  * alpha_pct + (int)ColorGetBlue(bg)  * (100 - alpha_pct)) / 100;

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

#endif // RP_UTILS_MQH
