//+------------------------------------------------------------------+
//|                                              RP_Detection.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        RP Detection Logic                         |
//+------------------------------------------------------------------+
#ifndef RP_DETECTION_MQH
#define RP_DETECTION_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| Detect candle pattern at bar                                      |
//+------------------------------------------------------------------+
ENUM_CANDLE_PATTERN DetectCandlePattern(int bar_idx)
{
   if(bar_idx < RP_SHIFT_MIN) return PATTERN_NONE;

   double high_i  = RP_High(bar_idx);
   double low_i   = RP_Low(bar_idx);
   double open_i  = iOpen(_Symbol, PERIOD_CURRENT, bar_idx);
   double close_i = RP_Close(bar_idx);

   if(high_i == 0.0 || low_i == 0.0) return PATTERN_NONE;

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

   // Engulfing: body[i] engulfs body[i+1], opposite direction, body >= 1.5x prev
   double open_prev  = iOpen(_Symbol, PERIOD_CURRENT, bar_idx + 1);
   double close_prev = RP_Close(bar_idx + 1);
   if(open_prev != 0.0 && close_prev != 0.0)
   {
      double body_prev     = MathAbs(open_prev - close_prev);
      double body_prev_top = MathMax(open_prev, close_prev);
      double body_prev_bot = MathMin(open_prev, close_prev);
      bool bull_curr = close_i > open_i;
      bool bull_prev = close_prev > open_prev;

      if(bull_curr != bull_prev &&
         body_top >= body_prev_top && body_bottom <= body_prev_bot &&
         body_prev > 0 && body >= body_prev * 1.5)
         return PATTERN_ENGULFING;
   }

   // Outside Bar: high[i] > high[i+1] AND low[i] < low[i+1], not engulfing
   double high_prev = RP_High(bar_idx + 1);
   double low_prev  = RP_Low(bar_idx + 1);
   if(high_prev > 0.0 && low_prev > 0.0)
   {
      if(high_i > high_prev && low_i < low_prev)
         return PATTERN_OUTSIDE_BAR;
   }

   // Large Wick: 1 wick >= 40% range, close opposite direction of wick
   if(upper_wick >= range * 0.40 && close_i < open_i)
      return PATTERN_LARGE_WICK;
   if(lower_wick >= range * 0.40 && close_i > open_i)
      return PATTERN_LARGE_WICK;

   return PATTERN_NONE;
}

//+------------------------------------------------------------------+
//| Check momentum confirmation for swing                             |
//| Returns true + reaction_pips if price moved enough after swing    |
//+------------------------------------------------------------------+
bool CheckMomentumConfirmation(int swing_bar, ENUM_RP_TYPE rp_type, double &reaction_pips)
{
   reaction_pips = 0.0;

   double min_move;
   if(g_use_adaptive_reaction)
      min_move = SafeATR(14) * g_reaction_atr_multiplier;
   else
      min_move = PipsToPrice(g_min_reaction_move_pips);

   double swing_price = (rp_type == RP_SUPPORT) ?
                        RP_Low(swing_bar) :
                        RP_High(swing_bar);

   if(swing_price == 0.0) return false;

   // Scan closed bars after swing for max move away
   double max_move = 0.0;
   for(int i = swing_bar - 1; i >= 1; i--)
   {
      double close_i = RP_Close(i);
      if(close_i == 0.0) continue;

      double move = 0.0;
      if(rp_type == RP_SUPPORT)
         move = close_i - swing_price;
      else
         move = swing_price - close_i;

      if(move > max_move)
         max_move = move;
   }

   if(max_move >= min_move)
   {
      reaction_pips = PriceToPips(max_move);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Evict an RP slot when array is full                               |
//| Priority: 1) inactive, 2) lowest score non-confluence, 3) oldest |
//+------------------------------------------------------------------+
int EvictRP()
{
   // 1st: find first inactive RP
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active)
         return i;
   }

   // 2nd: find lowest score RP that is NOT in confluence
   int lowest_idx = -1;
   double lowest_score = DBL_MAX;
   for(int i = 0; i < g_rp_count; i++)
   {
      if(g_rp_array[i].is_confluence) continue;
      if(g_rp_array[i].final_score < lowest_score)
      {
         lowest_score = g_rp_array[i].final_score;
         lowest_idx = i;
      }
   }
   if(lowest_idx >= 0)
      return lowest_idx;

   // 3rd: find oldest RP
   int oldest_idx = -1;
   datetime oldest_time = D'2099.01.01';
   for(int i = 0; i < g_rp_count; i++)
   {
      if(g_rp_array[i].time_formed < oldest_time)
      {
         oldest_time = g_rp_array[i].time_formed;
         oldest_idx = i;
      }
   }
   if(oldest_idx >= 0)
      return oldest_idx;

   // All active + confluence — cannot evict
   Print("ERROR: EvictRP — all RPs active + confluence, cannot evict");
   return -1;
}

//+------------------------------------------------------------------+
//| Create a new Reaction Point                                       |
//+------------------------------------------------------------------+
void CreateRP(ENUM_RP_TYPE rp_type, int bar_index, double price,
              ENUM_CANDLE_PATTERN pattern, double reaction_pips)
{
   // Check distance from existing RPs
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      double dist = MathAbs(g_rp_array[i].price - price);
      if(PriceToPips(dist) < g_min_rp_distance_pips)
         return;
   }

   // Handle array full — evict
   int slot = -1;
   if(g_rp_count >= MAX_RP_COUNT)
   {
      int evict_idx = EvictRP();
      if(evict_idx < 0) return;
      slot = evict_idx;
      g_rp_dirty[evict_idx] = true;
   }
   else
   {
      slot = g_rp_count;
      g_rp_count++;
   }

   // Create new RP
   SReactionPoint rp;
   rp.Init();
   rp.id                   = g_next_rp_id++;
   rp.rp_type              = rp_type;
   rp.price                = price;

   //--- Dynamic zone width from actual candle at swing point (P21)
   double bar_open  = iOpen(_Symbol, PERIOD_CURRENT, bar_index);
   double bar_close = iClose(_Symbol, PERIOD_CURRENT, bar_index);
   double bar_high  = iHigh(_Symbol, PERIOD_CURRENT, bar_index);
   double bar_low   = iLow(_Symbol, PERIOD_CURRENT, bar_index);

   if(rp_type == RP_SUPPORT)
   {
      rp.zone_low  = bar_low;
      rp.zone_high = MathMax(bar_open, bar_close);
   }
   else // RP_RESISTANCE
   {
      rp.zone_high = bar_high;
      rp.zone_low  = MathMin(bar_open, bar_close);
   }

   //--- P24a: Wick Ratio Filter — trim zone when wick dominates candle
   //    When wick >= 60% of range, zone focuses on the 30% nearest the reaction edge
   //    Uses bar_range as basis (not body_size) to avoid ultra-thin zones on pinbars
   double bar_range   = bar_high - bar_low;

   if(bar_range > 0.0)
   {
      double body_top    = MathMax(bar_open, bar_close);
      double body_bottom = MathMin(bar_open, bar_close);
      double upper_wick  = bar_high - body_top;
      double lower_wick  = body_bottom - bar_low;
      double trim_width  = bar_range * 0.30;  // zone = 30% of candle range

      if(rp_type == RP_SUPPORT && lower_wick >= bar_range * 0.60)
      {
         // Long lower wick: liquidity grab at bottom → zone hugs the wick tip area
         rp.zone_low  = bar_low;
         rp.zone_high = bar_low + trim_width;
         rp.has_wick_filter = true;
      }
      else if(rp_type == RP_RESISTANCE && upper_wick >= bar_range * 0.60)
      {
         // Long upper wick: liquidity grab at top → zone hugs the wick tip area
         rp.zone_high = bar_high;
         rp.zone_low  = bar_high - trim_width;
         rp.has_wick_filter = true;
      }
   }

   //--- P24b: ATR-Adaptive Width Cap by timeframe
   double min_width  = PipsToPrice(g_zone_width_pips / 2.0);
   double atr_multiplier = 1.0;
   ENUM_TIMEFRAMES tf = Period();
   if(tf <= PERIOD_M15)
      atr_multiplier = 0.5;
   else if(tf <= PERIOD_H4)
      atr_multiplier = 0.7;
   else
      atr_multiplier = 1.0;

   double max_width  = (g_cached_atr14 > 0.0) ? g_cached_atr14 * atr_multiplier : PipsToPrice(30);

   //--- Safety clamps
   double zone_range = rp.zone_high - rp.zone_low;

   if(zone_range < min_width)
   {
      double center = (rp.zone_high + rp.zone_low) / 2.0;
      rp.zone_high = center + min_width / 2.0;
      rp.zone_low  = center - min_width / 2.0;
      zone_range = min_width;  // Update after clamp
   }

   if(zone_range > max_width)
   {
      if(rp_type == RP_SUPPORT)
         rp.zone_high = rp.zone_low + max_width;
      else
         rp.zone_low = rp.zone_high - max_width;
   }
   //--- P24c: Save original zone edges for retest refinement reference
   rp.zone_high_original   = rp.zone_high;
   rp.zone_low_original    = rp.zone_low;

   rp.time_formed          = iTime(_Symbol, PERIOD_CURRENT, bar_index);
   rp.bar_formed           = bar_index;
   rp.source_tf            = Period();
   rp.session_formed       = g_current_session;
   rp.candle_pattern       = pattern;
   rp.initial_reaction_pips= reaction_pips;
   rp.is_active            = true;
   rp.is_fresh             = true;
   rp.test_count           = 0;
   rp.confluence_id        = -1;

   // Day of week
   MqlDateTime dt;
   TimeToStruct(rp.time_formed, dt);
   rp.day_of_week_formed = dt.day_of_week;

   // Display opacity based on level (initially HIDDEN until scored)
   rp.display_opacity = 100.0;

   // Store
   g_rp_array[slot] = rp;
   g_rp_dirty[slot] = true;

   // P26: Log zone creation
   LogZoneCreated(rp);
}

//+------------------------------------------------------------------+
//| Detect swing points and create RPs                                |
//+------------------------------------------------------------------+
void DetectSwingPoints(int bars_to_scan)
{
   int available = Bars(_Symbol, PERIOD_CURRENT);
   if(available < g_swing_lookback * 2 + 5)
   {
      Print("Warning: Not enough bars for swing detection (have ", available, ", need ", g_swing_lookback * 2 + 5, ")");
      return;
   }

   int limit = MathMin(bars_to_scan, available - g_swing_lookback - 1);
   int N = g_swing_lookback;

   //--- Batch copy price data ONCE (replaces thousands of RP_High/RP_Low calls)
   double highs[], lows[];
   int copy_count = limit + N + 1;
   int copied_h = CopyHigh(_Symbol, PERIOD_CURRENT, 0, copy_count, highs);
   int copied_l = CopyLow(_Symbol, PERIOD_CURRENT, 0, copy_count, lows);
   if(copied_h <= 0 || copied_l <= 0) return;
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   int safe_limit = MathMin(limit, copied_h - N - 1);

   // Anti-repainting: start from N+1 (confirmed closed bars only)
   for(int i = N + 1; i < safe_limit; i++)
   {
      double high_i = highs[i];
      double low_i  = lows[i];
      if(high_i == 0.0 || low_i == 0.0) continue;

      // Check Swing High: high[i] > N bars left AND N bars right
      bool is_swing_high = true;
      for(int j = 1; j <= N; j++)
      {
         if(high_i <= highs[i + j] || high_i <= highs[i - j])
         { is_swing_high = false; break; }
      }

      // Check Swing Low: low[i] < N bars left AND N bars right
      bool is_swing_low = true;
      for(int j = 1; j <= N; j++)
      {
         if(low_i >= lows[i + j] || low_i >= lows[i - j])
         { is_swing_low = false; break; }
      }

      // Create Resistance RP from Swing High
      if(is_swing_high)
      {
         ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(i);
         double reaction_pips = 0.0;
         if(CheckMomentumConfirmation(i, RP_RESISTANCE, reaction_pips))
            CreateRP(RP_RESISTANCE, i, high_i, pattern, reaction_pips);
      }

      // Create Support RP from Swing Low
      if(is_swing_low)
      {
         ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(i);
         double reaction_pips = 0.0;
         if(CheckMomentumConfirmation(i, RP_SUPPORT, reaction_pips))
            CreateRP(RP_SUPPORT, i, low_i, pattern, reaction_pips);
      }
   }
}

//+------------------------------------------------------------------+
//| Handle confirmed breakout — start role reversal monitoring        |
//+------------------------------------------------------------------+
void HandleBreakout(int rp_index, int current_bar)
{
   SReactionPoint rp = g_rp_array[rp_index];

   rp.bar_last_tested  = current_bar;
   rp.time_last_tested = TimeCurrent();
   g_rp_array[rp_index] = rp;
   g_rp_dirty[rp_index] = true;
}

//+------------------------------------------------------------------+
//| Check for role reversal retest                                    |
//+------------------------------------------------------------------+
void CheckRoleReversalRetest(int rp_index, int current_bar,
                             double close_1, double high_1, double low_1)
{
   SReactionPoint rp = g_rp_array[rp_index];
   if(rp.is_role_reversed) return;

   // Check if price was beyond the RP within retest window (breakout occurred)
   bool was_broken = false;
   int max_bars = MathMin(g_max_retest_bars, current_bar - 1);

   if(rp.rp_type == RP_SUPPORT)
   {
      for(int j = 2; j <= max_bars; j++)
      {
         double c = RP_Close(j);
         if(c > 0.0 && c < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
         {
            was_broken = true;
            break;
         }
      }
   }
   else
   {
      for(int j = 2; j <= max_bars; j++)
      {
         double c = RP_Close(j);
         if(c > 0.0 && c > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
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
   rp.test_count = 0;
   rp.strong_test_count = 0;       // P25a: reset quality counters
   rp.weak_test_count   = 0;       // P25a: reset quality counters
   ArrayInitialize(rp.test_volumes, 0.0);  // P25b: reset volume history
   rp.test_vol_index    = 0;       // P25b: reset volume index
   rp.is_fresh = true;
   rp.time_last_tested = TimeCurrent();
   rp.bar_last_tested = current_bar;

   // If RP is in confluence, detach and trigger re-check
   if(rp.is_confluence)
   {
      rp.is_confluence = false;
      rp.confluence_id = -1;
      g_confluence_needs_update = true;
   }

   g_rp_array[rp_index] = rp;
   g_rp_dirty[rp_index] = true;
}

//+------------------------------------------------------------------+
//| Check gap breakout (close crosses RP without touching zone)       |
//+------------------------------------------------------------------+
void CheckGapBreakout(int rp_index, double close_1)
{
   SReactionPoint rp = g_rp_array[rp_index];

   double close_2 = RP_Close(2);
   if(close_2 == 0.0) return;

   double high_1 = RP_High(1);
   double low_1  = RP_Low(1);
   double high_2 = RP_High(2);
   double low_2  = RP_Low(2);

   // Check if either bar touched the zone
   bool bar1_touches = (low_1 <= rp.zone_high && high_1 >= rp.zone_low);
   bool bar2_touches = (low_2 <= rp.zone_high && high_2 >= rp.zone_low);

   if(bar1_touches || bar2_touches) return; // Not a gap

   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   if(rp.rp_type == RP_SUPPORT)
   {
      // Both bars below → gap breakout down
      if(close_2 < rp.zone_low - PipsToPrice(g_breakout_confirm_pips) &&
         close_1 < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
      {
         HandleBreakout(rp_index, current_bar);
      }
   }
   else
   {
      // Both bars above → gap breakout up
      if(close_2 > rp.zone_high + PipsToPrice(g_breakout_confirm_pips) &&
         close_1 > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
      {
         HandleBreakout(rp_index, current_bar);
      }
   }
}

//+------------------------------------------------------------------+
//| Check breakouts and retests for all active RPs                    |
//+------------------------------------------------------------------+
void CheckBreakoutsAndRetests()
{
   // Anti-repainting: use bar[1] for all checks
   double close_1 = RP_Close(1);
   double high_1  = RP_High(1);
   double low_1   = RP_Low(1);
   if(close_1 == 0.0) return;

   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;

      SReactionPoint rp = g_rp_array[i];

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

            //--- P25a: Test Quality — classify strong (body) vs weak (wick-only)
            //    Body rejection: close is inside or beyond zone = price truly engaged
            //    Wick touch: only wick entered zone, body stayed outside = weak signal
            bool is_body_test = false;
            double open_1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
            if(rp.rp_type == RP_SUPPORT)
            {
               // Body test: close or open entered the zone (not just wick)
               double body_low = MathMin(open_1, close_1);
               is_body_test = (body_low <= rp.zone_high && body_low >= rp.zone_low);
            }
            else
            {
               double body_high = MathMax(open_1, close_1);
               is_body_test = (body_high >= rp.zone_low && body_high <= rp.zone_high);
            }

            if(is_body_test)
               rp.strong_test_count++;
            else
               rp.weak_test_count++;

            //--- P25b: Zone Absorption — track volume at each test
            long test_tick_vol = iVolume(_Symbol, PERIOD_CURRENT, 1);
            rp.test_volumes[rp.test_vol_index % 4] = (double)test_tick_vol;
            rp.test_vol_index++;

            //--- P26: Capture zone width before refinement for logging
            double zone_width_before_refine = rp.zone_high - rp.zone_low;

            //--- P24c: Re-test Refinement — tighten zone to actual reaction point
            //    Uses weighted average: new_edge = old_edge * 0.6 + reaction * 0.4
            //    This prevents a single shallow touch from locking zone too tight.
            //    Zone can expand back toward original if deeper test occurs.
            double min_zone = PipsToPrice(g_zone_width_pips / 2.0);

            if(rp.rp_type == RP_SUPPORT)
            {
               // Support: low_1 is where price actually rejected
               // Handles both shallow tests (shrink) and deeper tests (expand back)
               if(low_1 >= rp.zone_low_original)
               {
                  double target = rp.zone_low * 0.6 + low_1 * 0.4;
                  target = MathMax(target, rp.zone_low_original);
                  if(rp.zone_high - target >= min_zone)
                     rp.zone_low = target;
               }
            }
            else // RP_RESISTANCE
            {
               if(high_1 <= rp.zone_high_original)
               {
                  double target = rp.zone_high * 0.6 + high_1 * 0.4;
                  target = MathMin(target, rp.zone_high_original);
                  if(target - rp.zone_low >= min_zone)
                     rp.zone_high = target;
               }
            }

            //--- P26: Log test event
            LogZoneTest(rp, is_body_test, zone_width_before_refine,
                        rp.zone_high - rp.zone_low,
                        low_1, high_1, close_1, test_tick_vol);

            g_rp_array[i] = rp;
            g_rp_dirty[i] = true;
         }
         else
         {
            // Breakout confirmed
            LogZoneBroken(rp);  // P26: Log breakout
            HandleBreakout(i, current_bar);
         }
      }

      // Check gap breakout (price passes zone without touching)
      CheckGapBreakout(i, close_1);

      // Check role reversal retest
      CheckRoleReversalRetest(i, current_bar, close_1, high_1, low_1);
   }

   //--- Check confluence zone tests: price may enter confluence zone
   //    without entering individual RP zones
   CheckConfluenceZoneTests(close_1, high_1, low_1, current_bar);
}

//+------------------------------------------------------------------+
//| CheckConfluenceZoneTests                                           |
//| When price enters a confluence zone, update test_count for the     |
//| best RP in that zone (even if price didn't hit individual RP zone) |
//+------------------------------------------------------------------+
void CheckConfluenceZoneTests(double close_1, double high_1, double low_1, int current_bar)
{
   for(int z = 0; z < g_confluence_count; z++)
   {
      //--- Check if price entered confluence zone
      bool in_conf_zone = (low_1 <= g_confluence_array[z].zone_high &&
                           high_1 >= g_confluence_array[z].zone_low);
      if(!in_conf_zone) continue;

      //--- Find best RP in this confluence zone
      int best_idx = -1;
      double best_score = -1.0;
      for(int k = 0; k < g_confluence_array[z].rp_count; k++)
      {
         int rp_id = g_confluence_array[z].rp_ids[k];
         for(int r = 0; r < g_rp_count; r++)
         {
            if(g_rp_array[r].id == rp_id && g_rp_array[r].is_active)
            {
               if(g_rp_array[r].final_score > best_score)
               {
                  best_score = g_rp_array[r].final_score;
                  best_idx = r;
               }
               break;
            }
         }
      }
      if(best_idx < 0) continue;

      //--- Skip if this RP was already tested on this bar (by individual zone check)
      if(g_rp_array[best_idx].bar_last_tested == current_bar) continue;

      //--- Check it's not a breakout
      bool is_breakout = false;
      if(g_confluence_array[z].zone_type == RP_SUPPORT &&
         close_1 < g_confluence_array[z].zone_low - PipsToPrice(g_breakout_confirm_pips))
         is_breakout = true;
      if(g_confluence_array[z].zone_type == RP_RESISTANCE &&
         close_1 > g_confluence_array[z].zone_high + PipsToPrice(g_breakout_confirm_pips))
         is_breakout = true;
      if(is_breakout) continue;

      //--- Update test on best RP
      g_rp_array[best_idx].test_count++;
      g_rp_array[best_idx].is_fresh = false;
      g_rp_array[best_idx].time_last_tested = TimeCurrent();
      g_rp_array[best_idx].bar_last_tested  = current_bar;
      g_rp_dirty[best_idx] = true;
   }
}

#endif // RP_DETECTION_MQH
