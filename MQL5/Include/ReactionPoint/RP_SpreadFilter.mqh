//+------------------------------------------------------------------+
//|                                           RP_SpreadFilter.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Module G — Spread Filter                   |
//+------------------------------------------------------------------+
#ifndef RP_SPREADFILTER_MQH
#define RP_SPREADFILTER_MQH

#include "RP_Utils.mqh"

//--- Extern inputs
extern bool   Use_Spread_Filter;
extern double Spread_Alert_Multiplier;
extern double Spread_Block_Multiplier;

//--- Rolling spread buffer
double g_spread_buffer[100];
int    g_spread_idx   = 0;
int    g_spread_count = 0;

//+------------------------------------------------------------------+
//| Update spread filter (called every tick)                          |
//+------------------------------------------------------------------+
void UpdateSpreadFilter()
{
   double pip_val = PipValue();
   if(pip_val <= 0) return;

   double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
                           * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / pip_val;

   // Update rolling buffer
   g_spread_buffer[g_spread_idx % 100] = current_spread;
   g_spread_idx++;
   if(g_spread_count < 100) g_spread_count++;

   // Calculate average
   double sum = 0;
   int cnt = (g_spread_count < 100) ? g_spread_count : 100;
   for(int i = 0; i < cnt; i++)
      sum += g_spread_buffer[i];
   double avg = (cnt > 0) ? sum / cnt : current_spread;

   // Update globals
   g_current_spread_pips = current_spread;
   g_average_spread_pips = avg;

   if(!Use_Spread_Filter)
   {
      g_spread_blocked = false;
      g_spread_warning = false;
      return;
   }

   if(avg > 0 && current_spread > avg * Spread_Block_Multiplier)
   {
      g_spread_blocked = true;
      g_spread_warning = true;
   }
   else if(avg > 0 && current_spread > avg * Spread_Alert_Multiplier)
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
//| Get spread score adjustment                                       |
//+------------------------------------------------------------------+
double GetSpreadScoreAdjustment()
{
   if(!Use_Spread_Filter) return 0.0;
   if(g_spread_blocked) return -15.0;
   if(g_spread_warning) return -10.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if spread is blocking                                       |
//+------------------------------------------------------------------+
bool IsSpreadBlocked()
{
   return g_spread_blocked;
}

//+------------------------------------------------------------------+
//| Get spread display color                                          |
//+------------------------------------------------------------------+
color GetSpreadColor()
{
   if(g_spread_blocked) return clrRed;
   if(g_spread_warning) return clrYellow;
   return clrWhite;
}

#endif
