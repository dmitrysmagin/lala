#ifndef DQB_H
#define DQB_H

#define AUTO    (-1)
#define ONCE    (0)
#define LOOPED  (1)
#define VIDEO   (0)

#define DQBAPI __far __pascal

extern int DQBAPI DQBinit(int numLayers, int numSounds, int memSize);
extern void DQBAPI DQBclose(void);
extern void DQBAPI DQBcopyLayer(int srcLayer, int dstLayer);
extern void DQBAPI DQBclearLayer(int layer);
extern void DQBAPI DQBwait(int times);
extern void DQBAPI DQBinitVGA(void);
extern void DQBAPI DQBinitText(void);
extern void DQBAPI DQBfadeTo(int red, int green, int blue);
extern void DQBAPI DQBpalOff(void);
extern void DQBAPI xDQBsetPal(char __far *pal);
extern void DQBAPI DQBbox(int layer, int x1, int y1, int x2, int y2, int col);
extern void DQBAPI DQBfilterBox(int layer, int x1, int y1, int x2, int y2, int col, int bmap);
extern int DQBAPI DQBcreateBMap(int bmap, int firstCol, int lastCol);
extern int DQBAPI xDQBloadBMap(int bmap, char __far *file);
extern int DQBAPI xDQBloadImage(int layer, int x, int y, char __far *file, char __far *pal, int __near *imgW, int __near *imgH);
extern void DQBAPI DQBget(int layer, int x1, int y1, int x2, int y2, void __far *buf);
extern void DQBAPI DQBput(int layer, int x, int y, const void __far *buf);
extern void DQBAPI DQBsetTransPut(void);
extern int DQBAPI xDQBloadFont(char __far *file);
extern void DQBAPI xDQBprint(int layer, char __far *text, int x, int y, int col, int style);
extern void DQBAPI DQBinstallKeyboard(void);
extern void DQBAPI DQBremoveKeyboard(void);
extern int DQBAPI DQBkey(int scanCode);
extern int DQBAPI xDQBinkey(void);
extern unsigned char KeyStatus[128];
extern int DQBAPI DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma);
extern int DQBAPI xDQBloadSound(int slot, char __far *file);
extern void DQBAPI DQBplaySound(int soundNum, int voice, int freq, int loopFlag);
extern void DQBAPI DQBstopVoice(int voice);
extern void DQBAPI DQBremoveSB(void);
extern int DQBAPI DQBshiftLeft(int value, int nBits);
extern int DQBAPI DQBshiftRight(int value, int nBits);
extern int DQBAPI DQBsetBit(int value, int bit);
extern int DQBAPI DQBreadBit(int value, int bit);

int DQBloadImage(int layer, int x, int y, const char __far *file, void __far *pal, int *imgW, int *imgH);
void DQBprint(int layer, const char __far *text, int x, int y, int col);

#endif
