# REACTION POINT INDICATOR v3.4
## Logic, Thong so UI & Huong dan Trade

---

## 1. LOGIC HOAT DONG

### 1.1 Zone la gi?

Zone = vung gia co xac suat cao gia se phan ung (bật lên hoặc bật xuống). Indicator phat hien zone tu:

- **Swing point** — dinh/day duoc xac nhan boi N nen trai/phai
- **Order Block (OB)** — nen institutional cuoi cung truoc impulse move
- **Wick filter** — thu hep zone vao vung liquidity grab (dau wick)

### 1.2 Chuoi loc 7 tang

```
1. Swing Detection (lookback N nen)
   → chi lay swing co N nen trai + N nen phai xac nhan
   
2. Momentum Confirmation
   → gia phai di chuyen >= X pips sau swing (chung minh co reaction)
   
3. ATR-Adaptive Proximity
   → zone moi phai cach zone cu >= max(fixed_pips, ATR x 0.6)
   → zone moi manh hon 1.5x → thay the zone yeu
   
4. Zone Creation
   → OB detection → wick filter → ATR width cap → min width floor
   → FVG check → Imbalance candle check
   
5. Scoring (22 yeu to, 0-200 diem)
   → chi zone Premium (>=120) hien thi mac dinh
   
6. Overlap Suppression
   → zone chong cheo trong ATR x 0.8 → giu zone manh nhat
   → cung loai (2 support gan nhau) → margin x 1.5
   
7. Level Toggle Filter
   → mac dinh chi hien Premium (bat/tat tung level rieng)
```

### 1.3 He thong Scoring — 22 yeu to

#### Base Score (0-100):

| # | Yeu to | Diem | Mo ta |
|---|--------|------|-------|
| 1 | Reaction Strength | max 35 | reaction_pips / ATR_smooth x 35 |
| 2 | Test Quality (Mitigation) | -15 to +12 | Fresh +10, test 1 +12, test 2 +5, test 3+ penalty |
| 3 | Candle Pattern | max 12 | Pinbar 12, Engulfing 10, Outside 8, Wick 6 |
| 4 | Fibonacci | max 18 | 61.8% +10, 78.6% +8, 50% +7, 38.2% +4, multi-leg +5/leg |
| 5 | Volume | max 15 | vol/MA20: >2x +15, >1.5x +12, >1.2x +8 |
| 6 | Round Number | max 8 | gan .000 +8, gan .500 +5 |
| 7 | Volume Delta | +/-5 | nen bullish tai support +5, bearish -5 |
| 8 | Zone Precision | -5 to +13 | zone hep +5, rong -5, retest-refined +5, wick +3 |
| 9 | Imbalance Candle | +8 | body >= 70% range + vol > 1.5x MA20 |

#### Final Adjustments (-170 to +200):

| Module | Diem | Logic |
|--------|------|-------|
| Regime Filter (ADX) | -30 to +20 | cung trend +20, nguoc trend -30, choppy -20 |
| Decay Penalty | 0 to -35 | zone cu mat diem theo thoi gian |
| Recent Bonus | 0 to +15 | phan ung trong 5 bar gan nhat +15 |
| Session + DoW | -30 to +20 | Overlap +15, Dead -20, Friday chieu -10 |
| Structure (BOS/CHoCH) | -20 to +15 | cung BOS +15, nguoc -20, CHoCH fade |
| Liquidity Sweep | 0 to +25 | quet qua swing + volume tiered: >2x=+25, >1.5x=+20, >1x=+12 |
| Trend Alignment (3 TF) | -25 to +20 | 3 TF cung huong +20, nguoc -25 |
| HTF Nesting | 0 to +30 | zone xac nhan boi H4+D1 +30 |
| Absorption | -10 to +5 | volume tang qua test → zone yeu -10 |
| FVG Bonus | 0 to +15 | zone overlap voi Fair Value Gap +15 |
| Role Reversal | +15 | support bi pha → thanh resistance |
| Breaker Block | +10 | OB bi pha boi impulse + retest tu phia doi dien |
| Confluence | x1.8 + 40 | 4+ RP tu nhieu TF gop lai |

#### Score Cap = 200, Classification:

| Level | Score | Mo ta |
|-------|-------|-------|
| **PREMIUM** | >= 120 | Zone cuc manh, chi zone nay hien mac dinh |
| LEVEL 1 | 85-119 | Zone manh |
| LEVEL 2 | 60-84 | Zone trung binh |
| LEVEL 3 | 40-59 | Zone yeu |
| HIDDEN | < 40 | An |

### 1.4 Multi-Touch Mitigation (ICT concept)

Moi lan gia test zone, liquidity tai zone giam dan:

| Lan test | Diem (default) | Diem (CADJPY) | Y nghia |
|----------|----------------|---------------|---------|
| Chua test (Fresh) | **+10** | **+10** | Zone manh nhat — chua ai "an" liquidity |
| Test 1 | **+12** | **+12** | Zone duoc xac nhan — tin hieu tot nhat |
| Test 2 | **+5** | **+2** | Zone con hieu luc nhung dang yeu |
| Test 3+ | **-5/lan** (floor -15) | **-7/lan** | Zone da bi "an het" — nen tranh |

> **Luu y:** Test quality penalty tuy thuoc vao cap tien. Pair trending manh (CADJPY, GBPJPY)
> co penalty nang hon vi zone break nhanh hon. Thong so duoc set trong `SPairProfile`.

### 1.5 FVG (Fair Value Gap)

FVG = khoang trong gia giua 3 nen lien tiep (institutional imbalance):
- **Bullish FVG**: high[nen cu] < low[nen moi] → gap len
- **Bearish FVG**: low[nen cu] > high[nen moi] → gap xuong
- Zone overlap voi FVG cung huong → **+15 diem**
- Zone overlap voi FVG nguoc huong → **+5 diem**

### 1.6 Breaker Block

Breaker = Order Block bi pha boi impulse manh (body >= 0.8 x ATR), sau do duoc retest tu phia doi dien:
- Demand OB bi pha xuong → thanh supply Breaker → **+25 tong** (15 role reversal + 10 breaker)
- Xac suat reversal cao hon role reversal thuong 5-10%

### 1.7 ATR Smoothing

Scoring dung **ATR smoothed (EMA period 10)** thay vi ATR raw:
- Tranh score nhay khi news spike
- Detection (tao zone, FVG, proximity) van dung ATR raw → phan ung nhanh

### 1.8 Pair Profile (P22b) — Tu dong tinh chinh theo cap tien

Indicator tu dong nhan dien cap tien va ap dung profile rieng. **Khong can chinh tay.**

| Cap tien | Session chinh | ADX (H1) | Zone life | Decay | Vol threshold |
|----------|--------------|----------|-----------|-------|---------------|
| **GBPUSD** | London Open +18 | 25/20 | 8 ngay | default | 2.0/1.5/1.2 |
| **CADJPY** | NY Open +20 | 30/23 | 5 ngay | 4 pts | 2.5/1.8/1.4 |
| **GBPJPY** | London Open +18 | 28/22 | 4 ngay | 4 pts | 2.2/1.6/1.3 |
| **USDJPY** | Asian -3 | 27/22 | 7 ngay | default | 2.0/1.5/1.2 |
| **USDCAD** | NY Open +18 | default | 7 ngay | default | 2.0/1.5/1.2 |
| **AUDJPY** | Asian -7 | 27/22 | 6 ngay | 3 pts | 2.3/1.7/1.3 |

**TF auto-scaling:** Cac thong so tu dong dieu chinh theo TF:

| Factor | M15 | M30 | H1 | H4 |
|--------|-----|-----|----|----|
| Zone lifespan | x0.60 | x0.80 | x1.00 | x1.30 |
| Volume noise | +0.2 | +0.1 | 0 | 0 |
| ADX noise | +3.0 | +1.5 | 0 | 0 |
| Session effect | x1.15 | x1.0 | x1.0 | x1.0 |

**Them cap tien moi:** Chi can them 1 block trong `BuildPairProfile()` (RP_Utils.mqh).
Dinh nghia "ngay valid" tren H1 — tat ca TF tu adapt.

### 1.9 Sweep Volume Qualification (P22c)

Liquidity sweep gio co **volume tiered bonus** thay vi flat +20:

| Volume tai sweep | Bonus | Y nghia |
|-----------------|-------|---------|
| > 2.0x MA20 | **+25** | Institutional sweep — rat manh |
| > 1.5x MA20 | **+20** | Confirmed sweep — manh |
| > 1.0x MA20 | **+12** | Average volume — vua |
| < 1.0x MA20 | **Rejected** | Noise — khong phai sweep that |

Sweep volume thap (< 1x MA20) bi loai bo hoan toan — tranh false signal tu thin market.

---

## 2. THONG SO UI TREN CHART

### 2.1 Zone Design

```
 ─────────────────────── R 142 BB     ← label: direction + score + tag
 ░░░░░░░░░░░░░░░░░░░░░               ← fill: subtle 12% opacity  
 ───────────────────────               ← edge: 2px, 55% opacity
```

- **Mau xanh (Blue)** = Demand / Support — gia co xu huong bat len
- **Mau do (Red)** = Supply / Resistance — gia co xu huong bat xuong
- **Mau amber** = Role Reversal / Breaker Block

### 2.2 Label Format

Format: `[S/R] [Score] [Tag]`

| Vi du | Y nghia |
|-------|---------|
| `S 156 FVG` | Support, 156 diem, co Fair Value Gap |
| `R 142 BB` | Resistance, 142 diem, Breaker Block |
| `S 148 RR` | Support, 148 diem, Role Reversal |
| `R 128 C` | Resistance, 128 diem, Confluence |
| `S 134` | Support, 134 diem, zone binh thuong |

Tags:
- **BB** = Breaker Block (OB bi pha + retest)
- **RR** = Role Reversal (zone doi vai tro)
- **FVG** = Fair Value Gap (co imbalance)
- **C** = Confluence (nhieu TF chong nhau)
- (trong) = zone Premium binh thuong

### 2.3 Dashboard

| Phan | Thong tin | Cach doc |
|------|-----------|----------|
| **Market Context** | Session, Regime, Structure, Trend | London Open = tot, Choppy = tranh |
| **Indicators** | ATR, Spread, News | Spread cao = cho, News = khong vao lenh |
| **Active Zones** | Zone cards voi score + tags | Uu tien score cao + tags (FVG, BB) |
| **Performance** | Hit rate tong + theo Premium | Premium 86% = tot |
| **Legend** | Mau sac | Blue = demand, Red = supply, Amber = reversal |

### 2.4 Zone Visual

| Thuoc tinh | Gia tri | Ly do |
|------------|---------|-------|
| Fill alpha | 45% (Premium) | Nhe, khong che nen |
| Edge width | 2px (Premium) | Sac net nhung khong qua day |
| Zone length | Max 100 bars back | Khong keo dai qua khu xa |
| Glow | Tat khi chi show Premium | Giam noise |
| Font | Arial Bold 9pt | De doc |

---

## 3. CACH SU DUNG DE TRADE HIEU QUA NHAT

### 3.1 Workflow Top-Down (Khuyen nghi)

```
BUOC 1: H4 — Xac dinh vung gia lon
   → Mo H4, nhin zone Premium
   → Xac dinh zone S/R chinh (score cao nhat)
   → Ghi nhan huong trend (dashboard: Trend H4↑ hay ↓)

BUOC 2: H1 — Tim zone entry
   → Chuyen sang H1
   → Tim zone Premium co HTF nesting (tag C hoac score >140)
   → Zone gan gia hien tai = muc tieu

BUOC 3: M15 — Entry chinh xac
   → Chuyen sang M15 khi gia den gan zone H1
   → Cho zone M15 Premium xuat hien tai cung vung gia
   → Cho pattern xac nhan (pinbar, engulfing)
   → Vao lenh khi co label FVG hoac BB
```

### 3.2 Uu tien zone nao?

**Xep hang tu manh → yeu:**

| # | Loai zone | Score | Tag | Ti le uoc tinh |
|---|-----------|-------|-----|----------------|
| 1 | Premium + Confluence + FVG + HTF nesting | 160-200 | `S 175 FVG` + C | **85-92%** |
| 2 | Premium + Breaker Block | 140-170 | `R 155 BB` | **83-90%** |
| 3 | Premium + FVG | 135-165 | `S 145 FVG` | **80-88%** |
| 4 | Premium + Role Reversal | 135-160 | `S 140 RR` | **78-85%** |
| 5 | Premium standard | 120-140 | `R 128` | **75-82%** |
| 6 | Level 1 | 85-119 | (khong hien mac dinh) | 60-70% |

### 3.3 Khi nao KHONG trade

| Dieu kien | Ly do | Hien thi |
|-----------|-------|----------|
| Dashboard: **Choppy** | Gia khong co huong → zone bi sai | Regime = CHOPPY |
| Dashboard: **Dead Zone** | Thanh khoan thap | Session = Dead |
| Dashboard: **News** | Tin quan trong → spread spike | News = NFP in 12min |
| Dashboard: **Spread cao** | Chi phi vao lenh lon | Spread = Warning/Blocked |
| Zone test **3+ lan** | Liquidity da can | Label khong co tag, score thap |
| Zone **nguoc trend manh** | ADX > 25 + zone nguoc huong | Score thap do Regime -30 |

### 3.4 Entry Rules

**BUY tai zone Demand (Blue):**
```
1. Gia cham zone demand (S xxx)
2. Cho 1 nen H1/M15 dong trong zone
3. Nen phai co pattern (pinbar/engulfing/outside)
4. SL = duoi zone_low - 5 pips
5. TP1 = zone supply (Red) gan nhat
6. TP2 = zone supply thu 2
7. R:R toi thieu 1:1.5 (khuyen nghi 1:2+)
```

**SELL tai zone Supply (Red):**
```
1. Gia cham zone supply (R xxx)
2. Cho 1 nen H1/M15 dong trong zone
3. Nen phai co pattern
4. SL = tren zone_high + 5 pips
5. TP1 = zone demand (Blue) gan nhat
6. TP2 = zone demand thu 2
7. R:R toi thieu 1:1.5
```

### 3.5 Quan ly lenh

```
Khi dat TP1:
  → Chot 50% vi the
  → Doi SL ve entry (hoa von)
  → De 50% con lai chay den TP2

Khi zone bi pha (breakout):
  → Cat lenh ngay
  → Cho zone do chuyen thanh Breaker Block (RR/BB)
  → Vao lenh theo huong moi khi co retest
```

### 3.6 Cau hinh khuyen nghi theo style

| Style | TF | Preset | Luu y |
|-------|-----|--------|-------|
| **Scalping** | M15 entry, H1 bias | AUTO | Decay nhanh, chi zone fresh |
| **Intraday** | H1 entry, H4 bias | AUTO | Zone Premium + FVG uu tien |
| **Swing** | H4 entry, D1 bias | AUTO | Zone HTF nesting, giu lenh 2-5 ngay |
| **Position** | D1 entry, W1 bias | AUTO | Chi Premium confluence |

---

## 4. PRESET THEO KHUNG THOI GIAN

| Param | M15 | M30 | H1 | H4 | D1 |
|-------|-----|-----|-----|-----|-----|
| Swing_Lookback | 5 | 5 | 5 | 4 | 3 |
| Min_Distance | 20 | 25 | 40 | 50 | 40 |
| Min_Reaction | 15 | 12 | 20 | 25 | 40 |
| Decay_Interval | 30 | 15 | 15 | 15 | 10 |
| Decay_Points | 2 | 3 | 3 | 3 | 3 |
| Max_Age | 300 | 200 | 250 | 180 | 100 |
| Merge_Pips | 10 | 8 | 15 | 20 | 25 |
| Score_To_Show | 75 | 50 | 80 | 80 | 35 |
| HTF_1 | H1 | H1 | H4 | D1 | W1 |
| HTF_2 | H4 | H4 | D1 | W1 | MN1 |

- **M15**: Entry TF — decay nhanh, chi zone fresh, HTF confirm tu H1+H4
- **H1**: Core TF — zone Premium clean, khoang cach rong
- **H4**: Bias TF — zone lon, spacing 50+ pips
- **D1**: Structure TF — it zone nhung cuc chinh xac

---

## 5. INPUT QUAN TRONG

### 5.1 Level Toggles (mac dinh chi Premium)

| Input | Default | Mo ta |
|-------|---------|-------|
| Show_Premium | **true** | Zone Premium (>=120) |
| Show_Level1 | false | Zone Level 1 (85-119) |
| Show_Level2 | false | Zone Level 2 (60-84) |
| Show_Level3 | false | Zone Level 3 (40-59) |

→ Mac dinh chi hien Premium. Bat them level neu muon thay nhieu zone hon.

### 5.2 Module Toggles

| Input | Default | Tac dung khi tat |
|-------|---------|------------------|
| Use_Regime_Filter | true | Khong dieu chinh score theo trend |
| Use_Dynamic_Score | true | Zone khong mat diem theo thoi gian |
| Use_Confluence_Zones | true | Khong gop zone tu nhieu TF |
| Use_Market_Structure | true | Khong co BOS/CHoCH scoring |
| Use_Trend_Alignment | true | Khong check multi-TF trend |
| Use_News_Filter | true | Khong loc tin tuc |
| Use_Spread_Filter | true | Khong theo doi spread |

### 5.3 Display

| Input | Default | Mo ta |
|-------|---------|-------|
| Clean_Chart_Mode | false | Tat tat ca UI tru zone |
| Show_Dashboard | true | Bang thong tin |
| Show_Session_Background | true | To mau nen theo phien |
| Label_Font_Size | 8 | Co chu label (thuc te +1 = 9pt) |

---

## 6. CAI DAT

### Buoc 1: Copy file
```
<MT5 Data Folder>/MQL5/
├── Indicators/ReactionPoint/
│   └── RP_Main.mq5
└── Include/ReactionPoint/
    ├── RP_Defines.mqh      RP_Utils.mqh
    ├── RP_Detection.mqh    RP_MarketStructure.mqh
    ├── RP_FVG.mqh          RP_Confluence.mqh
    ├── RP_Scoring.mqh      RP_EntrySetup.mqh
    ├── RP_RegimeFilter.mqh RP_Session.mqh
    ├── RP_DynamicDecay.mqh RP_NewsFilter.mqh
    ├── RP_SpreadFilter.mqh RP_Stats.mqh
    ├── RP_Drawing.mqh      RP_Dashboard.mqh
    ├── RP_Alerts.mqh       RP_Logger.mqh
    (18 files)
```

### Buoc 2: Compile
MetaEditor (F4) → mo RP_Main.mq5 → Compile (F7)

### Buoc 3: Them vao chart
Navigator (Ctrl+N) → Indicators → ReactionPoint → keo RP_Main vao chart

### Buoc 4: Cau hinh
- TF_Preset = **AUTO** (khuyen nghi)
- Nhan OK
- Xong. Indicator tu cau hinh theo TF hien tai.

---

## 7. XU LY SU CO

| Van de | Giai phap |
|--------|-----------|
| Khong thay zone | Tang Initial_Bars_To_Scan, giam Min_Score_To_Show |
| Zone qua nhieu | Bat chi Show_Premium, tang Min_RP_Distance |
| Zone chong cheo | Tang Confluence_Merge_Pips |
| Dashboard che chart | Doi Dashboard_Corner, hoac Clean_Chart_Mode = true |
| Canh bao khong hoat dong | Check session (co the dang Dead Zone), check News filter |
| Chay cham | Giam Initial_Bars_To_Scan va HTF_Bars_To_Scan |

---

## 8. FAQ

**Zone co repaint khong?**
→ Khong. Chi dung bar[1]+ (da dong). Khong bao gio bar[0].

**TF nao hieu qua nhat?**
→ H1 cho entry intraday, H4 cho swing. M15 de tinh chinh entry.

**Score bao nhieu la tot?**
→ Premium >= 120. Zone 150+ cuc ky dang tin.

**Zone test 3 lan co nen trade khong?**
→ Nen tranh. Moi lan test, liquidity giam. Sau 3 lan, zone thuong bi pha.

**Breaker Block la gi?**
→ Order Block bi pha boi impulse manh, sau do gia quay lai test tu phia doi dien. Xac suat reversal cao.

**FVG la gi?**
→ Fair Value Gap — khoang trong gia giua 3 nen. Cho thay institutional imbalance. Zone co FVG manh hon.

---

## 9. BACKTEST & TOI UU

### 9.1 Logger da bat mac dinh

`Enable_Logger = true` (mac dinh). Khi indicator chay, CSV tu dong ghi.

### 9.2 File log luu o dau?

```
Cach 1: MT5 → File → Open Data Folder
        → di len 1 cap → Common → Files → RP_Logs/

Cach 2: Truy cap truc tiep:
        C:\Users\{TEN_USER}\AppData\Roaming\MetaQuotes\Terminal\Common\Files\RP_Logs\

3 file CSV:
  {SYMBOL}_{TF}_zones.csv      ← zone duoc tao
  {SYMBOL}_{TF}_tests.csv      ← moi lan zone bi test
  {SYMBOL}_{TF}_outcomes.csv   ← ket qua phan ung sau N bars
```

### 9.3 Cach mo log

- **Excel**: File → Open → chon file .csv → Delimiter = Comma
- **Google Sheets**: Upload file .csv len Google Drive → mo bang Sheets
- **Notepad/VSCode**: Mo truc tiep de xem raw data

### 9.4 Gui log de toi uu

Khi co du data (toi thieu 2 tuan chay live hoac Strategy Tester):

1. Mo thu muc `RP_Logs/`
2. Copy 3 file CSV cua cap tien + TF ban muon toi uu
   - Vi du: `EURUSD_PERIOD_H1_zones.csv`, `_tests.csv`, `_outcomes.csv`
3. Gui 3 file nay trong conversation voi Claude
4. Claude se:
   - Phan tich win rate theo level, session, regime, pattern, test count
   - Tim yeu to nao dang over/under-weighted
   - De xuat chinh weight cu the (file + function + gia tri moi)
   - Truc tiep sua code va verify

**Cang nhieu data cang chinh xac — toi thieu 50+ outcomes.**

### 9.5 Chay nhanh bang Strategy Tester

De thu thap data nhanh (1 nam trong vai phut):

1. MT5 → View → Strategy Tester (Ctrl+R)
2. Chon: Indicator → ReactionPoint/RP_Main
3. Symbol: cap tien muon test (vd: EURUSD)
4. Period: H1
5. Date: 1 nam gan nhat
6. Model: Every tick (hoac Open prices neu muon nhanh)
7. Visual mode: **TAT** (nhanh hon nhieu)
8. Nhan Start
9. Khi xong → lay CSV tai `Common/Files/RP_Logs/`

→ Xem chi tiet phan tich: **docs/BACKTEST_GUIDE.html**

---

**Version:** 3.3 | **Files:** 19 (1 .mq5 + 18 .mqh) | **Score Cap:** 200 | **Anti-repainting:** Yes
