//+------------------------------------------------------------------+
//|                                             RP_NewsFilter.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Module F — News Filter                     |
//+------------------------------------------------------------------+
#ifndef RP_NEWSFILTER_MQH
#define RP_NEWSFILTER_MQH

#include "RP_Utils.mqh"

//--- Extern inputs
extern bool Use_News_Filter;
extern int  News_Blackout_Minutes;
extern bool News_Filter_High_Only;

//--- Medium impact tracking
bool g_news_medium_nearby = false;

//+------------------------------------------------------------------+
//| Get currency country code for calendar                            |
//+------------------------------------------------------------------+
string GetCurrencyCountry(string currency)
{
   if(currency == "USD") return "US";
   if(currency == "EUR") return "EU";
   if(currency == "GBP") return "GB";
   if(currency == "JPY") return "JP";
   if(currency == "AUD") return "AU";
   if(currency == "NZD") return "NZ";
   if(currency == "CAD") return "CA";
   if(currency == "CHF") return "CH";
   return "";
}

//+------------------------------------------------------------------+
//| Update news filter status                                         |
//+------------------------------------------------------------------+
void UpdateNewsFilter()
{
   if(!Use_News_Filter)
   {
      g_news_blackout = false;
      g_news_medium_nearby = false;
      g_news_status_text = "OFF";
      g_news_status_color = clrDarkGray;
      return;
   }

   // Get base and quote currencies
   string base_currency  = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string quote_currency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);

   datetime from_time = TimeCurrent() - News_Blackout_Minutes * 60;
   datetime to_time   = TimeCurrent() + News_Blackout_Minutes * 60;

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from_time, to_time);

   if(count < 0)
   {
      // Calendar API failed
      g_news_available = false;
      g_news_blackout = false;
      g_news_status_text = "unavailable";
      g_news_status_color = clrWhite;
      return;
   }

   g_news_available = true;
   g_news_blackout = false;
   g_news_medium_nearby = false;

   string closest_event = "";
   int closest_minutes = 9999;
   bool closest_is_upcoming = false;
   bool found_high = false;

   for(int i = 0; i < count; i++)
   {
      // Get event details
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event)) continue;

      // Get country info
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country)) continue;

      // Check if event matches our symbol's currencies
      string country_currency = country.currency;
      if(country_currency != base_currency && country_currency != quote_currency)
         continue;

      // Check impact
      ENUM_CALENDAR_EVENT_IMPACT impact = event.importance;

      if(impact == CALENDAR_IMPACT_LOW) continue;

      if(News_Filter_High_Only && impact != CALENDAR_IMPACT_HIGH)
      {
         // Track medium for dashboard display
         if(impact == CALENDAR_IMPACT_MEDIUM)
            g_news_medium_nearby = true;
         continue;
      }

      // Calculate time difference
      int diff_seconds = (int)(values[i].time - TimeCurrent());
      int diff_minutes = diff_seconds / 60;

      // Check if this is the closest event
      int abs_minutes = MathAbs(diff_minutes);
      if(abs_minutes < MathAbs(closest_minutes))
      {
         closest_minutes = diff_minutes;
         closest_event = event.name;
         closest_is_upcoming = (diff_seconds > 0);

         if(impact == CALENDAR_IMPACT_HIGH)
            found_high = true;
      }

      // High impact → full blackout
      if(impact == CALENDAR_IMPACT_HIGH)
         g_news_blackout = true;
      else if(impact == CALENDAR_IMPACT_MEDIUM)
         g_news_medium_nearby = true;
   }

   // Update status text
   if(g_news_blackout && closest_event != "")
   {
      if(closest_is_upcoming)
      {
         g_news_status_text = closest_event + " in " + IntegerToString(MathAbs(closest_minutes)) + "min";
         g_news_status_color = clrRed;
      }
      else
      {
         g_news_status_text = closest_event + " " + IntegerToString(MathAbs(closest_minutes)) + "min ago";
         g_news_status_color = clrYellow;
      }
   }
   else if(g_news_medium_nearby && closest_event != "")
   {
      g_news_status_text = closest_event + " (Med)";
      g_news_status_color = clrYellow;
   }
   else
   {
      g_news_status_text = "clear";
      g_news_status_color = clrLime;
   }
}

//+------------------------------------------------------------------+
//| Get news score adjustment                                         |
//+------------------------------------------------------------------+
double GetNewsScoreAdjustment()
{
   if(!Use_News_Filter) return 0.0;
   if(g_news_blackout)        return -15.0;
   if(g_news_medium_nearby)   return -10.0;
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if in news blackout                                         |
//+------------------------------------------------------------------+
bool IsInNewsBlackout()
{
   return g_news_blackout;
}

#endif
