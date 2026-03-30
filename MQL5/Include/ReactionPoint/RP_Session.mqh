//+------------------------------------------------------------------+
//|                                                 RP_Session.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module E — Session Detection               |
//+------------------------------------------------------------------+
#ifndef RP_SESSION_MQH
#define RP_SESSION_MQH

#include "RP_Utils.mqh"

//--- Extern inputs
extern int  UTC_Offset;
extern bool Show_Session_Background;

//+------------------------------------------------------------------+
//| Get session for a specific time                                   |
//+------------------------------------------------------------------+
ENUM_SESSION GetSessionForTime(datetime time)
{
   datetime utc_time = time - UTC_Offset * 3600;
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);
   double hour_min = dt.hour + dt.min / 60.0;

   // Priority: Overlap > London Open > NY Open > London > NY > Asian > Dead
   if(hour_min >= 13.0 && hour_min < 16.0)
      return SESSION_OVERLAP;
   if(hour_min >= 7.0 && hour_min < 8.5)
      return SESSION_LONDON_OPEN;
   if(hour_min >= 13.0 && hour_min < 14.5)
      return SESSION_NY_OPEN;
   if(hour_min >= 7.0 && hour_min < 16.0)
      return SESSION_LONDON;
   if(hour_min >= 13.0 && hour_min < 22.0)
      return SESSION_NY;
   if(hour_min >= 0.0 && hour_min < 7.0)
      return SESSION_ASIAN;

   return SESSION_DEAD; // 22:00-00:00
}

//+------------------------------------------------------------------+
//| Update current session                                            |
//+------------------------------------------------------------------+
void UpdateCurrentSession()
{
   g_current_session = GetSessionForTime(TimeCurrent());
}

//+------------------------------------------------------------------+
//| Session score adjustment                                          |
//+------------------------------------------------------------------+
double GetSessionScoreAdjustment()
{
   switch(g_current_session)
   {
      case SESSION_OVERLAP:     return 15.0;
      case SESSION_LONDON_OPEN: return 10.0;
      case SESSION_NY_OPEN:     return 10.0;
      case SESSION_LONDON:      return 5.0;
      case SESSION_NY:          return 5.0;
      case SESSION_ASIAN:       return -10.0;
      case SESSION_DEAD:        return -20.0;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Day of week score adjustment                                      |
//+------------------------------------------------------------------+
double GetDayOfWeekAdjustment()
{
   datetime utc_time = TimeCurrent() - UTC_Offset * 3600;
   MqlDateTime dt;
   TimeToStruct(utc_time, dt);

   switch(dt.day_of_week)
   {
      case 1: return -5.0;   // Monday
      case 2: return 0.0;    // Tuesday
      case 3: return 0.0;    // Wednesday
      case 4: return 5.0;    // Thursday
      case 5:                // Friday
         return (dt.hour >= 15) ? -10.0 : 0.0;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Session color for background                                      |
//+------------------------------------------------------------------+
color GetSessionBGColor(ENUM_SESSION sess)
{
   switch(sess)
   {
      case SESSION_ASIAN:       return clrLavender;
      case SESSION_LONDON_OPEN: return clrMistyRose;
      case SESSION_LONDON:      return clrMistyRose;
      case SESSION_NY_OPEN:     return clrLightCyan;
      case SESSION_NY:          return clrLightCyan;
      case SESSION_OVERLAP:     return clrLemonChiffon;
      case SESSION_DEAD:        return clrGainsboro;
   }
   return clrGainsboro;
}

//+------------------------------------------------------------------+
//| Session icon for dashboard                                        |
//+------------------------------------------------------------------+
string GetSessionIcon(ENUM_SESSION sess)
{
   switch(sess)
   {
      case SESSION_OVERLAP:     return "●";  // green
      case SESSION_LONDON_OPEN: return "●";
      case SESSION_NY_OPEN:     return "●";
      case SESSION_LONDON:      return "●";
      case SESSION_NY:          return "●";
      case SESSION_ASIAN:       return "○";
      case SESSION_DEAD:        return "○";
   }
   return "○";
}

//+------------------------------------------------------------------+
//| Draw session background rectangles                                |
//+------------------------------------------------------------------+
void DrawSessionBackgrounds(int bars_visible)
{
   if(!Show_Session_Background) return;

   // Delete old session backgrounds
   ObjectsDeleteAll(0, OBJECT_PREFIX + "SES_");

   // Draw backgrounds for visible bars
   ENUM_SESSION prev_session = SESSION_DEAD;
   datetime sess_start = 0;
   int obj_idx = 0;

   for(int i = bars_visible; i >= 0; i--)
   {
      datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, i);
      if(bar_time == 0) continue;
      ENUM_SESSION sess = GetSessionForTime(bar_time);

      if(sess != prev_session || i == 0)
      {
         // Close previous session block
         if(sess_start > 0 && prev_session != SESSION_DEAD)
         {
            string name = OBJECT_PREFIX + "SES_" + IntegerToString(obj_idx++);
            datetime end_time = iTime(_Symbol, PERIOD_CURRENT, (i == 0) ? 0 : i + 1);

            double chart_high = ChartGetDouble(0, CHART_PRICE_MAX);
            double chart_low  = ChartGetDouble(0, CHART_PRICE_MIN);

            if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, sess_start, chart_high, end_time, chart_low))
            {
               color clr = GetSessionBGColor(prev_session);
               ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
            }
         }
         sess_start = bar_time;
         prev_session = sess;
      }
   }
}

#endif
