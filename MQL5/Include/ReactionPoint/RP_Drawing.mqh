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
static bool          g_rp_display_suppressed[];  // overlap suppression: hide weaker overlapping zones
static bool          g_prev_suppressed[];        // previous frame suppression state for change detection
static bool          g_draw_state_initialized = false;

//+------------------------------------------------------------------+
//| P28: Fill alpha — must be high enough to see on dark backgrounds   |
//| BlendColor(fg, bg, alpha) with dark bg needs alpha >= 25 to show  |
//+------------------------------------------------------------------+
int GetLevelAlpha(ENUM_RP_LEVEL level)
{
   switch(level)
   {
      case RP_PREMIUM: return 45;   // Subtle fill — edges carry the visual weight
      case RP_LEVEL1:  return 30;   // Light
      case RP_LEVEL2:  return 20;   // Very light
      case RP_LEVEL3:  return 15;   // Barely visible
      default:         return 10;
   }
}

//+------------------------------------------------------------------+
//| P28: Edge line width by level — thicker = stronger                 |
//+------------------------------------------------------------------+
int GetEdgeWidth(ENUM_RP_LEVEL level)
{
   switch(level)
   {
      case RP_PREMIUM: return 2;    // Clean edges, not overly thick
      case RP_LEVEL1:  return 1;
      case RP_LEVEL2:  return 1;
      default:         return 1;
   }
}

//+------------------------------------------------------------------+
//| P28: Get zone base color by type (support/resistance aware)        |
//+------------------------------------------------------------------+
color GetZoneBaseColor(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return clrGray;
   SReactionPoint rp = g_rp_array[rp_index];

   if(rp.is_role_reversed) return g_color_role_reversal;

   //--- All zones use type-aware color (blue=demand, red=supply)
   //    Confluence/Premium get same color as base type — clean, consistent
   //    Level differences handled by alpha/edge width, not color
   if(rp.rp_type == RP_SUPPORT)
      return g_color_support;      // Blue for all demand zones
   else
      return g_color_resistance;   // Red for all supply zones
}

//+------------------------------------------------------------------+
//| GetRPColor — backward-compatible wrapper                           |
//+------------------------------------------------------------------+
color GetRPColor(int rp_index)
{
   return GetZoneBaseColor(rp_index);
}

//+------------------------------------------------------------------+
//| P28: DrawRPZone — modern zone: soft fill + top/bottom edge lines  |
//|                                                                    |
//| Visual design:                                                     |
//|   ─────────────── (edge_high: solid line, width by level)          |
//|   ░░░░░░░░░░░░░░░ (fill: soft transparent rectangle)              |
//|   ─────────────── (edge_low: solid line, width by level)           |
//|                                                                    |
//| Premium/L1: solid edges, visible fill                              |
//| L2/L3: thinner edges, subtle fill                                  |
//+------------------------------------------------------------------+
void DrawRPZone(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];
   if(!rp.is_active) return;

   //--- Level filter: skip zones whose level is toggled off
   if(!IsLevelVisible(rp.rp_level))
      return;

   string id_str    = IntegerToString(rp.id);
   string name_fill = OBJECT_PREFIX + "ZONE_" + id_str;
   string name_top  = OBJECT_PREFIX + "EDGE_H_" + id_str;
   string name_bot  = OBJECT_PREFIX + "EDGE_L_" + id_str;

   //--- Time range: limit visual length to max 100 bars back (clean chart)
   //    Old zones don't need to stretch to original formation time
   datetime time_end   = TimeCurrent() + PeriodSeconds() * 20;
   datetime max_lookback = TimeCurrent() - PeriodSeconds() * 100;
   datetime time_start = (rp.time_formed > max_lookback) ? rp.time_formed : max_lookback;

   //--- Color with opacity decay
   color fg = GetZoneBaseColor(rp_index);
   color bg = GetChartBackground();
   int alpha = GetLevelAlpha(rp.rp_level);

   //--- Decay visual: alpha decreases with age, floor at 20% (visible on dark bg)
   alpha = (int)(alpha * rp.display_opacity / 100.0);
   if(alpha < 20) alpha = 20;

   color fill_color = BlendColor(fg, bg, alpha);
   int edge_width   = GetEdgeWidth(rp.rp_level);

   //--- 1. FILL RECTANGLE (soft transparent body)
   if(ObjectFind(0, name_fill) < 0)
   {
      if(ObjectCreate(0, name_fill, OBJ_RECTANGLE, 0,
                   time_start, rp.zone_high, time_end, rp.zone_low))
         g_object_count++;
      ObjectSetInteger(0, name_fill, OBJPROP_FILL, true);
      ObjectSetInteger(0, name_fill, OBJPROP_BACK, true);
      ObjectSetInteger(0, name_fill, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name_fill, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectSetInteger(0, name_fill, OBJPROP_TIME, 1, time_end);
   }

   //--- 2. TOP EDGE LINE (zone_high boundary — crisp, visible)
   if(ObjectFind(0, name_top) < 0)
   {
      if(ObjectCreate(0, name_top, OBJ_TREND, 0,
                   time_start, rp.zone_high, time_end, rp.zone_high))
         g_object_count++;
      ObjectSetInteger(0, name_top, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, name_top, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name_top, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name_top, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name_top, OBJPROP_BACK, false); // On top of fill
   }
   else
   {
      ObjectSetInteger(0, name_top, OBJPROP_TIME, 1, time_end);
   }

   //--- 3. BOTTOM EDGE LINE (zone_low boundary)
   if(ObjectFind(0, name_bot) < 0)
   {
      if(ObjectCreate(0, name_bot, OBJ_TREND, 0,
                   time_start, rp.zone_low, time_end, rp.zone_low))
         g_object_count++;
      ObjectSetInteger(0, name_bot, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, name_bot, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name_bot, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name_bot, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name_bot, OBJPROP_BACK, false);
   }
   else
   {
      ObjectSetInteger(0, name_bot, OBJPROP_TIME, 1, time_end);
   }

   //--- Update visual properties when state changed
   //    NOTE: g_rp_dirty may be cleared by scoring before drawing runs.
   //    RedrawChangedRP() already tracks state changes via g_prev_* arrays,
   //    so we always update properties when this function is called (it's
   //    only called when RedrawChangedRP detects a change).
   {
      // Fill
      ObjectSetInteger(0, name_fill, OBJPROP_COLOR, fill_color);
      ObjectSetDouble(0, name_fill, OBJPROP_PRICE, 0, rp.zone_high);
      ObjectSetDouble(0, name_fill, OBJPROP_PRICE, 1, rp.zone_low);

      // Edge color: brighter than fill (90% opacity for edges)
      color edge_color = BlendColor(fg, bg, MathMin(alpha + 40, 95));

      // Top edge
      ObjectSetInteger(0, name_top, OBJPROP_COLOR, edge_color);
      ObjectSetInteger(0, name_top, OBJPROP_WIDTH, edge_width);
      ObjectSetInteger(0, name_top, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetDouble(0, name_top, OBJPROP_PRICE, 0, rp.zone_high);
      ObjectSetDouble(0, name_top, OBJPROP_PRICE, 1, rp.zone_high);

      // Bottom edge
      ObjectSetInteger(0, name_bot, OBJPROP_COLOR, edge_color);
      ObjectSetInteger(0, name_bot, OBJPROP_WIDTH, edge_width);
      ObjectSetInteger(0, name_bot, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetDouble(0, name_bot, OBJPROP_PRICE, 0, rp.zone_low);
      ObjectSetDouble(0, name_bot, OBJPROP_PRICE, 1, rp.zone_low);
   }
}

//+------------------------------------------------------------------+
//| DrawConfluenceGlow — 3-layer glow for confluence zones (3+ RP)    |
//+------------------------------------------------------------------+
void DrawConfluenceGlow(int conf_index)
{
   if(conf_index < 0 || conf_index >= g_confluence_count) return;

   //--- Skip glow when only Premium is shown — zone edges are sufficient
   if(g_show_premium && !g_show_level1 && !g_show_level2 && !g_show_level3)
      return;

   SConfluenceZone zone = g_confluence_array[conf_index];

   //--- Only for zones with 3+ RPs
   if(zone.rp_count < 3) return;

   //--- Skip glow if all component RPs are display-suppressed
   bool all_suppressed = true;
   for(int k = 0; k < zone.rp_count; k++)
   {
      int r = FindRPIndexByID(zone.rp_ids[k]);
      if(r >= 0 && !g_rp_display_suppressed[r])
      { all_suppressed = false; break; }
   }
   if(all_suppressed) return;

   color bg = GetChartBackground();
   double pip_ext = PipsToPrice(2);
   double pip_mid = PipsToPrice(1);

   datetime time_start = 0;
   datetime time_end   = TimeCurrent() + PeriodSeconds() * 20;

   //--- Find earliest RP time in zone (O(1) lookup per RP via ID map)
   for(int k = 0; k < zone.rp_count; k++)
   {
      int r = FindRPIndexByID(zone.rp_ids[k]);
      if(r >= 0)
      {
         if(time_start == 0 || g_rp_array[r].time_formed < time_start)
            time_start = g_rp_array[r].time_formed;
      }
   }
   if(time_start == 0) time_start = TimeCurrent() - PeriodSeconds() * 50;

   //--- Outer glow: zone ± 2 pip, alpha 14%
   string name_outer = OBJECT_PREFIX + "GLOW_OUT_" + IntegerToString(zone.id);
   if(ObjectFind(0, name_outer) < 0)
   {
      if(ObjectCreate(0, name_outer, OBJ_RECTANGLE, 0,
                   time_start, zone.zone_high + pip_ext,
                   time_end, zone.zone_low - pip_ext))
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
      if(ObjectCreate(0, name_mid, OBJ_RECTANGLE, 0,
                   time_start, zone.zone_high + pip_mid,
                   time_end, zone.zone_low - pip_mid))
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
      if(ObjectCreate(0, name_core, OBJ_RECTANGLE, 0,
                   time_start, zone.zone_high,
                   time_end, zone.zone_low))
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
//| GetLevelIcon — readable level name                                 |
//+------------------------------------------------------------------+
string GetLevelIcon(ENUM_RP_LEVEL level)
{
   switch(level)
   {
      case RP_PREMIUM: return "PRE";
      case RP_LEVEL1:  return "LV1";
      case RP_LEVEL2:  return "LV2";
      case RP_LEVEL3:  return "LV3";
      default:         return " ";
   }
}

//+------------------------------------------------------------------+
//| DrawRPLabel — original readable format, positioned at zone center  |
//|                                                                    |
//| Format: PREMIUM | CONFLUENCE 124 | H1 | Tested:0x | Fresh         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Label collision tracking — prevents overlapping labels             |
//+------------------------------------------------------------------+
static double g_label_placed_prices[];
static int    g_label_placed_count = 0;

void ResetLabelCollision()
{
   g_label_placed_count = 0;
}

double AdjustLabelPrice(double price)
{
   //--- Min spacing: label font height in price units ≈ 1.5x ATR/chart_height
   //    Simplified: use zone_width_pips as min label spacing
   double min_spacing = PipsToPrice(g_zone_width_pips * 1.5);
   if(min_spacing <= 0.0) min_spacing = PipsToPrice(5);

   double adjusted = price;
   for(int attempt = 0; attempt < 3; attempt++)
   {
      bool collision = false;
      for(int i = 0; i < g_label_placed_count; i++)
      {
         if(MathAbs(adjusted - g_label_placed_prices[i]) < min_spacing)
         {
            //--- Nudge down (lower price) to avoid overlap
            adjusted = g_label_placed_prices[i] - min_spacing;
            collision = true;
            break;
         }
      }
      if(!collision) break;
   }

   //--- Track this label position
   if(g_label_placed_count < ArraySize(g_label_placed_prices))
   {
      g_label_placed_prices[g_label_placed_count] = adjusted;
      g_label_placed_count++;
   }

   return adjusted;
}

void DrawRPLabel(int rp_index)
{
   if(rp_index < 0 || rp_index >= g_rp_count) return;
   SReactionPoint rp = g_rp_array[rp_index];
   if(!rp.is_active) return;
   if(rp.final_score < g_min_score_to_show) return;
   if(!IsLevelVisible(rp.rp_level)) return;

   string name = OBJECT_PREFIX + "LBL_" + IntegerToString(rp.id);

   //--- Position: center of zone, adjusted to avoid collision
   double label_price = AdjustLabelPrice((rp.zone_high + rp.zone_low) / 2.0);

   //--- Build label: compact, professional — "S 142" or "R 128 BB"
   string dir_str = (rp.rp_type == RP_SUPPORT) ? "S" : "R";
   string score_str = DoubleToString(rp.final_score, 0);

   //--- Tags: only show special status (keep clean)
   string tag = "";
   if(rp.is_breaker_block && rp.is_role_reversed)  tag = " BB";
   else if(rp.is_role_reversed)                     tag = " RR";
   else if(rp.has_fvg)                              tag = " FVG";
   else if(rp.is_confluence)                        tag = " C";

   string full_text = dir_str + " " + score_str + tag;

   //--- Position label at right edge of zone (future end) + small offset
   datetime label_time = TimeCurrent() + PeriodSeconds() * 21;

   if(ObjectFind(0, name) < 0)
   {
      if(ObjectCreate(0, name, OBJ_TEXT, 0, label_time, label_price))
         g_object_count++;
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, label_time);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, label_price);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, full_text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, g_label_font_size + 1);
   ObjectSetInteger(0, name, OBJPROP_COLOR, GetRPColor(rp_index));
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

// P28: Entry setup panels and SL/TP lines removed from chart drawing.
// Entry logic remains in RP_EntrySetup.mqh for alert messages only.
// Experienced traders prefer clean charts — zones + labels only.

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
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                      TimeCurrent() - PeriodSeconds() * 100, 0,
                      TimeCurrent(), 0))
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

      //--- Apply UTC offset (DST-aware)
      int start_hour = sess_start_h[i] + GetEffectiveUTCOffset();
      int end_hour   = sess_end_h[i] + GetEffectiveUTCOffset();

      datetime t_start = day_start + start_hour * 3600;
      datetime t_end   = day_start + end_hour * 3600;

      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t_start);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 0, chart_high);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t_end);
      ObjectSetDouble(0, name, OBJPROP_PRICE, 1, chart_low);
   }
}

//+------------------------------------------------------------------+
//| SuppressOverlappingZones — keep only strongest zone per overlap    |
//|   Priority: Premium > higher final_score > lower index             |
//|   Suppressed zones are hidden from drawing but remain active       |
//+------------------------------------------------------------------+
void SuppressOverlappingZones()
{
   if(ArraySize(g_rp_display_suppressed) < MAX_RP_COUNT)
   {
      ArrayResize(g_rp_display_suppressed, MAX_RP_COUNT);
   }
   ArrayInitialize(g_rp_display_suppressed, false);

   //--- Use ATR-based margin: zones within 0.8×ATR of each other are "overlapping"
   //    Aggressive suppression ensures clean chart with well-spaced zones
   double atr = g_cached_atr14;
   if(atr <= 0.0) atr = PipsToPrice(20);
   double overlap_margin = atr * 0.8;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      if(g_rp_display_suppressed[i]) continue;
      if(g_rp_array[i].final_score < g_min_score_to_show) continue;

      for(int j = i + 1; j < g_rp_count; j++)
      {
         if(!g_rp_array[j].is_active) continue;
         if(g_rp_display_suppressed[j]) continue;
         if(g_rp_array[j].final_score < g_min_score_to_show) continue;

         //--- Check price overlap (zones touch or within ATR-based margin)
         //    Same-type zones use wider margin (1.2×ATR) — they are redundant
         bool same_type = (g_rp_array[i].rp_type == g_rp_array[j].rp_type);
         double eff_margin = same_type ? overlap_margin * 1.5 : overlap_margin;

         bool overlaps = (g_rp_array[i].zone_low <= g_rp_array[j].zone_high + eff_margin) &&
                         (g_rp_array[j].zone_low <= g_rp_array[i].zone_high + eff_margin);
         if(!overlaps) continue;

         //--- Determine winner: premium first, then score, then freshness
         int winner = i, loser = j;
         bool i_premium = (g_rp_array[i].rp_level == RP_PREMIUM);
         bool j_premium = (g_rp_array[j].rp_level == RP_PREMIUM);

         if(j_premium && !i_premium)
         { winner = j; loser = i; }
         else if(i_premium == j_premium && g_rp_array[j].final_score > g_rp_array[i].final_score)
         { winner = j; loser = i; }

         g_rp_display_suppressed[loser] = true;

         //--- If loser was i, i is now suppressed — stop comparing i
         if(loser == i) break;
      }
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
   ArrayResize(g_rp_display_suppressed, MAX_RP_COUNT);
   ArrayResize(g_prev_suppressed, MAX_RP_COUNT);

   ArrayInitialize(g_prev_scores, -1.0);
   ArrayInitialize(g_prev_types, RP_SUPPORT);
   ArrayInitialize(g_prev_active, false);
   ArrayInitialize(g_prev_conf, false);
   ArrayInitialize(g_prev_role_rev, false);
   ArrayInitialize(g_prev_opacity, -1.0);
   ArrayInitialize(g_prev_suppressed, false);

   //--- Label collision tracking array
   ArrayResize(g_label_placed_prices, MAX_RP_COUNT);
   ArrayInitialize(g_label_placed_prices, 0.0);

   g_draw_state_initialized = true;
}

//+------------------------------------------------------------------+
//| RedrawChangedRP — only redraw RPs that changed state               |
//+------------------------------------------------------------------+
void RedrawChangedRP()
{
   if(!g_draw_state_initialized)
      InitDrawState();

   //--- Reset label collision tracker for this redraw pass
   ResetLabelCollision();

   //--- Suppress weaker overlapping zones (keep strongest per overlap group)
   SuppressOverlappingZones();

   //--- Permanently deactivate zones suppressed for too long (free up slots)
   //    If a zone has been display-suppressed for 50+ bars, it's permanently eclipsed
   static int g_suppressed_count[];
   if(ArraySize(g_suppressed_count) < MAX_RP_COUNT)
   {
      ArrayResize(g_suppressed_count, MAX_RP_COUNT);
      ArrayInitialize(g_suppressed_count, 0);
   }
   for(int s = 0; s < g_rp_count; s++)
   {
      if(!SafeRP(s)) break;
      if(s >= ArraySize(g_rp_display_suppressed)) break;

      if(g_rp_display_suppressed[s])
         g_suppressed_count[s]++;
      else
         g_suppressed_count[s] = 0;

      if(g_suppressed_count[s] >= 50 && g_rp_array[s].is_active && !g_rp_array[s].is_confluence)
      {
         g_rp_array[s].is_active = false;
         if(SafeDirty(s))
            g_rp_dirty[s] = true;
         g_suppressed_count[s] = 0;
      }
   }

   //--- Extend time_end for all active zones every call (lightweight)
   //    This ensures zones always reach current candle + 20 bars ahead,
   //    even when no state change triggers a full redraw.
   datetime extend_end = TimeCurrent() + PeriodSeconds() * 20;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!SafeRP(i)) break;
      if(i >= ArraySize(g_prev_scores)) break;

      SReactionPoint rp = g_rp_array[i];

      //--- Check if state changed
      bool changed = false;
      if(g_prev_scores[i] != rp.final_score)     changed = true;
      if(g_prev_types[i] != rp.rp_type)           changed = true;
      if(g_prev_active[i] != rp.is_active)        changed = true;
      if(g_prev_conf[i] != rp.is_confluence)       changed = true;
      if(g_prev_role_rev[i] != rp.is_role_reversed) changed = true;
      if(MathAbs(g_prev_opacity[i] - rp.display_opacity) > 1.0) changed = true;
      if(g_rp_display_suppressed[i] != g_prev_suppressed[i]) changed = true;

      //--- RP became inactive → delete its objects
      if(!rp.is_active && g_prev_active[i])
      {
         DeleteRPObjects(rp.id);
         changed = true;
      }
      //--- RP is suppressed by overlap → hide its objects
      else if(g_rp_display_suppressed[i])
      {
         DeleteRPObjects(rp.id);
         changed = true;
      }
      //--- RP is active and not suppressed → draw or extend
      else if(rp.is_active)
      {
         if(changed)
         {
            //--- Full redraw: color, edges, prices, time
            DrawRPZone(i);
            DrawRPLabel(i);
         }
         else
         {
            //--- Lightweight: only extend zone time_end forward
            string id_str = IntegerToString(rp.id);
            string nf = OBJECT_PREFIX + "ZONE_"   + id_str;
            string nt = OBJECT_PREFIX + "EDGE_H_" + id_str;
            string nb = OBJECT_PREFIX + "EDGE_L_" + id_str;
            if(ObjectFind(0, nf) >= 0) ObjectSetInteger(0, nf, OBJPROP_TIME, 1, extend_end);
            if(ObjectFind(0, nt) >= 0) ObjectSetInteger(0, nt, OBJPROP_TIME, 1, extend_end);
            if(ObjectFind(0, nb) >= 0) ObjectSetInteger(0, nb, OBJPROP_TIME, 1, extend_end);
         }
      }

      if(!changed) continue;

      //--- Update previous state
      g_prev_scores[i]   = rp.final_score;
      g_prev_types[i]    = rp.rp_type;
      g_prev_active[i]   = rp.is_active;
      g_prev_conf[i]     = rp.is_confluence;
      g_prev_role_rev[i] = rp.is_role_reversed;
      g_prev_opacity[i]  = rp.display_opacity;
      g_prev_suppressed[i] = g_rp_display_suppressed[i];
   }

   //--- Redraw confluence glows only when confluence zones changed (skip in clean mode)
   if(!g_clean_chart_mode && g_confluence_needs_redraw)
   {
      for(int z = 0; z < g_confluence_count; z++)
         DrawConfluenceGlow(z);
      g_confluence_needs_redraw = false;
   }

   // P28: Entry setup panels removed — clean chart, zones only
}

//+------------------------------------------------------------------+
//| DeleteRPObjects — remove all objects for one RP                    |
//+------------------------------------------------------------------+
void DeleteRPObjects(int rp_id)
{
   string id_str = IntegerToString(rp_id);

   //--- Zone fill + edge lines (P28)
   string obj_names[] = {"ZONE_", "EDGE_H_", "EDGE_L_", "LBL_",
                         "GLOW_OUT_", "GLOW_MID_", "GLOW_CORE_"};
   for(int i = 0; i < 7; i++)
   {
      string oname = OBJECT_PREFIX + obj_names[i] + id_str;
      if(ObjectFind(0, oname) >= 0)
      {
         if(ObjectDelete(0, oname))
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
   if(g_object_count <= MAX_CHART_OBJECTS) return;

   //--- Estimate how many RPs to remove (each RP = up to 3 objects)
   int excess = g_object_count - MAX_CHART_OBJECTS;
   int to_remove = (excess / 3) + 2;  // Remove enough in one pass + buffer
   const int MAX_BATCH = 10;
   if(to_remove > MAX_BATCH) to_remove = MAX_BATCH;

   //--- Collect lowest-score non-confluence RPs
   int remove_indices[];
   double remove_scores[];
   ArrayResize(remove_indices, to_remove);
   ArrayResize(remove_scores, to_remove);
   ArrayInitialize(remove_scores, DBL_MAX);
   int found = 0;

   for(int i = 0; i < g_rp_count; i++)
   {
      if(!g_rp_array[i].is_active) continue;
      if(g_rp_array[i].is_confluence) continue;

      double score = g_rp_array[i].final_score;

      //--- Insert into sorted removal list (ascending by score)
      if(found < to_remove)
      {
         remove_indices[found] = i;
         remove_scores[found]  = score;
         found++;
      }
      else
      {
         //--- Replace the highest score in removal list if this one is lower
         int worst = 0;
         for(int j = 1; j < to_remove; j++)
            if(remove_scores[j] > remove_scores[worst]) worst = j;
         if(score < remove_scores[worst])
         {
            remove_indices[worst] = i;
            remove_scores[worst]  = score;
         }
      }
   }

   //--- Batch delete all collected RPs
   for(int i = 0; i < found && g_object_count > MAX_CHART_OBJECTS; i++)
      DeleteRPObjects(g_rp_array[remove_indices[i]].id);
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
