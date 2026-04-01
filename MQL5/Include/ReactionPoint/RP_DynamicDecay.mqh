//+------------------------------------------------------------------+
//|                                            RP_DynamicDecay.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module B — Dynamic Score Decay             |
//+------------------------------------------------------------------+
#ifndef RP_DYNAMICDECAY_MQH
#define RP_DYNAMICDECAY_MQH

#include "RP_Utils.mqh"

// NO extern/input here — reads g_use_dynamic_score, g_decay_interval_bars,
// g_decay_points_per_interval, g_max_rp_age_bars from globals

//+------------------------------------------------------------------+
//| Calculate decay penalty for an RP                                 |
//| - penalty based on bars since last event (formed or tested)       |
//| - extra +10 if beyond max age                                     |
//| - deactivate if 2x max age AND score < 80                        |
//+------------------------------------------------------------------+
double CalcDecayPenalty(int rp_index)
{
   if(!g_use_dynamic_score) return 0.0;
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;

   SReactionPoint rp = g_rp_array[rp_index];
   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   int bars_since_formed = current_bar - rp.bar_formed;
   if(bars_since_formed < 0) bars_since_formed = 0;

   // Use last event (tested or formed)
   int last_event_bar = (rp.bar_last_tested > 0) ? rp.bar_last_tested : rp.bar_formed;
   int bars_since_event = current_bar - last_event_bar;
   if(bars_since_event < 0) bars_since_event = 0;

   // Base decay penalty
   double penalty = 0.0;
   if(g_decay_interval_bars > 0)
      penalty = ((double)bars_since_event / g_decay_interval_bars) * g_decay_points_per_interval;

   // Extra penalty for very old RP
   if(bars_since_formed > g_max_rp_age_bars)
      penalty += 10.0;

   // Cap decay penalty — prevents strong zones from being killed too early
   // Max -35 matches reaction strength max (+35), keeping scoring balanced
   penalty = MathMin(penalty, 35.0);

   // Deactivate extremely old low-score RP
   if(bars_since_formed > 2 * g_max_rp_age_bars && rp.final_score < 80.0)
   {
      rp.is_active = false;
      if(rp_index < ArraySize(g_rp_dirty))
         g_rp_dirty[rp_index] = true;
      g_rp_array[rp_index] = rp;
   }

   return penalty;
}

//+------------------------------------------------------------------+
//| Calculate recent bonus for an RP                                  |
//| CHỈ dùng closed bars [1..N], KHÔNG BAO GIỜ bar[0]                |
//| - Reaction confirmed in bars[1..5] → +15                         |
//| - Test without break in bars[1..10] → +8                         |
//+------------------------------------------------------------------+
double CalcRecentBonus(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;

   SReactionPoint rp = g_rp_array[rp_index];

   // Check bars 1-5 for confirmed reaction
   // (candle touches zone + closes in reaction direction + move >= min_move)
   double min_move;
   if(g_use_adaptive_reaction)
      min_move = SafeATR(14) * g_reaction_atr_multiplier;
   else
      min_move = PipsToPrice(g_min_reaction_move_pips);

   for(int i = 1; i <= 5; i++)
   {
      double h = RP_High(i);
      double l = RP_Low(i);
      double c = RP_Close(i);
      if(h == 0.0 || l == 0.0) continue;

      // Check if bar touches the zone
      bool touches_zone = (l <= rp.zone_high && h >= rp.zone_low);
      if(!touches_zone) continue;

      // Check reaction direction + min move
      if(rp.rp_type == RP_SUPPORT)
      {
         // Price touched support zone, then moved up
         double move_up = c - rp.zone_low;
         if(c > rp.zone_high && move_up >= min_move)
            return 15.0;
      }
      else // RP_RESISTANCE
      {
         // Price touched resistance zone, then moved down
         double move_down = rp.zone_high - c;
         if(c < rp.zone_low && move_down >= min_move)
            return 15.0;
      }
   }

   // Check bars 1-10 for test without break
   for(int i = 1; i <= 10; i++)
   {
      double h = RP_High(i);
      double l = RP_Low(i);
      double c = RP_Close(i);
      if(h == 0.0 || l == 0.0) continue;

      bool touches_zone = (l <= rp.zone_high && h >= rp.zone_low);
      if(!touches_zone) continue;

      // Test without break: touched zone but close didn't exceed breakout threshold
      bool held = true;
      if(rp.rp_type == RP_SUPPORT && c < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
         held = false;
      if(rp.rp_type == RP_RESISTANCE && c > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
         held = false;

      if(held)
         return 8.0;
   }

   return 0.0;
}

//+------------------------------------------------------------------+
//| Update decay + opacity for all active RPs                         |
//| Opacity decays linearly with age, floor at 30%                    |
//| Formula: opacity = max(30, initial - (bars/max_age)*(initial-30)) |
//+------------------------------------------------------------------+
void UpdateAllDecay()
{
   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;

      int bars_since = current_bar - g_rp_array[i].bar_formed;
      if(bars_since < 0) bars_since = 0;

      // Initial opacity based on RP level
      double initial_opacity;
      switch(g_rp_array[i].rp_level)
      {
         case RP_PREMIUM: initial_opacity = 80.0; break;
         case RP_LEVEL1:  initial_opacity = 70.0; break;
         case RP_LEVEL2:  initial_opacity = 50.0; break;
         case RP_LEVEL3:  initial_opacity = 35.0; break;
         default:         initial_opacity = 30.0; break;
      }

      double max_age = (g_max_rp_age_bars > 0) ? (double)g_max_rp_age_bars : 300.0;
      double decay_ratio = (double)bars_since / max_age;
      if(decay_ratio > 1.0) decay_ratio = 1.0;

      double opacity = initial_opacity - decay_ratio * (initial_opacity - 30.0);
      g_rp_array[i].display_opacity = MathMax(30.0, opacity);
   }
}

#endif // RP_DYNAMICDECAY_MQH
