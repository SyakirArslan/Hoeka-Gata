// HokaGATA Engulfing Breakout MT5
// Core state machine: mirrors .pine state 0 / +/-1 / +/-2 / +/-3 flow.

// Forward declarations (MQL5 requires these when helpers are used before
// their definition further down in the same include).
void   PushEngulfName(string &names[], const string name);
void   RemoveEngulfName(string &names[], const int index);
string EngulfTimeframeText();

// ---- Two-pass replay bookkeeping -------------------------------------------
// RecalculateEngulfing() is a full replay of every bar, and it used to build the
// Entry/SL/TP/Body objects for EVERY historical setup before trimming the
// surplus away again inside the same loop. On a 5000-bar H4 chart that is
// hundreds of objects created and destroyed per recalculation, and each
// ObjectCreate/ObjectSet* is a call into the terminal.
//
// OnCalculate therefore replays twice:
//   pass 1  paint = false  -> pure arithmetic, only counts the setups
//   pass 2  paint = true   -> creates objects for the newest InpKeepN setups
//                             only, i.e. exactly the ones the history trim keeps
// EngulfTotalSetups is filled by pass 1, EngulfPaintFromOrdinal is what pass 2
// compares every setup ordinal against.
int EngulfTotalSetups      = 0;
int EngulfPaintFromOrdinal = 0;


struct EngulfAlertFlags
{
   bool armedNow;
   bool hitBuy;
   bool hitSell;
   bool tpHitNow;
   bool slHitNow;
   bool cancelledNow;
   bool closeCancelNow;
   int  cancelledDir;
   int  resultDir;

   // Snapshot of the setup taken the moment the event fired. The replay keeps
   // going after an event and may create a brand-new setup in the same bar
   // (cancel + opposite pattern, TP/SL + new pattern), overwriting every
   // setup.p* field. Alerts must report these captured values, never setup.*.
   int    evDir;
   int    evSetupBar;
   int    evEventBar;
   double evBreak;
   double evEntry;
   double evSL;
   double evTP;
   double evClose;
};

// Alert de-duplication. RecalculateEngulfing() replays every bar from scratch
// on each tick that changes the forming bar, so an event that stays on the last
// bar would fire Alert() on every tick. One key per event type is enough: only
// the last bar can alert, therefore identical keys are always consecutive.
string EngulfAlertKeyArmed  = "";
string EngulfAlertKeyEntry  = "";
string EngulfAlertKeyTP     = "";
string EngulfAlertKeySL     = "";
string EngulfAlertKeyCancel = "";
string EngulfAlertKeyCancelClose = "";

// Nama terminal global variable untuk menandai bar terakhir yang sudah
// diumumkan per jenis event (dipisah chart & timeframe).
string EngulfAlertSeenName(const string tag)
{
   return "HG_AL_" + IntegerToString(ChartID()) + "_" +
          IntegerToString(PeriodSeconds(_Period)) + "_" + tag;
}

// Reload indikator, ganti timeframe, atau restart terminal mereset variabel di
// atas, sehingga bar close terakhir diumumkan ulang. Karena itu waktu bar event
// juga disimpan sebagai terminal global variable: event yang bar-nya tidak lebih
// baru dari catatan terakhir dianggap sudah terkirim. Variable ini sengaja TIDAK
// dihapus di OnDeinit - justru itu yang menahan duplikat saat re-attach.
bool EngulfAlertOnce(string &lastKey, const string key, const string tag, const datetime eventTime)
{
   if(key == "" || key == lastKey)
      return false;

   string seenName = EngulfAlertSeenName(tag);

   if(eventTime > 0 && GlobalVariableCheck(seenName) &&
      eventTime <= (datetime)(long)GlobalVariableGet(seenName))
      return false;

   lastKey = key;

   if(eventTime > 0)
      GlobalVariableSet(seenName, (double)eventTime);

   return true;
}

// Captures the setup that produced the event; call it at trigger time.
void EngulfAlertCapture(EngulfAlertFlags &flags, const EngulfSetup &s, const int dir, const int eventBar)
{
   flags.evDir      = dir;
   flags.evSetupBar = s.setupBar;
   flags.evEventBar = eventBar;
   flags.evBreak    = s.pBreak;
   flags.evEntry    = s.pEntry;
   flags.evSL       = s.pSL;
   flags.evTP       = s.pTP;
}

// Returns the "risk" distance used for the R:R target.
double EngulfRisk(const int dir, const double entry, const double sl)
{
   return MathAbs(entry - sl);
}

// Alert text helpers: same price format as the chart labels, plus the two
// pieces every alert needs to be unambiguous (setup bar vs event bar, and the
// realised R:R of that setup).
string EngulfAlertBarText(const int bar, const datetime &time[])
{
   if(bar < 0 || bar >= ArraySize(time))
      return "n/a";

   return TimeToString(time[bar], TIME_DATE | TIME_MINUTES);
}

string EngulfAlertRRText(const double entry, const double sl, const double tp)
{
   double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return "n/a";

   return "1:" + DoubleToString(MathAbs(tp - entry) / risk, 2);
}

string EngulfAlertHead()
{
   return _Symbol + " " + EngulfTimeframeText();
}

// Identity of one event: event name + direction + setup bar time + event bar
// time. Bar times are used instead of indexes so that a history re-download
// (which shifts every index) cannot make the same event alert twice.
string EngulfAlertKey(const string event, const int dir, const string setupAt, const string barAt)
{
   return event + "|" + IntegerToString(dir) + "|" + setupAt + "|" + barAt;
}

// .pine CREATE NEW SETUP level math, including the guards.
void EngulfComputeLevels(const int dir, const double o1, const double c1,
                         const double wickTop, const double wickBot,
                         const double bufEntry, const double bufSL, const double bufBodyBreak,
                         double &breakCalc, double &entryCalc, double &slCalc, double &tpCalc)
{
   double mintick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(mintick <= 0.0)
      mintick = MathPow(10.0, -_Digits);

   double bodyTopPrev = MathMax(o1, c1);
   double bodyBotPrev = MathMin(o1, c1);

   breakCalc = dir == 1 ? bodyTopPrev + bufBodyBreak : bodyBotPrev - bufBodyBreak;
   entryCalc = dir == 1 ? wickTop + bufEntry : wickBot - bufEntry;

   // guard: break body tidak boleh melewati level pending
   if(dir == 1 && breakCalc >= entryCalc)
      breakCalc = entryCalc - mintick;
   if(dir == -1 && breakCalc <= entryCalc)
      breakCalc = entryCalc + mintick;

   // SL dari wick berlawanan, TP dari entry (wick)
   slCalc = dir == 1 ? wickBot - bufSL : wickTop + bufSL;

   if(dir == 1 && slCalc >= entryCalc)
      slCalc = entryCalc - MathMax(bufSL, mintick * 2.0);

   if(dir == -1 && slCalc <= entryCalc)
      slCalc = entryCalc + MathMax(bufSL, mintick * 2.0);

   double risk = EngulfRisk(dir, entryCalc, slCalc);
   tpCalc = dir == 1 ? entryCalc + InpRrRatio * risk : entryCalc - InpRrRatio * risk;
}

// =====================================================
// KUNCI SETUP INTRABAR (v2.04, requirement R2)
// RecalculateEngulfing() me-replay seluruh histori pada setiap tick dan tidak
// menyimpan state di antara tick. Pola hanya sah bila DetectEngulfing() lolos,
// dan syaratnya memakai close (close > high(S-1) untuk BUY). Di dalam candle
// yang masih berjalan close hanyalah harga terakhir, jadi setup yang sempat
// terbit bisa hilang begitu harga berbalik sebelum close: level, garis, panel,
// dan buffer EA lenyap, padahal alert arm/fill dan (dengan shift 0) posisi EA
// sudah ada. Itulah jalur "void" yang dihapus dari Docs/entry-animation.html.
//
// Tabel ini menyimpan level setup yang lahir di bar terakhir (candle berjalan)
// supaya replay berikutnya bisa membangun ulang setup itu tanpa mengenali pola
// lagi, dan supaya level yang sudah diumumkan tidak bergeser saat close (ATR
// bar S memakai range final, jadi hitungan ulang bisa menggeser entry/SL/TP
// yang sudah diumumkan lewat alert). Satu entri per bar yang pernah punya setup
// intrabar, urut naik menurut waktu bar.
// =====================================================
struct EngulfLock
{
   datetime barTime;
   int      dir;
   double   pBreak;
   double   pEntry;
   double   pSL;
   double   pTP;
   bool     filled;
};

EngulfLock g_engulfLocks[];          // urut naik menurut barTime

// Binary search: dipanggil untuk setiap bar pada setiap replay (ribuan bar per
// tick), jadi tidak boleh linear. Tidak ada batas jumlah entri - membuang entri
// akan menghidupkan lagi gejala void pada histori lama.
int EngulfLockFind(const datetime barTime)
{
   int lo = 0;
   int hi = ArraySize(g_engulfLocks) - 1;

   while(lo <= hi)
   {
      int mid = (lo + hi) / 2;

      if(g_engulfLocks[mid].barTime == barTime)
         return mid;

      if(g_engulfLocks[mid].barTime < barTime)
         lo = mid + 1;
      else
         hi = mid - 1;
   }

   return -1;
}

void EngulfLockStore(const datetime barTime, const int dir,
                     const double pBreak, const double pEntry,
                     const double pSL, const double pTP)
{
   if(EngulfLockFind(barTime) >= 0)
      return;

   int size = ArraySize(g_engulfLocks);
   ArrayResize(g_engulfLocks, size + 1);

   // Bar baru selalu yang paling akhir, jadi sisipan hampir selalu append.
   int at = size;
   while(at > 0 && g_engulfLocks[at - 1].barTime > barTime)
   {
      g_engulfLocks[at] = g_engulfLocks[at - 1];
      at--;
   }

   g_engulfLocks[at].barTime = barTime;
   g_engulfLocks[at].dir      = dir;
   g_engulfLocks[at].pBreak   = pBreak;
   g_engulfLocks[at].pEntry   = pEntry;
   g_engulfLocks[at].pSL      = pSL;
   g_engulfLocks[at].pTP      = pTP;
   g_engulfLocks[at].filled   = false;
}

void EngulfLockMarkFilled(const datetime barTime)
{
   int k = EngulfLockFind(barTime);
   if(k >= 0)
      g_engulfLocks[k].filled = true;
}

// =====================================================
// MAIN ENGINE
// Urutan per bar (v2.02, A = P):
//   EXTEND -> PATTERN -> OPPOSITE CANCEL -> CREATE NEW SETUP
//   -> BREAK BODY -> PENDING FILL -> CANCEL AT SETUP BAR CLOSE
//   -> ACTIVE RESULT -> FREEZE
// Setup selalu selesai di bar pola: filled atau canceled. Tidak ada pending
// yang bertahan ke bar berikutnya.
//
// Default (InpAllowFormingBar = false): bar pola harus sudah close, jadi
// panel/counter/buffer EA hanya berubah saat sebuah candle tertutup.
// InpAllowFormingBar = true: bar pola terakhir (yang masih berjalan) ikut
// dievaluasi, sehingga level + pending + fill muncul saat candle S berjalan
// (termasuk alert arm/fill-nya; alert cancel tetap menunggu bar close).
//
// R2 (v2.04): setup yang lahir di candle berjalan dikunci di g_engulfLocks.
// Kalau harga berbalik dan pola tidak lagi lolos di close, replay tidak
// membuang setup itu - ia dibangun ulang dari level yang terkunci, dan status
// filled/armed-nya dipertahankan. Jadi tidak ada lagi jalur "void": begitu
// diumumkan, setup berakhir filled (ACTIVE) atau canceled, tidak pernah hilang.
//
// paint = false  -> dry replay: no objects, no alerts (pass 1)
// paint = true   -> creates objects for setups with an ordinal above
//                   EngulfPaintFromOrdinal (pass 2)
// =====================================================
void RecalculateEngulfing(
   const int start,
   const int rates_total,
   const bool paint,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[]
)
{
   EngulfStats stats;
   stats.nSig = 0;
   stats.nRun = 0;
   stats.nWin = 0;
   stats.nLos = 0;
   stats.nCancelled = 0;
   stats.nBuyRun = 0;
   stats.nSellRun = 0;
   stats.buyWins = 0;
   stats.buyLoss = 0;
   stats.sellWins = 0;
   stats.sellLoss = 0;
   stats.maxTPStreak = 0;
   stats.maxSLStreak = 0;
   stats.state = STATE_NONE;

   int curTPStreak = 0;
   int curSLStreak = 0;

   EngulfSetup setup;
   setup.dir = 0;
   setup.setupBar = -1;
   setup.entryBar = -1;
   setup.pBreak = 0.0;
   setup.pEntry = 0.0;
   setup.pSL = 0.0;
   setup.pTP = 0.0;
   setup.lnE = "";
   setup.lnS = "";
   setup.lnT = "";
   setup.lbE = "";
   setup.lbS = "";
   setup.lbT = "";
   setup.lnBody = "";
   setup.lbBody = "";

   int state = STATE_NONE;

   // 1-based counters over the setups the replay walks past, used to keep the
   // painted objects limited to the newest InpKeepN setups. attemptOrdinal
   // counts create-setup attempts (body-break line), setupOrdinal counts the
   // attempts that survived the level guards (Entry / SL / TP lines).
   int attemptOrdinal = 0;
   int setupOrdinal   = 0;

   // history of setup visual object names (keepN * 3 lines, keepN * 3 labels)
   string histLines[];
   string histLabels[];
   string histBodyLines[];
   string histBodyLabels[];

   int firstBar = start > 1 ? start : 1;

   for(int i = firstBar; i < rates_total; i++)
   {
      EngulfAlertFlags flags;
      flags.armedNow = false;
      flags.hitBuy = false;
      flags.hitSell = false;
      flags.tpHitNow = false;
      flags.slHitNow = false;
      flags.cancelledNow = false;
      flags.closeCancelNow = false;
      flags.cancelledDir = 0;
      flags.resultDir = 0;
      flags.evDir = 0;
      flags.evSetupBar = -1;
      flags.evEventBar = -1;
      flags.evBreak = 0.0;
      flags.evEntry = 0.0;
      flags.evSL = 0.0;
      flags.evTP = 0.0;
      flags.evClose = 0.0;

      // .pine EXTEND ACTIVE SETUP (state != 0): stretch visuals to bar_index + extendB
      if(state != STATE_NONE && InpShowLines)
      {
         int xRight = i + InpExtendB;
         EngulfSetLineX2(setup.lnE, xRight, setup.pEntry, rates_total, time);
         EngulfSetLineX2(setup.lnS, xRight, setup.pSL, rates_total, time);
         EngulfSetLineX2(setup.lnT, xRight, setup.pTP, rates_total, time);
         EngulfSetLineX2(setup.lnBody, xRight, setup.pBreak, rates_total, time);

         EngulfSetLabelX(setup.lbE, xRight, setup.pEntry, rates_total, time);
         EngulfSetLabelX(setup.lbS, xRight, setup.pSL, rates_total, time);
         EngulfSetLabelX(setup.lbT, xRight, setup.pTP, rates_total, time);
         EngulfSetLabelX(setup.lbBody, xRight, setup.pBreak, rates_total, time);
      }

      // .pine PATTERN DETECTION (barstate.isconfirmed -> closed bar)
      // D1 = A: bar terakhir (rates_total - 1) masih bergerak, jadi bukan
      // kandidat pola. Guard ini yang membuat klaim "PENDING tidak pernah
      // tampil" benar - setup hanya dibuat di bar yang sudah close dan siklus
      // A = P selesai di bar itu juga. Tanpa guard, pola pada candle berjalan
      // bisa armed/filled intrabar: panel menampilkan PENDING, counter naik
      // turun, dan EA (shift 0) entry sebelum candle pola confirmed.
      //
      // InpAllowFormingBar = true melepas guard ini dengan sengaja: pola,
      // trigger, dan fill boleh terjadi saat candle pola masih berjalan
      // (pending intrabar). Dua keputusan yang bergantung pada harga close -
      // cancel-at-setup-bar-close dan "setup tanpa break body" - tetap memakai
      // notFormingBar, karena pada candle berjalan close[] hanyalah harga
      // terakhir dan keputusan itu akan membuang pending yang baru dipasang.
      // Konsekuensi lainnya: pola yang sah di tengah candle bisa gugur saat
      // close, dan seluruh loop diulang dari awal setiap tick. Itu dulu membuat
      // level/pending/counter hilang sendiri (void). Sejak v2.04 setup seperti
      // itu dikunci (g_engulfLocks) lalu dibangun ulang dari level yang sama,
      // jadi akhirnya hanya dua: filled (ACTIVE) atau canceled.
      // Alert ikut intrabar (arm/fill, lihat blok ALERTS di bawah) supaya
      // pending bisa dipasang dan fill diketahui selagi candle bergerak; alert
      // cancel tetap menunggu bar close.
      const bool notFormingBar = (i < rates_total - 1);
      const bool evalBar = (notFormingBar || InpAllowFormingBar);

      EngulfSignal sig = DetectEngulfing(i, open, high, low, close);

      // R2.2: bar yang setupnya sudah diumumkan intrabar tetap dikenali walau
      // syarat pola tidak lagi terpenuhi (harga berbalik sebelum close). Tanpa
      // ini replay berikutnya tidak tahu setup itu pernah ada dan seluruh
      // jejaknya hilang - persis skenario void yang dihapus dari animasi.
      const int  lockIdx   = (evalBar && InpAllowFormingBar) ? EngulfLockFind(time[i]) : -1;
      const bool lockedBar = (lockIdx >= 0 && !sig.buy && !sig.sell);

      if(evalBar && (sig.buy || sig.sell || lockedBar))
         stats.nSig++;

      // .pine OPPOSITE SIGNAL CANCELLATION
      // Jalur warisan .pine. Di A = P blok ini tidak pernah terpicu: state
      // SETUP/ARMED hanya hidup di dalam iterasi bar pola, sedangkan blok ini
      // dievaluasi sebelum CREATE, jadi state yang terbawa dari bar sebelumnya
      // selalu NONE. Dibiarkan utuh agar kontrak input & teks alert lama tidak
      // berubah; lihat catatan legacy di Docs/Indicator_MT5.md.
      bool oppositeToBuy = (state == STATE_BUY_SETUP || state == STATE_BUY_ARMED) && sig.sell;
      bool oppositeToSell = (state == STATE_SELL_SETUP || state == STATE_SELL_ARMED) && sig.buy;

      if(InpCancelOpp && (oppositeToBuy || oppositeToSell))
      {
         int cancelDir = state > 0 ? 1 : -1;

         EngulfAlertCapture(flags, setup, cancelDir, i);
         flags.cancelledDir = cancelDir;
         stats.nCancelled++;
         flags.cancelledNow = true;
         state = STATE_NONE;

         EngulfClearSetupVisuals(setup);
      }

      // =====================================================
      // .pine CREATE NEW SETUP
      // =====================================================
      // Blok ini sengaja dievaluasi SEBELUM trigger/fill/cancel (A = P): setup
      // baru langsung diuji di bar yang sama. Bila posisi lama masih ACTIVE,
      // state != NONE sehingga pola di bar ini diabaikan - hasil TP/SL baru
      // diproses setelah blok ini, jadi satu bar tidak pernah memuat dua event
      // dan snapshot alert TP/SL tidak bisa tertimpa snapshot fill.
      if(evalBar && state == STATE_NONE && (sig.buy || sig.sell || lockedBar))
      {
         // R2.2/R2.3: arah dan level selalu dari kunci. Kunci menang atas pola,
         // termasuk saat close berbalik jauh sampai pola arah berlawanan sah di
         // bar yang sama: setup yang sudah diumumkan tidak boleh diganti diam-diam.
         int dir = lockIdx >= 0 ? g_engulfLocks[lockIdx].dir : (sig.buy ? 1 : -1);

         setup.lnE = "";
         setup.lnS = "";
         setup.lnT = "";
         setup.lbE = "";
         setup.lbS = "";
         setup.lbT = "";
         setup.lnBody = "";
         setup.lbBody = "";

         // Count every attempt (the body-break line is drawn per attempt, and the
         // history trim works in lines), but only paint the newest InpKeepN -
         // older ones would be created and deleted again within this same loop.
         attemptOrdinal++;
         const bool drawAttempt = paint && (attemptOrdinal > EngulfPaintFromOrdinal);

         setup.dir = dir;
         setup.setupBar = i;
         setup.entryBar = -1;

         double breakCalc;
         double entryCalc;
         double slCalc;
         double tpCalc;

         // R2.2: level dipakai apa adanya dari kunci. Menghitung ulang bisa
         // menggeser harga (ATR bar S memakai range final dan guard di
         // EngulfComputeLevels bisa memotong level), sedangkan user sudah
         // melihat angka yang lama saat alert BREAK BODY terbit. Saat pola sudah
         // gagal, hitungan ulang juga tidak ada artinya lagi: pergerakan harga
         // setelah itu bukan lagi gambaran setup yang diumumkan.
         if(lockIdx >= 0)
         {
            breakCalc = g_engulfLocks[lockIdx].pBreak;
            entryCalc = g_engulfLocks[lockIdx].pEntry;
            slCalc    = g_engulfLocks[lockIdx].pSL;
            tpCalc    = g_engulfLocks[lockIdx].pTP;
         }
         else
         {
            double atr = EngulfAtrAt(i, high, low, close, 14);
            double bufEntry = InpBufEntryX * atr;
            double bufSL = InpBufSLX * atr;
            double bufBodyBreak = InpBodyBreakTol * atr;

            double o1 = open[i - 1];
            double c1 = close[i - 1];
            double wickTop = high[i - 1];
            double wickBot = low[i - 1];

            EngulfComputeLevels(dir, o1, c1, wickTop, wickBot, bufEntry, bufSL, bufBodyBreak,
                                breakCalc, entryCalc, slCalc, tpCalc);
         }

         double mintick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(mintick <= 0.0)
            mintick = MathPow(10.0, -_Digits);

         // .pine: draw body-break line (trigger level) when master display is on
         if(InpShowLines && drawAttempt)
         {
            int xStartBody = i - 1;
            int xRightBody = i + InpExtendB;
            string bodyKey = IntegerToString(i);

            setup.lnBody = PREFIX + "BODYLINE_" + bodyKey;
            setup.lbBody = PREFIX + "BODYLABEL_" + bodyKey;

            EngulfMakeLine(setup.lnBody, xStartBody, breakCalc, xRightBody, breakCalc,
                           InpCBodyBreak, EngulfBodyBreakStyle(), rates_total, time);
            EngulfMakeLabel(setup.lbBody, xRightBody, breakCalc, "BREAK BODY",
                            InpCBodyBreak, InpLabelSize, rates_total, time);

            PushEngulfName(histBodyLines, setup.lnBody);
            PushEngulfName(histBodyLabels, setup.lbBody);

            // limit history arrays to keepBodyHistory (= keepN)
            while(ArraySize(histBodyLines) > InpKeepN)
            {
               EngulfDeleteObject(histBodyLines[0]);
               RemoveEngulfName(histBodyLines, 0);
            }
            while(ArraySize(histBodyLabels) > InpKeepN)
            {
               EngulfDeleteObject(histBodyLabels[0]);
               RemoveEngulfName(histBodyLabels, 0);
            }
         }

         if(EngulfRisk(dir, entryCalc, slCalc) > mintick &&
            MathAbs(tpCalc - entryCalc) > mintick)
         {
            setup.pBreak = breakCalc;
            setup.pEntry = entryCalc;
            setup.pSL = slCalc;
            setup.pTP = tpCalc;
            state = dir;

            // Only a setup that survives the level guards counts towards the
            // painted Entry / SL / TP window.
            setupOrdinal++;
            const bool drawThis = paint && (setupOrdinal > EngulfPaintFromOrdinal);

            int xEntryStart = i;
            int xSLStart = i - 1;
            int xRight = i + InpExtendB;
            string setupKey = IntegerToString(i) + "_" + IntegerToString(dir);

            if(InpShowLines && drawThis)
            {
               setup.lnE = PREFIX + "ENTRYLINE_" + setupKey;
               setup.lnS = PREFIX + "SLLINE_" + setupKey;
               setup.lnT = PREFIX + "TPLINE_" + setupKey;
               setup.lbE = PREFIX + "ENTRYLABEL_" + setupKey;
               setup.lbS = PREFIX + "SLLABEL_" + setupKey;
               setup.lbT = PREFIX + "TPLABEL_" + setupKey;

               EngulfMakeLine(setup.lnE, xEntryStart, setup.pEntry, xRight, setup.pEntry,
                              InpCEntryLine, STYLE_DASH, rates_total, time);
               EngulfMakeLine(setup.lnS, xSLStart, setup.pSL, xRight, setup.pSL,
                              InpCSL, EngulfLineStyle(), rates_total, time);
               EngulfMakeLine(setup.lnT, xEntryStart, setup.pTP, xRight, setup.pTP,
                              InpCTP, EngulfLineStyle(), rates_total, time);

               PushEngulfName(histLines, setup.lnE);
               PushEngulfName(histLines, setup.lnS);
               PushEngulfName(histLines, setup.lnT);

               string side = dir == 1 ? "BUY" : "SELL";
               color entryColor = dir == 1 ? InpCBuyText : InpCSellText;

               EngulfMakeLabel(setup.lbE, xRight, setup.pEntry,
                               "PENDING " + side + " " + EngulfPriceText(setup.pEntry),
                               entryColor, InpLabelSize, rates_total, time);
               EngulfMakeLabel(setup.lbS, xRight, setup.pSL,
                               "SL " + EngulfPriceText(setup.pSL),
                               InpCSL, InpLabelSize, rates_total, time);
               EngulfMakeLabel(setup.lbT, xRight, setup.pTP,
                               "TP " + EngulfPriceText(setup.pTP),
                               InpCTP, InpLabelSize, rates_total, time);

               PushEngulfName(histLabels, setup.lbE);
               PushEngulfName(histLabels, setup.lbS);
               PushEngulfName(histLabels, setup.lbT);

               while(ArraySize(histLines) > InpKeepN * 3)
               {
                  EngulfDeleteObject(histLines[0]);
                  RemoveEngulfName(histLines, 0);
               }
               while(ArraySize(histLabels) > InpKeepN * 3)
               {
                  EngulfDeleteObject(histLabels[0]);
                  RemoveEngulfName(histLabels, 0);
               }
            }

            // R2.1: setup yang lahir di candle berjalan langsung dikunci, jadi
            // replay tick berikutnya (dan replay saat bar itu close) bisa
            // membangunnya ulang walau pola sudah tidak lolos DetectEngulfing().
            if(i == rates_total - 1 && InpAllowFormingBar)
               EngulfLockStore(time[i], dir, setup.pBreak, setup.pEntry, setup.pSL, setup.pTP);

            // R2.3: fill yang sudah terjadi tetap sah. Setup dilanjutkan sebagai
            // ACTIVE supaya TP/SL di bar berikutnya tetap dipantau; garis dan
            // label entry disamakan dengan blok fill normal.
            if(lockIdx >= 0 && g_engulfLocks[lockIdx].filled)
            {
               state = dir == 1 ? STATE_BUY_ACTIVE : STATE_SELL_ACTIVE;
               setup.entryBar = i;

               stats.nRun++;
               if(dir == 1)
                  stats.nBuyRun++;
               else
                  stats.nSellRun++;

               EngulfSetLineStyle(setup.lnE, STYLE_SOLID);
               EngulfSetLineColor(setup.lnE, dir == 1 ? InpCBuyText : InpCSellText);
               EngulfSetLabelText(setup.lbE,
                                  (dir == 1 ? "BUY " : "SELL ") + EngulfPriceText(setup.pEntry),
                                  dir == 1 ? InpCBuyText : InpCSellText, InpLabelSize);

               // D8 = A: kontrak buffer EA sama seperti fill intrabar.
               if(dir == 1)
                  BuyBuffer[i] = setup.pEntry;
               else
                  SellBuffer[i] = setup.pEntry;

               SignalSLBuffer[i] = setup.pSL;
               SignalTPBuffer[i] = setup.pTP;
            }
         }
      }

      // .pine BREAK BODY TRIGGER (BUY) - hanya di bar pola (A = P)
      if(state == STATE_BUY_SETUP && i == setup.setupBar)
      {
         if(high[i] >= setup.pBreak)
         {
            EngulfAlertCapture(flags, setup, 1, i);
            state = STATE_BUY_ARMED;
            flags.armedNow = true;
         }
      }

      // .pine PENDING FILL (BUY) - bar pola yang sama
      if(state == STATE_BUY_ARMED && i == setup.setupBar)
      {
         if(high[i] >= setup.pEntry)
         {
            EngulfAlertCapture(flags, setup, 1, i);
            state = STATE_BUY_ACTIVE;
            setup.entryBar = i;
            stats.nRun++;
            stats.nBuyRun++;
            flags.hitBuy = true;

            EngulfSetLineStyle(setup.lnE, STYLE_SOLID);
            EngulfSetLineColor(setup.lnE, InpCBuyText);
            EngulfSetLabelText(setup.lbE, "BUY " + EngulfPriceText(setup.pEntry), InpCBuyText, InpLabelSize);
         }
      }

      // .pine BREAK BODY TRIGGER (SELL) - hanya di bar pola (A = P)
      if(state == STATE_SELL_SETUP && i == setup.setupBar)
      {
         if(low[i] <= setup.pBreak)
         {
            EngulfAlertCapture(flags, setup, -1, i);
            state = STATE_SELL_ARMED;
            flags.armedNow = true;
         }
      }

      // .pine PENDING FILL (SELL) - bar pola yang sama
      if(state == STATE_SELL_ARMED && i == setup.setupBar)
      {
         if(low[i] <= setup.pEntry)
         {
            EngulfAlertCapture(flags, setup, -1, i);
            state = STATE_SELL_ACTIVE;
            setup.entryBar = i;
            stats.nRun++;
            stats.nSellRun++;
            flags.hitSell = true;

            EngulfSetLineStyle(setup.lnE, STYLE_SOLID);
            EngulfSetLineColor(setup.lnE, InpCSellText);
            EngulfSetLabelText(setup.lbE, "SELL " + EngulfPriceText(setup.pEntry), InpCSellText, InpLabelSize);
         }
      }

      // R2.3: pending bar ini sudah terisi -> kunci ikut ditandai, supaya replay
      // berikutnya membangun setup sebagai ACTIVE (bukan ARMED lagi).
      if(flags.hitBuy || flags.hitSell)
         EngulfLockMarkFilled(time[i]);

      // .pine CANCEL AT SETUP BAR CLOSE (BUY): armed, tapi close belum melewati ENTRY
      // Blok ini tetap hanya dievaluasi pada bar yang sudah close (notFormingBar).
      // Dengan InpAllowFormingBar, close[i] pada candle berjalan hanyalah harga
      // terakhir, jadi memakainya di sini akan langsung menghapus pending yang
      // baru saja dipasang (pending hanya akan sempat tampil pada tick di mana
      // harga sudah melewati ENTRY - dan saat itu state-nya sudah ACTIVE).
      if(notFormingBar && state == STATE_BUY_ARMED && i == setup.setupBar && close[i] <= setup.pEntry)
      {
         EngulfAlertCapture(flags, setup, 1, i);
         flags.cancelledDir = 1;
         flags.closeCancelNow = true;
         flags.evClose = close[i];
         stats.nCancelled++;
         state = STATE_NONE;

         EngulfClearSetupVisuals(setup);
      }

      // .pine CANCEL AT SETUP BAR CLOSE (SELL) - juga hanya pada bar yang sudah close
      if(notFormingBar && state == STATE_SELL_ARMED && i == setup.setupBar && close[i] >= setup.pEntry)
      {
         EngulfAlertCapture(flags, setup, -1, i);
         flags.cancelledDir = -1;
         flags.closeCancelNow = true;
         flags.evClose = close[i];
         stats.nCancelled++;
         state = STATE_NONE;

         EngulfClearSetupVisuals(setup);
      }

      // Setup yang tidak menyentuh BREAK BODY di bar pola (hanya mungkin bila
      // InpBodyBreakTol > 0) hangus tanpa order: tidak ada fill, tidak ada alert.
      // Sama seperti cancel-at-close, keputusan "tidak pernah armed" baru sah
      // setelah bar pola close - pada candle berjalan high/low belum final,
      // sehingga pending intrabar tidak boleh langsung dibuang di sini.
      if(notFormingBar && (state == STATE_BUY_SETUP || state == STATE_SELL_SETUP) && i == setup.setupBar)
      {
         state = STATE_NONE;
         EngulfClearSetupVisuals(setup);
      }

      // .pine ACTIVE BUY RESULT (SL checked first)
      if(state == STATE_BUY_ACTIVE && i > setup.entryBar)
      {
         if(low[i] <= setup.pSL)
         {
            stats.nLos++;
            stats.buyLoss++;
            curSLStreak++;
            curTPStreak = 0;
            if(curSLStreak > stats.maxSLStreak)
               stats.maxSLStreak = curSLStreak;

            EngulfAlertCapture(flags, setup, 1, i);
            flags.slHitNow = true;
            flags.resultDir = 1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "BUY SL " + EngulfPriceText(setup.pEntry), InpCSL, InpLabelSize);
            EngulfSetLabelText(setup.lbS, "SL HIT " + EngulfPriceText(setup.pSL), InpCSL, InpLabelSize);
         }
         else if(high[i] >= setup.pTP)
         {
            stats.nWin++;
            stats.buyWins++;
            curTPStreak++;
            curSLStreak = 0;
            if(curTPStreak > stats.maxTPStreak)
               stats.maxTPStreak = curTPStreak;

            EngulfAlertCapture(flags, setup, 1, i);
            flags.tpHitNow = true;
            flags.resultDir = 1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "BUY TP " + EngulfPriceText(setup.pEntry), InpCTP, InpLabelSize);
            EngulfSetLabelText(setup.lbT, "TP HIT " + EngulfPriceText(setup.pTP), InpCTP, InpLabelSize);
         }
      }

      // .pine ACTIVE SELL RESULT (SL checked first)
      if(state == STATE_SELL_ACTIVE && i > setup.entryBar)
      {
         if(high[i] >= setup.pSL)
         {
            stats.nLos++;
            stats.sellLoss++;
            curSLStreak++;
            curTPStreak = 0;
            if(curSLStreak > stats.maxSLStreak)
               stats.maxSLStreak = curSLStreak;

            EngulfAlertCapture(flags, setup, -1, i);
            flags.slHitNow = true;
            flags.resultDir = -1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "SELL SL " + EngulfPriceText(setup.pEntry), InpCSL, InpLabelSize);
            EngulfSetLabelText(setup.lbS, "SL HIT " + EngulfPriceText(setup.pSL), InpCSL, InpLabelSize);
         }
         else if(low[i] <= setup.pTP)
         {
            stats.nWin++;
            stats.sellWins++;
            curTPStreak++;
            curSLStreak = 0;
            if(curTPStreak > stats.maxTPStreak)
               stats.maxTPStreak = curTPStreak;

            EngulfAlertCapture(flags, setup, -1, i);
            flags.tpHitNow = true;
            flags.resultDir = -1;
            state = STATE_NONE;

            EngulfSetLabelText(setup.lbE, "SELL TP " + EngulfPriceText(setup.pEntry), InpCTP, InpLabelSize);
            EngulfSetLabelText(setup.lbT, "TP HIT " + EngulfPriceText(setup.pTP), InpCTP, InpLabelSize);
         }
      }

      // .pine FREEZE COMPLETED SETUP
      if(flags.tpHitNow || flags.slHitNow)
      {
         int xFinal = i + InpExtendB;
         EngulfSetLineX2(setup.lnE, xFinal, setup.pEntry, rates_total, time);
         EngulfSetLineX2(setup.lnS, xFinal, setup.pSL, rates_total, time);
         EngulfSetLineX2(setup.lnT, xFinal, setup.pTP, rates_total, time);
         EngulfSetLineX2(setup.lnBody, xFinal, setup.pBreak, rates_total, time);
         EngulfSetLabelX(setup.lbE, xFinal, setup.pEntry, rates_total, time);
         EngulfSetLabelX(setup.lbS, xFinal, setup.pSL, rates_total, time);
         EngulfSetLabelX(setup.lbT, xFinal, setup.pTP, rates_total, time);
         EngulfSetLabelX(setup.lbBody, xFinal, setup.pBreak, rates_total, time);

         // clear active references; history copies remain
         setup.lnBody = "";
         setup.lbBody = "";
      }


      // =====================================================
      // SIGNAL BUFFERS (EA contract) + ALERTS
      // =====================================================
      if(flags.hitBuy || flags.hitSell)
      {
         if(flags.hitBuy)
            BuyBuffer[i] = setup.pEntry;
         else
            SellBuffer[i] = setup.pEntry;

         SignalSLBuffer[i] = setup.pSL;
         SignalTPBuffer[i] = setup.pTP;
      }

      // Alerts: arm / fill / cancel memakai bar yang sudah close
      // (rates_total - 2) supaya OHLC-nya final; TP/SL tetap boleh intrabar.
      //
      // InpAllowFormingBar = true juga melepas gate arm/fill agar alert
      // "pasang pending" (BREAK BODY) dan "order terisi" (ENTRY FILLED) terbit
      // selagi candle pola masih berjalan - itu inti mode intrabar. Dedupe
      // EngulfAlertOnce memakai waktu bar event, jadi tiap event tetap sekali
      // per bar walau bar itu dievaluasi puluhan kali. Konsekuensinya: pola
      // yang gugur saat close sudah terlanjur diumumkan (alert tidak bisa
      // ditarik), sementara garis/panel/buffer ikut hilang. Alert cancel tetap
      // hanya dari bar close karena cancel memang keputusan close.
      const bool closedBar = (i == rates_total - 2);
      const bool alertArmFillBar = (closedBar || (InpAllowFormingBar && i == rates_total - 1));

      if(paint && (i == rates_total - 1 || closedBar))
      {
         // Every field below comes from the snapshot taken when the event
         // fired, so a setup created later in this same bar cannot rewrite the
         // numbers that are being reported.
         string head    = EngulfAlertHead();
         string setupAt = EngulfAlertBarText(flags.evSetupBar, time);
         string barAt   = EngulfAlertBarText(flags.evEventBar, time);
         string side    = flags.evDir == 1 ? "BUY" : "SELL";
         string rr      = EngulfAlertRRText(flags.evEntry, flags.evSL, flags.evTP);

         if(flags.armedNow && alertArmFillBar && EngulfAlertOnce(EngulfAlertKeyArmed,
                                               EngulfAlertKey("ARMED", flags.evDir, setupAt, barAt),
                                               "ARMED", time[flags.evEventBar]))
         {
            Alert(head + " | BREAK BODY " + side + " @ " + EngulfPriceText(flags.evBreak) +
                  " | pending entry " + EngulfPriceText(flags.evEntry) +
                  " | SL " + EngulfPriceText(flags.evSL) +
                  " | TP " + EngulfPriceText(flags.evTP) +
                  " | RR " + rr +
                  " | setup " + setupAt +
                  " | bar " + barAt);
         }
         if((flags.hitBuy || flags.hitSell) && alertArmFillBar &&
            EngulfAlertOnce(EngulfAlertKeyEntry, EngulfAlertKey("ENTRY", flags.evDir, setupAt, barAt),
                            "ENTRY", time[flags.evEventBar]))
         {
            Alert(head + " | ENTRY " + side + " FILLED @ " + EngulfPriceText(flags.evEntry) +
                  " | SL " + EngulfPriceText(flags.evSL) +
                  " | TP " + EngulfPriceText(flags.evTP) +
                  " | RR " + rr +
                  " | break body " + EngulfPriceText(flags.evBreak) +
                  " | setup " + setupAt +
                  " | fill bar " + barAt);
         }
         if(flags.tpHitNow && EngulfAlertOnce(EngulfAlertKeyTP,
                                               EngulfAlertKey("TP", flags.evDir, setupAt, barAt),
                                               "TP", time[flags.evEventBar]))
         {
            Alert(head + " | TP HIT " + side + " @ " + EngulfPriceText(flags.evTP) +
                  " | entry " + EngulfPriceText(flags.evEntry) +
                  " | SL " + EngulfPriceText(flags.evSL) +
                  " | RR " + rr +
                  " | setup " + setupAt +
                  " | result bar " + barAt);
         }
         if(flags.slHitNow && EngulfAlertOnce(EngulfAlertKeySL,
                                               EngulfAlertKey("SL", flags.evDir, setupAt, barAt),
                                               "SL", time[flags.evEventBar]))
         {
            Alert(head + " | SL HIT " + side + " @ " + EngulfPriceText(flags.evSL) +
                  " | entry " + EngulfPriceText(flags.evEntry) +
                  " | TP " + EngulfPriceText(flags.evTP) +
                  " | RR " + rr +
                  " | setup " + setupAt +
                  " | result bar " + barAt);
         }
         if(flags.cancelledNow && closedBar && EngulfAlertOnce(EngulfAlertKeyCancel,
                                                   EngulfAlertKey("CANCEL", flags.evDir, setupAt, barAt),
                                                   "CANCEL", time[flags.evEventBar]))
         {
            Alert(head + " | CANCELLED " + side + " (opposite signal)" +
                  " | pending entry " + EngulfPriceText(flags.evEntry) +
                  " | SL " + EngulfPriceText(flags.evSL) +
                  " | TP " + EngulfPriceText(flags.evTP) +
                  " | setup " + setupAt +
                  " | cancel bar " + barAt);
         }
         if(flags.closeCancelNow && closedBar &&
            EngulfAlertOnce(EngulfAlertKeyCancelClose,
                            EngulfAlertKey("CANCELED", flags.evDir, setupAt, barAt),
                            "CANCELED", time[flags.evEventBar]))
         {
            Alert(head + " | ENTRY " + side + " CANCELED @ " + EngulfPriceText(flags.evEntry) +
                  " | close bar " + EngulfPriceText(flags.evClose) +
                  " | SL " + EngulfPriceText(flags.evSL) +
                  " | TP " + EngulfPriceText(flags.evTP) +
                  " | RR " + rr +
                  " | setup " + setupAt +
                  " | bar " + barAt);
         }
      }
   }

   // final accumulated stats for the panel
   stats.state = state;

   // Publish the live level on the last bar so the EA sees BUY / SELL activation
   if(state == STATE_BUY_ACTIVE)
   {
      BuyBuffer[rates_total - 1] = setup.pEntry;
      SignalSLBuffer[rates_total - 1] = setup.pSL;
      SignalTPBuffer[rates_total - 1] = setup.pTP;
   }
   else if(state == STATE_SELL_ACTIVE)
   {
      SellBuffer[rates_total - 1] = setup.pEntry;
      SignalSLBuffer[rates_total - 1] = setup.pSL;
      SignalTPBuffer[rates_total - 1] = setup.pTP;
   }

   // Cache the snapshot so OnChartEvent() can repaint the panel after a scroll,
   // zoom or resize without recomputing the whole history.
   EngulfTotalSetups = setupOrdinal;
   LastPanelStats = stats;
   HasLastPanelStats = true;

   EngulfDrawPanel(stats);
}

// Small helpers used by Core / Panel
void PushEngulfName(string &names[], const string name)
{
   int size = ArraySize(names);
   ArrayResize(names, size + 1);
   names[size] = name;
}

void RemoveEngulfName(string &names[], const int index)
{
   int size = ArraySize(names);
   if(index < 0 || index >= size)
      return;

   for(int i = index; i < size - 1; i++)
      names[i] = names[i + 1];

   ArrayResize(names, size - 1);
}

string EngulfTimeframeText()
{
   return EnumToString((ENUM_TIMEFRAMES)_Period);
}
