//+------------------------------------------------------------------+
//|                                                    RP_FVG.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Fair Value Gap Detection (P34)             |
//+------------------------------------------------------------------+
#ifndef RP_FVG_MQH
#define RP_FVG_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| FVG cache — stores recent gaps for zone overlap checking          |
//+------------------------------------------------------------------+
#define MAX_FVG_COUNT 50

struct SFVG
{
   double   high;          // Upper edge of gap
   double   low;           // Lower edge of gap
   datetime time_formed;   // Time of middle candle
   int      bar_formed;    // Bar index of middle candle
   bool     is_bullish;    // true = bullish FVG (gap up), false = bearish FVG (gap down)
   bool     is_filled;     // true if price has filled the gap
   bool     is_active;     // false if filled or expired
};

SFVG   g_fvg_array[MAX_FVG_COUNT];
int    g_fvg_count = 0;

//+------------------------------------------------------------------+
//| DetectFVG — scan recent bars for Fair Value Gaps                   |
//|                                                                    |
//| Bullish FVG: low[i-1] > high[i+1]  (gap between candle 3 & 1)    |
//|   → price jumped up, leaving unfilled space                        |
//|   → gap zone = [high[i+1], low[i-1]]                              |
//|                                                                    |
//| Bearish FVG: high[i-1] < low[i+1]  (gap between candle 1 & 3)    |
//|   → price dropped down, leaving unfilled space                     |
//|   → gap zone = [high[i-1], low[i+1]]                              |
//|                                                                    |
//| Minimum gap size: 30% of ATR to filter noise                      |
//| Only scans closed bars (anti-repainting: bar[2] and older)         |
//+------------------------------------------------------------------+
void DetectFVG(int bars_to_scan)
{
   int available = Bars(_Symbol, PERIOD_CURRENT);
   if(available < 10) return;

   int limit = MathMin(bars_to_scan, available - 3);

   //--- Minimum gap size: 30% of ATR (filter micro-gaps)
   double min_gap = (g_cached_atr14 > 0.0) ? g_cached_atr14 * 0.30 : PipsToPrice(5);

   //--- Scan from bar[2] onward (bar[1] is most recent closed, need i+1 = bar[1] minimum)
   for(int i = 2; i < limit; i++)
   {
      double high_prev = RP_High(i + 1);   // Candle BEFORE the gap (older)
      double low_prev  = RP_Low(i + 1);
      double high_next = RP_High(i - 1);   // Candle AFTER the gap (newer)
      double low_next  = RP_Low(i - 1);

      if(high_prev == 0.0 || low_next == 0.0) continue;

      //--- Bullish FVG: candle[i+1].high < candle[i-1].low
      //    Gap between top of older candle and bottom of newer candle
      if(high_prev < low_next)
      {
         double gap_size = low_next - high_prev;
         if(gap_size >= min_gap)
            AddFVG(high_prev, low_next, i, true);
      }
      //--- Bearish FVG: candle[i+1].low > candle[i-1].high
      //    Gap between bottom of older candle and top of newer candle
      else if(low_prev > high_next)
      {
         double gap_size = low_prev - high_next;
         if(gap_size >= min_gap)
            AddFVG(high_next, low_prev, i, false);
      }
   }

   //--- Check if any existing FVGs have been filled
   CheckFVGFilled();
}

//+------------------------------------------------------------------+
//| AddFVG — store a detected FVG (avoid duplicates)                   |
//+------------------------------------------------------------------+
void AddFVG(double gap_low, double gap_high, int bar_idx, bool is_bullish)
{
   datetime fvg_time = iTime(_Symbol, PERIOD_CURRENT, bar_idx);

   //--- Check for duplicate (same time = same FVG)
   for(int i = 0; i < g_fvg_count; i++)
   {
      if(g_fvg_array[i].time_formed == fvg_time && g_fvg_array[i].is_bullish == is_bullish)
         return;
   }

   //--- Find slot: reuse inactive or append
   int slot = -1;
   if(g_fvg_count < MAX_FVG_COUNT)
   {
      slot = g_fvg_count;
      g_fvg_count++;
   }
   else
   {
      //--- Evict oldest inactive FVG
      for(int i = 0; i < MAX_FVG_COUNT; i++)
      {
         if(!g_fvg_array[i].is_active) { slot = i; break; }
      }
      if(slot < 0)
      {
         //--- Evict oldest active FVG
         datetime oldest = D'2099.01.01';
         for(int i = 0; i < MAX_FVG_COUNT; i++)
         {
            if(g_fvg_array[i].time_formed < oldest)
            { oldest = g_fvg_array[i].time_formed; slot = i; }
         }
      }
   }
   if(slot < 0) return;

   g_fvg_array[slot].high         = gap_high;
   g_fvg_array[slot].low          = gap_low;
   g_fvg_array[slot].time_formed  = fvg_time;
   g_fvg_array[slot].bar_formed   = bar_idx;
   g_fvg_array[slot].is_bullish   = is_bullish;
   g_fvg_array[slot].is_filled    = false;
   g_fvg_array[slot].is_active    = true;
}

//+------------------------------------------------------------------+
//| CheckFVGFilled — mark FVGs that have been filled by price          |
//|                                                                    |
//| Bullish FVG filled: any candle low <= gap_low (closed the gap)     |
//| Bearish FVG filled: any candle high >= gap_high (closed the gap)   |
//+------------------------------------------------------------------+
void CheckFVGFilled()
{
   double close_1 = RP_Close(1);
   double high_1  = RP_High(1);
   double low_1   = RP_Low(1);
   if(close_1 == 0.0) return;

   for(int i = 0; i < g_fvg_count; i++)
   {
      if(!g_fvg_array[i].is_active) continue;
      if(g_fvg_array[i].is_filled) continue;

      if(g_fvg_array[i].is_bullish)
      {
         // Bullish FVG filled when price drops to close the gap
         if(low_1 <= g_fvg_array[i].low)
         {
            g_fvg_array[i].is_filled = true;
            g_fvg_array[i].is_active = false;
         }
      }
      else
      {
         // Bearish FVG filled when price rises to close the gap
         if(high_1 >= g_fvg_array[i].high)
         {
            g_fvg_array[i].is_filled = true;
            g_fvg_array[i].is_active = false;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CheckZoneFVGOverlap — check if an RP zone overlaps with any FVG   |
//|                                                                    |
//| Returns true if zone overlaps with an active, direction-aligned FVG|
//| Also sets rp.has_fvg and rp.has_fvg_bullish                       |
//|                                                                    |
//| Alignment logic:                                                   |
//|   Support zone  + Bullish FVG = aligned (demand + gap up)          |
//|   Resistance zone + Bearish FVG = aligned (supply + gap down)      |
//|   Misaligned FVG: still counts but with reduced bonus              |
//+------------------------------------------------------------------+
bool CheckZoneFVGOverlap(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return false;

   double z_high = g_rp_array[rp_index].zone_high;
   double z_low  = g_rp_array[rp_index].zone_low;

   for(int i = 0; i < g_fvg_count; i++)
   {
      if(!g_fvg_array[i].is_active) continue;

      //--- Check overlap: zone and FVG intersect
      bool overlaps = (z_low <= g_fvg_array[i].high) && (g_fvg_array[i].low <= z_high);
      if(!overlaps) continue;

      g_rp_array[rp_index].has_fvg         = true;
      g_rp_array[rp_index].has_fvg_bullish = g_fvg_array[i].is_bullish;
      return true;
   }

   g_rp_array[rp_index].has_fvg = false;
   return false;
}

//+------------------------------------------------------------------+
//| CalcFVGBonus — scoring bonus for FVG overlap (P34)                 |
//|                                                                    |
//| Aligned FVG (support+bullish / resistance+bearish): +15 pts        |
//| Misaligned FVG (still institutional imbalance):     +5 pts         |
//| No FVG:                                             0 pts          |
//| Range: [0, +15]                                                    |
//+------------------------------------------------------------------+
double CalcFVGBonus(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return 0.0;
   SReactionPoint rp = g_rp_array[rp_index];

   if(!rp.has_fvg) return 0.0;

   //--- Check alignment
   bool aligned = false;
   if(rp.rp_type == RP_SUPPORT && rp.has_fvg_bullish)
      aligned = true;   // Demand zone + bullish gap = institutional buying
   if(rp.rp_type == RP_RESISTANCE && !rp.has_fvg_bullish)
      aligned = true;   // Supply zone + bearish gap = institutional selling

   return aligned ? 15.0 : 5.0;
}

#endif // RP_FVG_MQH
