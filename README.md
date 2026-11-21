# Quantitative MQL5 Expert Advisor & Blackbox Telemetry Engine

## 1. Executive Summary & Philosophy

This project establishes an institutional-grade quantitative framework for ingesting, auditing, translating, and engineering algorithmic trading strategies from retail or discretionary sources (such as YouTube videos, webinars, and public trading plans) into deterministic, production-ready **MetaTrader 5 (MQL5)** Expert Advisors.

The framework operates on the **Tripartite Quant Desk Paradigm**:

```
 ┌──────────────────────────────────────────────────────────────┐
 │                     THE TRIPARTITE PARADIGM                  │
 ├──────────────────────────────────────────────────────────────┤
 │                                                              │
 │   1. THE FIGHTER JET         2. THE BLACKBOX                 │
 │      (MQL5 Execution EA)        (Telemetry Logger)           │
 │      • Deterministic Logic      • In-Memory Tick Tracker     │
 │      • Institutional Sizing     • MAE / MFE Flight Metrics   │
 │      • Millisecond Execution    • Market State Snapshots     │
 │               │                         ▲                    │
 │               ▼                         │                    │
 │         Orders & Ticks ─────────────────┘                    │
 │                                                              │
 │                              │                               │
 │                              ▼ (CSV Telemetry Stream)        │
 │                                                              │
 │                 3. THE FLIGHT DATA ANALYST                   │
 │                    (AI Quant Agent)                          │
 │                    • Edge Verification                       │
 │                    • SL/TP Calibration via MAE/MFE           │
 │                    • Upgraded Flight Specifications          │
 └──────────────────────────────────────────────────────────────┘
```

1. **The Fighter Jet (Execution EA):** A high-performance, object-oriented MQL5 Expert Advisor engineered with zero repainting, deterministic entry/exit rules, and strict risk controls.
2. **The Blackbox (Surveillance Engine):** A non-blocking, in-memory telemetry recorder (`BlackboxLogger.mqh`) that captures flight dynamics tick-by-tick (Slippage, Spread, StopLevel, MAE, MFE, and indicator features).
3. **The Flight Data Analyst (AI Agent):** The quantitative researcher that ingests post-trade CSV telemetry data, diagnoses inefficiencies, and mathematically calibrates parameters for optimal risk-adjusted returns.

---

## 2. End-to-End Operational Pipeline

```
 [YouTube Link / Strategy Source]
               │
               ▼
 [Phase 1: Ingestion & Transcript Parsing]
       • Run get_youtube_transcript.py
       • Extract clean audio transcripts and metadata
               │
               ▼
 [Phase 2: Quantitative Deconstruction (7 Pillars)]
       • Asset class & timeframe suitability
       • Mathematical indicator formulas
       • Deterministic entry / exit triggers
       • Volatility, session, and spread confluences
               │
               ▼
 [Phase 3: Head Analyst Red-Flag Audit]
       • Ambiguity resolution (subjektif -> mathematical formula)
       • Repainting indicator identification
       • Cost-of-trade & friction feasibility check
               │
               ▼
 [Phase 4: Code Generation & Compilation]
       • Generate self-contained .mq5 file
       • Embed CBlackboxLogger telemetry class
       • Support Dual Modes (Surveillance-Only vs Real Broker Execution)
               │
               ▼
 [Phase 5: Flight Testing & Data Capture]
       • Run EA on MT5 (Strategy Tester, Demo, or Micro-Live)
       • Flight records automatically stream to MQL5/Files/Blackbox_*.csv
               │
               ▼
 [Phase 6: Post-Flight Optimization & Calibration]
       • AI Analyst parses MAE/MFE distributions
       • Optimize Stop Loss, Take Profit, and Break-Even thresholds
       • Upgrade the Fighter Jet parameters
```

---

## 3. Repository Structure

```
.
├── README.md                      # Overview, philosophy, and operational pipeline
├── ARCHITECTURE.md                # 7 Pillars of MQL5 design & event architecture
├── BLACKBOX_TELEMETRY.md          # 22-column flight data dictionary & telemetry mechanics
├── QUANT_OPTIMIZATION_PLAYBOOK.md # Post-flight diagnostic guide & calibration rules
└── templates/
    └── BlackboxLogger.mqh         # Reusable MQL5 telemetry logging class
```

---

## 4. Quick Start Guide

### Step 1: Ingesting a Trading Strategy
Provide a YouTube video link to the agent:
```bash
python scripts/get_youtube_transcript.py "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Step 2: Generating the Expert Advisor
The agent generates:
1. **Flight Plan Document:** Strategy blueprint, formula definitions, and gap audit.
2. **`.mq5` Source Code:** Complete, clean, object-oriented MQL5 script ready for MetaEditor.

### Step 3: Compiling & Deploying in MetaTrader 5
1. Copy the generated `.mq5` file into your MT5 directory: `MQL5/Experts/`.
2. Copy `BlackboxLogger.mqh` into `MQL5/Include/`.
3. Open **MetaEditor (F4)** and press **Compile (F7)**. Check for 0 errors and 0 warnings.
4. Attach the EA to your target chart.

### Step 4: Configuring Flight Modes
In the EA input properties:
* `InpSurveillanceOnly = true`: **Surveillance Mode.** The EA tracks paper/virtual trades, records simulated MAE/MFE, and logs data without placing live broker orders.
* `InpSurveillanceOnly = false`: **Live/Demo Execution Mode.** The EA sends native orders via `CTrade`, capturing real broker execution metrics (fill latency, slippage, real PnL).

### Step 5: Post-Flight Data Review
After collecting 30–50 trades, locate the output CSV in:
`Terminal Directory / MQL5 / Files / Blackbox_<EAName>_<Magic>.csv`

Provide this file back to the AI Analyst to run the **Post-Flight Optimization Protocol**.
