//+------------------------------------------------------------------+
//|                                             RP_EntrySetup.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Module C — Entry Setup Generation          |
//+------------------------------------------------------------------+
#ifndef RP_ENTRYSETUP_MQH
#define RP_ENTRYSETUP_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| Sorted price cache for binary search (when g_rp_count > 30)      |
//+------------------------------------------------------------------+
struct SSortedRP
{
   double price;
   int    rp_index;
};

static SSortedRP g_rp_sorted_by_price[];
static int       g_rp_sorted_count = 0;
static int       g_rp_sorted_bar   = -1;  // bar when last updated

//+------------------------------------------------------------------+
//| RebuildSortedCache — once per bar when RP changes                 |
//+------------------------------------------------------------------+
void RebuildSortedCache()
{
   int current_bar = Bars(_Symbol, PERIOD_CURRENT);
   if(current_bar == g_rp_sorted_bar && g_rp_sorted_count > 0)
      return;

   g_rp_sorted_count = 0;
   ArrayResize(g_rp_sorted_by_price, g_rp_count);

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      g_rp_sorted_by_price[g_rp_sorted_count].price    = g_rp_array[i].price;
      g_rp_sorted_by_price[g_rp_sorted_count].rp_index = i;
      g_rp_sorted_count++;
   }

   //--- Insertion sort by price ascending
   for(int i = 1; i < g_rp_sorted_count; i++)
   {
      SSortedRP key = g_rp_sorted_by_price[i];
      int j = i - 1;
      while(j >= 0 && g_rp_sorted_by_price[j].price > key.price)
      {
         g_rp_sorted_by_price[j + 1] = g_rp_sorted_by_price[j];
         j--;
      }
      g_rp_sorted_by_price[j + 1] = key;
   }

   g_rp_sorted_bar = current_bar;
}

//+------------------------------------------------------------------+
//| FindNearestRPInDirection                                          |
//| BUY: find RP_RESISTANCE above from_price                          |
//| SELL: find RP_SUPPORT below from_price                            |
//| skip_count: 0=nearest, 1=second nearest                           |
//| Returns price or 0.0 if not found                                 |
//+------------------------------------------------------------------+
double FindNearestRPInDirection(double from_price, ENUM_RP_TYPE direction, int skip_count)
{
   if(g_rp_count <= 0) return 0.0;

   //--- Use sorted cache for performance when many RPs
   if(g_rp_count > 30)
   {
      RebuildSortedCache();
      return FindNearestSorted(from_price, direction, skip_count);
   }

   //--- Linear search for small RP count
   double candidates[];
   int    cand_count = 0;
   ArrayResize(candidates, 0);

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;

      if(direction == RP_SUPPORT)
      {
         // BUY → find RESISTANCE above
         if(g_rp_array[i].rp_type == RP_RESISTANCE && g_rp_array[i].price > from_price)
         {
            ArrayResize(candidates, cand_count + 1, 10);
            candidates[cand_count] = g_rp_array[i].price;
            cand_count++;
         }
      }
      else
      {
         // SELL → find SUPPORT below
         if(g_rp_array[i].rp_type == RP_SUPPORT && g_rp_array[i].price < from_price)
         {
            ArrayResize(candidates, cand_count + 1, 10);
            candidates[cand_count] = g_rp_array[i].price;
            cand_count++;
         }
      }
   }

   if(cand_count <= skip_count) return 0.0;

   //--- Sort candidates by distance from from_price
   ArraySort(candidates);

   if(direction == RP_SUPPORT)
   {
      // BUY → RESISTANCE above → ascending, closest first
      return (skip_count < cand_count) ? candidates[skip_count] : 0.0;
   }
   else
   {
      // SELL → SUPPORT below → descending (closest to from_price first)
      int idx = cand_count - 1 - skip_count;
      return (idx >= 0) ? candidates[idx] : 0.0;
   }
}

//+------------------------------------------------------------------+
//| FindNearestSorted — binary search version                         |
//+------------------------------------------------------------------+
double FindNearestSorted(double from_price, ENUM_RP_TYPE direction, int skip_count)
{
   int skipped = 0;

   if(direction == RP_SUPPORT)
   {
      //--- BUY → find RESISTANCE above from_price (scan upward)
      for(int i = 0; i < g_rp_sorted_count; i++)
      {
         int idx = g_rp_sorted_by_price[i].rp_index;
         if(g_rp_array[idx].rp_type == RP_RESISTANCE &&
            g_rp_sorted_by_price[i].price > from_price)
         {
            if(skipped >= skip_count)
               return g_rp_sorted_by_price[i].price;
            skipped++;
         }
      }
   }
   else
   {
      //--- SELL → find SUPPORT below from_price (scan downward)
      for(int i = g_rp_sorted_count - 1; i >= 0; i--)
      {
         int idx = g_rp_sorted_by_price[i].rp_index;
         if(g_rp_array[idx].rp_type == RP_SUPPORT &&
            g_rp_sorted_by_price[i].price < from_price)
         {
            if(skipped >= skip_count)
               return g_rp_sorted_by_price[i].price;
            skipped++;
         }
      }
   }

   return 0.0;
}

//+------------------------------------------------------------------+
//| CreateEntrySetup — generate entry with SL/TP for an RP            |
//+------------------------------------------------------------------+
void CreateEntrySetup(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];

   double entry, sl;

   if(rp.rp_type == RP_SUPPORT)
   {
      //--- BUY setup
      entry = RP_High(1) + PipsToPrice(g_entry_buffer_pips);
      sl    = RP_Low(1)  - PipsToPrice(g_sl_buffer_pips);
   }
   else
   {
      //--- SELL setup
      entry = RP_Low(1)  - PipsToPrice(g_entry_buffer_pips);
      sl    = RP_High(1) + PipsToPrice(g_sl_buffer_pips);
   }

   if(entry <= 0.0 || sl <= 0.0) return;

   //--- Calculate SL pips (guard div-by-zero)
   double sl_pips = PriceToPips(MathAbs(entry - sl));
   if(sl_pips < 0.1) sl_pips = 0.1;

   //--- TP1: nearest RP in direction
   double tp1 = FindNearestRPInDirection(entry, rp.rp_type, 0);
   double tp1_rr = 0.0;

   if(tp1 > 0.0)
   {
      double tp1_pips_check = PriceToPips(MathAbs(tp1 - entry));
      tp1_rr = tp1_pips_check / sl_pips;
   }

   //--- Fallback TP1 if not found or R:R too low
   if(tp1 == 0.0 || tp1_rr < g_min_rr_ratio)
   {
      double atr = g_cached_atr14;
      if(atr <= 0.0) atr = PipsToPrice(10);

      if(rp.rp_type == RP_SUPPORT)
         tp1 = entry + atr * 2.0;
      else
         tp1 = entry - atr * 2.0;
   }

   //--- TP2: second nearest RP in direction
   double tp2 = FindNearestRPInDirection(entry, rp.rp_type, 1);
   if(tp2 == 0.0)
   {
      double atr = g_cached_atr14;
      if(atr <= 0.0) atr = PipsToPrice(10);

      if(rp.rp_type == RP_SUPPORT)
         tp2 = entry + atr * 4.0;
      else
         tp2 = entry - atr * 4.0;
   }

   //--- Calculate pip values
   double final_sl_pips  = PriceToPips(MathAbs(entry - sl));
   if(final_sl_pips < 0.1) final_sl_pips = 0.1;
   double final_tp1_pips = PriceToPips(MathAbs(tp1 - entry));
   double final_tp2_pips = PriceToPips(MathAbs(tp2 - entry));

   double rr1 = final_tp1_pips / final_sl_pips;
   double rr2 = final_tp2_pips / final_sl_pips;

   //--- Check if array is full → replace lowest score setup
   int slot = -1;
   if(g_setup_count >= MAX_SETUPS)
   {
      double lowest = DBL_MAX;
      int lowest_idx = 0;
      for(int i = 0; i < g_setup_count; i++)
      {
         if(!g_setup_array[i].is_active)
         {
            slot = i;
            break;
         }
         //--- Find RP score for this setup
         for(int r = 0; r < g_rp_count; r++)
         {
            if(g_rp_array[r].id == g_setup_array[i].rp_id)
            {
               if(g_rp_array[r].final_score < lowest)
               {
                  lowest = g_rp_array[r].final_score;
                  lowest_idx = i;
               }
               break;
            }
         }
      }
      if(slot < 0) slot = lowest_idx;
   }
   else
   {
      slot = g_setup_count;
      g_setup_count++;
   }

   //--- Build setup
   SEntrySetup setup;
   setup.Init();
   setup.rp_id         = rp.id;
   setup.direction     = rp.rp_type;
   setup.entry_price   = entry;
   setup.sl_price      = sl;
   setup.tp1_price     = tp1;
   setup.tp2_price     = tp2;
   setup.rr_ratio1     = rr1;
   setup.rr_ratio2     = rr2;
   setup.sl_pips       = final_sl_pips;
   setup.tp1_pips      = final_tp1_pips;
   setup.tp2_pips      = final_tp2_pips;
   setup.bar_created   = Bars(_Symbol, PERIOD_CURRENT) - 1;
   setup.time_created  = TimeCurrent();
   setup.is_active     = true;

   g_setup_array[slot] = setup;

   //--- Check for conflicting/same-direction setups
   for(int i = 0; i < g_setup_count; i++)
   {
      if(i == slot) continue;
      if(!g_setup_array[i].is_active) continue;

      if(g_setup_array[i].rp_id == rp.id)
      {
         //--- Duplicate RP setup — invalidate older one
         g_setup_array[i].is_active = false;
         g_setup_array[i].is_invalidated = true;
         continue;
      }

      if(g_setup_array[i].direction == setup.direction)
      {
         //--- Same direction → tag PREFERRED for higher-score setup
         double score_new = rp.final_score;
         double score_old = 0.0;
         for(int r = 0; r < g_rp_count; r++)
         {
            if(g_rp_array[r].id == g_setup_array[i].rp_id)
            {
               score_old = g_rp_array[r].final_score;
               break;
            }
         }

         if(score_new >= score_old)
         {
            g_setup_array[slot].is_preferred = true;
            g_setup_array[i].is_preferred    = false;
         }
         else
         {
            g_setup_array[slot].is_preferred = false;
            g_setup_array[i].is_preferred    = true;
         }
      }
      else
      {
         //--- Opposite direction → warning
         Print("WARNING: Conflicting setups — ",
               (setup.direction == RP_SUPPORT ? "BUY" : "SELL"),
               " vs ",
               (g_setup_array[i].direction == RP_SUPPORT ? "BUY" : "SELL"));
      }
   }
}

//+------------------------------------------------------------------+
//| CheckEntryConditions — scan RPs for valid entry triggers          |
//| Called once per new bar                                            |
//+------------------------------------------------------------------+
void CheckEntryConditions()
{
   if(!g_show_entry_setup) return;

   double close_1 = RP_Close(1);
   if(close_1 == 0.0) return;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      if(g_rp_array[i].final_score < g_min_score_to_show) continue;

      SReactionPoint rp = g_rp_array[i];

      //--- a) Price (bar[1] close) must be in zone
      if(close_1 < rp.zone_low || close_1 > rp.zone_high)
         continue;

      //--- b) Bar[1] must have valid candle pattern
      ENUM_CANDLE_PATTERN pattern = DetectCandlePattern(1);
      if(pattern == PATTERN_NONE)
         continue;

      //--- c) Regime not choppy (exception: Premium Confluence score >= 110)
      if(g_current_regime == REGIME_CHOPPY && rp.final_score < 110.0)
         continue;

      //--- d) Spread not blocked
      if(g_spread_blocked)
         continue;

      //--- e) Not in news blackout
      if(g_news_blackout)
         continue;

      //--- f) Trend alignment (P20) — exception: Premium score >= 110
      if(g_use_trend_alignment && !IsTrendAligned(rp.rp_type))
      {
         if(rp.final_score < 110.0)
            continue;
      }

      //--- Check if setup already exists for this RP
      bool already_exists = false;
      for(int s = 0; s < g_setup_count; s++)
      {
         if(g_setup_array[s].rp_id == rp.id && g_setup_array[s].is_active)
         {
            already_exists = true;
            break;
         }
      }
      if(already_exists) continue;

      //--- All conditions passed → create entry setup
      CreateEntrySetup(i);
   }
}

//+------------------------------------------------------------------+
//| UpdateSetups — per-bar heavy updates (age check, entry trigger)   |
//+------------------------------------------------------------------+
void UpdateSetups()
{
   if(!g_show_entry_setup) return;

   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;
   double close_1 = RP_Close(1);

   for(int i = 0; i < g_setup_count; i++)
   {
      if(!g_setup_array[i].is_active) continue;

      SEntrySetup setup = g_setup_array[i];

      //--- a) Age check — expire if too old
      int age = current_bar - setup.bar_created;
      if(age > g_max_setup_age_bars)
      {
         setup.is_active = false;
         g_setup_array[i] = setup;
         continue;
      }

      //--- b) Entry triggered — bar[1] close touches entry price
      if(close_1 > 0.0)
      {
         if(setup.direction == RP_SUPPORT)
         {
            // BUY: close >= entry
            if(close_1 >= setup.entry_price)
               setup.is_triggered = true;
         }
         else
         {
            // SELL: close <= entry
            if(close_1 <= setup.entry_price)
               setup.is_triggered = true;
         }
      }
      g_setup_array[i] = setup;
   }
}

//+------------------------------------------------------------------+
//| UpdateSetupInvalidation — per-tick lightweight SL check           |
//| Called from Main OnCalculate on every tick                         |
//+------------------------------------------------------------------+
void UpdateSetupInvalidation()
{
   if(!g_show_entry_setup) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0) return;

   for(int i = 0; i < g_setup_count; i++)
   {
      if(!g_setup_array[i].is_active) continue;
      if(g_setup_array[i].is_invalidated) continue;

      SEntrySetup setup = g_setup_array[i];

      //--- SL invalidation: if price hits SL level, invalidate
      if(setup.direction == RP_SUPPORT)
      {
         // BUY: invalidate if bid <= SL
         if(bid <= setup.sl_price)
         {
            setup.is_invalidated = true;
            setup.is_active = false;
         }
      }
      else
      {
         // SELL: invalidate if bid >= SL
         if(bid >= setup.sl_price)
         {
            setup.is_invalidated = true;
            setup.is_active = false;
         }
      }
      g_setup_array[i] = setup;
   }
}

#endif // RP_ENTRYSETUP_MQH
