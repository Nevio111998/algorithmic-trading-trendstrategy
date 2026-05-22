# Rule-Based Trend-Following Expert Advisor (MQL5)

This repository contains the implementation of a fully rule-based,
multi-timeframe trend-following trading strategy developed as part of an
academic project.

The strategy is designed to operate deterministically without subjective
intervention and was implemented as a MetaTrader 5 Expert Advisor (EA)
using the MQL5 programming language.

## Strategy Overview

The trading logic follows a top-down, multi-timeframe approach:

- **Daily (D1):** Determination of the overall market bias (Daily Bias)
  based on structural breaks of swing highs and swing lows.
- **H4:** Identification of market structure and retracement zones using
  Fair Value Gaps (FVGs) and the 50% retracement level.
- **M15:** Entry execution based on momentum confirmation using closed
  candles in trend direction.

## Key Features

- Fully rule-based and deterministic trading logic
- Multi-timeframe analysis (D1, H4, M15)
- Fair Value Gap (FVG) detection as retracement zones
- Momentum-based entry confirmation
- ATR-based stop-loss calculation
- Fixed percentage risk per trade with dynamic position sizing
- Optional session-based trading filter

## Backtesting

The strategy was evaluated using historical market data in the
MetaTrader 5 Strategy Tester with tick-based simulation.

Backtesting was conducted on:
- Instrument: EUR/USD
- Data source: OANDA (MT5 demo feed)
- Time period: 2020-10-01 to 2024-01-31

The backtest results and performance metrics are discussed and interpreted
in the corresponding project documentation.

## Version 2.0 – Bachelor Thesis Extension

**TrendFollowingEA_V2.0** was further developed as part of the bachelor thesis and builds on the first version created during the previous academic project. While the original signal logic remains unchanged, the Expert Advisor was extended with a technical safety, risk, execution, and monitoring framework.

The main extensions in V2.0 include:

- Spread Guard for controlling increased trading costs
- Volatility Guard for blocking exceptional ATR spikes
- Volatility regime classification for additional market context analysis
- Pre-trade validation for terminal, symbol, tick, and data checks
- Circuit Breaker for daily loss limits, consecutive losses, and technical execution errors
- Exposure and margin checks before order execution
- Execution hardening with retry logic, slippage control, and post-trade verification
- Persistent state handling for restart and crash safety
- Extended Trade Journal and RejectedTrades logging with reason codes
- Preparation for a controlled demo-live trading environment

This version is intended as a technically extended framework for the bachelor thesis. It should not be understood as a fully validated live trading bot for real-money trading.

## Disclaimer

This code is provided for research and educational purposes only.
It does not constitute financial advice.
Trading financial instruments involves risk, and past performance
does not guarantee future results.
