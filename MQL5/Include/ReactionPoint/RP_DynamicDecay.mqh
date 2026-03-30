//+------------------------------------------------------------------+
//|                                            RP_DynamicDecay.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module B — Dynamic Decay                   |
//+------------------------------------------------------------------+
#ifndef RP_DYNAMICDECAY_MQH
#define RP_DYNAMICDECAY_MQH

#include "RP_Utils.mqh"

//--- Extern inputs
extern bool Use_Dynamic_Score;

//+------------------------------------------------------------------+
//| Calculate decay penalty for an RP                                 |
//+------------------------------------------------------------------+
double CalcDecayPenalty(int rp_index)
{
   if(!Use_Dynamic_Score) return 0.0;
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;

   SReactionPoint &rp = g_rp_array[rp_index];
   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;
   int bars_since_formed = current_bar - rp.bar_formed;
   if(bars_since_formed < 0) bars_since_formed = 0;

   // Use last event (tested or formed)
   int last_event_bar = (rp.bar_last_tested > 0) ? rp.bar_last_tested : rp.bar_formed;
   int bars_since_event = current_bar - last_event_bar;
   if(bars_since_event < 0) bars_since_event = 0;

   double penalty = 0;
   if(g_decay_interval_bars > 0)
      penalty = ((double)bars_since_event / g_decay_interval_bars) * g_decay_points_per_interval;

   // Extra penalty for very old RP
   if(bars_since_formed > g_max_rp_age_bars)
      penalty += 10.0;

   // Hide extremely old low-score RP
   if(bars_since_formed > 2 * g_max_rp_age_bars && rp.base_score < 80)
      rp.is_active = false;

   return penalty;
}

//+------------------------------------------------------------------+
//| Calculate recent bonus for an RP                                  |
//+------------------------------------------------------------------+
double CalcRecentBonus(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;

   SReactionPoint &rp = g_rp_array[rp_index];

   // Anti-repainting: ONLY use closed bars [1..N], NEVER bar[0]
   double bonus = 0.0;

   // Check bars 1-5 for reaction (candle confirming near zone)
   for(int i = 1; i <= 5; i++)
   {
      double low_i  = iLow(_Symbol, PERIOD_CURRENT, i);
      double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
      double close_i = iClose(_Symbol, PERIOD_CURRENT, i);
      double open_i  = iOpen(_Symbol, PERIOD_CURRENT, i);

      if(low_i == 0 || high_i == 0) continue;

      // Check if bar touches the zone
      bool touches_zone = (low_i <= rp.zone_high && high_i >= rp.zone_low);
      if(!touches_zone) continue;

      // Check for confirming pattern (rejection candle)
      double range = high_i - low_i;
      if(range <= 0) continue;

      if(rp.rp_type == RP_SUPPORT)
      {
         // Bullish rejection: close > open, lower wick significant
         double lower_wick = MathMin(open_i, close_i) - low_i;
         if(close_i > open_i && lower_wick >= range * 0.3)
         {
            bonus = 15.0;
            break;
         }
      }
      else
      {
         // Bearish rejection: close < open, upper wick significant
         double upper_wick = high_i - MathMax(open_i, close_i);
         if(close_i < open_i && upper_wick >= range * 0.3)
         {
            bonus = 15.0;
            break;
         }
      }
   }

   // Check bars 1-10 for test without break (if no reaction found)
   if(bonus < 15.0)
   {
      for(int i = 1; i <= 10; i++)
      {
         double low_i  = iLow(_Symbol, PERIOD_CURRENT, i);
         double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
         double close_i = iClose(_Symbol, PERIOD_CURRENT, i);

         if(low_i == 0) continue;

         bool touches_zone = (low_i <= rp.zone_high && high_i >= rp.zone_low);
         if(!touches_zone) continue;

         // Test without break: bar touched zone but didn't close beyond
         bool held = true;
         if(rp.rp_type == RP_SUPPORT && close_i < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
            held = false;
         if(rp.rp_type == RP_RESISTANCE && close_i > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
            held = false;

         if(touches_zone && held)
         {
            bonus = 8.0;
            break;
         }
      }
   }

   return bonus;
}

//+------------------------------------------------------------------+
//| Update decay for all active RPs                                   |
//+------------------------------------------------------------------+
void UpdateAllDecay()
{
   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;

      int bars_since_formed = current_bar - g_rp_array[i].bar_formed;
      if(bars_since_formed < 0) bars_since_formed = 0;

      // Update display opacity (decay visual)
      double max_age = (double)g_max_rp_age_bars;
      if(max_age <= 0) max_age = 300;

      double opacity = 100.0 - ((double)bars_since_formed / max_age * 70.0);
      opacity = MathMax(opacity, 30.0); // Floor 30%
      g_rp_array[i].display_opacity = opacity;
   }
}

#endif
