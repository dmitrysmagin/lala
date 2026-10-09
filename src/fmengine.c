/* fmengine.c — Bisqwit's FMENGINE.BAS ported to C (OpenWatcom 16-bit).
 *
 * OPL2/3 S3M player for DirectQB games. See fmengine.h for the
 * deliberate differences from the QB original (PIT instead of PLAY,
 * preloaded patterns, integer-only math).
 *
 * Indexing conventions kept from QB to ease comparison:
 *  - order/adldata/insdata/adlchan use the same 0/1-based indices,
 *  - pattern buffers are 1-based (byte 0 unused), patpos/effptr too.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <conio.h>
#include <i86.h>

#include "fmengine.h"
#include "engine.h"

/* --- Shared state (QB DIM SHARED) --- */

int fmperiod[12];
int __far order[FM_MAXORDER];
int __far adldata[FM_MAXINST + 1][12];
TypeInsData __far insdata[FM_MAXINST + 1];
TypeAdlChan adlchan[FM_MAXCHAN];
int MIDInote[FM_MAXCHAN];
int MIDIchan[FM_MAXCHAN];
char fmfile[64];
TypeFmData fmdata;
TypeFmEff fmeff[FM_MAXEFF];
volatile unsigned long fm_writes = 0;

/* Precomputed tables (host-computed, see PORTING.md). */
static const int FMPERIOD[12] = {
	1712, 1616, 1525, 1440, 1359, 1283,
	1211, 1143, 1078, 1018, 961, 907
};

/* 255*sin(i * 0.09817477042468103), QB banker's rounding. */
static const int SINTAB[64] = {
	0, 25, 50, 74, 98, 120, 142, 162,
	180, 197, 212, 225, 236, 244, 250, 254,
	255, 254, 250, 244, 236, 225, 212, 197,
	180, 162, 142, 120, 98, 74, 50, 25,
	0, -25, -50, -74, -98, -120, -142, -162,
	-180, -197, -212, -225, -236, -244, -250, -254,
	-255, -254, -250, -244, -236, -225, -212, -197,
	-180, -162, -142, -120, -98, -74, -50, -25
};

/* Preloaded song patterns (exact file bytes at [1..len], 1-based use). */
static unsigned char __far *patTab[FM_MAXPAT];
int patLen[FM_MAXPAT];
static unsigned char __far patwork[FM_PATWORK + 2];
static int patworklen;

/* Preloaded effect patterns (FMplayeffect stages these). */
static unsigned char __far *effTab[FM_MAXEFF];
static int effLen[FM_MAXEFF];

/* Music on/off (QB PLAY ON/STOP) + PIT state. */
static volatile int playing = 0;
volatile unsigned long fm_ticks = 0;
static void (__interrupt __far *oldTimer)(void) = 0;

#define PIT_DIV 47727	/* 1193182 / 25 Hz */

/* --- Low level --- */

void FMwrite(int i, int d)
{
	int k;
	outp(OPLBASE, i & 0xFF);
	for (k = 0; k < 6; k++)
		(void)inp(OPLBASE);
	outp(OPLBASE + 1, d & 0xFF);
	for (k = 0; k < 35; k++)
		(void)inp(OPLBASE);
	fm_writes++;
}

void FMnoteoff(int chan, int ope)
{
	FMwrite(0xB0 + chan, 0);
	FMwrite(0x40 + ope, 255);
	FMwrite(0x43 + ope, 255);

	/* Issue MIDI noteoff command */
	MPUwrite(0x80 + MIDIchan[chan]);
	MPUwrite(MIDInote[chan]);
	MPUwrite(127);

	MIDIchan[chan] = -1;
}

void MPUwrite(int b)
{
	(void)b;
	/* disabled in the original ("disabled for now") */
}

void BeSilent(void)
{
	int j;
	for (j = 0; j < 32; j++)
		FMnoteoff(j, j);
	for (j = 0; j < 245; j++)
		FMwrite(j, 0);
}

void FMend(void)
{
	unsigned long __far *ivt;
	playing = 0;	/* PLAY OFF */
	BeSilent();
	_disable();
	ivt = (unsigned long __far *)MK_FP(0, 0);
	ivt[8] = (unsigned long)oldTimer;
	outp(0x43, 0x36);
	outp(0x40, 0);
	outp(0x40, 0);
	_enable();
}

void FMstop(void)
{
	playing = 0;	/* PLAY STOP: freeze position */
}

/* --- PIT music timer (replaces QB PLAY/ON PLAY) --- */

void __interrupt __far FMisr(void)
{
	fm_ticks++;
	if (playing)
		FMtimer();
	outp(0x20, 0x20);
}

static void FMinstallTimer(void)
{
	unsigned long __far *ivt = (unsigned long __far *)MK_FP(0, 0);
	_disable();
	oldTimer = (void (__interrupt __far *)(void))ivt[8];
	ivt[8] = (unsigned long)FMisr;
	outp(0x43, 0x36);	/* mode 3, square wave */
	outp(0x40, PIT_DIV & 0xFF);
	outp(0x40, (PIT_DIV >> 8) & 0xFF);
	_enable();
}

int FMinit(void)
{
	int x, y;
	FMwrite(4, 96);
	FMwrite(4, 128);
	(void)inp(OPLBASE);
	FMwrite(2, 255);
	FMwrite(4, 33);
	/* QB read TIMER twice here as a delay; port reads are enough. */
	(void)inp(OPLBASE);
	FMwrite(4, 96);
	FMwrite(4, 128);

	/* OPL-detect IF is commented out in the original: always proceed. */
	for (x = 0; x < 12; x++)
		fmperiod[x] = FMPERIOD[x];
	BeSilent();
	/* PLAY ON + ON PLAY(1) GOSUB timercallback */
	FMinstallTimer();

	/* Let us load effects. */
	FMload("MUSIC\\EFFECTS.S3M");

	BeSilent();
	fmdata.effind = 0;
	for (x = 0; x < 4; x++)
		fmeff[x].effA = fmdata.effectA;
	for (x = 0; x < 32; x++)
		adlchan[x].effres = -1;
	for (x = 1; x <= fmdata.insnum; x++) {
		for (y = 0; y < 12; y++)
			adldata[70 + x][y] = adldata[x][y];
		insdata[70 + x] = insdata[x];
	}
	fmdata.effpptr = 0x60 + fmdata.ordnum + fmdata.insnum * 2;
	x = (int)MPUDetect();
	(void)x;
	return 1;
}

/* --- File helpers (0-based offsets; QB SEEK is 1-based) --- */

static int rd8(FILE *f, long off)
{
	int c;
	fseek(f, off, SEEK_SET);
	c = fgetc(f);
	return c < 0 ? 0 : c;
}

static int rd16(FILE *f, long off)
{
	int lo, hi;
	fseek(f, off, SEEK_SET);
	lo = fgetc(f);
	hi = fgetc(f);
	if (lo < 0 || hi < 0)
		return 0;
	return lo | (hi << 8);
}

static int qbval(const char *s)
{
	int v = 0, neg = 0;
	while (*s == ' ')
		s++;
	if (*s == '-') {
		neg = 1;
		s++;
	} else if (*s == '+') {
		s++;
	}
	while (*s >= '0' && *s <= '9') {
		v = v * 10 + (*s - '0');
		s++;
	}
	return neg ? -v : v;
}

static void freePatterns(void)
{
	int p;
	for (p = 0; p < FM_MAXPAT; p++) {
		if (patTab[p]) {
			ffree_nw(patTab[p], patLen[p] + 1);
			patTab[p] = 0;
		}
		patLen[p] = 0;
	}
}

void FMload(const char *file)
{
	FILE *f;
	int x, y, p;
	long size;

	playing = 0;	/* PLAY STOP */
	BeSilent();

	_disable();
	freePatterns();

	f = fopen(file, "rb");
	if (!f) {
		_enable();
		printf("FILE NOT FOUND ERROR: %s\n", file);
		return;
	}
	fseek(f, 0, SEEK_END);
	size = ftell(f);
	fseek(f, 0, SEEK_SET);
	if (size <= 0) {
		fclose(f);
		_enable();
		printf("FILE NOT FOUND ERROR: %s\n", file);
		return;
	}

	fmdata.ordnum = rd16(f, 0x20);
	fmdata.insnum = rd16(f, 0x22);
	fmdata.patnum = rd16(f, 0x24);

	fmdata.effectA = rd8(f, 0x31);
	fmdata.effectT = rd8(f, 0x32);

	fseek(f, 0x60, SEEK_SET);
	for (x = 0; x < fmdata.ordnum; x++)
		order[x] = fgetc(f);

	for (x = 1; x <= fmdata.insnum; x++) {
		long insptr;
		char name[29];
		int g, n, n1, c, j;
		insptr = rd16(f, 0x60L + fmdata.ordnum + (long)(x - 1) * 2);
		fseek(f, insptr * 16L + 0x10, SEEK_SET);
		for (y = 0; y < 12; y++)
			adldata[x][y] = fgetc(f);
		fseek(f, insptr * 16L + 0x1C, SEEK_SET);
		insdata[x].vol = fgetc(f);
		insdata[x].c4spd = rd16(f, insptr * 16L + 0x20);
		fseek(f, insptr * 16L + 0x30, SEEK_SET);
		for (y = 0; y < 28; y++) {
			int ch = fgetc(f);
			name[y] = ch < 0 ? 0 : (char)ch;
		}
		name[28] = 0;

		if (name[0] == 'G' && name[1] == 'M')
			g = 0;
		else if (name[0] == 'G' && name[1] == 'P')
			g = 1;
		else
			g = -1;
		if (g < 0) {
			insdata[x].gm = 0;
			insdata[x].gmadd = 0;
			insdata[x].gmvol = 0;
		} else {
			n = qbval(name + 2);
			if (g == 1)
				n1 = n - 35 + 128;
			else
				n1 = n - 1;

			insdata[x].gmadd = 0;
			insdata[x].gmvol = 64;
			insdata[x].gm = n1;
			if (n < 10)
				c = 1;
			else if (n < 100)
				c = 2;
			else
				c = 3;
			j = 2 + c;
			/* NOTE: QB's `ELSEIF c$ = ""` bank branch is dead code
			 * (MID$ never returns "" here); omitted deliberately. */
			while (j < 28) {
				char ch = name[j];
				if (ch == '+' || ch == '-') {
					j++;
					n = qbval(name + j);
					if (n < 10)
						c = 1;
					else if (n < 100)
						c = 2;
					else
						c = 3;
					if (ch == '-')
						n = -n;
					insdata[x].gmadd = n;
					j += c;
				} else if (ch == '/') {
					j++;
					n = qbval(name + j);
					if (n < 10)
						c = 1;
					else if (n < 100)
						c = 2;
					else
						c = 3;
					insdata[x].gmvol = n;
					j += c;
				} else if (ch == '&') {
					j++;
					n = qbval(name + j);
					if (n < 10)
						c = 1;
					else if (n < 100)
						c = 2;
					else
						c = 3;
					j += c;
				} else {
					break;
				}
			}
			/* GM123+4/6: blah blah */
		}
	}

	/* Preload patterns (the original streamed them from disk in the
	 * timer callback to save QB memory; same bytes, RAM instead). */
	if (fmdata.patnum > FM_MAXPAT)
		fmdata.patnum = FM_MAXPAT;
	for (p = 0; p < fmdata.patnum; p++) {
		long patptr, avail;
		int len;
		patptr = rd16(f, 0x60L + fmdata.ordnum + (long)fmdata.insnum * 2 + (long)p * 2);
		len = rd16(f, patptr * 16L);
		/* Parapointer 0 never occurs in our songs; QB would read the
		 * length from file offset 0 and INPUT$ past EOF. Clamp to
		 * what the file holds (same observable bytes). */
		avail = size - (patptr * 16L + 2);
		if (avail < 0)
			avail = 0;
		if (len > avail)
			len = (int)avail;
		if (len > 1024)
			len = 1024;
		if (len > 0) {
			int k;
			patTab[p] = fmalloc_nw(len + 1);
			fseek(f, patptr * 16L + 2, SEEK_SET);
			for (k = 1; k <= len; k++) {
				int ch = fgetc(f);
				((char __far *)patTab[p])[k] = ch < 0 ? 0 : (char)ch;
			}
		}
		patLen[p] = len;
	}

	for (x = 0; x < 32; x++) {
		adlchan[x].CurInst = 0;
		adlchan[x].CurVol = 0;
		adlchan[x].n = 255;
		adlchan[x].s = 0;
		adlchan[x].v = 255;
		adlchan[x].c = 0;
		adlchan[x].i = 0;
		MIDIchan[x] = -1;
	}

	fmdata.CurRow = 0;
	fmdata.CurOrd = 0;
	fmdata.SkipRow = 0;
	fmdata.NeedPat = 1;
	fmdata.LoopBegin = 0;
	fmdata.LoopCount = 0;
	fmdata.TickPos = 0;
	fmdata.EdPat = -1;
	/* NOTE: patdelay/patdelaymax intentionally NOT reset (QB doesn't). */

	fclose(f);
	strncpy(fmfile, file, 63);
	fmfile[63] = 0;

	if (order[fmdata.CurOrd] < 255)
		playing = 1;	/* PLAY ON */
	_enable();
}

void FMplayeffect(int ind)
{
	FILE *f;
	long patptr;
	int patlen;

	playing = 0;	/* PLAY STOP */

	f = fopen("MUSIC\\EFFECTS.S3M", "rb");
	if (!f)
		return;

	patptr = rd16(f, fmdata.effpptr + (long)ind * 2);
	patlen = rd16(f, patptr * 16L);
	if (patlen > 1024)
		patlen = 1024;
	if (effTab[fmdata.effind]) {
		ffree_nw(effTab[fmdata.effind], effLen[fmdata.effind] + 1);
		effTab[fmdata.effind] = 0;
	}
	if (patlen > 0) {
		int k;
		effTab[fmdata.effind] = fmalloc_nw(patlen + 1);
		fseek(f, patptr * 16L + 2, SEEK_SET);
		for (k = 1; k <= patlen; k++) {
			int ch = fgetc(f);
			((char __far *)effTab[fmdata.effind])[k] = ch < 0 ? 0 : (char)ch;
		}
	}
	effLen[fmdata.effind] = patlen;
	fmeff[fmdata.effind].effptr = 1;
	fmeff[fmdata.effind].effTickPos = 0;
	fmdata.effind = (fmdata.effind + 1) & 3;

	fclose(f);

	playing = 1;	/* PLAY ON */
}

/* --- Row player --- */

void FMplayrowfrom(unsigned char __far *pat, int *plen, int *pofs, int effnum)
{
	int c, n, chan, note, ins, vol, cmd, info;
	int ofs;

	if (*plen == 0)
		return;
	ofs = *pofs;

	for (c = 0; c < 32; c++) {
		if (adlchan[c].effres == effnum) {
			adlchan[c].n = 255;
			adlchan[c].s = 0;
			adlchan[c].v = 255;
			adlchan[c].c = 0;
			adlchan[c].i = 0;
		}
	}

	for (;;) {
		int termination = 0;
		c = pat[ofs];
		n = ofs + 1;

		if (c > 0) {
			chan = c & 31;

			if (effnum >= 0)
				adlchan[chan].effres = effnum;

			if (c & 32) {
				note = pat[n];
				n++;
				ins = pat[n];
				n++;
				if (effnum >= 0 || adlchan[chan].effres < 0) {
					if (effnum >= 0)
						ins += 70;
					adlchan[chan].n = note;
					adlchan[chan].s = ins;
				}
			}
			if (c & 64) {
				vol = pat[n];
				n++;
				if (effnum >= 0 || adlchan[chan].effres < 0)
					adlchan[chan].v = vol;
			}
			if (c & 128) {
				cmd = pat[n];
				n++;
				info = pat[n];
				n++;

				if (effnum >= 0 && cmd == 3) {	/* C */
					termination = 1;
					adlchan[chan].effres = -1;
				} else {
					if (effnum >= 0 || adlchan[chan].effres < 0) {
						adlchan[chan].c = cmd;
						adlchan[chan].i = info;
					}

					if (cmd == 1)	/* A */
						fmdata.effectA = adlchan[chan].i;
					if (info == 20)	/* T */
						fmdata.effectT = adlchan[chan].i;
				}
			}
		}
		ofs = n;
		if (c == 0)
			break;
		if (termination) {
			/* Terminate this effect! */
			*plen = 0;
			*pofs = 1;
			return;
		}
	}
	*pofs = ofs;
}

/* --- The timer callback (runs in the PIT ISR, and directly in tests) --- */

void FMtimer(void)
{
	int looper, c, n, x, chan, ope, vol, note, ins, cmd, info;
	int sclass, sinfo, notedelay, notecut, CurTick;
	int vspeed, vdepth, value, Oct, loophere;

	/* Exit quickly if adlib has not been recognized */
	if (fmperiod[0] == 0 || fmfile[0] == 0)
		return;

	/* NOTE: the QB version reprogrammed PLAY tempo here from effectT
	 * (pp/VARPTR$ mechanism). Our PIT runs at a fixed 25Hz and each
	 * call processes two frames, i.e. the S3M-correct 50 frames/sec. */

	for (looper = 0; looper <= 1; looper++) {
		if (fmdata.TickPos == 0) {
			if (fmdata.patdelay == 0) {
				if (fmdata.NeedPat) {
					int CurPat;
					c = 0;
					do {
						CurPat = order[fmdata.CurOrd];
						if (CurPat < 254)
							break;
						fmdata.CurOrd = (fmdata.CurOrd + 1) % fmdata.ordnum;
						c++;
					} while (c < fmdata.ordnum);

					if (CurPat != fmdata.EdPat) {
						int len = (CurPat >= 0 && CurPat < FM_MAXPAT) ? patLen[CurPat] : 0;
						if (len > FM_PATWORK)
							len = FM_PATWORK;
						if (len > 0 && patTab[CurPat])
							_fmemcpy(patwork + 1, (char __far *)patTab[CurPat] + 1, len);
						patworklen = len;
						fmdata.EdPat = CurPat;
					}

					fmdata.CurRow = 0;
					fmdata.NeedPat = 0;
					fmdata.patpos = 1;
				}

				/* Skip rows (may originate from Cxx) */
				while (fmdata.SkipRow > 0) {
					for (;;) {
						n = 1;
						c = patwork[fmdata.patpos];
						if (c & 32)
							n += 2;
						if (c & 64)
							n += 1;
						if (c & 128)
							n += 2;
						fmdata.patpos += n;
						if (c == 0)
							break;
					}
					fmdata.SkipRow--;
					fmdata.CurRow++;
				}

				/* fmpattern$ points to the current row. */
				FMplayrowfrom(patwork, &patworklen, &fmdata.patpos, -1);
			}
			fmdata.TickPos = fmdata.effectA;
		}
		for (x = 0; x < 4; x++) {
			if (fmeff[x].effTickPos == 0) {
				/* Time to fetch a new row for the effect... */
				c = fmdata.effectA;
				fmdata.effectA = fmeff[x].effA;
				FMplayrowfrom(effTab[x], &effLen[x], &fmeff[x].effptr, x);
				fmeff[x].effA = fmdata.effectA;
				fmdata.effectA = c;
				fmeff[x].effTickPos = fmeff[x].effA;
				fmeff[x].effTickPos = fmeff[x].effA;
			}
		}

		loophere = 0;
		for (x = -1; x <= 3; x++) {
			if (x >= 0)
				CurTick = fmeff[x].effA - fmeff[x].effTickPos;
			else
				CurTick = fmdata.effectA - fmdata.TickPos;	/* 0..(A-1) */

			for (c = 0; c <= 8; c++) {
				if (adlchan[c].effres == x) {
					/* Mark the vibrato obsolete */
					if (adlchan[c].VibEff == 2)
						adlchan[c].VibEff = 1;

					chan = c;	/* FIXME: Take from the headers */
					ope = chan;
					if (chan > 2)
						ope += 5;
					if (chan > 5)
						ope += 5;

					notedelay = 0;
					notecut = -1;

					cmd = adlchan[c].c;
					info = adlchan[c].i;

					if (cmd == 19) {	/* S */
						sclass = info / 16;
						sinfo = info & 15;

						if (sclass == 11) {	/* B */
							if (CurTick == 0) {
								if (sinfo == 0) {
									fmdata.LoopBegin = fmdata.CurRow;
								} else {
									if (fmdata.LoopCount == 0)
										fmdata.LoopCount = sinfo + 1;
								}
							}
							if (sinfo > 0)
								loophere = 1;
						}
						if (sclass == 12)	/* C */
							notecut = sinfo;
						if (sclass == 13)	/* D */
							notedelay = sinfo;
						if (sclass == 14) {	/* E */
							if (CurTick == 0) {
								if (fmdata.patdelay == 0) {
									fmdata.patdelay = sinfo;
									fmdata.patdelaymax = sinfo;
								} else {
									fmdata.patdelay--;
								}
							}
						}
					}
					if (notedelay == CurTick &&
						(fmdata.patdelay == fmdata.patdelaymax || CurTick > 0)) {
						vol = adlchan[c].v;
						note = adlchan[c].n;
						ins = adlchan[c].s;
						if (ins == 0)
							ins = adlchan[c].CurInst;
						else
							adlchan[c].CurInst = ins;
						if (ins > 0) {
							if (vol == 255) {
								vol = insdata[ins].vol;
							} else {
								FMtouch(chan, ope, vol, ins);
								adlchan[c].CurVol = vol;
							}
							if (note < 255) {	/* Something indeed mentioned */
								FMnoteoff(chan, ope);
								if (note != 254) {	/* adlib notecut */
									Oct = note / 16;
									note &= 15;

									adlchan[c].Period = note2period(note, Oct, ins);

									FMupdate(chan, ope, adlchan[c].Period, ins, vol);
									adlchan[c].CurVol = vol;
								}
							}
						}
					}
					if (adlchan[c].CurInst > 0) {	/* No command on channels without instrus playing */
						if (cmd == 4 || cmd == 11) {	/* D, K */
							vol = adlchan[c].CurVol;
							if (info == 0)
								info = adlchan[c].DefD;
							else
								adlchan[c].DefD = info;
							if (info == 255) {	/* FF */
								vol = 64;
							} else if (info >= 240) {	/* F0..FE */
								if (CurTick == 0)
									vol -= info & 15;
							} else if (info < 16) {	/* 01..0F */
								vol -= info & 15;
							} else if ((info & 15) == 15) {
								if (CurTick == 0)
									vol += info / 16;
							} else if (info <= 240) {	/* 10..F0 */
								vol += info / 16;
							}
							if (vol < 0)
								vol = 0;
							else if (vol > 64)
								vol = 64;
							adlchan[c].CurVol = vol;
							FMtouch(chan, ope, vol, adlchan[c].CurInst);
						}
						if (cmd == 5 || cmd == 6) {	/* E or F */
							if (info == 0)
								info = adlchan[c].DefE;
							else
								adlchan[c].DefE = info;
							if (cmd == 6)
								info = -info;
							adlchan[c].Period = adlchan[c].Period + info * 4;
							FMupdate(chan, ope, adlchan[c].Period, adlchan[c].CurInst, adlchan[c].CurVol);
						}
						if (cmd == 8 || cmd == 11) {	/* H, K */
							if (cmd == 11)
								info = 0;
							if (info == 0)
								info = adlchan[c].DefH;
							else
								adlchan[c].DefH = info;
							if (adlchan[c].VibEff == 0)
								adlchan[c].VibPos = 0;
							vspeed = info / 16;
							vdepth = info & 15;
							value = VibVal(&adlchan[c].VibPos, 0) * vdepth / 32;
							FMupdate(chan, ope, adlchan[c].Period + value, adlchan[c].CurInst, adlchan[c].CurVol);
							adlchan[c].VibPos += vspeed;
							adlchan[c].VibEff = 2;
						}
						if (notecut == CurTick &&
							(fmdata.patdelay == fmdata.patdelaymax || CurTick > 0)) {
							FMnoteoff(chan, ope);
						}
					}
					if (adlchan[c].VibEff == 1) {	/* Vibrato still obsolete? */
						adlchan[c].VibEff = 0;	/* No more vibrato */
						FMupdate(chan, ope, adlchan[c].Period, adlchan[c].CurInst, adlchan[c].CurVol);
					}
				}
			}
		}

		fmdata.TickPos--;
		for (x = 0; x < 4; x++)
			fmeff[x].effTickPos--;

		/* If this row is finished, find out where to go next. */
		if (fmdata.TickPos == 0 && fmdata.patdelay == 0) {
			int brkord = -1;
			int brkrow = -1;
			int doloop = 0;

			fmdata.patdelaymax = 0;
			fmdata.CurRow++;
			if (fmdata.CurRow == 64)
				brkrow = 0;

			if (fmdata.LoopCount > 0 && loophere) {
				fmdata.LoopCount--;
				if (fmdata.LoopCount == 0) {
					/* SB0 pending. */
					fmdata.LoopBegin = fmdata.CurRow;
				} else {
					brkord = fmdata.CurOrd;
					brkrow = fmdata.LoopBegin;
					doloop = 1;
				}
			}

			if (!doloop) {
				for (c = 0; c <= 8; c++) {
					cmd = adlchan[c].c;	/* 1=A, 2=B, and so on... 0=none */
					info = adlchan[c].i;

					if (cmd == 2) {	/* B */
						brkord = info;
						fmdata.LoopBegin = 0;
					}
					if (cmd == 3) {	/* C */
						brkrow = (info / 16) * 10 + (info & 15);
						fmdata.LoopBegin = 0;
					}
				}
				if (brkord >= 0 && brkrow == -1)
					brkrow = 0;
			}
			if (brkrow >= 0) {
				fmdata.CurOrd = (fmdata.CurOrd + 1) % fmdata.ordnum;
				fmdata.NeedPat = 1;
				if (brkord >= 0)
					fmdata.CurOrd = brkord;
				fmdata.SkipRow = brkrow;
			}
		}
	}
}

/* --- Instrument voice --- */

void FMtouch(int chan, int ope, int vol, int ins)
{
	int v = vol * 63 / 64;
	int c;

	c = adldata[ins][2] & 0xC0;
	c |= 63 + (adldata[ins][2] & 63) * v / 63 - v;
	FMwrite(0x40 + ope, c);

	c = adldata[ins][3] & 0xC0;
	c |= 63 + (adldata[ins][3] & 63) * v / 63 - v;
	FMwrite(0x43 + ope, c);

	MPUwrite(0xB0 + MIDIchan[chan]);
	MPUwrite(7);	/* Master volume */

	v = MPUvol(vol, ins);
	MPUwrite(v);
}

void FMupdate(int chan, int ope, int period, int ins, int vol)
{
	/* Patch with the instrument data */
	long Herz;
	int Oct, n;

	if (ins <= 0)
		return;

	FMwrite(0x20 + ope, adldata[ins][0]);
	FMwrite(0x60 + ope, adldata[ins][4]);
	FMwrite(0x80 + ope, adldata[ins][6]);
	FMwrite(0xE0 + ope, adldata[ins][8] & 3);

	FMwrite(0x23 + ope, adldata[ins][1]);
	FMwrite(0x63 + ope, adldata[ins][5]);
	FMwrite(0x83 + ope, adldata[ins][7]);
	FMwrite(0xE3 + ope, adldata[ins][9] & 3);

	FMwrite(0xC0 + chan, adldata[ins][10] | 0x30);

	/* MIDI branch (MPU output disabled; keep channel state only).
	 * The original computed n = gmadd + CINT(60.10259 +
	 * 17.31234 * LOG(...)) here; unobservable without MPU. */
	if (insdata[ins].gm < 128) {
		n = 0;
		if (MIDIchan[chan] == -1) {
			MIDIchan[chan] = chan;
			MIDInote[chan] = n;

			MPUwrite(0xC0 + MIDIchan[chan]);	/* Patch */
			MPUwrite(insdata[ins].gm);

			MPUwrite(0x90 + MIDIchan[chan]);
			MPUwrite(MIDInote[chan]);
			MPUwrite(127);
		}
	} else {
		if (MIDIchan[chan] == -1) {
			MIDIchan[chan] = 9;	/* Percussion */
			MIDInote[chan] = insdata[ins].gm + 35 - 128;

			MPUwrite(0x90 + MIDIchan[chan]);
			MPUwrite(MIDInote[chan]);
			MPUwrite(127);
		}
	}

	FMtouch(chan, ope, vol, ins);

	Oct = 0;
	if (period == 0) {
		/* Exception, circumvention of a bug or something */
		Herz = 0;
	} else {
		/* 5500 = 22000 / 4 */
		Herz = (long)fmperiod[0] * 5500L / period;
	}

	while (Herz >= 512) {
		Oct++;
		Herz >>= 1;
	}

	FMwrite(0xA0 + chan, (int)(Herz & 255));
	FMwrite(0xB0 + chan, 32 | (int)((Herz >> 8) & 3) | ((Oct & 7) * 4));
}

/* --- Helpers --- */

long MPUDetect(void)
{
	int b;

	outp(MPUBASE + 1, 255);
	b = 10000;
	while ((inp(MPUBASE + 1) & 0x40) != 0) {
		if (--b == 0)
			return 0;
	}
	outp(MPUBASE + 1, 255);
	b = 10000;
	for (;;) {
		while ((inp(MPUBASE + 1) & 0x80) != 0) {
			if (--b == 0)
				return 0;
		}

		if (inp(MPUBASE) != 254)
			continue;
		break;
	}

	while ((inp(MPUBASE + 1) & 0x40) != 0)
		;
	outp(MPUBASE + 1, 63);
	b = 10000;
	for (;;) {
		while ((inp(MPUBASE + 1) & 0x80) != 0) {
			if (--b == 0)
				return 0;
		}

		if (inp(MPUBASE) != 254)
			continue;
		break;
	}

	return -1;
}

int MPUvol(int vol, int ins)
{
	(void)vol;
	(void)ins;
	/* Value feeds only the disabled MPUwrite; keep it simple. */
	return 0;
}

int note2period(int note, int oct, int ins)
{
	long c4spd = (long)insdata[ins].c4spd;
	long tmp;

	tmp = 8363L * 16L * (long)fmperiod[note];

	if (c4spd == 0) {
		/* Exception, circumvention of a bug or something */
		return 0;
	}
	return (int)((tmp >> oct) / c4spd);
}

int VibVal(int *ind, int mode)
{
	/* The variable pointed by "ind" IS modified (QB BYREF param). */
	if (mode >= 4) {
		*ind &= 63;
	} else if (*ind >= 64) {
		*ind = 0;
	}

	switch (mode) {
	case 0:
		return SINTAB[*ind];
	case 1:
		if (*ind == 0)
			return 0;
		return -256 + *ind * 8;
	case 2:
		if (*ind < 0)
			return 0;
		return 255;
	default:
		break;
	}
	return 0;
}
