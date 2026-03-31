//+------------------------------------------------------------------+
//|                                                 RP_Logger.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        P26: Zone Event Logging for Optimization   |
//+------------------------------------------------------------------+
#ifndef RP_LOGGER_MQH
#define RP_LOGGER_MQH

#include "RP_Defines.mqh"

//+------------------------------------------------------------------+
//| Global — Logger state                                             |
//+------------------------------------------------------------------+
bool   g_use_logger        = false;
int    g_log_handle_zones  = INVALID_HANDLE;
int    g_log_handle_tests  = INVALID_HANDLE;
int    g_log_handle_outcomes = INVALID_HANDLE;
string g_log_folder        = "RP_Logs";

//+------------------------------------------------------------------+
//| Outcome tracking — pending reaction measurement                   |
//+------------------------------------------------------------------+
#define MAX_PENDING_OUTCOMES 50

struct SPendingOutcome
{
   int      rp_id;
   int      bar_tested;         // Bar when test occurred
   double   zone_high;
   double   zone_low;
   double   test_price;         // Close at test time
   ENUM_RP_TYPE rp_type;
   double   final_score;
   int      test_count_at_test;
   bool     is_active;
};

SPendingOutcome g_pending_outcomes[];
int             g_pending_count = 0;

//+------------------------------------------------------------------+
//| InitLogger — open CSV files with headers                          |
//| Called from OnInit() when g_use_logger == true                    |
//+------------------------------------------------------------------+
bool InitLogger()
{
   if(!g_use_logger) return true;

   ArrayResize(g_pending_outcomes, MAX_PENDING_OUTCOMES);
   for(int i = 0; i < MAX_PENDING_OUTCOMES; i++)
      g_pending_outcomes[i].is_active = false;
   g_pending_count = 0;

   string symbol = _Symbol;
   string tf_str = EnumToString(Period());
   string prefix = g_log_folder + "/" + symbol + "_" + tf_str;

   //--- Zone Created log
   g_log_handle_zones = FileOpen(prefix + "_zones.csv",
      FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(g_log_handle_zones == INVALID_HANDLE)
   {
      Print("RP_Logger: Failed to open zones log: ", GetLastError());
      return false;
   }
   FileWrite(g_log_handle_zones,
      "timestamp", "rp_id", "type", "price", "zone_high", "zone_low",
      "zone_width_pips", "atr14_pips", "width_atr_ratio",
      "pattern", "reaction_pips", "volume_ratio",
      "session", "regime", "has_wick_filter",
      "base_score", "final_score", "level");

   //--- Test Events log
   g_log_handle_tests = FileOpen(prefix + "_tests.csv",
      FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(g_log_handle_tests == INVALID_HANDLE)
   {
      Print("RP_Logger: Failed to open tests log: ", GetLastError());
      return false;
   }
   FileWrite(g_log_handle_tests,
      "timestamp", "rp_id", "test_number", "is_body_test",
      "test_volume", "volume_vs_ma20",
      "zone_width_before", "zone_width_after",
      "reaction_bar_low", "reaction_bar_high", "reaction_bar_close",
      "score_at_test");

   //--- Outcome log (reaction measurement)
   g_log_handle_outcomes = FileOpen(prefix + "_outcomes.csv",
      FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(g_log_handle_outcomes == INVALID_HANDLE)
   {
      Print("RP_Logger: Failed to open outcomes log: ", GetLastError());
      return false;
   }
   FileWrite(g_log_handle_outcomes,
      "timestamp", "rp_id", "type", "score_at_test",
      "test_count", "max_favorable_pips", "max_adverse_pips",
      "bars_to_max_favorable", "outcome",
      "session", "regime", "pattern",
      "has_wick_filter", "strong_tests", "weak_tests",
      "zone_width_pips", "width_atr_ratio");

   Print("RP_Logger: Initialized — ", prefix);
   return true;
}

//+------------------------------------------------------------------+
//| DeinitLogger — flush and close all files                          |
//+------------------------------------------------------------------+
void DeinitLogger()
{
   if(g_log_handle_zones != INVALID_HANDLE)
   { FileClose(g_log_handle_zones); g_log_handle_zones = INVALID_HANDLE; }
   if(g_log_handle_tests != INVALID_HANDLE)
   { FileClose(g_log_handle_tests); g_log_handle_tests = INVALID_HANDLE; }
   if(g_log_handle_outcomes != INVALID_HANDLE)
   { FileClose(g_log_handle_outcomes); g_log_handle_outcomes = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
//| LogZoneCreated — log when a new RP zone is created                |
//+------------------------------------------------------------------+
void LogZoneCreated(const SReactionPoint &rp)
{
   if(!g_use_logger || g_log_handle_zones == INVALID_HANDLE) return;

   double zone_width = PriceToPips(rp.zone_high - rp.zone_low);
   double atr_pips   = PriceToPips(g_cached_atr14);
   double width_ratio = (atr_pips > 0.0) ? zone_width / atr_pips : 0.0;

   // Volume ratio at formation bar
   long tick_vol = iVolume(_Symbol, PERIOD_CURRENT, rp.bar_formed);
   double vol_ratio = (g_cached_volume_ma20 > 0.0) ? (double)tick_vol / g_cached_volume_ma20 : 0.0;

   FileWrite(g_log_handle_zones,
      TimeToString(rp.time_formed, TIME_DATE | TIME_MINUTES),
      rp.id,
      (rp.rp_type == RP_SUPPORT) ? "SUPPORT" : "RESISTANCE",
      DoubleToString(rp.price, (int)_Digits),
      DoubleToString(rp.zone_high, (int)_Digits),
      DoubleToString(rp.zone_low, (int)_Digits),
      DoubleToString(zone_width, 1),
      DoubleToString(atr_pips, 1),
      DoubleToString(width_ratio, 3),
      EnumToString(rp.candle_pattern),
      DoubleToString(rp.initial_reaction_pips, 1),
      DoubleToString(vol_ratio, 2),
      EnumToString(rp.session_formed),
      EnumToString(g_current_regime),
      rp.has_wick_filter ? "Y" : "N",
      DoubleToString(rp.base_score, 1),
      DoubleToString(rp.final_score, 1),
      EnumToString(rp.rp_level));
}

//+------------------------------------------------------------------+
//| LogZoneTest — log each test event with quality details            |
//+------------------------------------------------------------------+
void LogZoneTest(const SReactionPoint &rp, bool is_body_test,
                 double zone_width_before, double zone_width_after,
                 double low_1, double high_1, double close_1,
                 long test_volume)
{
   if(!g_use_logger || g_log_handle_tests == INVALID_HANDLE) return;

   double vol_vs_ma = (g_cached_volume_ma20 > 0.0) ?
      (double)test_volume / g_cached_volume_ma20 : 0.0;

   FileWrite(g_log_handle_tests,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
      rp.id,
      rp.test_count,
      is_body_test ? "BODY" : "WICK",
      (long)test_volume,
      DoubleToString(vol_vs_ma, 2),
      DoubleToString(PriceToPips(zone_width_before), 1),
      DoubleToString(PriceToPips(zone_width_after), 1),
      DoubleToString(low_1, (int)_Digits),
      DoubleToString(high_1, (int)_Digits),
      DoubleToString(close_1, (int)_Digits),
      DoubleToString(rp.final_score, 1));

   //--- Register pending outcome for reaction measurement
   RegisterPendingOutcome(rp);
}

//+------------------------------------------------------------------+
//| LogZoneBroken — log when zone is broken                           |
//+------------------------------------------------------------------+
void LogZoneBroken(const SReactionPoint &rp)
{
   if(!g_use_logger || g_log_handle_outcomes == INVALID_HANDLE) return;

   double zone_width = PriceToPips(rp.zone_high - rp.zone_low);
   double atr_pips = PriceToPips(g_cached_atr14);
   double width_ratio = (atr_pips > 0.0) ? zone_width / atr_pips : 0.0;

   FileWrite(g_log_handle_outcomes,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
      rp.id,
      (rp.rp_type == RP_SUPPORT) ? "SUPPORT" : "RESISTANCE",
      DoubleToString(rp.final_score, 1),
      rp.test_count,
      0.0, 0.0, 0,  // no favorable move — broken
      "BROKEN",
      EnumToString(rp.session_formed),
      EnumToString(g_current_regime),
      EnumToString(rp.candle_pattern),
      rp.has_wick_filter ? "Y" : "N",
      rp.strong_test_count,
      rp.weak_test_count,
      DoubleToString(zone_width, 1),
      DoubleToString(width_ratio, 3));
}

//+------------------------------------------------------------------+
//| RegisterPendingOutcome — queue for reaction measurement           |
//+------------------------------------------------------------------+
void RegisterPendingOutcome(const SReactionPoint &rp)
{
   // Find empty slot or overwrite oldest
   int slot = -1;
   for(int i = 0; i < MAX_PENDING_OUTCOMES; i++)
   {
      if(!g_pending_outcomes[i].is_active)
      { slot = i; break; }
   }
   if(slot < 0)
   {
      // Overwrite oldest
      int oldest = 0;
      int oldest_bar = INT_MAX;
      for(int i = 0; i < MAX_PENDING_OUTCOMES; i++)
      {
         if(g_pending_outcomes[i].bar_tested < oldest_bar)
         { oldest_bar = g_pending_outcomes[i].bar_tested; oldest = i; }
      }
      slot = oldest;
   }

   g_pending_outcomes[slot].rp_id            = rp.id;
   g_pending_outcomes[slot].bar_tested       = Bars(_Symbol, PERIOD_CURRENT) - 1;
   g_pending_outcomes[slot].zone_high        = rp.zone_high;
   g_pending_outcomes[slot].zone_low         = rp.zone_low;
   g_pending_outcomes[slot].test_price       = RP_Close(1);
   g_pending_outcomes[slot].rp_type          = rp.rp_type;
   g_pending_outcomes[slot].final_score      = rp.final_score;
   g_pending_outcomes[slot].test_count_at_test = rp.test_count;
   g_pending_outcomes[slot].is_active        = true;
   if(g_pending_count < MAX_PENDING_OUTCOMES)
      g_pending_count++;
}

//+------------------------------------------------------------------+
//| CheckPendingOutcomes — measure reaction after N bars              |
//| Called once per new bar from OnCalculate                           |
//+------------------------------------------------------------------+
void CheckPendingOutcomes(int measure_bars)
{
   if(!g_use_logger || g_log_handle_outcomes == INVALID_HANDLE) return;

   int current_bar = Bars(_Symbol, PERIOD_CURRENT) - 1;

   for(int i = 0; i < MAX_PENDING_OUTCOMES; i++)
   {
      if(!g_pending_outcomes[i].is_active) continue;

      int bars_elapsed = current_bar - g_pending_outcomes[i].bar_tested;
      if(bars_elapsed < measure_bars) continue;

      //--- Measure max favorable and adverse move
      double max_favorable = 0.0;
      double max_adverse   = 0.0;
      int    bars_to_max   = 0;

      for(int j = 1; j <= measure_bars; j++)
      {
         int bar_idx = current_bar - g_pending_outcomes[i].bar_tested - j;
         if(bar_idx < 1) bar_idx = 1;
         // Convert to actual bar shift from current
         int shift = current_bar - (g_pending_outcomes[i].bar_tested + j);
         if(shift < 1 || shift > current_bar) continue;

         double close_j = RP_Close(shift);
         if(close_j == 0.0) continue;

         double move = 0.0;
         if(g_pending_outcomes[i].rp_type == RP_SUPPORT)
            move = close_j - g_pending_outcomes[i].test_price;
         else
            move = g_pending_outcomes[i].test_price - close_j;

         double move_pips = PriceToPips(MathAbs(move));

         if(move > 0 && PriceToPips(move) > max_favorable)
         {
            max_favorable = PriceToPips(move);
            bars_to_max = j;
         }
         if(move < 0 && move_pips > max_adverse)
            max_adverse = move_pips;
      }

      //--- Classify outcome
      double atr_pips = PriceToPips(g_cached_atr14);
      string outcome;
      if(max_favorable >= atr_pips)
         outcome = "STRONG_REACT";      // Moved >= 1x ATR in favorable direction
      else if(max_favorable >= atr_pips * 0.5)
         outcome = "WEAK_REACT";        // Moved 0.5-1x ATR
      else if(max_adverse >= atr_pips * 0.5)
         outcome = "FAILED";            // Adverse move >= 0.5x ATR
      else
         outcome = "NEUTRAL";           // No significant move either way

      //--- Find the RP for additional data
      string session_str = "N/A";
      string regime_str  = EnumToString(g_current_regime);
      string pattern_str = "N/A";
      string wick_str    = "N";
      int    strong_t    = 0;
      int    weak_t      = 0;
      double zone_width  = PriceToPips(g_pending_outcomes[i].zone_high - g_pending_outcomes[i].zone_low);
      double width_ratio = (atr_pips > 0.0) ? zone_width / atr_pips : 0.0;

      for(int k = 0; k < g_rp_count; k++)
      {
         if(g_rp_array[k].id == g_pending_outcomes[i].rp_id)
         {
            session_str = EnumToString(g_rp_array[k].session_formed);
            pattern_str = EnumToString(g_rp_array[k].candle_pattern);
            wick_str    = g_rp_array[k].has_wick_filter ? "Y" : "N";
            strong_t    = g_rp_array[k].strong_test_count;
            weak_t      = g_rp_array[k].weak_test_count;
            break;
         }
      }

      FileWrite(g_log_handle_outcomes,
         TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
         g_pending_outcomes[i].rp_id,
         (g_pending_outcomes[i].rp_type == RP_SUPPORT) ? "SUPPORT" : "RESISTANCE",
         DoubleToString(g_pending_outcomes[i].final_score, 1),
         g_pending_outcomes[i].test_count_at_test,
         DoubleToString(max_favorable, 1),
         DoubleToString(max_adverse, 1),
         bars_to_max,
         outcome,
         session_str, regime_str, pattern_str,
         wick_str, strong_t, weak_t,
         DoubleToString(zone_width, 1),
         DoubleToString(width_ratio, 3));

      g_pending_outcomes[i].is_active = false;
   }
}

#endif // RP_LOGGER_MQH
