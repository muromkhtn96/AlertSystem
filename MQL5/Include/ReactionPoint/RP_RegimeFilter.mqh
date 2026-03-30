//+------------------------------------------------------------------+
//|                                            RP_RegimeFilter.mqh   |
//|                        Reaction Point Indicator v3.0              |
//|                        Module A — Market Regime                   |
//+------------------------------------------------------------------+
#ifndef RP_REGIMEFILTER_MQH
#define RP_REGIMEFILTER_MQH

#include "RP_Utils.mqh"

//--- Extern inputs from main
extern int    ADX_Period;
extern double ADX_Strong_Threshold;
extern double ADX_Weak_Threshold;
extern bool   Use_Regime_Filter;

//+------------------------------------------------------------------+
//| Update market regime based on ADX + ATR                           |
//+------------------------------------------------------------------+
void UpdateMarketRegime()
{
   double adx_val  = GetADX(1);
   double di_plus  = GetADXPlus(1);
   double di_minus = GetADXMinus(1);
   g_current_adx = adx_val;

   // Calculate ATR average over 50 bars for choppy detection
   double atr_current = GetATR14(1);
   double atr_sum = 0;
   int atr_count = 0;
   for(int i = 1; i <= 50; i++)
   {
      double a = GetATR14(i);
      if(a > 0) { atr_sum += a; atr_count++; }
   }
   double atr_avg50 = (atr_count > 0) ? atr_sum / atr_count : atr_current;

   // Classify regime
   if(adx_val > ADX_Strong_Threshold)
   {
      g_current_regime = REGIME_STRONG_TREND;
      g_current_trend = (di_plus > di_minus) ? TREND_UP : TREND_DOWN;
   }
   else if(adx_val >= ADX_Weak_Threshold)
   {
      g_current_regime = REGIME_WEAK_TREND;
      g_current_trend = (di_plus > di_minus) ? TREND_UP : TREND_DOWN;
   }
   else if(atr_current < atr_avg50 * 0.7)
   {
      g_current_regime = REGIME_CHOPPY;
      g_current_trend = TREND_NONE;
   }
   else
   {
      g_current_regime = REGIME_RANGING;
      g_current_trend = TREND_NONE;
   }
}

//+------------------------------------------------------------------+
//| Get regime score adjustment for RP                                |
//+------------------------------------------------------------------+
double GetRegimeScoreAdjustment(ENUM_RP_TYPE rp_type)
{
   if(!Use_Regime_Filter) return 0.0;

   switch(g_current_regime)
   {
      case REGIME_STRONG_TREND:
      {
         bool same_dir = (g_current_trend == TREND_UP && rp_type == RP_SUPPORT) ||
                         (g_current_trend == TREND_DOWN && rp_type == RP_RESISTANCE);
         return same_dir ? 20.0 : -30.0;
      }
      case REGIME_WEAK_TREND:
      {
         bool same_dir = (g_current_trend == TREND_UP && rp_type == RP_SUPPORT) ||
                         (g_current_trend == TREND_DOWN && rp_type == RP_RESISTANCE);
         return same_dir ? 10.0 : -15.0;
      }
      case REGIME_RANGING:
         return 15.0;

      case REGIME_CHOPPY:
         return -20.0;
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Check if market is choppy                                         |
//+------------------------------------------------------------------+
bool IsChoppyRegime()
{
   return (g_current_regime == REGIME_CHOPPY);
}

#endif
