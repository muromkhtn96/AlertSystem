//+------------------------------------------------------------------+
//|                                                  RP_Defines.mqh  |
//|                        Reaction Point Indicator v3.0              |
//|                        Enums, Structs, Constants                  |
//+------------------------------------------------------------------+
#ifndef RP_DEFINES_MQH
#define RP_DEFINES_MQH

//--- Enums
enum ENUM_RP_TYPE        { RP_SUPPORT, RP_RESISTANCE };
enum ENUM_RP_LEVEL       { RP_PREMIUM, RP_LEVEL1, RP_LEVEL2, RP_LEVEL3, RP_HIDDEN };
enum ENUM_MARKET_REGIME  { REGIME_STRONG_TREND, REGIME_WEAK_TREND, REGIME_RANGING, REGIME_CHOPPY };
enum ENUM_TREND_DIR      { TREND_UP, TREND_DOWN, TREND_NONE };
enum ENUM_SESSION        { SESSION_ASIAN, SESSION_LONDON_OPEN, SESSION_LONDON,
                           SESSION_NY_OPEN, SESSION_NY, SESSION_OVERLAP, SESSION_DEAD };
enum ENUM_CANDLE_PATTERN { PATTERN_NONE, PATTERN_PINBAR, PATTERN_ENGULFING,
                           PATTERN_OUTSIDE_BAR, PATTERN_LARGE_WICK };
enum ENUM_TF_PRESET      { PRESET_AUTO, PRESET_M30, PRESET_H1, PRESET_H4, PRESET_D1, PRESET_CUSTOM };
enum ENUM_DASH_CORNER    { DASH_TOP_LEFT, DASH_TOP_RIGHT, DASH_BOTTOM_LEFT, DASH_BOTTOM_RIGHT };

//--- Constants
#define MAX_RP_COUNT      200
#define MAX_CHART_OBJECTS  250
#define MAX_CONFLUENCE     50
#define MAX_SETUPS         10
#define MAX_FLASH_RP       3
#define MAX_HTF_RETRIES    3
#define OBJECT_PREFIX      "RP_"
#define SCORE_CAP          150.0

//--- Structs
struct SReactionPoint {
   int              id;
   ENUM_RP_TYPE     rp_type;
   ENUM_RP_LEVEL    rp_level;
   ENUM_TIMEFRAMES  source_tf;
   ENUM_SESSION     session_formed;
   ENUM_CANDLE_PATTERN candle_pattern;
   double           price, zone_high, zone_low;
   datetime         time_formed, time_last_tested;
   int              bar_formed, bar_last_tested;
   double           base_score, final_score, initial_reaction_pips;
   int              test_count;
   bool             is_role_reversed, is_active, is_confluence, is_fresh;
   int              confluence_id;
   bool             alert_sent[4];
   datetime         alert_reset_time;
   bool             is_flashing;
   int              flash_count;
   double           display_opacity;
   int              day_of_week_formed;

   void Init() {
      id = -1;
      rp_type = RP_SUPPORT;
      rp_level = RP_HIDDEN;
      source_tf = PERIOD_CURRENT;
      session_formed = SESSION_DEAD;
      candle_pattern = PATTERN_NONE;
      price = 0; zone_high = 0; zone_low = 0;
      time_formed = 0; time_last_tested = 0;
      bar_formed = 0; bar_last_tested = 0;
      base_score = 0; final_score = 0; initial_reaction_pips = 0;
      test_count = 0;
      is_role_reversed = false; is_active = false; is_confluence = false; is_fresh = true;
      confluence_id = -1;
      ArrayInitialize(alert_sent, false);
      alert_reset_time = 0;
      is_flashing = false;
      flash_count = 0;
      display_opacity = 100.0;
      day_of_week_formed = 0;
   }
};

struct SConfluenceZone {
   int              id;
   double           zone_high, zone_low, center_price;
   int              rp_count;
   int              rp_ids[10];
   ENUM_RP_TYPE     zone_type;
   double           multiplier, bonus, final_score;
   string           tf_description;
   bool             is_premium;

   void Init() {
      id = -1;
      zone_high = 0; zone_low = 0; center_price = 0;
      rp_count = 0;
      ArrayInitialize(rp_ids, -1);
      zone_type = RP_SUPPORT;
      multiplier = 1.0; bonus = 0; final_score = 0;
      tf_description = "";
      is_premium = false;
   }
};

struct SEntrySetup {
   int              rp_id;
   ENUM_RP_TYPE     direction;
   double           entry_price, sl_price, tp1_price, tp2_price;
   double           rr_ratio1, rr_ratio2;
   double           sl_pips, tp1_pips, tp2_pips;
   int              bar_created;
   datetime         time_created;
   bool             is_active, is_invalidated, is_triggered;

   void Init() {
      rp_id = -1;
      direction = RP_SUPPORT;
      entry_price = 0; sl_price = 0; tp1_price = 0; tp2_price = 0;
      rr_ratio1 = 0; rr_ratio2 = 0;
      sl_pips = 0; tp1_pips = 0; tp2_pips = 0;
      bar_created = 0;
      time_created = 0;
      is_active = false; is_invalidated = false; is_triggered = false;
   }
};

struct SRPStats {
   int    total_formed, total_reacted, total_broken;
   int    premium_formed, premium_reacted;
   int    level1_formed, level1_reacted;
   int    level2_formed, level2_reacted;
   int    london_formed, london_reacted;
   int    ny_formed, ny_reacted;
   int    asian_formed, asian_reacted;
   datetime tracking_start;

   void Init() {
      total_formed = 0; total_reacted = 0; total_broken = 0;
      premium_formed = 0; premium_reacted = 0;
      level1_formed = 0; level1_reacted = 0;
      level2_formed = 0; level2_reacted = 0;
      london_formed = 0; london_reacted = 0;
      ny_formed = 0; ny_reacted = 0;
      asian_formed = 0; asian_reacted = 0;
      tracking_start = TimeCurrent();
   }
};

#endif
