//+------------------------------------------------------------------+
//|                                              RP_Confluence.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module D — Multi-TF Confluence Zones       |
//+------------------------------------------------------------------+
#ifndef RP_CONFLUENCE_MQH
#define RP_CONFLUENCE_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| HTF swing point cache                                             |
//+------------------------------------------------------------------+
struct SHTFSwingPoint
{
   double           price;
   ENUM_RP_TYPE     rp_type;
   ENUM_TIMEFRAMES  source_tf;
   datetime         time_formed;
};

static SHTFSwingPoint g_htf_swing_cache[];
static int            g_htf_swing_count = 0;

//+------------------------------------------------------------------+
//| CollectHTFReactionPoints                                          |
//| Only called when IsNewBarHTF() == true or cache invalid           |
//+------------------------------------------------------------------+
void CollectHTFReactionPoints()
{
   if(!g_use_confluence_zones) return;

   g_htf_swing_count = 0;
   ArrayResize(g_htf_swing_cache, 0);

   //--- Collect from both HTF timeframes
   CollectHTFSwings(g_htf_1);
   CollectHTFSwings(g_htf_2);

   g_htf1_cache_valid = true;
   g_htf2_cache_valid = true;
}

//+------------------------------------------------------------------+
//| CollectHTFSwings — batch copy + swing detect on one HTF           |
//+------------------------------------------------------------------+
void CollectHTFSwings(ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_CURRENT) return;

   double htf_high[], htf_low[], htf_close[];
   datetime htf_time[];

   //--- Batch copy — 1 call = N bars (performance)
   int bars_needed = g_htf_bars_to_scan;
   int copied_h = -1, copied_l = -1, copied_c = -1, copied_t = -1;

   for(int retry = 0; retry < MAX_HTF_RETRIES; retry++)
   {
      copied_h = CopyHigh(_Symbol, tf, 0, bars_needed, htf_high);
      copied_l = CopyLow(_Symbol, tf, 0, bars_needed, htf_low);
      copied_c = CopyClose(_Symbol, tf, 0, bars_needed, htf_close);
      copied_t = CopyTime(_Symbol, tf, 0, bars_needed, htf_time);

      if(copied_h > 0 && copied_l > 0 && copied_c > 0 && copied_t > 0)
         break;

      if(retry < MAX_HTF_RETRIES - 1)
         Print("WARNING: HTF data retry ", retry + 1, " for ", TFToString(tf));
   }

   int bars_avail = MathMin(MathMin(copied_h, copied_l), MathMin(copied_c, copied_t));
   if(bars_avail <= 0)
   {
      Print("WARNING: HTF data unavailable for ", TFToString(tf), " — fallback to current TF only");
      return;
   }

   //--- Set as series (index 0 = newest)
   ArraySetAsSeries(htf_high, true);
   ArraySetAsSeries(htf_low, true);
   ArraySetAsSeries(htf_close, true);
   ArraySetAsSeries(htf_time, true);

   int N = g_swing_lookback;

   //--- Detect swing points on HTF (anti-repainting: start from N+1)
   for(int i = N + 1; i < bars_avail - N; i++)
   {
      //--- Swing High
      bool is_swing_high = true;
      for(int j = 1; j <= N; j++)
      {
         if(htf_high[i] <= htf_high[i + j] || htf_high[i] <= htf_high[i - j])
         {
            is_swing_high = false;
            break;
         }
      }

      //--- Swing Low
      bool is_swing_low = true;
      for(int j = 1; j <= N; j++)
      {
         if(htf_low[i] >= htf_low[i + j] || htf_low[i] >= htf_low[i - j])
         {
            is_swing_low = false;
            break;
         }
      }

      if(is_swing_high)
         AddHTFSwing(htf_high[i], RP_RESISTANCE, tf, htf_time[i]);

      if(is_swing_low)
         AddHTFSwing(htf_low[i], RP_SUPPORT, tf, htf_time[i]);
   }
}

//+------------------------------------------------------------------+
//| Add HTF swing to cache                                            |
//+------------------------------------------------------------------+
void AddHTFSwing(double price, ENUM_RP_TYPE rp_type, ENUM_TIMEFRAMES tf, datetime time_formed)
{
   int size = ArraySize(g_htf_swing_cache);
   ArrayResize(g_htf_swing_cache, size + 1, 50); // Reserve 50 extra

   g_htf_swing_cache[size].price       = price;
   g_htf_swing_cache[size].rp_type     = rp_type;
   g_htf_swing_cache[size].source_tf   = tf;
   g_htf_swing_cache[size].time_formed = time_formed;
   g_htf_swing_count = size + 1;
}

//+------------------------------------------------------------------+
//| Price entry for merge sorting (must be at global scope in MQL5)   |
//+------------------------------------------------------------------+
struct SPriceEntry
{
   double           price;
   int              rp_index;     // >=0 for current TF RP, -1 for HTF
   ENUM_RP_TYPE     rp_type;
   ENUM_TIMEFRAMES  source_tf;
};

//+------------------------------------------------------------------+
//| MergeClusterZones — sort-based O(N log N)                         |
//+------------------------------------------------------------------+
void MergeClusterZones()
{
   if(!g_use_confluence_zones) return;

   //--- Reset confluence arrays
   g_confluence_count = 0;
   for(int i = 0; i < g_rp_count; i++)
   {
      g_rp_array[i].is_confluence = false;
      g_rp_array[i].confluence_id = -1;
   }

   //--- Build combined price list: current TF RPs + HTF swings
   int total = 0;
   SPriceEntry entries[];

   //--- Pre-allocate once (no per-iteration ArrayResize)
   int max_entries = g_rp_count + g_htf_swing_count;
   ArrayResize(entries, max_entries);

   //--- Add current TF active RPs
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      entries[total].price    = g_rp_array[i].price;
      entries[total].rp_index = i;
      entries[total].rp_type  = g_rp_array[i].rp_type;
      entries[total].source_tf= g_rp_array[i].source_tf;
      total++;
   }

   //--- Add HTF swings (these are virtual — no rp_index)
   for(int i = 0; i < g_htf_swing_count; i++)
   {
      entries[total].price    = g_htf_swing_cache[i].price;
      entries[total].rp_index = -1;
      entries[total].rp_type  = g_htf_swing_cache[i].rp_type;
      entries[total].source_tf= g_htf_swing_cache[i].source_tf;
      total++;
   }

   if(total < 2) return;

   //--- Sort by price ascending — simple insertion sort (N typically < 200)
   for(int i = 1; i < total; i++)
   {
      SPriceEntry key = entries[i];
      int j = i - 1;
      while(j >= 0 && entries[j].price > key.price)
      {
         entries[j + 1] = entries[j];
         j--;
      }
      entries[j + 1] = key;
   }

   //--- Linear scan: cluster entries within merge distance
   double merge_dist = PipsToPrice(g_confluence_merge_pips);
   if(merge_dist <= 0.0) return;

   //--- Temporary cluster storage
   int cluster_start = 0;

   for(int i = 1; i <= total; i++)
   {
      bool end_cluster = (i == total) ||
                         (entries[i].price - entries[i - 1].price > merge_dist);

      if(!end_cluster) continue;

      int cluster_size = i - cluster_start;
      if(cluster_size < 2)
      {
         cluster_start = i;
         continue;
      }

      //--- We have a cluster from cluster_start to i-1
      if(g_confluence_count >= MAX_CONFLUENCE)
      {
         cluster_start = i;
         continue;
      }

      //--- Count current-TF RPs in this cluster
      int rp_indices[MAX_ZONE_RPS];
      int rp_in_cluster = 0;
      double zone_low  = DBL_MAX;
      double zone_high = -DBL_MAX;
      int support_count = 0;
      int resistance_count = 0;
      string tf_set = "";
      double highest_score = -1.0;

      //--- Collect all entries in cluster: track zone bounds, type votes, TF set
      //    For current-TF RPs: store up to 2*MAX_ZONE_RPS candidates first
      int rp_candidates[];
      int rp_cand_count = 0;
      ArrayResize(rp_candidates, 0);

      for(int k = cluster_start; k < i; k++)
      {
         if(entries[k].price < zone_low)  zone_low  = entries[k].price;
         if(entries[k].price > zone_high) zone_high = entries[k].price;

         if(entries[k].rp_type == RP_SUPPORT) support_count++;
         else resistance_count++;

         //--- Build TF description
         string tf_str = TFToString(entries[k].source_tf);
         if(StringFind(tf_set, tf_str) < 0)
         {
            if(StringLen(tf_set) > 0) tf_set += "+";
            tf_set += tf_str;
         }

         //--- Track current-TF RP indices (collect all first)
         if(entries[k].rp_index >= 0)
         {
            ArrayResize(rp_candidates, rp_cand_count + 1, 10);
            rp_candidates[rp_cand_count] = entries[k].rp_index;
            rp_cand_count++;
         }
      }

      //--- If >MAX_ZONE_RPS current-TF RPs, keep top 8 by score
      if(rp_cand_count > MAX_ZONE_RPS)
      {
         //--- Sort by score descending, keep top 8
         for(int a = 0; a < rp_cand_count - 1; a++)
         {
            for(int b = a + 1; b < rp_cand_count; b++)
            {
               if(g_rp_array[rp_candidates[b]].final_score >
                  g_rp_array[rp_candidates[a]].final_score)
               {
                  int tmp = rp_candidates[a];
                  rp_candidates[a] = rp_candidates[b];
                  rp_candidates[b] = tmp;
               }
            }
         }
         rp_cand_count = MAX_ZONE_RPS;
      }

      //--- Copy candidates into fixed-size rp_indices array
      rp_in_cluster = MathMin(rp_cand_count, MAX_ZONE_RPS);
      for(int k = 0; k < rp_in_cluster; k++)
      {
         rp_indices[k] = rp_candidates[k];
         double score_k = g_rp_array[rp_candidates[k]].final_score;
         if(score_k > highest_score) highest_score = score_k;
      }

      //--- Determine multiplier & bonus based on cluster_size
      double multiplier = 1.0;
      double bonus = 0.0;
      bool is_premium = false;

      if(cluster_size >= 4)      { multiplier = 1.8; bonus = 40.0; is_premium = true; }
      else if(cluster_size >= 3) { multiplier = 1.5; bonus = 25.0; }
      else if(cluster_size >= 2) { multiplier = 1.3; bonus = 10.0; }

      //--- Create confluence zone
      SConfluenceZone zone;
      zone.Init();
      zone.id            = g_next_confluence_id++;
      zone.zone_high     = zone_high + PipsToPrice(g_zone_width_pips / 2.0);
      zone.zone_low      = zone_low  - PipsToPrice(g_zone_width_pips / 2.0);
      zone.center_price  = (zone_high + zone_low) / 2.0;
      zone.zone_type     = (support_count >= resistance_count) ? RP_SUPPORT : RP_RESISTANCE;
      zone.multiplier    = multiplier;
      zone.bonus         = bonus;
      zone.is_premium    = is_premium;
      zone.tf_description= tf_set;
      zone.rp_count      = rp_in_cluster;

      for(int k = 0; k < rp_in_cluster; k++)
         zone.rp_ids[k] = g_rp_array[rp_indices[k]].id;

      //--- Set highest score
      if(highest_score > 0.0)
         zone.final_score = highest_score;

      //--- Store zone
      if(g_confluence_count < MAX_CONFLUENCE)
      {
         g_confluence_array[g_confluence_count] = zone;
         g_confluence_count++;
      }

      //--- Mark RPs as confluence members
      for(int k = 0; k < rp_in_cluster; k++)
      {
         int idx = rp_indices[k];
         g_rp_array[idx].is_confluence = true;
         g_rp_array[idx].confluence_id = zone.id;
         g_rp_dirty[idx] = true;
      }

      cluster_start = i;
   }

   //--- Post-merge: merge overlapping confluence zones
   MergeOverlappingConfluenceZones();

   g_confluence_needs_update = false;
}

//+------------------------------------------------------------------+
//| MergeOverlappingConfluenceZones                                    |
//| If two confluence zones overlap or are within merge distance,      |
//| keep the one with higher score and absorb the other                |
//+------------------------------------------------------------------+
void MergeOverlappingConfluenceZones()
{
   double merge_dist = PipsToPrice(g_confluence_merge_pips);

   bool merged = true;
   int merge_iterations = 0;
   const int MAX_MERGE_ITERATIONS = 10;
   while(merged)
   {
      if(merge_iterations >= MAX_MERGE_ITERATIONS)
      {
         Print("WARNING: MergeOverlappingConfluenceZones — hit iteration limit (", MAX_MERGE_ITERATIONS, "), stopping");
         break;
      }
      merge_iterations++;
      merged = false;
      for(int i = 0; i < g_confluence_count && !merged; i++)
      {
         for(int j = i + 1; j < g_confluence_count && !merged; j++)
         {
            //--- Check if zones overlap or are within merge distance
            bool overlap = (g_confluence_array[i].zone_low <= g_confluence_array[j].zone_high + merge_dist) &&
                           (g_confluence_array[j].zone_low <= g_confluence_array[i].zone_high + merge_dist);
            if(!overlap) continue;

            //--- Pick winner (higher score), loser gets absorbed
            int winner = i, loser = j;
            if(g_confluence_array[j].final_score > g_confluence_array[i].final_score)
            { winner = j; loser = i; }

            //--- Keep winner's zone boundaries (better zone = more precise)

            //--- Upgrade multiplier if combined RP count qualifies
            int combined_rps = g_confluence_array[winner].rp_count + g_confluence_array[loser].rp_count;
            if(combined_rps >= 4 && !g_confluence_array[winner].is_premium)
            {
               g_confluence_array[winner].multiplier = 1.8;
               g_confluence_array[winner].bonus      = 40.0;
               g_confluence_array[winner].is_premium = true;
            }

            //--- Absorb loser's RPs into winner (up to MAX_ZONE_RPS)
            for(int k = 0; k < g_confluence_array[loser].rp_count; k++)
            {
               if(g_confluence_array[winner].rp_count >= MAX_ZONE_RPS) break;
               int rp_id = g_confluence_array[loser].rp_ids[k];
               bool exists = false;
               for(int m = 0; m < g_confluence_array[winner].rp_count; m++)
               {
                  if(g_confluence_array[winner].rp_ids[m] == rp_id) { exists = true; break; }
               }
               if(!exists)
               {
                  g_confluence_array[winner].rp_ids[g_confluence_array[winner].rp_count] = rp_id;
                  g_confluence_array[winner].rp_count++;
               }
            }

            //--- Re-point loser's RPs to winner zone (O(1) lookup via ID map)
            for(int k = 0; k < g_confluence_array[loser].rp_count; k++)
            {
               int rp_idx = FindRPIndexByID(g_confluence_array[loser].rp_ids[k]);
               if(rp_idx >= 0)
               {
                  g_rp_array[rp_idx].confluence_id = g_confluence_array[winner].id;
                  g_rp_dirty[rp_idx] = true;
               }
            }

            //--- Remove loser zone by shifting array
            for(int k = loser; k < g_confluence_count - 1; k++)
               g_confluence_array[k] = g_confluence_array[k + 1];
            g_confluence_count--;

            merged = true; // restart scan from beginning
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ApplyConfluenceScoring                                            |
//| Apply multiplier+bonus to highest-score RP in each zone           |
//+------------------------------------------------------------------+
void ApplyConfluenceScoring()
{
   if(!g_use_confluence_zones) return;

   for(int z = 0; z < g_confluence_count; z++)
   {
      SConfluenceZone zone = g_confluence_array[z];
      if(zone.rp_count <= 0) continue;

      //--- Find RP with highest score in zone (O(1) lookup per RP via ID map)
      int best_idx = -1;
      double best_score = -1.0;

      for(int k = 0; k < zone.rp_count; k++)
      {
         int r = FindRPIndexByID(zone.rp_ids[k]);
         if(r >= 0 && g_rp_array[r].is_active && g_rp_array[r].final_score > best_score)
         {
            best_score = g_rp_array[r].final_score;
            best_idx = r;
         }
      }

      if(best_idx < 0) continue;

      //--- Apply multiplier + bonus with clamping
      double adjusted = g_rp_array[best_idx].final_score * zone.multiplier + zone.bonus;
      g_rp_array[best_idx].final_score = MathMax(0.0, MathMin(adjusted, SCORE_CAP));
      g_rp_array[best_idx].rp_level = ClassifyRPLevel(g_rp_array[best_idx].final_score);

      //--- Update zone final_score
      zone.final_score = g_rp_array[best_idx].final_score;
      g_confluence_array[z] = zone;
   }
}

//+------------------------------------------------------------------+
//| HandlePartialBreakout — detach 1 RP from zone on breakout         |
//+------------------------------------------------------------------+
void HandlePartialBreakout(int rp_id)
{
   //--- Find which zone contains this RP
   for(int z = 0; z < g_confluence_count; z++)
   {
      SConfluenceZone zone = g_confluence_array[z];

      bool found = false;
      for(int j = 0; j < zone.rp_count; j++)
      {
         if(zone.rp_ids[j] == rp_id)
         {
            //--- Shift remaining left (bounds-safe)
            for(int k = j; k < zone.rp_count - 1; k++)
               zone.rp_ids[k] = zone.rp_ids[k + 1];

            zone.rp_ids[zone.rp_count - 1] = -1;
            zone.rp_count--;
            found = true;
            break;
         }
      }

      if(!found) continue;

      //--- Detach the broken RP (O(1) lookup via ID map)
      int detach_idx = FindRPIndexByID(rp_id);
      if(detach_idx >= 0)
      {
         g_rp_array[detach_idx].is_confluence = false;
         g_rp_array[detach_idx].confluence_id = -1;
         g_rp_dirty[detach_idx] = true;
      }

      //--- Recalc multiplier/bonus or dissolve zone
      if(zone.rp_count <= 1)
      {
         //--- Dissolve zone: detach remaining RP
         if(zone.rp_count == 1)
         {
            int last_idx = FindRPIndexByID(zone.rp_ids[0]);
            if(last_idx >= 0)
            {
               g_rp_array[last_idx].is_confluence = false;
               g_rp_array[last_idx].confluence_id = -1;
               g_rp_dirty[last_idx] = true;
            }
         }

         //--- Remove zone by shifting array
         for(int k = z; k < g_confluence_count - 1; k++)
            g_confluence_array[k] = g_confluence_array[k + 1];

         g_confluence_count--;
      }
      else
      {
         //--- Recalc multiplier/bonus
         if(zone.rp_count >= 4)      { zone.multiplier = 1.8; zone.bonus = 40.0; zone.is_premium = true; }
         else if(zone.rp_count >= 3) { zone.multiplier = 1.5; zone.bonus = 25.0; zone.is_premium = false; }
         else if(zone.rp_count >= 2) { zone.multiplier = 1.3; zone.bonus = 10.0; zone.is_premium = false; }

         //--- Mark remaining RPs dirty for re-score (O(1) lookup via ID map)
         for(int k = 0; k < zone.rp_count; k++)
         {
            int dirty_idx = FindRPIndexByID(zone.rp_ids[k]);
            if(dirty_idx >= 0)
               g_rp_dirty[dirty_idx] = true;
         }

         //--- Write modified zone back to array
         g_confluence_array[z] = zone;
      }

      g_confluence_needs_update = true;
      return; // RP can only be in one zone
   }

   Print("WARNING: rp_id ", rp_id, " not found in any confluence zone");
}

//+------------------------------------------------------------------+
//| UpdateHTFTrends — detect trend direction on all timeframes (P20) |
//| Called per-bar in Main OnCalculate after UpdateMarketRegime       |
//+------------------------------------------------------------------+
void UpdateHTFTrends()
{
   if(!g_use_trend_alignment) return;

   //--- Current TF — already detected by UpdateMarketRegime
   g_htf_trends[0].tf           = (ENUM_TIMEFRAMES)Period();
   g_htf_trends[0].trend        = g_current_trend;
   g_htf_trends[0].is_valid     = true;
   g_htf_trends[0].last_updated = TimeCurrent();

   //--- HTF_1 and HTF_2
   ENUM_TIMEFRAMES tfs[2];
   tfs[0] = g_htf_1;
   tfs[1] = g_htf_2;

   for(int t = 0; t < 2; t++)
   {
      int idx = t + 1;
      g_htf_trends[idx].tf = tfs[t];

      double htf_close[];
      int copied = CopyClose(_Symbol, tfs[t], 0, 21, htf_close);
      if(copied < 21)
      {
         g_htf_trends[idx].is_valid = false;
         continue;
      }

      ArraySetAsSeries(htf_close, true);

      //--- Trend detection via price structure on closed bars[1..20]
      bool up1   = htf_close[1]  > htf_close[10];
      bool up2   = htf_close[10] > htf_close[20];
      bool down1 = htf_close[1]  < htf_close[10];
      bool down2 = htf_close[10] < htf_close[20];

      if(up1 && up2)
         g_htf_trends[idx].trend = TREND_UP;
      else if(down1 && down2)
         g_htf_trends[idx].trend = TREND_DOWN;
      else
         g_htf_trends[idx].trend = TREND_NONE;

      g_htf_trends[idx].is_valid     = true;
      g_htf_trends[idx].last_updated = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| GetTrendAlignmentScore — multi-TF trend agreement score (P20)    |
//| Returns [-25, +20] based on how many TFs agree with RP direction |
//+------------------------------------------------------------------+
double GetTrendAlignmentScore(ENUM_RP_TYPE rp_type)
{
   if(!g_use_trend_alignment) return 0.0;

   int aligned = 0;
   int counter = 0;
   int total   = 0;

   for(int i = 0; i < 3; i++)
   {
      if(!g_htf_trends[i].is_valid) continue;
      total++;

      // TREND_NONE = neutral — neither aligned nor counter
      // Only explicit directional agreement counts as alignment
      if(g_htf_trends[i].trend == TREND_NONE)
         continue;  // Skip neutral TFs — don't inflate alignment count

      bool is_aligned;
      if(rp_type == RP_SUPPORT)
         is_aligned = (g_htf_trends[i].trend == TREND_UP);
      else // RP_RESISTANCE
         is_aligned = (g_htf_trends[i].trend == TREND_DOWN);

      if(is_aligned) aligned++;
      else counter++;
   }

   if(total == 0) return 0.0;

   // directional = TFs with clear trend (excludes TREND_NONE)
   int directional = aligned + counter;

   //--- No directional TFs (all TREND_NONE) → neutral
   if(directional == 0) return 0.0;

   //--- All directional TFs agree with RP
   if(aligned == directional && aligned >= 2) return 20.0;
   if(aligned == directional && aligned == 1) return 10.0;

   //--- Majority aligned (2 of 3 directional, or 1 aligned + 0 counter + neutrals)
   if(aligned > counter) return 10.0;

   //--- Counter-trend
   double penalty = (aligned == 0) ? -25.0 : -15.0;

   //--- CHoCH exception: reduce penalty with gradual fade
   //    Bar 1-5: 50% reduction, bar 6-15: fade from 50% reduction to full penalty
   //    Multiplier: bar 5 = 0.5, bar 15 = 1.0 (no reduction = full penalty)
   if(g_choch_detected && g_last_choch_bar <= 5)
      penalty *= 0.5;
   else if(g_choch_detected && g_last_choch_bar <= 15)
   {
      // Linear fade: 0.5 (bar 6) → 1.0 (bar 15)
      double fade = 0.5 + 0.5 * (double)(g_last_choch_bar - 5) / 10.0;
      penalty *= fade;
   }

   return penalty;
}

//+------------------------------------------------------------------+
//| IsTrendAligned — simple boolean check for entry filter (P20)     |
//+------------------------------------------------------------------+
bool IsTrendAligned(ENUM_RP_TYPE rp_type)
{
   return GetTrendAlignmentScore(rp_type) >= 0.0;
}

#endif // RP_CONFLUENCE_MQH
