# HƯỚNG DẪN PHÂN TÍCH LOG & TINH CHỈNH SCORING
## Reaction Point Indicator v3.0 — Data-Driven Optimization

---

## MỤC LỤC

1. [Tổng quan quy trình](#1-tổng-quan-quy-trình)
2. [Thu thập dữ liệu](#2-thu-thập-dữ-liệu)
3. [Cấu trúc file CSV](#3-cấu-trúc-file-csv)
4. [Phân tích cơ bản (Excel)](#4-phân-tích-cơ-bản-excel)
5. [Phân tích nâng cao (Python)](#5-phân-tích-nâng-cao-python)
6. [Cách đọc kết quả](#6-cách-đọc-kết-quả)
7. [Tinh chỉnh scoring weights](#7-tinh-chỉnh-scoring-weights)
8. [Quy trình lặp lại](#8-quy-trình-lặp-lại)
9. [Checklist trước khi chỉnh code](#9-checklist-trước-khi-chỉnh-code)

---

## 1. TỔNG QUAN QUY TRÌNH

```
THU THẬP          PHÂN TÍCH           TINH CHỈNH          KIỂM CHỨNG
─────────         ─────────           ──────────           ──────────
Bật Logger   →   Mở CSV trong    →   Sửa weights     →   Chạy lại Logger
Chạy 500+        Excel/Python        trong code           So sánh win rate
zone events      Tính win rate       Compile lại          trước/sau
                 theo từng yếu tố
```

**Nguyên tắc vàng:** Chỉ thay đổi 1-2 weights mỗi lần. Thay đổi quá nhiều
cùng lúc thì không biết cái nào thực sự cải thiện.

---

## 2. THU THẬP DỮ LIỆU

### 2.1. Cách bật Logger

Trong MT5, khi thêm indicator vào chart:
- `Enable_Logger` = **true**
- `Outcome_Measure_Bars` = **20** (hoặc tùy TF)

### 2.2. Hai phương pháp thu thập

| Phương pháp | Ưu điểm | Nhược điểm | Thời gian |
|---|---|---|---|
| **Strategy Tester** | Nhanh, nhiều data, test 6-12 tháng | Không có real spread/volume | 5-10 phút |
| **Demo live** | Data thực, spread thực | Chậm, cần 2-4 tuần | 2-4 tuần |

**Khuyến nghị:** Chạy Strategy Tester trước (6 tháng), rồi validate bằng demo live (2 tuần).

### 2.3. Cách dùng Strategy Tester cho indicator

1. MT5 → View → Strategy Tester
2. Chọn loại: **Indicator** (không phải Expert Advisor)
3. Chọn indicator: RP_Main
4. Symbol: GBPUSD hoặc CADJPY
5. Timeframe: H4 (hoặc TF đang dùng)
6. Date range: 6 tháng gần nhất
7. Chế độ: **Every tick** (chính xác nhất) hoặc **Open prices only** (nhanh)
8. Bật Visual Mode nếu muốn xem chart
9. Bấm Start

### 2.4. Bao nhiêu data là đủ?

| Mức | Số zone events | Tin cậy | Đủ cho |
|---|---|---|---|
| Tối thiểu | 200+ | Thấp | Phát hiện lỗi lớn |
| Khuyến nghị | 500+ | Trung bình | Tinh chỉnh cơ bản |
| Lý tưởng | 1000+ | Cao | Tinh chỉnh chi tiết |

### 2.5. File output ở đâu?

```
Windows: C:\Users\{username}\AppData\Roaming\MetaQuotes\Terminal\Common\Files\RP_Logs\
```

Hoặc trong MT5: File → Open Data Folder → MQL5 → Files → RP_Logs

### 2.6. Log tự quản lý như thế nào?

| Hành vi | Chi tiết |
|---|---|
| **Append mode** | Data tích lũy qua nhiều sessions — không mất data khi restart indicator |
| **Header tự động** | Chỉ viết header khi file mới, không viết lại header khi append |
| **Auto rotation** | Khi file > 10 MB → xóa file cũ, tạo file mới (tránh file quá lớn) |
| **Không tự xóa** | Log tồn tại vĩnh viễn cho đến khi bạn xóa thủ công hoặc file đạt 10 MB |

**Xóa thủ công:** Vào thư mục RP_Logs, xóa các file `.csv` không cần nữa.

**Thay đổi giới hạn size:** Sửa `g_log_max_size_mb` trong RP_Logger.mqh (mặc định 10 MB).

**Ước tính dung lượng:**

| Thời gian chạy | Số zones (H4) | File size ước tính |
|---|---|---|
| 1 tuần | ~50-100 | ~20-50 KB |
| 1 tháng | ~200-400 | ~100-200 KB |
| 6 tháng | ~1,000-2,000 | ~500 KB - 1 MB |
| 2 năm+ | ~4,000+ | ~2-4 MB |

→ Với giới hạn 10 MB, thực tế **không bao giờ cần rotation** trên H4.
   Rotation chỉ cần thiết trên M5/M15 chạy lâu dài.

---

## 3. CẤU TRÚC FILE CSV

### 3.1. zones.csv — Mỗi zone được tạo

| Column | Ý nghĩa | Dùng để |
|---|---|---|
| timestamp | Thời gian tạo zone | Filter theo ngày/giờ |
| rp_id | ID duy nhất | Join với tests/outcomes |
| type | SUPPORT / RESISTANCE | So sánh win rate S vs R |
| price | Giá swing point | Tham khảo |
| zone_high, zone_low | Biên zone | Tính zone width |
| zone_width_pips | Độ rộng zone (pips) | **KEY:** zone hẹp vs rộng |
| atr14_pips | ATR tại thời điểm tạo | Normalize zone width |
| width_atr_ratio | zone_width / ATR | **KEY:** < 0.3 là hẹp, > 0.8 là rộng |
| pattern | PINBAR / ENGULFING / ... | **KEY:** pattern nào hiệu quả? |
| reaction_pips | Lực phản ứng ban đầu | **KEY:** reaction mạnh = zone tốt? |
| volume_ratio | Volume / MA20 | **KEY:** volume cao = zone tốt? |
| session | SESSION_LONDON / ... | **KEY:** session nào tạo zone tốt? |
| regime | REGIME_STRONG_TREND / ... | **KEY:** regime nào tạo zone tốt? |
| has_wick_filter | Y/N | Wick filter có cải thiện? |
| base_score | 0-100 | Kiểm tra scoring distribution |
| final_score | 0-150 | **KEY:** score cao = win rate cao? |
| level | RP_PREMIUM / RP_LEVEL1 / ... | Kiểm tra level distribution |

### 3.2. tests.csv — Mỗi lần zone bị test

| Column | Ý nghĩa | Dùng để |
|---|---|---|
| rp_id | ID zone | Join với zones/outcomes |
| test_number | Lần test thứ mấy | Test thứ mấy hiệu quả nhất? |
| is_body_test | BODY / WICK | **KEY:** body test win rate vs wick |
| test_volume | Tick volume lúc test | Volume tăng hay giảm? |
| volume_vs_ma20 | Volume / MA20 | Normalize volume |
| zone_width_before | Width trước refinement | Refinement có hiệu quả? |
| zone_width_after | Width sau refinement | Zone thu hẹp bao nhiêu? |
| score_at_test | Score tại thời điểm test | Score thay đổi qua tests? |

### 3.3. outcomes.csv — Kết quả sau N bars

| Column | Ý nghĩa | Dùng để |
|---|---|---|
| rp_id | ID zone | Join ngược lại |
| score_at_test | Final score khi test | **KEY CHÍNH:** score vs outcome |
| max_favorable_pips | Di chuyển tốt nhất (pips) | Đo lường hiệu quả thực |
| max_adverse_pips | Di chuyển xấu nhất (pips) | Đo lường rủi ro |
| bars_to_max_favorable | Bao nhiêu bars đạt peak | Timing |
| outcome | STRONG_REACT / WEAK_REACT / FAILED / NEUTRAL / BROKEN | **KPI CHÍNH** |
| strong_tests | Số body tests | Test quality ảnh hưởng? |
| weak_tests | Số wick tests | Test quality ảnh hưởng? |
| zone_width_pips | Width tại thời điểm test | Zone hẹp/rộng vs outcome |
| width_atr_ratio | Width / ATR | Normalize |

---

## 4. PHÂN TÍCH CƠ BẢN (EXCEL)

### 4.1. Mở file và chuẩn bị

1. Mở `outcomes.csv` trong Excel
2. Chuyển sang Table (Ctrl+T)
3. Thêm cột mới: `is_success` = `IF(OR(outcome="STRONG_REACT", outcome="WEAK_REACT"), 1, 0)`

### 4.2. Pivot Table — Win Rate theo Score Range

1. Insert → PivotTable
2. Rows: tạo cột `score_bucket` = `IF(score_at_test>=110,"PREMIUM",IF(score_at_test>=80,"LEVEL1",IF(score_at_test>=60,"LEVEL2",IF(score_at_test>=40,"LEVEL3","HIDDEN"))))`
3. Values: Average of `is_success`

**Kết quả mong đợi:**

| Score Range | Win Rate | Đánh giá |
|---|---|---|
| PREMIUM (110+) | > 70% | Scoring hoạt động tốt |
| LEVEL1 (80-109) | > 55% | OK |
| LEVEL2 (60-79) | > 45% | Trung bình |
| LEVEL3 (40-59) | < 40% | Đúng — zone yếu |

**Nếu win rate không tăng theo score → scoring weights cần sửa.**

### 4.3. Pivot Table — Win Rate theo từng yếu tố

Lặp lại bước trên cho mỗi yếu tố:

| Phân tích | Row field | Câu hỏi trả lời |
|---|---|---|
| Session | session | Session nào tạo zone hiệu quả nhất? |
| Pattern | pattern | Pinbar có thực sự tốt hơn? |
| Regime | regime | Trending hay ranging zone tốt hơn? |
| Wick filter | has_wick_filter | Wick filter có cải thiện win rate? |
| Test quality | `IF(strong_tests>weak_tests,"STRONG","WEAK")` | Body test quan trọng hơn? |
| Zone width | `IF(width_atr_ratio<0.3,"TIGHT",IF(width_atr_ratio>0.8,"WIDE","MEDIUM"))` | Zone hẹp có tốt hơn? |

### 4.4. Scatter Plot — Score vs Max Favorable Pips

1. Insert → Scatter
2. X: score_at_test
3. Y: max_favorable_pips
4. Thêm trendline → xem R² (correlation)

**R² > 0.3:** Score tương quan tốt với hiệu quả
**R² < 0.1:** Score không dự đoán được hiệu quả → cần sửa weights

---

## 5. PHÂN TÍCH NÂNG CAO (PYTHON)

### 5.1. Script cơ bản

```python
import pandas as pd
import numpy as np

# Load data
outcomes = pd.read_csv('GBPUSD_PERIOD_H4_outcomes.csv')
zones = pd.read_csv('GBPUSD_PERIOD_H4_zones.csv')
tests = pd.read_csv('GBPUSD_PERIOD_H4_tests.csv')

# Merge zones + outcomes
df = outcomes.merge(zones[['rp_id','pattern','session','regime','volume_ratio',
                           'reaction_pips','has_wick_filter','width_atr_ratio']],
                    on='rp_id', how='left', suffixes=('','_zone'))

# Binary success
df['success'] = df['outcome'].isin(['STRONG_REACT','WEAK_REACT']).astype(int)

print("=== OVERALL WIN RATE ===")
print(f"Total: {len(df)}, Win: {df['success'].sum()}, "
      f"Rate: {df['success'].mean():.1%}")
```

### 5.2. Win rate theo score buckets

```python
bins = [0, 40, 60, 80, 110, 150]
labels = ['HIDDEN','LEVEL3','LEVEL2','LEVEL1','PREMIUM']
df['level'] = pd.cut(df['score_at_test'], bins=bins, labels=labels)

print("\n=== WIN RATE BY SCORE LEVEL ===")
print(df.groupby('level')['success'].agg(['count','mean'])
        .rename(columns={'count':'zones','mean':'win_rate'})
        .to_string())
```

### 5.3. Feature importance — yếu tố nào quan trọng nhất?

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score

features = ['score_at_test','zone_width_pips','width_atr_ratio',
            'strong_tests','weak_tests','test_count']

# Encode categoricals
for col in ['session','regime','pattern','has_wick_filter']:
    if col in df.columns:
        df[col + '_enc'] = df[col].astype('category').cat.codes
        features.append(col + '_enc')

X = df[features].fillna(0)
y = df['success']

rf = RandomForestClassifier(n_estimators=100, random_state=42)
scores = cross_val_score(rf, X, y, cv=5, scoring='accuracy')
print(f"\n=== MODEL ACCURACY: {scores.mean():.1%} ===")

rf.fit(X, y)
importance = pd.Series(rf.feature_importances_, index=features)
print("\n=== FEATURE IMPORTANCE ===")
print(importance.sort_values(ascending=False).to_string())
```

### 5.4. Tìm threshold tối ưu cho từng yếu tố

```python
print("\n=== WIN RATE BY SESSION ===")
print(df.groupby('session')['success'].agg(['count','mean'])
        .sort_values('mean', ascending=False).to_string())

print("\n=== WIN RATE BY PATTERN ===")
print(df.groupby('pattern')['success'].agg(['count','mean'])
        .sort_values('mean', ascending=False).to_string())

print("\n=== WIN RATE BY REGIME ===")
print(df.groupby('regime')['success'].agg(['count','mean'])
        .sort_values('mean', ascending=False).to_string())

print("\n=== WIN RATE BY WICK FILTER ===")
print(df.groupby('has_wick_filter')['success'].agg(['count','mean']).to_string())

# Zone width buckets
df['width_bucket'] = pd.cut(df['width_atr_ratio'],
    bins=[0, 0.2, 0.3, 0.5, 0.8, 2.0],
    labels=['<0.2','0.2-0.3','0.3-0.5','0.5-0.8','>0.8'])
print("\n=== WIN RATE BY ZONE WIDTH (ATR ratio) ===")
print(df.groupby('width_bucket')['success'].agg(['count','mean']).to_string())

# Body vs Wick test dominance
df['test_type'] = np.where(df['strong_tests'] > df['weak_tests'],
                           'BODY_DOMINANT', 'WICK_DOMINANT')
print("\n=== WIN RATE BY TEST QUALITY ===")
print(df.groupby('test_type')['success'].agg(['count','mean']).to_string())
```

### 5.5. So sánh GBPUSD vs CADJPY

```python
gbp = pd.read_csv('GBPUSD_PERIOD_H4_outcomes.csv')
cad = pd.read_csv('CADJPY_PERIOD_H4_outcomes.csv')
gbp['pair'] = 'GBPUSD'
cad['pair'] = 'CADJPY'
both = pd.concat([gbp, cad])
both['success'] = both['outcome'].isin(['STRONG_REACT','WEAK_REACT']).astype(int)

print("=== WIN RATE BY PAIR ===")
print(both.groupby('pair')['success'].agg(['count','mean']).to_string())

print("\n=== WIN RATE BY PAIR x SESSION ===")
print(both.groupby(['pair','session'])['success'].agg(['count','mean'])
         .sort_values('mean', ascending=False).to_string())
```

---

## 6. CÁCH ĐỌC KẾT QUẢ

### 6.1. Kịch bản phổ biến và cách xử lý

**Kịch bản A: Score cao nhưng win rate không cao**
```
PREMIUM: 45% win rate  ← vấn đề!
LEVEL1:  42% win rate
LEVEL2:  38% win rate
```
→ Scoring không phản ánh thực tế. Xem feature importance để biết yếu tố nào
  đang được weight quá cao so với thực tế.

**Kịch bản B: Win rate tăng theo score nhưng PREMIUM không đủ cao**
```
PREMIUM: 55% win rate  ← muốn > 65%
LEVEL1:  48% win rate
LEVEL2:  35% win rate
```
→ Scoring đúng hướng nhưng cần siết threshold. Tăng ngưỡng PREMIUM từ 110 lên 120,
  hoặc thêm điều kiện phụ (e.g., phải có ít nhất 1 strong test).

**Kịch bản C: Một yếu tố có win rate cao bất ngờ**
```
SESSION_ASIAN + CADJPY: 68% win rate (n=45)
```
→ Asian session penalty (-10 + 7 JPY bonus = -3) có thể quá nặng cho CADJPY.
  Xem xét giảm penalty hoặc thêm pair-specific bonus.

**Kịch bản D: Một yếu tố không ảnh hưởng**
```
Round Number <= 10 pips: 44% win rate
Round Number > 20 pips:  43% win rate
```
→ Round Number bonus (+8) không tạo ra sự khác biệt thực tế.
  Có thể giảm weight từ 8 xuống 4, hoặc bỏ hoàn toàn.

### 6.2. Bảng quyết định

| Phát hiện | Hành động | File sửa | Rủi ro |
|---|---|---|---|
| Yếu tố X win rate cao hơn weight hiện tại | Tăng weight X | RP_Scoring.mqh | Thấp |
| Yếu tố X win rate thấp hơn weight hiện tại | Giảm weight X | RP_Scoring.mqh | Thấp |
| Yếu tố X không ảnh hưởng (win rate ~= overall) | Giảm về 0 hoặc bỏ | RP_Scoring.mqh | Trung bình |
| Session A win rate khác biệt cho pair B | Thêm pair-specific adj | RP_Session.mqh | Thấp |
| Score threshold không phân tách tốt | Điều chỉnh ngưỡng level | RP_Utils.mqh (ClassifyRPLevel) | Trung bình |
| Zone width X hiệu quả nhất | Điều chỉnh ATR multiplier | RP_Detection.mqh | Trung bình |

---

## 7. TINH CHỈNH SCORING WEIGHTS

### 7.1. Nguyên tắc

1. **Chỉ sửa 1-2 weights mỗi lần** — nếu sửa nhiều, không biết cái nào thực sự hiệu quả
2. **Giữ tổng Base Score max ~100** — nếu tăng 1 yếu tố, giảm yếu tố khác
3. **Test trên cùng data range** — so sánh trước/sau trên cùng 6 tháng
4. **Cẩn thận overfitting** — nếu chỉ có 200 zones, kết quả có thể do ngẫu nhiên

### 7.2. Bảng weights hiện tại và cách sửa

| Yếu tố | File | Dòng code | Weight hiện tại | Cách sửa |
|---|---|---|---|---|
| Reaction Strength | RP_Scoring.mqh | `* 35.0, 35.0` | max 35 | Đổi 35.0 → X |
| Test Quality | RP_Scoring.mqh | CalcTestQualityScore() | max 25 | Sửa return values |
| Candle Pattern | RP_Scoring.mqh | switch(rp.candle_pattern) | 12/10/8/6 | Sửa từng giá trị |
| Fibonacci | RP_Scoring.mqh | CalcFibonacciScore() | 10/8/7/4 | Sửa từng giá trị |
| Volume | RP_Scoring.mqh | CalcVolumeScore() | 15/8 | Sửa threshold & score |
| Round Number | RP_Scoring.mqh | RoundNumberScore() | 8/4 | Sửa giá trị |
| Volume Delta | RP_Scoring.mqh | CalcVolumeDeltaBonus() | ±5 | Sửa 5.0 → X |
| Zone Precision | RP_Scoring.mqh | CalcZonePrecisionScore() | +5/+5/+3/-5 | Sửa từng giá trị |
| Regime adj | RP_RegimeFilter.mqh | GetRegimeScoreAdj() | [-30,+20] | Sửa return values |
| Session adj | RP_Session.mqh | GetSessionScoreAdj() | [-20,+15] | Sửa adj values |
| Structure adj | RP_MarketStructure.mqh | GetStructureScoreAdj() | [-20,+15] | Sửa return values |
| Absorption | RP_Scoring.mqh | CalcAbsorptionAdj() | [-10,+5] | Sửa thresholds & returns |
| Level thresholds | RP_Utils.mqh | ClassifyRPLevel() | 110/80/60/40 | Sửa ngưỡng |

### 7.3. Ví dụ tinh chỉnh thực tế

**Giả sử data cho thấy:**
- Pinbar win rate = 62%, Engulfing = 58%, Large Wick = 44%, None = 41%
- Round Number win rate = 43% (gần = overall 42%)

**Hành động:**
```
Trước:  PATTERN_PINBAR: 12,  PATTERN_LARGE_WICK: 6, RoundNumber max: 8
Sau:    PATTERN_PINBAR: 15,  PATTERN_LARGE_WICK: 3, RoundNumber max: 4

Lý do: Pinbar thực sự hiệu quả → tăng weight
       Large Wick không khác mấy vs None → giảm
       Round Number không ảnh hưởng → giảm một nửa
       Tổng thay đổi: +3 -3 -4 = -4 → có thể phân bổ cho yếu tố khác
```

---

## 8. QUY TRÌNH LẶP LẠI

```
Vòng 1: Thu thập data gốc (code chưa sửa)
  → Phân tích → Tìm 1-2 weights cần sửa
  → Sửa code → Compile

Vòng 2: Thu thập data mới (code đã sửa)
  → So sánh win rate trước/sau
  → Nếu cải thiện → giữ thay đổi
  → Nếu không cải thiện hoặc xấu hơn → revert

Vòng 3: Lặp lại cho 1-2 weights tiếp theo
```

### So sánh trước/sau

```python
# Load both runs
before = pd.read_csv('run1_outcomes.csv')
after  = pd.read_csv('run2_outcomes.csv')

for df, label in [(before,'BEFORE'), (after,'AFTER')]:
    df['success'] = df['outcome'].isin(['STRONG_REACT','WEAK_REACT']).astype(int)
    bins = [0, 40, 60, 80, 110, 150]
    labels_l = ['HIDDEN','LEVEL3','LEVEL2','LEVEL1','PREMIUM']
    df['level'] = pd.cut(df['score_at_test'], bins=bins, labels=labels_l)
    print(f"\n=== {label} ===")
    print(df.groupby('level')['success'].agg(['count','mean']).to_string())
```

### Metrics cần theo dõi qua các vòng

| Metric | Mục tiêu | Cách tính |
|---|---|---|
| Overall win rate | > 50% | success / total |
| PREMIUM win rate | > 65% | success / total where level=PREMIUM |
| Score-win correlation | R² > 0.2 | scipy.stats.pearsonr |
| False positive rate | < 30% | FAILED / total where level>=LEVEL1 |
| Zone efficiency | > 1.5 | avg(max_favorable) / avg(max_adverse) |

---

## 9. CHECKLIST TRƯỚC KHI CHỈNH CODE

- [ ] Có ít nhất 500 zone events trong data?
- [ ] Win rate theo score level có xu hướng tăng rõ ràng?
- [ ] Yếu tố cần sửa có sample size >= 50?
- [ ] Đã xác nhận không phải do ngẫu nhiên (p-value < 0.05 nếu dùng Python)?
- [ ] Chỉ sửa tối đa 1-2 weights?
- [ ] Đã backup code trước khi sửa?
- [ ] Đã lên kế hoạch chạy lại Logger sau khi sửa?

**Nếu bất kỳ checkbox nào chưa tick → CHƯA sửa code.**

---

## PHỤ LỤC: Quick Reference

### Outcome classification

| Outcome | Điều kiện | Coi là |
|---|---|---|
| STRONG_REACT | Favorable >= 1.0x ATR | Win |
| WEAK_REACT | Favorable >= 0.5x ATR | Win |
| FAILED | Adverse >= 0.5x ATR | Loss |
| NEUTRAL | Không đáng kể | Ignore |
| BROKEN | Breakout confirmed | Loss |

### File locations

| File | Nội dung | Key columns |
|---|---|---|
| *_zones.csv | Zone được tạo | pattern, session, regime, width_atr_ratio |
| *_tests.csv | Mỗi lần test | is_body_test, test_volume, zone_width_after |
| *_outcomes.csv | Kết quả | outcome, score_at_test, max_favorable_pips |

### Scoring files cần sửa

| Sửa gì | File |
|---|---|
| Base score weights | RP_Scoring.mqh |
| Session adjustments | RP_Session.mqh |
| Regime adjustments | RP_RegimeFilter.mqh |
| Structure adjustments | RP_MarketStructure.mqh |
| Level thresholds | RP_Utils.mqh → ClassifyRPLevel() |
| Zone width params | RP_Detection.mqh → CreateRP() |
