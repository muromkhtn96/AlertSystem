//+------------------------------------------------------------------+
//|                                           RP_SpreadFilter.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Module G — Spread Filter                   |
//+------------------------------------------------------------------+
#ifndef RP_SPREADFILTER_MQH
#define RP_SPREADFILTER_MQH

#include "RP_Utils.mqh"

// NO extern/input here — reads g_use_spread_filter, g_spread_alert_multiplier,
// g_spread_block_multiplier from globals

//--- Rolling spread buffer (100 ticks)
//    g_spread_idx wraps via modulo to prevent integer overflow on long sessions
#define SPREAD_BUF_SIZE 100
double g_spread_buffer[SPREAD_BUF_SIZE];
int    g_spread_idx   = 0;
int    g_spread_count = 0;

//+------------------------------------------------------------------+
//| Get current spread in pips                                        |
//+------------------------------------------------------------------+
double GetCurrentSpreadPips()
{
   double pip_val = PipValue();
   if(pip_val <= 0.0) return 0.0;
   return (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
          * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / pip_val;
}

//+------------------------------------------------------------------+
//| Get average spread from rolling buffer                            |
//+------------------------------------------------------------------+
double GetAverageSpread()
{
   int cnt = (g_spread_count < SPREAD_BUF_SIZE) ? g_spread_count : SPREAD_BUF_SIZE;
   if(cnt <= 0) return 0.0;

   double sum = 0.0;
   for(int i = 0; i < cnt; i++)
      sum += g_spread_buffer[i];

   return sum / cnt;
}

//+------------------------------------------------------------------+
//| Update spread filter (called every tick)                          |
//| Blocked: cur > avg * block_multiplier (3.0)                       |
//|   → block entry, block alert cấp 2                               |
//| Warning: cur > avg * alert_multiplier (2.0)                       |
//|   → score -10 tạm thời, entry vẫn hoạt động với warning          |
//+------------------------------------------------------------------+
void UpdateSpreadFilter()
{
   //--- Always update spread data (even if filter is off)
   g_current_spread_pips = GetCurrentSpreadPips();

   //--- Update rolling buffer (modulo prevents integer overflow)
   g_spread_buffer[g_spread_idx] = g_current_spread_pips;
   g_spread_idx = (g_spread_idx + 1) % SPREAD_BUF_SIZE;
   if(g_spread_count < SPREAD_BUF_SIZE) g_spread_count++;

   g_average_spread_pips = GetAverageSpread();

   //--- Check filter toggle
   if(!g_use_spread_filter)
   {
      g_spread_blocked = false;
      g_spread_warning = false;
      return;
   }

   //--- Classify spread status
   if(g_average_spread_pips > 0.0 && g_current_spread_pips > g_average_spread_pips * g_spread_block_multiplier)
   {
      g_spread_blocked = true;
      g_spread_warning = false;  // Blocked supersedes warning
   }
   else if(g_average_spread_pips > 0.0 && g_current_spread_pips > g_average_spread_pips * g_spread_alert_multiplier)
   {
      g_spread_blocked = false;
      g_spread_warning = true;
   }
   else
   {
      g_spread_blocked = false;
      g_spread_warning = false;
   }
}

//+------------------------------------------------------------------+
//| Get spread temporary score adjustment                             |
//| Blocked → -15, Warning → -10, Normal → 0                         |
//+------------------------------------------------------------------+
double GetSpreadTempScoreAdj()
{
   if(!g_use_spread_filter) return 0.0;
   if(g_spread_blocked) return -15.0;
   if(g_spread_warning) return -10.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if spread is blocking entries                               |
//+------------------------------------------------------------------+
bool IsSpreadBlocked()
{
   return g_spread_blocked;
}

#endif // RP_SPREADFILTER_MQH
