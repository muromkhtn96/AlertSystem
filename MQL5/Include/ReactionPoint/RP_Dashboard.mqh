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
//| P28: Dashboard layout — compact, modern                            |
//+------------------------------------------------------------------+
#define DASH_WIDTH         340
#define DASH_ROW_HEIGHT    17
#define DASH_PADDING       8
#define DASH_BG_COLOR      C'16,20,28'
#define DASH_BORDER_COLOR  C'40,48,62'
#define DASH_ACCENT_COLOR  C'55,65,85'
#define DASH_DIM_COLOR     C'90,100,120'
#define DASH_MAX_ROWS      18

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
//+------------------------------------------------------------------+
//| P28: Thin separator line using Unicode                             |
//+------------------------------------------------------------------+
string DashSep(int char_count)
{
   string s = "";
   string thin_line = ShortToString(0x2500); // ─ (box drawing horizontal)
   for(int i = 0; i < char_count; i++)
      s += thin_line;
   return s;
}

//+------------------------------------------------------------------+
//| P28: UpdateDashboard — compact, modern, clean                      |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!g_show_dashboard || !g_dash_created) return;

   int x = DASH_PADDING + 6;
   int y = DASH_PADDING + 6;
   int row = 0;
   int fs = g_dashboard_font_size;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   //=== HEADER: Title + TF ===
   DashLabel(OBJECT_PREFIX + "DASH_R0", x, y + row * DASH_ROW_HEIGHT,
             "RP v3.0  " + _Symbol + "  " + TFToString(Period()),
             C'180,190,210', fs);
   row++;

   //=== SESSION + REGIME (single row) ===
   color regime_clr = (g_current_regime == REGIME_CHOPPY) ? C'220,80,80' :
                      (g_current_regime == REGIME_STRONG_TREND) ? C'80,220,120' : C'160,170,190';
   string regime_short;
   switch(g_current_regime)
   {
      case REGIME_STRONG_TREND: regime_short = "TREND"; break;
      case REGIME_WEAK_TREND:   regime_short = "WEAK";  break;
      case REGIME_RANGING:      regime_short = "RANGE"; break;
      case REGIME_CHOPPY:       regime_short = "CHOP";  break;
      default:                  regime_short = "---";   break;
   }

   DashLabel(OBJECT_PREFIX + "DASH_R1", x, y + row * DASH_ROW_HEIGHT,
             SessionToString(g_current_session) + "  " +
             ShortToString(0x2502) + "  " +    // │ vertical separator
             regime_short + " " + DoubleToString(g_current_adx, 0) + "  " +
             ShortToString(0x2502) + "  " +
             GetBiasString(),
             regime_clr, fs);
   row++;

   //=== THIN SEPARATOR ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP1", x, y + row * DASH_ROW_HEIGHT,
             DashSep(44), DASH_ACCENT_COLOR, fs - 2);
   row++;

   //=== METRICS ROW: ATR  Spread  News ===
   double atr_pips = PriceToPips(g_cached_atr14);
   string metrics = "ATR " + DoubleToString(atr_pips, 1) + "p" +
                    "   Sprd " + DoubleToString(g_current_spread_pips, 1) + "p" +
                    "   News " + g_news_status_text;
   DashLabel(OBJECT_PREFIX + "DASH_R3", x, y + row * DASH_ROW_HEIGHT,
             metrics, DASH_DIM_COLOR, fs - 1);
   row++;

   //--- Colored overlay for spread + news status
   color spread_clr = GetSpreadColor(g_current_spread_pips, g_average_spread_pips);
   DashLabel(OBJECT_PREFIX + "DASH_R3S", x + 100, y + (row-1) * DASH_ROW_HEIGHT,
             DoubleToString(g_current_spread_pips, 1) + "p", spread_clr, fs - 1);
   DashLabel(OBJECT_PREFIX + "DASH_R3N", x + 240, y + (row-1) * DASH_ROW_HEIGHT,
             g_news_status_text, g_news_status_color, fs - 1);

   //=== THIN SEPARATOR ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP2", x, y + row * DASH_ROW_HEIGHT,
             DashSep(44), DASH_ACCENT_COLOR, fs - 2);
   row++;

   //=== NEAREST ZONES (top 2) ===
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
         bool already = false;
         for(int s = 0; s < shown; s++)
            if(shown_indices[s] == i) { already = true; break; }
         if(already) continue;

         double dist = MathAbs(bid - g_rp_array[i].price);
         if(dist < best_dist) { best_dist = dist; best_idx = i; }
      }

      if(best_idx >= 0)
      {
         shown_indices[shown] = best_idx;
         SReactionPoint rp = g_rp_array[best_idx];
         string t = (rp.rp_type == RP_SUPPORT) ? "S" : "R";
         if(rp.is_confluence) t = "C";
         double dp = PriceToPips(MathAbs(bid - rp.price));

         // Arrow indicator: ▲ for support below, ▼ for resistance above
         string arrow = (rp.rp_type == RP_SUPPORT) ?
                        ShortToString(0x25B2) : ShortToString(0x25BC);

         string rp_line = arrow + " " + t + "  " +
                          DoubleToString(rp.price, digits) + "  " +
                          DoubleToString(rp.final_score, 0) + "  " +
                          DoubleToString(dp, 0) + "p";

         if(rp.is_fresh) rp_line += "  Fresh";
         else if(rp.is_role_reversed) rp_line += "  RR";
         else if(rp.test_count > 0) rp_line += "  " + IntegerToString(rp.test_count) + "x";

         DashLabel(OBJECT_PREFIX + "DASH_RP" + IntegerToString(shown),
                   x, y + row * DASH_ROW_HEIGHT,
                   rp_line, GetRPColor(best_idx), fs);
         row++;
         shown++;
      }
   }

   for(int f = shown; f < 2; f++)
   {
      DashLabel(OBJECT_PREFIX + "DASH_RP" + IntegerToString(f),
                x, y + row * DASH_ROW_HEIGHT,
                ShortToString(0x00B7) + " ---", DASH_DIM_COLOR, fs);
      row++;
   }

   //=== RADAR ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP3", x, y + row * DASH_ROW_HEIGHT,
             DashSep(44), DASH_ACCENT_COLOR, fs - 2);
   row++;

   UpdateRadar(x, y + row * DASH_ROW_HEIGHT, fs);
   row += 2;

   //=== FOOTER: Counts + Hit Rate ===
   DashLabel(OBJECT_PREFIX + "DASH_SEP4", x, y + row * DASH_ROW_HEIGHT,
             DashSep(44), DASH_ACCENT_COLOR, fs - 2);
   row++;

   int active_cnt = 0, rev_cnt = 0;
   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      active_cnt++;
      if(g_rp_array[i].is_role_reversed) rev_cnt++;
   }

   int setup_cnt = 0;
   for(int i = 0; i < g_setup_count; i++)
      if(g_setup_array[i].is_active) setup_cnt++;

   string footer = IntegerToString(active_cnt) + "z  " +
                   IntegerToString(g_confluence_count) + "c  " +
                   IntegerToString(rev_cnt) + "rr  " +
                   IntegerToString(setup_cnt) + "s";

   if(g_show_performance_stats)
   {
      int total_decided = g_stats.total_reacted + g_stats.total_broken;
      int hit_pct = (total_decided > 0) ?
                    (int)MathRound((double)g_stats.total_reacted / (double)total_decided * 100.0) : 0;
      footer += "  " + ShortToString(0x2502) + "  Hit " +
                IntegerToString(hit_pct) + "%";
   }

   DashLabel(OBJECT_PREFIX + "DASH_FOOTER", x, y + row * DASH_ROW_HEIGHT,
             footer, DASH_DIM_COLOR, fs - 1);
   row++;

   // P28: Entry setup row removed — clean dashboard, zones only

   //=== Resize BG to fit ===
   string bg_name = OBJECT_PREFIX + "DASH_BG";
   if(ObjectFind(0, bg_name) >= 0)
      ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, row * DASH_ROW_HEIGHT + DASH_PADDING * 2);
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

   //--- RES above, SUP below — color-coded
   if(StringLen(res_line) == 0) res_line = "---";
   if(StringLen(sup_line) == 0) sup_line = "---";

   DashLabel(OBJECT_PREFIX + "DASH_RADAR_RES", x_base, y_start,
             ShortToString(0x25BC) + " R  " + res_line, g_color_resistance, fs - 1);
   DashLabel(OBJECT_PREFIX + "DASH_RADAR_SUP", x_base, y_start + DASH_ROW_HEIGHT,
             ShortToString(0x25B2) + " S  " + sup_line, g_color_support, fs - 1);
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
