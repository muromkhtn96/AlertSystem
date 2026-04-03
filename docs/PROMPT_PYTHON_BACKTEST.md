# PROMPT: Python MT5 Data Fetcher + Backtest Analyzer

**Mục đích:** Tạo script Python lấy dữ liệu từ MetaTrader 5 và phân tích CSV outcomes từ RP Logger.
**Khi nào dùng:** Paste prompt bên dưới vào Claude/ChatGPT khi cần tạo hoặc cập nhật script.

---

## PROMPT 1: Lấy dữ liệu OHLCV từ MT5

```
Tạo script Python "mt5_data_fetcher.py" với các yêu cầu:

### Mục tiêu
Kết nối MetaTrader 5 qua thư viện `MetaTrader5` (pip install MetaTrader5),
lấy dữ liệu OHLCV lịch sử và xuất ra CSV.

### Dependencies
- MetaTrader5 (pip install MetaTrader5)
- pandas
- argparse

### CLI Interface
python mt5_data_fetcher.py --symbol EURUSD --timeframe H1 --bars 10000 --output data/
python mt5_data_fetcher.py --symbol GBPUSD,CADJPY --timeframe H4 --months 6
python mt5_data_fetcher.py --symbol EURUSD --timeframe M15 --start 2025-01-01 --end 2025-06-30

### Arguments
- --symbol: 1 hoặc nhiều symbols, phân cách bằng dấu phẩy (default: EURUSD)
- --timeframe: M1, M5, M15, M30, H1, H4, D1, W1, MN1 (default: H1)
- --bars: số nến muốn lấy (default: 10000)
- --months: thay vì --bars, lấy N tháng gần nhất
- --start / --end: date range cụ thể (format: YYYY-MM-DD)
- --output: thư mục output (default: ./data/)
- --tick: nếu có flag này → lấy tick data thay vì OHLCV

### Logic chính
1. mt5.initialize() — nếu fail → print hướng dẫn: "Cần mở MT5 trước khi chạy script"
2. Validate symbol tồn tại: mt5.symbol_info(symbol)
3. Map timeframe string → mt5.TIMEFRAME_*
4. Lấy data:
   - OHLCV: mt5.copy_rates_from_pos() hoặc mt5.copy_rates_range()
   - Tick: mt5.copy_ticks_range()
5. Convert sang pandas DataFrame
6. Columns OHLCV: time, open, high, low, close, tick_volume, spread, real_volume
7. Convert time từ Unix timestamp → datetime
8. Export CSV: {symbol}_{timeframe}_{start}_{end}.csv
9. mt5.shutdown()

### Output format CSV
time,open,high,low,close,tick_volume,spread,real_volume
2025-01-02 00:00:00,1.10234,1.10456,1.10100,1.10350,1234,8,0

### Error handling
- MT5 chưa mở → message rõ ràng
- Symbol không tồn tại → list available symbols chứa keyword
- Không có data trong range → warning + suggest range khác
- Print tóm tắt sau khi xong: symbol, timeframe, số nến, date range, file size

### Bonus
- Thêm flag --info: in thông tin account, server, symbols available
- Thêm flag --spread-stats: tính avg/min/max spread từ data
- Progress bar nếu lấy nhiều symbols
```

---

## PROMPT 2: Phân tích CSV Outcomes từ RP Logger

```
Tạo script Python "rp_analyzer.py" để phân tích kết quả backtest
từ CSV files do RP Logger (MQL5 indicator) tạo ra.

### Mục tiêu
Đọc 3 file CSV (zones, tests, outcomes) → tính win rate, phân tích
theo từng yếu tố → xuất báo cáo + biểu đồ → đề xuất weight adjustments.

### Dependencies
- pandas, numpy, matplotlib, seaborn
- argparse

### CLI Interface
python rp_analyzer.py --log-dir "C:/Users/{user}/AppData/Roaming/MetaQuotes/Terminal/Common/Files/RP_Logs/"
python rp_analyzer.py --log-dir ./logs/ --symbol GBPUSD --timeframe H4
python rp_analyzer.py --log-dir ./logs/ --report full --output report/

### Input CSV Format

**{SYMBOL}_{PERIOD}_zones.csv** — Zone creation events:
timestamp, rp_id, type(SUPPORT/RESISTANCE), price, zone_high, zone_low,
zone_width_pips, atr14_pips, width_atr_ratio,
pattern(PINBAR/ENGULFING/OUTSIDE_BAR/LARGE_WICK),
reaction_pips, volume_ratio, session(SESSION_*), regime(REGIME_*),
has_wick_filter(Y/N), is_order_block(Y/N),
base_score, final_score, level(RP_PREMIUM/RP_LEVEL1/RP_LEVEL2/RP_LEVEL3/RP_HIDDEN)

**{SYMBOL}_{PERIOD}_tests.csv** — Zone test events:
rp_id, test_number, is_body_test(BODY/WICK),
test_volume, volume_vs_ma20,
zone_width_before, zone_width_after,
reaction_bar_low, reaction_bar_high, reaction_bar_close,
score_at_test

**{SYMBOL}_{PERIOD}_outcomes.csv** — Outcome measurement:
rp_id, type, score_at_test, test_count,
max_favorable_pips, max_adverse_pips, bars_to_max_favorable,
outcome(STRONG_REACT/WEAK_REACT/FAILED/BROKEN/NEUTRAL),
session, regime, pattern, has_wick_filter,
strong_tests, weak_tests, zone_width_pips, width_atr_ratio

### Outcome definitions
- STRONG_REACT: max_favorable >= 1×ATR → SUCCESS
- WEAK_REACT: max_favorable >= 0.5×ATR → PARTIAL SUCCESS
- FAILED: max_adverse >= 0.5×ATR → FAILURE
- BROKEN: zone hoàn toàn bị phá → FAILURE
- NEUTRAL: không rõ → bỏ qua

### Phân tích cần thực hiện

#### A. Tổng quan (Summary)
- Tổng zones, tổng tests, tổng outcomes
- Overall win rate: (STRONG_REACT + WEAK_REACT) / total (excl NEUTRAL)
- Strong win rate: STRONG_REACT / total (excl NEUTRAL)
- Avg max_favorable_pips, avg max_adverse_pips
- Profit factor: sum(max_favorable khi win) / sum(max_adverse khi loss)

#### B. Win rate theo Score Range
- Chia score thành bins: 0-39, 40-59, 60-84, 85-119, 120+
  (tương ứng HIDDEN, LEVEL3, LEVEL2, LEVEL1, PREMIUM)
- Mỗi bin: count, win rate, strong rate, avg favorable, avg adverse
- KỲ VỌNG: Premium >= 75% win rate, nếu không → cần tune

#### C. Win rate theo Factor
Pivot table win rate cho TỪNG yếu tố:
1. **Pattern**: PINBAR vs ENGULFING vs OUTSIDE_BAR vs LARGE_WICK
2. **Session**: ASIAN vs LONDON vs NY vs OVERLAP vs DEAD
3. **Regime**: STRONG_TREND vs WEAK_TREND vs RANGING vs CHOPPY
4. **Zone type**: SUPPORT vs RESISTANCE
5. **Volume ratio**: bins <1.0, 1.0-1.5, 1.5-2.0, 2.0+
6. **Width ATR ratio**: bins <0.3, 0.3-0.5, 0.5-0.8, 0.8+
7. **Test count**: 1st test vs 2nd vs 3rd+
8. **Body vs Wick test**: BODY vs WICK
9. **has_wick_filter**: Y vs N
10. **is_order_block**: Y vs N (nếu có data)
11. **Day of week** (from timestamp): Mon-Fri

#### D. Correlation Matrix
- Tính correlation giữa final_score và max_favorable_pips
- Tính correlation giữa mỗi factor score và outcome
- Nếu correlation < 0.1 → factor không hiệu quả → đề xuất giảm weight

#### E. Score Distribution
- Histogram: phân bố final_score
- Box plot: final_score theo outcome type
- Scatter: final_score vs max_favorable_pips

#### F. Đề xuất Weight Adjustment
Dựa trên kết quả, tự động đề xuất:
- Factor nào có win rate cao nhưng weight thấp → tăng
- Factor nào có win rate thấp nhưng weight cao → giảm
- Score threshold nào optimal (không nhất thiết 120 cho Premium)
- Session nào nên penalty nhiều hơn / ít hơn

### Output
1. Console: bảng tóm tắt dạng tabulate
2. CSV: raw analysis tables → {output}/analysis_summary.csv
3. PNG charts (nếu --charts flag):
   - win_rate_by_score.png
   - win_rate_by_factor.png (grouped bar chart)
   - score_distribution.png
   - score_vs_outcome_scatter.png
   - correlation_heatmap.png
4. TXT: weight adjustment recommendations → {output}/recommendations.txt

### Lưu ý quan trọng
- Join zones + outcomes qua rp_id
- Bỏ qua outcomes = NEUTRAL khi tính win rate
- Minimum sample size: chỉ hiển thị factor nếu count >= 20
- Format số: 2 decimal places cho rates, 1 cho pips
- Hỗ trợ multiple files: nếu log-dir có nhiều symbol/TF → gộp hoặc tách report
```

---

## PROMPT 3: Automated Backtest Pipeline (nâng cao)

```
Tạo script Python "rp_backtest_pipeline.py" kết hợp data fetching + analysis
thành một pipeline tự động.

### Mục tiêu
1-click pipeline: lấy data MT5 → đọc RP Logger CSV → phân tích → báo cáo

### Workflow
1. Kiểm tra MT5 đang chạy
2. Đọc CSV files từ RP_Logs folder (auto-detect symbol + TF từ filename)
3. Lấy OHLCV data tương ứng từ MT5 (cùng symbol, TF, date range)
4. Merge: map outcomes lên OHLCV data theo timestamp
5. Phân tích (dùng logic từ Prompt 2)
6. Thêm: vẽ zones lên price chart (matplotlib) để visual verify
7. Xuất báo cáo HTML (self-contained, mở trong browser)

### Visual chart output
- Candlestick chart (mplfinance) với:
  - Zone rectangles: xanh=support, đỏ=resistance
  - Opacity theo score: Premium=đậm, Level3=nhạt
  - Markers tại test points: ✓ = STRONG_REACT, ✗ = FAILED
  - Chỉ vẽ 200 nến gần nhất (configurable --chart-bars)

### HTML Report
- Summary stats table
- Interactive charts (plotly nếu có, fallback matplotlib PNG)
- Factor analysis tables
- Weight recommendations
- Mở auto trong browser sau khi generate

### CLI
python rp_backtest_pipeline.py --auto
python rp_backtest_pipeline.py --log-dir ./logs/ --chart-bars 500 --output report/

### Dependencies bắt buộc
pandas, numpy, matplotlib, mplfinance

### Dependencies tùy chọn (graceful fallback)
plotly, MetaTrader5, seaborn, tabulate
```

---

## GHI CHÚ SỬ DỤNG

### Thứ tự thực thi
```
Prompt 1 (data fetcher) → có thể dùng độc lập
Prompt 2 (analyzer)     → cần CSV từ RP Logger (MT5 Strategy Tester)
Prompt 3 (pipeline)     → kết hợp 1+2, chạy khi đã có cả MT5 data + CSV logs
```

### Cách dùng
1. Copy prompt cần dùng
2. Paste vào Claude Code / ChatGPT
3. AI sẽ tạo script Python hoàn chỉnh
4. Cài dependencies: `pip install MetaTrader5 pandas numpy matplotlib mplfinance seaborn`
5. Chạy script theo CLI examples

### Yêu cầu hệ thống
- Windows (MetaTrader5 Python chỉ hỗ trợ Windows)
- Python 3.8+
- MT5 terminal đang mở (cho Prompt 1 và 3)
- CSV files từ RP Logger (cho Prompt 2 và 3)
