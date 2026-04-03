//+------------------------------------------------------------------+
//|                                                RP_Alerts.mqh     |
//|                        Reaction Point Indicator v3.0              |
//|                        4-Level Alert System                       |
//+------------------------------------------------------------------+
#ifndef RP_ALERTS_MQH
#define RP_ALERTS_MQH

#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| SendRPAlert — fire alert + push + log                              |
//| Pre-build message only when alert actually fires (performance)     |
//+------------------------------------------------------------------+
void SendRPAlert(int level, int rp_index, string message)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   if(level < 1 || level > 4) return;

   if(g_enable_system_alert)
      Alert(message);
   if(g_enable_push_notify)
      SendNotification(message);
   Print("RP_ALERT[", level, "]: ", message);

   g_rp_array[rp_index].alert_sent[level - 1] = true;
}

//+------------------------------------------------------------------+
//| CheckProximityAlert (Level 1) — price approaching RP               |
//+------------------------------------------------------------------+
bool CheckProximityAlert(int rp_index)
{
   SReactionPoint rp = g_rp_array[rp_index];
   if(rp.alert_sent[0]) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distance = MathAbs(bid - rp.price);

   if(PriceToPips(distance) > g_proximity_alert_pips)
      return false;

   //--- Check direction: price moving TOWARDS RP
   double close_1 = RP_Close(1);
   double close_2 = RP_Close(2);
   if(close_1 == 0.0 || close_2 == 0.0) return false;

   bool approaching = false;
   if(rp.rp_type == RP_SUPPORT)
      approaching = (close_1 < close_2);  // price falling toward support
   else
      approaching = (close_1 > close_2);  // price rising toward resistance

   if(!approaching) return false;

   //--- Build message only when firing
   string msg = "Approaching " + _Symbol + " " + TFToString(Period()) +
                " | " + DoubleToString(rp.price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                " | Score:" + DoubleToString(rp.final_score, 0) +
                " | Dist:" + DoubleToString(PriceToPips(distance), 1) + "p";

   SendRPAlert(1, rp_index, msg);
   return true;
}

//+------------------------------------------------------------------+
//| CheckReactionAlert (Level 2) — candle pattern at RP zone           |
//+------------------------------------------------------------------+
bool CheckReactionAlert(int rp_index)
{
   SReactionPoint rp = g_rp_array[rp_index];
   if(rp.alert_sent[1]) return false;

   //--- Bar[1] close must be in zone
   double close_1 = RP_Close(1);
   if(close_1 == 0.0) return false;
   if(close_1 < rp.zone_low || close_1 > rp.zone_high)
      return false;

   //--- Use cached candle_pattern — do NOT call DetectCandlePattern again
   if(rp.candle_pattern == PATTERN_NONE) return false;

   //--- Build pattern name
   string pat_str;
   switch(rp.candle_pattern)
   {
      case PATTERN_PINBAR:      pat_str = "Pinbar";      break;
      case PATTERN_ENGULFING:   pat_str = "Engulfing";   break;
      case PATTERN_OUTSIDE_BAR: pat_str = "OutsideBar";  break;
      case PATTERN_LARGE_WICK:  pat_str = "LargeWick";   break;
      default:                  pat_str = "Pattern";      break;
   }

   string msg = "RP REACTION " + _Symbol + " " + TFToString(Period()) +
                " | " + pat_str + "@" +
                DoubleToString(rp.price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                " | Score:" + DoubleToString(rp.final_score, 0);

   //--- Add R:R if setup exists
   for(int s = 0; s < g_setup_count; s++)
   {
      if(g_setup_array[s].rp_id == rp.id && g_setup_array[s].is_active)
      {
         msg += " | R:R=" + DoubleToString(g_setup_array[s].rr_ratio1, 1);
         break;
      }
   }

   SendRPAlert(2, rp_index, msg);
   return true;
}

//+------------------------------------------------------------------+
//| CheckRoleReversalAlert (Level 3)                                   |
//+------------------------------------------------------------------+
bool CheckRoleReversalAlert(int rp_index)
{
   SReactionPoint rp = g_rp_array[rp_index];
   if(rp.alert_sent[2]) return false;
   if(!rp.is_role_reversed) return false;

   string new_type = (rp.rp_type == RP_SUPPORT) ? "SUPPORT" : "RESISTANCE";

   string msg = "ROLE REVERSAL " + _Symbol + " " + TFToString(Period()) +
                " | " + DoubleToString(rp.price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                " -> " + new_type +
                " | Score:" + DoubleToString(rp.final_score, 0);

   SendRPAlert(3, rp_index, msg);
   return true;
}

//+------------------------------------------------------------------+
//| CheckPremiumAlert (Level 4)                                        |
//+------------------------------------------------------------------+
bool CheckPremiumAlert(int rp_index)
{
   SReactionPoint rp = g_rp_array[rp_index];
   if(rp.alert_sent[3]) return false;
   if(rp.final_score < 120.0) return false;
   if(!rp.is_confluence) return false;

   //--- Count TFs aligned
   string tf_desc = "";
   for(int z = 0; z < g_confluence_count; z++)
   {
      for(int k = 0; k < g_confluence_array[z].rp_count; k++)
      {
         if(g_confluence_array[z].rp_ids[k] == rp.id)
         {
            tf_desc = g_confluence_array[z].tf_description;
            break;
         }
      }
      if(StringLen(tf_desc) > 0) break;
   }

   string msg = "PREMIUM " + _Symbol +
                " | " + DoubleToString(rp.zone_low, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                "-" + DoubleToString(rp.zone_high, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                " | Score:" + DoubleToString(rp.final_score, 0) +
                " | " + tf_desc + " aligned";

   SendRPAlert(4, rp_index, msg);
   return true;
}

//+------------------------------------------------------------------+
//| ResetAlertIfDistant — reset alert_sent when price moves away       |
//| Called INSIDE CheckAllAlerts per-RP, NOT in separate loop          |
//+------------------------------------------------------------------+
void ResetAlertIfDistant(int rp_index)
{
   SReactionPoint rp = g_rp_array[rp_index];

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distance = MathAbs(bid - rp.price);

   if(PriceToPips(distance) >= g_reset_alert_pips)
   {
      ArrayInitialize(rp.alert_sent, false);
      g_rp_array[rp_index] = rp;
   }
}

//+------------------------------------------------------------------+
//| CheckAllAlerts — main alert loop                                   |
//| Called from OnCalculate when price moves >= 2 pips (throttled)     |
//+------------------------------------------------------------------+
void CheckAllAlerts()
{
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!SafeRP(i)) break;
      if(!g_rp_array[i].is_active) continue;

      //--- Reset alerts if price moved far away
      ResetAlertIfDistant(i);

      //--- Re-read RP AFTER reset (ResetAlertIfDistant may have cleared alert_sent)
      SReactionPoint rp = g_rp_array[i];

      //--- Early exit: all alerts already sent for this RP
      if(rp.alert_sent[0] && rp.alert_sent[1] &&
         rp.alert_sent[2] && rp.alert_sent[3])
         continue;

      //--- Session filter
      if(g_alert_only_active_sessions && g_current_session == SESSION_DEAD)
         continue;

      bool is_premium_conf = (rp.final_score >= 120.0 && rp.is_confluence);

      //--- Level 4: Premium (always alerts, even in choppy/news)
      if(!rp.alert_sent[3])
         CheckPremiumAlert(i);

      //--- Level 3: Role Reversal (no news/spread filter)
      if(!rp.alert_sent[2])
         CheckRoleReversalAlert(i);

      //--- Level 2: Reaction (blocked by news + spread)
      if(!rp.alert_sent[1])
      {
         bool l2_blocked = false;
         if(!is_premium_conf)
         {
            if(g_news_blackout)  l2_blocked = true;
            if(g_spread_blocked) l2_blocked = true;
         }
         if(!l2_blocked)
            CheckReactionAlert(i);
      }

      //--- Level 1: Proximity (blocked by news only, NOT spread)
      if(!rp.alert_sent[0])
      {
         bool l1_blocked = false;
         if(!is_premium_conf && g_news_blackout)
            l1_blocked = true;
         if(!l1_blocked)
            CheckProximityAlert(i);
      }
   }
}

#endif // RP_ALERTS_MQH
