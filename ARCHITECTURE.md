# MQL5 Architecture & System Design

## 1. The 7 Quantitative Pillars of Deterministic Execution

Every strategy parsed by this system must strictly satisfy and define the **7 Quantitative Pillars** before code synthesis.

```
┌─────────────────────────────────────────────────────────────────┐
│               THE 7 QUANTITATIVE PILLARS OF MQL5                │
├─────────────────────────────────────────────────────────────────┤
│ 1. ASSET CLASS & REGIME     Instrument specs, tick values, TF   │
│ 2. INDICATOR FORMULAS       Discrete formulas, shifts, buffers  │
│ 3. ENTRY TRIGGER            Deterministic boolean condition     │
│ 4. CONFLUENCE & FILTERS     Session, Higher-TF, Spread guard    │
│ 5. STOP LOSS & CUTLOSS      ATR / Swing logic, emergency cut    │
│ 6. TAKE PROFIT & TRAILING   Asymmetric R:R, BEP, trailing step  │
│ 7. MONEY MANAGEMENT         Dynamic equity risk %, max DD limit │
└─────────────────────────────────────────────────────────────────┘
```

---

### Pillar 1: Asset Class & Market Regime Suitability
* **Market Character:** Trend-following, mean-reversion, breakout, or volatility-expansion.
* **Symbol Specifications:** Dynamic query of `_Point`, `_Digits`, `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_TRADE_TICK_SIZE`, and `SYMBOL_VOLUME_MIN/STEP/MAX`.
* **Execution Timeframe:** Base operational timeframe (e.g. `PERIOD_M15`) and context timeframe (e.g. `PERIOD_H4`).

### Pillar 2: Technical Indicators & Mathematical Formulas
* All indicators must be instantiated during `OnInit()` and assigned to safe handles (e.g., `iMA()`, `iRSI()`, `iATR()`).
* Dynamic buffers are fetched via `CopyBuffer()` with strict boundary and error checking.
* Historical candle data is mapped using `MqlRates` with `ArraySetAsSeries(rates, true)` to ensure index `[0]` represents the developing candle and index `[1]` represents the closed candle.

### Pillar 3: Deterministic Entry Triggers
* **Bar-Close Confirmation:** Default execution is strictly tied to `isNewBar()` check to prevent intra-bar repainting noise.
* **Boolean Formula:** A discrete condition returning `SIGNAL_BUY`, `SIGNAL_SELL`, or `SIGNAL_NONE`. No ambiguous terms (*"good volume"*, *"price looks ready"*) are permitted.

### Pillar 4: Confluence & Quality Filters
* **Spread Guard:** Compare current spread `(Ask - Bid) / _Point` against `InpMaxSpreadPoints`.
* **Stop Level Compliance:** Ensure initial distance between Entry and SL/TP exceeds broker `SYMBOL_TRADE_STOPS_LEVEL`.
* **Trading Session Window:** User-configurable trading hours (e.g. London `08:00–16:00 UTC`, NY `13:00–21:00 UTC`) to avoid low-liquidity rollover widenings.

### Pillar 5: Stop Loss & Emergency Cutloss
* **Mathematical SL Definition:**
  - ATR-based: $\text{SL} = \text{Entry} \pm (k \times \text{ATR}_{14})$.
  - Structural: Swing high/low using `iFractals` or $N$-bar lowest low / highest high.
* **Emergency Cutloss:** Invalidation logic if an opposing signal triggers or higher-TF trend structurally breaks before SL is hit.

### Pillar 6: Take Profit, Break-Even & Trailing Engine
* **Risk-to-Reward Ratio (RRR):** Target TP is mathematically linked to the SL distance (e.g., $1.5 \times \text{SL}$ or $2.0 \times \text{SL}$).
* **Step-wise Break-Even:** When unrealized gain reaches $+1.0 \times \text{Risk}$, SL is shifted to $\text{OpenPrice} + \text{SpreadBuffer}$.
* **Trailing Stop:** Trailing step triggered beyond predefined MFE threshold.

### Pillar 7: Money Management & Risk Allocation
* Dynamic lot calculation based on account risk percentage:
  $$\text{Lots} = \frac{\text{AccountEquity} \times \text{RiskPercentage}}{\text{StopLossDistanceInPoints} \times \text{TickValue}}$$
* Lot volume is normalized using `MathFloor(Lots / VolumeStep) * VolumeStep`.
* Daily Maximum Drawdown hard stop: halts new trade initiation if daily equity drop exceeds limit.

---

## 2. Event Loop Architecture

```
   OnTick()
     │
     ├── 1. Update Blackbox Telemetry (Update MAE & MFE for active trades)
     │
     ├── 2. Is New Bar? (isNewBar() check)
     │      └── If FALSE -> Exit tick (for Bar-Close strategies)
     │
     ├── 3. Trailing Stop / Break-Even Update
     │
     ├── 4. Check Exit Conditions / Cutloss
     │      └── If Signal Exit -> Close position & log to Blackbox
     │
     ├── 5. Check Entry Filters (Spread, Session Time, StopLevel)
     │      └── If Fails -> Abort entry
     │
     └── 6. Evaluate Signal Engine (CheckEntry())
            ├── If BUY -> RecordEntry() & Execute Order
            └── If SELL -> RecordEntry() & Execute Order
```

---

## 3. Dual Execution Engine (Surveillance vs Native)

```cpp
// Mode Switch
input bool InpSurveillanceOnly = true; // TRUE = Shadow/Virtual, FALSE = Live Broker
```

### Surveillance Mode (`InpSurveillanceOnly = true`)
* Orders are simulated purely in-memory inside `CBlackboxLogger`.
* Virtual positions are tracked per tick:
  - If `Bid <= Virtual_SL`, position is marked closed with `VIRTUAL_SL`.
  - If `Bid >= Virtual_TP`, position is marked closed with `VIRTUAL_TP`.
* Zero financial risk, allowing rapid forward-testing on demo or live charts without incurring broker fees or margin locks.

### Live/Demo Execution Mode (`InpSurveillanceOnly = false`)
* Uses standard `CTrade` library with market orders (`Buy()` / `Sell()`).
* Tracks actual order ticket, fill slippage (`order_open_price - request_price`), and exact broker commission/swap.
* On exit (`OnTradeTransaction`), matches closure ticket and writes finalized telemetry.
