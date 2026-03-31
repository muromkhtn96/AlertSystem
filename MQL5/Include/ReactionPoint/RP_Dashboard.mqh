//+------------------------------------------------------------------+
//|                                             RP_Dashboard.mqh     |
//|                        Reaction Point Indicator v3.0              |
//|                        Dashboard UI Panel                         |
//+------------------------------------------------------------------+
#ifndef RP_DASHBOARD_MQH
#define RP_DASHBOARD_MQH

#include "RP_Defines.mqh"
#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| Dashboard layout constants                                        |
//+------------------------------------------------------------------+
#define DASH_WIDTH         380
#define DASH_ROW_HEIGHT    18
#define DASH_PADDING       10
#define DASH_BG_COLOR      C'20,25,32'
#define DASH_BORDER_COLOR  C'60,65,75'
#define DASH_MAX_ROWS      20

//+------------------------------------------------------------------+
//| Dashboard row names                                                |
//+------------------------------------------------------------------+
static string g_dash_row_names[];
static int    g_dash_row_count = 0;
static bool   g_dash_created = false;

//+------------------------------------------------------------------+
//| Helper: create or update a dashboard label                         |
//+------------------------------------------------------------------+
void DashLabel(string name, int x, int y, string text, color clr, int font_size)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      g_object_count++;
   }

   ENUM_BASE_CORNER corner;
   switch(g_dashboard_corner)
   {
      case DASH_TOP_RIGHT:    corner = CORNER_RIGHT_UPPER; break;
      case DASH_BOTTOM_LEFT:  corner = CORNER_LEFT_LOWER;  break;
      case DASH_BOTTOM_RIGHT: corner = CORNER_RIGHT_LOWER; break;
      default:                corner = CORNER_LEFT_UPPER;   break;
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| GetBiasString                                                      |
//+------------------------------------------------------------------+
string GetBiasString()
{
   if(g_current_regime == REGIME_CHOPPY)       return "Avoid trading";
   if(g_current_regime == REGIME_RANGING)       return "Neutral";

   if(g_current_trend == TREND_UP)   return "BUY preferred";
   if(g_current_trend == TREND_DOWN) return "SELL preferred";
   return "Neutral";
}

//+------------------------------------------------------------------+
//| GetBiasColor                                                       |
//+------------------------------------------------------------------+
color GetBiasColor()
{
   if(g_current_regime == REGIME_CHOPPY) return clrTomato;
   if(g_current_regime == REGIME_RANGING) return clrDarkGray;
   if(g_current_trend == TREND_UP)   return clrLime;
   if(g_current_trend == TREND_DOWN) return clrTomato;
   return clrDarkGray;
}

//+------------------------------------------------------------------+
//| CreateDashboard — called once in OnInit                            |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   if(!g_show_dashboard) return;

   //--- Background panel
   string bg_name = OBJECT_PREFIX + "DASH_BG";
   if(ObjectFind(0, bg_name) < 0)
   {
      ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      g_object_count++;
   }

   ENUM_BASE_CORNER corner;
   switch(g_dashboard_corner)
   {
      case DASH_TOP_RIGHT:    corner = CORNER_RIGHT_UPPER; break;
      case DASH_BOTTOM_LEFT:  corner = CORNER_LEFT_LOWER;  break;
      case DASH_BOTTOM_RIGHT: corner = CORNER_RIGHT_LOWER; break;
      default:                corner = CORNER_LEFT_UPPER;   break;
   }

   int dash_x = DASH_PADDING;
   int dash_y = DASH_PADDING;

   ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, dash_x);
   ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, dash_y);
   ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, DASH_WIDTH);
   ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, DASH_MAX_ROWS * DASH_ROW_HEIGHT + DASH_PADDING * 2);
   ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR, ColorToARGB(DASH_BG_COLOR, 230));
   ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR, DASH_BORDER_COLOR);
   ObjectSetInteger(0, bg_name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg_name, OBJPROP_HIDDEN, true);

   g_dash_created = true;
}

//+------------------------------------------------------------------+
//| UpdateDashboard — called once per new bar                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_show_dashboard || !g_dash_created) return;

   int x_base = DASH_PADDING + 8;
   int y_base = DASH_PADDING + 8;
   int row = 0;
   int fs = g_dashboard_font_size;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   //--- Detect current TF preset name
   string preset_name;
   ENUM_TIMEFRAMES tf = Period();
   if(tf <= PERIOD_M30)      preset_name = "M30";
   else if(tf <= PERIOD_H1)  preset_name = "H1";
   else if(tf <= PERIOD_H4)  preset_name = "H4";
   else                      preset_name = "D1";

   //=== ROW 0: Title ===
   DashLabel(OBJECT_PREFIX + "DASH_R0", x_base, y_base + row * DASH_ROW_HEIGHT,
             "REACTION POINT v3.0           Preset: " + preset_name,
             clrWhite, fs);
   row++;

   //=== ROW 1: Symbol | TF | Session ===
   DashLabel(OBJECT_PREFIX + "DASH_R1", x_base, y_base + row * DASH_ROW_HEIGHT,
             _Symbol + "  |  " + TFToString(Period()) + "  |  " + SessionToString(g_current_session),
             clrWhite, fs);
   row++;

   //=== ROW 2: Separator ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP1", x_base, y_base + row * DASH_ROW_HEIGHT,
             "--------------------------------------------",
             DASH_BORDER_COLOR, fs - 1);
   row++;

   //=== ROW 3: Regime ===
   color regime_color = (g_current_regime == REGIME_CHOPPY) ? clrTomato :
                        (g_current_regime == REGIME_STRONG_TREND) ? clrLime : clrWhite;
   string regime_text = "REGIME   " + RegimeToString(g_current_regime) +
                        "    ADX: " + DoubleToString(g_current_adx, 1);
   if(g_current_regime == REGIME_CHOPPY)
      regime_text += "  AVOID TRADING";

   DashLabel(OBJECT_PREFIX + "DASH_R3", x_base, y_base + row * DASH_ROW_HEIGHT,
             regime_text, regime_color, fs);
   row++;

   //=== ROW 4: Bias ===
   DashLabel(OBJECT_PREFIX + "DASH_R4", x_base, y_base + row * DASH_ROW_HEIGHT,
             "BIAS     " + GetBiasString(),
             GetBiasColor(), fs);
   row++;

   //=== ROW 5: ATR | Spread | News ===
   double atr_pips = PriceToPips(g_cached_atr14);
   color spread_color = GetSpreadColor(g_current_spread_pips, g_average_spread_pips);

   DashLabel(OBJECT_PREFIX + "DASH_R5", x_base, y_base + row * DASH_ROW_HEIGHT,
             "ATR: " + DoubleToString(atr_pips, 1) + "p  |  " +
             "Spread: " + DoubleToString(g_current_spread_pips, 1) + "p  |  " +
             "NEWS: " + g_news_status_text,
             clrWhite, fs);
   row++;

   //--- Spread sub-color and News sub-color (update inline colors via separate labels)
   DashLabel(OBJECT_PREFIX + "DASH_R5_SPREAD", x_base + 130, y_base + (row - 1) * DASH_ROW_HEIGHT,
             DoubleToString(g_current_spread_pips, 1) + "p",
             spread_color, fs);

   DashLabel(OBJECT_PREFIX + "DASH_R5_NEWS", x_base + 280, y_base + (row - 1) * DASH_ROW_HEIGHT,
             g_news_status_text,
             g_news_status_color, fs);

   //=== ROW 6: Separator ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP2", x_base, y_base + row * DASH_ROW_HEIGHT,
             "--------------------------------------------",
             DASH_BORDER_COLOR, fs - 1);
   row++;

   //=== ROW 7-8: Top 2 nearest RPs (selection sort, no state mutation) ===
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int shown = 0;
   int shown_indices[2];
   shown_indices[0] = -1;
   shown_indices[1] = -1;

   for(int pass = 0; pass < 2; pass++)
   {
      int best_idx = -1;
      double best_dist = DBL_MAX;

      for(int i = 0; i < g_rp_count; i++)
      {
         if(!g_rp_array[i].is_active) continue;
         if(g_rp_array[i].final_score < g_min_score_to_show) continue;

         //--- Skip already-shown indices
         bool already = false;
         for(int s = 0; s < shown; s++)
            if(shown_indices[s] == i) { already = true; break; }
         if(already) continue;

         double dist = MathAbs(bid - g_rp_array[i].price);
         if(dist < best_dist)
         {
            best_dist = dist;
            best_idx = i;
         }
      }

      if(best_idx >= 0)
      {
         shown_indices[shown] = best_idx;
         SReactionPoint rp = g_rp_array[best_idx];
         string type_str = (rp.rp_type == RP_SUPPORT) ? "SUP" : "RES";
         double dist_pips = PriceToPips(MathAbs(bid - rp.price));
         string conf_str = rp.is_confluence ? "Conf" : "";
         string status_str = rp.is_fresh ? "Fresh" : "";
         if(rp.is_role_reversed) status_str = "RoleRev";

         string rp_line = type_str + "  " +
                          DoubleToString(rp.price, digits) + "  Score:" +
                          DoubleToString(rp.final_score, 0) + "   " +
                          DoubleToString(dist_pips, 0) + "p  " +
                          conf_str + "  " + status_str;

         DashLabel(OBJECT_PREFIX + "DASH_RP" + IntegerToString(shown),
                   x_base, y_base + row * DASH_ROW_HEIGHT,
                   rp_line, GetRPColor(best_idx), fs);
         row++;
         shown++;
      }
   }

   //--- Fill empty rows if < 2 shown
   for(int f = shown; f < 2; f++)
   {
      DashLabel(OBJECT_PREFIX + "DASH_RP" + IntegerToString(f),
                x_base, y_base + row * DASH_ROW_HEIGHT,
                "(no RP)", clrDarkGray, fs);
      row++;
   }

   //=== ROW: Separator ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP3", x_base, y_base + row * DASH_ROW_HEIGHT,
             "--------------------------------------------",
             DASH_BORDER_COLOR, fs - 1);
   row++;

   //=== RADAR: Top 5 nearest ===
   DashLabel(OBJECT_PREFIX + "DASH_RADAR_HDR", x_base, y_base + row * DASH_ROW_HEIGHT,
             "RADAR  (top 5 nearest)", clrWhite, fs);
   row++;

   UpdateRadar(x_base, y_base + row * DASH_ROW_HEIGHT, fs);
   row += 2; // radar takes ~2 rows

   //=== ROW: Separator ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP4", x_base, y_base + row * DASH_ROW_HEIGHT,
             "--------------------------------------------",
             DASH_BORDER_COLOR, fs - 1);
   row++;

   //=== ROW: Status line ===
   int role_rev_count = 0;
   int active_zone_count = 0;
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      active_zone_count++;
      if(g_rp_array[i].is_role_reversed) role_rev_count++;
   }

   int active_setup_count = 0;
   for(int i = 0; i < g_setup_count; i++)
      if(g_setup_array[i].is_active) active_setup_count++;

   string status = "Zones:" + IntegerToString(active_zone_count) +
                   "  Conf:" + IntegerToString(g_confluence_count) +
                   "  RevR:" + IntegerToString(role_rev_count) +
                   "  Setups:" + IntegerToString(active_setup_count) +
                   "  Obj:" + IntegerToString(g_object_count) + "/" +
                   IntegerToString(MAX_CHART_OBJECTS);

   DashLabel(OBJECT_PREFIX + "DASH_STATUS", x_base, y_base + row * DASH_ROW_HEIGHT,
             status, clrWhite, fs);
   row++;

   //=== ROW: HTF + Hit Rate ===
   string htf_line = "HTF: ";
   if(g_show_htf_1) htf_line += TFToString(g_htf_1) + " ";
   if(g_show_htf_2) htf_line += TFToString(g_htf_2);

   if(g_show_performance_stats)
   {
      int total_decided = g_stats.total_reacted + g_stats.total_broken;
      int hit_pct = (total_decided > 0) ?
                    (int)MathRound((double)g_stats.total_reacted / (double)total_decided * 100.0) : 0;
      htf_line += "  |  Hit Rate: " + IntegerToString(hit_pct) + "% (" +
                  IntegerToString(g_stats.total_reacted) + "/" +
                  IntegerToString(total_decided) + ")";
   }

   DashLabel(OBJECT_PREFIX + "DASH_HTF", x_base, y_base + row * DASH_ROW_HEIGHT,
             htf_line, clrWhite, fs);
   row++;

   //=== ROW: Active Entry Setup (if any) ===
   bool has_active_setup = false;
   for(int s = 0; s < g_setup_count; s++)
   {
      if(!g_setup_array[s].is_active) continue;
      SEntrySetup setup = g_setup_array[s];

      string dir = (setup.direction == RP_SUPPORT) ? "BUY" : "SELL";
      color  dir_color = (setup.direction == RP_SUPPORT) ? g_color_entry_buy : g_color_entry_sell;

      string setup_line = dir + "@" +
                          DoubleToString(setup.entry_price, digits) +
                          "  SL:" + DoubleToString(setup.sl_pips, 0) + "p" +
                          "  TP1:" + DoubleToString(setup.tp1_pips, 0) + "p" +
                          "  R:R=1:" + DoubleToString(setup.rr_ratio1, 1);

      DashLabel(OBJECT_PREFIX + "DASH_SETUP", x_base, y_base + row * DASH_ROW_HEIGHT,
                setup_line, dir_color, fs);
      row++;
      has_active_setup = true;
      break; // show only first active setup
   }

   if(!has_active_setup)
   {
      //--- Hide setup row
      string setup_name = OBJECT_PREFIX + "DASH_SETUP";
      if(ObjectFind(0, setup_name) >= 0)
         ObjectSetString(0, setup_name, OBJPROP_TEXT, "");
   }

   //=== Resize background to fit content ===
   string bg_name = OBJECT_PREFIX + "DASH_BG";
   if(ObjectFind(0, bg_name) >= 0)
   {
      int total_height = row * DASH_ROW_HEIGHT + DASH_PADDING * 2;
      ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, total_height);
   }
}

//+------------------------------------------------------------------+
//| UpdateRadar — top 5 nearest RPs (partial sort O(5N) = O(N))       |
//+------------------------------------------------------------------+
void UpdateRadar(int x_base, int y_start, int fs)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int radar_count = MathMin(5, g_rp_count);

   //--- Partial sort: select top 5 nearest (O(5N))
   bool selected[];
   ArrayResize(selected, g_rp_count);
   ArrayInitialize(selected, false);

   string res_line = "";
   string sup_line = "";
   int res_shown = 0, sup_shown = 0;

   for(int pass = 0; pass < radar_count; pass++)
   {
      int best_idx = -1;
      double best_dist = DBL_MAX;

      for(int i = 0; i < g_rp_count; i++)
      {
         if(selected[i]) continue;
         if(!g_rp_array[i].is_active) continue;
         if(g_rp_array[i].final_score < g_min_score_to_show) continue;

         double dist = MathAbs(bid - g_rp_array[i].price);
         if(dist < best_dist)
         {
            best_dist = dist;
            best_idx = i;
         }
      }

      if(best_idx < 0) break;
      selected[best_idx] = true;

      SReactionPoint rp = g_rp_array[best_idx];
      double dist_pips = PriceToPips(MathAbs(bid - rp.price));

      string entry = DoubleToString(rp.price, digits) + " " +
                     DoubleToString(dist_pips, 0) + "p " +
                     DoubleToString(rp.final_score, 0);

      if(rp.rp_type == RP_RESISTANCE)
      {
         if(res_shown > 0) res_line += " | ";
         res_line += entry;
         res_shown++;
      }
      else
      {
         if(sup_shown > 0) sup_line += " | ";
         sup_line += entry;
         sup_shown++;
      }
   }

   //--- RES above, SUP below
   if(StringLen(res_line) == 0) res_line = "(none)";
   if(StringLen(sup_line) == 0) sup_line = "(none)";

   DashLabel(OBJECT_PREFIX + "DASH_RADAR_RES", x_base, y_start,
             "R: " + res_line, clrTomato, fs - 1);
   DashLabel(OBJECT_PREFIX + "DASH_RADAR_SUP", x_base, y_start + DASH_ROW_HEIGHT,
             "S: " + sup_line, clrLime, fs - 1);
}

//+------------------------------------------------------------------+
//| RepositionDashboard — called on CHARTEVENT_CHART_CHANGE            |
//+------------------------------------------------------------------+
void RepositionDashboard()
{
   if(!g_show_dashboard || !g_dash_created) return;

   //--- Just update the corner — all labels use g_dashboard_corner
   ENUM_BASE_CORNER corner;
   switch(g_dashboard_corner)
   {
      case DASH_TOP_RIGHT:    corner = CORNER_RIGHT_UPPER; break;
      case DASH_BOTTOM_LEFT:  corner = CORNER_LEFT_LOWER;  break;
      case DASH_BOTTOM_RIGHT: corner = CORNER_RIGHT_LOWER; break;
      default:                corner = CORNER_LEFT_UPPER;   break;
   }

   //--- Update all DASH_ objects corner
   int total = ObjectsTotal(0);
   string dash_prefix = OBJECT_PREFIX + "DASH_";

   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, dash_prefix) == 0)
         ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   }
}

//+------------------------------------------------------------------+
//| DeleteDashboard                                                    |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
   int deleted = ObjectsDeleteAll(0, OBJECT_PREFIX + "DASH_");
   g_object_count -= deleted;
   if(g_object_count < 0) g_object_count = 0;
   g_dash_created = false;
}

#endif // RP_DASHBOARD_MQH
