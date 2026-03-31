//+------------------------------------------------------------------+
//|                                                RP_Scoring.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Scoring System (Base + Final)              |
//+------------------------------------------------------------------+
#ifndef RP_SCORING_MQH
#define RP_SCORING_MQH

#include "RP_Utils.mqh"

// NOTE: This file calls functions from modules included BEFORE it in Main:
//   RP_RegimeFilter.mqh    → GetRegimeScoreAdj(ENUM_RP_TYPE)
//   RP_DynamicDecay.mqh    → CalcDecayPenalty(int), CalcRecentBonus(int)
//   RP_Session.mqh         → GetSessionScoreAdj(ENUM_SESSION), GetDayOfWeekAdj()
//   RP_MarketStructure.mqh → GetStructureScoreAdj(int), GetLiquiditySweepBonus(int)
//   RP_Confluence.mqh      → GetTrendAlignmentScore(ENUM_RP_TYPE)  [P20]

//+------------------------------------------------------------------+
//| CalcFibonacciScore — multi-leg swing-to-swing fibo scoring (P19) |
//| Checks all valid fibo legs, awards confluence bonus for multi-leg|
//+------------------------------------------------------------------+
double CalcFibonacciScore(double price)
{
   double tolerance = PipsToPrice(g_fibo_tolerance_pips);
   double best_score = 0.0;
   bool   found_in_another_leg = false;
   bool   confluence_bonus_paid = false;

   //--- Scan all valid fibo legs
   for(int i = 0; i < g_fibo_leg_count; i++)
   {
      if(!g_fibo_legs[i].is_valid) continue;

      double score = 0.0;

      if(MathAbs(price - g_fibo_legs[i].fibo_618) <= tolerance)
         score = 10.0;
      else if(MathAbs(price - g_fibo_legs[i].fibo_786) <= tolerance)
         score = 8.0;
      else if(MathAbs(price - g_fibo_legs[i].fibo_500) <= tolerance)
         score = 7.0;
      else if(MathAbs(price - g_fibo_legs[i].fibo_382) <= tolerance)
         score = 4.0;

      //--- Fibo confluence: ONE-TIME +3 bonus when RP aligns with 2+ legs
      if(score > 0.0 && found_in_another_leg && !confluence_bonus_paid)
      {
         score += 3.0;
         confluence_bonus_paid = true;
      }
      if(score > 0.0)
         found_in_another_leg = true;

      if(score > best_score)
         best_score = score;
   }

   //--- Fallback: use backward-compatible cache if no legs found
   if(best_score == 0.0 && g_fibo_leg_count == 0)
   {
      if(g_cached_fibo_618 != 0.0 || g_cached_fibo_500 != 0.0 || g_cached_fibo_382 != 0.0)
      {
         if(MathAbs(price - g_cached_fibo_618) <= tolerance) return 10.0;
         if(MathAbs(price - g_cached_fibo_786) <= tolerance) return 8.0;
         if(MathAbs(price - g_cached_fibo_500) <= tolerance) return 7.0;
         if(MathAbs(price - g_cached_fibo_382) <= tolerance) return 4.0;
      }
   }

   return MathMin(best_score, 13.0); // Cap: 10 base + 3 one-time confluence bonus
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

   if(tick_vol > g_cached_volume_ma20 * 1.5) return 15.0;
   if(tick_vol > g_cached_volume_ma20 * 1.2) return 8.0;
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

   if(min_dist <= 10.0) return 8.0;
   if(min_dist <= 20.0) return 4.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| CalcZonePrecisionScore — reward tight/refined zones (P24d)       |
//| Range: [-5, +13]                                                  |
//+------------------------------------------------------------------+
double CalcZonePrecisionScore(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;
   SReactionPoint &rp = g_rp_array[rp_index];

   double score = 0.0;
   double zone_width = rp.zone_high - rp.zone_low;
   if(zone_width <= 0.0 || g_cached_atr14 <= 0.0) return 0.0;

   double width_ratio = zone_width / g_cached_atr14;

   // 1. Tight zone bonus: width < 0.3x ATR → institutional precision (+5)
   if(width_ratio < 0.30)
      score += 5.0;
   // Penalty: width > 0.8x ATR → zone too wide, low precision (-5)
   else if(width_ratio > 0.80)
      score -= 5.0;

   // 2. Retest-refined zone: tested 2+ times AND zone has shrunk → confirmed by PA (+5)
   if(rp.test_count >= 2)
   {
      double original_width = rp.zone_high_original - rp.zone_low_original;
      if(original_width > 0.0 && zone_width < original_width * 0.85)
         score += 5.0;  // Zone shrunk by at least 15% through retests
   }

   // 3. Wick filter applied → zone targets liquidity grab area (+3)
   if(rp.has_wick_filter)
      score += 3.0;

   return score;  // Range: [-5, +13]
}

//+------------------------------------------------------------------+
//| CalcTestQualityScore — weighted test count (P25a)                 |
//| Replaces flat test_count scoring with quality-aware scoring       |
//| Range: [0, 25]                                                    |
//+------------------------------------------------------------------+
double CalcTestQualityScore(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;
   SReactionPoint &rp = g_rp_array[rp_index];

   // Weighted test count: strong = 1.0, weak = 0.3
   double weighted = (double)rp.strong_test_count + (double)rp.weak_test_count * 0.3;

   // Scoring curve: similar to original but using weighted count
   // 0: 0, 0.3-1: 5, 1.3-2: 12, 2-3: 20, 3+: declining
   if(weighted < 0.1)  return 0.0;
   if(weighted < 1.1)  return 5.0;
   if(weighted < 2.1)  return 12.0;
   if(weighted < 3.1)  return 20.0;

   // 3+ weighted: bonus for strong-dominant, penalty for weak-dominant
   double strong_ratio = (rp.test_count > 0) ?
      (double)rp.strong_test_count / (double)rp.test_count : 0.0;

   if(strong_ratio >= 0.7)
      return 25.0;  // Mostly body rejections = very reliable zone (+5 bonus)

   // Mixed or mostly weak: standard declining curve
   return MathMax(20.0 - (weighted - 3.0) * 5.0, 5.0);
}

//+------------------------------------------------------------------+
//| CalcAbsorptionAdj — detect zone being eaten by volume (P25b)     |
//| Increasing volume across tests = zone weakening                   |
//| Range: [-10, +5]                                                  |
//+------------------------------------------------------------------+
double CalcAbsorptionAdj(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;
   SReactionPoint &rp = g_rp_array[rp_index];

   // Need at least 2 tests to compare volume trend
   int tests_recorded = MathMin(rp.test_vol_index, 4);
   if(tests_recorded < 2) return 0.0;

   // Calculate volume trend direction across recorded tests
   // Read in chronological order from circular buffer
   double sum_early = 0.0;
   double sum_late  = 0.0;
   int    half      = tests_recorded / 2;

   for(int j = 0; j < tests_recorded; j++)
   {
      // Chronological index: oldest first
      int idx = (rp.test_vol_index - tests_recorded + j + 400) % 4;  // +400 to avoid negative modulo
      double vol = rp.test_volumes[idx];
      if(vol <= 0.0) return 0.0;

      if(j < half)
         sum_early += vol;
      else
         sum_late += vol;
   }

   if(sum_early <= 0.0) return 0.0;

   double avg_early = sum_early / (double)half;
   double avg_late  = sum_late / (double)(tests_recorded - half);
   double change    = (avg_late - avg_early) / avg_early;

   // Volume increasing > 50% across tests → zone being absorbed → DANGER
   if(change > 0.50)
      return -10.0;
   // Volume increasing > 20% → moderate concern
   if(change > 0.20)
      return -5.0;
   // Volume decreasing > 30% → sellers/buyers exhausting → zone holding strong
   if(change < -0.30)
      return 5.0;

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

   // 1. Reaction Strength (max 35) — primary factor, institutional interest
   //    Use g_cached_atr14 — do NOT call SafeATR() again
   double atr_pips = PriceToPips(g_cached_atr14);
   if(atr_pips < 0.1) atr_pips = 10.0; // Guard div by zero
   score += MathMin((rp.initial_reaction_pips / atr_pips) * 35.0, 35.0);

   // 2. Test Quality (max 25, was max 20) — P25a: weighted by body vs wick
   score += CalcTestQualityScore(rp_index);

   // 3. Candle Pattern (max 12) — confirmation only, not primary driver
   //    Pattern already saved in rp.candle_pattern at detect time
   switch(rp.candle_pattern)
   {
      case PATTERN_PINBAR:      score += 12.0; break;
      case PATTERN_ENGULFING:   score += 10.0; break;
      case PATTERN_OUTSIDE_BAR: score += 8.0;  break;
      case PATTERN_LARGE_WICK:  score += 6.0;  break;
      default: break;
   }

   // 4. Fibonacci Alignment (max 10) — uses cached fibo levels
   score += CalcFibonacciScore(rp.price);

   // 5. Volume (max 15) — uses cached volume MA20
   score += CalcVolumeScore(rp.bar_formed);

   // 6. Round Number (max 8)
   score += RoundNumberScore(rp.price);

   // BONUS: Volume Delta (can go negative)
   score += CalcVolumeDeltaBonus(rp_index);

   // 7. Zone Precision (P24d): [-5, +13] — reward tight/refined zones
   score += CalcZonePrecisionScore(rp_index);

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
      + GetTrendAlignmentScore(rp.rp_type)             // Multi-TF: [-25, +20] (P20)
      + CalcAbsorptionAdj(rp_index)                    // P25b: [-10, +5]
      + (rp.is_role_reversed ? 15.0 : 0.0)            // Role reversal bonus
      + ((rp.is_fresh && rp.test_count == 0) ? 10.0 : 0.0); // First touch bonus

   adjusted = MathMax(adjusted, 0.0);

   // Confluence scoring is applied externally by Module D (RP_Confluence.mqh)
   rp.final_score = MathMin(adjusted, SCORE_CAP);

   // Classify level
   rp.rp_level = ClassifyRPLevel(rp.final_score);
}

#endif // RP_SCORING_MQH
