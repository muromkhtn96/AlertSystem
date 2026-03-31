//+------------------------------------------------------------------+
//|                                                RP_Scoring.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Scoring System (Base + Final)              |
//+------------------------------------------------------------------+
#ifndef RP_SCORING_MQH
#define RP_SCORING_MQH

#include "RP_Utils.mqh"

// NOTE: This file calls functions from modules included BEFORE it in Main:
//   RP_RegimeFilter.mqh  → GetRegimeScoreAdj(ENUM_RP_TYPE)
//   RP_DynamicDecay.mqh  → CalcDecayPenalty(int), CalcRecentBonus(int)
//   RP_Session.mqh       → GetSessionScoreAdj(ENUM_SESSION), GetDayOfWeekAdj()
//   RP_MarketStructure.mqh → GetStructureScoreAdj(int), GetLiquiditySweepBonus(int)

//+------------------------------------------------------------------+
//| CalcFibonacciScore — uses cached fibo levels from UpdateFiboCache |
//+------------------------------------------------------------------+
double CalcFibonacciScore(double price)
{
   // Use cached fibo levels — no recalculation per RP
   if(g_cached_fibo_618 == 0.0 && g_cached_fibo_500 == 0.0 && g_cached_fibo_382 == 0.0)
      return 0.0;

   double tolerance = PipsToPrice(g_fibo_tolerance_pips);

   if(MathAbs(price - g_cached_fibo_618) <= tolerance) return 15.0;
   if(MathAbs(price - g_cached_fibo_500) <= tolerance) return 10.0;
   if(MathAbs(price - g_cached_fibo_382) <= tolerance) return 7.0;

   return 0.0;
}

//+------------------------------------------------------------------+
//| CalcVolumeScore — uses cached volume MA20                         |
//+------------------------------------------------------------------+
double CalcVolumeScore(int bar_shift)
{
   long tick_vol = iVolume(_Symbol, PERIOD_CURRENT, bar_shift);
   if(tick_vol <= 0) return 0.0;

   // Use cached MA20 from UpdateBarCache
   if(g_cached_volume_ma20 <= 0.0) return 0.0;

   if(tick_vol > g_cached_volume_ma20 * 1.5) return 10.0;
   if(tick_vol > g_cached_volume_ma20 * 1.2) return 5.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| CalcVolumeDeltaBonus — proxy buy/sell volume via candle direction  |
//+------------------------------------------------------------------+
double CalcVolumeDeltaBonus(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;
   SReactionPoint &rp = g_rp_array[rp_index];

   double open_f  = iOpen(_Symbol, PERIOD_CURRENT, rp.bar_formed);
   double close_f = iClose(_Symbol, PERIOD_CURRENT, rp.bar_formed);
   if(open_f == 0.0 || close_f == 0.0) return 0.0;

   bool is_buying = (close_f > open_f);

   if(rp.rp_type == RP_SUPPORT)
      return is_buying ? 5.0 : -5.0;
   else
      return is_buying ? -5.0 : 5.0;
}

//+------------------------------------------------------------------+
//| RoundNumberScore — distance to nearest x.x000 or x.x500          |
//+------------------------------------------------------------------+
double RoundNumberScore(double price)
{
   if(price <= 0.0) return 0.0;

   // Nearest round number: x.x000 or x.x500
   double pip = PipValue();
   if(pip <= 0.0) return 0.0;

   // Scale to find distance to nearest 100-pip or 50-pip level
   double price_in_pips = price / pip;
   double remainder_100 = MathMod(price_in_pips, 100.0);
   double remainder_50  = MathMod(price_in_pips, 50.0);

   // Distance to nearest 100-pip level
   double dist_100 = MathMin(remainder_100, 100.0 - remainder_100);
   // Distance to nearest 50-pip level
   double dist_50  = MathMin(remainder_50, 50.0 - remainder_50);

   double min_dist = MathMin(dist_100, dist_50);

   if(min_dist <= 10.0) return 10.0;
   if(min_dist <= 20.0) return 5.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| CalcBaseScore (0-100)                                             |
//| ONLY called when g_rp_dirty[rp_index] == true                    |
//| Uses cached values — no recalculation                            |
//+------------------------------------------------------------------+
double CalcBaseScore(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;
   SReactionPoint &rp = g_rp_array[rp_index];

   double score = 0.0;

   // 1. Reaction Strength (max 25)
   //    Use g_cached_atr14 — do NOT call SafeATR() again
   double atr_pips = PriceToPips(g_cached_atr14);
   if(atr_pips < 0.1) atr_pips = 10.0; // Guard div by zero
   score += MathMin((rp.initial_reaction_pips / atr_pips) * 25.0, 25.0);

   // 2. Test Count (max 20)
   switch(rp.test_count)
   {
      case 0:  break;
      case 1:  score += 5.0;  break;
      case 2:  score += 12.0; break;
      case 3:  score += 20.0; break;
      default:
         score += MathMax(20.0 - (rp.test_count - 3) * 5.0, 5.0);
         break;
   }

   // 3. Candle Pattern (max 20)
   //    Pattern already saved in rp.candle_pattern at detect time
   switch(rp.candle_pattern)
   {
      case PATTERN_PINBAR:      score += 20.0; break;
      case PATTERN_ENGULFING:   score += 15.0; break;
      case PATTERN_OUTSIDE_BAR: score += 12.0; break;
      case PATTERN_LARGE_WICK:  score += 10.0; break;
      default: break;
   }

   // 4. Fibonacci Alignment (max 15) — uses cached fibo levels
   score += CalcFibonacciScore(rp.price);

   // 5. Volume (max 10) — uses cached volume MA20
   score += CalcVolumeScore(rp.bar_formed);

   // 6. Round Number (max 10)
   score += RoundNumberScore(rp.price);

   // BONUS: Volume Delta (can go negative)
   score += CalcVolumeDeltaBonus(rp_index);

   return MathMin(score, 100.0);
}

//+------------------------------------------------------------------+
//| CalcFinalScore — aggregates all module adjustments                |
//| Called only when g_rp_dirty[rp_index] == true                    |
//+------------------------------------------------------------------+
void CalcFinalScore(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint &rp = g_rp_array[rp_index];

   // Calculate base score
   rp.base_score = CalcBaseScore(rp_index);

   double adjusted = rp.base_score
      + GetRegimeScoreAdj(rp.rp_type)                 // Module A: [-30, +20]
      - CalcDecayPenalty(rp_index)                     // Module B: [0, -35+]
      + CalcRecentBonus(rp_index)                      // Module B: [0, +15]
      + GetSessionScoreAdj(rp.session_formed)          // Module E: [-20, +15]
      + GetDayOfWeekAdj()                              // [-10, +5]
      + GetStructureScoreAdj(rp_index)                 // Module H: [-20, +15]
      + GetLiquiditySweepBonus(rp_index)               // Module H: [0, +20]
      + (rp.is_role_reversed ? 15.0 : 0.0)            // Role reversal bonus
      + ((rp.is_fresh && rp.test_count == 0) ? 10.0 : 0.0); // First touch bonus

   adjusted = MathMax(adjusted, 0.0);

   // Confluence scoring is applied externally by Module D (RP_Confluence.mqh)
   rp.final_score = MathMin(adjusted, SCORE_CAP);

   // Classify level
   rp.rp_level = ClassifyRPLevel(rp.final_score);
}

#endif // RP_SCORING_MQH
