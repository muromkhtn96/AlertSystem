//+------------------------------------------------------------------+
//|                                             RP_NewsFilter.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Module F — News Filter                     |
//+------------------------------------------------------------------+
#ifndef RP_NEWSFILTER_MQH
#define RP_NEWSFILTER_MQH

#include "RP_Utils.mqh"

// NO extern/input here — reads g_use_news_filter, g_news_blackout_minutes,
// g_news_filter_high_only from globals

//--- Medium impact tracking
bool g_news_medium_nearby = false;

//--- Throttle: only call Calendar API every 5 minutes (300s)
datetime g_news_last_update = 0;

//--- Exponential backoff for API failures
int      g_news_fail_count  = 0;
datetime g_news_next_retry  = 0;

//+------------------------------------------------------------------+
//| Update news filter status                                         |
//| PERFORMANCE: throttled to run every 5 minutes, NOT every bar      |
//| On API failure: exponential backoff 5min → 10min → 20min → 30min  |
//+------------------------------------------------------------------+
void UpdateNewsFilter()
{
   if(!g_use_news_filter)
   {
      g_news_blackout       = false;
      g_news_medium_nearby  = false;
      g_news_status_text    = "OFF";
      g_news_status_color   = clrDarkGray;
      return;
   }

   //--- Throttle: skip if updated within 300 seconds
   datetime now = TimeCurrent();
   if(g_news_last_update > 0 && (now - g_news_last_update) < 300)
      return;

   //--- Backoff: skip if not yet time to retry after failure
   if(g_news_next_retry > 0 && now < g_news_next_retry)
      return;

   //--- Get base and quote currencies from symbol
   string base_currency  = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string quote_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);

   datetime from_time = now - g_news_blackout_minutes * 60;
   datetime to_time   = now + g_news_blackout_minutes * 60;

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from_time, to_time);

   if(count < 0)
   {
      //--- Calendar API failed — exponential backoff
      g_news_available = false;
      g_news_blackout  = false;
      g_news_status_text  = "unavailable";
      g_news_status_color = clrWhite;

      g_news_fail_count++;
      int wait_seconds = MathMin(300 * (int)MathPow(2, g_news_fail_count - 1), 1800);
      g_news_next_retry = now + wait_seconds;
      return;
   }

   //--- API success — reset backoff
   g_news_available   = true;
   g_news_fail_count  = 0;
   g_news_next_retry  = 0;
   g_news_last_update = now;

   g_news_blackout      = false;
   g_news_medium_nearby = false;

   string closest_event     = "";
   int    closest_minutes   = 9999;
   bool   closest_is_upcoming = false;

   for(int i = 0; i < count; i++)
   {
      //--- Get event details
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event)) continue;

      //--- Get country info to match currency
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country)) continue;

      string event_currency = country.currency;
      if(event_currency != base_currency && event_currency != quote_currency)
         continue;

      //--- Check importance (MQL5 uses CALENDAR_IMPORTANCE_*, not IMPACT)
      ENUM_CALENDAR_EVENT_IMPORTANCE importance = event.importance;

      if(importance == CALENDAR_IMPORTANCE_LOW)
         continue;

      if(g_news_filter_high_only && importance != CALENDAR_IMPORTANCE_HIGH)
      {
         // Track medium for dashboard display only
         if(importance == CALENDAR_IMPORTANCE_MODERATE)
            g_news_medium_nearby = true;
         continue;
      }

      //--- Calculate time difference
      int diff_seconds = (int)(values[i].time - now);
      int diff_minutes = diff_seconds / 60;
      int abs_minutes  = (int)MathAbs(diff_minutes);

      //--- Track closest event for status text
      if(abs_minutes < (int)MathAbs(closest_minutes))
      {
         closest_minutes     = diff_minutes;
         closest_event       = event.name;
         closest_is_upcoming = (diff_seconds > 0);
      }

      //--- High impact → full blackout
      if(importance == CALENDAR_IMPORTANCE_HIGH)
         g_news_blackout = true;
      else if(importance == CALENDAR_IMPORTANCE_MODERATE)
         g_news_medium_nearby = true;
   }

   //--- Update status text for dashboard
   if(g_news_blackout && closest_event != "")
   {
      if(closest_is_upcoming)
      {
         g_news_status_text  = closest_event + " in " + IntegerToString((int)MathAbs(closest_minutes)) + "min";
         g_news_status_color = clrRed;
      }
      else
      {
         g_news_status_text  = closest_event + " " + IntegerToString((int)MathAbs(closest_minutes)) + "min ago";
         g_news_status_color = clrYellow;
      }
   }
   else if(g_news_medium_nearby && closest_event != "")
   {
      g_news_status_text  = closest_event + " (Med)";
      g_news_status_color = clrYellow;
   }
   else
   {
      g_news_status_text  = "clear";
      g_news_status_color = clrLime;
   }
}

//+------------------------------------------------------------------+
//| Get news temporary score adjustment                               |
//| Blackout (High)  → -15                                            |
//| Warning (Medium) → -10                                            |
//| Clear            →  0                                              |
//+------------------------------------------------------------------+
double GetNewsTempScoreAdj()
{
   if(!g_use_news_filter) return 0.0;
   if(g_news_blackout)      return -15.0;
   if(g_news_medium_nearby) return -10.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if in news blackout                                         |
//+------------------------------------------------------------------+
bool IsInNewsBlackout()
{
   return g_news_blackout;
}

#endif // RP_NEWSFILTER_MQH
