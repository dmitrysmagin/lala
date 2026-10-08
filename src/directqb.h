/* directqb.h — C binding layer over dqb/dqb.lib (DirectQB 1.61, WASM build).
 *
 * Two levels:
 *  1. Raw externs (UPPERCASE, __far __pascal) matching the ASM X-procs
 *     1:1: FAR, params pushed left-to-right, callee cleans stack.
 *     Far-pointer params are (seg, off) word pairs; Watcom __pascal
 *     pushes far pointers seg-first, verified in spike/probe.c.
 *  2. Mixed-case C wrappers with Sugar: ASCIZ filenames, far buffers.
 *
 * SEGMENT RULES (the ASM assumes them, verified against sources):
 *  - `const char *file` params must be DGROUP-resident (string literals
 *    and globals/static; NOT stack buffers). The wrapper derives DS
 *    via segread() and builds the (seg, off) pair the X-proc wants.
 *  - `void __far *` buffer params may point anywhere (layer/sprite/
 *    palette data); the segment travels explicitly.
 *  - `int *w/h` OUT params: same, must be DGROUP (directqb.c stages
 *    through statics because callers pass stack locals).
 */
#ifndef _DIRECTQB_H_
#define _DIRECTQB_H_

/* Library constants (from DIRECTQB.BI): */
#define AUTO	(-1)
#define ONCE	 (0)
#define LOOPED	 (1)
#define VIDEO	 (0)

/* ------------------------------------------------------------------ */
/* Raw entry points in dqb.lib. Do not call directly; use the     */
/* wrappers below. Signatures mirror the "; Stack layout:" comments   */
/* in the dqb ASM sources.                                            */
/* ------------------------------------------------------------------ */
extern int __far __pascal DQBINIT(int numLayers, int numSounds, int memSize);
extern void __far __pascal DQBCLOSE(void);
extern void __far __pascal DQBCOPYLAYER(int srcLayer, int dstLayer);
extern void __far __pascal DQBCLEARLAYER(int layer);
extern void __far __pascal DQBWAIT(int times);
extern void __far __pascal DQBINITVGA(void);
extern void __far __pascal DQBINITTEXT(void);
extern void __far __pascal DQBFADETO(int red, int green, int blue);
extern void __far __pascal DQBPALOFF(void);
extern void __far __pascal XDQBSETPAL(char __far *pal);
extern void __far __pascal DQBBOX(int layer, int x1, int y1, int x2, int y2, int col);
extern void __far __pascal DQBFILTERBOX(int layer, int x1, int y1, int x2, int y2, int col, int bmap);
extern int __far __pascal DQBCREATEBMAP(int bmap, int firstCol, int lastCol);
extern int __far __pascal XDQBLOADBMAP(int bmap, char __far *file);
extern int __far __pascal XDQBLOADIMAGE(int layer, int x, int y, char __far *file, char __far *pal, int __near *imgW, int __near *imgH);
extern void __far __pascal DQBGET(int layer, int x1, int y1, int x2, int y2, void __far *buf);
extern void __far __pascal DQBPUT(int layer, int x, int y, void __far *buf);
extern void __far __pascal DQBSETTRANSPUT(void);
extern int __far __pascal XDQBLOADFONT(char __far *file);
extern void __far __pascal XDQBPRINT(int layer, char __far *text, int x, int y, int col, int style);
extern void __far __pascal DQBINSTALLKEYBOARD(void);
extern void __far __pascal DQBREMOVEKEYBOARD(void);
extern int __far __pascal DQBKEY(int scanCode);	/* -1 pressed, 0 released */
extern int __far __pascal XDQBINKEY(void);	/* ASCII char, 0 = none */
extern int __far __pascal DQBINSTALLSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma);
extern int __far __pascal XDQBLOADSOUND(int slot, char __far *file);
extern void __far __pascal DQBPLAYSOUND(int soundNum, int voice, int freq, int loopFlag);
extern void __far __pascal DQBSTOPVOICE(int voice);
extern int __far __pascal DQBSHIFTLEFT(int value, int nBits);
extern int __far __pascal DQBSHIFTRIGHT(int value, int nBits);
extern int __far __pascal DQBSETBIT(int value, int bit);
extern int __far __pascal DQBREADBIT(int value, int bit);

/* ------------------------------------------------------------------ */
/* C wrappers (implemented in directqb.c). All return 0 on success    */
/* where the ASM reports errors (same as the QB originals).           */
/* ------------------------------------------------------------------ */
int DQBinit(int numLayers, int numSounds, int memSize);
void DQBclose(void);
void DQBcopyLayer(int srcLayer, int dstLayer);
void DQBclearLayer(int layer);
void DQBwait(int times);
void DQBinitVGA(void);
void DQBinitText(void);
void DQBfadeTo(int red, int green, int blue);
void DQBpalOff(void);
void DQBsetPal(void __far *pal);	/* 768 bytes, any segment */
void DQBbox(int layer, int x1, int y1, int x2, int y2, int col);
void DQBfilterBox(int layer, int x1, int y1, int x2, int y2, int col, int bmap);
int DQBcreateBMap(int bmap, int firstCol, int lastCol);
int DQBloadBMap(int bmap, const char *file);	/* file: literal/global */
int DQBloadImage(int layer, int x, int y, const char *file, void __far *pal, int *imgW, int *imgH);
void DQBget(int layer, int x1, int y1, int x2, int y2, void __far *buf);
void DQBput(int layer, int x, int y, const void __far *buf);
void DQBsetTransPut(void);
int DQBloadFont(const char *file);	/* file: literal/global */
void DQBprint(int layer, const char *text, int x, int y, int col);
void DQBinstallKeyboard(void);
void DQBremoveKeyboard(void);
int DQBkey(int scanCode);
char DQBinkey(void);
int DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma);
int DQBloadSound(int slot, const char *file);	/* file: literal/global */
void DQBplaySound(int soundNum, int voice, int freq, int loopFlag);
void DQBstopVoice(int voice);
int DQBshiftLeft(int value, int nBits);
int DQBshiftRight(int value, int nBits);

#endif /* _DIRECTQB_H_ */
