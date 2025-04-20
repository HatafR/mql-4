//+------------------------------------------------------------------+
//| Smart Money Concepts [LUX] - MQL4 Version                        |
//|                       |
//|                                             |
//+------------------------------------------------------------------+
#property copyright "Converted"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

// Input Parameters
input string Mode = "Historical";           // Mode: Historical or Present
input string Style = "Colored";             // Style: Colored or Monochrome
input bool ShowTrend = false;               // Color Candles
input bool ShowInternals = true;            // Show Internal Structure
input string ShowIBull = "All";             // Bullish Structure: All, BOS, CHoCH
input string ShowIBear = "All";             // Bearish Structure: All, BOS, CHoCH
input bool IFilterConfluence = false;       // Confluence Filter
input bool ShowStructure = true;            // Show Swing Structure
input string ShowBull = "All";              // Bullish Structure: All, BOS, CHoCH
input string ShowBear = "All";              // Bearish Structure: All, BOS, CHoCH
input bool ShowSwings = false;              // Show Swing Points
input int SwingLength = 50;                 // Swing Length
input bool ShowHLSwings = true;             // Show Strong/Weak High/Low
input bool ShowIOB = true;                  // Internal Order Blocks
input int IOBShowLast = 5;                  // Number of Internal OBs
input bool ShowOB = false;                  // Swing Order Blocks
input int OBShowLast = 5;                   // Number of Swing OBs
input string OBFilter = "Atr";              // OB Filter: Atr or Cumulative Mean Range
input bool OBHighlightMit = true;           // Highlight Mitigated OBs
input bool ShowEQ = true;                   // Equal High/Low
input int EQLen = 3;                        // Bars Confirmation
input double EQThreshold = 0.1;             // Threshold (0-0.5)
input bool ShowFVG = false;                 // Fair Value Gaps
input bool FVGAuto = true;                  // Auto Threshold
input string FVGTf = "";                    // FVG Timeframe (e.g., "D1")
input int FVGExtend = 1;                    // Extend FVG
input bool ShowPDHL = false;                // Previous Day High/Low
input bool ShowPWHL = false;                // Previous Week High/Low
input bool ShowPMHL = false;                // Previous Month High/Low
input bool ShowSD = false;                  // Premium/Discount Zones

// Colors
input color SwingIBullCSS = clrTeal;        // Internal Bullish Structure
input color SwingIBearCSS = clrRed;         // Internal Bearish Structure
input color SwingBullCSS = clrTeal;         // Swing Bullish Structure
input color SwingBearCSS = clrRed;          // Swing Bearish Structure
input color IBullOBCSS = clrDodgerBlue;     // Internal Bullish OB
input color IBullMOBCSS = clrGray;          // Mitigated Internal Bullish OB
input color IBearOBCSS = clrPink;           // Internal Bearish OB
input color IBearMOBCSS = clrGray;          // Mitigated Internal Bearish OB
input color BullOBCSS = clrBlue;            // Swing Bullish OB
input color BullMOBCSS = clrGray;           // Mitigated Swing Bullish OB
input color BearOBCSS = clrDarkRed;         // Swing Bearish OB
input color BearMOBCSS = clrGray;           // Mitigated Swing Bearish OB
input color BullFVGCSS = clrLime;           // Bullish FVG
input color BearFVGCSS = clrRed;            // Bearish FVG
input color PDHLCSS = clrBlue;              // Previous Day High/Low
input color PWHLCSS = clrBlue;              // Previous Week High/Low
input color PMHLCSS = clrBlue;              // Previous Month High/Low
input color PremiumCSS = clrRed;            // Premium Zone
input color EqCSS = clrGray;                // Equilibrium Zone
input color DiscountCSS = clrGreen;         // Discount Zone

// Global Variables
double TrailUp = 0, TrailDn = 0;
datetime TrailUpX = 0, TrailDnX = 0;
int Trend = 0, ITrend = 0;
double TopY = 0, BtmY = 0, ITopY = 0, IBtmY = 0;
int TopX = 0, BtmX = 0, ITopX = 0, IBtmX = 0;
bool TopCross = true, BtmCross = true, ITopCross = true, IBtmCross = true;

// Order Block Arrays (fixed size for simplicity)
#define MAX_OB 50
double IOBTop[MAX_OB], IOBBtm[MAX_OB], OBTop[MAX_OB], OBBtm[MAX_OB];
datetime IOBLeft[MAX_OB], IOBRight[MAX_OB], OBLeft[MAX_OB], OBRight[MAX_OB];
int IOBType[MAX_OB], IOBMit[MAX_OB], OBType[MAX_OB], OBMit[MAX_OB];
int IOBSize = 0, OBSize = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trails
   TrailUp = High[0];
   TrailDn = Low[0];
   TrailUpX = Time[0];
   TrailDnX = Time[0];
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMC_");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Calculate ATR
   double atr = iATR(NULL, 0, 200, 1);
   
   // Swing Detection
   double top = SwingHigh(rates_total, SwingLength);
   double btm = SwingLow(rates_total, SwingLength);
   double itop = SwingHigh(rates_total, 5);
   double ibtm = SwingLow(rates_total, 5);

   // Process Pivots
   if (top > 0) ProcessTop(top, time[rates_total - SwingLength - 1]);
   if (btm > 0) ProcessBtm(btm, time[rates_total - SwingLength - 1]);
   if (itop > 0) ProcessITop(itop, time[rates_total - 5 - 1]);
   if (ibtm > 0) ProcessIBtm(ibtm, time[rates_total - 5 - 1]);

   // Update Trails
   UpdateTrails(high[rates_total - 1], low[rates_total - 1], time[rates_total - 1]);

   // Structure Detection
   DetectStructure(close[rates_total - 1], atr, time[rates_total - 1]);

   // Order Blocks
   ManageOrderBlocks(close[rates_total - 1], low[rates_total - 1], high[rates_total - 1], time[rates_total - 1]);

   // Equal Highs/Lows
   if (ShowEQ) DetectEQHL(rates_total);

   // Fair Value Gaps
   if (ShowFVG) DetectFVG(rates_total, time);

   // Previous Highs/Lows
   DrawPreviousHL(time[rates_total - 1]);

   // Premium/Discount Zones
   if (ShowSD) DrawSDZones(time[rates_total - 1]);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Swing High Detection                                             |
//+------------------------------------------------------------------+
double SwingHigh(int rates_total, int len)
{
   double highest = iHighest(NULL, 0, MODE_HIGH, len, 1);
   if (High[highest] > High[highest + 1] && High[highest] > High[highest - 1])
      return High[highest];
   return 0;
}

//+------------------------------------------------------------------+
//| Swing Low Detection                                              |
//+------------------------------------------------------------------+
double SwingLow(int rates_total, int len)
{
   double lowest = iLowest(NULL, 0, MODE_LOW, len, 1);
   if (Low[lowest] < Low[lowest + 1] && Low[lowest] < Low[lowest - 1])
      return Low[lowest];
   return 0;
}

//+------------------------------------------------------------------+
//| Process Top Pivot                                                |
//+------------------------------------------------------------------+
void ProcessTop(double top, datetime time)
{
   TopCross = true;
   TopY = top;
   TopX = iBarShift(NULL, 0, time);
   TrailUp = top;
   TrailUpX = time;
   if (ShowSwings) DrawLabel("SMC_Top_" + TimeToString(time), time, top, "HH", SwingBearCSS, ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
//| Process Bottom Pivot                                             |
//+------------------------------------------------------------------+
void ProcessBtm(double btm, datetime time)
{
   BtmCross = true;
   BtmY = btm;
   BtmX = iBarShift(NULL, 0, time);
   TrailDn = btm;
   TrailDnX = time;
   if (ShowSwings) DrawLabel("SMC_Btm_" + TimeToString(time), time, btm, "LL", SwingBullCSS, ANCHOR_LOWER);
}

//+------------------------------------------------------------------+
//| Process Internal Top Pivot                                       |
//+------------------------------------------------------------------+
void ProcessITop(double itop, datetime time)
{
   ITopCross = true;
   ITopY = itop;
   ITopX = iBarShift(NULL, 0, time);
}

//+------------------------------------------------------------------+
//| Process Internal Bottom Pivot                                    |
//+------------------------------------------------------------------+
void ProcessIBtm(double ibtm, datetime time)
{
   IBtmCross = true;
   IBtmY = ibtm;
   IBtmX = iBarShift(NULL, 0, time);
}

//+------------------------------------------------------------------+
//| Update Trailing High/Low                                         |
//+------------------------------------------------------------------+
void UpdateTrails(double high, double low, datetime time)
{
   if (high > TrailUp) {
      TrailUp = high;
      TrailUpX = time;
   }
   if (low < TrailDn) {
      TrailDn = low;
      TrailDnX = time;
   }
   if (ShowHLSwings) {
      DrawLine("SMC_TrailUp", TrailUpX, TrailUp, Time[0], TrailUp, SwingBearCSS);
      DrawLine("SMC_TrailDn", TrailDnX, TrailDn, Time[0], TrailDn, SwingBullCSS);
   }
}

//+------------------------------------------------------------------+
//| Detect Structure (BOS/CHoCH)                                     |
//+------------------------------------------------------------------+
void DetectStructure(double close, double atr, datetime time)
{
   // Bullish Internal Structure
   if (close > ITopY && ITopCross && TopY != ITopY) {
      string txt = (ITrend < 0) ? "CHoCH" : "BOS";
      ITrend = 1;
      if (ShowInternals && (ShowIBull == "All" || (ShowIBull == txt))) {
         DrawLine("SMC_IBull_" + TimeToString(time), Time[ITopX], ITopY, time, ITopY, SwingIBullCSS, STYLE_DASH);
         DrawLabel("SMC_IBullLbl_" + TimeToString(time), time, ITopY, txt, SwingIBullCSS, ANCHOR_UPPER);
      }
      if (ShowIOB) AddOrderBlock(false, ITopX, time, atr);
      ITopCross = false;
   }

   // Bearish Internal Structure
   if (close < IBtmY && IBtmCross && BtmY != IBtmY) {
      string txt = (ITrend > 0) ? "CHoCH" : "BOS";
      ITrend = -1;
      if (ShowInternals && (ShowIBear == "All" || (ShowIBear == txt))) {
         DrawLine("SMC_IBear_" + TimeToString(time), Time[IBtmX], IBtmY, time, IBtmY, SwingIBearCSS, STYLE_DASH);
         DrawLabel("SMC_IBearLbl_" + TimeToString(time), time, IBtmY, txt, SwingIBearCSS, ANCHOR_LOWER);
      }
      if (ShowIOB) AddOrderBlock(true, IBtmX, time, atr);
      IBtmCross = false;
   }

   // Bullish Swing Structure
   if (close > TopY && TopCross) {
      string txt = (Trend < 0) ? "CHoCH" : "BOS";
      Trend = 1;
      if (ShowStructure && (ShowBull == "All" || (ShowBull == txt))) {
         DrawLine("SMC_Bull_" + TimeToString(time), Time[TopX], TopY, time, TopY, SwingBullCSS, STYLE_SOLID);
         DrawLabel("SMC_BullLbl_" + TimeToString(time), time, TopY, txt, SwingBullCSS, ANCHOR_UPPER);
      }
      if (ShowOB) AddOrderBlock(false, TopX, time, atr);
      TopCross = false;
   }

   // Bearish Swing Structure
   if (close < BtmY && BtmCross) {
      string txt = (Trend > 0) ? "CHoCH" : "BOS";
      Trend = -1;
      if (ShowStructure && (ShowBear == "All" || (ShowBear == txt))) {
         DrawLine("SMC_Bear_" + TimeToString(time), Time[BtmX], BtmY, time, BtmY, SwingBearCSS, STYLE_SOLID);
         DrawLabel("SMC_BearLbl_" + TimeToString(time), time, BtmY, txt, SwingBearCSS, ANCHOR_LOWER);
      }
      if (ShowOB) AddOrderBlock(true, BtmX, time, atr);
      BtmCross = false;
   }
}

//+------------------------------------------------------------------+
//| Add Order Block                                                  |
//+------------------------------------------------------------------+
void AddOrderBlock(bool useMax, int loc, datetime time, double threshold)
{
   double max = 0, min = 99999999;
   int idx = 0;
   for (int i = 1; i < Bars - loc - 1; i++) {
      if ((High[i] - Low[i]) < threshold * 2) {
         if (useMax) {
            if (High[i] > max) {
               max = High[i];
               min = Low[i];
               idx = i;
            }
         } else {
            if (Low[i] < min) {
               min = Low[i];
               max = High[i];
               idx = i;
            }
         }
      }
   }
   if (useMax && IBearOBCSS != clrNONE && IOBSize < MAX_OB) {
      IOBTop[IOBSize] = max;
      IOBBtm[IOBSize] = min;
      IOBLeft[IOBSize] = Time[idx];
      IOBRight[IOBSize] = time;
      IOBType[IOBSize] = -1;
      IOBMit[IOBSize] = 0;
      IOBSize++;
   } else if (!useMax && IBullOBCSS != clrNONE && IOBSize < MAX_OB) {
      IOBTop[IOBSize] = max;
      IOBBtm[IOBSize] = min;
      IOBLeft[IOBSize] = Time[idx];
      IOBRight[IOBSize] = time;
      IOBType[IOBSize] = 1;
      IOBMit[IOBSize] = 0;
      IOBSize++;
   }
}

//+------------------------------------------------------------------+
//| Manage Order Blocks                                              |
//+------------------------------------------------------------------+
void ManageOrderBlocks(double close, double low, double high, datetime time)
{
   for (int i = 0; i < IOBSize; i++) {
      if (IOBType[i] == 1 && close < IOBBtm[i]) {
         RemoveIOB(i--);
      } else if (IOBType[i] == -1 && close > IOBTop[i]) {
         RemoveIOB(i--);
      } else if (OBHighlightMit) {
         if (IOBType[i] == 1 && low <= IOBTop[i] && low > IOBBtm[i]) {
            IOBMit[i]++;
            IOBRight[i] = time;
         } else if (IOBType[i] == -1 && high >= IOBBtm[i] && high < IOBTop[i]) {
            IOBMit[i]++;
            IOBRight[i] = time;
         }
      }
      DrawOB("SMC_IOB_" + i, IOBLeft[i], IOBTop[i], IOBRight[i], IOBBtm[i], IOBType[i], IOBMit[i], false);
   }
}

//+------------------------------------------------------------------+
//| Remove Internal Order Block                                      |
//+------------------------------------------------------------------+
void RemoveIOB(int index)
{
   for (int i = index; i < IOBSize - 1; i++) {
      IOBTop[i] = IOBTop[i + 1];
      IOBBtm[i] = IOBBtm[i + 1];
      IOBLeft[i] = IOBLeft[i + 1];
      IOBRight[i] = IOBRight[i + 1];
      IOBType[i] = IOBType[i + 1];
      IOBMit[i] = IOBMit[i + 1];
   }
   IOBSize--;
}

//+------------------------------------------------------------------+
//| Draw Order Block                                                 |
//+------------------------------------------------------------------+
void DrawOB(string name, datetime left, double top, datetime right, double btm, int type, int mit, bool swing)
{
   color css = (type == 1) ? (mit > 0 ? (swing ? BullMOBCSS : IBullMOBCSS) : (swing ? BullOBCSS : IBullOBCSS))
                           : (mit > 0 ? (swing ? BearMOBCSS : IBearMOBCSS) : (swing ? BearOBCSS : IBearOBCSS));
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, left, top, right, btm);
   ObjectSetInteger(0, name, OBJPROP_COLOR, css);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
}

//+------------------------------------------------------------------+
//| Detect Equal Highs/Lows                                          |
//+------------------------------------------------------------------+
void DetectEQHL(int rates_total)
{
   double eqTop = iHighest(NULL, 0, MODE_HIGH, EQLen * 2 + 1, EQLen);
   double eqBtm = iLowest(NULL, 0, MODE_LOW, EQLen * 2 + 1, EQLen);
   static double prevTop = 0, prevBtm = 0;
   static datetime topX = 0, btmX = 0;

   if (eqTop > 0 && MathAbs(eqTop - prevTop) < iATR(NULL, 0, 14, 1) * EQThreshold) {
      DrawLine("SMC_EQH_" + TimeToString(Time[EQLen]), topX, prevTop, Time[EQLen], eqTop, SwingBearCSS, STYLE_DOT);
      DrawLabel("SMC_EQHLbl_" + TimeToString(Time[EQLen]), Time[EQLen], eqTop, "EQH", SwingBearCSS, ANCHOR_UPPER);
   }
   if (eqBtm > 0 && MathAbs(eqBtm - prevBtm) < iATR(NULL, 0, 14, 1) * EQThreshold) {
      DrawLine("SMC_EQL_" + TimeToString(Time[EQLen]), btmX, prevBtm, Time[EQLen], eqBtm, SwingBullCSS, STYLE_DOT);
      DrawLabel("SMC_EQLLbl_" + TimeToString(Time[EQLen]), Time[EQLen], eqBtm, "EQL", SwingBullCSS, ANCHOR_LOWER);
   }
   if (eqTop > 0) { prevTop = eqTop; topX = Time[EQLen]; }
   if (eqBtm > 0) { prevBtm = eqBtm; btmX = Time[EQLen]; }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gaps                                           |
//+------------------------------------------------------------------+
void DetectFVG(int rates_total, const datetime &time[])
{
   int tf = Period();
   if (FVGTf != "") tf = StrToTimeframe(FVGTf);
   double c1 = iClose(NULL, tf, 1);
   double o1 = iOpen(NULL, tf, 1);
   double h = iHigh(NULL, tf, 0);
   double l = iLow(NULL, tf, 0);
   double h2 = iHigh(NULL, tf, 2);
   double l2 = iLow(NULL, tf, 2);

   if (l > h2 && c1 > h2) {
      DrawRectangle("SMC_FVGBull_" + TimeToString(time[1]), time[1], l, time[0] + FVGExtend * PeriodSeconds(), h2, BullFVGCSS);
   }
   if (h < l2 && c1 < l2) {
      DrawRectangle("SMC_FVGBear_" + TimeToString(time[1]), time[1], h, time[0] + FVGExtend * PeriodSeconds(), l2, BearFVGCSS);
   }
}

//+------------------------------------------------------------------+
//| Draw Previous Highs/Lows                                         |
//+------------------------------------------------------------------+
void DrawPreviousHL(datetime time)
{
   if (ShowPDHL) {
      double pdh = iHigh(NULL, PERIOD_D1, 1);
      double pdl = iLow(NULL, PERIOD_D1, 1);
      DrawLine("SMC_PDH", Time[1], pdh, time, pdh, PDHLCSS, STYLE_SOLID);
      DrawLine("SMC_PDL", Time[1], pdl, time, pdl, PDHLCSS, STYLE_SOLID);
   }
   if (ShowPWHL) {
      double pwh = iHigh(NULL, PERIOD_W1, 1);
      double pwl = iLow(NULL, PERIOD_W1, 1);
      DrawLine("SMC_PWH", Time[1], pwh, time, pwh, PWHLCSS, STYLE_SOLID);
      DrawLine("SMC_PWL", Time[1], pwl, time, pwl, PWHLCSS, STYLE_SOLID);
   }
   if (ShowPMHL) {
      double pmh = iHigh(NULL, PERIOD_MN1, 1);
      double pml = iLow(NULL, PERIOD_MN1, 1);
      DrawLine("SMC_PMH", Time[1], pmh, time, pmh, PMHLCSS, STYLE_SOLID);
      DrawLine("SMC_PML", Time[1], pml, time, pml, PMHLCSS, STYLE_SOLID);
   }
}

//+------------------------------------------------------------------+
//| Draw Premium/Discount Zones                                      |
//+------------------------------------------------------------------+
void DrawSDZones(datetime time)
{
   double avg = (TrailUp + TrailDn) / 2;
   DrawRectangle("SMC_Premium", MathMax(Time[TopX], Time[BtmX]), TrailUp, time, 0.95 * TrailUp + 0.05 * TrailDn, PremiumCSS);
   DrawRectangle("SMC_EQ", MathMax(Time[TopX], Time[BtmX]), 0.525 * TrailUp + 0.475 * TrailDn, time, 0.525 * TrailDn + 0.475 * TrailUp, EqCSS);
   DrawRectangle("SMC_Discount", MathMax(Time[TopX], Time[BtmX]), 0.95 * TrailDn + 0.05 * TrailUp, time, TrailDn, DiscountCSS);
}

//+------------------------------------------------------------------+
//| Draw Line                                                        |
//+------------------------------------------------------------------+
void DrawLine(string name, datetime x1, double y1, datetime x2, double y2, color css, int style)
{
   ObjectCreate(0, name, OBJ_TREND, 0, x1, y1, x2, y2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, css);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Draw Label                                                       |
//+------------------------------------------------------------------+
void DrawLabel(string name, datetime x, double y, string text, color css, int anchor)
{
   ObjectCreate(0, name, OBJ_TEXT, 0, x, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, css);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
}

//+------------------------------------------------------------------+
//| Draw Rectangle                                                   |
//+------------------------------------------------------------------+
void DrawRectangle(string name, datetime x1, double y1, datetime x2, double y2, color css)
{
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, x1, y1, x2, y2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, css);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
}

//+------------------------------------------------------------------+
//| Convert String to Timeframe                                      |
//+------------------------------------------------------------------+
int StrToTimeframe(string tf)
{
   if (tf == "D1") return PERIOD_D1;
   if (tf == "W1") return PERIOD_W1;
   if (tf == "M1") return PERIOD_M1;
   return Period();
}
//+------------------------------------------------------------------+