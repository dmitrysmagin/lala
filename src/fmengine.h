/* fmengine.h — Bisqwit's FMENGINE.BAS ported to C (OpenWatcom 16-bit).
 *
 * OPL2/3 S3M player. Differences from the QB original, all deliberate:
 *  - PLAY/ON PLAY timer mechanism replaced by a PIT channel-0 ISR at
 *    25Hz; FMtimer's `FOR looper = 0 TO 1` is kept, so the effective
 *    frame rate is the S3M-correct 50 frames/sec.
 *  - Patterns are preloaded into RAM at FMload. The original loaded
 *    them from disk inside the timer callback only to save QB memory;
 *    doing file I/O inside a hardware ISR is unsafe. Same bytes.
 *  - All floating point eliminated (period table + vibrato sine table
 *    are precomputed integers) so no FP emulator is linked.
 *  - MPU-401 support stays disabled exactly like the original
 *    (MPUwrite returns immediately); MIDI state machine kept.
 *  - QB `\` integer division truncates in C (QB rounds halves away
 *    from zero); the only affected path is vibrato depth scaling,
 *    off by at most 1 OPL step for exact halves — inaudible.
 */
#ifndef _FMENGINE_H_
#define _FMENGINE_H_

#define OPLBASE 0x388
#define MPUBASE 0x330

#define FM_MAXORDER 256
#define FM_MAXINST 100
#define FM_MAXCHAN 32
#define FM_MAXEFF 4
#define FM_MAXPAT 100
#define FM_PATWORK 2048	/* largest pattern in our S3Ms is 778 bytes */

typedef struct {
	/* Per row */
	int n;	/* note */
	int s;	/* instrument (s=sample) */
	int v;	/* volume */
	int c;	/* cmd */
	int i;	/* info */
	/* Volatiles */
	int DefD;
	int DefE;
	int DefH;
	int CurInst;
	int CurVol;
	int Period;
	int VibPos;	/* 0..63 */
	int effres;	/* allocated effect number. -1 = background music */
	int VibEff;	/* 0=nope, 1=was, 2=is */
} TypeAdlChan;

typedef struct {
	int c4spd;
	int vol;
	int gm;		/* gm program (0-127 or 128-..) */
	int gmadd;	/* disposition (semitones) */
	int gmvol;	/* factor for volumes */
	int gmbank;	/* bank */
} TypeInsData;

typedef struct {
	int CurRow;
	int CurOrd;
	int NeedPat;
	int EdPat;
	int TickPos;
	int SkipRow;
	int ordnum;
	int insnum;
	int patnum;
	int patdelay;
	int patdelaymax;
	int LoopBegin;
	int LoopCount;
	int patpos;	/* 1-based offset within patwork, like QB MID$ */
	int effectA;
	int effectT;
	int effind;
	long effpptr;	/* 0-based pattern-pointer-table offset in effect file */
} TypeFmData;

typedef struct {
	int effA;	/* Axx for effects, distinct */
	int effptr;	/* 1-based offset within effect buffer */
	int effTickPos;
} TypeFmEff;

/* Shared state (QB DIM SHARED). Big tables live in far segments to
 * keep DGROUP small (see PORTING.md 64K quirk); hot small state stays
 * near. Access is transparent in C. */
extern int fmperiod[12];
extern int __far order[FM_MAXORDER];
extern int __far adldata[FM_MAXINST + 1][12];
extern TypeInsData __far insdata[FM_MAXINST + 1];
extern TypeAdlChan adlchan[FM_MAXCHAN];
extern int MIDInote[FM_MAXCHAN];
extern int MIDIchan[FM_MAXCHAN];
extern char fmfile[64];
extern TypeFmData fmdata;
extern TypeFmEff fmeff[FM_MAXEFF];
extern int patLen[FM_MAXPAT];	/* preloaded pattern lengths (test use) */
extern volatile unsigned long fm_writes; /* OPL port writes, for tests */
extern volatile unsigned long fm_ticks;	/* PIT ISR invocations */

/* Music control (QB PLAY equivalents). File paths are DGROUP
 * literals/statics (same rule as DQB wrappers). */
int FMinit(void);
void FMend(void);
void FMstop(void);	/* PLAY STOP: freeze position */
void FMload(const char *file);
void BeSilent(void);

/* Player internals (FMtimer runs in the PIT ISR; callable directly). */
void FMtimer(void);
void FMplayrowfrom(unsigned char __far *pat, int *plen, int *pofs, int effnum);
void FMplayeffect(int ind);
void FMwrite(int i, int d);
void FMnoteoff(int chan, int ope);
void FMtouch(int chan, int ope, int vol, int ins);
void FMupdate(int chan, int ope, int period, int ins, int vol);
void MPUwrite(int b);
long MPUDetect(void);
int MPUvol(int vol, int ins);
int note2period(int note, int oct, int ins);
int VibVal(int *ind, int mode);

#endif /* _FMENGINE_H_ */
