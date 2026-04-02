//+------------------------------------------------------------------+
//|                                                 RP_Session.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module E — Session & Day-of-Week           |
//+------------------------------------------------------------------+
#ifndef RP_SESSION_MQH
#define RP_SESSION_MQH

#include "RP_Utils.mqh"

// NO extern/input here — reads g_utc_offset, g_show_session_background from globals

//+------------------------------------------------------------------+
//| Session definitions (UTC)                                         |
//|   Asian         00:00 - 07:00                                     |
//|   London Open   07:00 - 08:30                                     |
//|   London        07:00 - 16:00                                     |
//|   NY Open       13:00 - 14:30                                     |
//|   NY            13:00 - 22:00                                     |
//|   Overlap       13:00 - 16:00                                     |
//|   Dead Zone     22:00 - 00:00                                     |
//| Priority: Overlap > London Open > NY Open > London > NY > Asian  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get session for a specific time                                   |
//+------------------------------------------------------------------+
ENUM_SESSION GetSessionForTime(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);

   // Convert server time to UTC
   int utc_hour = (dt.hour - g_utc_offset + 24) % 24;
   int utc_min  = dt.min;
   double hour_min = utc_hour + utc_min / 60.0;

   // Priority order: Overlap > London Open > NY Open > London > NY > Asian > Dead
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

   return SESSION_DEAD; // 22:00 - 00:00
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
double GetSessionScoreAdj(ENUM_SESSION session)
{
   double adj = 0.0;

   switch(session)
   {
      case SESSION_OVERLAP:     adj = 15.0;  break;
      case SESSION_LONDON_OPEN: adj = 10.0;  break;
      case SESSION_NY_OPEN:     adj = 10.0;  break;
      case SESSION_LONDON:      adj =  5.0;  break;
      case SESSION_NY:          adj =  5.0;  break;
      case SESSION_ASIAN:       adj = -10.0; break;
      case SESSION_DEAD:        adj = -20.0; break;
   }

   //--- Pair-specific adjustments (P22)
   if(g_is_gbp_pair)
   {
      if(session == SESSION_LONDON_OPEN) adj += 5.0;  // GBP reacts strongly at London Open
      if(session == SESSION_LONDON)      adj += 3.0;  // GBP active throughout London
      if(session == SESSION_ASIAN)       adj -= 5.0;  // GBP Asian zones unreliable (-10 → -15)
   }

   if(g_is_jpy_pair)
   {
      if(session == SESSION_ASIAN) adj += 7.0;  // JPY active in Asian (-10 → -3)
      if(session == SESSION_DEAD)  adj += 5.0;  // Less dead for JPY (-20 → -15)
   }

   if(g_is_cross_pair)
   {
      if(session == SESSION_DEAD)    adj += 5.0;  // Crosses less session-dependent
      if(session == SESSION_OVERLAP) adj -= 5.0;  // Overlap less meaningful for crosses (+15 → +10)
   }

   return adj;
}

//+------------------------------------------------------------------+
//| Day of week score adjustment                                      |
//+------------------------------------------------------------------+
double GetDayOfWeekAdj()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Convert to UTC hour for Friday check
   int utc_hour = (dt.hour - g_utc_offset + 24) % 24;

   switch(dt.day_of_week)
   {
      case 1: return -5.0;    // Monday
      case 2: return  0.0;    // Tuesday
      case 3: return  0.0;    // Wednesday
      case 4: return  5.0;    // Thursday
      case 5:                 // Friday
         return (utc_hour >= 15) ? -10.0 : 0.0;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Draw session background rectangles                                |
//| Colors (8-10% opacity via BlendColor):                            |
//|   Asian   = LightCyan                                             |
//|   London  = Lavender                                              |
//|   NY      = LemonChiffon                                          |
//|   Overlap = MistyRose                                             |
//|   Dead    = Gainsboro                                              |
//| Name prefix: OBJECT_PREFIX + "SESS_"                              |
//+------------------------------------------------------------------+
color GetSessionRawColor(ENUM_SESSION sess)
{
   switch(sess)
   {
      case SESSION_ASIAN:       return clrLightCyan;
      case SESSION_LONDON_OPEN: return clrLavender;
      case SESSION_LONDON:      return clrLavender;
      case SESSION_NY_OPEN:     return clrLemonChiffon;
      case SESSION_NY:          return clrLemonChiffon;
      case SESSION_OVERLAP:     return clrMistyRose;
      case SESSION_DEAD:        return clrGainsboro;
   }
   return clrGainsboro;
}

// DrawSessionBackgrounds removed — replaced by CreateSessionObjects() + UpdateSessionVisibility() in RP_Drawing.mqh

#endif // RP_SESSION_MQH
