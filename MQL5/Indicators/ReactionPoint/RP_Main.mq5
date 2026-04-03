//+------------------------------------------------------------------+
//|                                                   RP_Main.mq5    |
//|                        Reaction Point Indicator v3.0              |
//|                        Main Indicator File                        |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property description "Reaction Point Indicator v3.0 — Multi-TF S/R with scoring"

//+------------------------------------------------------------------+
//| Includes (order matters — dependencies must come first)           |
//+------------------------------------------------------------------+
#include <ReactionPoint/RP_Defines.mqh>
#include <ReactionPoint/RP_Utils.mqh>
#include <ReactionPoint/RP_RegimeFilter.mqh>
#include <ReactionPoint/RP_Session.mqh>
#include <ReactionPoint/RP_DynamicDecay.mqh>
#include <ReactionPoint/RP_NewsFilter.mqh>
#include <ReactionPoint/RP_SpreadFilter.mqh>
#include <ReactionPoint/RP_Detection.mqh>
#include <ReactionPoint/RP_MarketStructure.mqh>
#include <ReactionPoint/RP_FVG.mqh>
#include <ReactionPoint/RP_Confluence.mqh>
#include <ReactionPoint/RP_Scoring.mqh>
#include <ReactionPoint/RP_EntrySetup.mqh>
#include <ReactionPoint/RP_Stats.mqh>
#include <ReactionPoint/RP_Drawing.mqh>
#include <ReactionPoint/RP_Dashboard.mqh>
#include <ReactionPoint/RP_Alerts.mqh>
#include <ReactionPoint/RP_Logger.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- Preset
input ENUM_TF_PRESET TF_Preset               = PRESET_AUTO;
input bool   Clean_Chart_Mode                 = true;     // Clean mode: zones only, no labels/dashboard/panels

//--- Swing Detection
input int    Swing_Lookback                   = 3;       // Swing lookback [1-10]
input int    Min_RP_Distance_Pips             = 20;      // Min distance between RPs [5-100]
input int    Min_Reaction_Move_Pips           = 15;      // Min reaction move [5-100]
input int    Initial_Bars_To_Scan             = 500;     // Bars to scan on first run [50-2000]
input bool   Use_Adaptive_Reaction            = true;    // Use ATR-based reaction
input double Reaction_ATR_Multiplier          = 0.5;     // ATR multiplier for reaction

//--- Breakout
input int    Breakout_Confirm_Pips            = 5;       // Breakout confirmation [1-50]
input int    Max_Retest_Bars                  = 50;      // Max bars for retest [10-200]

//--- Regime (Module A)
input int    ADX_Period                       = 14;      // ADX period
input double ADX_Strong_Threshold             = 25.0;    // ADX strong trend threshold
input double ADX_Weak_Threshold               = 20.0;    // ADX weak trend threshold
input bool   Use_Regime_Filter                = true;    // Enable regime filter

//--- Decay (Module B)
input int    Decay_Interval_Bars              = 20;      // Bars between decay
input int    Decay_Points_Per_Interval        = 2;       // Points lost per interval
input int    Max_RP_Age_Bars                  = 300;     // Max RP age in bars
input bool   Use_Dynamic_Score                = true;    // Enable dynamic scoring

//--- Entry (Module C)
input bool   Show_Entry_Setup                 = true;    // Show entry setups
input int    SL_Buffer_Pips                   = 5;       // SL buffer pips
input int    Entry_Buffer_Pips                = 2;       // Entry buffer pips
input double Min_RR_Ratio                     = 1.5;     // Minimum R:R ratio
input int    Max_Setup_Age_Bars               = 10;      // Max setup age bars

//--- Confluence (Module D)
input int    Confluence_Merge_Pips            = 10;      // Merge distance pips
input bool   Use_Confluence_Zones             = true;    // Enable confluence zones
input int    HTF_Bars_To_Scan                 = 200;     // HTF bars to scan

//--- Session (Module E)
input int    UTC_Offset                       = 3;       // UTC offset (broker)
input bool   Alert_Only_Active_Sessions       = true;    // Alert only in active sessions
input bool   Show_Session_Background          = true;    // Show session backgrounds

//--- Fibonacci
input int    Fibo_Lookback_Bars               = 100;     // Fibonacci lookback
input int    Fibo_Tolerance_Pips              = 5;       // Fibonacci tolerance

//--- Candle
input int    Min_Candle_Size_Pips             = 3;       // Min candle size filter

//--- News (Module F)
input bool   Use_News_Filter                  = true;    // Enable news filter
input int    News_Blackout_Minutes            = 30;      // News blackout minutes
input bool   News_Filter_High_Only            = false;   // High-impact news only

//--- Spread (Module G)
input bool   Use_Spread_Filter                = true;    // Enable spread filter
input double Spread_Alert_Multiplier          = 2.0;     // Spread alert threshold
input double Spread_Block_Multiplier          = 3.0;     // Spread block threshold

//--- Market Structure (Module H)
input bool   Use_Market_Structure             = true;    // Enable BOS/CHoCH
input int    Structure_Lookback_Bars          = 50;      // Structure lookback [20-100]

//--- Trend Alignment (Phase 7 — P20)
input bool   Use_Trend_Alignment              = true;    // Multi-TF trend alignment filter

//--- Multi-Timeframe
input bool             Show_HTF_1             = true;    // Show HTF 1
input ENUM_TIMEFRAMES  HTF_1                  = PERIOD_H4;  // Higher TF 1
input bool             Show_HTF_2             = true;    // Show HTF 2
input ENUM_TIMEFRAMES  HTF_2                  = PERIOD_D1;  // Higher TF 2

//--- Display
input int              Zone_Width_Pips        = 4;       // Zone width in pips
input int              Min_Score_To_Show      = 40;      // Min score to display
input bool             Show_Premium           = true;    // Show Premium zones (score>=120)
input bool             Show_Level1            = false;   // Show Level 1 zones (score>=80)
input bool             Show_Level2            = false;   // Show Level 2 zones (score>=60)
input bool             Show_Level3            = false;   // Show Level 3 zones (score>=40)
input bool             Show_Dashboard         = true;    // Show dashboard
input bool             Show_Performance_Stats = true;    // Show hit rate stats
input bool             Enable_System_Alert    = false;   // Enable Alert() popup
input bool             Enable_Push_Notify     = false;   // Enable push notification
input int              Proximity_Alert_Pips   = 20;      // Proximity alert distance
input int              Reset_Alert_Pips       = 30;      // Alert reset distance
input ENUM_DASH_CORNER Dashboard_Corner       = DASH_TOP_LEFT; // Dashboard corner
input int              Dashboard_Font_Size    = 9;       // Dashboard font size
input int              Label_Font_Size        = 8;       // Zone label font size

//--- Data Logger (P26)
input bool   Enable_Logger                    = false;   // Log zone data to CSV for optimization
input int    Outcome_Measure_Bars             = 20;      // Bars after test to measure reaction

//--- Colors
input color  Color_Premium                    = clrGold;
input color  Color_Level1                     = clrCrimson;
input color  Color_Level2                     = clrOrange;
input color  Color_Level3                     = clrSkyBlue;
input color  Color_Confluence                 = clrMediumPurple;
input color  Color_RoleReversal               = clrMagenta;
input color  Color_EntryBuy                   = clrLimeGreen;
input color  Color_EntrySell                  = clrRed;

//+------------------------------------------------------------------+
//| Static variables for OnCalculate state                            |
//+------------------------------------------------------------------+
static bool     s_first_run       = true;
static datetime s_last_news_check = 0;
static int      s_last_bar_count  = 0;

//+------------------------------------------------------------------+
//| ApplyTFPreset — set globals from TF preset table                  |
//+------------------------------------------------------------------+
void ApplyTFPreset()
{
   //--- Clean Chart Mode — override display settings
   g_clean_chart_mode = Clean_Chart_Mode;

   //--- Always copy non-preset inputs to globals first
   g_use_adaptive_reaction   = Use_Adaptive_Reaction;
   g_reaction_atr_multiplier = Reaction_ATR_Multiplier;
   g_use_regime_filter       = Use_Regime_Filter;
   g_adx_period              = ADX_Period;
   g_adx_strong_threshold    = ADX_Strong_Threshold;
   g_adx_weak_threshold      = ADX_Weak_Threshold;
   g_use_dynamic_score       = Use_Dynamic_Score;
   g_show_entry_setup        = Show_Entry_Setup;
   g_min_rr_ratio            = Min_RR_Ratio;
   g_use_confluence_zones    = Use_Confluence_Zones;
   g_utc_offset              = UTC_Offset;
   g_alert_only_active_sessions = Alert_Only_Active_Sessions;
   g_enable_system_alert        = Enable_System_Alert;
   g_enable_push_notify         = Enable_Push_Notify;
   g_show_session_background = Show_Session_Background;
   g_use_news_filter         = Use_News_Filter;
   g_news_blackout_minutes   = News_Blackout_Minutes;
   g_news_filter_high_only   = News_Filter_High_Only;
   g_use_spread_filter       = Use_Spread_Filter;
   g_spread_alert_multiplier = Spread_Alert_Multiplier;
   g_spread_block_multiplier = Spread_Block_Multiplier;
   g_use_market_structure    = Use_Market_Structure;
   g_use_trend_alignment     = Use_Trend_Alignment;
   g_show_htf_1              = Show_HTF_1;
   g_show_htf_2              = Show_HTF_2;
   g_show_dashboard          = Show_Dashboard;
   g_show_performance_stats  = Show_Performance_Stats;
   g_use_logger              = Enable_Logger;

   //--- Clean mode: force-disable all UI clutter
   if(g_clean_chart_mode)
   {
      g_show_dashboard         = false;
      g_show_entry_setup       = false;
      g_show_session_background= false;
      g_show_performance_stats = false;
   }
   //--- Level toggle inputs
   g_show_premium  = Show_Premium;
   g_show_level1   = Show_Level1;
   g_show_level2   = Show_Level2;
   g_show_level3   = Show_Level3;

   //--- Compute g_show_min_level for backward compat (lowest enabled level)
   if(g_show_level3)       g_show_min_level = RP_LEVEL3;
   else if(g_show_level2)  g_show_min_level = RP_LEVEL2;
   else if(g_show_level1)  g_show_min_level = RP_LEVEL1;
   else                    g_show_min_level = RP_PREMIUM;
   g_dashboard_corner        = Dashboard_Corner;
   g_dashboard_font_size     = Dashboard_Font_Size;
   g_label_font_size         = Label_Font_Size;

   //--- Colors
   g_color_premium       = Color_Premium;
   g_color_level1        = Color_Level1;
   g_color_level2        = Color_Level2;
   g_color_level3        = Color_Level3;
   g_color_confluence    = Color_Confluence;
   g_color_role_reversal = Color_RoleReversal;
   g_color_entry_buy     = Color_EntryBuy;
   g_color_entry_sell    = Color_EntrySell;

   //--- Determine preset
   ENUM_TF_PRESET preset = TF_Preset;
   if(preset == PRESET_AUTO)
   {
      ENUM_TIMEFRAMES tf = Period();
      if(tf <= PERIOD_M15)      preset = PRESET_M15;
      else if(tf <= PERIOD_M30) preset = PRESET_M30;
      else if(tf <= PERIOD_H1)  preset = PRESET_H1;
      else if(tf <= PERIOD_H4)  preset = PRESET_H4;
      else                      preset = PRESET_D1;
   }

   if(preset == PRESET_CUSTOM)
   {
      //--- Use input values directly
      g_swing_lookback            = Swing_Lookback;
      g_min_rp_distance_pips      = Min_RP_Distance_Pips;
      g_min_reaction_move_pips    = Min_Reaction_Move_Pips;
      g_initial_bars_to_scan      = Initial_Bars_To_Scan;
      g_breakout_confirm_pips     = Breakout_Confirm_Pips;
      g_max_retest_bars           = Max_Retest_Bars;
      g_decay_interval_bars       = Decay_Interval_Bars;
      g_decay_points_per_interval = Decay_Points_Per_Interval;
      g_max_rp_age_bars           = Max_RP_Age_Bars;
      g_sl_buffer_pips            = SL_Buffer_Pips;
      g_entry_buffer_pips         = Entry_Buffer_Pips;
      g_max_setup_age_bars        = Max_Setup_Age_Bars;
      g_confluence_merge_pips     = Confluence_Merge_Pips;
      g_htf_bars_to_scan          = HTF_Bars_To_Scan;
      g_fibo_lookback_bars        = Fibo_Lookback_Bars;
      g_fibo_tolerance_pips       = Fibo_Tolerance_Pips;
      g_min_candle_size_pips      = Min_Candle_Size_Pips;
      g_zone_width_pips           = Zone_Width_Pips;
      g_min_score_to_show         = Min_Score_To_Show;
      g_proximity_alert_pips      = Proximity_Alert_Pips;
      g_reset_alert_pips          = Reset_Alert_Pips;
      g_structure_lookback_bars   = Structure_Lookback_Bars;
      g_htf_1                     = HTF_1;
      g_htf_2                     = HTF_2;
      return;
   }

   //--- Apply TF Preset Table values
   switch(preset)
   {
      case PRESET_M15:
         g_swing_lookback            = 7;     // 105 min window — filters M15 noise
         g_min_rp_distance_pips      = 15;    // Tighter spacing for lower volatility
         g_min_reaction_move_pips    = 15;    // Higher floor — rejects wick noise
         g_initial_bars_to_scan      = 1000;  // More bars (denser candles)
         g_breakout_confirm_pips     = 2;     // Faster confirmation
         g_max_retest_bars           = 50;    // Wider retest window
         g_decay_interval_bars       = 60;    // ~15 hrs (proportional to M30's 7.5 hrs)
         g_decay_points_per_interval = 1;     // Gentle decay — zones live longer
         g_max_rp_age_bars           = 500;   // ~5 days (proportional to M30's ~4 days)
         g_sl_buffer_pips            = 2;
         g_entry_buffer_pips         = 1;
         g_max_setup_age_bars        = 10;
         g_confluence_merge_pips     = 12;    // Wider merge — M15 zones naturally closer
         g_htf_bars_to_scan          = 200;
         g_fibo_lookback_bars        = 100;
         g_fibo_tolerance_pips       = 4;
         g_min_candle_size_pips      = 3;     // Stricter — filters small M15 bodies
         g_zone_width_pips           = 3;
         g_min_score_to_show         = 55;    // Stricter threshold
         g_proximity_alert_pips      = 12;
         g_reset_alert_pips          = 18;
         g_structure_lookback_bars   = 50;    // More local structure context
         g_htf_1                     = PERIOD_H1;
         g_htf_2                     = PERIOD_H4;
         break;

      case PRESET_M30:
         g_swing_lookback            = 5;
         g_min_rp_distance_pips      = 25;
         g_min_reaction_move_pips    = 12;
         g_initial_bars_to_scan      = 600;
         g_breakout_confirm_pips     = 3;
         g_max_retest_bars           = 40;
         g_decay_interval_bars       = 15;
         g_decay_points_per_interval = 3;
         g_max_rp_age_bars           = 200;
         g_sl_buffer_pips            = 3;
         g_entry_buffer_pips         = 1;
         g_max_setup_age_bars        = 8;
         g_confluence_merge_pips     = 8;
         g_htf_bars_to_scan          = 200;
         g_fibo_lookback_bars        = 80;
         g_fibo_tolerance_pips       = 3;
         g_min_candle_size_pips      = 2;
         g_zone_width_pips           = 3;
         g_min_score_to_show         = 50;
         g_proximity_alert_pips      = 15;
         g_reset_alert_pips          = 20;
         g_structure_lookback_bars   = 30;
         g_htf_1                     = PERIOD_H1;
         g_htf_2                     = PERIOD_H4;
         break;

      case PRESET_H1:
         g_swing_lookback            = 5;     // Stronger swings: require 5 bars each side
         g_min_rp_distance_pips      = 40;    // Wider spacing: no cluttered zones
         g_min_reaction_move_pips    = 20;    // Stronger reaction required
         g_initial_bars_to_scan      = 500;
         g_breakout_confirm_pips     = 7;     // Firmer breakout confirmation
         g_max_retest_bars           = 50;
         g_decay_interval_bars       = 15;    // Faster decay: remove stale zones sooner
         g_decay_points_per_interval = 3;     // Stronger decay penalty
         g_max_rp_age_bars           = 250;   // Shorter max age
         g_sl_buffer_pips            = 5;
         g_entry_buffer_pips         = 2;
         g_max_setup_age_bars        = 10;
         g_confluence_merge_pips     = 15;    // Wider merge: absorb nearby zones
         g_htf_bars_to_scan          = 200;
         g_fibo_lookback_bars        = 100;
         g_fibo_tolerance_pips       = 5;
         g_min_candle_size_pips      = 5;     // Skip small candles on H1
         g_zone_width_pips           = 4;
         g_min_score_to_show         = 80;    // Only show LV1+ quality zones
         g_proximity_alert_pips      = 20;
         g_reset_alert_pips          = 30;
         g_structure_lookback_bars   = 50;
         g_htf_1                     = PERIOD_H4;
         g_htf_2                     = PERIOD_D1;
         break;

      case PRESET_H4:
         g_swing_lookback            = 3;
         g_min_rp_distance_pips      = 20;
         g_min_reaction_move_pips    = 20;
         g_initial_bars_to_scan      = 300;
         g_breakout_confirm_pips     = 8;
         g_max_retest_bars           = 40;
         g_decay_interval_bars       = 25;
         g_decay_points_per_interval = 2;
         g_max_rp_age_bars           = 200;
         g_sl_buffer_pips            = 8;
         g_entry_buffer_pips         = 3;
         g_max_setup_age_bars        = 10;
         g_confluence_merge_pips     = 15;
         g_htf_bars_to_scan          = 150;
         g_fibo_lookback_bars        = 100;
         g_fibo_tolerance_pips       = 8;
         g_min_candle_size_pips      = 5;
         g_zone_width_pips           = 6;
         g_min_score_to_show         = 40;
         g_proximity_alert_pips      = 30;
         g_reset_alert_pips          = 40;
         g_structure_lookback_bars   = 50;
         g_htf_1                     = PERIOD_D1;
         g_htf_2                     = PERIOD_W1;
         break;

      case PRESET_D1:
      default:
         g_swing_lookback            = 3;
         g_min_rp_distance_pips      = 40;
         g_min_reaction_move_pips    = 40;
         g_initial_bars_to_scan      = 200;
         g_breakout_confirm_pips     = 15;
         g_max_retest_bars           = 30;
         g_decay_interval_bars       = 10;
         g_decay_points_per_interval = 3;
         g_max_rp_age_bars           = 100;
         g_sl_buffer_pips            = 15;
         g_entry_buffer_pips         = 5;
         g_max_setup_age_bars        = 5;
         g_confluence_merge_pips     = 25;
         g_htf_bars_to_scan          = 100;
         g_fibo_lookback_bars        = 60;
         g_fibo_tolerance_pips       = 12;
         g_min_candle_size_pips      = 10;
         g_zone_width_pips           = 10;
         g_min_score_to_show         = 35;
         g_proximity_alert_pips      = 50;
         g_reset_alert_pips          = 60;
         g_structure_lookback_bars   = 80;
         g_htf_1                     = PERIOD_W1;
         g_htf_2                     = PERIOD_MN1;
         break;
   }

   Print("RP: TF Preset applied — ", EnumToString(preset),
         " | Swing:", g_swing_lookback,
         " | Scan:", g_initial_bars_to_scan,
         " | HTF:", TFToString(g_htf_1), "+", TFToString(g_htf_2));
}

//+------------------------------------------------------------------+
//| ValidateInputs — clamp to valid ranges                            |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   int bars_avail = Bars(_Symbol, PERIOD_CURRENT);

   //--- Minimum bars check
   if(bars_avail < g_swing_lookback * 2 + 5)
   {
      Print("ERROR: Not enough bars (have ", bars_avail,
            ", need ", g_swing_lookback * 2 + 5, ")");
      return false;
   }

   //--- Clamp ranges
   int orig;

   orig = g_swing_lookback;
   g_swing_lookback = MathMax(1, MathMin(g_swing_lookback, 10));
   if(orig != g_swing_lookback)
      Print("WARNING: Swing_Lookback clamped to ", g_swing_lookback);

   orig = g_min_rp_distance_pips;
   g_min_rp_distance_pips = MathMax(5, MathMin(g_min_rp_distance_pips, 100));
   if(orig != g_min_rp_distance_pips)
      Print("WARNING: Min_RP_Distance_Pips clamped to ", g_min_rp_distance_pips);

   orig = g_min_reaction_move_pips;
   g_min_reaction_move_pips = MathMax(5, MathMin(g_min_reaction_move_pips, 100));
   if(orig != g_min_reaction_move_pips)
      Print("WARNING: Min_Reaction_Move_Pips clamped to ", g_min_reaction_move_pips);

   orig = g_initial_bars_to_scan;
   g_initial_bars_to_scan = MathMax(50, MathMin(g_initial_bars_to_scan, bars_avail - 10));
   if(orig != g_initial_bars_to_scan)
      Print("WARNING: Initial_Bars_To_Scan clamped to ", g_initial_bars_to_scan);

   orig = g_breakout_confirm_pips;
   g_breakout_confirm_pips = MathMax(1, MathMin(g_breakout_confirm_pips, 50));
   if(orig != g_breakout_confirm_pips)
      Print("WARNING: Breakout_Confirm_Pips clamped to ", g_breakout_confirm_pips);

   orig = g_structure_lookback_bars;
   g_structure_lookback_bars = MathMax(20, MathMin(g_structure_lookback_bars, 100));
   if(orig != g_structure_lookback_bars)
      Print("WARNING: Structure_Lookback_Bars clamped to ", g_structure_lookback_bars);

   //--- Validate HTF hierarchy: HTF_1 > Period(), HTF_2 > HTF_1
   if(g_htf_1 <= Period())
   {
      Print("WARNING: HTF_1 (", TFToString(g_htf_1),
            ") must be > current TF (", TFToString(Period()),
            "). HTF_1 disabled.");
      g_show_htf_1 = false;
   }

   if(g_htf_2 <= g_htf_1)
   {
      Print("WARNING: HTF_2 (", TFToString(g_htf_2),
            ") must be > HTF_1 (", TFToString(g_htf_1),
            "). HTF_2 disabled.");
      g_show_htf_2 = false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| OnInit                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- 1. Apply TF preset
   ApplyTFPreset();

   //--- 2. Validate inputs
   if(!ValidateInputs())
      return INIT_FAILED;

   //--- 3. Pre-allocate ALL arrays once (no runtime resize)
   ArrayResize(g_rp_array, MAX_RP_COUNT);
   ArrayResize(g_confluence_array, MAX_CONFLUENCE);
   ArrayResize(g_setup_array, MAX_SETUPS);
   ArrayResize(g_rp_dirty, MAX_RP_COUNT);
   ArrayResize(g_last_calc_bar, MAX_RP_COUNT);
   ArrayResize(g_fibo_legs, MAX_FIBO_LEGS);    // Phase 7 — P19
   ArrayInitialize(g_rp_dirty, true);      // Force first calc
   ArrayInitialize(g_last_calc_bar, -1);
   InitRPIDMap();                          // v3.0.1: O(1) RP ID lookup map
   for(int fi = 0; fi < MAX_FIBO_LEGS; fi++)   // Init fibo legs
      g_fibo_legs[fi].Init();
   for(int ti = 0; ti < 3; ti++)               // Init HTF trends
      g_htf_trends[ti].Init();

   //--- 4. Detect pair type (P22)
   DetectPairType();

   //--- 5. Init indicator handles (ADX, ATR)
   if(!InitIndicatorHandles())
      return INIT_FAILED;

   //--- 6. Init stats
   InitStats();

   //--- 6. Create dashboard (once)
   if(g_show_dashboard)
      CreateDashboard();

   //--- 7. Create session background objects (once)
   if(g_show_session_background)
      CreateSessionObjects();

   //--- 8. Timer for flash management
   EventSetTimer(1);

   //--- 9. Init data logger (P26)
   if(g_use_logger && !InitLogger())
      Print("RP: Warning — Logger init failed, logging disabled");


   //--- 9. Reset state
   s_first_run       = true;
   s_last_news_check = 0;
   s_last_bar_count  = 0;
   g_rp_count        = 0;
   g_confluence_count= 0;
   g_setup_count     = 0;

   Print("RP: Indicator initialized — ",
         _Symbol, " ", TFToString(Period()),
         " | Bars: ", Bars(_Symbol, PERIOD_CURRENT));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnCalculate — performance-optimized: per-tick vs per-bar          |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //================================================================
   // PER-TICK — lightweight operations only (<1ms)
   //================================================================

   //--- Spread: rolling buffer 100 ticks
   if(g_use_spread_filter)
      UpdateSpreadFilter();

   //--- Alerts: only check when price moved >= 2 pips (throttled)
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(MathAbs(current_bid - g_last_alert_check_price) >= PipsToPrice(2))
   {
      CheckAllAlerts();
      g_last_alert_check_price = current_bid;
   }

   //--- Setup invalidation: lightweight SL check per tick
   UpdateSetupInvalidation();

   //================================================================
   // PER-BAR — all heavy logic (IsNewBar guard)
   //================================================================
   if(!IsNewBar())
      return rates_total;

   //── STEP 0: Cache & Revalidation ──
   UpdateBarCache();      // ATR14, Volume MA20, Fibo levels
   RevalidateHandles();   // Every 100 bars

   //── STEP 0b: Volatility scaling — once on first run (P22) ──
   static bool s_scaling_applied = false;
   if(!s_scaling_applied && g_cached_atr14 > 0.0)
   {
      ApplyVolatilityScaling();
      s_scaling_applied = true;
   }

   //── STEP 1: Market Context ──
   UpdateCurrentSession();
   UpdateMarketRegime();
   if(g_use_trend_alignment)
      UpdateHTFTrends();       // Phase 7 — P20: Multi-TF trend detection

   //── STEP 2: News Filter (throttled — every 5 minutes) ──
   if(g_use_news_filter)
   {
      if(TimeCurrent() - s_last_news_check >= 300)
      {
         UpdateNewsFilter();
         s_last_news_check = TimeCurrent();
      }
   }

   //── STEP 3: Market Structure ──
   if(g_use_market_structure)
      UpdateMarketStructure();

   //── STEP 4: RP Detection ──
   int scan_bars = s_first_run ? g_initial_bars_to_scan : g_swing_lookback * 2 + 5;
   int prev_rp_count = g_rp_count;
   DetectSwingPoints(scan_bars);
   s_first_run = false;

   //── STEP 4b: FVG Detection (P34) ──
   DetectFVG(scan_bars);

   //── STEP 5: Breakout & Retest ──
   CheckBreakoutsAndRetests();

   //── STEP 6: Scoring — only dirty RPs ──
   //--- Mark newly created RPs as dirty
   for(int i = prev_rp_count; i < g_rp_count; i++)
      g_rp_dirty[i] = true;

   //--- Score dirty RPs
   int current_bars = Bars(_Symbol, PERIOD_CURRENT);
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;

      //--- Decay interval check: mark dirty periodically
      int bars_since = current_bars - g_last_calc_bar[i];
      if(bars_since >= g_decay_interval_bars)
         g_rp_dirty[i] = true;

      if(!g_rp_dirty[i]) continue;

      CalcFinalScore(i);
      g_rp_dirty[i] = false;
      g_last_calc_bar[i] = current_bars;
   }

   //--- Update opacity decay for all active RPs
   UpdateAllDecay();

   //--- P26: Check pending outcomes for reaction measurement
   CheckPendingOutcomes(Outcome_Measure_Bars);

   //── STEP 7: Confluence — only when RPs changed or breakout ──
   if(g_use_confluence_zones)
   {
      bool need_confluence_update = (g_rp_count != prev_rp_count) ||
                                    g_confluence_needs_update;

      if(need_confluence_update)
      {
         //--- HTF: only update on new HTF bar
         bool htf1_new = IsNewBarHTF(g_htf_1);
         bool htf2_new = IsNewBarHTF(g_htf_2);

         if(htf1_new || htf2_new || !g_htf1_cache_valid || !g_htf2_cache_valid)
            CollectHTFReactionPoints();

         MergeClusterZones();
         ApplyConfluenceScoring();
         g_confluence_needs_update = false;
         g_confluence_needs_redraw = true;
      }
   }

   //── STEP 8: Entry Setup — create new setups per-bar only ──
   if(g_show_entry_setup)
   {
      CheckEntryConditions();
      UpdateSetups();
   }

   //── STEP 9: UI — only redraw changes ──
   RedrawChangedRP();

   if(g_show_session_background)
      UpdateSessionVisibility();

   if(g_show_dashboard)
      UpdateDashboard();

   EnforceObjectLimit();

   //── STEP 10: Stats ──
   UpdateStats();

   //── Broker disconnect detection ──
   if(s_last_bar_count > 0 && current_bars - s_last_bar_count > 5)
   {
      Print("RP: Gap detected (", current_bars - s_last_bar_count,
            " bars). Rescanning...");
      s_first_run = true;

      //--- Reset alert cooldowns
      for(int i = 0; i < g_rp_count; i++)
         ArrayInitialize(g_rp_array[i].alert_sent, false);
   }
   s_last_bar_count = current_bars;

   return rates_total;
}

//+------------------------------------------------------------------+
//| OnDeinit                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeinitLogger();  // P26: flush and close log files

   switch(reason)
   {
      case REASON_PARAMETERS:
         //--- Parameters changed: clear visuals, keep RP data, force rescan
         DeleteAllObjects();
         DeleteDashboard();
         ReleaseIndicatorHandles();         // Prevent handle leak on re-init
         g_draw_state_initialized = false;  // Force full redraw after re-init
         s_first_run = true;
         Print("RP: Parameters changed — rescanning on next bar");
         break;

      case REASON_CHARTCHANGE:
      case REASON_RECOMPILE:
      case REASON_REMOVE:
      default:
         //--- Full reset
         DeleteAllObjects();
         DeleteDashboard();
         ReleaseIndicatorHandles();
         g_rp_count = 0;
         g_confluence_count = 0;
         g_setup_count = 0;
         Print("RP: Indicator removed — full cleanup done");
         break;
   }
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RepositionDashboard();
      UpdateFontSizes();
   }
}

//+------------------------------------------------------------------+
//| OnTimer — flash management                                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   int flashing_count = 0;

   for(int i = 0; i < g_rp_count && flashing_count < MAX_FLASH_RP; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      if(!g_rp_array[i].is_flashing) continue;

      flashing_count++;

      //--- Toggle zone visibility
      string zone_name = OBJECT_PREFIX + "ZONE_" + IntegerToString(g_rp_array[i].id);
      if(ObjectFind(0, zone_name) >= 0)
      {
         long current_time_scale = ObjectGetInteger(0, zone_name, OBJPROP_TIMEFRAMES);
         if(current_time_scale == OBJ_ALL_PERIODS)
            ObjectSetInteger(0, zone_name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         else
            ObjectSetInteger(0, zone_name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }

      //--- Decrement flash counter
      g_rp_array[i].flash_count--;
      if(g_rp_array[i].flash_count <= 0)
      {
         g_rp_array[i].is_flashing = false;
         g_rp_array[i].flash_count = 0;

         //--- Ensure zone is visible after flash ends
         if(ObjectFind(0, zone_name) >= 0)
            ObjectSetInteger(0, zone_name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
   }

   //--- Only redraw chart when there are actually flashing zones
   if(flashing_count > 0)
      ChartRedraw(0);
}
//+------------------------------------------------------------------+
