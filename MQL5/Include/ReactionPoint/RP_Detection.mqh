//+------------------------------------------------------------------+
//|                                              RP_Detection.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        RP Detection Logic                         |
//+------------------------------------------------------------------+
#ifndef RP_DETECTION_MQH
#define RP_DETECTION_MQH

#include "RP_Utils.mqh"

//--- Extern inputs
extern bool   Use_Adaptive_Reaction;
extern double Reaction_ATR_Multiplier;

//+------------------------------------------------------------------+
//| Detect candle pattern at bar                                      |
//+------------------------------------------------------------------+
ENUM_CANDLE_PATTERN DetectCandlePattern(int bar_idx)
{
   double high_i  = iHigh(_Symbol, PERIOD_CURRENT, bar_idx);
   double low_i   = iLow(_Symbol, PERIOD_CURRENT, bar_idx);
   double open_i  = iOpen(_Symbol, PERIOD_CURRENT, bar_idx);
   double close_i = iClose(_Symbol, PERIOD_CURRENT, bar_idx);

   if(high_i == 0 || low_i == 0) return PATTERN_NONE;

   double range = high_i - low_i;
   if(range <= 0) return PATTERN_NONE;

   // Size filter
   if(range < PipsToPrice(g_min_candle_size_pips))
      return PATTERN_NONE;

   double body = MathAbs(open_i - close_i);

   // Doji filter
   if(body < range * 0.10)
      return PATTERN_NONE;

   double body_top    = MathMax(open_i, close_i);
   double body_bottom = MathMin(open_i, close_i);
   double upper_wick  = high_i - body_top;
   double lower_wick  = body_bottom - low_i;

   // Pinbar: 1 wick >= 60% range, body <= 25% range, body in opposite 1/3
   if(body <= range * 0.25)
   {
      double third = range / 3.0;
      if(upper_wick >= range * 0.60 && body_bottom <= low_i + third)
         return PATTERN_PINBAR;
      if(lower_wick >= range * 0.60 && body_top >= high_i - third)
         return PATTERN_PINBAR;
   }

   // Engulfing: body[i] engulfs body[i+1], opposite direction
   double open_prev  = iOpen(_Symbol, PERIOD_CURRENT, bar_idx + 1);
   double close_prev = iClose(_Symbol, PERIOD_CURRENT, bar_idx + 1);
   if(open_prev != 0 && close_prev != 0)
   {
      double body_prev = MathAbs(open_prev - close_prev);
      double body_prev_top = MathMax(open_prev, close_prev);
      double body_prev_bot = MathMin(open_prev, close_prev);
      bool bull_curr = close_i > open_i;
      bool bull_prev = close_prev > open_prev;

      if(bull_curr != bull_prev &&
         body_top >= body_prev_top && body_bottom <= body_prev_bot &&
         body_prev > 0 && body >= body_prev * 1.5)
         return PATTERN_ENGULFING;
   }

   // Outside Bar
   double high_prev = iHigh(_Symbol, PERIOD_CURRENT, bar_idx + 1);
   double low_prev  = iLow(_Symbol, PERIOD_CURRENT, bar_idx + 1);
   if(high_prev > 0 && low_prev > 0)
   {
      if(high_i > high_prev && low_i < low_prev)
         return PATTERN_OUTSIDE_BAR;
   }

   // Large Wick: 1 wick >= 40% range, close opposite direction of wick
   if(upper_wick >= range * 0.40 && close_i < open_i) // bearish close with upper wick
      return PATTERN_LARGE_WICK;
   if(lower_wick >= range * 0.40 && close_i > open_i) // bullish close with lower wick
      return PATTERN_LARGE_WICK;

   return PATTERN_NONE;
}

//+------------------------------------------------------------------+
//| Check momentum confirmation for swing                             |
//+------------------------------------------------------------------+
bool CheckMomentumConfirmation(int swing_bar, ENUM_RP_TYPE rp_type)
{
   // Anti-repainting: confirmed on closed bars only
   double min_move;
   if(Use_Adaptive_Reaction)
      min_move = GetATR14(swing_bar) * Reaction_ATR_Multiplier;
   else
      min_move = PipsToPrice(g_min_reaction_move_pips);

   double swing_price = (rp_type == RP_SUPPORT) ?
                        iLow(_Symbol, PERIOD_CURRENT, swing_bar) :
                        iHigh(_Symbol, PERIOD_CURRENT, swing_bar);

   if(swing_price == 0) return false;

   // Check bars after swing for move away
   for(int i = swing_bar - 1; i >= 1; i--) // Never bar[0]
   {
      double close_i = iClose(_Symbol, PERIOD_CURRENT, i);
      if(close_i == 0) continue;

      double move = 0;
      if(rp_type == RP_SUPPORT)
         move = close_i - swing_price; // Price should move UP from support
      else
         move = swing_price - close_i; // Price should move DOWN from resistance

      if(move >= min_move)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Create a new Reaction Point                                       |
//+------------------------------------------------------------------+
void CreateRP(int swing_bar, ENUM_RP_TYPE rp_type, double swing_price, ENUM_CANDLE_PATTERN pattern)
{
   // Check distance from existing RPs
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      double dist = MathAbs(g_rp_array[i].price - swing_price);
      if(PriceToPips(dist) < g_min_rp_distance_pips)
         return; // Too close to existing RP
   }

   // Handle array full
   if(g_rp_count >= MAX_RP_COUNT)
   {
      int evict_idx = EvictRP();
      if(evict_idx >= 0)
      {
         // Move last element to evicted position
         if(evict_idx < g_rp_count - 1)
            g_rp_array[evict_idx] = g_rp_array[g_rp_count - 1];
         g_rp_count--;
      }
      else return;
   }

   // Create new RP
   SReactionPoint rp;
   rp.Init();
   rp.id = g_next_rp_id++;
   rp.rp_type = rp_type;
   rp.price = swing_price;
   rp.zone_high = swing_price + PipsToPrice(g_zone_width_pips / 2.0);
   rp.zone_low  = swing_price - PipsToPrice(g_zone_width_pips / 2.0);
   rp.time_formed = iTime(_Symbol, PERIOD_CURRENT, swing_bar);
   rp.bar_formed = swing_bar;
   rp.source_tf = Period();
   rp.session_formed = g_current_session;
   rp.candle_pattern = pattern;
   rp.is_active = true;
   rp.is_fresh = true;
   rp.display_opacity = 100.0;

   // Calculate initial reaction pips
   double move = 0;
   for(int i = swing_bar - 1; i >= 1; i--)
   {
      double close_i = iClose(_Symbol, PERIOD_CURRENT, i);
      if(close_i == 0) continue;
      double m = (rp_type == RP_SUPPORT) ? close_i - swing_price : swing_price - close_i;
      if(m > move) move = m;
   }
   rp.initial_reaction_pips = PriceToPips(move);

   // Day of week
   MqlDateTime dt;
   TimeToStruct(rp.time_formed, dt);
   rp.day_of_week_formed = dt.day_of_week;

   // Add to array
   if(g_rp_count < MAX_RP_COUNT)
   {
      g_rp_array[g_rp_count] = rp;
      g_rp_count++;
   }
}

//+------------------------------------------------------------------+
//| Detect swing points and create RPs                                |
//+------------------------------------------------------------------+
void DetectSwingPoints(int bars_to_scan)
{
   int available = Bars(_Symbol, PERIOD_CURRENT);
   if(available < g_swing_lookback * 2 + 5)
   {
      Print("Warning: Not enough bars for swing detection");
      return;
   }

   int limit = MathMin(bars_to_scan, available - g_swing_lookback - 1);

   // Anti-repainting: confirmed on closed bars only, start from g_swing_lookback+1
   for(int i = g_swing_lookback + 1; i < limit; i++)
   {
      double high_i = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low_i  = iLow(_Symbol, PERIOD_CURRENT, i);
      if(high_i == 0 || low_i == 0) continue;

      // Check Swing High
      bool is_swing_high = true;
      for(int j = 1; j <= g_swing_lookback; j++)
      {
         double h_left  = iHigh(_Symbol, PERIOD_CURRENT, i + j);
         double h_right = iHigh(_Symbol, PERIOD_CURRENT, i - j);
         if(h_left == 0 || h_right == 0) { is_swing_high = false; break; }
         if(high_i <= h_left || high_i <= h_right) { is_swing_high = false; break; }
      }

      // Check Swing Low
      bool is_swing_low = true;
      for(int j = 1; j <= g_swing_lookback; j++)
      {
         double l_left  = iLow(_Symbol, PERIOD_CURRENT, i + j);
         double l_right = iLow(_Symbol, PERIOD_CURRENT, i - j);
         if(l_left == 0 || l_right == 0) { is_swing_low = false; break; }
         if(low_i >= l_left || low_i >= l_right) { is_swing_low = false; break; }
      }

      // Create Resistance RP from Swing High
      if(is_swing_high)
      {
         ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(i);
         if(CheckMomentumConfirmation(i, RP_RESISTANCE))
            CreateRP(i, RP_RESISTANCE, high_i, pattern);
      }

      // Create Support RP from Swing Low
      if(is_swing_low)
      {
         ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(i);
         if(CheckMomentumConfirmation(i, RP_SUPPORT))
            CreateRP(i, RP_SUPPORT, low_i, pattern);
      }
   }
}

//+------------------------------------------------------------------+
//| Check breakouts and retests for all active RPs                    |
//+------------------------------------------------------------------+
void CheckBreakoutsAndRetests()
{
   // Anti-repainting: use bar[1] for all checks
   double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high_1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low_1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   if(close_1 == 0) return;

   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;

      SReactionPoint &rp = g_rp_array[i];

      // Check test (price enters zone)
      bool in_zone = (low_1 <= rp.zone_high && high_1 >= rp.zone_low);
      if(in_zone)
      {
         // Don't count as test if it's a breakout
         bool is_breakout = false;
         if(rp.rp_type == RP_SUPPORT && close_1 < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
            is_breakout = true;
         if(rp.rp_type == RP_RESISTANCE && close_1 > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
            is_breakout = true;

         if(!is_breakout)
         {
            rp.test_count++;
            rp.is_fresh = false;
            rp.time_last_tested = TimeCurrent();
            rp.bar_last_tested = current_bar;
         }
         else
         {
            // Breakout confirmed — start role reversal monitoring
            HandleBreakout(i, current_bar);
         }
      }

      // Check gap breakout (price passes zone without touching)
      CheckGapBreakout(i, close_1);

      // Check role reversal retest
      CheckRoleReversalRetest(i, current_bar, close_1, high_1, low_1);
   }
}

//+------------------------------------------------------------------+
//| Handle confirmed breakout                                         |
//+------------------------------------------------------------------+
void HandleBreakout(int rp_index, int current_bar)
{
   SReactionPoint &rp = g_rp_array[rp_index];

   // Mark for role reversal monitoring
   // Store breakout bar for retest window
   if(rp.bar_last_tested == 0 || rp.bar_last_tested < current_bar - g_max_retest_bars)
   {
      rp.bar_last_tested = current_bar;
      rp.time_last_tested = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Check for role reversal retest                                    |
//+------------------------------------------------------------------+
void CheckRoleReversalRetest(int rp_index, int current_bar, double close_1, double high_1, double low_1)
{
   SReactionPoint &rp = g_rp_array[rp_index];
   if(rp.is_role_reversed) return; // Already reversed

   // Check if price was beyond the RP (breakout occurred)
   bool was_broken = false;
   if(rp.rp_type == RP_SUPPORT)
   {
      // Support broken = price closed below
      for(int j = 2; j <= g_max_retest_bars && j < current_bar; j++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, j);
         if(c > 0 && c < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
         {
            was_broken = true;
            break;
         }
      }
   }
   else
   {
      // Resistance broken = price closed above
      for(int j = 2; j <= g_max_retest_bars && j < current_bar; j++)
      {
         double c = iClose(_Symbol, PERIOD_CURRENT, j);
         if(c > 0 && c > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
         {
            was_broken = true;
            break;
         }
      }
   }

   if(!was_broken) return;

   // Check if bar[1] is retesting the zone from the other side
   bool retest = (low_1 <= rp.zone_high && high_1 >= rp.zone_low);
   if(!retest) return;

   // Role reversal confirmed
   rp.rp_type = (rp.rp_type == RP_SUPPORT) ? RP_RESISTANCE : RP_SUPPORT;
   rp.is_role_reversed = true;
   rp.final_score += 15.0;
   rp.test_count = 0; // Reset test count after flip
   rp.is_fresh = true;
   rp.time_last_tested = TimeCurrent();
   rp.bar_last_tested = current_bar;

   // If RP is in confluence, detach and re-check
   if(rp.is_confluence)
   {
      rp.is_confluence = false;
      rp.confluence_id = -1;
   }
}

//+------------------------------------------------------------------+
//| Check gap breakout (close crosses RP without touching zone)       |
//+------------------------------------------------------------------+
void CheckGapBreakout(int rp_index, double close_1)
{
   SReactionPoint &rp = g_rp_array[rp_index];

   double close_2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   if(close_2 == 0) return;

   // Gap = both close_2 and close_1 are on the same side past the RP
   // without either bar touching the zone
   double high_1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low_1  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double high_2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   double low_2  = iLow(_Symbol, PERIOD_CURRENT, 2);

   // Check if bar[1] touched the zone
   bool bar1_touches = (low_1 <= rp.zone_high && high_1 >= rp.zone_low);
   bool bar2_touches = (low_2 <= rp.zone_high && high_2 >= rp.zone_low);

   if(bar1_touches || bar2_touches) return; // Not a gap

   if(rp.rp_type == RP_SUPPORT)
   {
      // Was above, now both bars below → gap breakout down
      if(close_2 < rp.zone_low - PipsToPrice(g_breakout_confirm_pips) &&
         close_1 < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
      {
         HandleBreakout(rp_index, Bars(_Symbol, PERIOD_CURRENT) - 1);
      }
   }
   else
   {
      // Was below, now both bars above → gap breakout up
      if(close_2 > rp.zone_high + PipsToPrice(g_breakout_confirm_pips) &&
         close_1 > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
      {
         HandleBreakout(rp_index, Bars(_Symbol, PERIOD_CURRENT) - 1);
      }
   }
}

#endif
