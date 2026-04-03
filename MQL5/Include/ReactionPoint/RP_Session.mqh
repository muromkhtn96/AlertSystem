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
//| DST-Aware UTC Offset Detection                                     |
//|                                                                    |
//| Problem: Static UTC_Offset input becomes wrong after DST switch.   |
//|   Broker servers shift by ±1 hour during DST transitions.          |
//|   E.g., UTC+3 (winter) → UTC+2 (summer) for some brokers, or      |
//|   UTC+2 → UTC+3 for EET-based brokers.                            |
//|                                                                    |
//| Solution: Compare broker server time with TimeGMT() every new bar.|
//|   TimeGMT() returns UTC from OS clock (DST-aware).                 |
//|   TimeCurrent() returns broker server time.                        |
//|   Difference = actual broker UTC offset, auto-adjusting for DST.   |
//|                                                                    |
//| Fallback: If TimeGMT() unavailable or delta unstable, keep using   |
//|   the manual UTC_Offset input (no regression).                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| GetEffectiveUTCOffset — returns best available UTC offset          |
//+------------------------------------------------------------------+
int GetEffectiveUTCOffset()
{
   if(g_utc_offset_auto_valid)
      return g_utc_offset_auto;
   return g_utc_offset;
}

//+------------------------------------------------------------------+
//| DetectUTCOffset — auto-detect broker UTC offset from TimeGMT()    |
//| Call once per new bar (lightweight — 2 datetime comparisons)       |
//| Uses median of last 5 samples to filter transient spikes           |
//+------------------------------------------------------------------+
void DetectUTCOffset()
{
   datetime server_time = TimeCurrent();
   datetime gmt_time    = TimeGMT();

   //--- Guard: TimeGMT() returns 0 on some terminals or in tester
   if(gmt_time <= 0 || server_time <= 0)
   {
      g_utc_offset_auto_valid = false;
      return;
   }

   //--- Calculate raw offset (round to nearest hour)
   int diff_seconds = (int)(server_time - gmt_time);
   int offset_hours = (int)MathRound((double)diff_seconds / 3600.0);

   //--- Sanity check: valid broker offsets are typically [-12, +14]
   if(offset_hours < -12 || offset_hours > 14)
   {
      g_utc_offset_auto_valid = false;
      return;
   }

   //--- Median filter: collect 5 samples, use median to reject outliers
   //    (e.g., during the exact second of DST switch, values may be unstable)
   static int  offset_samples[5];
   static int  sample_count = 0;
   static int  sample_idx   = 0;

   offset_samples[sample_idx] = offset_hours;
   sample_idx = (sample_idx + 1) % 5;
   if(sample_count < 5) sample_count++;

   //--- Need at least 3 samples for reliable median
   if(sample_count < 3)
   {
      g_utc_offset_auto_valid = false;
      return;
   }

   //--- Sort copy to find median
   int sorted[5];
   int n = MathMin(sample_count, 5);
   for(int i = 0; i < n; i++)
      sorted[i] = offset_samples[i];

   // Simple insertion sort (n <= 5)
   for(int i = 1; i < n; i++)
   {
      int key = sorted[i];
      int j = i - 1;
      while(j >= 0 && sorted[j] > key)
      {
         sorted[j + 1] = sorted[j];
         j--;
      }
      sorted[j + 1] = key;
   }

   int median_offset = sorted[n / 2];

   //--- Detect change from previous auto offset
   if(g_utc_offset_auto_valid && median_offset != g_utc_offset_auto)
   {
      Print("RP: DST offset change detected: UTC+", g_utc_offset_auto,
            " → UTC+", median_offset,
            " (manual input was UTC+", g_utc_offset, ")");
   }

   g_utc_offset_auto = median_offset;
   g_utc_offset_auto_valid = true;
}

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

   // Convert server time to UTC using DST-aware offset
   int effective_offset = GetEffectiveUTCOffset();
   int utc_hour = (dt.hour - effective_offset + 24) % 24;
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

   //--- Pair-specific adjustments (P22b)
   //    Reads from centralized g_pair_profile — no stacking, no ambiguity.
   //    Each pair has ONE definitive session_adj[] array.
   //    Index maps: 0=Asian, 1=LondonOpen, 2=London, 3=NYOpen, 4=NY, 5=Overlap, 6=Dead
   adj += g_pair_profile.session_adj[(int)session];

   return adj;
}

//+------------------------------------------------------------------+
//| Day of week score adjustment                                      |
//+------------------------------------------------------------------+
double GetDayOfWeekAdj()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Convert to UTC hour for Friday check (DST-aware)
   int utc_hour = (dt.hour - GetEffectiveUTCOffset() + 24) % 24;

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
