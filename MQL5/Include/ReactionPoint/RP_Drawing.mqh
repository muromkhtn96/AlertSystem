//+------------------------------------------------------------------+
//|                                                RP_Drawing.mqh    |
//|                        Reaction Point Indicator v3.0              |
//|                        Zone Drawing, Labels, Session BG, Entry    |
//+------------------------------------------------------------------+
#ifndef RP_DRAWING_MQH
#define RP_DRAWING_MQH

#include "RP_Defines.mqh"
#include "RP_Utils.mqh"

//+------------------------------------------------------------------+
//| Redraw state tracking (static arrays)                             |
//+------------------------------------------------------------------+
static double        g_prev_scores[];
static ENUM_RP_TYPE  g_prev_types[];
static bool          g_prev_active[];
static bool          g_prev_conf[];
static bool          g_prev_role_rev[];
static double        g_prev_opacity[];
static bool          g_draw_state_initialized = false;

//+------------------------------------------------------------------+
//| Alpha values by level                                             |
//+------------------------------------------------------------------+
int GetLevelAlpha(ENUM_RP_LEVEL level)
{
   switch(level)
   {
      case RP_PREMIUM: return 80;
      case RP_LEVEL1:  return 70;
      case RP_LEVEL2:  return 50;
      case RP_LEVEL3:  return 35;
      default:         return 30;
   }
}

//+------------------------------------------------------------------+
//| GetRPColor — determine color for an RP                            |
//+------------------------------------------------------------------+
color GetRPColor(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return clrGray;
   SReactionPoint rp = g_rp_array[rp_index];

   if(rp.is_role_reversed) return g_color_role_reversal;
   if(rp.is_confluence)    return g_color_confluence;

   switch(rp.rp_level)
   {
      case RP_PREMIUM: return g_color_premium;
      case RP_LEVEL1:  return g_color_level1;
      case RP_LEVEL2:  return g_color_level2;
      case RP_LEVEL3:  return g_color_level3;
      default:         return clrGray;
   }
}

//+------------------------------------------------------------------+
//| DrawRPZone — OBJ_RECTANGLE for one RP                             |
//+------------------------------------------------------------------+
void DrawRPZone(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];
   if(!rp.is_active) return;

   //--- Clean mode: only draw Premium + Level 1
   if(g_clean_chart_mode && rp.rp_level != RP_PREMIUM && rp.rp_level != RP_LEVEL1)
      return;

   string name = OBJECT_PREFIX + "ZONE_" + IntegerToString(rp.id);

   //--- Time range: from formed to future
   datetime time_start = rp.time_formed;
   datetime time_end   = TimeCurrent() + PeriodSeconds() * 20;

   //--- Color with opacity decay
   color fg = GetRPColor(rp_index);
   color bg = GetChartBackground();
   int alpha = GetLevelAlpha(rp.rp_level);

   //--- Decay visual: alpha decreases linearly with age, floor 30%
   alpha = (int)(alpha * rp.display_opacity / 100.0);
   if(alpha < 30) alpha = 30;

   color blended = BlendColor(fg, bg, alpha);

   //--- Create or update rectangle
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   time_start, rp.zone_high,
                   time_end, rp.zone_low);
      g_object_count++;

      //--- Static properties — set ONCE on creation only
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_COLOR, blended);

      if(rp.rp_level == RP_PREMIUM || rp.rp_level == RP_LEVEL1)
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      else
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   }
   else
   {
      //--- Only update time end (extends zone forward) and price if changed
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, time_end);
   }

   //--- Update color only when opacity/score changed (detected by dirty flag)
   if(g_rp_dirty[rp_index])
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, blended);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, rp.zone_high);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, rp.zone_low);

      if(rp.rp_level == RP_PREMIUM || rp.rp_level == RP_LEVEL1)
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      else
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
   }
}

//+------------------------------------------------------------------+
//| DrawConfluenceGlow — 3-layer glow for confluence zones (3+ RP)    |
//+------------------------------------------------------------------+
void DrawConfluenceGlow(int conf_index)
{
   if(conf_index < 0 || conf_index >= g_confluence_count) return;
   SConfluenceZone zone = g_confluence_array[conf_index];

   //--- Only for zones with 3+ RPs
   if(zone.rp_count < 3) return;

   color bg = GetChartBackground();
   double pip_ext = PipsToPrice(2);
   double pip_mid = PipsToPrice(1);

   datetime time_start = 0;
   datetime time_end   = TimeCurrent() + PeriodSeconds() * 20;

   //--- Find earliest RP time in zone
   for(int k = 0; k < zone.rp_count; k++)
   {
      for(int r = 0; r < g_rp_count; r++)
      {
         if(g_rp_array[r].id == zone.rp_ids[k])
         {
            if(time_start == 0 || g_rp_array[r].time_formed < time_start)
               time_start = g_rp_array[r].time_formed;
            break;
         }
      }
   }
   if(time_start == 0) time_start = TimeCurrent() - PeriodSeconds() * 50;

   //--- Outer glow: zone ± 2 pip, alpha 14%
   string name_outer = OBJECT_PREFIX + "GLOW_OUT_" + IntegerToString(zone.id);
   if(ObjectFind(0, name_outer) < 0)
   {
      ObjectCreate(0, name_outer, OBJ_RECTANGLE, 0,
                   time_start, zone.zone_high + pip_ext,
                   time_end, zone.zone_low - pip_ext);
      g_object_count++;
   }
   else
   {
      ObjectSetInteger(0, name_outer, OBJPROP_TIME, 0, time_start);
      ObjectSetDouble(0, name_outer, OBJPROP_PRICE, 0, zone.zone_high + pip_ext);
      ObjectSetInteger(0, name_outer, OBJPROP_TIME, 1, time_end);
      ObjectSetDouble(0, name_outer, OBJPROP_PRICE, 1, zone.zone_low - pip_ext);
   }
   ObjectSetInteger(0, name_outer, OBJPROP_COLOR, BlendColor(g_color_confluence, bg, 14));
   ObjectSetInteger(0, name_outer, OBJPROP_FILL, true);
   ObjectSetInteger(0, name_outer, OBJPROP_BACK, true);
   ObjectSetInteger(0, name_outer, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name_outer, OBJPROP_HIDDEN, true);

   //--- Middle glow: zone ± 1 pip, alpha 30%
   string name_mid = OBJECT_PREFIX + "GLOW_MID_" + IntegerToString(zone.id);
   if(ObjectFind(0, name_mid) < 0)
   {
      ObjectCreate(0, name_mid, OBJ_RECTANGLE, 0,
                   time_start, zone.zone_high + pip_mid,
                   time_end, zone.zone_low - pip_mid);
      g_object_count++;
   }
   else
   {
      ObjectSetInteger(0, name_mid, OBJPROP_TIME, 0, time_start);
      ObjectSetDouble(0, name_mid, OBJPROP_PRICE, 0, zone.zone_high + pip_mid);
      ObjectSetInteger(0, name_mid, OBJPROP_TIME, 1, time_end);
      ObjectSetDouble(0, name_mid, OBJPROP_PRICE, 1, zone.zone_low - pip_mid);
   }
   ObjectSetInteger(0, name_mid, OBJPROP_COLOR, BlendColor(g_color_confluence, bg, 30));
   ObjectSetInteger(0, name_mid, OBJPROP_FILL, true);
   ObjectSetInteger(0, name_mid, OBJPROP_BACK, true);
   ObjectSetInteger(0, name_mid, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name_mid, OBJPROP_HIDDEN, true);

   //--- Core glow: zone original, alpha 50%
   string name_core = OBJECT_PREFIX + "GLOW_CORE_" + IntegerToString(zone.id);
   if(ObjectFind(0, name_core) < 0)
   {
      ObjectCreate(0, name_core, OBJ_RECTANGLE, 0,
                   time_start, zone.zone_high,
                   time_end, zone.zone_low);
      g_object_count++;
   }
   else
   {
      ObjectSetInteger(0, name_core, OBJPROP_TIME, 0, time_start);
      ObjectSetDouble(0, name_core, OBJPROP_PRICE, 0, zone.zone_high);
      ObjectSetInteger(0, name_core, OBJPROP_TIME, 1, time_end);
      ObjectSetDouble(0, name_core, OBJPROP_PRICE, 1, zone.zone_low);
   }
   ObjectSetInteger(0, name_core, OBJPROP_COLOR, BlendColor(g_color_confluence, bg, 50));
   ObjectSetInteger(0, name_core, OBJPROP_FILL, true);
   ObjectSetInteger(0, name_core, OBJPROP_BACK, true);
   ObjectSetInteger(0, name_core, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name_core, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Build progress bar string from score                               |
//+------------------------------------------------------------------+
string BuildProgressBar(double score, int total_chars)
{
   int filled = (int)MathRound(score / SCORE_CAP * total_chars);
   if(filled < 0) filled = 0;
   if(filled > total_chars) filled = total_chars;

   string bar = "";
   string block_filled = ShortToString(0x2588); // █ (U+2588)
   string block_empty  = ShortToString(0x2591); // ░ (U+2591)

   for(int i = 0; i < filled; i++)
      bar += block_filled;
   for(int i = filled; i < total_chars; i++)
      bar += block_empty;

   return bar;
}

//+------------------------------------------------------------------+
//| GetLevelIcon — BMP-safe characters (no surrogate pairs)            |
//+------------------------------------------------------------------+
string GetLevelIcon(ENUM_RP_LEVEL level)
{
   // MQL5 \x escape = single 16-bit char. Emoji above U+FFFF
   // require surrogate pairs which MQL5 doesn't support.
   // Use BMP-safe symbols instead:
   switch(level)
   {
      case RP_PREMIUM: return ShortToString(0x2605); // ★ (U+2605)
      case RP_LEVEL1:  return ShortToString(0x25CF); // ● (U+25CF)
      case RP_LEVEL2:  return ShortToString(0x25C6); // ◆ (U+25C6)
      case RP_LEVEL3:  return ShortToString(0x25CB); // ○ (U+25CB)
      default:         return " ";
   }
}

//+------------------------------------------------------------------+
//| DrawRPLabel — text label for an RP                                 |
//+------------------------------------------------------------------+
void DrawRPLabel(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];
   if(!rp.is_active) return;
   if(rp.final_score < g_min_score_to_show) return;

   string name = OBJECT_PREFIX + "LBL_" + IntegerToString(rp.id);

   //--- Position: resistance above zone, support below zone
   double label_price;
   if(rp.rp_type == RP_RESISTANCE)
      label_price = rp.zone_high + PipsToPrice(2);
   else
      label_price = rp.zone_low - PipsToPrice(2);

   //--- Anti-overlap: offset if another label nearby (± 30 pips)
   for(int i = 0; i < g_rp_count; i++)
   {
      if(i == rp_index) continue;
      if(!g_rp_array[i].is_active) continue;
      double other_price = (g_rp_array[i].rp_type == RP_RESISTANCE) ?
                           g_rp_array[i].zone_high : g_rp_array[i].zone_low;
      if(PriceToPips(MathAbs(label_price - other_price)) < 30.0)
      {
         if(rp.rp_type == RP_RESISTANCE)
            label_price += PipsToPrice(5);
         else
            label_price -= PipsToPrice(5);
         break; // one offset is enough
      }
   }

   //--- Build label text
   //    Line 1: [icon] [score] [progress_bar] [TYPE]
   string type_str = rp.is_confluence ? "CONFLUENCE" :
                     (rp.rp_type == RP_SUPPORT ? "SUPPORT" : "RESISTANCE");
   string progress = BuildProgressBar(rp.final_score, 12);
   string line1 = GetLevelIcon(rp.rp_level) + " " +
                  DoubleToString(rp.final_score, 0) + " " +
                  progress + " " + type_str;

   //    Line 2: [TF] | Tested:[n]x | [session] | [status]
   string status_str;
   if(rp.is_role_reversed)
      status_str = "RoleRev";
   else if(rp.is_fresh)
      status_str = "Fresh";
   else if(rp.display_opacity < 99.0)
   {
      //--- Show decay amount: Decay:-N (estimated from opacity drop)
      int decay_pct = (int)MathRound(100.0 - rp.display_opacity);
      status_str = "Decay:-" + IntegerToString(decay_pct);
   }
   else
      status_str = "Active";

   string line2 = TFToString(rp.source_tf) + " | Tested:" +
                  IntegerToString(rp.test_count) + "x | " +
                  SessionToString(rp.session_formed) + " | " + status_str;

   string full_text = line1 + "\n" + line2;

   //--- Create or update text object
   datetime label_time = TimeCurrent() + PeriodSeconds() * 5;

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, label_time, label_price);
      g_object_count++;
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, label_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, label_price);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, full_text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, g_label_font_size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, GetRPColor(rp_index));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);

   //--- Anchor based on type
   if(rp.rp_type == RP_RESISTANCE)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   else
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| DrawEntrySetupPanel — OBJ_RECTANGLE_LABEL + labels for entry      |
//+------------------------------------------------------------------+
void DrawEntrySetupPanel(int setup_index)
{
   if(setup_index < 0 || setup_index >= g_setup_count) return;
   SEntrySetup setup = g_setup_array[setup_index];
   if(!setup.is_active) return;

   //--- Find RP score
   double rp_score = 0.0;
   for(int r = 0; r < g_rp_count; r++)
   {
      if(g_rp_array[r].id == setup.rp_id)
      {
         rp_score = g_rp_array[r].final_score;
         break;
      }
   }

   string prefix = OBJECT_PREFIX + "ENTRY_" + IntegerToString(setup_index) + "_";
   bool is_buy = (setup.direction == RP_SUPPORT);
   string dir_str = is_buy ? "BUY SETUP" : "SELL SETUP";

   //--- Background panel
   string bg_name = prefix + "BG";
   if(ObjectFind(0, bg_name) < 0)
   {
      ObjectCreate(0, bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      g_object_count++;
   }

   int panel_x = 10;
   int panel_y = 100 + setup_index * 160;
   int panel_w = 260;
   int panel_h = 140;

   ObjectSetInteger(0, bg_name, OBJPROP_XDISTANCE, panel_x);
   ObjectSetInteger(0, bg_name, OBJPROP_YDISTANCE, panel_y);
   ObjectSetInteger(0, bg_name, OBJPROP_XSIZE, panel_w);
   ObjectSetInteger(0, bg_name, OBJPROP_YSIZE, panel_h);
   ObjectSetInteger(0, bg_name, OBJPROP_BGCOLOR,
                    is_buy ? ColorToARGB(C'15,30,15', 216) : ColorToARGB(C'30,15,15', 216));
   ObjectSetInteger(0, bg_name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg_name, OBJPROP_HIDDEN, true);

   //--- Text lines
   int bars_remaining = g_max_setup_age_bars - (Bars(_Symbol, PERIOD_CURRENT) - 1 - setup.bar_created);
   if(bars_remaining < 0) bars_remaining = 0;

   string lines[];
   ArrayResize(lines, 7);
   lines[0] = dir_str + "  Score: " + DoubleToString(rp_score, 0);
   lines[1] = "Entry: " + DoubleToString(setup.entry_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   lines[2] = "SL:    " + DoubleToString(setup.sl_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
              "  (" + DoubleToString(setup.sl_pips, 1) + " pip)";
   lines[3] = "TP1:   " + DoubleToString(setup.tp1_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
              "  (" + DoubleToString(setup.tp1_pips, 1) + " pip)";
   lines[4] = "TP2:   " + DoubleToString(setup.tp2_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
              "  (" + DoubleToString(setup.tp2_pips, 1) + " pip)";
   lines[5] = "R:R1 = 1:" + DoubleToString(setup.rr_ratio1, 1) +
              "  R:R2 = 1:" + DoubleToString(setup.rr_ratio2, 1);
   lines[6] = "Expires in " + IntegerToString(bars_remaining) + " bars";

   color text_color = is_buy ? g_color_entry_buy : g_color_entry_sell;

   for(int row = 0; row < 7; row++)
   {
      string lbl_name = prefix + "L" + IntegerToString(row);
      if(ObjectFind(0, lbl_name) < 0)
      {
         ObjectCreate(0, lbl_name, OBJ_LABEL, 0, 0, 0);
         g_object_count++;
      }

      ObjectSetInteger(0, lbl_name, OBJPROP_XDISTANCE, panel_x + 10);
      ObjectSetInteger(0, lbl_name, OBJPROP_YDISTANCE, panel_y + 8 + row * 18);
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, lines[row]);
      ObjectSetString(0, lbl_name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, g_label_font_size);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, (row == 0) ? text_color : clrWhite);
      ObjectSetInteger(0, lbl_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, lbl_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lbl_name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| DrawSLTPLines — SL/TP/Entry horizontal lines for setup            |
//+------------------------------------------------------------------+
void DrawSLTPLines(int setup_index)
{
   if(setup_index < 0 || setup_index >= g_setup_count) return;
   SEntrySetup setup = g_setup_array[setup_index];
   if(!setup.is_active) return;

   string prefix = OBJECT_PREFIX + "SLTP_" + IntegerToString(setup_index) + "_";
   bool is_buy = (setup.direction == RP_SUPPORT);

   //--- Entry line
   string entry_name = prefix + "ENTRY";
   if(ObjectFind(0, entry_name) < 0)
   {
      ObjectCreate(0, entry_name, OBJ_HLINE, 0, 0, setup.entry_price);
      g_object_count++;
   }
   ObjectSetDouble(0, entry_name, OBJPROP_PRICE, 0, setup.entry_price);
   ObjectSetInteger(0, entry_name, OBJPROP_COLOR, is_buy ? g_color_entry_buy : g_color_entry_sell);
   ObjectSetInteger(0, entry_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entry_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, entry_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, entry_name, OBJPROP_HIDDEN, true);

   //--- SL line
   string sl_name = prefix + "SL";
   if(ObjectFind(0, sl_name) < 0)
   {
      ObjectCreate(0, sl_name, OBJ_HLINE, 0, 0, setup.sl_price);
      g_object_count++;
   }
   ObjectSetDouble(0, sl_name, OBJPROP_PRICE, 0, setup.sl_price);
   ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrFireBrick);
   ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, sl_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, sl_name, OBJPROP_HIDDEN, true);

   //--- TP1 line
   string tp1_name = prefix + "TP1";
   if(ObjectFind(0, tp1_name) < 0)
   {
      ObjectCreate(0, tp1_name, OBJ_HLINE, 0, 0, setup.tp1_price);
      g_object_count++;
   }
   ObjectSetDouble(0, tp1_name, OBJPROP_PRICE, 0, setup.tp1_price);
   ObjectSetInteger(0, tp1_name, OBJPROP_COLOR, clrKhaki);
   ObjectSetInteger(0, tp1_name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, tp1_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, tp1_name, OBJPROP_HIDDEN, true);

   //--- TP2 line
   string tp2_name = prefix + "TP2";
   if(ObjectFind(0, tp2_name) < 0)
   {
      ObjectCreate(0, tp2_name, OBJ_HLINE, 0, 0, setup.tp2_price);
      g_object_count++;
   }
   ObjectSetDouble(0, tp2_name, OBJPROP_PRICE, 0, setup.tp2_price);
   ObjectSetInteger(0, tp2_name, OBJPROP_COLOR, clrDarkKhaki);
   ObjectSetInteger(0, tp2_name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, tp2_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, tp2_name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| CreateSessionObjects — called ONCE in OnInit                       |
//+------------------------------------------------------------------+
void CreateSessionObjects()
{
   if(!g_show_session_background) return;

   color bg = GetChartBackground();

   string sessions[] = {"ASIAN", "LONDON", "NY", "OVERLAP", "DEAD"};
   color  sess_colors[] = {clrLightCyan, clrLavender, clrLemonChiffon, clrMistyRose, clrGainsboro};

   for(int i = 0; i < 5; i++)
   {
      string name = OBJECT_PREFIX + "SESS_" + sessions[i];
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                      TimeCurrent() - PeriodSeconds() * 100, 0,
                      TimeCurrent(), 0);
         g_object_count++;
      }

      ObjectSetInteger(0, name, OBJPROP_COLOR, BlendColor(sess_colors[i], bg, 10));
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   }
}

//+------------------------------------------------------------------+
//| UpdateSessionVisibility — called per bar (lightweight)             |
//| Only updates time properties, does NOT delete/recreate             |
//+------------------------------------------------------------------+
void UpdateSessionVisibility()
{
   if(!g_show_session_background) return;

   //--- Get chart visible range
   datetime vis_start = (datetime)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visible_bars   = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);

   //--- Get chart price range for vertical extent
   double chart_high = ChartGetDouble(0, CHART_PRICE_MAX);
   double chart_low  = ChartGetDouble(0, CHART_PRICE_MIN);

   //--- Session hour ranges (UTC-based, offset applied)
   //    Asian: 00:00-08:00, London: 07:00-16:00, NY: 13:00-22:00
   //    Overlap: 13:00-16:00, Dead: 22:00-00:00
   string sessions[] = {"ASIAN", "LONDON", "NY", "OVERLAP", "DEAD"};

   //--- Update time range to cover visible chart area
   datetime now = TimeCurrent();
   datetime day_start = now - (now % 86400); // Start of current day (UTC)

   //--- Each session rectangle covers today's session period
   int sess_start_h[] = {0, 7, 13, 13, 22};
   int sess_end_h[]   = {8, 16, 22, 16, 24};

   for(int i = 0; i < 5; i++)
   {
      string name = OBJECT_PREFIX + "SESS_" + sessions[i];
      if(ObjectFind(0, name) < 0) continue;

      //--- Apply UTC offset
      int start_hour = sess_start_h[i] + g_utc_offset;
      int end_hour   = sess_end_h[i] + g_utc_offset;

      datetime t_start = day_start + start_hour * 3600;
      datetime t_end   = day_start + end_hour * 3600;

      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t_start);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, chart_high);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t_end);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, chart_low);
   }
}

//+------------------------------------------------------------------+
//| InitDrawState — initialize state tracking arrays                   |
//+------------------------------------------------------------------+
void InitDrawState()
{
   ArrayResize(g_prev_scores, MAX_RP_COUNT);
   ArrayResize(g_prev_types, MAX_RP_COUNT);
   ArrayResize(g_prev_active, MAX_RP_COUNT);
   ArrayResize(g_prev_conf, MAX_RP_COUNT);
   ArrayResize(g_prev_role_rev, MAX_RP_COUNT);
   ArrayResize(g_prev_opacity, MAX_RP_COUNT);

   ArrayInitialize(g_prev_scores, -1.0);
   ArrayInitialize(g_prev_active, false);
   ArrayInitialize(g_prev_conf, false);
   ArrayInitialize(g_prev_role_rev, false);
   ArrayInitialize(g_prev_opacity, -1.0);

   g_draw_state_initialized = true;
}

//+------------------------------------------------------------------+
//| RedrawChangedRP — only redraw RPs that changed state               |
//+------------------------------------------------------------------+
void RedrawChangedRP()
{
   if(!g_draw_state_initialized)
      InitDrawState();

   for(int i = 0; i < g_rp_count; i++)
   {
      SReactionPoint rp = g_rp_array[i];

      //--- Check if state changed
      bool changed = false;
      if(g_prev_scores[i] != rp.final_score)     changed = true;
      if(g_prev_types[i] != rp.rp_type)           changed = true;
      if(g_prev_active[i] != rp.is_active)        changed = true;
      if(g_prev_conf[i] != rp.is_confluence)       changed = true;
      if(g_prev_role_rev[i] != rp.is_role_reversed) changed = true;
      if(MathAbs(g_prev_opacity[i] - rp.display_opacity) > 1.0) changed = true;

      if(!changed) continue;

      //--- RP became inactive → delete its objects
      if(!rp.is_active && g_prev_active[i])
      {
         DeleteRPObjects(rp.id);
      }
      else if(rp.is_active)
      {
         DrawRPZone(i);
         if(!g_clean_chart_mode)
            DrawRPLabel(i);
      }

      //--- Update previous state
      g_prev_scores[i]   = rp.final_score;
      g_prev_types[i]    = rp.rp_type;
      g_prev_active[i]   = rp.is_active;
      g_prev_conf[i]     = rp.is_confluence;
      g_prev_role_rev[i] = rp.is_role_reversed;
      g_prev_opacity[i]  = rp.display_opacity;
   }

   //--- Redraw confluence glows (skip in clean mode)
   if(!g_clean_chart_mode)
   {
      for(int z = 0; z < g_confluence_count; z++)
         DrawConfluenceGlow(z);
   }

   //--- Redraw entry setups (skip in clean mode)
   if(!g_clean_chart_mode)
   for(int s = 0; s < g_setup_count; s++)
   {
      if(g_setup_array[s].is_active)
      {
         DrawEntrySetupPanel(s);
         DrawSLTPLines(s);
      }
      else
      {
         //--- Cleanup inactive setup objects
         string prefix = OBJECT_PREFIX + "ENTRY_" + IntegerToString(s) + "_";
         ObjectsDeleteAll(0, prefix);
         string sltp_prefix = OBJECT_PREFIX + "SLTP_" + IntegerToString(s) + "_";
         ObjectsDeleteAll(0, sltp_prefix);
      }
   }
}

//+------------------------------------------------------------------+
//| DeleteRPObjects — remove all objects for one RP                    |
//+------------------------------------------------------------------+
void DeleteRPObjects(int rp_id)
{
   string id_str = IntegerToString(rp_id);

   string zone_name = OBJECT_PREFIX + "ZONE_" + id_str;
   if(ObjectFind(0, zone_name) >= 0)
   {
      ObjectDelete(0, zone_name);
      g_object_count--;
   }

   string lbl_name = OBJECT_PREFIX + "LBL_" + id_str;
   if(ObjectFind(0, lbl_name) >= 0)
   {
      ObjectDelete(0, lbl_name);
      g_object_count--;
   }

   //--- Glow objects (confluence)
   string glow_names[] = {"GLOW_OUT_", "GLOW_MID_", "GLOW_CORE_"};
   for(int i = 0; i < 3; i++)
   {
      string gname = OBJECT_PREFIX + glow_names[i] + id_str;
      if(ObjectFind(0, gname) >= 0)
      {
         ObjectDelete(0, gname);
         g_object_count--;
      }
   }
}

//+------------------------------------------------------------------+
//| DeleteAllObjects                                                   |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   g_object_count = 0;
}

//+------------------------------------------------------------------+
//| EnforceObjectLimit — delete lowest-score RP objects when over limit|
//+------------------------------------------------------------------+
void EnforceObjectLimit()
{
   while(g_object_count > MAX_CHART_OBJECTS)
   {
      //--- Find lowest-score active RP
      int lowest_idx = -1;
      double lowest_score = DBL_MAX;

      for(int i = 0; i < g_rp_count; i++)
      {
         if(!g_rp_array[i].is_active) continue;
         if(g_rp_array[i].is_confluence) continue; // protect confluence
         if(g_rp_array[i].final_score < lowest_score)
         {
            lowest_score = g_rp_array[i].final_score;
            lowest_idx = i;
         }
      }

      if(lowest_idx < 0) break; // cannot free more

      DeleteRPObjects(g_rp_array[lowest_idx].id);
   }
}

//+------------------------------------------------------------------+
//| UpdateFontSizes — adjust font based on chart zoom                  |
//+------------------------------------------------------------------+
void UpdateFontSizes()
{
   long chart_scale = ChartGetInteger(0, CHART_SCALE);

   //--- Adjust label font: base ± 2 based on zoom, min 6
   int adjusted = g_label_font_size;
   if(chart_scale >= 4)
      adjusted = g_label_font_size + 2;
   else if(chart_scale <= 1)
      adjusted = g_label_font_size - 2;

   if(adjusted < 6) adjusted = 6;

   //--- Apply to all existing labels
   for(int i = 0; i < g_rp_count; i++)
   {
      string name = OBJECT_PREFIX + "LBL_" + IntegerToString(g_rp_array[i].id);
      if(ObjectFind(0, name) >= 0)
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, adjusted);
   }
}

#endif // RP_DRAWING_MQH
