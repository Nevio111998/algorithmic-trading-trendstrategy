//|                                              TrendFollowingEA.mq5 |
//|                                             Nevio Di Palma       |
//|                                                                  |
//| STRATEGY OVERVIEW:                                              |
//| 1. Calculate Daily Bias (D1 structure breaks)                  |
//| 2. Filter by trading session (Asian/London/New York)           |
//| 3. Identify H4 market structure (swing high/low)                |
//| 4. Find Fair Value Gap (FVG) in 50% Fibonacci zone             |
//| 5. Wait for price to touch FVG or 50% level                    |
//| 6. Confirm with 2 consecutive momentum candles on M15          |
//| 7. Enter trade with ATR-based SL and RR-based TP               |
//+------------------------------------------------------------------+
#property copyright "Nevio Di Palma"
#property link      ""
#property version   "1.13"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "Fibonacci Plot Type"
enum FibPlotType
{
   PLOT_LOOKBACK = 0,
   PLOT_PRICE_INPUT = 1
};
input FibPlotType InpFibPlotType = PLOT_LOOKBACK;

input group "Lookback Settings"
enum LookbackType
{
   LOOKBACK_CANDLES = 0,
   LOOKBACK_DAYS = 1
};
input LookbackType InpLookbackType = LOOKBACK_CANDLES;
input int InpLookbackPeriod = 100;
input bool InpReverseFibs = false;
input bool InpShowExtraFibs = false;

input group "Fibs Based on Price Input"
input double InpHighPrice = 0.0;
input double InpLowPrice = -1.0;

input group "Fib Line/Label Style"
input color InpBullColor = clrGreen;
input color InpBearColor = clrRed;
input bool InpShowCurrentFib = false;
input color InpCurrentFibColor = clrOrange;
enum LineStyleType
{
   LINE_STYLE_DOTTED = 0,
   LINE_STYLE_SOLID = 1
};
input LineStyleType InpLineStyle = LINE_STYLE_DOTTED;
input int InpLineWidth = 1;
input bool InpExtendLeft = false;

input group "Show/Hide Fibonacci Levels"
input bool InpShowFib0 = true;
input bool InpShowFib236 = true;
input bool InpShowFib382 = true;
input bool InpShowFib500 = true;
input bool InpShowFib618 = true;
input bool InpShowFib786 = true;
input bool InpShowFib886 = true;
input bool InpShowFib1000 = true;

input group "Extension Levels (Price Input Mode)"
input bool InpShowFib1113 = true;
input bool InpShowFib1272 = true;
input bool InpShowFib1618 = true;
input bool InpShowFib2000 = true;
input bool InpShowFib2236 = true;
input bool InpShowFib2618 = true;
input bool InpShowFib3236 = true;
input bool InpShowFib3618 = true;
input bool InpShowFib4236 = true;
input bool InpShowFib4618 = true;

input group "Fair Value Gaps (FVG) Settings"
input bool InpShowFVG = true;
input int InpFVGLookback = 50;
input color InpBullishFVGColor = clrDodgerBlue;
input color InpBearishFVGColor = clrOrangeRed;
input int InpFVGTransparency = 80;

input group "Daily Bias Filter"
input bool InpShowBiasOnChart = true;
input color InpBullishBiasColor = clrLime;
input color InpBearishBiasColor = clrRed;
input color InpNeutralBiasColor = clrGray;

input group "Trading Session Filter"
input bool InpEnableSessionFilter = true;
input bool InpTradeAsianSession = false;
input string InpAsianStartTime = "01:00";
input string InpAsianEndTime = "07:00";
input bool InpTradeLondonSession = true;
input string InpLondonStartTime = "07:00";
input string InpLondonEndTime = "13:00";
input bool InpTradeNewYorkSession = true;
input string InpNewYorkStartTime = "13:00";
input string InpNewYorkEndTime = "19:00";

input group "Trading Settings"
input bool InpEnableTrading = true;
input double InpRiskPercent = 1.0;
input int InpATRPeriod = 14;
input double InpATRMultiplier = 2.5;
input double InpRiskReward = 1.0;
input int InpMaxTradesPerDay = 2;
input int InpMaxTradeHours = 120;      // Max Hours Per Trade (0 = disabled)
input int InpMagicNumber = 123456;

input group "Spread Guard"
input bool InpEnableSpreadGuard = true;
input int InpMaxSpreadPoints = 30;     // Max spread in points (0 = disabled)

input group "ATR Spike Filter (Volatility Guard)"
input bool InpEnableATRSpikeFilter = true;
input int InpATRSpikeLookback = 50;   // Bars for average ATR calculation
input double InpATRSpikeMultiplier = 1.5;  // Block if current ATR > average * this (e.g. 1.5 = 50% spike)

input group "Volatility Regime Analysis"
input bool InpEnableRegimeAnalysis = true;
input int InpRegimeLookback = 100;    // Bars for ATR percentile calculation
input int InpRegimeHistoryDays = 90;  // Days of history to analyze on EA stop
input bool InpRegimeLogCSV = false;   // Log trades to CSV for external analysis

input group "Circuit Breaker"
input bool InpEnableCircuitBreaker = true;
input double InpMaxDailyLossPct = 2.0;
input int InpMaxConsecutiveLosses = 3;
input int InpMaxTradeErrorsInWindow = 5;
input int InpErrorWindowMinutes = 10;
input bool InpManualResetCB = false;

input group "Exposure Limits"
input int InpMaxPositionsPerSymbol = 1;
input double InpMaxTotalLotsPerSymbol = 1.0;
input double InpMaxMarginUsagePct = 50.0;

input group "Safety - Margin (pre-trade)"
input double InpMinFreeMarginPct = 30.0;

input group "Safety - Logging"
input int InpLogBlockThrottleSec = 60;

input group "BA - Trade Journal & Analysis"
input bool InpEnableTradeJournal = true;    // Write per-trade CSV on EA stop
input bool InpEnableRejectedLog = true;     // Write rejected-trade CSV on EA stop
input int InpRejectedTradeLogCooldownMinutes = 120; // Cooldown per reject key (0 = disabled)
input bool InpPrintExtendedSummary = true;  // Print breakdowns by session/bias/DOW
input int InpMaxSlippagePoints = 20;        // Max acceptable slippage (0 = no check, log only)

input group "Execution Hardening"
input int InpMaxRetries = 3;                // Max retry attempts for retryable errors
input int InpRetryDelayMs = 500;            // Base delay between retries (ms, exponential backoff)
input bool InpEnforceSlippage = true;       // Close position immediately if slippage exceeds max
input double InpProjectedMarginPct = 30.0;  // Min projected free margin % after trade (0 = skip)

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
double g_fhigh = 0;
double g_flow = 0;
int g_highBar = 0;
int g_lowBar = 0;
bool g_revfibs = false;

int g_effectivePeriod = 0;
string g_objectPrefix = "FibRet_";
datetime g_lastBarTime = 0;
datetime g_lastH4BarTime = 0;

bool g_waitingForEntry = false;
int g_tradeDirection = 0;
int g_atrHandle = INVALID_HANDLE;

double g_activeFVGTop = 0;
double g_activeFVGBottom = 0;
bool g_hasActiveFVG = false;
datetime g_fvgTime = 0;
bool g_waitingFor50Percent = false;

int g_dailyTradeCount = 0;
datetime g_lastTradeDate = 0;

int g_currentBias = 0;
datetime g_lastD1BarTime = 0;
string g_biasLabelName = "DailyBiasLabel";

datetime g_rejTimes[];
string   g_rejReasons[];
string   g_rejDirections[];
string   g_rejDetails[];
int      g_rejCount = 0;

struct RejectedTradeLogState
{
   string   key;
   datetime lastLogTime;
};

RejectedTradeLogState g_rejLogState[];

bool     g_tradingDisabled = false;
string   g_cbLastReason = "";
int      g_cbDayKey = -1;
datetime g_cbDayStart = 0;
double   g_cbStartEquity = 0.0;
int      g_consecutiveLosses = 0;
datetime g_errorTimes[];

//+------------------------------------------------------------------+
//| PERSISTENT STATE — Restart & Crash Safety                        |
//+------------------------------------------------------------------+
#define STATE_VERSION       1
#define STATE_SAVE_INTERVAL 30
#define STATE_MAX_SETUP_AGE 14400

datetime g_lastStateSave = 0;

struct PersistentState
{
   int      version;
   int      magic;
   int      symbolHash;
   datetime saveTime;
   int      tradingDisabled;
   int      cbDayKey;
   datetime cbDayStart;
   double   cbStartEquity;
   int      consecutiveLosses;
   int      cbReasonCode;
   int      dailyTradeCount;
   datetime lastTradeDate;
   int      waitingForEntry;
   int      tradeDirection;
   int      hasActiveFVG;
   double   activeFVGTop;
   double   activeFVGBottom;
   datetime fvgTime;
   int      waitingFor50Percent;
   int      currentBias;
};

int GetSymbolHash()
{
   int h = 0;
   for(int i = 0; i < StringLen(_Symbol); i++)
      h = h * 31 + StringGetCharacter(_Symbol, i);
   return h;
}

string GetStateFileName()
{
   return "EA_State_" + _Symbol + "_" + IntegerToString(InpMagicNumber) + ".bin";
}

int EncodeCBReason(const string reason)
{
   if(reason == "")                    return 0;
   if(reason == "[CB_DAILY_LOSS]")     return 1;
   if(reason == "[CB_CONSEC_LOSSES]")  return 2;
   if(reason == "[CB_ERROR_RATE]")     return 3;
   return 4;
}

string DecodeCBReason(int code)
{
   switch(code)
   {
      case 0:  return "";
      case 1:  return "[CB_DAILY_LOSS]";
      case 2:  return "[CB_CONSEC_LOSSES]";
      case 3:  return "[CB_ERROR_RATE]";
      default: return "[CB_UNKNOWN]";
   }
}

string DirectionToString(const int direction)
{
   return direction == 1 ? "LONG" : "SHORT";
}

string BiasToString(const int bias)
{
   if(bias == 1)  return "BULLISH";
   if(bias == -1) return "BEARISH";
   return "NEUTRAL";
}

string BiasTagShort()
{
   if(g_currentBias == 1)  return "BULL";
   if(g_currentBias == -1) return "BEAR";
   return "NEUT";
}

string ActiveSessionOrClosed()
{
   string sess = GetActiveSession();
   return sess == "" ? "CLOSED" : sess;
}

string BuildOrderComment(const int direction, const double atr, const double point)
{
   MqlDateTime dow;
   TimeToStruct(TimeCurrent(), dow);
   long spreadNow = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   string regime = InpEnableRegimeAnalysis ? GetVolatilityRegime() : "NA";

   return (direction == 1 ? "L" : "S")
      + "|" + regime
      + "|" + ActiveSessionOrClosed()
      + "|" + BiasTagShort()
      + "|D" + IntegerToString(dow.day_of_week)
      + "|SP" + IntegerToString(spreadNow)
      + "|ATR" + DoubleToString(atr / point, 0);
}

void BuildStatusMainState(string &statusText, color &statusColor)
{
   ulong posTk = 0;
   if(HasMyOpenPosition(_Symbol, posTk))
   {
      statusText += "IN TRADE";
      statusColor = clrYellow;
      return;
   }

   if(g_waitingForEntry)
   {
      statusText += "WAITING FOR MOMENTUM (" + DirectionToString(g_tradeDirection) + ")";
      statusColor = clrOrange;
      return;
   }

   if(g_hasActiveFVG)
   {
      if(g_waitingFor50Percent)
      {
         statusText += "WAITING FOR 50% TOUCH (" + DirectionToString(g_tradeDirection) + ")";
         statusColor = clrMagenta;
      }
      else
      {
         statusText += "WAITING FOR FVG TOUCH (" + DirectionToString(g_tradeDirection) + ")";
         statusColor = clrCyan;
      }
      return;
   }

   statusText += "SCANNING FOR SETUP";
   statusColor = clrLightGray;
}

void AppendSpreadStatus(string &statusText)
{
   if(!(InpEnableSpreadGuard && InpMaxSpreadPoints > 0))
      return;

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   statusText += " | Spread: " + IntegerToString(spread) + "/" + IntegerToString(InpMaxSpreadPoints);
   if(spread > InpMaxSpreadPoints)
      statusText += " (BLOCKED)";
}

void AppendATRSpikeStatus(string &statusText)
{
   if(!(InpEnableATRSpikeFilter && InpATRSpikeLookback >= 5 && InpATRSpikeMultiplier > 0))
      return;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int barsNeed = InpATRSpikeLookback + 1;
   if(CopyBuffer(g_atrHandle, 0, 0, barsNeed, atrBuf) < barsNeed)
      return;

   double curATR = atrBuf[0];
   double sum = 0;
   for(int i = 1; i < barsNeed; i++) sum += atrBuf[i];
   double avgATR = sum / InpATRSpikeLookback;
   double maxATR = avgATR * InpATRSpikeMultiplier;
   statusText += " | ATR: " + DoubleToString(curATR, 2) + "/" + DoubleToString(maxATR, 2);
   if(curATR > maxATR)
      statusText += " (SPIKE)";
}

void ClearSetupState(const bool clearFVGZone = false)
{
   g_waitingForEntry     = false;
   g_hasActiveFVG        = false;
   g_waitingFor50Percent = false;
   g_tradeDirection      = 0;

   if(clearFVGZone)
   {
      g_activeFVGTop    = 0;
      g_activeFVGBottom = 0;
      g_fvgTime         = 0;
   }
}

void SavePersistentState()
{
   if(MQLInfoInteger(MQL_TESTER)) return;

   PersistentState st;
   ZeroMemory(st);

   st.version             = STATE_VERSION;
   st.magic               = InpMagicNumber;
   st.symbolHash          = GetSymbolHash();
   st.saveTime            = TimeCurrent();
   st.tradingDisabled     = g_tradingDisabled ? 1 : 0;
   st.cbDayKey            = g_cbDayKey;
   st.cbDayStart          = g_cbDayStart;
   st.cbStartEquity       = g_cbStartEquity;
   st.consecutiveLosses   = g_consecutiveLosses;
   st.cbReasonCode        = EncodeCBReason(g_cbLastReason);
   st.dailyTradeCount     = g_dailyTradeCount;
   st.lastTradeDate       = g_lastTradeDate;
   st.waitingForEntry     = g_waitingForEntry ? 1 : 0;
   st.tradeDirection      = g_tradeDirection;
   st.hasActiveFVG        = g_hasActiveFVG ? 1 : 0;
   st.activeFVGTop        = g_activeFVGTop;
   st.activeFVGBottom     = g_activeFVGBottom;
   st.fvgTime             = g_fvgTime;
   st.waitingFor50Percent = g_waitingFor50Percent ? 1 : 0;
   st.currentBias         = g_currentBias;

   string fn = GetStateFileName();
   int fh = FileOpen(fn, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(fh == INVALID_HANDLE)
   {
      Print("[STATE] Save FAILED: ", fn, " err=", GetLastError());
      return;
   }
   FileWriteStruct(fh, st);
   FileClose(fh);
   g_lastStateSave = TimeCurrent();
}

bool LoadPersistentState(PersistentState &st)
{
   string fn = GetStateFileName();
   if(!FileIsExist(fn, FILE_COMMON))
      return false;

   int fh = FileOpen(fn, FILE_READ | FILE_BIN | FILE_COMMON);
   if(fh == INVALID_HANDLE)
      return false;

   uint bytesRead = FileReadStruct(fh, st);
   FileClose(fh);

   if(bytesRead != sizeof(PersistentState))
   {
      Print("[STATE] File size mismatch (", bytesRead, " vs ", sizeof(PersistentState), ") — ignoring");
      return false;
   }
   if(st.version != STATE_VERSION)
   {
      Print("[STATE] Version mismatch (file=", st.version, " expected=", STATE_VERSION, ") — ignoring");
      return false;
   }
   if(st.magic != InpMagicNumber)
   {
      Print("[STATE] Magic mismatch (file=", st.magic, " expected=", InpMagicNumber, ") — ignoring");
      return false;
   }
   if(st.symbolHash != GetSymbolHash())
   {
      Print("[STATE] Symbol mismatch — ignoring");
      return false;
   }
   return true;
}

void RestoreFromPersistentState()
{
   if(MQLInfoInteger(MQL_TESTER)) return;

   PersistentState st;
   if(!LoadPersistentState(st))
   {
      Print("[STATE] No valid saved state — starting fresh");
      return;
   }

   datetime age = TimeCurrent() - st.saveTime;
   Print("[STATE] ======= RESTORING PERSISTENT STATE =======");
   Print("[STATE] Saved: ", TimeToString(st.saveTime, TIME_DATE|TIME_MINUTES), " (", age, "s ago)");

   //--- Circuit Breaker ---
   g_cbDayKey          = st.cbDayKey;
   g_cbDayStart        = st.cbDayStart;
   g_cbStartEquity     = st.cbStartEquity;
   g_consecutiveLosses = st.consecutiveLosses;
   g_tradingDisabled   = (st.tradingDisabled != 0);
   g_cbLastReason      = DecodeCBReason(st.cbReasonCode);

   MqlDateTime tNow;
   TimeToStruct(TimeCurrent(), tNow);
   int todayKey = tNow.year * 1000 + tNow.day_of_year;
   if(todayKey != g_cbDayKey)
   {
      Print("[STATE] New trading day detected — resetting Circuit Breaker");
      g_cbDayKey          = todayKey;
      g_cbDayStart        = TimeCurrent();
      g_cbStartEquity     = AccountInfoDouble(ACCOUNT_EQUITY);
      g_consecutiveLosses = 0;
      g_tradingDisabled   = false;
      g_cbLastReason      = "";
      ArrayResize(g_errorTimes, 0);
   }
   else if(g_tradingDisabled)
   {
      if(g_cbLastReason == "")
         g_cbLastReason = ResolveCBCause();
      Print("[STATE] Circuit Breaker ACTIVE — reason: ", g_cbLastReason, " | Trading disabled until day reset or manual reset");
   }
   else
      Print("[STATE] Circuit Breaker: inactive | Consecutive losses: ", g_consecutiveLosses);

   //--- Daily trade tracking ---
   g_dailyTradeCount = st.dailyTradeCount;
   g_lastTradeDate   = st.lastTradeDate;
   if(todayKey != st.cbDayKey)
   {
      g_dailyTradeCount = 0;
      g_lastTradeDate   = TimeCurrent();
   }
   Print("[STATE] Daily trades: ", g_dailyTradeCount, "/", InpMaxTradesPerDay);

   //--- Open position handling ---
   ulong openTicket = 0;
   if(HasMyOpenPosition(_Symbol, openTicket))
   {
      Print("[STATE] Open position found: ticket=", openTicket, " — EA will continue managing it");
      ClearSetupState(false);
      Print("[STATE] Setup state cleared (position already open)");
   }
   else
   {
      //--- Setup / FVG state ---
      if(age < STATE_MAX_SETUP_AGE)
      {
         g_waitingForEntry     = (st.waitingForEntry != 0);
         g_tradeDirection      = st.tradeDirection;
         g_hasActiveFVG        = (st.hasActiveFVG != 0);
         g_activeFVGTop        = st.activeFVGTop;
         g_activeFVGBottom     = st.activeFVGBottom;
         g_fvgTime             = st.fvgTime;
         g_waitingFor50Percent = (st.waitingFor50Percent != 0);

         if(g_hasActiveFVG)
            Print("[STATE] Active FVG restored: ", g_activeFVGBottom, " - ", g_activeFVGTop,
                  " dir=", DirectionToString(g_tradeDirection),
                  " waitEntry=", g_waitingForEntry, " wait50=", g_waitingFor50Percent);
         else if(g_waitingForEntry)
            Print("[STATE] Waiting for momentum entry restored: dir=", DirectionToString(g_tradeDirection));
         else
            Print("[STATE] No active setup — scanning will resume");
      }
      else
      {
         Print("[STATE] Setup state too old (", age / 3600, "h) — discarding, will rescan");
         ClearSetupState(false);
      }
   }

   //--- Bias ---
   g_currentBias = st.currentBias;
   Print("[STATE] Bias: ", BiasToString(g_currentBias));
   Print("[STATE] ======= STATE RESTORATION COMPLETE =======");
}

//+------------------------------------------------------------------+
//| Expert Advisor initialization function                           |
//+------------------------------------------------------------------+
int OnInit()
{
   DeleteAllObjects();
   
   g_atrHandle = iATR(_Symbol, PERIOD_M15, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator: ", GetLastError());
      return(INIT_FAILED);
   }
   
   if(iBars(_Symbol, PERIOD_D1) < 3)
   {
      Print("ERROR: Insufficient D1 bars for bias calculation");
      return(INIT_FAILED);
   }
   
   UpdateFibonacci();
   UpdateH4Structure();
   CalculateDailyBias();
   
   if(InpShowBiasOnChart)
   {
      CreateBiasLabel();
      UpdateBiasLabel();
   }
   
   Print("EA Initialized. Trading: ", InpEnableTrading ? "Enabled" : "Disabled");
   Print("Daily Bias: ", BiasToString(g_currentBias));
   
   if(InpEnableSessionFilter)
   {
      Print("=======================================");
      Print("SESSION FILTER: ENABLED");
      Print("=======================================");
      if(InpTradeAsianSession)
         Print("- Asian Session:    ", InpAsianStartTime, " - ", InpAsianEndTime);
      else
         Print("- Asian Session:    DISABLED");
      
      if(InpTradeLondonSession)
         Print("- London Session:   ", InpLondonStartTime, " - ", InpLondonEndTime);
      else
         Print("- London Session:   DISABLED");
      
      if(InpTradeNewYorkSession)
         Print("- New York Session: ", InpNewYorkStartTime, " - ", InpNewYorkEndTime);
      else
         Print("- New York Session: DISABLED");
      Print("=======================================");
   }
   else
   {
      Print("SESSION FILTER: DISABLED (Trading 24/5)");
   }
   
   if(InpEnableSpreadGuard && InpMaxSpreadPoints > 0)
      Print("SPREAD GUARD: ENABLED | Max spread: ", InpMaxSpreadPoints, " points");
   else
      Print("SPREAD GUARD: DISABLED");
   
   if(InpEnableATRSpikeFilter && InpATRSpikeLookback >= 5 && InpATRSpikeMultiplier > 0)
      Print("ATR SPIKE FILTER: ENABLED | Lookback: ", InpATRSpikeLookback, " | Max: avg*", InpATRSpikeMultiplier);
   else
      Print("ATR SPIKE FILTER: DISABLED");
   
   if(InpEnableRegimeAnalysis)
      Print("VOLATILITY REGIME: ENABLED | Lookback: ", InpRegimeLookback, " | History: ", InpRegimeHistoryDays, " days");
   else
      Print("VOLATILITY REGIME: DISABLED");
   
   CircuitBreakerNewBrokerDay();
   Print("Safety: Magic=", InpMagicNumber, " CB=", InpEnableCircuitBreaker ? "ON" : "OFF");
   
   RestoreFromPersistentState();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Advisor deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SavePersistentState();
   
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   
   if(InpShowBiasOnChart)
      ObjectDelete(0, g_biasLabelName);
   
   if(InpEnableRegimeAnalysis)
      PrintRegimePerformanceSummary();
   
   WriteTradeJournalCSV();
   WriteRejectedTradesCSV();
   PrintExtendedPerformanceSummary();
   
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Expert Advisor tick function                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!MQLInfoInteger(MQL_TESTER) && TimeCurrent() - g_lastStateSave >= STATE_SAVE_INTERVAL)
      SavePersistentState();

   datetime currentD1BarTime = iTime(_Symbol, PERIOD_D1, 0);
   if(currentD1BarTime != g_lastD1BarTime)
   {
      g_lastD1BarTime = currentD1BarTime;
      CalculateDailyBias();
      
      if(InpShowBiasOnChart)
         UpdateBiasLabel();
   }
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      UpdateFibonacci();
   }
   
   datetime currentH4BarTime = iTime(_Symbol, PERIOD_H4, 0);
   if(currentH4BarTime != g_lastH4BarTime)
   {
      g_lastH4BarTime = currentH4BarTime;
      UpdateH4Structure();
   }
   
   if(InpEnableTrading)
   {
      CircuitBreakerNewBrokerDay();
      ProcessManualCircuitBreakerReset();
      EvaluateCircuitBreakerFromTick();
      
      ulong myTicket = 0;
      if(HasMyOpenPosition(_Symbol, myTicket))
      {
         CheckTimeBasedExit(myTicket);
         return;
      }
      
      if(InpEnableSessionFilter && !IsWithinTradingSession())
         return;
      
      if(!CheckDailyTradeLimit())
      {
         if(g_waitingForEntry)
            RecordRejectedTrade("[BLOCK_DAILY_LIMIT]", DirectionToString(g_tradeDirection), BuildRejectedDetails());
         return;
      }
      
      if(!g_hasActiveFVG && !g_waitingForEntry)
      {
         static datetime lastSetupCheck = 0;
         if(TimeCurrent() - lastSetupCheck > 60)
         {
            CheckH4Setup();
            lastSetupCheck = TimeCurrent();
         }
      }
      
      if(g_hasActiveFVG && !g_waitingForEntry)
      {
         static datetime lastValidationCheck = 0;
         if(TimeCurrent() - lastValidationCheck > 5)
         {
            CheckFVGValidation();
            lastValidationCheck = TimeCurrent();
         }
      }
      
      if(g_hasActiveFVG && !g_waitingForEntry)
      {
         static datetime lastTouchCheck = 0;
         if(TimeCurrent() - lastTouchCheck > 10)
         {
            CheckFVGTouch();
            lastTouchCheck = TimeCurrent();
         }
      }
      
      if(g_waitingForEntry)
      {
         CheckMomentumEntry();
      }
   }
}

//+------------------------------------------------------------------+
//| Trade transactions — consecutive losses (this EA, this symbol)   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   ulong dealTicket = trans.deal;
   if(dealTicket == 0) return;
   if(!HistoryDealSelect(dealTicket)) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != (long)InpMagicNumber) return;
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) return;
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   double net = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   if(net < 0.0)
      g_consecutiveLosses++;
   else if(net > 0.0)
      g_consecutiveLosses = 0;
   SavePersistentState();
   if(InpEnableCircuitBreaker && InpMaxConsecutiveLosses > 0 && g_consecutiveLosses >= InpMaxConsecutiveLosses)
      DisableTrading("[CB_CONSEC_LOSSES]");
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session                  |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   int currentMinutes = currentTime.hour * 60 + currentTime.min;
   
   if(InpTradeAsianSession)
   {
      int asianStart = StringToMinutes(InpAsianStartTime);
      int asianEnd = StringToMinutes(InpAsianEndTime);
      
      if(IsTimeInRange(currentMinutes, asianStart, asianEnd))
      {
         static datetime lastAsianPrint = 0;
         if(TimeCurrent() - lastAsianPrint > 3600)
         {
            Print("Trading: ASIAN SESSION active");
            lastAsianPrint = TimeCurrent();
         }
         return true;
      }
   }
   
   if(InpTradeLondonSession)
   {
      int londonStart = StringToMinutes(InpLondonStartTime);
      int londonEnd = StringToMinutes(InpLondonEndTime);
      
      if(IsTimeInRange(currentMinutes, londonStart, londonEnd))
      {
         static datetime lastLondonPrint = 0;
         if(TimeCurrent() - lastLondonPrint > 3600)
         {
            Print("Trading: LONDON SESSION active");
            lastLondonPrint = TimeCurrent();
         }
         return true;
      }
   }
   
   if(InpTradeNewYorkSession)
   {
      int nyStart = StringToMinutes(InpNewYorkStartTime);
      int nyEnd = StringToMinutes(InpNewYorkEndTime);
      
      if(IsTimeInRange(currentMinutes, nyStart, nyEnd))
      {
         static datetime lastNYPrint = 0;
         if(TimeCurrent() - lastNYPrint > 3600)
         {
            Print("Trading: NEW YORK SESSION active");
            lastNYPrint = TimeCurrent();
         }
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Convert time string "HH:MM" to minutes from midnight             |
//+------------------------------------------------------------------+
int StringToMinutes(string timeStr)
{
   string parts[];
   int count = StringSplit(timeStr, ':', parts);
   
   if(count != 2)
      return 0;
   
   int hours = (int)StringToInteger(parts[0]);
   int minutes = (int)StringToInteger(parts[1]);
   
   return hours * 60 + minutes;
}

//+------------------------------------------------------------------+
//| Check if time is within range (handles midnight crossover)       |
//+------------------------------------------------------------------+
bool IsTimeInRange(int currentMin, int startMin, int endMin)
{
   if(startMin <= endMin)
   {
      return (currentMin >= startMin && currentMin < endMin);
   }
   else
   {
      return (currentMin >= startMin || currentMin < endMin);
   }
}

//+------------------------------------------------------------------+
//| Get name of currently active trading session                     |
//+------------------------------------------------------------------+
string GetActiveSession()
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   int currentMinutes = currentTime.hour * 60 + currentTime.min;
   
   if(InpTradeAsianSession)
   {
      int asianStart = StringToMinutes(InpAsianStartTime);
      int asianEnd = StringToMinutes(InpAsianEndTime);
      
      if(IsTimeInRange(currentMinutes, asianStart, asianEnd))
         return "ASIAN";
   }
   
   if(InpTradeLondonSession)
   {
      int londonStart = StringToMinutes(InpLondonStartTime);
      int londonEnd = StringToMinutes(InpLondonEndTime);
      
      if(IsTimeInRange(currentMinutes, londonStart, londonEnd))
         return "LONDON";
   }
   
   if(InpTradeNewYorkSession)
   {
      int nyStart = StringToMinutes(InpNewYorkStartTime);
      int nyEnd = StringToMinutes(InpNewYorkEndTime);
      
      if(IsTimeInRange(currentMinutes, nyStart, nyEnd))
         return "NEW YORK";
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Check if spread is within allowed limit (Spread Guard)           |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   if(!InpEnableSpreadGuard || InpMaxSpreadPoints <= 0)
      return true;
   
   long currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(currentSpread > InpMaxSpreadPoints)
   {
      static datetime lastSpreadPrint = 0;
      if(TimeCurrent() - lastSpreadPrint > 60)
      {
         Print("SPREAD GUARD: Blocked entry - Spread ", currentSpread, " > Max ", InpMaxSpreadPoints, " points");
         lastSpreadPrint = TimeCurrent();
      }
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if ATR is not spiking (Volatility Guard)                   |
//+------------------------------------------------------------------+
bool IsATRSpikeOK()
{
   if(!InpEnableATRSpikeFilter || InpATRSpikeLookback < 5 || InpATRSpikeMultiplier <= 0)
      return true;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   int barsNeeded = InpATRSpikeLookback + 1;
   if(CopyBuffer(g_atrHandle, 0, 0, barsNeeded, atrBuffer) < barsNeeded)
      return true;
   
   double currentATR = atrBuffer[0];
   double sumATR = 0;
   int count = 0;
   for(int i = 1; i < barsNeeded; i++)
   {
      sumATR += atrBuffer[i];
      count++;
   }
   if(count == 0) return true;
   
   double avgATR = sumATR / count;
   double maxAllowedATR = avgATR * InpATRSpikeMultiplier;
   
   if(currentATR > maxAllowedATR)
   {
      static datetime lastATRPrint = 0;
      if(TimeCurrent() - lastATRPrint > 60)
      {
         Print("ATR SPIKE FILTER: Blocked entry - ATR ", DoubleToString(currentATR, 5), 
               " > ", DoubleToString(maxAllowedATR, 5), " (avg*", InpATRSpikeMultiplier, ")");
         lastATRPrint = TimeCurrent();
      }
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Ownership + risk/safety (after IsSpreadOK / IsATRSpikeOK)         |
//+------------------------------------------------------------------+
void LogBlock(const string reasonCode, const string extra = "")
{
   static string s_codes[];
   static datetime s_times[];
   int n = ArraySize(s_codes);
   int idx = -1;
   for(int i = 0; i < n; i++) { if(s_codes[i] == reasonCode) { idx = i; break; } }
   if(idx < 0)
   {
      idx = n;
      ArrayResize(s_codes, n + 1);
      ArrayResize(s_times, n + 1);
      s_codes[idx] = reasonCode;
      s_times[idx] = 0;
   }
   if(TimeCurrent() - s_times[idx] < InpLogBlockThrottleSec)
      return;
   s_times[idx] = TimeCurrent();
   string tail = extra == "" ? "" : (" | " + extra);
   Print(reasonCode, " ", _Symbol, tail);
}

string ExtractSessionFromRejectedDetails(const string details)
{
   string parts[];
   int nP = StringSplit(details, '|', parts);
   for(int p = 0; p < nP; p++)
   {
      if(StringFind(parts[p], "sess=") == 0)
      {
         string sess = StringSubstr(parts[p], 5);
         if(sess != "")
            return sess;
      }
   }
   return ActiveSessionOrClosed();
}

int CountExecErrorsInWindow()
{
   datetime cut = TimeCurrent() - InpErrorWindowMinutes * 60;
   int c = 0;
   for(int i = ArraySize(g_errorTimes) - 1; i >= 0; i--)
      if(g_errorTimes[i] >= cut) c++;
   return c;
}

string ResolveCBCause()
{
   if(g_cbLastReason != "")
      return g_cbLastReason;

   if(!g_tradingDisabled)
      return "NA";

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_cbStartEquity > 0.0 && InpMaxDailyLossPct > 0.0)
   {
      double ddp = (g_cbStartEquity - eq) / g_cbStartEquity * 100.0;
      if(ddp >= InpMaxDailyLossPct)
         return "[CB_DAILY_LOSS]";
   }
   if(InpMaxConsecutiveLosses > 0 && g_consecutiveLosses >= InpMaxConsecutiveLosses)
      return "[CB_CONSEC_LOSSES]";
   if(InpMaxTradeErrorsInWindow > 0 && CountExecErrorsInWindow() >= InpMaxTradeErrorsInWindow)
      return "[CB_ERROR_RATE]";

   return "[CB_UNKNOWN]";
}

bool ShouldLogRejectedTrade(string symbol, string direction, string reason, string session)
{
   if(InpRejectedTradeLogCooldownMinutes <= 0)
      return true;

   datetime nowTime = TimeCurrent();
   int cooldownSec = InpRejectedTradeLogCooldownMinutes * 60;
   string key = symbol + "|" + direction + "|" + reason + "|" + session;

   int n = ArraySize(g_rejLogState);
   for(int i = 0; i < n; i++)
   {
      if(g_rejLogState[i].key != key)
         continue;

      if((nowTime - g_rejLogState[i].lastLogTime) < cooldownSec)
         return false;

      g_rejLogState[i].lastLogTime = nowTime;
      return true;
   }

   ArrayResize(g_rejLogState, n + 1);
   g_rejLogState[n].key = key;
   g_rejLogState[n].lastLogTime = nowTime;
   return true;
}

void RecordRejectedTrade(const string reasonCode, const string direction, const string details)
{
   if(!InpEnableRejectedLog) return;
   string session = ExtractSessionFromRejectedDetails(details);
   if(!ShouldLogRejectedTrade(_Symbol, direction, reasonCode, session))
      return;

   int i = g_rejCount;
   g_rejCount++;
   ArrayResize(g_rejTimes, g_rejCount);
   ArrayResize(g_rejReasons, g_rejCount);
   ArrayResize(g_rejDirections, g_rejCount);
   ArrayResize(g_rejDetails, g_rejCount);
   g_rejTimes[i] = TimeCurrent();
   g_rejReasons[i] = reasonCode;
   g_rejDirections[i] = direction;
   g_rejDetails[i] = details;
}

string BuildRejectedDetails()
{
   MqlTick tk;
   SymbolInfoTick(_Symbol, tk);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spreadPts = (tk.ask > 0 && tk.bid > 0 && point > 0) ? (tk.ask - tk.bid) / point : 0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double fmPct = (eq > 0) ? fm / eq * 100.0 : 0;
   double ddPct = (g_cbStartEquity > 0) ? (g_cbStartEquity - eq) / g_cbStartEquity * 100.0 : 0;
   string sess = GetActiveSession();
   if(sess == "") sess = "CLOSED";
   string bias = (g_currentBias == 1) ? "BULL" : (g_currentBias == -1 ? "BEAR" : "NEUT");
   string regime = InpEnableRegimeAnalysis ? GetVolatilityRegime() : "NA";
   MqlDateTime dow;
   TimeToStruct(TimeCurrent(), dow);
   
   string cbCause = g_tradingDisabled ? ResolveCBCause() : "NA";

   return "spread=" + DoubleToString(spreadPts, 1)
      + "|fmPct=" + DoubleToString(fmPct, 1)
      + "|ddPct=" + DoubleToString(ddPct, 2)
      + "|consec=" + IntegerToString(g_consecutiveLosses)
      + "|errWin=" + IntegerToString(CountExecErrorsInWindow())
      + "|cbCause=" + cbCause
      + "|sess=" + sess
      + "|bias=" + bias
      + "|regime=" + regime
      + "|dow=D" + IntegerToString(dow.day_of_week)
      + "|trades=" + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(InpMaxTradesPerDay);
}

void WriteRejectedTradesCSV()
{
   if(!InpEnableRejectedLog || g_rejCount == 0) return;
   
   string fn = "RejectedTrades_" + _Symbol + "_" + IntegerToString(InpMagicNumber) + ".csv";
   int fh = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) { Print("[REJECTED] FileOpen failed: ", fn); return; }
   
   FileWrite(fh, "No", "Time", "Direction", "ReasonCode", "CBCause", "Spread", "FreeMarginPct", "DailyDDPct",
             "ConsecLosses", "ErrorsInWindow", "Session", "Bias", "Regime", "DOW", "TradesUsed", "RawDetails");
   
   for(int i = 0; i < g_rejCount; i++)
   {
      string parts[];
      int nP = StringSplit(g_rejDetails[i], '|', parts);
      
      string spread = "NA", fmPct = "NA", ddPct = "NA", consec = "NA", errW = "NA";
      string cbCause = "NA", sess = "NA", bias = "NA", regime = "NA", dowS = "NA", trades = "NA";
      
      for(int p = 0; p < nP; p++)
      {
         if(StringFind(parts[p], "spread=") == 0) spread = StringSubstr(parts[p], 7);
         else if(StringFind(parts[p], "fmPct=") == 0) fmPct = StringSubstr(parts[p], 6);
         else if(StringFind(parts[p], "ddPct=") == 0) ddPct = StringSubstr(parts[p], 6);
         else if(StringFind(parts[p], "consec=") == 0) consec = StringSubstr(parts[p], 7);
         else if(StringFind(parts[p], "errWin=") == 0) errW = StringSubstr(parts[p], 7);
         else if(StringFind(parts[p], "cbCause=") == 0) cbCause = StringSubstr(parts[p], 8);
         else if(StringFind(parts[p], "sess=") == 0) sess = StringSubstr(parts[p], 5);
         else if(StringFind(parts[p], "bias=") == 0) bias = StringSubstr(parts[p], 5);
         else if(StringFind(parts[p], "regime=") == 0) regime = StringSubstr(parts[p], 7);
         else if(StringFind(parts[p], "dow=") == 0) dowS = StringSubstr(parts[p], 4);
         else if(StringFind(parts[p], "trades=") == 0) trades = StringSubstr(parts[p], 7);
      }
      
      FileWrite(fh, IntegerToString(i + 1),
         TimeToString(g_rejTimes[i], TIME_DATE | TIME_MINUTES),
         g_rejDirections[i], g_rejReasons[i], cbCause,
         spread, fmPct, ddPct, consec, errW,
         sess, bias, regime, dowS, trades,
         g_rejDetails[i]);
   }
   
   FileClose(fh);
   string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + fn;
   Print("[REJECTED] Saved ", g_rejCount, " rejected entries to: ", commonPath);
}

bool HasMyOpenPosition(const string symbol, ulong &ticketOut)
{
   ticketOut = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      ticketOut = t;
      return true;
   }
   return false;
}

bool SelectMyPositionByTicket(const ulong ticket)
{
   return PositionSelectByTicket(ticket);
}

bool CloseMyPositionByTicket(const ulong ticket, const string reasonCode)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) return false;

   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);

   for(int attempt = 0; attempt <= InpMaxRetries; attempt++)
   {
      if(attempt > 0)
      {
         int delay = InpRetryDelayMs * (1 << (attempt - 1));
         if(delay > 5000) delay = 5000;
         Print("[CLOSE] Retry ", attempt, "/", InpMaxRetries, " after ", delay, "ms...");
         Sleep(delay);
         if(!PositionSelectByTicket(ticket))
         {
            Print("[CLOSE] Position gone — likely closed by SL/TP");
            return true;
         }
      }

      if(trade.PositionClose(ticket))
      {
         LogBlock("[CLOSE_OK]", reasonCode + " ticket=" + IntegerToString(ticket));
         return true;
      }

      uint retcode = trade.ResultRetcode();
      ENUM_RETCODE_CLASS cls = ClassifyRetcode(retcode);
      Print("[CLOSE] Attempt ", attempt + 1, " failed | retcode=", retcode,
            " (", RetcodeDescription(retcode), ") class=", RetcodeClassToString(cls));

      if(cls != RETCODE_RETRY || attempt >= InpMaxRetries)
      {
         LogBlock("[CLOSE_FAIL]", reasonCode
            + " retcode=" + IntegerToString(retcode)
            + " " + RetcodeDescription(retcode));
         RegisterExecutionError(retcode);
         return false;
      }
   }
   return false;
}

void DisableTrading(const string causeCode)
{
   if(g_tradingDisabled) return;
   g_tradingDisabled = true;
   g_cbLastReason = causeCode;
   LogBlock("[CB_TRIGGERED]", causeCode + " consec=" + IntegerToString(g_consecutiveLosses) + " errWin=" + IntegerToString(CountExecErrorsInWindow()));
   SavePersistentState();
}

void CircuitBreakerNewBrokerDay()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   int key = t.year * 1000 + t.day_of_year;
   if(key == g_cbDayKey)
      return;
   g_cbDayKey = key;
   g_cbDayStart = TimeCurrent();
   g_cbStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_consecutiveLosses = 0;
   ArrayResize(g_errorTimes, 0);
   g_tradingDisabled = false;
   g_cbLastReason = "";
   SavePersistentState();
}

void RegisterExecutionError(const uint retcode)
{
   int sz = ArraySize(g_errorTimes);
   ArrayResize(g_errorTimes, sz + 1);
   g_errorTimes[sz] = TimeCurrent();
   int cnt = CountExecErrorsInWindow();
   LogBlock("[EXEC_FAIL]", "retcode=" + IntegerToString((int)retcode) + " win=" + IntegerToString(cnt));
   if(!InpEnableCircuitBreaker || InpMaxTradeErrorsInWindow <= 0) return;
   if(cnt >= InpMaxTradeErrorsInWindow)
      DisableTrading("[CB_ERROR_RATE]");
}

void EvaluateCircuitBreakerFromTick()
{
   if(!InpEnableCircuitBreaker || g_tradingDisabled) return;
   EvaluateCircuitBreakerDailyLoss();
   if(InpMaxConsecutiveLosses > 0 && g_consecutiveLosses >= InpMaxConsecutiveLosses)
      DisableTrading("[CB_CONSEC_LOSSES]");
   if(InpMaxTradeErrorsInWindow > 0 && CountExecErrorsInWindow() >= InpMaxTradeErrorsInWindow)
      DisableTrading("[CB_ERROR_RATE]");
}

void EvaluateCircuitBreakerDailyLoss()
{
   if(!InpEnableCircuitBreaker || g_tradingDisabled) return;
   if(g_cbStartEquity <= 0) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddp = (g_cbStartEquity - eq) / g_cbStartEquity * 100.0;
   if(InpMaxDailyLossPct > 0.0 && ddp >= InpMaxDailyLossPct)
      DisableTrading("[CB_DAILY_LOSS]");
}

void ProcessManualCircuitBreakerReset()
{
   static bool s_prevManualCB = false;
   if(InpManualResetCB && !s_prevManualCB)
   {
      g_tradingDisabled = false;
      g_cbLastReason = "";
      g_consecutiveLosses = 0;
      ArrayResize(g_errorTimes, 0);
      g_cbStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      LogBlock("[CB_RESET]", "Circuit breaker reset by user. Set InpManualResetCB back to false.");
      SavePersistentState();
   }
   s_prevManualCB = InpManualResetCB;
}

bool PreTradeValidate(string &reasonCode)
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) { reasonCode = "[BLOCK_TRADE_NOT_ALLOWED]"; return false; }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) { reasonCode = "[BLOCK_TRADE_NOT_ALLOWED]"; return false; }
   if(!InpEnableTrading) { reasonCode = "[BLOCK_TRADE_NOT_ALLOWED]"; return false; }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
   { reasonCode = "[BLOCK_SYMBOL_DISABLED]"; return false; }
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.ask <= 0 || tk.bid <= 0)
   { reasonCode = "[BLOCK_NO_TICK]"; return false; }
   if(iBars(_Symbol, PERIOD_M15) < InpATRPeriod + 2 || iBars(_Symbol, PERIOD_D1) < 3)
   { reasonCode = "[BLOCK_DATA]"; return false; }
   if(g_atrHandle == INVALID_HANDLE) { reasonCode = "[BLOCK_DATA]"; return false; }
   double atrProbe[];
   ArraySetAsSeries(atrProbe, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrProbe) < 1 || atrProbe[0] <= 0.0)
   { reasonCode = "[BLOCK_DATA]"; return false; }
   if(!IsSpreadOK()) { reasonCode = "[BLOCK_SPREAD]"; return false; }
   if(!IsATRSpikeOK()) { reasonCode = "[BLOCK_ATR_SPIKE]"; return false; }
   if(InpMinFreeMarginPct > 0.0)
   {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(eq <= 0.0 || (fm / eq) * 100.0 < InpMinFreeMarginPct)
      { reasonCode = "[BLOCK_MARGIN]"; return false; }
   }
   reasonCode = "";
   return true;
}

bool ValidateStops(const double price, const double sl, const double tp, const ENUM_ORDER_TYPE otype, string &reasonCode)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) { reasonCode = "[BLOCK_STOPSLEVEL]"; return false; }
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int minPts = MathMax(stopsLevel, freezeLevel);
   if(minPts <= 0) { reasonCode = ""; return true; }
   double dmin = minPts * point;
   if(otype == ORDER_TYPE_BUY)
   {
      if(MathAbs(price - sl) < dmin - 1e-12 || MathAbs(tp - price) < dmin - 1e-12)
      { reasonCode = "[BLOCK_STOPSLEVEL]"; return false; }
   }
   else
   {
      if(MathAbs(sl - price) < dmin - 1e-12 || MathAbs(price - tp) < dmin - 1e-12)
      { reasonCode = "[BLOCK_STOPSLEVEL]"; return false; }
   }
   reasonCode = "";
   return true;
}

int CountMySymbolPositions(const string symbol, double &sumLots)
{
   sumLots = 0.0;
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      c++;
      sumLots += PositionGetDouble(POSITION_VOLUME);
   }
   return c;
}

bool CheckExposureLimits(const double newOrderLots, string &reasonCode)
{
   double sumLots = 0.0;
   int cnt = CountMySymbolPositions(_Symbol, sumLots);
   if(InpMaxPositionsPerSymbol > 0 && cnt >= InpMaxPositionsPerSymbol)
   { reasonCode = "[BLOCK_EXPOSURE_POS]"; return false; }
   if(InpMaxTotalLotsPerSymbol > 0.0 && sumLots + newOrderLots > InpMaxTotalLotsPerSymbol + 1e-8)
   { reasonCode = "[BLOCK_EXPOSURE_LOTS]"; return false; }
   if(InpMaxMarginUsagePct > 0.0)
   {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double mg = AccountInfoDouble(ACCOUNT_MARGIN);
      if(eq > 0.0 && (mg / eq) * 100.0 > InpMaxMarginUsagePct)
      { reasonCode = "[BLOCK_EXPOSURE_MARGIN]"; return false; }
   }
   reasonCode = "";
   return true;
}

//+------------------------------------------------------------------+
//| EXECUTION HARDENING — Retcode Classification & Retry Logic       |
//+------------------------------------------------------------------+
enum ENUM_RETCODE_CLASS
{
   RETCODE_SUCCESS = 0,
   RETCODE_RETRY   = 1,
   RETCODE_MARKET  = 2,
   RETCODE_FATAL   = 3,
   RETCODE_BROKER  = 4
};

ENUM_RETCODE_CLASS ClassifyRetcode(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE:
      case TRADE_RETCODE_PLACED:
      case TRADE_RETCODE_DONE_PARTIAL:
         return RETCODE_SUCCESS;

      case TRADE_RETCODE_REQUOTE:
      case TRADE_RETCODE_TIMEOUT:
      case TRADE_RETCODE_PRICE_CHANGED:
      case TRADE_RETCODE_PRICE_OFF:
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
      case TRADE_RETCODE_LOCKED:
      case TRADE_RETCODE_CONNECTION:
         return RETCODE_RETRY;

      case TRADE_RETCODE_MARKET_CLOSED:
      case TRADE_RETCODE_SERVER_DISABLES_AT:
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
      case TRADE_RETCODE_FROZEN:
         return RETCODE_MARKET;

      case TRADE_RETCODE_REJECT:
      case TRADE_RETCODE_CANCEL:
      case TRADE_RETCODE_ERROR:
      case TRADE_RETCODE_REJECT_CANCEL:
         return RETCODE_BROKER;

      default:
         return RETCODE_FATAL;
   }
}

string RetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:            return "Requote";
      case TRADE_RETCODE_REJECT:             return "Rejected by dealer";
      case TRADE_RETCODE_CANCEL:             return "Canceled by dealer";
      case TRADE_RETCODE_DONE:               return "Done";
      case TRADE_RETCODE_DONE_PARTIAL:       return "Partial fill";
      case TRADE_RETCODE_ERROR:              return "General error";
      case TRADE_RETCODE_TIMEOUT:            return "Timeout";
      case TRADE_RETCODE_INVALID:            return "Invalid request";
      case TRADE_RETCODE_INVALID_VOLUME:     return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE:      return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS:      return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED:     return "Trade disabled";
      case TRADE_RETCODE_MARKET_CLOSED:      return "Market closed";
      case TRADE_RETCODE_NO_MONEY:           return "Not enough money";
      case TRADE_RETCODE_PRICE_CHANGED:      return "Price changed";
      case TRADE_RETCODE_PRICE_OFF:          return "Off quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:  return "Too many requests";
      case TRADE_RETCODE_SERVER_DISABLES_AT: return "Server disabled autotrading";
      case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Client disabled autotrading";
      case TRADE_RETCODE_LOCKED:             return "Locked";
      case TRADE_RETCODE_FROZEN:             return "Frozen";
      case TRADE_RETCODE_INVALID_FILL:       return "Invalid fill policy";
      case TRADE_RETCODE_CONNECTION:         return "No connection";
      case TRADE_RETCODE_LIMIT_ORDERS:       return "Limit orders exceeded";
      case TRADE_RETCODE_LIMIT_VOLUME:       return "Limit volume exceeded";
      case TRADE_RETCODE_LIMIT_POSITIONS:    return "Limit positions exceeded";
      case TRADE_RETCODE_REJECT_CANCEL:      return "Reject cancel";
      case TRADE_RETCODE_LONG_ONLY:          return "Long only allowed";
      case TRADE_RETCODE_SHORT_ONLY:         return "Short only allowed";
      case TRADE_RETCODE_CLOSE_ONLY:         return "Close only allowed";
      default:                               return "Unknown (" + IntegerToString(retcode) + ")";
   }
}

string RetcodeClassToString(ENUM_RETCODE_CLASS cls)
{
   switch(cls)
   {
      case RETCODE_SUCCESS: return "SUCCESS";
      case RETCODE_RETRY:   return "RETRY";
      case RETCODE_MARKET:  return "MARKET";
      case RETCODE_FATAL:   return "FATAL";
      case RETCODE_BROKER:  return "BROKER";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Pre-trade: projected margin check via OrderCalcMargin            |
//+------------------------------------------------------------------+
bool CheckProjectedMargin(double lots, ENUM_ORDER_TYPE otype, string &reasonCode)
{
   if(InpProjectedMarginPct <= 0.0) { reasonCode = ""; return true; }

   double marginRequired = 0;
   double price = (otype == ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!OrderCalcMargin(otype, _Symbol, lots, price, marginRequired))
   {
      LogBlock("[BLOCK_MARGIN_CALC]", "OrderCalcMargin failed err=" + IntegerToString(GetLastError()));
      reasonCode = "[BLOCK_MARGIN_CALC]";
      return false;
   }

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double projFree   = freeMargin - marginRequired;

   if(equity <= 0.0) { reasonCode = "[BLOCK_MARGIN_PROJ]"; return false; }

   double projFreePct = projFree / equity * 100.0;
   if(projFreePct < InpProjectedMarginPct)
   {
      LogBlock("[BLOCK_MARGIN_PROJ]",
         "projected=" + DoubleToString(projFreePct, 1) + "% < min " + DoubleToString(InpProjectedMarginPct, 1) + "%"
         + " | required=" + DoubleToString(marginRequired, 2)
         + " free=" + DoubleToString(freeMargin, 2));
      reasonCode = "[BLOCK_MARGIN_PROJ]";
      return false;
   }
   reasonCode = "";
   return true;
}

//+------------------------------------------------------------------+
//| Execute order with classified retry logic                        |
//+------------------------------------------------------------------+
bool ExecuteOrderWithRetry(MqlTradeRequest &request, MqlTradeResult &result,
                           int maxRetries, const string dirStr)
{
   for(int attempt = 0; attempt <= maxRetries; attempt++)
   {
      if(attempt > 0)
      {
         int delay = InpRetryDelayMs * (1 << (attempt - 1));
         if(delay > 5000) delay = 5000;
         Print("[EXEC] Retry ", attempt, "/", maxRetries, " after ", delay, "ms...");
         Sleep(delay);

         double freshPrice = (request.type == ORDER_TYPE_BUY)
                             ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(freshPrice <= 0)
         {
            Print("[EXEC] No valid price for retry — aborting");
            return false;
         }
         request.price = freshPrice;

         if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
         {
            Print("[EXEC] Trading no longer allowed — aborting retries");
            return false;
         }
      }

      ZeroMemory(result);
      bool sent = OrderSend(request, result);
      if(!sent)
      {
         uint sendErr = (uint)GetLastError();
         Print("[EXEC] OrderSend API failure | err=", sendErr);
         RegisterExecutionError(sendErr);
         RecordRejectedTrade("[EXEC_API_FAIL]", dirStr,
            "err=" + IntegerToString((int)sendErr) + "|" + BuildRejectedDetails());
         return false;
      }

      ENUM_RETCODE_CLASS cls = ClassifyRetcode(result.retcode);

      if(cls == RETCODE_SUCCESS)
      {
         if(attempt > 0)
            Print("[EXEC] Succeeded on attempt ", attempt + 1);
         return true;
      }

      Print("[EXEC] Attempt ", attempt + 1, "/", maxRetries + 1,
            " | retcode=", result.retcode,
            " (", RetcodeDescription(result.retcode), ")"
            " class=", RetcodeClassToString(cls));

      if(cls == RETCODE_RETRY && attempt < maxRetries)
         continue;

      if(cls == RETCODE_FATAL)
         Print("[EXEC] FATAL — ", RetcodeDescription(result.retcode), " — will not retry");
      else if(cls == RETCODE_MARKET)
         Print("[EXEC] MARKET — ", RetcodeDescription(result.retcode), " — will not retry");
      else if(cls == RETCODE_BROKER)
         Print("[EXEC] BROKER — ", RetcodeDescription(result.retcode), " — will not retry");
      else
         Print("[EXEC] Retries exhausted (", maxRetries, ")");

      RegisterExecutionError(result.retcode);
      RecordRejectedTrade("[EXEC_" + RetcodeClassToString(cls) + "]", dirStr,
         "retcode=" + IntegerToString((int)result.retcode)
         + " desc=" + RetcodeDescription(result.retcode)
         + "|" + BuildRejectedDetails());
      return false;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Post-trade verification: position, fill, slippage enforcement    |
//+------------------------------------------------------------------+
bool PostTradeVerify(const MqlTradeResult &result, const MqlTradeRequest &request,
                     const string dirStr)
{
   if(result.order == 0)
   {
      Print("[VERIFY] WARNING: Order ticket=0 despite success retcode");
      return false;
   }

   Sleep(50);
   ulong posTicket = 0;
   if(!HasMyOpenPosition(_Symbol, posTicket))
   {
      Sleep(200);
      if(!HasMyOpenPosition(_Symbol, posTicket))
      {
         Print("[VERIFY] WARNING: Position not found after OrderSend | order=", result.order);
         return false;
      }
   }

   if(!PositionSelectByTicket(posTicket))
   {
      Print("[VERIFY] WARNING: Cannot select position ticket=", posTicket);
      return false;
   }

   double fillPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
   double fillVolume = PositionGetDouble(POSITION_VOLUME);
   double fillSL     = PositionGetDouble(POSITION_SL);
   double fillTP     = PositionGetDouble(POSITION_TP);
   int    digits     = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   Print("[VERIFY] Position confirmed | ticket=", posTicket,
         " price=", DoubleToString(fillPrice, digits),
         " vol=", DoubleToString(fillVolume, 2),
         " SL=", DoubleToString(fillSL, digits),
         " TP=", DoubleToString(fillTP, digits));

   if(MathAbs(fillVolume - request.volume) > 0.001)
      Print("[VERIFY] Volume mismatch: requested=", DoubleToString(request.volume, 2),
            " filled=", DoubleToString(fillVolume, 2));

   if(MathAbs(fillSL - request.sl) > _Point * 2)
      Print("[VERIFY] SL mismatch: requested=", DoubleToString(request.sl, digits),
            " actual=", DoubleToString(fillSL, digits));
   if(MathAbs(fillTP - request.tp) > _Point * 2)
      Print("[VERIFY] TP mismatch: requested=", DoubleToString(request.tp, digits),
            " actual=", DoubleToString(fillTP, digits));

   double slippagePts = MathAbs(fillPrice - request.price) / _Point;
   if(slippagePts > 0.5)
      Print("[VERIFY] Slippage: ", DoubleToString(slippagePts, 1), " pts"
            " | requested=", DoubleToString(request.price, digits),
            " filled=", DoubleToString(fillPrice, digits));

   if(InpMaxSlippagePoints > 0 && slippagePts > InpMaxSlippagePoints)
   {
      Print("[VERIFY] SLIPPAGE EXCEEDED: ", DoubleToString(slippagePts, 1),
            " > max ", InpMaxSlippagePoints, " pts");

      if(InpEnforceSlippage)
      {
         Print("[VERIFY] Enforcing slippage limit — closing position");
         if(CloseMyPositionByTicket(posTicket, "[SLIPPAGE_ENFORCE]"))
         {
            Print("[VERIFY] Position closed due to excessive slippage");
            return false;
         }
         Print("[VERIFY] WARNING: Close failed — position remains open despite slippage");
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get current volatility regime (LV/MV/HV) for analysis             |
//| Uses ATR percentile: bottom 33% = Low, middle 33% = Medium, top 33% = High |
//+------------------------------------------------------------------+
string GetVolatilityRegime()
{
   if(!InpEnableRegimeAnalysis || InpRegimeLookback < 10)
      return "MV";
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   int barsNeeded = InpRegimeLookback + 1;
   if(CopyBuffer(g_atrHandle, 0, 0, barsNeeded, atrBuffer) < barsNeeded)
      return "MV";
   
   double currentATR = atrBuffer[0];
   double sorted[];
   ArrayResize(sorted, InpRegimeLookback);
   for(int i = 0; i < InpRegimeLookback; i++)
      sorted[i] = atrBuffer[i + 1];
   
   ArraySort(sorted);
   int rank = 0;
   for(int i = 0; i < InpRegimeLookback; i++)
   {
      if(currentATR <= sorted[i])
      {
         rank = i;
         break;
      }
      rank = i + 1;
   }
   double percentile = (double)rank / InpRegimeLookback * 100.0;
   
   if(percentile < 33.33)
      return "LV";
   if(percentile > 66.66)
      return "HV";
   return "MV";
}

//+------------------------------------------------------------------+
//| Check daily trade limit                                          |
//+------------------------------------------------------------------+
bool CheckDailyTradeLimit()
{
   if(InpMaxTradesPerDay <= 0)
      return true;

   datetime currentTime = TimeCurrent();
   MqlDateTime currentDate;
   TimeToStruct(currentTime, currentDate);
   
   datetime todayStart = StructToTime(currentDate) - (currentDate.hour * 3600 + currentDate.min * 60 + currentDate.sec);
   
   if(g_lastTradeDate < todayStart)
   {
      g_dailyTradeCount = 0;
      g_lastTradeDate = todayStart;
      Print("=== NEW TRADING DAY - Trade limit reset: ", InpMaxTradesPerDay, " trades ===");
   }
   
   if(g_dailyTradeCount >= InpMaxTradesPerDay)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Increment daily trade counter                                    |
//+------------------------------------------------------------------+
void IncrementDailyTradeCount()
{
   g_dailyTradeCount++;
   Print("=== Trade ", g_dailyTradeCount, "/", InpMaxTradesPerDay, " executed today ===");
   
   if(g_dailyTradeCount >= InpMaxTradesPerDay)
      Print("Daily trade limit reached. No more trades today.");
   SavePersistentState();
}

//+------------------------------------------------------------------+
//| Update Fibonacci levels and drawings                             |
//+------------------------------------------------------------------+
void UpdateFibonacci()
{
   int bars = Bars(_Symbol, PERIOD_CURRENT);
   if(bars < 2) return;
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int copied_high = CopyHigh(_Symbol, PERIOD_CURRENT, 0, bars, high);
   int copied_low = CopyLow(_Symbol, PERIOD_CURRENT, 0, bars, low);
   int copied_close = CopyClose(_Symbol, PERIOD_CURRENT, 0, bars, close);
   
   if(copied_high < 2 || copied_low < 2 || copied_close < 2) return;
   
   DeleteAllObjects();
   
   CalculateEffectivePeriod();
   FindHighLow(bars, high, low);
   DrawFibonacci(bars, close);
   DrawLabels(close);
   
   if(InpShowCurrentFib)
      ShowCurrentFibLevel(close);
   
   DrawSwingMarkers();
   
   if(InpShowFVG)
      DrawFVGs(bars, high, low);
   
   if(g_hasActiveFVG)
      DrawActiveFVG();
   
   DrawStatusDisplay();
}

//+------------------------------------------------------------------+
//| Calculate effective lookback period                              |
//+------------------------------------------------------------------+
void CalculateEffectivePeriod()
{
   if(InpLookbackType == LOOKBACK_DAYS)
   {
      int periodMinutes = PeriodSeconds() / 60;
      
      if(periodMinutes < 1440)
      {
         g_effectivePeriod = (1440 / periodMinutes) * InpLookbackPeriod;
      }
      else if(periodMinutes == 1440)
      {
         g_effectivePeriod = InpLookbackPeriod;
      }
      else if(periodMinutes == 10080)
      {
         g_effectivePeriod = InpLookbackPeriod / 7;
      }
      else if(periodMinutes == 43200)
      {
         g_effectivePeriod = InpLookbackPeriod / 28;
      }
      else
      {
         g_effectivePeriod = InpLookbackPeriod;
      }
   }
   else
   {
      g_effectivePeriod = InpLookbackPeriod;
   }
   
   if(g_effectivePeriod < 2)
      g_effectivePeriod = 2;
}

//+------------------------------------------------------------------+
//| Update H4 swing points                                           |
//+------------------------------------------------------------------+
void UpdateH4Structure()
{
   double h4High[], h4Low[];
   ArraySetAsSeries(h4High, true);
   ArraySetAsSeries(h4Low, true);
   
   int bars = Bars(_Symbol, PERIOD_H4);
   if(bars < InpLookbackPeriod) return;
   
   int copied_high = CopyHigh(_Symbol, PERIOD_H4, 0, InpLookbackPeriod + 10, h4High);
   int copied_low = CopyLow(_Symbol, PERIOD_H4, 0, InpLookbackPeriod + 10, h4Low);
   
   if(copied_high < InpLookbackPeriod || copied_low < InpLookbackPeriod) return;
   
   g_fhigh = h4High[0];
   g_flow = h4Low[0];
   g_highBar = 0;
   g_lowBar = 0;
   
   for(int i = 0; i < InpLookbackPeriod; i++)
   {
      if(h4High[i] > g_fhigh)
      {
         g_fhigh = h4High[i];
         g_highBar = i;
      }
      
      if(h4Low[i] < g_flow)
      {
         g_flow = h4Low[i];
         g_lowBar = i;
      }
   }
   
   g_revfibs = (g_highBar < g_lowBar);
   
   Print("=== H4 STRUCTURE UPDATE ===");
   Print("Swing High: ", g_fhigh, " at bar ", g_highBar);
   Print("Swing Low: ", g_flow, " at bar ", g_lowBar);
   Print("Trend: ", g_revfibs ? "BULLISH (retracing from Low)" : "BEARISH (retracing from High)");
   
   ClearSetupState(false);
   SavePersistentState();
}

//+------------------------------------------------------------------+
//| Find swing high and low                                          |
//+------------------------------------------------------------------+
void FindHighLow(int bars, const double &high[], const double &low[])
{
   if(InpFibPlotType == PLOT_LOOKBACK)
   {
      int lookback = MathMin(g_effectivePeriod, bars - 1);
      if(lookback < 2)
         lookback = MathMin(2, bars - 1);
      if(lookback < 1)
         return;

      g_fhigh = high[1];
      g_flow = low[1];
      g_highBar = 1;
      g_lowBar = 1;

      for(int i = 1; i <= lookback; i++)
      {
         if(high[i] > g_fhigh)
         {
            g_fhigh = high[i];
            g_highBar = i;
         }
         if(low[i] < g_flow)
         {
            g_flow = low[i];
            g_lowBar = i;
         }
      }

      if(!InpReverseFibs)
         g_revfibs = (g_highBar < g_lowBar);
      else
         g_revfibs = (g_highBar > g_lowBar);
   }
   else
   {
      if(InpHighPrice == 0.0)
      {
         int lookback = MathMin(100, bars);
         g_fhigh = high[0];
         for(int i = 0; i < lookback; i++)
         {
            if(high[i] > g_fhigh)
               g_fhigh = high[i];
         }
      }
      else
      {
         g_fhigh = InpHighPrice;
      }
      
      if(InpLowPrice == -1.0)
      {
         int lookback = MathMin(100, bars);
         g_flow = low[0];
         for(int i = 0; i < lookback; i++)
         {
            if(low[i] < g_flow)
               g_flow = low[i];
         }
      }
      else
      {
         g_flow = InpLowPrice;
      }
      
      g_highBar = 1;
      g_lowBar = 2;
      
      if(!InpReverseFibs)
         g_revfibs = (g_lowBar > g_highBar);
      else
         g_revfibs = (g_lowBar < g_highBar);
   }
}

//+------------------------------------------------------------------+
//| Calculate price at given Fibonacci level                         |
//+------------------------------------------------------------------+
double CalculateFibPrice(double level)
{
   if(g_revfibs)
   {
      return g_flow + (g_fhigh - g_flow) * level;
   }
   else
   {
      return g_fhigh - (g_fhigh - g_flow) * level;
   }
}

//+------------------------------------------------------------------+
//| Draw a single Fibonacci line                                     |
//+------------------------------------------------------------------+
void DrawFibLine(string name, double price, int bars, const double &close[])
{
   color lineColor = (close[0] > price) ? InpBullColor : InpBearColor;
   ENUM_LINE_STYLE lineStyle = (InpLineStyle == LINE_STYLE_DOTTED) ? STYLE_DOT : STYLE_SOLID;
   
   int startBarIdx;
   if(InpFibPlotType == PLOT_LOOKBACK)
   {
      startBarIdx = (g_lowBar < g_highBar) ? g_lowBar : g_highBar;
   }
   else
   {
      startBarIdx = MathMin(50, bars - 1);
   }
   
   datetime startTime = iTime(_Symbol, PERIOD_CURRENT, startBarIdx);
   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   string objName = g_objectPrefix + name;
   ObjectCreate(0, objName, OBJ_TREND, 0, startTime, price, endTime, price);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, lineStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpLineWidth);
   ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, InpExtendLeft);
   ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw a single Fibonacci label                                    |
//+------------------------------------------------------------------+
void DrawFibLabel(string name, double price, string levelText, const double &close[])
{
   color labelColor = (close[0] > price) ? InpBullColor : InpBearColor;
   datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   string objName = g_objectPrefix + "Label_" + name;
   string labelText = levelText + " ( " + DoubleToString(price, _Digits) + " )";
   
   ObjectCreate(0, objName, OBJ_TEXT, 0, labelTime, price);
   ObjectSetString(0, objName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, labelColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw all Fibonacci retracement levels                            |
//+------------------------------------------------------------------+
void DrawFibonacci(int bars, const double &close[])
{
   if(InpShowFib0)
      DrawFibLine("Fib0", CalculateFibPrice(0.000), bars, close);
   
   if(InpShowFib236)
      DrawFibLine("Fib236", CalculateFibPrice(0.236), bars, close);
   
   if(InpShowFib382)
      DrawFibLine("Fib382", CalculateFibPrice(0.382), bars, close);
   
   if(InpShowFib500)
      DrawFibLine("Fib500", CalculateFibPrice(0.500), bars, close);
   
   if(InpShowFib618)
      DrawFibLine("Fib618", CalculateFibPrice(0.618), bars, close);
   
   if(InpShowFib786)
      DrawFibLine("Fib786", CalculateFibPrice(0.786), bars, close);
   
   if(InpShowFib1000)
      DrawFibLine("Fib1000", CalculateFibPrice(1.000), bars, close);
   
   if(InpShowExtraFibs && InpShowFib886)
   {
      DrawFibLine("Fib886", CalculateFibPrice(0.886), bars, close);
   }
   
   if(InpFibPlotType == PLOT_PRICE_INPUT)
   {
      if(InpShowExtraFibs && InpShowFib1113)
      {
         DrawFibLine("Fib1113", CalculateFibPrice(1.113), bars, close);
      }
      
      if(InpShowFib1272)
         DrawFibLine("Fib1272", CalculateFibPrice(1.272), bars, close);
      
      if(InpShowFib1618)
         DrawFibLine("Fib1618", CalculateFibPrice(1.618), bars, close);
      
      if(InpShowFib2000)
         DrawFibLine("Fib2000", CalculateFibPrice(2.000), bars, close);
      
      if(InpShowFib2236)
         DrawFibLine("Fib2236", CalculateFibPrice(2.236), bars, close);
      
      if(InpShowFib2618)
         DrawFibLine("Fib2618", CalculateFibPrice(2.618), bars, close);
      
      if(InpShowFib3236)
         DrawFibLine("Fib3236", CalculateFibPrice(3.236), bars, close);
      
      if(InpShowFib3618)
         DrawFibLine("Fib3618", CalculateFibPrice(3.618), bars, close);
      
      if(InpShowFib4236)
         DrawFibLine("Fib4236", CalculateFibPrice(4.236), bars, close);
      
      if(InpShowFib4618)
         DrawFibLine("Fib4618", CalculateFibPrice(4.618), bars, close);
   }
}

//+------------------------------------------------------------------+
//| Draw all Fibonacci labels                                        |
//+------------------------------------------------------------------+
void DrawLabels(const double &close[])
{
   if(InpShowFib0)
      DrawFibLabel("Fib0", CalculateFibPrice(0.000), "0", close);
   
   if(InpShowFib236)
      DrawFibLabel("Fib236", CalculateFibPrice(0.236), "0.236", close);
   
   if(InpShowFib382)
      DrawFibLabel("Fib382", CalculateFibPrice(0.382), "0.382", close);
   
   if(InpShowFib500)
      DrawFibLabel("Fib500", CalculateFibPrice(0.500), "0.500", close);
   
   if(InpShowFib618)
      DrawFibLabel("Fib618", CalculateFibPrice(0.618), "0.618", close);
   
   if(InpShowFib786)
      DrawFibLabel("Fib786", CalculateFibPrice(0.786), "0.786", close);
   
   if(InpShowFib1000)
      DrawFibLabel("Fib1000", CalculateFibPrice(1.000), "1.000", close);
   
   if(InpShowExtraFibs && InpShowFib886)
   {
      DrawFibLabel("Fib886", CalculateFibPrice(0.886), "0.886", close);
   }
   
   if(InpFibPlotType == PLOT_PRICE_INPUT)
   {
      if(InpShowExtraFibs && InpShowFib1113)
      {
         DrawFibLabel("Fib1113", CalculateFibPrice(1.113), "1.113", close);
      }
      
      if(InpShowFib1272)
         DrawFibLabel("Fib1272", CalculateFibPrice(1.272), "1.272", close);
      
      if(InpShowFib1618)
         DrawFibLabel("Fib1618", CalculateFibPrice(1.618), "1.618", close);
      
      if(InpShowFib2000)
         DrawFibLabel("Fib2000", CalculateFibPrice(2.000), "2.000", close);
      
      if(InpShowFib2236)
         DrawFibLabel("Fib2236", CalculateFibPrice(2.236), "2.236", close);
      
      if(InpShowFib2618)
         DrawFibLabel("Fib2618", CalculateFibPrice(2.618), "2.618", close);
      
      if(InpShowFib3236)
         DrawFibLabel("Fib3236", CalculateFibPrice(3.236), "3.236", close);
      
      if(InpShowFib3618)
         DrawFibLabel("Fib3618", CalculateFibPrice(3.618), "3.618", close);
      
      if(InpShowFib4236)
         DrawFibLabel("Fib4236", CalculateFibPrice(4.236), "4.236", close);
      
      if(InpShowFib4618)
         DrawFibLabel("Fib4618", CalculateFibPrice(4.618), "4.618", close);
   }
}

//+------------------------------------------------------------------+
//| Show current price's Fibonacci level                             |
//+------------------------------------------------------------------+
void ShowCurrentFibLevel(const double &close[])
{
   double currentPrice = close[0];
   double currentFibLevel;
   
   if(g_revfibs)
   {
      if(g_fhigh != g_flow)
         currentFibLevel = (currentPrice - g_flow) / (g_fhigh - g_flow);
      else
         currentFibLevel = 0;
   }
   else
   {
      if(g_fhigh != g_flow)
         currentFibLevel = (g_fhigh - currentPrice) / (g_fhigh - g_flow);
      else
         currentFibLevel = 0;
   }
   
   datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   string objName = g_objectPrefix + "CurrentFib";
   string labelText = DoubleToString(currentFibLevel, 2);
   
   ObjectCreate(0, objName, OBJ_TEXT, 0, labelTime, currentPrice);
   ObjectSetString(0, objName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, InpCurrentFibColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw swing high and low markers                                  |
//+------------------------------------------------------------------+
void DrawSwingMarkers()
{
   datetime highTime, lowTime;
   
   if(InpFibPlotType == PLOT_LOOKBACK)
   {
      highTime = iTime(_Symbol, PERIOD_CURRENT, g_highBar);
      lowTime = iTime(_Symbol, PERIOD_CURRENT, g_lowBar);
   }
   else
   {
      highTime = iTime(_Symbol, PERIOD_CURRENT, 50);
      lowTime = iTime(_Symbol, PERIOD_CURRENT, 50);
   }
   
   string highArrowName = g_objectPrefix + "HighArrow";
   ObjectCreate(0, highArrowName, OBJ_ARROW_DOWN, 0, highTime, g_fhigh);
   ObjectSetInteger(0, highArrowName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, highArrowName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, highArrowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, highArrowName, OBJPROP_SELECTABLE, false);
   
   string highLabelName = g_objectPrefix + "HighLabel";
   ObjectCreate(0, highLabelName, OBJ_TEXT, 0, highTime, g_fhigh);
   ObjectSetString(0, highLabelName, OBJPROP_TEXT, "  SWING HIGH");
   ObjectSetInteger(0, highLabelName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, highLabelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, highLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, highLabelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, highLabelName, OBJPROP_SELECTABLE, false);
   
   string lowArrowName = g_objectPrefix + "LowArrow";
   ObjectCreate(0, lowArrowName, OBJ_ARROW_UP, 0, lowTime, g_flow);
   ObjectSetInteger(0, lowArrowName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, lowArrowName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, lowArrowName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lowArrowName, OBJPROP_SELECTABLE, false);
   
   string lowLabelName = g_objectPrefix + "LowLabel";
   ObjectCreate(0, lowLabelName, OBJ_TEXT, 0, lowTime, g_flow);
   ObjectSetString(0, lowLabelName, OBJPROP_TEXT, "  SWING LOW");
   ObjectSetInteger(0, lowLabelName, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, lowLabelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, lowLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, lowLabelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lowLabelName, OBJPROP_SELECTABLE, false);
   
   string directionName = g_objectPrefix + "Direction";
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double midPrice = (g_fhigh + g_flow) / 2;
   
   string directionText;
   color directionColor;
   
   if(g_revfibs)
   {
      directionText = "UPTREND (Low -> High)";
      directionColor = clrLime;
   }
   else
   {
      directionText = "DOWNTREND (High -> Low)";
      directionColor = clrRed;
   }
   
   ObjectCreate(0, directionName, OBJ_TEXT, 0, currentTime, midPrice);
   ObjectSetString(0, directionName, OBJPROP_TEXT, directionText);
   ObjectSetInteger(0, directionName, OBJPROP_COLOR, directionColor);
   ObjectSetInteger(0, directionName, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, directionName, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, directionName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   ObjectSetInteger(0, directionName, OBJPROP_BACK, false);
   ObjectSetInteger(0, directionName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw Fair Value Gaps within Fibonacci zone                       |
//+------------------------------------------------------------------+
void DrawFVGs(int bars, const double &high[], const double &low[])
{
   if(bars < 10) return;
   
   color bullColor = InpBullishFVGColor;
   color bearColor = InpBearishFVGColor;
   
   double fibHigh = MathMax(g_fhigh, g_flow);
   double fibLow = MathMin(g_fhigh, g_flow);
   
   int lookback = MathMin(InpFVGLookback, bars - 4);
   
   for(int i = 1; i <= lookback; i++)
   {
      int candleA = i + 2;
      int candleC = i;
      
      if(candleA >= bars) continue;
      
      if(high[candleA] < low[candleC])
      {
         double gapTop = low[candleC];
         double gapBottom = high[candleA];
         
         if(gapTop <= fibHigh && gapBottom >= fibLow)
         {
            bool filled = false;
            for(int j = i - 1; j >= 1; j--)
            {
               if(low[j] <= gapTop)
               {
                  filled = true;
                  break;
               }
            }
            
            if(!filled)
            {
               string name = g_objectPrefix + "FVG_B_" + IntegerToString(candleA);
               datetime t1 = iTime(_Symbol, PERIOD_CURRENT, candleA);
               datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0);
               
               ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, gapBottom, t2, gapTop);
               ObjectSetInteger(0, name, OBJPROP_COLOR, bullColor);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
               
            }
         }
      }
      
      if(low[candleA] > high[candleC])
      {
         double gapTop = low[candleA];
         double gapBottom = high[candleC];
         
         if(gapTop <= fibHigh && gapBottom >= fibLow)
         {
            bool filled = false;
            for(int j = i - 1; j >= 1; j--)
            {
               if(high[j] >= gapBottom)
               {
                  filled = true;
                  break;
               }
            }
            
            if(!filled)
            {
               string name = g_objectPrefix + "FVG_S_" + IntegerToString(candleA);
               datetime t1 = iTime(_Symbol, PERIOD_CURRENT, candleA);
               datetime t2 = iTime(_Symbol, PERIOD_CURRENT, 0);
               
               ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, gapBottom, t2, gapTop);
               ObjectSetInteger(0, name, OBJPROP_COLOR, bearColor);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
               
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Scan for valid FVG within H4 swing range                         |
//+------------------------------------------------------------------+
void CheckH4Setup()
{
   if(g_fhigh == 0 || g_flow == 0) return;
   
   double h4High[], h4Low[], h4Open[], h4Close[];
   ArraySetAsSeries(h4High, true);
   ArraySetAsSeries(h4Low, true);
   ArraySetAsSeries(h4Open, true);
   ArraySetAsSeries(h4Close, true);
   
   int bars = Bars(_Symbol, PERIOD_H4);
   if(bars < 50) return;
   
   int copied = CopyHigh(_Symbol, PERIOD_H4, 0, 50, h4High);
   CopyLow(_Symbol, PERIOD_H4, 0, 50, h4Low);
   CopyOpen(_Symbol, PERIOD_H4, 0, 50, h4Open);
   CopyClose(_Symbol, PERIOD_H4, 0, 50, h4Close);
   
   if(copied < 50) return;
   
   double fib50 = CalculateFibPrice(0.500);
   double fibHigh = MathMax(g_fhigh, g_flow);
   double fibLow = MathMin(g_fhigh, g_flow);
   
   for(int i = 1; i <= 30; i++)
   {
      int candleA = i + 2;
      int candleC = i;
      
      if(candleA >= 50) continue;
      
      if(g_revfibs)
      {
         if(g_currentBias != 1)
         {
            static bool printedBullishFilter = false;
            if(!printedBullishFilter)
            {
               Print("BULLISH SETUP FILTERED: Daily bias is ", 
                     g_currentBias == -1 ? "BEARISH" : "NEUTRAL", " - Bullish bias required");
               printedBullishFilter = true;
            }
            return;
         }
         
         if(h4High[candleA] < h4Low[candleC])
         {
            double gapTop = h4Low[candleC];
            double gapBottom = h4High[candleA];
            
            if(gapTop < fibLow || gapBottom > fibHigh) continue;
            
            bool entirelyBelow50 = (gapTop <= fib50);
            bool overlaps50 = (gapBottom < fib50 && gapTop > fib50);
            
            if(entirelyBelow50 || overlaps50)
            {
               bool filled = false;
               for(int j = i - 1; j >= 1; j--)
               {
                  double bodyLow = MathMin(h4Open[j], h4Close[j]);
                  if(bodyLow <= gapBottom)
                  {
                     filled = true;
                     break;
                  }
               }
               
               if(!filled)
               {
                  g_activeFVGTop = gapTop;
                  g_activeFVGBottom = gapBottom;
                  g_hasActiveFVG = true;
                  g_tradeDirection = 1;
                  g_fvgTime = iTime(_Symbol, PERIOD_H4, candleC);
                  g_waitingFor50Percent = overlaps50;
                  
                  Print("=== BULLISH SETUP FOUND ===");
                  Print("FVG: ", gapBottom, " - ", gapTop);
                  Print("50% level: ", fib50);
                  Print("Wait for: ", overlaps50 ? "50% touch" : "FVG touch");
                  SavePersistentState();
                  return;
               }
            }
         }
      }
      else
      {
         if(g_currentBias != -1)
         {
            static bool printedBearishFilter = false;
            if(!printedBearishFilter)
            {
               Print("BEARISH SETUP FILTERED: Daily bias is ", 
                     g_currentBias == 1 ? "BULLISH" : "NEUTRAL", " - Bearish bias required");
               printedBearishFilter = true;
            }
            return;
         }
         
         if(h4Low[candleA] > h4High[candleC])
         {
            double gapTop = h4Low[candleA];
            double gapBottom = h4High[candleC];
            
            if(gapTop > fibHigh || gapBottom < fibLow) continue;
            
            bool entirelyAbove50 = (gapBottom >= fib50);
            bool overlaps50 = (gapBottom < fib50 && gapTop > fib50);
            
            if(entirelyAbove50 || overlaps50)
            {
               bool filled = false;
               for(int j = i - 1; j >= 1; j--)
               {
                  double bodyHigh = MathMax(h4Open[j], h4Close[j]);
                  if(bodyHigh >= gapTop)
                  {
                     filled = true;
                     break;
                  }
               }
               
               if(!filled)
               {
                  g_activeFVGTop = gapTop;
                  g_activeFVGBottom = gapBottom;
                  g_hasActiveFVG = true;
                  g_tradeDirection = -1;
                  g_fvgTime = iTime(_Symbol, PERIOD_H4, candleC);
                  g_waitingFor50Percent = overlaps50;
                  
                  Print("=== BEARISH SETUP FOUND ===");
                  Print("FVG: ", gapBottom, " - ", gapTop);
                  Print("50% level: ", fib50);
                  Print("Wait for: ", overlaps50 ? "50% touch" : "FVG touch");
                  SavePersistentState();
                  return;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Validate active FVG hasn't been invalidated                      |
//+------------------------------------------------------------------+
void CheckFVGValidation()
{
   if(!g_hasActiveFVG) return;
   
   double h4High[], h4Low[], h4Open[], h4Close[];
   ArraySetAsSeries(h4High, true);
   ArraySetAsSeries(h4Low, true);
   ArraySetAsSeries(h4Open, true);
   ArraySetAsSeries(h4Close, true);
   
   int bars = Bars(_Symbol, PERIOD_H4);
   if(bars < 10) return;
   
   int copied = CopyHigh(_Symbol, PERIOD_H4, 0, 10, h4High);
   CopyLow(_Symbol, PERIOD_H4, 0, 10, h4Low);
   CopyOpen(_Symbol, PERIOD_H4, 0, 10, h4Open);
   CopyClose(_Symbol, PERIOD_H4, 0, 10, h4Close);
   
   if(copied < 10) return;
   
   for(int i = 0; i < 10; i++)
   {
      if(g_tradeDirection == 1)
      {
         double candleBody = MathMin(h4Open[i], h4Close[i]);
         if(candleBody <= g_activeFVGBottom)
         {
            Print("=== FVG INVALIDATED - Bullish FVG broken ===");
            
            ClearSetupState(true);
            SavePersistentState();
            return;
         }
      }
      else if(g_tradeDirection == -1)
      {
         double candleBody = MathMax(h4Open[i], h4Close[i]);
         if(candleBody >= g_activeFVGTop)
         {
            Print("=== FVG INVALIDATED - Bearish FVG broken ===");
            
            ClearSetupState(true);
            SavePersistentState();
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price touched FVG or 50% level                          |
//+------------------------------------------------------------------+
void CheckFVGTouch()
{
   if(!g_hasActiveFVG) return;
   
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   bool touched = false;
   
   if(g_waitingFor50Percent)
   {
      double fib50 = CalculateFibPrice(0.500);
      double tolerance = 10 * _Point;
      
      if(g_tradeDirection == 1)
      {
         if(currentLow <= (fib50 + tolerance) && currentHigh >= (fib50 - tolerance))
            touched = true;
      }
      else
      {
         if(currentHigh >= (fib50 - tolerance) && currentLow <= (fib50 + tolerance))
            touched = true;
      }
   }
   else
   {
      double tolerance = 100 * _Point;
      
      if(g_tradeDirection == 1)
      {
         if(currentLow <= g_activeFVGTop + tolerance && currentHigh >= g_activeFVGBottom)
            touched = true;
      }
      else
      {
         if(currentHigh >= g_activeFVGBottom - tolerance && currentLow <= g_activeFVGTop)
            touched = true;
      }
   }
   
   if(touched)
   {
      Print("=== ", g_waitingFor50Percent ? "50% LEVEL" : "FVG", " TOUCHED ===");
      Print("Direction: ", DirectionToString(g_tradeDirection));
      Print("Waiting for momentum entry on M15...");
      
      g_waitingForEntry = true;
      g_waitingFor50Percent = false;
      SavePersistentState();
   }
}

//+------------------------------------------------------------------+
//| Check for momentum entry on M15                                  |
//+------------------------------------------------------------------+
void CheckMomentumEntry()
{
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   
   int copied = CopyOpen(_Symbol, PERIOD_M15, 0, 3, open);
   CopyClose(_Symbol, PERIOD_M15, 0, 3, close);
   
   if(copied < 3) return;
   
   if(g_tradeDirection == 1)
   {
      bool candle1Bullish = close[1] > open[1];
      bool candle2Bullish = close[2] > open[2];
      
      if(candle1Bullish && candle2Bullish)
      {
         double body1 = close[1] - open[1];
         double body2 = close[2] - open[2];
         
         if(body1 >= body2 * 0.5)
         {
            string rc;
            if(!PreTradeValidate(rc))
            {
               LogBlock(rc, "momentum long");
               RecordRejectedTrade(rc, "LONG", BuildRejectedDetails());
               return;
            }
            
            Print("=== BULLISH MOMENTUM DETECTED ===");
            Print("Last closed body: ", body1, " | Previous closed body: ", body2);
            Print("Entering LONG trade...");
            
            if(EnterTrade(1))
            {
               ClearSetupState(false);
            }
            return;
         }
      }
   }
   else if(g_tradeDirection == -1)
   {
      bool candle1Bearish = close[1] < open[1];
      bool candle2Bearish = close[2] < open[2];
      
      if(candle1Bearish && candle2Bearish)
      {
         double body1 = open[1] - close[1];
         double body2 = open[2] - close[2];
         
         if(body1 >= body2 * 0.5)
         {
            string rc;
            if(!PreTradeValidate(rc))
            {
               LogBlock(rc, "momentum short");
               RecordRejectedTrade(rc, "SHORT", BuildRejectedDetails());
               return;
            }
            
            Print("=== BEARISH MOMENTUM DETECTED ===");
            Print("Last closed body: ", body1, " | Previous closed body: ", body2);
            Print("Entering SHORT trade...");
            
            if(EnterTrade(-1))
            {
               ClearSetupState(false);
            }
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(minLot <= 0.0)
      minLot = 0.01;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0 || slDistancePoints <= 0.0)
   {
      Print("[RISK] Invalid balance/SL distance. Using minimum lot: ", DoubleToString(minLot, 2));
      return minLot;
   }

   double riskAmount = balance * (InpRiskPercent / 100.0);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
   {
      Print("[RISK] Invalid symbol tick settings. Using minimum lot: ", DoubleToString(minLot, 2));
      return minLot;
   }
   
   double pointValuePerLot = (tickValue / tickSize) * point;
   if(pointValuePerLot <= 0.0)
   {
      Print("[RISK] Invalid point value per lot. Using minimum lot: ", DoubleToString(minLot, 2));
      return minLot;
   }
   double lotSize = riskAmount / (slDistancePoints * pointValuePerLot);
   
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lotStep <= 0) lotStep = 0.01;
   
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   
   double actualRisk = lotSize * slDistancePoints * pointValuePerLot;
   double actualRiskPercent = (actualRisk / balance) * 100.0;
   
   Print("=== LOT SIZE CALCULATION ===");
   Print("Balance: $", balance, " | Risk: ", InpRiskPercent, "% = $", riskAmount);
   Print("SL Distance: ", slDistancePoints, " points | Lot Size: ", lotSize);
   Print("Actual Risk: $", actualRisk, " (", actualRiskPercent, "%)");
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Execute trade with ATR-based SL and RR-based TP                  |
//+------------------------------------------------------------------+
bool EnterTrade(int direction)
{
   MqlTradeRequest request = {};
   MqlTradeResult  result  = {};

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   string dirStr = (direction == 1) ? "LONG" : "SHORT";
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) <= 0)
   {
      LogBlock("[BLOCK_DATA]", "ATR CopyBuffer err=" + IntegerToString(GetLastError()));
      RecordRejectedTrade("[BLOCK_DATA]", dirStr, BuildRejectedDetails());
      return false;
   }
   double atr = atrBuffer[0];

   double price = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = atr * InpATRMultiplier;
   double tpDistance = slDistance * InpRiskReward;

   double sl, tp;
   ENUM_ORDER_TYPE otype = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(direction == 1)  { sl = price - slDistance; tp = price + tpDistance; }
   else                { sl = price + slDistance; tp = price - tpDistance; }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistancePoints = MathAbs(price - sl) / point;
   double lotSize = CalculateLotSize(slDistancePoints);

   //--- Gate 1: Circuit Breaker ---
   if(InpEnableCircuitBreaker && g_tradingDisabled)
   {
      string cbCause = ResolveCBCause();
      if(g_cbLastReason == "" && cbCause != "NA" && cbCause != "[CB_UNKNOWN]")
         g_cbLastReason = cbCause;
      LogBlock(cbCause, "entry blocked (circuit breaker)");
      RecordRejectedTrade(cbCause, dirStr, BuildRejectedDetails());
      return false;
   }

   //--- Gate 2: Pre-trade validation (terminal, data, spread, ATR) ---
   string rc;
   if(!PreTradeValidate(rc))
   {
      LogBlock(rc, "enter");
      RecordRejectedTrade(rc, dirStr, BuildRejectedDetails());
      return false;
   }

   //--- Gate 3: Stop levels ---
   if(!ValidateStops(price, sl, tp, otype, rc))
   {
      LogBlock(rc, "stops");
      RecordRejectedTrade(rc, dirStr, BuildRejectedDetails());
      return false;
   }

   //--- Gate 4: Exposure limits ---
   if(!CheckExposureLimits(lotSize, rc))
   {
      LogBlock(rc, "exposure");
      RecordRejectedTrade(rc, dirStr, BuildRejectedDetails());
      return false;
   }

   //--- Gate 5: Projected margin (OrderCalcMargin) ---
   if(!CheckProjectedMargin(lotSize, otype, rc))
   {
      RecordRejectedTrade(rc, dirStr, BuildRejectedDetails());
      return false;
   }

   //--- Build request ---
   Print("=== EXECUTING TRADE ===");
   Print(dirStr, " | Price: ", price, " | SL: ", sl, " | TP: ", tp, " | Lots: ", lotSize);

   request.action    = TRADE_ACTION_DEAL;
   request.symbol    = _Symbol;
   request.volume    = lotSize;
   request.type      = otype;
   request.price     = price;
   request.sl        = sl;
   request.tp        = tp;
   request.deviation = (InpMaxSlippagePoints > 0) ? (ulong)InpMaxSlippagePoints : 20;
   request.magic     = InpMagicNumber;

   request.comment = BuildOrderComment(direction, atr, point);

   //--- Execute with classified retry logic ---
   if(!ExecuteOrderWithRetry(request, result, InpMaxRetries, dirStr))
      return false;

   Print("[EXEC] OrderSend OK | retcode=", result.retcode,
         " (", RetcodeDescription(result.retcode), ") ticket=", result.order);

   //--- Post-trade verification: position, fill, slippage enforcement ---
   bool verified = PostTradeVerify(result, request, dirStr);

   if(!verified)
   {
      ulong posCheck = 0;
      if(!HasMyOpenPosition(_Symbol, posCheck))
      {
         Print("[EXEC] Position was closed (slippage enforcement or fill issue) — aborting");
         ClearSetupState(true);
         SavePersistentState();
         return false;
      }
      Print("[EXEC] Verification warnings but position is open — proceeding");
   }

   IncrementDailyTradeCount();

   ClearSetupState(true);
   SavePersistentState();
   return true;
}

//+------------------------------------------------------------------+
//| Check and close trade if it exceeds maximum hours                |
//+------------------------------------------------------------------+
void CheckTimeBasedExit(const ulong eaTicket)
{
   if(InpMaxTradeHours <= 0)
      return;
   if(!SelectMyPositionByTicket(eaTicket))
      return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;
   if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) return;
   
   datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
   datetime currentTime = TimeCurrent();
   
   int hoursOpen = (int)((currentTime - positionTime) / 3600);
   
   if(hoursOpen >= InpMaxTradeHours)
   {
      Print("=== TIME-BASED EXIT === ticket=", eaTicket, " hours=", hoursOpen);
      CloseMyPositionByTicket(eaTicket, "[TIME_EXIT]");
   }
}

//+------------------------------------------------------------------+
//| Draw the currently active FVG zone                               |
//+------------------------------------------------------------------+
void DrawActiveFVG()
{
   if(!g_hasActiveFVG) return;
   
   string objName = g_objectPrefix + "ActiveFVG";
   datetime startTime = g_fvgTime;
   datetime endTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   color fvgColor = (g_tradeDirection == 1) ? InpBullishFVGColor : InpBearishFVGColor;
   
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, g_activeFVGBottom, endTime, g_activeFVGTop);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, fvgColor);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   
   string labelName = g_objectPrefix + "ActiveFVG_Label";
   string labelText = "ACTIVE FVG (" + DirectionToString(g_tradeDirection) + ")";
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, endTime, (g_activeFVGTop + g_activeFVGBottom) / 2);
   ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, fvgColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw status display showing current EA state                     |
//+------------------------------------------------------------------+
void DrawStatusDisplay()
{
   string objName = g_objectPrefix + "Status";
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   string statusText = "ICT EA | Momentum Entry | ";
   color statusColor = clrWhite;
   BuildStatusMainState(statusText, statusColor);
   
   if(g_fhigh != 0 && g_flow != 0)
   {
      statusText += " | H4: " + (g_revfibs ? "BULLISH" : "BEARISH");
   }
   
   statusText += " | D1 Bias: " + BiasToString(g_currentBias);
   
   if(InpEnableSessionFilter)
   {
      statusText += " | Session: " + ActiveSessionOrClosed();
   }
   
   statusText += " | Trades: " + IntegerToString(g_dailyTradeCount) + "/" + IntegerToString(InpMaxTradesPerDay);
   AppendSpreadStatus(statusText);
   AppendATRSpikeStatus(statusText);
   
   if(InpEnableRegimeAnalysis)
      statusText += " | Regime: " + GetVolatilityRegime();
   
   if(g_dailyTradeCount >= InpMaxTradesPerDay)
   {
      statusText += " (LIMIT REACHED)";
      statusColor = clrRed;
   }
   
   ObjectCreate(0, objName, OBJ_TEXT, 0, currentTime, currentPrice);
   ObjectSetString(0, objName, OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, statusColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Calculate daily bias based on D1 structure breaks                |
//+------------------------------------------------------------------+
void CalculateDailyBias()
{
   int d1_bars = iBars(_Symbol, PERIOD_D1);
   
   if(d1_bars < 3)
      return;
   
   struct StructPoint
   {
      int    idx;
      double open_price;
      double close_price;
   };
   
   StructPoint valid_highs[];
   StructPoint valid_lows[];
   ArrayResize(valid_highs, 0);
   ArrayResize(valid_lows, 0);
   
   for(int i = 1; i < d1_bars - 1 && i < 100; i++)
   {
      double prevHigh = iHigh(_Symbol, PERIOD_D1, i + 1);
      double currHigh = iHigh(_Symbol, PERIOD_D1, i);
      double nextHigh = iHigh(_Symbol, PERIOD_D1, i - 1);
      
      double prevLow = iLow(_Symbol, PERIOD_D1, i + 1);
      double currLow = iLow(_Symbol, PERIOD_D1, i);
      double nextLow = iLow(_Symbol, PERIOD_D1, i - 1);
      
      double currOpen  = iOpen(_Symbol, PERIOD_D1, i);
      double currClose = iClose(_Symbol, PERIOD_D1, i);
      
      if(currHigh > prevHigh && currHigh > nextHigh)
      {
         int size = ArraySize(valid_highs);
         ArrayResize(valid_highs, size + 1);
         valid_highs[size].idx = i;
         valid_highs[size].open_price = currOpen;
         valid_highs[size].close_price = currClose;
      }
      
      if(currLow < prevLow && currLow < nextLow)
      {
         int size = ArraySize(valid_lows);
         ArrayResize(valid_lows, size + 1);
         valid_lows[size].idx = i;
         valid_lows[size].open_price = currOpen;
         valid_lows[size].close_price = currClose;
      }
   }
   
   int biasValue = 0;
   double last_structure_high_body = 0;
   double last_structure_low_body = 0;
   
   for(int i = d1_bars - 1; i >= 0; i--)
   {
      if(i > d1_bars - 3)
         continue;
      
      double closePrice = iClose(_Symbol, PERIOD_D1, i);
      
      for(int j = 0; j < ArraySize(valid_highs); j++)
      {
         if(valid_highs[j].idx == i + 1)
         {
            last_structure_high_body = MathMax(valid_highs[j].open_price, valid_highs[j].close_price);
            break;
         }
      }
      
      for(int j = 0; j < ArraySize(valid_lows); j++)
      {
         if(valid_lows[j].idx == i + 1)
         {
            last_structure_low_body = MathMin(valid_lows[j].open_price, valid_lows[j].close_price);
            break;
         }
      }
      
      if(last_structure_low_body > 0 && closePrice < last_structure_low_body)
      {
         biasValue = -1;
      }
      
      if(last_structure_high_body > 0 && closePrice > last_structure_high_body)
      {
         biasValue = 1;
      }
      
      if(i == 0)
         g_currentBias = biasValue;
   }
   
   Print("=== DAILY BIAS UPDATED ===");
   Print("Bias: ", BiasToString(g_currentBias));
}

//+------------------------------------------------------------------+
//| Create daily bias label                                          |
//+------------------------------------------------------------------+
void CreateBiasLabel()
{
   if(ObjectFind(0, g_biasLabelName) >= 0)
      ObjectDelete(0, g_biasLabelName);
   
   ObjectCreate(0, g_biasLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_biasLabelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_biasLabelName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(0, g_biasLabelName, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, g_biasLabelName, OBJPROP_COLOR, InpNeutralBiasColor);
   ObjectSetInteger(0, g_biasLabelName, OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, g_biasLabelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, g_biasLabelName, OBJPROP_TEXT, "DAILY BIAS: NEUTRAL");
}

//+------------------------------------------------------------------+
//| Update daily bias label                                          |
//+------------------------------------------------------------------+
void UpdateBiasLabel()
{
   if(ObjectFind(0, g_biasLabelName) < 0)
      return;
   
   string text;
   color clr;
   
   if(g_currentBias == 1)
   {
      text = "DAILY BIAS: BULLISH";
      clr = InpBullishBiasColor;
   }
   else if(g_currentBias == -1)
   {
      text = "DAILY BIAS: BEARISH";
      clr = InpBearishBiasColor;
   }
   else
   {
      text = "DAILY BIAS: NEUTRAL";
      clr = InpNeutralBiasColor;
   }
   
   ObjectSetString(0, g_biasLabelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_biasLabelName, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Print volatility regime performance summary from trade history   |
//+------------------------------------------------------------------+
void PrintRegimePerformanceSummary()
{
   if(!InpEnableRegimeAnalysis)
      return;
   
   datetime toTime = TimeCurrent();
   datetime fromTime = (InpRegimeHistoryDays > 0) ? (toTime - InpRegimeHistoryDays * 86400) : (datetime)0;
   if(!HistorySelect(fromTime, toTime))
   {
      Print("REGIME ANALYSIS: Could not load history");
      return;
   }
   
   double profitLV = 0, profitMV = 0, profitHV = 0;
   int winsLV = 0, winsMV = 0, winsHV = 0;
   int lossesLV = 0, lossesMV = 0, lossesHV = 0;
   int unknownCount = 0;
   
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      string dealSymbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      if(dealMagic != (long)InpMagicNumber) continue;
      if(dealSymbol != _Symbol && StringFind(dealSymbol, StringSubstr(_Symbol, 0, 6)) != 0) continue;
      if(dealEntry != DEAL_ENTRY_OUT) continue;
      
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                      HistoryDealGetDouble(ticket, DEAL_SWAP) + 
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      
      ulong posId = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
      if(!HistorySelectByPosition(posId))
         continue;
      
      string regime = "MV";
      int innerDeals = HistoryDealsTotal();
      for(int j = 0; j < innerDeals; j++)
      {
         ulong innerTicket = HistoryDealGetTicket(j);
         if(innerTicket == 0) continue;
         if(HistoryDealGetInteger(innerTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            string comment = HistoryDealGetString(innerTicket, DEAL_COMMENT);
            string parts[];
            int partsN = StringSplit(comment, '|', parts);
            if(partsN > 1)
            {
               if(parts[1] == "LV") regime = "LV";
               else if(parts[1] == "HV") regime = "HV";
               else if(parts[1] == "MV") regime = "MV";
               else { regime = "MV"; unknownCount++; }
            }
            else
            {
               regime = "MV";
               unknownCount++;
            }
            break;
         }
      }
      
      if(!HistorySelect(fromTime, toTime))
         break;
      
      if(regime == "LV")
      {
         profitLV += profit;
         if(profit > 0) winsLV++; else lossesLV++;
      }
      else if(regime == "HV")
      {
         profitHV += profit;
         if(profit > 0) winsHV++; else lossesHV++;
      }
      else
      {
         profitMV += profit;
         if(profit > 0) winsMV++; else lossesMV++;
      }
   }
   
   Print("===========================================================");
   Print("VOLATILITY REGIME PERFORMANCE (", InpRegimeHistoryDays > 0 ? "Last " + IntegerToString(InpRegimeHistoryDays) + " days" : "All history", ")");
   Print("===========================================================");
   Print("LOW VOL (LV):  Trades: ", winsLV + lossesLV, " | Wins: ", winsLV, " | Losses: ", lossesLV, 
         " | P/L: ", DoubleToString(profitLV, 2));
   Print("MED VOL (MV):  Trades: ", winsMV + lossesMV, " | Wins: ", winsMV, " | Losses: ", lossesMV, 
         " | P/L: ", DoubleToString(profitMV, 2));
   Print("HIGH VOL (HV): Trades: ", winsHV + lossesHV, " | Wins: ", winsHV, " | Losses: ", lossesHV, 
         " | P/L: ", DoubleToString(profitHV, 2));
   Print("===========================================================");
   Print("TOTAL: P/L ", DoubleToString(profitLV + profitMV + profitHV, 2));
   if(unknownCount > 0)
      Print("Note: ", unknownCount, " trades had no regime tag (pre-analysis)");
   if(winsLV + lossesLV + winsMV + lossesMV + winsHV + lossesHV == 0 && totalDeals > 0)
      Print("REGIME DEBUG: No matching deals. Total in history: ", totalDeals, " | Magic: ", InpMagicNumber, " | Symbol: ", _Symbol);
   Print("===========================================================");
   
   if(InpRegimeLogCSV)
   {
      string filename = "RegimeAnalysis_" + _Symbol + "_" + IntegerToString(InpMagicNumber) + ".csv";
      int fh = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
      if(fh != INVALID_HANDLE)
      {
         FileWrite(fh, "Regime", "Trades", "Wins", "Losses", "Profit");
         FileWrite(fh, "LV", winsLV + lossesLV, winsLV, lossesLV, DoubleToString(profitLV, 2));
         FileWrite(fh, "MV", winsMV + lossesMV, winsMV, lossesMV, DoubleToString(profitMV, 2));
         FileWrite(fh, "HV", winsHV + lossesHV, winsHV, lossesHV, DoubleToString(profitHV, 2));
         FileClose(fh);
         Print("Regime CSV saved: ", filename);
      }
   }
}

//+------------------------------------------------------------------+
//| BA: write per-trade CSV journal from deal history                |
//+------------------------------------------------------------------+
void WriteTradeJournalCSV()
{
   if(!InpEnableTradeJournal) return;
   
   datetime toTime = TimeCurrent();
   if(!HistorySelect(0, toTime)) { Print("[JOURNAL] HistorySelect failed"); return; }
   
   string fn = "TradeJournal_" + _Symbol + "_" + IntegerToString(InpMagicNumber) + ".csv";
   int fh = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(fh == INVALID_HANDLE) { Print("[JOURNAL] FileOpen failed: ", fn); return; }
   
   FileWrite(fh,
      "TradeNo", "OpenTime", "CloseTime", "DurationMin", "Direction",
      "OpenPrice", "ClosePrice", "SL", "TP",
      "Volume", "Profit", "Swap", "Commission", "NetProfit",
      "Regime", "Session", "Bias", "DOW", "SpreadEntry", "ATREntry",
      "WinLoss", "RMultiple");
   
   int totalDeals = HistoryDealsTotal();
   int tradeNo = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong exitTicket = HistoryDealGetTicket(i);
      if(exitTicket == 0) continue;
      if(HistoryDealGetInteger(exitTicket, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(exitTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(exitTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      double profit = HistoryDealGetDouble(exitTicket, DEAL_PROFIT);
      double swap = HistoryDealGetDouble(exitTicket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(exitTicket, DEAL_COMMISSION);
      double netProfit = profit + swap + commission;
      double exitPrice = HistoryDealGetDouble(exitTicket, DEAL_PRICE);
      double exitVol = HistoryDealGetDouble(exitTicket, DEAL_VOLUME);
      datetime exitTime = (datetime)HistoryDealGetInteger(exitTicket, DEAL_TIME);
      
      ulong posId = HistoryDealGetInteger(exitTicket, DEAL_POSITION_ID);
      if(!HistorySelectByPosition(posId)) continue;
      
      string entryComment = "";
      double entryPrice = 0;
      datetime entryTime = 0;
      long dealType = 0;
      
      int innerDeals = HistoryDealsTotal();
      for(int j = 0; j < innerDeals; j++)
      {
         ulong inTicket = HistoryDealGetTicket(j);
         if(inTicket == 0) continue;
         if(HistoryDealGetInteger(inTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            entryComment = HistoryDealGetString(inTicket, DEAL_COMMENT);
            entryPrice = HistoryDealGetDouble(inTicket, DEAL_PRICE);
            entryTime = (datetime)HistoryDealGetInteger(inTicket, DEAL_TIME);
            dealType = HistoryDealGetInteger(inTicket, DEAL_TYPE);
            break;
         }
      }
      
      if(!HistorySelect(0, toTime)) break;
      
      string parts[];
      int nParts = StringSplit(entryComment, '|', parts);
      
      string dir = (nParts > 0) ? parts[0] : ((dealType == DEAL_TYPE_BUY) ? "L" : "S");
      string regime = (nParts > 1) ? parts[1] : "NA";
      string sess = (nParts > 2) ? parts[2] : "NA";
      string bias = (nParts > 3) ? parts[3] : "NA";
      string dowStr = (nParts > 4) ? parts[4] : "NA";
      string spreadStr = (nParts > 5) ? parts[5] : "NA";
      string atrStr = (nParts > 6) ? parts[6] : "NA";
      
      int durMin = (entryTime > 0 && exitTime > entryTime) ? (int)((exitTime - entryTime) / 60) : 0;
      
      double rMultiple = 0;
      if(entryPrice > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(point > 0 && entryPrice > 0)
         {
            double priceDiff = MathAbs(exitPrice - entryPrice);
            string atrClean = atrStr;
            StringReplace(atrClean, "ATR", "");
            double atrPoints = StringToDouble(atrClean);
            if(atrPoints > 0)
               rMultiple = priceDiff / (atrPoints * point * InpATRMultiplier);
            if(netProfit < 0) rMultiple = -rMultiple;
         }
      }
      
      string winLoss = (netProfit > 0) ? "W" : ((netProfit < 0) ? "L" : "BE");
      
      tradeNo++;
      FileWrite(fh,
         IntegerToString(tradeNo),
         TimeToString(entryTime, TIME_DATE | TIME_MINUTES),
         TimeToString(exitTime, TIME_DATE | TIME_MINUTES),
         IntegerToString(durMin),
         dir,
         DoubleToString(entryPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
         DoubleToString(exitPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
         "0",
         "0",
         DoubleToString(exitVol, 2),
         DoubleToString(profit, 2),
         DoubleToString(swap, 2),
         DoubleToString(commission, 2),
         DoubleToString(netProfit, 2),
         regime, sess, bias, dowStr, spreadStr, atrStr,
         winLoss,
         DoubleToString(rMultiple, 2));
   }
   
   FileClose(fh);
   string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + fn;
   Print("[JOURNAL] Saved ", tradeNo, " trades to: ", commonPath);
}

//+------------------------------------------------------------------+
//| BA: extended performance breakdown for log output                |
//+------------------------------------------------------------------+
void PrintExtendedPerformanceSummary()
{
   if(!InpPrintExtendedSummary) return;
   
   datetime toTime = TimeCurrent();
   if(!HistorySelect(0, toTime)) return;
   
   string categories[];
   double catProfit[];
   int catWins[];
   int catLosses[];
   int catCount = 0;
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong exitTicket = HistoryDealGetTicket(i);
      if(exitTicket == 0) continue;
      if(HistoryDealGetInteger(exitTicket, DEAL_MAGIC) != (long)InpMagicNumber) continue;
      if(HistoryDealGetString(exitTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(exitTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      double netProfit = HistoryDealGetDouble(exitTicket, DEAL_PROFIT)
                        + HistoryDealGetDouble(exitTicket, DEAL_SWAP)
                        + HistoryDealGetDouble(exitTicket, DEAL_COMMISSION);
      
      ulong posId = HistoryDealGetInteger(exitTicket, DEAL_POSITION_ID);
      if(!HistorySelectByPosition(posId)) continue;
      
      string entryComment = "";
      int innerDeals = HistoryDealsTotal();
      for(int j = 0; j < innerDeals; j++)
      {
         ulong inTk = HistoryDealGetTicket(j);
         if(inTk == 0) continue;
         if(HistoryDealGetInteger(inTk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            entryComment = HistoryDealGetString(inTk, DEAL_COMMENT);
            break;
         }
      }
      if(!HistorySelect(0, toTime)) break;
      
      string parts[];
      int nParts = StringSplit(entryComment, '|', parts);
      
      string dir = (nParts > 0) ? parts[0] : "NA";
      string regime = (nParts > 1) ? parts[1] : "NA";
      string sess = (nParts > 2) ? parts[2] : "NA";
      string bias = (nParts > 3) ? parts[3] : "NA";
      string dowStr = (nParts > 4) ? parts[4] : "NA";
      
      string keys[];
      ArrayResize(keys, 5);
      keys[0] = "Dir:" + dir;
      keys[1] = "Regime:" + regime;
      keys[2] = "Session:" + sess;
      keys[3] = "Bias:" + bias;
      keys[4] = "DOW:" + dowStr;
      
      for(int k = 0; k < 5; k++)
      {
         int slot = -1;
         for(int s = 0; s < catCount; s++)
         {
            if(categories[s] == keys[k]) { slot = s; break; }
         }
         if(slot < 0)
         {
            slot = catCount;
            catCount++;
            ArrayResize(categories, catCount);
            ArrayResize(catProfit, catCount);
            ArrayResize(catWins, catCount);
            ArrayResize(catLosses, catCount);
            categories[slot] = keys[k];
            catProfit[slot] = 0;
            catWins[slot] = 0;
            catLosses[slot] = 0;
         }
         catProfit[slot] += netProfit;
         if(netProfit > 0) catWins[slot]++;
         else if(netProfit < 0) catLosses[slot]++;
      }
   }
   
   if(catCount == 0) return;
   
   Print("===================================================================");
   Print("BA PERFORMANCE BREAKDOWN (", _Symbol, " Magic=", InpMagicNumber, ")");
   Print("===================================================================");
   
   string groups[] = {"Dir:", "Regime:", "Session:", "Bias:", "DOW:"};
   string groupNames[] = {"DIRECTION", "VOLATILITY REGIME", "SESSION", "DAILY BIAS", "DAY OF WEEK"};
   
   for(int g = 0; g < 5; g++)
   {
      Print("--- ", groupNames[g], " ---");
      for(int s = 0; s < catCount; s++)
      {
         if(StringFind(categories[s], groups[g]) != 0) continue;
         string label = StringSubstr(categories[s], StringLen(groups[g]));
         int total = catWins[s] + catLosses[s];
         double wr = (total > 0) ? catWins[s] * 100.0 / total : 0;
         Print("  ", label, " | Trades: ", total, " | Wins: ", catWins[s], " | Losses: ", catLosses[s],
               " | WR: ", DoubleToString(wr, 1), "% | P/L: ", DoubleToString(catProfit[s], 2));
      }
   }
   Print("===================================================================");
}

//+------------------------------------------------------------------+
//| Delete all objects created by this EA                            |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, g_objectPrefix) == 0)
      {
         ObjectDelete(0, objName);
      }
   }
}

//+------------------------------------------------------------------+