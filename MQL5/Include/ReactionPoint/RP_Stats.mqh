//+------------------------------------------------------------------+
//|                                                  RP_Stats.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Performance Tracker                        |
//+------------------------------------------------------------------+
#ifndef RP_STATS_MQH
#define RP_STATS_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| InitStats                                                         |
//+------------------------------------------------------------------+
void InitStats()
{
   g_stats.Init();
}

//+------------------------------------------------------------------+
//| OnRPFormed — called when a new RP is created                      |
//+------------------------------------------------------------------+
void OnRPFormed(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];

   g_stats.total_formed++;

   //--- By level
   switch(rp.rp_level)
   {
      case RP_PREMIUM: g_stats.premium_formed++; break;
      case RP_LEVEL1:  g_stats.level1_formed++;  break;
      case RP_LEVEL2:  g_stats.level2_formed++;  break;
      default: break;
   }

   //--- By session
   switch(rp.session_formed)
   {
      case SESSION_LONDON_OPEN:
      case SESSION_LONDON:
         g_stats.london_formed++;
         break;
      case SESSION_NY_OPEN:
      case SESSION_NY:
      case SESSION_OVERLAP:
         g_stats.ny_formed++;
         break;
      case SESSION_ASIAN:
         g_stats.asian_formed++;
         break;
      default: break;
   }
}

//+------------------------------------------------------------------+
//| OnRPReacted — when price bounces off RP (no break)                |
//+------------------------------------------------------------------+
void OnRPReacted(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];

   g_stats.total_reacted++;

   //--- By level
   switch(rp.rp_level)
   {
      case RP_PREMIUM: g_stats.premium_reacted++; break;
      case RP_LEVEL1:  g_stats.level1_reacted++;  break;
      case RP_LEVEL2:  g_stats.level2_reacted++;  break;
      default: break;
   }

   //--- By session
   switch(rp.session_formed)
   {
      case SESSION_LONDON_OPEN:
      case SESSION_LONDON:
         g_stats.london_reacted++;
         break;
      case SESSION_NY_OPEN:
      case SESSION_NY:
      case SESSION_OVERLAP:
         g_stats.ny_reacted++;
         break;
      case SESSION_ASIAN:
         g_stats.asian_reacted++;
         break;
      default: break;
   }
}

//+------------------------------------------------------------------+
//| OnRPBroken — when RP breakout is confirmed                        |
//+------------------------------------------------------------------+
void OnRPBroken(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   g_stats.total_broken++;
}

//+------------------------------------------------------------------+
//| UpdateStats — called once per new bar                              |
//| Scans active RPs and checks bar[1] for reaction or break          |
//+------------------------------------------------------------------+
void UpdateStats()
{
   double close_1 = RP_Close(1);
   double high_1  = RP_High(1);
   double low_1   = RP_Low(1);
   if(close_1 == 0.0 || high_1 == 0.0 || low_1 == 0.0) return;

   double min_move;
   if(g_use_adaptive_reaction)
      min_move = SafeATR(14) * g_reaction_atr_multiplier;
   else
      min_move = PipsToPrice(g_min_reaction_move_pips);

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      SReactionPoint rp = g_rp_array[i];

      //--- Check if bar[1] touches zone
      bool touches_zone = (low_1 <= rp.zone_high && high_1 >= rp.zone_low);
      if(!touches_zone) continue;

      //--- Check breakout: close crosses zone by breakout_confirm_pips
      if(rp.rp_type == RP_SUPPORT)
      {
         if(close_1 < rp.zone_low - PipsToPrice(g_breakout_confirm_pips))
         {
            OnRPBroken(i);
            continue;
         }

         //--- Reaction: close stays above zone + moves up enough
         if(close_1 >= rp.zone_low)
         {
            double move_up = close_1 - rp.zone_low;
            if(move_up >= min_move)
               OnRPReacted(i);
         }
      }
      else // RP_RESISTANCE
      {
         if(close_1 > rp.zone_high + PipsToPrice(g_breakout_confirm_pips))
         {
            OnRPBroken(i);
            continue;
         }

         //--- Reaction: close stays below zone + moves down enough
         if(close_1 <= rp.zone_high)
         {
            double move_down = rp.zone_high - close_1;
            if(move_down >= min_move)
               OnRPReacted(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GetHitRate — overall reaction rate                                 |
//+------------------------------------------------------------------+
double GetHitRate()
{
   int denom = g_stats.total_reacted + g_stats.total_broken;
   if(denom <= 0) return 0.0;
   return (double)g_stats.total_reacted / (double)denom;
}

//+------------------------------------------------------------------+
//| GetLevelHitRate — hit rate by RP level                             |
//+------------------------------------------------------------------+
double GetLevelHitRate(ENUM_RP_LEVEL level)
{
   int reacted = 0, formed = 0;

   switch(level)
   {
      case RP_PREMIUM: reacted = g_stats.premium_reacted; formed = g_stats.premium_formed; break;
      case RP_LEVEL1:  reacted = g_stats.level1_reacted;  formed = g_stats.level1_formed;  break;
      case RP_LEVEL2:  reacted = g_stats.level2_reacted;  formed = g_stats.level2_formed;  break;
      default: return 0.0;
   }

   if(formed <= 0) return 0.0;
   return (double)reacted / (double)formed;
}

//+------------------------------------------------------------------+
//| Session hit rate helper                                            |
//+------------------------------------------------------------------+
double GetSessionHitRate(int formed, int reacted)
{
   if(formed <= 0) return 0.0;
   return (double)reacted / (double)formed;
}

//+------------------------------------------------------------------+
//| GetBestSession — returns "SessionName XX%"                         |
//+------------------------------------------------------------------+
string GetBestSession()
{
   double london_hr = GetSessionHitRate(g_stats.london_formed, g_stats.london_reacted);
   double ny_hr     = GetSessionHitRate(g_stats.ny_formed, g_stats.ny_reacted);
   double asian_hr  = GetSessionHitRate(g_stats.asian_formed, g_stats.asian_reacted);

   string best_name = "N/A";
   double best_rate = -1.0;

   if(g_stats.london_formed > 0 && london_hr > best_rate) { best_rate = london_hr; best_name = "London Open"; }
   if(g_stats.ny_formed > 0 && ny_hr > best_rate)         { best_rate = ny_hr;     best_name = "NY"; }
   if(g_stats.asian_formed > 0 && asian_hr > best_rate)    { best_rate = asian_hr;  best_name = "Asian"; }

   if(best_rate < 0.0) return "N/A";
   return best_name + " " + IntegerToString((int)MathRound(best_rate * 100.0)) + "%";
}

//+------------------------------------------------------------------+
//| GetWorstSession — returns "SessionName XX%"                        |
//+------------------------------------------------------------------+
string GetWorstSession()
{
   double london_hr = GetSessionHitRate(g_stats.london_formed, g_stats.london_reacted);
   double ny_hr     = GetSessionHitRate(g_stats.ny_formed, g_stats.ny_reacted);
   double asian_hr  = GetSessionHitRate(g_stats.asian_formed, g_stats.asian_reacted);

   string worst_name = "N/A";
   double worst_rate = 999.0;

   if(g_stats.london_formed > 0 && london_hr < worst_rate) { worst_rate = london_hr; worst_name = "London Open"; }
   if(g_stats.ny_formed > 0 && ny_hr < worst_rate)         { worst_rate = ny_hr;     worst_name = "NY"; }
   if(g_stats.asian_formed > 0 && asian_hr < worst_rate)    { worst_rate = asian_hr;  worst_name = "Asian"; }

   if(worst_rate > 100.0) return "N/A";
   return worst_name + " " + IntegerToString((int)MathRound(worst_rate * 100.0)) + "%";
}

//+------------------------------------------------------------------+
//| FormatStatsString — for dashboard display                          |
//+------------------------------------------------------------------+
string FormatStatsString()
{
   MqlDateTime dt;
   TimeToStruct(g_stats.tracking_start, dt);
   string start_date = StringFormat("%04d-%02d-%02d", dt.year, dt.mon, dt.day);

   int total_decided = g_stats.total_reacted + g_stats.total_broken;
   int hit_pct = (total_decided > 0)
                 ? (int)MathRound((double)g_stats.total_reacted / (double)total_decided * 100.0)
                 : 0;

   //--- Premium hit rate
   int prem_decided = g_stats.premium_reacted + (g_stats.premium_formed - g_stats.premium_reacted);
   int prem_pct = (g_stats.premium_formed > 0)
                  ? (int)MathRound((double)g_stats.premium_reacted / (double)g_stats.premium_formed * 100.0)
                  : 0;

   //--- Level1 hit rate
   int lv1_decided = g_stats.level1_reacted + (g_stats.level1_formed - g_stats.level1_reacted);
   int lv1_pct = (g_stats.level1_formed > 0)
                 ? (int)MathRound((double)g_stats.level1_reacted / (double)g_stats.level1_formed * 100.0)
                 : 0;

   string result = "PERFORMANCE (since " + start_date + ")\n";
   result += "  Hit Rate: " + IntegerToString(hit_pct) + "% ("
             + IntegerToString(g_stats.total_reacted) + "/"
             + IntegerToString(total_decided) + ")\n";
   result += "  Premium: " + IntegerToString(prem_pct) + "% ("
             + IntegerToString(g_stats.premium_reacted) + "/"
             + IntegerToString(g_stats.premium_formed) + ")"
             + " | Lv1: " + IntegerToString(lv1_pct) + "% ("
             + IntegerToString(g_stats.level1_reacted) + "/"
             + IntegerToString(g_stats.level1_formed) + ")\n";
   result += "  Best: " + GetBestSession()
             + " | Worst: " + GetWorstSession();

   return result;
}

#endif // RP_STATS_MQH
