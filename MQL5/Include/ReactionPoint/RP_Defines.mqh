//+------------------------------------------------------------------+
//|                                                  RP_Defines.mqh  |
//|                        Reaction Point Indicator v3.0              |
//|                        Enums, Constants, Structs                  |
//+------------------------------------------------------------------+
#ifndef RP_DEFINES_MQH
#define RP_DEFINES_MQH

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_RP_TYPE           { RP_SUPPORT, RP_RESISTANCE };
enum ENUM_RP_LEVEL          { RP_PREMIUM, RP_LEVEL1, RP_LEVEL2, RP_LEVEL3, RP_HIDDEN };
enum ENUM_MARKET_REGIME     { REGIME_STRONG_TREND, REGIME_WEAK_TREND, REGIME_RANGING, REGIME_CHOPPY };
enum ENUM_TREND_DIR         { TREND_UP, TREND_DOWN, TREND_NONE };
enum ENUM_SESSION           { SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON,
                              SESSION_NY_OPEN, SESSION_NY, SESSION_OVERLAP, SESSION_DEAD };
enum ENUM_CANDLE_PATTERN    { PATTERN_NONE, PATTERN_PINBAR, PATTERN_ENGULFING,
                              PATTERN_OUTSIDE_BAR, PATTERN_LARGE_WICK };
enum ENUM_TF_PRESET         { PRESET_AUTO, PRESET_M30, PRESET_H1, PRESET_H4, PRESET_D1, PRESET_CUSTOM };
enum ENUM_DASH_CORNER       { DASH_TOP_LEFT, DASH_TOP_RIGHT, DASH_BOTTOM_LEFT, DASH_BOTTOM_RIGHT };
enum ENUM_STRUCTURE_STATE   { STRUCTURE_BULLISH, STRUCTURE_BEARISH, STRUCTURE_NONE };

//+------------------------------------------------------------------+
//| Constants                                                        |
//+------------------------------------------------------------------+
#define MAX_RP_COUNT       200
#define MAX_CHART_OBJECTS  250
#define MAX_CONFLUENCE     50
#define MAX_SETUPS         10
#define MAX_ZONE_RPS       8
#define MAX_FLASH_RP       3
#define MAX_HTF_RETRIES    3
#define OBJECT_PREFIX      "RP_"
#define SCORE_CAP          150.0

//+------------------------------------------------------------------+
//| Anti-repainting shift guard                                      |
//+------------------------------------------------------------------+
#define RP_SHIFT_MIN 1

//+------------------------------------------------------------------+
//| SReactionPoint                                                   |
//+------------------------------------------------------------------+
struct SReactionPoint
{
   int              id;
   ENUM_RP_TYPE     rp_type;
   ENUM_RP_LEVEL    rp_level;
   ENUM_TIMEFRAMES  source_tf;
   ENUM_SESSION     session_formed;
   ENUM_CANDLE_PATTERN candle_pattern;
   double           price;
   double           zone_high;
   double           zone_low;
   datetime         time_formed;
   datetime         time_last_tested;
   int              bar_formed;
   int              bar_last_tested;
   double           base_score;
   double           final_score;
   double           initial_reaction_pips;
   int              test_count;
   bool             is_role_reversed;
   bool             is_active;
   bool             is_confluence;
   bool             is_fresh;
   int              confluence_id;
   bool             alert_sent[4];
   datetime         alert_reset_time;
   bool             is_flashing;
   int              flash_count;
   double           display_opacity;
   int              day_of_week_formed;
   bool             has_liquidity_sweep;

   void Init()
   {
      id                   = -1;
      rp_type              = RP_SUPPORT;
      rp_level             = RP_HIDDEN;
      source_tf            = PERIOD_CURRENT;
      session_formed       = SESSION_DEAD;
      candle_pattern       = PATTERN_NONE;
      price                = 0.0;
      zone_high            = 0.0;
      zone_low             = 0.0;
      time_formed          = 0;
      time_last_tested     = 0;
      bar_formed           = 0;
      bar_last_tested      = 0;
      base_score           = 0.0;
      final_score          = 0.0;
      initial_reaction_pips= 0.0;
      test_count           = 0;
      is_role_reversed     = false;
      is_active            = false;
      is_confluence        = false;
      is_fresh             = true;
      confluence_id        = -1;
      ArrayInitialize(alert_sent, false);
      alert_reset_time     = 0;
      is_flashing          = false;
      flash_count          = 0;
      display_opacity      = 100.0;
      day_of_week_formed   = 0;
      has_liquidity_sweep  = false;
   }
};

//+------------------------------------------------------------------+
//| SConfluenceZone                                                  |
//+------------------------------------------------------------------+
struct SConfluenceZone
{
   int              id;
   double           zone_high;
   double           zone_low;
   double           center_price;
   int              rp_count;
   int              rp_ids[MAX_ZONE_RPS];
   ENUM_RP_TYPE     zone_type;
   double           multiplier;
   double           bonus;
   double           final_score;
   string           tf_description;
   bool             is_premium;

   void Init()
   {
      id            = -1;
      zone_high     = 0.0;
      zone_low      = 0.0;
      center_price  = 0.0;
      rp_count      = 0;
      ArrayInitialize(rp_ids, -1);
      zone_type     = RP_SUPPORT;
      multiplier    = 1.0;
      bonus         = 0.0;
      final_score   = 0.0;
      tf_description= "";
      is_premium    = false;
   }
};

//+------------------------------------------------------------------+
//| SEntrySetup                                                      |
//+------------------------------------------------------------------+
struct SEntrySetup
{
   int              rp_id;
   ENUM_RP_TYPE     direction;
   double           entry_price;
   double           sl_price;
   double           tp1_price;
   double           tp2_price;
   double           rr_ratio1;
   double           rr_ratio2;
   double           sl_pips;
   double           tp1_pips;
   double           tp2_pips;
   int              bar_created;
   datetime         time_created;
   bool             is_active;
   bool             is_invalidated;
   bool             is_triggered;

   void Init()
   {
      rp_id          = -1;
      direction      = RP_SUPPORT;
      entry_price    = 0.0;
      sl_price       = 0.0;
      tp1_price      = 0.0;
      tp2_price      = 0.0;
      rr_ratio1      = 0.0;
      rr_ratio2      = 0.0;
      sl_pips        = 0.0;
      tp1_pips       = 0.0;
      tp2_pips       = 0.0;
      bar_created    = 0;
      time_created   = 0;
      is_active      = false;
      is_invalidated = false;
      is_triggered   = false;
   }
};

//+------------------------------------------------------------------+
//| SRPStats                                                         |
//+------------------------------------------------------------------+
struct SRPStats
{
   int      total_formed;
   int      total_reacted;
   int      total_broken;
   int      premium_formed;
   int      premium_reacted;
   int      level1_formed;
   int      level1_reacted;
   int      level2_formed;
   int      level2_reacted;
   int      london_formed;
   int      london_reacted;
   int      ny_formed;
   int      ny_reacted;
   int      asian_formed;
   int      asian_reacted;
   datetime tracking_start;

   void Init()
   {
      ZeroMemory(this);
      tracking_start = TimeCurrent();
   }
};

#endif // RP_DEFINES_MQH
