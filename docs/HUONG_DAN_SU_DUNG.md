# HƯỚNG DẪN CÀI ĐẶT VÀ SỬ DỤNG
## Reaction Point Indicator v3.0 — MetaTrader 5

---

## MỤC LỤC

1. [Yêu cầu hệ thống](#1-yêu-cầu-hệ-thống)
2. [Cài đặt](#2-cài-đặt)
3. [Thêm chỉ báo vào biểu đồ](#3-thêm-chỉ-báo-vào-biểu-đồ)
4. [Cấu hình tham số](#4-cấu-hình-tham-số)
5. [Hiểu giao diện](#5-hiểu-giao-diện)
6. [Hệ thống chấm điểm](#6-hệ-thống-chấm-điểm)
7. [Hệ thống cảnh báo](#7-hệ-thống-cảnh-báo)
8. [Gợi ý Entry Setup](#8-gợi-ý-entry-setup)
9. [Cách sử dụng trong giao dịch](#9-cách-sử-dụng-trong-giao-dịch)
10. [Preset theo khung thời gian](#10-preset-theo-khung-thời-gian)
11. [Xử lý sự cố](#11-xử-lý-sự-cố)
12. [Câu hỏi thường gặp](#12-câu-hỏi-thường-gặp)

---

## 1. YÊU CẦU HỆ THỐNG

| Yêu cầu | Chi tiết |
|----------|----------|
| Nền tảng | **MetaTrader 5** (build 2500 trở lên khuyến nghị) |
| Hệ điều hành | Windows 7/10/11 |
| Thị trường | Forex (tất cả các cặp tiền) |
| Khung thời gian | M30 trở lên (khuyến nghị H1, H4) |
| Kết nối | Internet ổn định (cần cho bộ lọc tin tức Calendar API) |

---

## 2. CÀI ĐẶT

### Bước 1: Mở thư mục dữ liệu MetaTrader 5

Trong MetaTrader 5, vào menu **File → Open Data Folder** (hoặc nhấn `Ctrl+Shift+D`).

### Bước 2: Sao chép file

Sao chép **2 thư mục** vào thư mục dữ liệu MT5 (Data Folder) sao cho cấu trúc như sau:

```
<MT5 Data Folder>/
└── MQL5/
    ├── Indicators/
    │   └── ReactionPoint/
    │       └── RP_Main.mq5              ← File chỉ báo chính
    │
    └── Include/
        └── ReactionPoint/
            ├── RP_Defines.mqh           ← Định nghĩa enum, struct, hằng số
            ├── RP_Utils.mqh             ← Hàm tiện ích
            ├── RP_Detection.mqh         ← Phát hiện swing point
            ├── RP_Scoring.mqh           ← Tính điểm
            ├── RP_RegimeFilter.mqh      ← Module A: Lọc xu hướng ADX
            ├── RP_DynamicDecay.mqh      ← Module B: Giảm điểm theo thời gian
            ├── RP_EntrySetup.mqh        ← Module C: Gợi ý vào lệnh
            ├── RP_Confluence.mqh        ← Module D: Hợp lưu đa khung
            ├── RP_Session.mqh           ← Module E: Phiên giao dịch
            ├── RP_NewsFilter.mqh        ← Module F: Lọc tin tức
            ├── RP_SpreadFilter.mqh      ← Module G: Lọc spread
            ├── RP_MarketStructure.mqh   ← Module H: Cấu trúc thị trường
            ├── RP_Drawing.mqh           ← Vẽ vùng RP trên chart
            ├── RP_Dashboard.mqh         ← Bảng thông tin
            ├── RP_Alerts.mqh            ← Hệ thống cảnh báo
            ├── RP_Stats.mqh             ← Thống kê hiệu suất
            └── RP_Logger.mqh            ← Ghi log hệ thống
```

> **Lưu ý quan trọng:** Các file `.mqh` phải nằm trong `MQL5/Include/ReactionPoint/` (không phải trong `Indicators/`), vì code sử dụng `#include <ReactionPoint/...>` — MQL5 tìm file include trong thư mục `Include/` mặc định.

**Cách copy nhanh:**

1. Từ thư mục dự án, copy `MQL5/Indicators/ReactionPoint/` → `<Data Folder>/MQL5/Indicators/ReactionPoint/`
2. Copy `MQL5/Include/ReactionPoint/` → `<Data Folder>/MQL5/Include/ReactionPoint/`

### Bước 3: Biên dịch (Compile)

1. Mở **MetaEditor** (nhấn `F4` trong MT5)
2. Trong Navigator bên trái, tìm đến `Indicators\ReactionPoint\RP_Main.mq5`
3. Nhấn đúp để mở file, sau đó nhấn **Compile** (`F7`)
4. Đảm bảo không có lỗi (error) — cảnh báo (warning) có thể bỏ qua
5. Đóng MetaEditor

### Bước 4: Cấp quyền Calendar API (cho bộ lọc tin tức)

1. Trong MT5: **Tools → Options → Expert Advisors**
2. Đánh dấu **Allow WebRequest for listed URL** (nếu cần)
3. Đảm bảo quyền **Calendar** được bật trong tài khoản demo/live

---

## 3. THÊM CHỈ BÁO VÀO BIỂU ĐỒ

### Cách 1: Từ Navigator

1. Mở cửa sổ **Navigator** (`Ctrl+N`)
2. Mở rộng **Indicators → ReactionPoint**
3. Kéo thả **RP_Main** vào biểu đồ mong muốn

### Cách 2: Từ Menu

1. Vào **Insert → Indicators → Custom → ReactionPoint → RP_Main**

### Lưu ý khi thêm

- Cửa sổ cài đặt sẽ tự động hiện ra
- Tab **Common**: đảm bảo **Allow DLL imports** được tắt (không cần DLL)
- Tab **Inputs**: điều chỉnh tham số (xem phần 4)
- Nhấn **OK** để xác nhận

---

## 4. CẤU HÌNH THAM SỐ

### 4.1 Preset — Bắt đầu nhanh (Khuyến nghị)

Tham số quan trọng nhất là **TF_Preset** — tự động cấu hình mọi thứ theo khung thời gian:

| Preset | Mô tả | Khi nào dùng |
|--------|--------|---------------|
| **AUTO** (mặc định) | Tự detect khung thời gian hiện tại | Phù hợp hầu hết trader |
| **M30** | Tối ưu cho scalping/intraday | Giao dịch ngắn hạn |
| **H1** | Tối ưu cho intraday | Giao dịch trong ngày |
| **H4** | Tối ưu cho swing trading | Giao dịch trung hạn |
| **D1** | Tối ưu cho position trading | Giao dịch dài hạn |
| **CUSTOM** | Tự điều chỉnh tất cả tham số | Trader nâng cao |

> **Với người mới:** Chỉ cần giữ `PRESET_AUTO` và nhấn OK. Chỉ báo sẽ tự cấu hình phù hợp.

### 4.2 Nhóm tham số chính

#### A. Phát hiện Swing (Swing Detection)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Swing_Lookback` | 3 | Số nến trái/phải để xác nhận swing. Tăng = ít RP hơn nhưng chất lượng cao hơn |
| `Min_RP_Distance_Pips` | 20 | Khoảng cách tối thiểu giữa 2 RP (pip). Tránh trùng lặp |
| `Min_Reaction_Move_Pips` | 15 | Giá phải di chuyển ít nhất bao nhiêu pip sau swing để xác nhận RP |
| `Initial_Bars_To_Scan` | 500 | Số nến quét lần đầu. Tăng = nhiều RP lịch sử hơn |
| `Use_Adaptive_Reaction` | true | Dùng ATR thay vì pip cố định cho reaction move |
| `Reaction_ATR_Multiplier` | 0.5 | Hệ số ATR: 0.5 = cần di chuyển ≥ 50% ATR |

#### B. Breakout & Role Reversal

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Breakout_Confirm_Pips` | 5 | Giá phải đóng cửa vượt RP bao nhiêu pip để xác nhận phá vỡ |
| `Max_Retest_Bars` | 50 | Số nến tối đa để phát hiện retest sau breakout |

#### C. Module A — Lọc xu hướng (Market Regime)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `ADX_Period` | 14 | Chu kỳ tính ADX |
| `ADX_Strong_Threshold` | 25.0 | ADX > 25 = xu hướng mạnh |
| `ADX_Weak_Threshold` | 20.0 | ADX 20–25 = xu hướng yếu |
| `Use_Regime_Filter` | true | Bật/tắt điều chỉnh điểm theo xu hướng |

> **Lưu ý:** Khi xu hướng mạnh, RP cùng chiều xu hướng được **+20 điểm**, ngược chiều bị **-30 điểm**.

#### D. Module B — Giảm điểm theo thời gian (Dynamic Decay)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Decay_Interval_Bars` | 20 | Mỗi N nến, RP mất điểm |
| `Decay_Points_Per_Interval` | 2 | Số điểm mất mỗi lần |
| `Max_RP_Age_Bars` | 300 | RP cũ hơn N nến sẽ bị ẩn/xóa |
| `Use_Dynamic_Score` | true | Bật/tắt cơ chế giảm điểm |

#### E. Module C — Gợi ý vào lệnh (Entry Setup)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Show_Entry_Setup` | true | Hiển thị gợi ý BUY/SELL |
| `SL_Buffer_Pips` | 5 | Buffer dưới/trên swing cho Stop Loss |
| `Entry_Buffer_Pips` | 2 | Buffer trên/dưới nến tín hiệu cho Entry |
| `Min_RR_Ratio` | 1.5 | Tỷ lệ R:R tối thiểu (chỉ hiện setup nếu ≥ 1:1.5) |
| `Max_Setup_Age_Bars` | 10 | Setup tự hết hạn sau N nến |

#### F. Module D — Hợp lưu đa khung (Confluence)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Use_Confluence_Zones` | true | Bật phát hiện vùng hợp lưu |
| `Confluence_Merge_Pips` | 10 | Gộp các RP trong khoảng N pip thành 1 vùng |
| `HTF_Bars_To_Scan` | 200 | Số nến quét trên khung cao hơn |
| `Show_HTF_1` / `HTF_1` | true / H4 | Khung thời gian cao hơn thứ 1 |
| `Show_HTF_2` / `HTF_2` | true / D1 | Khung thời gian cao hơn thứ 2 |

#### G. Module E — Phiên giao dịch (Sessions)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `UTC_Offset` | 3 | Offset UTC của broker (broker Việt Nam thường +7) |
| `Alert_Only_Active_Sessions` | true | Chỉ cảnh báo trong phiên hoạt động |
| `Show_Session_Background` | true | Tô màu nền theo phiên |

> **Quan trọng:** Kiểm tra UTC offset của broker trong **Market Watch → chuột phải → Specification → Trade time**. Broker ICMarkets thường +3, Exness thường +0.

#### H. Module F — Lọc tin tức (News Filter)

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Use_News_Filter` | true | Bật lọc tin tức từ Calendar |
| `News_Blackout_Minutes` | 30 | Chặn tín hiệu 30 phút trước/sau tin quan trọng |
| `News_Filter_High_Only` | false | true = chỉ lọc tin HIGH impact |

#### I. Module G — Lọc Spread

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Use_Spread_Filter` | true | Theo dõi và chặn spread cao |
| `Spread_Alert_Multiplier` | 2.0 | Cảnh báo khi spread > trung bình × 2 |
| `Spread_Block_Multiplier` | 3.0 | Chặn entry khi spread > trung bình × 3 |

#### J. Hiển thị & Giao diện

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Zone_Width_Pips` | 4 | Độ rộng vùng RP trên chart (pip) |
| `Min_Score_To_Show` | 40 | Chỉ hiển thị RP có điểm ≥ 40 |
| `Show_Dashboard` | true | Hiện bảng thông tin |
| `Show_Performance_Stats` | true | Hiện thống kê hit rate |
| `Proximity_Alert_Pips` | 20 | Cảnh báo khi giá trong khoảng N pip |
| `Dashboard_Corner` | TOP_LEFT | Vị trí dashboard |
| `Dashboard_Font_Size` | 9 | Cỡ chữ dashboard |

#### K. Màu sắc

| Tham số | Mặc định | Ý nghĩa |
|---------|----------|---------|
| `Color_Premium` | Vàng gold | Vùng Premium (≥110 điểm) |
| `Color_Level1` | Đỏ crimson | Level 1 (80–109 điểm) |
| `Color_Level2` | Cam orange | Level 2 (60–79 điểm) |
| `Color_Level3` | Xanh skyblue | Level 3 (40–59 điểm) |
| `Color_Confluence` | Tím | Vùng hợp lưu đa khung |
| `Color_RoleReversal` | Hồng magenta | Vùng đảo vai trò |
| `Color_EntryBuy` | Xanh lá | Setup mua |
| `Color_EntrySell` | Đỏ | Setup bán |

---

## 5. HIỂU GIAO DIỆN

### 5.1 Vùng RP trên biểu đồ

Mỗi Reaction Point được hiển thị dưới dạng **hình chữ nhật** (zone) trên biểu đồ:

```
Màu viền + nền    →  Cho biết cấp độ RP
Độ trong suốt     →  RP mới = đậm, RP cũ = mờ dần
Viền liền         →  Premium hoặc Level 1
Viền chấm         →  Level 2 hoặc Level 3
Hiệu ứng phát sáng →  Vùng hợp lưu 4+ RP (3 lớp chữ nhật)
```

### 5.2 Nhãn RP (Label trên zone)

Label hiển thị trực tiếp trên zone (bên phải), gồm 1 dòng:

```
[CẤP ĐỘ] | [LOẠI] [ĐIỂM] | [TF] | Tested:[SỐ LẦN]x | [TRẠNG THÁI]

Ví dụ:
  PREMIUM | CONFLUENCE 124 | H1 | Tested:3x | Fresh
  LV1 | RESISTANCE 85 | H4 | Tested:1x | Active
```

**Cấp độ zone:**

| Cấp độ | Điểm | Ý nghĩa |
|--------|-------|---------|
| **PREMIUM** | ≥110 | Zone cực mạnh, xác suất phản ứng giá rất cao |
| **LV1** | 80–109 | Zone mạnh, đáng tin cậy để giao dịch |
| **LV2** | 60–79 | Zone trung bình, cần thêm xác nhận |
| **LV3** | 40–59 | Zone yếu, chỉ tham khảo |

**Loại zone:**

| Loại | Ý nghĩa |
|------|---------|
| **SUPPORT** | Vùng hỗ trợ — giá có xu hướng bật lên khi chạm vùng này |
| **RESISTANCE** | Vùng kháng cự — giá có xu hướng bật xuống khi chạm vùng này |
| **CONFLUENCE** | Vùng hợp lưu — có 3 RP trở lên từ nhiều timeframe chồng nhau tại cùng 1 vùng giá, tín hiệu mạnh nhất |

**Trạng thái zone:**

| Trạng thái | Ý nghĩa |
|------------|---------|
| **Fresh** | Zone mới hình thành, chưa bị test lần nào — giá chạm lần đầu thường phản ứng mạnh nhất |
| **Active** | Zone đang hoạt động, đã bị test ít nhất 1 lần nhưng vẫn giữ vững |
| **RoleRev** | Role Reversal — zone đã đổi vai trò: Support cũ bị phá vỡ → trở thành Resistance (hoặc ngược lại). Đây là tín hiệu xác nhận xu hướng mạnh |
| **Decay:-N** | Zone đang suy giảm sức mạnh theo thời gian, mất N% so với ban đầu. Zone càng cũ càng giảm hiệu lực |

**Tested (số lần test):**

| Giá trị | Ý nghĩa |
|---------|---------|
| **Tested:0x** | Chưa test — zone Fresh, lần chạm đầu tiên có phản ứng mạnh nhất |
| **Tested:1-2x** | Test ít — zone vẫn mạnh, mỗi lần test thành công là xác nhận thêm |
| **Tested:3x+** | Test nhiều — zone đã được xác nhận nhiều lần nhưng cũng tăng rủi ro bị phá vỡ |

### 5.3 Dashboard (Bảng thông tin)

Dashboard nằm ở góc chart (mặc định góc trái trên), gồm các phần:

| Phần | Nội dung |
|------|----------|
| **Header** | Tên indicator, cặp tiền, khung thời gian, phiên hiện tại |
| **Regime** | Xu hướng thị trường (Strong/Weak Trend, Ranging, Choppy) + giá trị ADX |
| **Bias** | Hướng giao dịch ưu tiên (BUY/SELL/Neutral) |
| **Filters** | ATR hiện tại, Spread (bình thường/cảnh báo/chặn), trạng thái tin tức |
| **Top RPs** | 2 kháng cự + 2 hỗ trợ gần nhất với khoảng cách và điểm |
| **Radar** | 5 RP gần nhất dạng mini |
| **Stats** | Số RP, vùng hợp lưu, role reversal, entry setup đang hoạt động |
| **Hit Rate** | Tỷ lệ thành công (nếu bật `Show_Performance_Stats`) |
| **Entry** | Gợi ý vào lệnh hiện tại (nếu có) |

### 5.4 Phiên giao dịch (Nền màu)

Khi `Show_Session_Background = true`, nền chart được tô màu theo phiên:

| Phiên | Giờ (UTC) | Đặc điểm |
|-------|-----------|-----------|
| Asian | 00:00–07:00 | Biến động thấp, RP bị -10 điểm |
| London Open | 07:00–08:30 | Biến động tăng mạnh, +10 điểm |
| London | 08:30–12:00 | Thanh khoản tốt, +5 điểm |
| London-NY Overlap | 13:00–16:00 | **Biến động cao nhất**, +15 điểm |
| NY Open | 13:00–14:30 | Biến động tăng, +10 điểm |
| NY | 14:30–21:00 | Thanh khoản tốt, +5 điểm |
| Dead Zone | 22:00–00:00 | **Không giao dịch**, -20 điểm |

> **Mẹo:** Giao dịch hiệu quả nhất trong phiên **London-NY Overlap** (13:00–16:00 UTC). Tránh Dead Zone.

---

## 6. HỆ THỐNG CHẤM ĐIỂM

### 6.1 Điểm cơ bản (Base Score: 0–100)

| Tiêu chí | Điểm tối đa | Cách tính |
|-----------|-------------|-----------|
| **Reaction Strength** | 25 | Mức di chuyển giá sau swing / ATR × 25 |
| **Test Count** | 20 | Lần 1 = 5, lần 2 = 12, lần 3 = 20, sau đó giảm dần |
| **Candle Pattern** | 20 | Pinbar = 20, Engulfing = 15, Outside = 12, Large Wick = 10 |
| **Fibonacci** | 15 | Trùng 61.8% = 15, 50% = 10, 38.2% = 7 |
| **Volume** | 10 | Volume > 1.5× trung bình = 10, > 1.2× = 5 |
| **Round Number** | 10 | Gần x.x000/x.x500 (≤10pip = 10, ≤20pip = 5) |
| **Volume Delta** | ±5 | Áp lực mua/bán phù hợp loại RP |

### 6.2 Điều chỉnh từ các Module (Final Score: tối đa 150)

```
Final Score = Base Score
            + Regime adj      (−30 đến +20)   ← xu hướng ADX
            − Decay penalty   (0 đến −35+)    ← RP cũ mất điểm
            + Recent bonus    (0 đến +15)      ← RP mới phản ứng gần đây
            + Session adj     (−20 đến +15)    ← phiên giao dịch
            + Day of week     (−10 đến +5)     ← thứ trong tuần
            + Structure adj   (−20 đến +15)    ← cấu trúc thị trường
            + Liquidity sweep (+20 nếu bị quét)
            + Role reversal   (+15 nếu đảo vai trò)
            + First touch     (+10 nếu chưa test)
```

### 6.3 Vùng Confluence — Gộp và Phát hiện Test

**Gộp zone chồng nhau (Merge):**

Khi 2 vùng confluence nằm quá gần nhau (overlap hoặc cách ≤ `Confluence_Merge_Pips`), hệ thống tự động gộp:

1. So sánh `final_score` của 2 zone
2. **Giữ nguyên** zone có score cao hơn (boundaries không thay đổi)
3. **Xóa** zone yếu hơn
4. Chuyển toàn bộ RP từ zone bị xóa sang zone còn lại
5. Nếu tổng RP ≥ 4 → tự động nâng cấp lên **PREMIUM**

> Kết quả: Không còn 2 zone PREMIUM nằm sát nhau — chỉ giữ zone tốt nhất.

**Phát hiện test trên zone confluence:**

Hệ thống phát hiện test ở 2 cấp:

| Cấp | Điều kiện | Mô tả |
|-----|-----------|-------|
| **RP riêng lẻ** | Price vào `zone_high/zone_low` của từng RP | Phát hiện chính xác trên từng RP nhỏ |
| **Confluence zone** | Price vào `zone_high/zone_low` của zone confluence | Bắt được test ngay cả khi price không chạm đúng RP nhỏ bên trong |

Khi price test confluence zone:
- Tìm RP có score cao nhất trong zone → cập nhật `test_count` và `is_fresh` cho RP đó
- Không đếm trùng nếu RP đã được test trên cùng bar
- Loại trừ breakout (giá đóng cửa vượt qua zone)

### 6.4 Phân cấp RP

| Cấp | Điểm | Màu | Ý nghĩa |
|-----|------|-----|---------|
| **PREMIUM** | ≥ 110 | Vàng gold ⭐ | Vùng cực mạnh, ưu tiên cao nhất |
| **LEVEL 1** | 80–109 | Đỏ crimson 🔴 | Vùng mạnh, đáng tin cậy |
| **LEVEL 2** | 60–79 | Cam orange 🟠 | Vùng trung bình, cần thêm xác nhận |
| **LEVEL 3** | 40–59 | Xanh skyblue 🔵 | Vùng yếu, chỉ tham khảo |
| **HIDDEN** | < 40 | Không hiển thị | Bị ẩn, không đủ tiêu chuẩn |

---

## 7. HỆ THỐNG CẢNH BÁO

Chỉ báo có **4 cấp cảnh báo** (popup + sound + push notification):

### Level 1: Proximity Alert (Tiếp cận)
- **Khi nào:** Giá trong khoảng `Proximity_Alert_Pips` và đang di chuyển về phía RP
- **Thông báo:** `⚠ Approaching EURUSD H4 | 1.0850 | Score:92 | Dist:15p`
- **Chống spam:** Tự reset khi giá rời xa ≥ `Reset_Alert_Pips`

### Level 2: Reaction Alert (Phản ứng)
- **Khi nào:** Nến trước đóng cửa trong vùng RP với mẫu nến hợp lệ
- **Thông báo:** `🎯 RP REACTION EURUSD H4 | Pinbar@1.0850 | Score:92 | R:R=1:2.4`
- **Bao gồm:** Tỷ lệ R:R nếu có entry setup

### Level 3: Role Reversal Alert (Đảo vai trò)
- **Khi nào:** RP chuyển từ hỗ trợ → kháng cự hoặc ngược lại
- **Thông báo:** `⚡ ROLE REVERSAL EURUSD H4 | 1.0850 → Resistance | Score:107`
- **Cộng thêm:** +15 điểm cho RP

### Level 4: Premium Confluence Alert (Hợp lưu cao cấp)
- **Khi nào:** Điểm ≥ 110 VÀ là vùng hợp lưu (4+ RP từ nhiều khung)
- **Thông báo:** `⭐ PREMIUM EURUSD | 1.0845–1.0855 | Score:128 | 3TF aligned`
- **Đặc biệt:** Cảnh báo duy nhất hoạt động ngay cả khi thị trường choppy

### Bộ lọc áp dụng cho cảnh báo

- **Phiên:** Không cảnh báo trong Dead Zone (nếu `Alert_Only_Active_Sessions = true`)
- **Tin tức:** Chặn cảnh báo Level 1–2 trong blackout tin (Level 3–4 vẫn hoạt động)
- **Spread:** Chặn entry Level 2 khi spread quá cao

---

## 8. GỢI Ý ENTRY SETUP

Khi bật `Show_Entry_Setup = true`, chỉ báo tự động tạo gợi ý vào lệnh:

### Điều kiện kích hoạt
1. Nến trước đóng cửa trong vùng RP
2. Có mẫu nến hợp lệ (Pinbar, Engulfing, Outside Bar, Large Wick)
3. Điểm RP ≥ `Min_Score_To_Show`
4. Regime không phải Choppy
5. Tỷ lệ R:R ≥ `Min_RR_Ratio`

### Cách đọc Entry Setup

**Setup MUA (tại vùng Support):**
```
Entry = High nến trước + Entry_Buffer_Pips
SL    = Low nến trước − SL_Buffer_Pips
TP1   = RP kháng cự gần nhất (hoặc ATR × 2)
TP2   = RP kháng cự thứ 2 (hoặc ATR × 4)
```

**Setup BÁN (tại vùng Resistance):**
```
Entry = Low nến trước − Entry_Buffer_Pips
SL    = High nến trước + SL_Buffer_Pips
TP1   = RP hỗ trợ gần nhất (hoặc ATR × 2)
TP2   = RP hỗ trợ thứ 2 (hoặc ATR × 4)
```

### Hiển thị trên Dashboard

```
⚠ SELL@1.2752  SL:18p  TP1:43p  R:R=1:2.4
```

> **Quan trọng:** Setup tự động hết hạn sau `Max_Setup_Age_Bars` nến. Đây chỉ là **gợi ý**, không phải tín hiệu vào lệnh tự động.

---

## 9. CÁCH SỬ DỤNG TRONG GIAO DỊCH

### 9.1 Quy trình giao dịch khuyến nghị

```
Bước 1: Kiểm tra Dashboard
   → Regime? Bias? Session? News?
   → Nếu Choppy hoặc Dead Zone → KHÔNG giao dịch

Bước 2: Xác định vùng RP quan trọng
   → Ưu tiên: Premium > Level 1 > Level 2
   → Vùng hợp lưu (Confluence) > vùng đơn
   → Role Reversal > vùng bình thường

Bước 3: Chờ giá tiếp cận vùng RP
   → Nhận cảnh báo Level 1 (Proximity)
   → Quan sát phản ứng giá

Bước 4: Xác nhận bằng mẫu nến
   → Nhận cảnh báo Level 2 (Reaction)
   → Kiểm tra Entry Setup trên Dashboard

Bước 5: Vào lệnh (nếu đủ điều kiện)
   → Entry, SL, TP theo gợi ý
   → R:R ≥ 1.5 (khuyến nghị ≥ 2.0)

Bước 6: Quản lý lệnh
   → TP1: chốt 50% lời, dời SL về entry
   → TP2: để lệnh chạy đến RP tiếp theo
```

### 9.2 Tín hiệu mạnh nhất (ưu tiên cao)

- ⭐ **Premium Confluence**: Điểm ≥ 110, hợp lưu 3 khung thời gian
- ⚡ **Role Reversal** tại vùng hợp lưu: Hỗ trợ cũ thành kháng cự (hoặc ngược lại)
- 🎯 **Reaction** với Pinbar + Volume cao + phiên Overlap

### 9.3 Tín hiệu nên tránh

- RP Level 3 đứng một mình (không hợp lưu)
- RP trong phiên Dead Zone hoặc Asian
- RP ngược xu hướng mạnh (ADX > 25 + đi ngược trend)
- Trong thời gian blackout tin tức (30 phút trước/sau tin HIGH)
- Khi spread bị chặn (> trung bình × 3)

### 9.4 Giao dịch theo Regime

| Regime | ADX | Chiến lược |
|--------|-----|-----------|
| **Strong Trend** | > 25 | Chỉ giao dịch **cùng chiều** xu hướng. RP cùng chiều +20, ngược chiều -30 |
| **Weak Trend** | 20–25 | Ưu tiên cùng chiều nhưng có thể ngược nếu Premium/Confluence |
| **Ranging** | < 20 | Giao dịch cả 2 chiều tại RP mạnh. Thích hợp nhất cho indicator này |
| **Choppy** | Biến động bất thường | **KHÔNG giao dịch** (trừ Premium Confluence Alert Level 4) |

---

## 10. PRESET THEO KHUNG THỜI GIAN

Khi chọn preset khác AUTO, các tham số được tự động cấu hình:

| Tham số | M30 | H1 | H4 | D1 |
|---------|-----|-----|-----|-----|
| Swing_Lookback | 2 | 3 | 4 | 5 |
| Min_RP_Distance_Pips | 10 | 20 | 40 | 80 |
| Min_Reaction_Move_Pips | 8 | 15 | 30 | 60 |
| Initial_Bars_To_Scan | 300 | 500 | 300 | 200 |
| Decay_Interval_Bars | 10 | 20 | 15 | 10 |
| Max_RP_Age_Bars | 200 | 300 | 200 | 150 |
| Proximity_Alert_Pips | 10 | 20 | 40 | 80 |
| HTF_1 | H1 | H4 | D1 | W1 |
| HTF_2 | H4 | D1 | W1 | MN1 |

> Chọn `PRESET_CUSTOM` nếu muốn tự điều chỉnh từng tham số.

---

## 11. XỬ LÝ SỰ CỐ

### Không thấy chỉ báo sau khi thêm

1. Kiểm tra tab **Journal** (Ctrl+F5) xem có lỗi không
2. Biên dịch lại trong MetaEditor (F7)
3. Đảm bảo tất cả file `.mqh` nằm đúng thư mục `Include/`

### Không thấy vùng RP nào trên chart

- Tăng `Initial_Bars_To_Scan` (mặc định 500)
- Giảm `Min_Score_To_Show` (mặc định 40, thử 30)
- Kiểm tra khung thời gian ≥ M30
- Giảm `Swing_Lookback` nếu thị trường ít biến động

### Dashboard không hiển thị

- Đảm bảo `Show_Dashboard = true`
- Thử đổi `Dashboard_Corner` sang góc khác
- Kiểm tra không có indicator khác đè lên cùng vị trí

### Cảnh báo không hoạt động

- Kiểm tra `Alert_Only_Active_Sessions` — có thể đang ngoài phiên
- Kiểm tra `Use_News_Filter` — có thể đang trong blackout tin
- Trong MT5: **Tools → Options → Events** → đảm bảo **Alert** được bật
- Cho push notification: cấu hình **MetaQuotes ID** trong **Options → Notifications**

### Bộ lọc tin tức không hoạt động

- Cần tài khoản demo hoặc live (không hoạt động trên Strategy Tester)
- Kiểm tra kết nối internet
- Đảm bảo broker hỗ trợ MQL5 Calendar API

### Indicator chạy chậm

- Giảm `Initial_Bars_To_Scan`
- Giảm `HTF_Bars_To_Scan`
- Tắt `Show_Session_Background` nếu không cần
- Giảm số cặp tiền mở cùng lúc (mỗi chart chạy riêng 1 instance)

---

## 12. CÂU HỎI THƯỜNG GẶP

**Q: Chỉ báo có repainting không?**
> Không. RP chỉ được xác nhận trên nến đã đóng với N nến lookback phía sau. Không bao giờ thay đổi tín hiệu quá khứ.

**Q: Dùng trên khung nào hiệu quả nhất?**
> H1 và H4 cho tỷ lệ thắng và R:R tốt nhất. M30 cho nhiều tín hiệu hơn nhưng chất lượng thấp hơn. D1 cho ít tín hiệu nhưng rất chính xác.

**Q: Có dùng được cho vàng (XAUUSD), chỉ số (Index) không?**
> Indicator được thiết kế cho Forex. Có thể chạy trên XAUUSD/Index nhưng cần điều chỉnh tham số pip cho phù hợp (dùng PRESET_CUSTOM).

**Q: Tối đa bao nhiêu RP trên chart?**
> 200 RP, 50 vùng hợp lưu, 10 entry setup. Khi đầy, RP điểm thấp nhất bị xóa trước.

**Q: UTC Offset của broker tôi là bao nhiêu?**
> Trong MT5: chuột phải lên cặp tiền trong **Market Watch → Specification → Trade time**. Đối chiếu với giờ UTC thực tế để tính offset.

**Q: Làm sao tắt 1 module mà không ảnh hưởng module khác?**
> Mỗi module có toggle riêng: `Use_Regime_Filter`, `Use_Dynamic_Score`, `Show_Entry_Setup`, `Use_Confluence_Zones`, `Use_News_Filter`, `Use_Spread_Filter`. Đặt = false để tắt.

**Q: Chỉ báo có tự vào lệnh không?**
> Không. Đây là indicator (chỉ báo), không phải Expert Advisor (EA). Chỉ cung cấp tín hiệu và gợi ý, người dùng tự quyết định vào lệnh.

**Q: Có thể chạy trên nhiều chart cùng lúc không?**
> Có. Mỗi chart chạy 1 instance riêng biệt. Lưu ý hiệu suất khi mở quá nhiều chart.

---

## LIÊN HỆ & GHI CHÚ

- **Phiên bản:** 3.0
- **Ngôn ngữ:** MQL5
- **Tương thích:** MetaTrader 5
- **Không repainting** | **Không DLL** | **Không WebRequest bắt buộc**

> Tài liệu kỹ thuật chi tiết: xem file `docs/RP_FINAL_SPEC.md`
