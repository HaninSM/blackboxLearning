# Blackbox Telemetry Data Dictionary & Flight Recorder

## 1. Overview

The Blackbox Telemetry Engine is a high-speed, non-blocking telemetry system integrated into every MQL5 Expert Advisor generated under this framework. It acts as the aircraft flight data recorder, continuously observing open positions and capturing exact execution and market microstructure metrics.

All telemetry records are exported to the MT5 file sandbox:  
`MQL5/Files/Blackbox_<EAName>_<Magic>.csv`

---

## 2. Telemetry Data Dictionary (22 Columns)

| Column Index | Header | Data Type | Example Value | Description |
| :---: | :--- | :---: | :--- | :--- |
| **1** | `Ticket` | `ulong` | `10293847` | Broker order ticket or virtual simulation ID |
| **2** | `IsVirtual` | `string` | `TRUE` / `FALSE` | Indicates whether trade was simulated (surveillance) or real |
| **3** | `OpenTime` | `datetime` | `2026.11.21 14:30:00` | Exact entry timestamp |
| **4** | `CloseTime` | `datetime` | `2026.11.21 15:45:22` | Exact exit timestamp |
| **5** | `DurationSec` | `long` | `4522` | Trade lifetime in seconds |
| **6** | `Symbol` | `string` | `EURUSD` | Traded asset |
| **7** | `Timeframe` | `string` | `PERIOD_M15` | Operational chart timeframe |
| **8** | `Type` | `string` | `BUY` / `SELL` | Trade direction |
| **9** | `Lots` | `double` | `0.25` | Traded volume size |
| **10** | `OpenPrice` | `double` | `1.08550` | Fill execution price |
| **11** | `ClosePrice` | `double` | `1.08820` | Exit execution price |
| **12** | `SL` | `double` | `1.08300` | Initial Stop Loss level |
| **13** | `TP` | `double` | `1.09050` | Initial Take Profit level |
| **14** | `SpreadPoints` | `int` | `12` | Spread at the exact tick of entry (in points) |
| **15** | `SlippagePoints` | `int` | `3` | Execution price deviation from requested price |
| **16** | `StopLevelPoints` | `int` | `20` | Broker minimum allowed distance for stops |
| **17** | `MAE_Points` | `double` | `14.5` | **Maximum Adverse Excursion** (deepest floating drawdown) |
| **18** | `MFE_Points` | `double` | `48.2` | **Maximum Favorable Excursion** (highest floating peak profit) |
| **19** | `PnL_Points` | `double` | `27.0` | Net profit or loss measured in points |
| **20** | `PnL_Money` | `double` | `67.50` | Net profit or loss in account deposit currency |
| **21** | `ExitReason` | `string` | `TP` | Reason for exit (`SL`, `TP`, `TRAILING_STOP`, `OPPOSITE_SIGNAL`, `CUTLOSS`) |
| **22** | `MarketFeatures` | `string` | `"RSI:68.2\|ATR:0.0018\|Session:London"` | Feature snapshot of market state and indicators at entry |

---

## 3. Mathematical Definitions of Critical Flight Metrics

```
  Price
    ▲
    │                                          [Peak Profit = MFE]
    │                                                 *
    │                                                / \
    │                             [Entry Price]     /   \
    │ ──────────────────────────────────*──────────/─────*─── [Close Price: +PnL]
    │                                    \        /
    │                                     \      /
    │                                      \    /
    │                                       *
    │                               [Deepest Drawdown = MAE]
    │
    │ ──────────────────────────────────────────────────────── [Initial Stop Loss]
    └─────────────────────────────────────────────────────────────────────────────► Time
```

### A. Maximum Adverse Excursion (MAE)
MAE quantifies the worst paper loss experienced by a trade during its lifespan before it was closed.
* For BUY: $\text{MAE} = \max\left(0, \, \frac{\text{OpenPrice} - \text{LowestLowDuringTrade}}{\text{_Point}}\right)$
* For SELL: $\text{MAE} = \max\left(0, \, \frac{\text{HighestHighDuringTrade} - \text{OpenPrice}}{\text{_Point}}\right)$

**Why MAE Matters:**  
If 90% of winning trades never experience an MAE greater than 20 points, but the strategy uses a 50-point Stop Loss, the extra 30 points of risk are dead capital. Tightening the SL to 25 points immediately doubles the strategy's compounding efficiency without increasing the loss frequency.

---

### B. Maximum Favorable Excursion (MFE)
MFE quantifies the highest unrealized profit achieved by a trade during its lifespan.
* For BUY: $\text{MFE} = \max\left(0, \, \frac{\text{HighestHighDuringTrade} - \text{OpenPrice}}{\text{_Point}}\right)$
* For SELL: $\text{MFE} = \max\left(0, \, \frac{\text{OpenPrice} - \text{LowestLowDuringTrade}}{\text{_Point}}\right)$

**Why MFE Matters:**  
If losing trades consistently achieve an MFE of +30 points before reversing and hitting a full Stop Loss, the strategy is bleeding profits. Setting a Break-Even activation or Partial Take-Profit at +25 points transforms losers into scratch trades or small winners.

---

## 4. Performance & High-Frequency I/O Safety

1. **In-Memory Dynamic Buffering:**  
   During live operation, the EA updates MAE and MFE inside a lightweight struct array in RAM. Disk writes (`FileWrite`) are **never performed on standard ticks**.
2. **Event-Driven Disk Flushing:**  
   A record is appended to the CSV file strictly once per trade: when an exit event is triggered (`SL`, `TP`, or manual/signal close).
3. **Non-Blocking Architecture:**  
   File handles are opened with `FILE_READ | FILE_WRITE | FILE_CSV`, appended via `FileSeek(h, 0, SEEK_END)`, and closed immediately, preventing file locking across multi-chart instances.
