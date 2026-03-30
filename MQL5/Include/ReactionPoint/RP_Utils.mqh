//+------------------------------------------------------------------+
//|                                                    RP_Utils.mqh  |
//|                        Reaction Point Indicator v3.0              |
//|                        Utility Functions                          |
//+------------------------------------------------------------------+
#ifndef RP_UTILS_MQH
#define RP_UTILS_MQH

#include "RP_Defines.mqh"

//+------------------------------------------------------------------+
//| Globals for preset-applied parameters                            |
//+------------------------------------------------------------------+
int    g_swing_lookback;
int    g_min_rp_distance_pips;
int    g_min_reaction_move_pips;
int    g_initial_bars_to_scan;
int    g_breakout_confirm_pips;
int    g_max_retest_bars;
int    g_decay_interval_bars;
int    g_decay_points_per_interval;
int    g_max_rp_age_bars;
int    g_sl_buffer_pips;
int    g_entry_buffer_pips;
int    g_max_setup_age_bars;
int    g_confluence_merge_pips;
int    g_htf_bars_to_scan;
int    g_fibo_lookback_bars;
int    g_fibo_tolerance_pips;
int    g_min_candle_size_pips;
int    g_zone_width_pips;
int    g_min_score_to_show;
int    g_proximity_alert_pips;
int    g_reset_alert_pips;
ENUM_TIMEFRAMES g_htf_1;
ENUM_TIMEFRAMES g_htf_2;

//--- Global state flags
bool   g_news_blackout      = false;
bool   g_news_available     = true;
bool   g_spread_blocked     = false;
bool   g_spread_warning     = false;
string g_news_status_text   = "clear";
color  g_news_status_color  = clrLime;

//--- Global regime
ENUM_MARKET_REGIME g_current_regime = REGIME_RANGING;
ENUM_TREND_DIR     g_current_trend  = TREND_NONE;
double             g_current_adx    = 0;

//--- Global session
ENUM_SESSION       g_current_session = SESSION_DEAD;

//--- Global spread
double g_current_spread_pips = 0;
double g_average_spread_pips = 0;

//--- RP arrays
SReactionPoint g_rp_array[];
int            g_rp_count = 0;
int            g_next_rp_id = 0;

//--- Confluence arrays
SConfluenceZone g_confluence_array[];
int             g_confluence_count = 0;
int             g_next_confluence_id = 0;

//--- Entry setup arrays
SEntrySetup g_setup_array[];
int         g_setup_count = 0;

//--- Stats
SRPStats g_stats;

//--- Object count
int g_object_count = 0;

//--- Last bar time for IsNewBar
datetime g_last_bar_time = 0;

//+------------------------------------------------------------------+
//| Pip value for current symbol                                      |
//+------------------------------------------------------------------+
double PipValue()
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   else
      return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Convert pips to price distance                                    |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
{
   return pips * PipValue();
}

//+------------------------------------------------------------------+
//| Convert price distance to pips                                    |
//+------------------------------------------------------------------+
double PriceToPips(double price_dist)
{
   double pv = PipValue();
   if(pv <= 0) return 0;
   return price_dist / pv;
}

//+------------------------------------------------------------------+
//| Safe ATR with fallback                                            |
//+------------------------------------------------------------------+
double SafeATR(int period, int shift = 0)
{
   // Anti-repainting: confirmed on closed bars only
   double atr_buf[];
   int handle = iATR(_Symbol, PERIOD_CURRENT, period);
   if(handle == INVALID_HANDLE) return PipsToPrice(10);

   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(handle, 0, shift, 1, atr_buf) <= 0)
   {
      IndicatorRelease(handle);
      return PipsToPrice(10);
   }
   IndicatorRelease(handle);

   double atr = atr_buf[0];
   if(atr <= 0 || atr != atr) return PipsToPrice(10); // NaN check
   return atr;
}

//+------------------------------------------------------------------+
//| Cached ATR handle for performance                                 |
//+------------------------------------------------------------------+
int g_atr14_handle = INVALID_HANDLE;
int g_adx_handle   = INVALID_HANDLE;

bool InitIndicatorHandles()
{
   g_atr14_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
   g_adx_handle   = iADX(_Symbol, PERIOD_CURRENT, 14);
   return (g_atr14_handle != INVALID_HANDLE && g_adx_handle != INVALID_HANDLE);
}

void ReleaseIndicatorHandles()
{
   if(g_atr14_handle != INVALID_HANDLE) { IndicatorRelease(g_atr14_handle); g_atr14_handle = INVALID_HANDLE; }
   if(g_adx_handle != INVALID_HANDLE)   { IndicatorRelease(g_adx_handle);   g_adx_handle = INVALID_HANDLE; }
}

double GetATR14(int shift = 1)
{
   if(g_atr14_handle == INVALID_HANDLE) return PipsToPrice(10);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atr14_handle, 0, shift, 1, buf) <= 0) return PipsToPrice(10);
   if(buf[0] <= 0 || buf[0] != buf[0]) return PipsToPrice(10);
   return buf[0];
}

double GetADX(int shift = 1)
{
   if(g_adx_handle == INVALID_HANDLE) return 0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_adx_handle, 0, shift, 1, buf) <= 0) return 0;
   return buf[0];
}

double GetADXPlus(int shift = 1)
{
   if(g_adx_handle == INVALID_HANDLE) return 0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_adx_handle, 1, shift, 1, buf) <= 0) return 0;
   return buf[0];
}

double GetADXMinus(int shift = 1)
{
   if(g_adx_handle == INVALID_HANDLE) return 0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_adx_handle, 2, shift, 1, buf) <= 0) return 0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Check if new bar formed                                           |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current_time == 0) return false;
   if(g_last_bar_time == 0) { g_last_bar_time = current_time; return true; }
   if(current_time != g_last_bar_time)
   {
      g_last_bar_time = current_time;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Clamp integer to range                                            |
//+------------------------------------------------------------------+
int ClampInt(int value, int min_val, int max_val)
{
   if(value < min_val) { PrintFormat("Warning: clamped %d to %d", value, min_val); return min_val; }
   if(value > max_val) { PrintFormat("Warning: clamped %d to %d", value, max_val); return max_val; }
   return value;
}

//+------------------------------------------------------------------+
//| Clamp double to range                                             |
//+------------------------------------------------------------------+
double ClampDouble(double value, double min_val, double max_val)
{
   if(value < min_val) return min_val;
   if(value > max_val) return max_val;
   return value;
}

//+------------------------------------------------------------------+
//| Get CORNER_ANCHOR from ENUM_DASH_CORNER                           |
//+------------------------------------------------------------------+
ENUM_BASE_CORNER DashCornerToAnchor(ENUM_DASH_CORNER corner)
{
   switch(corner)
   {
      case DASH_TOP_LEFT:     return CORNER_LEFT_UPPER;
      case DASH_TOP_RIGHT:    return CORNER_RIGHT_UPPER;
      case DASH_BOTTOM_LEFT:  return CORNER_LEFT_LOWER;
      case DASH_BOTTOM_RIGHT: return CORNER_RIGHT_LOWER;
   }
   return CORNER_LEFT_UPPER;
}

//+------------------------------------------------------------------+
//| Color with opacity (MQL5 uses alpha channel via ColorToARGB)      |
//+------------------------------------------------------------------+
uint ColorWithOpacity(color clr, double opacity_pct)
{
   int alpha = (int)MathRound(255.0 * opacity_pct / 100.0);
   alpha = (int)MathMax(0, MathMin(255, alpha));
   return ColorToARGB(clr, (uchar)alpha);
}

//+------------------------------------------------------------------+
//| Check if price is near round number                               |
//+------------------------------------------------------------------+
double RoundNumberScore(double price)
{
   double pip_val = PipValue();
   if(pip_val <= 0) return 0;

   // Check distance to nearest x.x000 or x.x500
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double round_step = 0;

   if(digits == 5 || digits == 3)
      round_step = 0.01; // 100 pips
   else
      round_step = 0.1;

   double half_step = round_step / 2.0;

   double nearest_full = MathRound(price / round_step) * round_step;
   double nearest_half = MathRound(price / half_step) * half_step;

   double dist_full = MathAbs(price - nearest_full);
   double dist_half = MathAbs(price - nearest_half);
   double dist = MathMin(dist_full, dist_half);
   double dist_pips = PriceToPips(dist);

   if(dist_pips <= 10) return 10;
   if(dist_pips <= 20) return 5;
   return 0;
}

//+------------------------------------------------------------------+
//| Find RP index by ID                                               |
//+------------------------------------------------------------------+
int FindRPById(int rp_id)
{
   for(int i = 0; i < g_rp_count; i++)
      if(g_rp_array[i].id == rp_id) return i;
   return -1;
}

//+------------------------------------------------------------------+
//| Evict RP when array is full                                       |
//+------------------------------------------------------------------+
int EvictRP()
{
   // Priority: inactive → lowest score non-confluence → oldest
   int evict_idx = -1;
   double lowest_score = 999999;

   // First pass: find inactive
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active)
      {
         if(evict_idx == -1 || g_rp_array[i].final_score < lowest_score)
         {
            evict_idx = i;
            lowest_score = g_rp_array[i].final_score;
         }
      }
   }
   if(evict_idx >= 0) return evict_idx;

   // Second pass: lowest score non-confluence
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_confluence && g_rp_array[i].final_score < lowest_score)
      {
         evict_idx = i;
         lowest_score = g_rp_array[i].final_score;
      }
   }
   if(evict_idx >= 0) return evict_idx;

   // Third pass: oldest
   datetime oldest_time = TimeCurrent();
   for(int i = 0; i < g_rp_count; i++)
   {
      if(g_rp_array[i].time_formed < oldest_time)
      {
         evict_idx = i;
         oldest_time = g_rp_array[i].time_formed;
      }
   }
   return evict_idx;
}

//+------------------------------------------------------------------+
//| TF to string for display                                          |
//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
//| Session to string                                                 |
//+------------------------------------------------------------------+
string SessionToString(ENUM_SESSION sess)
{
   switch(sess)
   {
      case SESSION_ASIAN:       return "Asian";
      case SESSION_LONDON_OPEN: return "London Open";
      case SESSION_LONDON:      return "London";
      case SESSION_NY_OPEN:     return "NY Open";
      case SESSION_NY:          return "NY";
      case SESSION_OVERLAP:     return "Overlap";
      case SESSION_DEAD:        return "Dead Zone";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| RP Level to string                                                |
//+------------------------------------------------------------------+
string RPLevelToString(ENUM_RP_LEVEL lvl)
{
   switch(lvl)
   {
      case RP_PREMIUM: return "PREMIUM";
      case RP_LEVEL1:  return "LEVEL 1";
      case RP_LEVEL2:  return "LEVEL 2";
      case RP_LEVEL3:  return "LEVEL 3";
      case RP_HIDDEN:  return "HIDDEN";
   }
   return "";
}

//+------------------------------------------------------------------+
//| Regime to string                                                  |
//+------------------------------------------------------------------+
string RegimeToString(ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_TREND: return "STRONG TREND";
      case REGIME_WEAK_TREND:   return "WEAK TREND";
      case REGIME_RANGING:      return "RANGING";
      case REGIME_CHOPPY:       return "CHOPPY";
   }
   return "";
}

//+------------------------------------------------------------------+
//| Pattern to string                                                 |
//+------------------------------------------------------------------+
string PatternToString(ENUM_CANDLE_PATTERN pat)
{
   switch(pat)
   {
      case PATTERN_NONE:        return "None";
      case PATTERN_PINBAR:      return "Pinbar";
      case PATTERN_ENGULFING:   return "Engulfing";
      case PATTERN_OUTSIDE_BAR: return "Outside Bar";
      case PATTERN_LARGE_WICK:  return "Large Wick";
   }
   return "";
}

#endif
