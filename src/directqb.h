/* directqb.h — C bindings over dqb/dqb.lib (DirectQB 1.61, WASM build).
 *
 * All functions are called DIRECTLY with __far __pascal, which matches
 * the ASM convention 1:1 (FAR, params pushed left-to-right, callee
 * cleans). __pascal uppercases the symbol, so CamelCase source names
 * link against the UPPERCASE lib publics (verified in spike/probe5) —
 * i.e. DQBinit here IS DQBINIT in the lib. No wrappers, no pragmas.
 *
 * Signatures mirror the "; Stack layout:" comments in the dqb ASM sources:
 * far-pointer params are (seg, off) word pairs; Watcom pushes far
 * pointers seg-first, and materializes near->far with DS, so string
 * literals and DGROUP buffers pass straight through (verified live
 * by the render test in src/engtest.c).
 *
 * SEGMENT RULES (the ASM assumes them, verified against sources):
 *  - `char __far *file` params: literals and DGROUP buffers only,
 *    NOT stack buffers (the compiler supplies DS as the segment).
 *  - `void __far *` buffer params may point anywhere (layer/sprite/
 *    palette data); the segment travels explicitly.
 *  - DQBloadImage's imgW/imgH are stored through DS, so callers must
 *    pass DGROUP ints — directqb.c stages stack locals through
 *    statics so callers can keep using locals.
 */
#ifndef _DIRECTQB_H_
#define _DIRECTQB_H_

/* Library constants (from DIRECTQB.BI): */
#define AUTO    (-1)
#define ONCE     (0)
#define LOOPED     (1)
#define VIDEO     (0)

/* Direct lib bindings (dqb/dqb.lib). All return 0 on success where
 * the ASM reports errors (same as the QB originals). */
extern int __far __pascal DQBinit(int numLayers, int numSounds, int memSize);
extern void __far __pascal DQBclose(void);
extern void __far __pascal DQBcopyLayer(int srcLayer, int dstLayer);
extern void __far __pascal DQBclearLayer(int layer);
extern void __far __pascal DQBwait(int times);
extern void __far __pascal DQBinitVGA(void);
extern void __far __pascal DQBinitText(void);
extern void __far __pascal DQBfadeTo(int red, int green, int blue);
extern void __far __pascal DQBpalOff(void);
extern void __far __pascal xDQBsetPal(char __far *pal);    /* 768 bytes */
extern void __far __pascal DQBbox(int layer, int x1, int y1, int x2, int y2, int col);
extern void __far __pascal DQBfilterBox(int layer, int x1, int y1, int x2, int y2, int col, int bmap);
extern int __far __pascal DQBcreateBMap(int bmap, int firstCol, int lastCol);
extern int __far __pascal xDQBloadBMap(int bmap, char __far *file);
extern int __far __pascal xDQBloadImage(int layer, int x, int y, char __far *file, char __far *pal, int __near *imgW, int __near *imgH);
extern void __far __pascal DQBget(int layer, int x1, int y1, int x2, int y2, void __far *buf);
extern void __far __pascal DQBput(int layer, int x, int y, const void __far *buf);
extern void __far __pascal DQBsetTransPut(void);
extern int __far __pascal xDQBloadFont(char __far *file);
extern void __far __pascal xDQBprint(int layer, char __far *text, int x, int y, int col, int style);
extern void __far __pascal DQBinstallKeyboard(void);
extern void __far __pascal DQBremoveKeyboard(void);
extern int __far __pascal DQBkey(int scanCode);	/* -1 pressed, 0 released */
extern int __far __pascal xDQBinkey(void);	/* ASCII char, 0 = none */
/* Scancode table owned by the keyboard ISR (128 entries, 1 = pressed).
 * Tests poke it directly to script input; the game never touches it. */
#pragma aux KeyStatus "KEYSTATUS"
extern unsigned char KeyStatus[128];
extern int __far __pascal DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma);
extern int __far __pascal xDQBloadSound(int slot, char __far *file);
extern void __far __pascal DQBplaySound(int soundNum, int voice, int freq, int loopFlag);
extern void __far __pascal DQBstopVoice(int voice);
extern int __far __pascal DQBshiftLeft(int value, int nBits);
extern int __far __pascal DQBshiftRight(int value, int nBits);
extern int __far __pascal DQBsetBit(int value, int bit);
extern int __far __pascal DQBreadBit(int value, int bit);

/* Two thin wrappers stay in directqb.c (real added value only):
 * DQBloadImage stages stack int locals through DGROUP statics;
 * DQBprint supplies style = 0 (DQBprints is unused by the game). */
int DQBloadImage(int layer, int x, int y, const char __far *file, void __far *pal, int *imgW, int *imgH);
void DQBprint(int layer, const char __far *text, int x, int y, int col);

#endif /* _DIRECTQB_H_ */
