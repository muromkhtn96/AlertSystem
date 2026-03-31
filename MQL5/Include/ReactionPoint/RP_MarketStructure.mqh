//+------------------------------------------------------------------+
//|                                         RP_MarketStructure.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module H — BOS, CHoCH, Liquidity Sweep    |
//+------------------------------------------------------------------+
#ifndef RP_MARKETSTRUCTURE_MQH
#define RP_MARKETSTRUCTURE_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| UpdateMarketStructure                                             |
//| Detect BOS, CHoCH using price action only (no extra indicators)  |
//| Called once per new bar (IsNewBar)                                |
//+------------------------------------------------------------------+
void UpdateMarketStructure()
{
   if(!g_use_market_structure) return;

   //--- Increment bar counters FIRST (before detection may overwrite)
   if(g_last_bos_bar > 0)   g_last_bos_bar++;
   if(g_last_choch_bar > 0) g_last_choch_bar++;

   //--- CHoCH expires after 10 bars
   if(g_choch_detected && g_last_choch_bar > 10)
      g_choch_detected = false;

   int available = Bars(_Symbol, PERIOD_CURRENT);
   int lookback = MathMin(g_structure_lookback_bars, available - 2);
   if(lookback < 10) return;

   //--- Find 4 recent swing points (2 highs + 2 lows)
   //    Using same N-bar confirmation as main detection
   int N = g_swing_lookback;
   if(N < 2) N = 2;

   double swing_highs[];
   int    swing_high_bars[];
   double swing_lows[];
   int    swing_low_bars[];
   ArrayResize(swing_highs, 0);
   ArrayResize(swing_high_bars, 0);
   ArrayResize(swing_lows, 0);
   ArrayResize(swing_low_bars, 0);

   for(int i = N + 1; i <= lookback && i < available - N; i++)
   {
      double high_i = RP_High(i);
      double low_i  = RP_Low(i);
      if(high_i == 0.0 || low_i == 0.0) continue;

      // Check swing high
      bool is_sh = true;
      for(int j = 1; j <= N; j++)
      {
         double h_l = RP_High(i + j);
         double h_r = RP_High(i - j);
         if(h_l == 0.0 || h_r == 0.0 || high_i <= h_l || high_i <= h_r)
         { is_sh = false; break; }
      }
      if(is_sh)
      {
         int sz = ArraySize(swing_highs);
         if(sz < 4)
         {
            ArrayResize(swing_highs, sz + 1);
            ArrayResize(swing_high_bars, sz + 1);
            swing_highs[sz] = high_i;
            swing_high_bars[sz] = i;
         }
      }

      // Check swing low
      bool is_sl = true;
      for(int j = 1; j <= N; j++)
      {
         double l_l = RP_Low(i + j);
         double l_r = RP_Low(i - j);
         if(l_l == 0.0 || l_r == 0.0 || low_i >= l_l || low_i >= l_r)
         { is_sl = false; break; }
      }
      if(is_sl)
      {
         int sz = ArraySize(swing_lows);
         if(sz < 4)
         {
            ArrayResize(swing_lows, sz + 1);
            ArrayResize(swing_low_bars, sz + 1);
            swing_lows[sz] = low_i;
            swing_low_bars[sz] = i;
         }
      }

      // Stop once we have enough
      if(ArraySize(swing_highs) >= 2 && ArraySize(swing_lows) >= 2)
         break;
   }

   // Need at least 2 highs and 2 lows
   if(ArraySize(swing_highs) < 2 || ArraySize(swing_lows) < 2)
   {
      g_current_structure = STRUCTURE_NONE;
      return;
   }

   // swing_highs[0] = most recent swing high, [1] = previous
   // swing_lows[0]  = most recent swing low,  [1] = previous

   //--- Determine structure
   bool hh = swing_highs[0] > swing_highs[1]; // Higher High
   bool hl = swing_lows[0]  > swing_lows[1];  // Higher Low
   bool lh = swing_highs[0] < swing_highs[1]; // Lower High
   bool ll = swing_lows[0]  < swing_lows[1];  // Lower Low

   ENUM_STRUCTURE_STATE prev_structure = g_current_structure;

   if(hh && hl)
      g_current_structure = STRUCTURE_BULLISH;
   else if(lh && ll)
      g_current_structure = STRUCTURE_BEARISH;
   else
      g_current_structure = STRUCTURE_NONE;

   //--- BOS detection on bar[1] (anti-repainting)
   double close_1 = RP_Close(1);
   if(close_1 == 0.0) return;

   // Bullish BOS: close[1] breaks above most recent swing high
   if(close_1 > swing_highs[0])
      g_last_bos_bar = 1;

   // Bearish BOS: close[1] breaks below most recent swing low
   if(close_1 < swing_lows[0])
      g_last_bos_bar = 1;

   //--- CHoCH detection
   // In BULLISH structure: close[1] breaks below last Higher Low → CHoCH bearish
   if(prev_structure == STRUCTURE_BULLISH && close_1 < swing_lows[0])
   {
      g_choch_detected = true;
      g_last_choch_bar = 1;
   }

   // In BEARISH structure: close[1] breaks above last Lower High → CHoCH bullish
   if(prev_structure == STRUCTURE_BEARISH && close_1 > swing_highs[0])
   {
      g_choch_detected = true;
      g_last_choch_bar = 1;
   }

}

//+------------------------------------------------------------------+
//| CheckLiquiditySweep                                               |
//| Detects when price sweeps past swing H/L then closes back inside |
//| = Institutional trap signal, high probability reversal            |
//+------------------------------------------------------------------+
bool CheckLiquiditySweep(int bar_index)
{
   if(!g_use_market_structure) return false;
   if(bar_index < RP_SHIFT_MIN) return false;

   double high_i  = RP_High(bar_index);
   double low_i   = RP_Low(bar_index);
   double close_i = RP_Close(bar_index);
   if(high_i == 0.0 || low_i == 0.0 || close_i == 0.0) return false;

   double range = high_i - low_i;
   if(range <= 0) return false;

   double upper_wick = high_i - MathMax(iOpen(_Symbol, PERIOD_CURRENT, bar_index), close_i);
   double lower_wick = MathMin(iOpen(_Symbol, PERIOD_CURRENT, bar_index), close_i) - low_i;

   // Check against nearby swing points
   int N = g_swing_lookback;
   int lookback = MathMin(g_structure_lookback_bars, Bars(_Symbol, PERIOD_CURRENT) - 2);

   for(int j = bar_index + 1; j <= bar_index + lookback && j < Bars(_Symbol, PERIOD_CURRENT) - 1; j++)
   {
      double prev_high = RP_High(j);
      double prev_low  = RP_Low(j);
      if(prev_high == 0.0 || prev_low == 0.0) continue;

      // Check if j is a swing high
      bool is_sh = true;
      for(int k = 1; k <= N && (j + k) < Bars(_Symbol, PERIOD_CURRENT) && (j - k) >= 1; k++)
      {
         double hl = RP_High(j + k);
         double hr = RP_High(j - k);
         if(hl == 0.0 || hr == 0.0 || prev_high <= hl || prev_high <= hr)
         { is_sh = false; break; }
      }

      // Sweep above swing high: bar high > swing high, close back below
      if(is_sh && high_i > prev_high && close_i < prev_high)
      {
         // Wick on sweep side >= 40% range
         if(upper_wick >= range * 0.40)
         {
            // Mark nearest RP
            MarkNearestRPSweep(prev_high);
            return true;
         }
      }

      // Check if j is a swing low
      bool is_sl = true;
      for(int k = 1; k <= N && (j + k) < Bars(_Symbol, PERIOD_CURRENT) && (j - k) >= 1; k++)
      {
         double ll = RP_Low(j + k);
         double lr = RP_Low(j - k);
         if(ll == 0.0 || lr == 0.0 || prev_low >= ll || prev_low >= lr)
         { is_sl = false; break; }
      }

      // Sweep below swing low: bar low < swing low, close back above
      if(is_sl && low_i < prev_low && close_i > prev_low)
      {
         if(lower_wick >= range * 0.40)
         {
            MarkNearestRPSweep(prev_low);
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Mark nearest RP as having liquidity sweep                         |
//+------------------------------------------------------------------+
void MarkNearestRPSweep(double sweep_price)
{
   double min_dist = DBL_MAX;
   int    best_idx = -1;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      double dist = MathAbs(g_rp_array[i].price - sweep_price);
      if(dist < min_dist)
      {
         min_dist = dist;
         best_idx = i;
      }
   }

   if(best_idx >= 0 && PriceToPips(min_dist) <= g_zone_width_pips * 2.0)
   {
      g_rp_array[best_idx].has_liquidity_sweep = true;
      g_rp_dirty[best_idx] = true;
   }
}

//+------------------------------------------------------------------+
//| GetStructureScoreAdj — score adjustment based on BOS/CHoCH       |
//+------------------------------------------------------------------+
double GetStructureScoreAdj(int rp_index)
{
   if(!g_use_market_structure) return 0.0;
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;

   SReactionPoint rp = g_rp_array[rp_index];

   // RP SUPPORT + BULLISH structure (aligned with BOS) → +15
   if(rp.rp_type == RP_SUPPORT && g_current_structure == STRUCTURE_BULLISH)
      return 15.0;

   // RP RESISTANCE + BEARISH structure (aligned with BOS) → +15
   if(rp.rp_type == RP_RESISTANCE && g_current_structure == STRUCTURE_BEARISH)
      return 15.0;

   // Counter-trend without CHoCH → -20
   if(rp.rp_type == RP_SUPPORT && g_current_structure == STRUCTURE_BEARISH)
   {
      if(g_choch_detected && g_last_choch_bar <= 10)
         return 10.0;   // CHoCH just occurred → reversal play valid
      return -20.0;
   }

   if(rp.rp_type == RP_RESISTANCE && g_current_structure == STRUCTURE_BULLISH)
   {
      if(g_choch_detected && g_last_choch_bar <= 10)
         return 10.0;
      return -20.0;
   }

   // STRUCTURE_NONE → 0
   return 0.0;
}

//+------------------------------------------------------------------+
//| GetLiquiditySweepBonus — strongest bonus for sweep + RP           |
//+------------------------------------------------------------------+
double GetLiquiditySweepBonus(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;

   if(g_rp_array[rp_index].has_liquidity_sweep)
      return 20.0;

   return 0.0;
}

#endif // RP_MARKETSTRUCTURE_MQH
