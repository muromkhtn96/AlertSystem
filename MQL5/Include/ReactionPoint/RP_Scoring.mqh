//+------------------------------------------------------------------+
//|                                                RP_Scoring.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Scoring System                             |
//+------------------------------------------------------------------+
#ifndef RP_SCORING_MQH
#define RP_SCORING_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| Calculate Fibonacci score                                         |
//+------------------------------------------------------------------+
double CalcFibonacciScore(double price, int bar_shift)
{
   int lookback = g_fibo_lookback_bars;
   int end_bar = bar_shift + lookback;
   int available = Bars(_Symbol, PERIOD_CURRENT);
   if(end_bar >= available) end_bar = available - 1;

   // Find swing high and low in lookback range
   double swing_high = -1, swing_low = 999999;
   for(int i = bar_shift; i <= end_bar; i++)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);
      if(h > swing_high) swing_high = h;
      if(l < swing_low)  swing_low = l;
   }

   if(swing_high <= swing_low || swing_high <= 0) return 0;

   double range = swing_high - swing_low;

   // Determine direction: close > midpoint → uptrend (Low→High retrace)
   double midpoint = (swing_high + swing_low) / 2.0;
   double close_recent = iClose(_Symbol, PERIOD_CURRENT, bar_shift);

   // Fib levels
   double fib382, fib500, fib618;
   if(close_recent > midpoint)
   {
      // Uptrend: retrace from High to Low
      fib618 = swing_high - range * 0.618;
      fib500 = swing_high - range * 0.500;
      fib382 = swing_high - range * 0.382;
   }
   else
   {
      // Downtrend: retrace from Low to High
      fib618 = swing_low + range * 0.618;
      fib500 = swing_low + range * 0.500;
      fib382 = swing_low + range * 0.382;
   }

   double tolerance = PipsToPrice(g_fibo_tolerance_pips);

   if(MathAbs(price - fib618) <= tolerance) return 15.0;
   if(MathAbs(price - fib500) <= tolerance) return 10.0;
   if(MathAbs(price - fib382) <= tolerance) return 7.0;

   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate volume score                                            |
//+------------------------------------------------------------------+
double CalcVolumeScore(int bar_shift)
{
   long tick_vol = iVolume(_Symbol, PERIOD_CURRENT, bar_shift);
   if(tick_vol <= 0) return 0;

   // MA20 of volume
   long vol_sum = 0;
   int vol_count = 0;
   for(int i = bar_shift; i < bar_shift + 20; i++)
   {
      long v = iVolume(_Symbol, PERIOD_CURRENT, i);
      if(v > 0) { vol_sum += v; vol_count++; }
   }
   if(vol_count == 0) return 0;
   double vol_ma20 = (double)vol_sum / vol_count;

   if(tick_vol > vol_ma20 * 1.5) return 10.0;
   if(tick_vol > vol_ma20 * 1.2) return 5.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate volume delta bonus                                      |
//+------------------------------------------------------------------+
double CalcVolumeDeltaBonus(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0;
   SReactionPoint &rp = g_rp_array[rp_index];

   double open_f  = iOpen(_Symbol, PERIOD_CURRENT, rp.bar_formed);
   double close_f = iClose(_Symbol, PERIOD_CURRENT, rp.bar_formed);
   if(open_f == 0 || close_f == 0) return 0;

   // Proxy: close > open = buying, close < open = selling
   bool is_buying = (close_f > open_f);

   if(rp.rp_type == RP_SUPPORT)
      return is_buying ? 5.0 : -5.0;
   else
      return is_buying ? -5.0 : 5.0;
}

//+------------------------------------------------------------------+
//| Calculate base score (0-100)                                      |
//+------------------------------------------------------------------+
double CalcBaseScore(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0;
   SReactionPoint &rp = g_rp_array[rp_index];

   double score = 0;

   // 1. Reaction strength (max 25)
   double atr_val = PriceToPips(GetATR14(rp.bar_formed));
   if(atr_val > 0)
      score += MathMin((rp.initial_reaction_pips / atr_val) * 25.0, 25.0);

   // 2. Test count (max 20)
   switch(rp.test_count)
   {
      case 0: break;
      case 1: score += 5.0;  break;
      case 2: score += 12.0; break;
      case 3: score += 20.0; break;
      default:
         score += MathMax(20.0 - (rp.test_count - 3) * 5.0, 5.0);
         break;
   }

   // 3. Candle pattern (max 20)
   switch(rp.candle_pattern)
   {
      case PATTERN_PINBAR:      score += 20.0; break;
      case PATTERN_ENGULFING:   score += 15.0; break;
      case PATTERN_OUTSIDE_BAR: score += 12.0; break;
      case PATTERN_LARGE_WICK:  score += 10.0; break;
      default: break;
   }

   // 4. Fibonacci (max 15)
   score += CalcFibonacciScore(rp.price, rp.bar_formed);

   // 5. Volume (max 10)
   score += CalcVolumeScore(rp.bar_formed);

   // 6. Round number (max 10)
   score += RoundNumberScore(rp.price);

   return MathMin(score, 100.0);
}

//+------------------------------------------------------------------+
//| Calculate final score (calls all modules)                         |
//+------------------------------------------------------------------+
void CalcFinalScore(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint &rp = g_rp_array[rp_index];

   double base = CalcBaseScore(rp_index);
   rp.base_score = base;

   double adjusted = base
      + GetRegimeScoreAdjustment(rp.rp_type)                          // Module A
      - CalcDecayPenalty(rp_index)                                      // Module B
      + CalcRecentBonus(rp_index)                                       // Module B
      + GetSessionScoreAdjustment()                                     // Module E
      + GetDayOfWeekAdjustment()                                        // Day-of-week
      + (rp.is_role_reversed ? 15.0 : 0.0)                            // Role reversal
      + ((rp.is_fresh && rp.test_count == 0) ? 10.0 : 0.0)           // First touch
      + CalcVolumeDeltaBonus(rp_index);                                // Volume delta

   adjusted = MathMax(adjusted, 0.0);

   // Confluence scoring is applied externally by Module D
   rp.final_score = MathMin(adjusted, SCORE_CAP);

   // Classify level
   ClassifyRPLevel(rp_index);
}

//+------------------------------------------------------------------+
//| Classify RP level based on final score                            |
//+------------------------------------------------------------------+
void ClassifyRPLevel(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint &rp = g_rp_array[rp_index];

   if(rp.final_score >= 110)      rp.rp_level = RP_PREMIUM;
   else if(rp.final_score >= 80)  rp.rp_level = RP_LEVEL1;
   else if(rp.final_score >= 60)  rp.rp_level = RP_LEVEL2;
   else if(rp.final_score >= 40)  rp.rp_level = RP_LEVEL3;
   else                           rp.rp_level = RP_HIDDEN;
}

#endif
