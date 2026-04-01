//+------------------------------------------------------------------+
//|                                            RP_RegimeFilter.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module A — Market Regime                   |
//+------------------------------------------------------------------+
#ifndef RP_REGIMEFILTER_MQH
#define RP_REGIMEFILTER_MQH

#include "RP_Utils.mqh"

// NO extern/input here — all inputs khai báo trong RP_Main.mq5,
// Main copies vào g_ globals trong ApplyTFPreset().
// Module này đọc: g_adx_period, g_adx_strong_threshold, g_adx_weak_threshold,
//                 g_use_regime_filter, g_handle_adx,
//                 g_cached_atr14, g_cached_atr14_ma50

//+------------------------------------------------------------------+
//| Update market regime based on ADX + ATR                           |
//+------------------------------------------------------------------+
void UpdateMarketRegime()
{
   if(g_handle_adx == INVALID_HANDLE)
   {
      g_current_regime = REGIME_RANGING;
      g_current_trend  = TREND_NONE;
      g_current_adx    = 0.0;
      return;
   }

   //--- Read ADX main line (buffer 0), +DI (buffer 1), -DI (buffer 2)
   double adx_buf[], di_plus_buf[], di_minus_buf[];
   ArraySetAsSeries(adx_buf, true);
   ArraySetAsSeries(di_plus_buf, true);
   ArraySetAsSeries(di_minus_buf, true);

   if(CopyBuffer(g_handle_adx, 0, 1, 1, adx_buf) <= 0)      return;
   if(CopyBuffer(g_handle_adx, 1, 1, 1, di_plus_buf) <= 0)   return;
   if(CopyBuffer(g_handle_adx, 2, 1, 1, di_minus_buf) <= 0)  return;

   double adx_val  = adx_buf[0];
   double di_plus  = di_plus_buf[0];
   double di_minus = di_minus_buf[0];

   g_current_adx = adx_val;

   //--- Classify regime
   if(adx_val > g_adx_strong_threshold)
   {
      g_current_regime = REGIME_STRONG_TREND;
      g_current_trend  = (di_plus > di_minus) ? TREND_UP : TREND_DOWN;
   }
   else if(adx_val >= g_adx_weak_threshold)
   {
      g_current_regime = REGIME_WEAK_TREND;
      g_current_trend  = (di_plus > di_minus) ? TREND_UP : TREND_DOWN;
   }
   else
   {
      // ADX < weak threshold — check ATR for choppy vs ranging
      // Use cached ATR values (updated once per bar in UpdateBarCache)
      if(g_cached_atr14_ma50 > 0.0 && g_cached_atr14 < g_cached_atr14_ma50 * 0.7)
      {
         g_current_regime = REGIME_CHOPPY;
      }
      else
      {
         g_current_regime = REGIME_RANGING;
      }
      g_current_trend = TREND_NONE;
   }
}

//+------------------------------------------------------------------+
//| Get regime score adjustment for RP                                |
//| Bảng:                                                             |
//|   Regime       | Cùng chiều | Ngược chiều                        |
//|   STRONG_TREND | +20        | -30                                 |
//|   WEAK_TREND   | +10        | -15                                 |
//|   RANGING      | +15        | +15                                 |
//|   CHOPPY       | -20        | -20                                 |
//+------------------------------------------------------------------+
double GetRegimeScoreAdj(ENUM_RP_TYPE rp_type)
{
   if(!g_use_regime_filter) return 0.0;

   // Determine if RP is same direction as trend
   // Uptrend + SUPPORT = cùng chiều
   // Uptrend + RESISTANCE = ngược chiều
   // Downtrend + SUPPORT = ngược chiều
   // Downtrend + RESISTANCE = cùng chiều
   bool same_dir = (g_current_trend == TREND_UP   && rp_type == RP_SUPPORT) ||
                   (g_current_trend == TREND_DOWN  && rp_type == RP_RESISTANCE);

   switch(g_current_regime)
   {
      case REGIME_STRONG_TREND:
         if(same_dir) return 20.0;
         // Counter-trend: CHoCH reduces penalty (structure may be reversing)
         if(g_choch_detected && g_last_choch_bar <= 5)
            return -10.0;   // Fresh CHoCH: mild penalty instead of -30
         if(g_choch_detected && g_last_choch_bar <= 15)
         {
            // Gradual fade: -10 (bar 6) → -30 (bar 15)
            double fade = -10.0 - (double)(g_last_choch_bar - 5) / 10.0 * 20.0;
            return fade;
         }
         return -30.0;

      case REGIME_WEAK_TREND:
         if(same_dir) return 10.0;
         // Counter-trend with CHoCH: reduce from -15 to -5
         if(g_choch_detected && g_last_choch_bar <= 10)
            return -5.0;
         return -15.0;

      case REGIME_RANGING:
         return 15.0;  // Both directions get +15

      case REGIME_CHOPPY:
         return -20.0; // Both directions get -20
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if market is choppy                                         |
//+------------------------------------------------------------------+
bool IsChoppyMarket()
{
   return (g_current_regime == REGIME_CHOPPY);
}

#endif // RP_REGIMEFILTER_MQH
