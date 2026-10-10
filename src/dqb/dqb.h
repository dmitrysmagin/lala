#ifndef DQB_H
#define DQB_H

#define AUTO    (-1)
#define ONCE    (0)
#define LOOPED  (1)
#define VIDEO   (0)

#define DQBAPI __far __pascal

/* P0: init/close/layers/VGA/wait */
extern int DQBAPI DQBinit(int numLayers, int numSounds, int memSize);
extern void DQBAPI DQBclose(void);
extern void DQBAPI DQBcopyLayer(int srcLayer, int dstLayer);
extern void DQBAPI DQBclearLayer(int layer);
extern void DQBAPI DQBwait(int times);
extern void DQBAPI DQBinitVGA(void);
extern void DQBAPI DQBinitText(void);
/* MAIN extras */
extern int DQBAPI DQBver(void);
extern int DQBAPI DQBmapLayer(int layer);
extern void DQBAPI xDQBerror(char __far *dst);
extern void DQBAPI DQBsort(int arraySeg, int arrayOff, int numRecords, int recordLen, int indexOff);
extern int DQBAPI DQBangle(int x1, int y1, int x2, int y2);
extern void DQBAPI DQBsetFrameRate(int fps);
extern int DQBAPI DQBframeReady(void);
extern int DQBAPI DQBsetBaseLayer(int layer);
extern void DQBAPI DQBpeek(int dataSeg, int dataOff, long offset, int length);
extern void DQBAPI DQBpoke(int dataSeg, int dataOff, long offset, int length);
extern void DQBAPI DQBFPU(void);
extern void DQBAPI DQBINT3D(void);
/* P1: palette */
extern void DQBAPI DQBsetCol(int colorIndex, int r, int g, int b);
extern void DQBAPI DQBgetCol(int colorIndex, int __near *r, int __near *g, int __near *b);
extern int DQBAPI DQBfindCol(int red, int green, int blue);
extern int DQBAPI xDQBfindPalCol(char __far *pal, int red, int green, int blue);
extern void DQBAPI xDQBsetPal(char __far *pal);
extern void DQBAPI xDQBgetPal(char __far *pal);
extern void DQBAPI xDQBfadeIn(char __far *pal);
extern void DQBAPI xDQBfadeStepIn(char __far *pal);
extern void DQBAPI DQBfadeTo(int red, int green, int blue);
extern void DQBAPI DQBfadeStepTo(int red, int green, int blue);
extern void DQBAPI DQBpalOff(void);
extern void DQBAPI DQBpalRotate(int firstCol, int lastCol, int rotateDir);
/* P2: draw */
extern void DQBAPI DQBcopyTransLayer(int srcLayer, int dstLayer);
extern void DQBAPI DQBcopyHitLayer(int srcLayer, int dstLayer, int col);
extern void DQBAPI DQBpset(int layer, int x, int y, int col);
extern int DQBAPI DQBpoint(int layer, int x, int y);
extern void DQBAPI DQBline(int layer, int x1, int y1, int x2, int y2, int col);
extern void DQBAPI DQBgline(int layer, int x1, int y1, int x2, int y2, int col1, int col2);
extern void DQBAPI DQBellipse(int layer, int x, int y, int rx, int ry, int col);
extern void DQBAPI DQBbox(int layer, int x1, int y1, int x2, int y2, int col);
extern void DQBAPI DQBboxf(int layer, int x1, int y1, int x2, int y2, int col);
extern void DQBAPI DQBpaint(int layer, int x, int y, int col);
extern void DQBAPI DQBscroll(int layer, int dx, int dy);
extern void DQBAPI DQBscrollArea(int layer, int x1, int y1, int x2, int y2, int direction);
extern void DQBAPI DQBsetTransPut(void);
extern void DQBAPI DQBsetSolidPut(void);
extern void DQBAPI DQBget(int layer, int x1, int y1, int x2, int y2, void __far *buf);
extern void DQBAPI DQBput(int layer, int x, int y, const void __far *buf);
/* SPRITE */
extern int DQBAPI DQBsize(int x1, int y1, int x2, int y2);
extern void DQBAPI DQBsetClipBox(int x1, int y1, int x2, int y2);
extern void DQBAPI DQBsPut(int layer, int x, int y, const void __far *buf, int newW, int newH);
extern void DQBAPI DQBrPut(int layer, int x, int y, const void __far *buf, int angle, int zoom);
extern void DQBAPI DQBfPut(int layer, int x, int y, const void __far *buf);
extern void DQBAPI DQBxPut(int srcLayer, int x1, int y1, int x2, int y2, int dstLayer, int x, int y);
extern void DQBAPI DQBmPut(int layer, int x, int y, const void __far *buf, int flip);
extern void DQBAPI DQBhPut(int layer, int x, int y, const void __far *buf, int col);
extern void DQBAPI DQBtPut(int layer, int x, int y, const void __far *buf, int bitMode);
extern void DQBAPI DQBpPut(int layer, int x, int y, const void __far *buf, int pattern);
extern void DQBAPI DQBputOver(int backSeg, int backOff, int x, int y, const void __far *buf);
extern int DQBAPI DQBcollide(int x1, int y1, int seg1, int off1, int x2, int y2, int seg2, int off2);
extern int DQBAPI DQBcollideOnLayer(int layer, int x, int y, int spriteSeg, int spriteOff);
extern void DQBAPI DQBsetCollideMethod(int method);
/* P2: blending */
extern void DQBAPI DQBfilterBox(int layer, int x1, int y1, int x2, int y2, int col, int bmap);
extern void DQBAPI DQBbPut(int layer, int x, int y, const void __far *buf, int bmap);
extern void DQBAPI DQBcopyBlendLayer(int srcLayer, int dstLayer, int bmap);
extern int DQBAPI DQBcreateBMap(int bmap, int firstCol, int lastCol);
extern void DQBAPI DQBsetBMap(int bmap, int foreCol, int backCol, int newCol);
extern int DQBAPI DQBgetBMap(int bmap, int foreCol, int backCol);
extern int DQBAPI xDQBloadBMap(int bmap, char __far *file);
extern int DQBAPI xDQBsaveBMap(int bmap, char __far *file);
extern void DQBAPI DQBremoveBMap(int bmap);
/* P3: font/image */
extern int DQBAPI xDQBloadFont(char __far *file);
extern void DQBAPI xDQBprint(int layer, char __far *text, int x, int y, int col, int style);
extern void DQBAPI DQBsetFontTexture(char __far *text);
extern void DQBAPI DQBsetTextSpacing(int spacing);
extern int DQBAPI xDQBlen(char __far *text);
extern void DQBAPI DQBsetBIOSfont(void);
extern void DQBAPI xDQBsetFont(char __far *font);
extern void DQBAPI DQBsetTextBackCol(int col);
extern void DQBAPI DQBsetTextBMap(int bmap);
extern void DQBAPI DQBsetTextStyle(int style);
extern int DQBAPI xDQBloadImage(int layer, int x, int y, char __far *file, char __far *pal, int __near *imgW, int __near *imgH);
extern int DQBAPI xDQBsaveImage(int layer, int x1, int y1, int x2, int y2, char __far *file, char __far *pal, int format);
extern int DQBAPI xDQBplayFLI(char __far *file, int bufLayer, int stopKey, int looped);
extern int DQBAPI xDQBopenFLI(char __far *file, int __near *frames, int __near *speed);
extern void DQBAPI DQBcloseFLI(void);
extern void DQBAPI DQBplayFLIstep(int layer);
/* P4: keyboard */
extern void DQBAPI DQBinstallKeyboard(void);
extern void DQBAPI DQBremoveKeyboard(void);
extern int DQBAPI DQBkey(int scanCode);
extern int DQBAPI DQBreadKey(void);
extern void DQBAPI DQBwaitKey(int scanCode);
extern int DQBAPI DQBasc(int scanCode, int shiftFlag);
extern int DQBAPI xDQBinkey(void);
extern unsigned char KeyStatus[128];
/* DISK */
extern void DQBAPI xDQBdir(char __far *mask, int attrib, char __far *file);
extern int DQBAPI xDQBdrive(void);
extern void DQBAPI xDQBpath(char __far *path);
extern int DQBAPI DQBnumDrives(void);
extern void DQBAPI xDQBsetDrive(int driveCode);
extern int DQBAPI xDQBchDir(char __far *dir);
/* DATAFILE */
extern int DQBAPI xDQBopenDataFile(char __far *file, char __far *pwd);
extern int DQBAPI xDQBunpackFont(int packID, char __far *font);
extern int DQBAPI DQBunpackImage(int packID, int layer, int x, int y);
extern int DQBAPI DQBunpackSprite(int packID, void __far *sprite);
extern int DQBAPI DQBunpackSound(int packID, int slot);
extern int DQBAPI xDQBunpackPal(int packID, char __far *pal);
extern int DQBAPI DQBunpackBMap(int packID, int bmap);
extern int DQBAPI xDQBunpackCursor(int packID, char __far *cursor);
extern int DQBAPI DQBunpackUser(int packID, void __far *data);
extern void DQBAPI DQBcloseDataFile(void);
/* MOUSE */
extern int DQBAPI DQBmouseDetected(void);
extern int DQBAPI DQBmouseX(void);
extern int DQBAPI DQBmouseY(void);
extern int DQBAPI DQBmouseLB(void);
extern int DQBAPI DQBmouseRB(void);
extern void DQBAPI DQBsetMousePos(int x, int y);
extern void DQBAPI DQBmouseShow(void);
extern void DQBAPI DQBmouseHide(void);
extern void DQBAPI DQBsetMouseRange(int x1, int y1, int x2, int y2);
extern void DQBAPI xDQBsetMouseShape(int hotX, int hotY, char __far *shape);
extern void DQBAPI DQBsetMouseSpeed(int hor, int ver);
extern void DQBAPI DQBresetMouse(void);
/* JOYSTICK */
extern int DQBAPI DQBjoyDetected(int joyNum);
extern void DQBAPI DQBpollJoy(int joyNum);
extern int DQBAPI DQBjoyMove(int joyNum, int direction);
extern int DQBAPI DQBjoyX(int joyNum);
extern int DQBAPI DQBjoyY(int joyNum);
extern int DQBAPI DQBjoyFire(int joyNum, int button);
extern void DQBAPI DQBresetJoy(void);
extern void DQBAPI DQBsetJoySens(int newSens);
/* THREED */
extern void DQBAPI DQBtri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int col);
extern void DQBAPI DQBbtri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int col, int bmap);
extern void DQBAPI DQBgtri(int layer, int x1, int y1, int c1, int x2, int y2, int c2, int x3, int y3, int c3);
extern void DQBAPI DQBbgtri(int layer, int x1, int y1, int c1, int x2, int y2, int c2, int x3, int y3, int c3, int bmap);
extern void DQBAPI DQBttri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int u1, int v1, int u2, int v2, int u3, int v3, int texSeg, int texOff);
extern void DQBAPI DQBbttri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int u1, int v1, int u2, int v2, int u3, int v3, int texSeg, int texOff, int bmap);
extern void DQBAPI DQBfttri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int u1, int v1, int u2, int v2, int u3, int v3, int texSeg, int texOff);
extern void DQBAPI DQBsetTextureSize(int size);
/* SOUND */
extern int DQBAPI DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma);
extern int DQBAPI xDQBloadSound(int slot, char __far *file);
extern int DQBAPI xDQBloadRawSound(int slot, char __far *file, int hiOff, int loOff, int length);
extern void DQBAPI DQBplaySound(int soundNum, int voice, int freq, int loopFlag);
extern int DQBAPI DQBinUse(int voice);
extern void DQBAPI DQBpauseSound(void);
extern void DQBAPI DQBresumeSound(void);
extern void DQBAPI DQBstopVoice(int voice);
extern void DQBAPI DQBsetVoiceVol(int voice, int newVol);
extern void DQBAPI DQBremoveSB(void);
extern void DQBAPI DQBsetFreq(int voice, int sampleRate);
extern void DQBAPI DQBsetVolume(int volume);
/* BIT */
extern int DQBAPI DQBshiftLeft(int value, int nBits);
extern int DQBAPI DQBshiftRight(int value, int nBits);
extern int DQBAPI DQBsetBit(int value, int bit);
extern int DQBAPI DQBresetBit(int value, int bit);
extern int DQBAPI DQBreadBit(int value, int bit);
extern int DQBAPI DQBtoggleBit(int value, int bit);

int DQBloadImage(int layer, int x, int y, const char __far *file, void __far *pal, int *imgW, int *imgH);
void DQBprint(int layer, const char __far *text, int x, int y, int col);

#endif
