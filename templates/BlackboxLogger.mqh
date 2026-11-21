//+------------------------------------------------------------------+
//|                                              BlackboxLogger.mqh  |
//|               Advanced Telemetry Surveillance Engine for MQL5    |
//|                         Designed for Quant Strategy Optimization |
//+------------------------------------------------------------------+
#property copyright "MQL5 EA Architect / Quant Strategy Analyst"
#property link      "https://github.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Structure to store trade telemetry data                          |
//+------------------------------------------------------------------+
struct SBlackboxTrade
{
   ulong             ticket;              // Order/Position Ticket
   bool              is_virtual;          // True if purely paper/surveillance
   datetime          open_time;           // Entry Timestamp
   datetime          close_time;          // Exit Timestamp
   string            symbol;              // Traded Symbol
   ENUM_TIMEFRAMES   timeframe;           // Chart Timeframe
   ENUM_POSITION_TYPE position_type;      // POSITION_TYPE_BUY or POSITION_TYPE_SELL
   double            lot_size;            // Volume
   double            open_price;          // Execution Price
   double            close_price;         // Exit Price
   double            sl_price;            // Initial Stop Loss
   double            tp_price;            // Initial Take Profit
   int               spread_at_open;      // Spread at entry (points)
   int               slippage_points;     // Execution Slippage (points)
   int               stoplevel_at_open;   // Broker StopLevel (points)
   double            mae_points;          // Maximum Adverse Excursion (worst drawdown in points)
   double            mfe_points;          // Maximum Favorable Excursion (highest peak profit in points)
   double            pnl_points;          // Final PnL in points
   double            pnl_money;           // Final PnL in account currency
   string            exit_reason;         // "SL", "TP", "OPPOSITE_SIGNAL", "TRAILING_STOP", "EXPIRY", "MANUAL"
   string            market_features;     // Indicator snapshots at entry (e.g. "RSI:68.2|ATR:0.0018|Session:London")
   bool              is_closed;           // Is record finalized
};

//+------------------------------------------------------------------+
//| Class CBlackboxLogger: Manages in-memory tracking & CSV export   |
//+------------------------------------------------------------------+
class CBlackboxLogger
{
private:
   string            m_ea_name;
   ulong             m_magic;
   string            m_csv_filename;
   SBlackboxTrade    m_active_trades[];
   int               m_total_active;
   int               m_file_handle;

   // Helper to check if file exists
   bool FileExists(const string filename)
   {
      int h = FileOpen(filename, FILE_READ | FILE_CSV);
      if(h != INVALID_HANDLE)
      {
         FileClose(h);
         return true;
      }
      return false;
   }

   // Write CSV header if creating a new file
   void EnsureCsvHeader()
   {
      if(!FileExists(m_csv_filename))
      {
         int h = FileOpen(m_csv_filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
         if(h != INVALID_HANDLE)
         {
            FileWrite(h, 
               "Ticket",
               "IsVirtual",
               "OpenTime",
               "CloseTime",
               "DurationSec",
               "Symbol",
               "Timeframe",
               "Type",
               "Lots",
               "OpenPrice",
               "ClosePrice",
               "SL",
               "TP",
               "SpreadPoints",
               "SlippagePoints",
               "StopLevelPoints",
               "MAE_Points",
               "MFE_Points",
               "PnL_Points",
               "PnL_Money",
               "ExitReason",
               "MarketFeatures"
            );
            FileClose(h);
         }
      }
   }

public:
   CBlackboxLogger() : m_total_active(0), m_magic(0), m_ea_name("EA_FighterJet") {}
   ~CBlackboxLogger() {}

   //+---------------------------------------------------------------+
   //| Initialization                                                |
   //+---------------------------------------------------------------+
   void Init(const string ea_name, const ulong magic)
   {
      m_ea_name = ea_name;
      m_magic = magic;
      m_csv_filename = "Blackbox_" + m_ea_name + "_" + IntegerToString(m_magic) + ".csv";
      EnsureCsvHeader();
      ArrayResize(m_active_trades, 0);
      m_total_active = 0;
      Print("[Blackbox] Initialized telemetry logger. Output: MQL5/Files/", m_csv_filename);
   }

   //+---------------------------------------------------------------+
   //| Record new trade launch (Real or Virtual)                     |
   //+---------------------------------------------------------------+
   void RecordEntry(
      const ulong ticket,
      const bool is_virtual,
      const string symbol,
      const ENUM_TIMEFRAMES tf,
      const ENUM_POSITION_TYPE ptype,
      const double lot,
      const double open_price,
      const double sl,
      const double tp,
      const int slippage_points,
      const string market_features
   )
   {
      m_total_active++;
      ArrayResize(m_active_trades, m_total_active);
      int idx = m_total_active - 1;

      m_active_trades[idx].ticket             = ticket;
      m_active_trades[idx].is_virtual         = is_virtual;
      m_active_trades[idx].open_time           = TimeCurrent();
      m_active_trades[idx].close_time          = 0;
      m_active_trades[idx].symbol              = symbol;
      m_active_trades[idx].timeframe           = tf;
      m_active_trades[idx].position_type       = ptype;
      m_active_trades[idx].lot_size            = lot;
      m_active_trades[idx].open_price          = open_price;
      m_active_trades[idx].close_price         = 0.0;
      m_active_trades[idx].sl_price            = sl;
      m_active_trades[idx].tp_price            = tp;
      m_active_trades[idx].spread_at_open      = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      m_active_trades[idx].slippage_points     = slippage_points;
      m_active_trades[idx].stoplevel_at_open   = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_active_trades[idx].mae_points          = 0.0;
      m_active_trades[idx].mfe_points          = 0.0;
      m_active_trades[idx].pnl_points          = 0.0;
      m_active_trades[idx].pnl_money           = 0.0;
      m_active_trades[idx].exit_reason         = "OPEN";
      m_active_trades[idx].market_features     = market_features;
      m_active_trades[idx].is_closed           = false;

      PrintFormat("[Blackbox] Target locked! Ticket: %I64u | Type: %s | Price: %.5f | SL: %.5f | TP: %.5f",
                  ticket, EnumToString(ptype), open_price, sl, tp);
   }

   //+---------------------------------------------------------------+
   //| Update MAE & MFE on each tick for active trades               |
   //+---------------------------------------------------------------+
   void OnTickUpdate(const string symbol)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) return;

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      for(int i = 0; i < m_total_active; i++)
      {
         if(m_active_trades[i].is_closed || m_active_trades[i].symbol != symbol)
            continue;

         double current_price = (m_active_trades[i].position_type == POSITION_TYPE_BUY) ? bid : ask;
         double raw_diff = 0.0;

         if(m_active_trades[i].position_type == POSITION_TYPE_BUY)
            raw_diff = (current_price - m_active_trades[i].open_price) / point;
         else
            raw_diff = (m_active_trades[i].open_price - current_price) / point;

         // Check MFE (peak profit in points)
         if(raw_diff > m_active_trades[i].mfe_points)
            m_active_trades[i].mfe_points = raw_diff;

         // Check MAE (deepest adverse excursion in points)
         if(raw_diff < 0 && MathAbs(raw_diff) > m_active_trades[i].mae_points)
            m_active_trades[i].mae_points = MathAbs(raw_diff);

         // For Virtual positions: Check if hit Virtual SL or TP
         if(m_active_trades[i].is_virtual)
         {
            if(m_active_trades[i].position_type == POSITION_TYPE_BUY)
            {
               if(m_active_trades[i].sl_price > 0 && bid <= m_active_trades[i].sl_price)
                  RecordExit(m_active_trades[i].ticket, m_active_trades[i].sl_price, "VIRTUAL_SL", 0.0);
               else if(m_active_trades[i].tp_price > 0 && bid >= m_active_trades[i].tp_price)
                  RecordExit(m_active_trades[i].ticket, m_active_trades[i].tp_price, "VIRTUAL_TP", 0.0);
            }
            else // SELL
            {
               if(m_active_trades[i].sl_price > 0 && ask >= m_active_trades[i].sl_price)
                  RecordExit(m_active_trades[i].ticket, m_active_trades[i].sl_price, "VIRTUAL_SL", 0.0);
               else if(m_active_trades[i].tp_price > 0 && ask <= m_active_trades[i].tp_price)
                  RecordExit(m_active_trades[i].ticket, m_active_trades[i].tp_price, "VIRTUAL_TP", 0.0);
            }
         }
      }
   }

   //+---------------------------------------------------------------+
   //| Record trade exit & flush record to CSV file                  |
   //+---------------------------------------------------------------+
   void RecordExit(const ulong ticket, const double close_price, const string exit_reason, const double pnl_money=0.0)
   {
      for(int i = 0; i < m_total_active; i++)
      {
         if(!m_active_trades[i].is_closed && m_active_trades[i].ticket == ticket)
         {
            double point = SymbolInfoDouble(m_active_trades[i].symbol, SYMBOL_POINT);
            m_active_trades[i].close_time  = TimeCurrent();
            m_active_trades[i].close_price = close_price;
            m_active_trades[i].exit_reason = exit_reason;
            m_active_trades[i].is_closed   = true;

            if(point > 0)
            {
               if(m_active_trades[i].position_type == POSITION_TYPE_BUY)
                  m_active_trades[i].pnl_points = (close_price - m_active_trades[i].open_price) / point;
               else
                  m_active_trades[i].pnl_points = (m_active_trades[i].open_price - close_price) / point;
            }

            m_active_trades[i].pnl_money = pnl_money;

            // Write to CSV
            FlushToCsv(m_active_trades[i]);
            break;
         }
      }
   }

   //+---------------------------------------------------------------+
   //| Append single finalized flight record to CSV file             |
   //+---------------------------------------------------------------+
   void FlushToCsv(const SBlackboxTrade &t)
   {
      int h = FileOpen(m_csv_filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
      if(h != INVALID_HANDLE)
      {
         FileSeek(h, 0, SEEK_END);
         long duration = (long)(t.close_time - t.open_time);

         FileWrite(h,
            IntegerToString(t.ticket),
            t.is_virtual ? "TRUE" : "FALSE",
            TimeToString(t.open_time, TIME_DATE | TIME_SECONDS),
            TimeToString(t.close_time, TIME_DATE | TIME_SECONDS),
            IntegerToString(duration),
            t.symbol,
            EnumToString(t.timeframe),
            (t.position_type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            DoubleToString(t.lot_size, 2),
            DoubleToString(t.open_price, 5),
            DoubleToString(t.close_price, 5),
            DoubleToString(t.sl_price, 5),
            DoubleToString(t.tp_price, 5),
            IntegerToString(t.spread_at_open),
            IntegerToString(t.slippage_points),
            IntegerToString(t.stoplevel_at_open),
            DoubleToString(t.mae_points, 1),
            DoubleToString(t.mfe_points, 1),
            DoubleToString(t.pnl_points, 1),
            DoubleToString(t.pnl_money, 2),
            t.exit_reason,
            "\"" + t.market_features + "\""
         );
         FileClose(h);
         PrintFormat("[Blackbox] Telemetry logged to CSV! Ticket: %I64u | PnL Points: %.1f | MAE: %.1f | MFE: %.1f | Reason: %s",
                     t.ticket, t.pnl_points, t.mae_points, t.mfe_points, t.exit_reason);
      }
   }
};
