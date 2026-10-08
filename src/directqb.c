/* directqb.c — thin C wrappers over the raw DQB entry points.
 *
 * Only marshaling lives here: near ASCIZ filename -> far (seg, off),
 * far buffer passthrough, DGROUP staging for near OUT-pointers.
 * No behaviour, no reimplementation.
 */
#include <i86.h>

#include "directqb.h"

/* Near ASCIZ (literal/global, i.e. DGROUP) -> far pointer for X-procs. */
static char __far *near_to_far(const char *p)
{
    struct SREGS sr;
    segread(&sr);
    return (char __far *)MK_FP(sr.ds, FP_OFF(p));
}

/* xDQBloadImage writes imgW/imgH through NEAR pointers using DS, so they
 * must be DGROUP-resident; callers pass stack locals, hence staging. */
static int stagedW, stagedH;

int DQBinit(int numLayers, int numSounds, int memSize)
{
    return DQBINIT(numLayers, numSounds, memSize);
}

void DQBclose(void)
{
    DQBCLOSE();
}

void DQBcopyLayer(int srcLayer, int dstLayer)
{
    DQBCOPYLAYER(srcLayer, dstLayer);
}

void DQBclearLayer(int layer)
{
    DQBCLEARLAYER(layer);
}

void DQBwait(int times)
{
    DQBWAIT(times);
}

void DQBinitVGA(void)
{
    DQBINITVGA();
}

void DQBinitText(void)
{
    DQBINITTEXT();
}

void DQBfadeTo(int red, int green, int blue)
{
    DQBFADETO(red, green, blue);
}

void DQBpalOff(void)
{
    DQBPALOFF();
}

void DQBsetPal(void __far *pal)
{
    XDQBSETPAL((char __far *)pal);
}

void DQBbox(int layer, int x1, int y1, int x2, int y2, int col)
{
    DQBBOX(layer, x1, y1, x2, y2, col);
}

void DQBfilterBox(int layer, int x1, int y1, int x2, int y2, int col, int bmap)
{
    DQBFILTERBOX(layer, x1, y1, x2, y2, col, bmap);
}

int DQBcreateBMap(int bmap, int firstCol, int lastCol)
{
    return DQBCREATEBMAP(bmap, firstCol, lastCol);
}

int DQBloadBMap(int bmap, const char *file)
{
    return XDQBLOADBMAP(bmap, near_to_far(file));
}

int DQBloadImage(int layer, int x, int y, const char *file, void __far *pal, int *imgW, int *imgH)
{
    int rc = XDQBLOADIMAGE(layer, x, y, near_to_far(file),
                           (char __far *)pal, &stagedW, &stagedH);
    if (imgW)
        *imgW = stagedW;
    if (imgH)
        *imgH = stagedH;
    return rc;
}

void DQBget(int layer, int x1, int y1, int x2, int y2, void __far *buf)
{
    DQBGET(layer, x1, y1, x2, y2, buf);
}

void DQBput(int layer, int x, int y, const void __far *buf)
{
    DQBPUT(layer, x, y, (void __far *)buf);
}

void DQBsetTransPut(void)
{
    DQBSETTRANSPUT();
}

int DQBloadFont(const char *file)
{
    return XDQBLOADFONT(near_to_far(file));
}

void DQBprint(int layer, const char *text, int x, int y, int col)
{
    /* DQBprints (with style) is unused by the game; style = 0. */
    XDQBPRINT(layer, near_to_far(text), x, y, col, 0);
}

void DQBinstallKeyboard(void)
{
    DQBINSTALLKEYBOARD();
}

void DQBremoveKeyboard(void)
{
    DQBREMOVEKEYBOARD();
}

int DQBkey(int scanCode)
{
    return DQBKEY(scanCode);
}

char DQBinkey(void)
{
    return (char)XDQBINKEY();
}

int DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma)
{
    return DQBINSTALLSB(volActive, channels, freq, baseAddr, irq, dma);
}

int DQBloadSound(int slot, const char *file)
{
    return XDQBLOADSOUND(slot, near_to_far(file));
}

void DQBplaySound(int soundNum, int voice, int freq, int loopFlag)
{
    DQBPLAYSOUND(soundNum, voice, freq, loopFlag);
}

void DQBstopVoice(int voice)
{
    DQBSTOPVOICE(voice);
}

int DQBshiftLeft(int value, int nBits)
{
    return DQBSHIFTLEFT(value, nBits);
}

int DQBshiftRight(int value, int nBits)
{
    return DQBSHIFTRIGHT(value, nBits);
}
