/* main_extra.c — remaining MAIN.ASM publics (C port). */
#include "dqb_int.h"
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <math.h>
#include <string.h>

static char ErrorMsgs[30][33] = {
    "Library already initialized     ",
    "386 or better CPU not found     ",
    "No EMM driver detected          ",
    "Not enough free EMS memory      ",
    "Unable to open file             ",
    "General file reading error      ",
    "Blender map already allocated   ",
    "Not enough free base memory     ",
    "Blender map is not active       ",
    "Cannot create file              ",
    "General file writing error      ",
    "Unknown or bad file format      ",
    "No sounds initialized           ",
    "DMA channel not supported       ",
    "Failed to reset sound card DSP  ",
    "High mixing speed not supported ",
    "Old sound card not supported    ",
    "File format not supported       ",
    "Sound exceed 64k size limit     ",
    "Unknown sound slot              ",
    "Cannot read past end of file    ",
    "Can't open two FLI files at once",
    "Incompatible blender map        ",
    "BLASTER variable not set        ",
    "Sound engine not yet initialized",
    "Datafile not yet opened         ",
    "Unknown packet ID               ",
    "Bad password or corrupted data  ",
    "Can't open two datafiles at once",
    "Operation successful            "
};

int DQBAPI DQBver(void)
{
    return LibVersion;
}

int DQBAPI DQBmapLayer(int layer)
{
    return dqb_get_layer_seg((unsigned)layer);
}

void DQBAPI xDQBerror(char __far *dst)
{
    unsigned char far *d = (unsigned char far *)dst;
    int i;
    char *src = ErrorMsgs[LastError > 29 ? 29 : LastError];

    for (i = 0; i < 32; i++)
        d[i] = (unsigned char)src[i];
}

void DQBAPI DQBsort(int arraySeg, int arrayOff, int numRecords, int recordLen, int indexOff)
{
    unsigned char far *base;
    int cx;

    if (numRecords == 1)
        return;
    if (numRecords <= 0)
        return;
    base = (unsigned char far *)MK_FP((unsigned short)arraySeg, 0);
    for (cx = 0; cx < numRecords - 1; cx++) {
        unsigned char far *si = base + arrayOff + indexOff + cx * recordLen;
        unsigned short bx = si[0] | ((unsigned short)si[1] << 8);
        int inner;

        for (inner = cx + 1; inner < numRecords; inner++) {
            unsigned char far *di = base + arrayOff + indexOff + inner * recordLen;
            unsigned short cand = di[0] | ((unsigned short)di[1] << 8);

            if ((short)bx <= (short)cand)
                continue;
            bx = cand;
            {
                unsigned char far *s = base + arrayOff + cx * recordLen;
                unsigned char far *d = base + arrayOff + inner * recordLen;
                int k;

                for (k = 0; k < recordLen; k++) {
                    unsigned char t = s[k];
                    s[k] = d[k];
                    d[k] = t;
                }
                si = base + arrayOff + indexOff + cx * recordLen;
                di = base + arrayOff + indexOff + inner * recordLen;
            }
        }
    }
}

int DQBAPI DQBangle(int x1, int y1, int x2, int y2)
{
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
    double dx, dy, a;

    if (x1 == x2)
        return (y1 < y2) ? 127 : 0;
    dx = (double)(x2 - x1);
    dy = (double)(y2 - y1);
    a = atan2(dy, dx) / M_PI * 128.0 + 64.0;
    if (x1 < x2)
        a += 128.0;
    return ((int)a) & 0xFF;
}

static void __interrupt __far timer_isr(void);

void DQBAPI DQBsetFrameRate(int fps)
{
    union REGS regs;
    struct SREGS sregs;

    if (!TimerActive) {
        regs.x.ax = 0x3508;
        dqb_int386x(0x21, &regs, &regs, &sregs);
        OldInt8 = ((unsigned long)sregs.es << 16) | regs.x.bx;
        _disable();
        regs.x.ax = 0x2508;
        regs.x.dx = FP_OFF(timer_isr);
        sregs.ds = FP_SEG(timer_isr);
        dqb_int386x(0x21, &regs, &regs, &sregs);
        _enable();
        TimerActive = 1;
    }
    ElapsedTicks = 0;
    if (fps >= 19) {
        unsigned long div = 0x1234DDUL / (unsigned)fps;
        TimerCount = div;
        outp(0x43, 0x34);
        outp(0x40, (unsigned char)div);
        outp(0x40, (unsigned char)(div >> 8));
    } else {
        TimerCount = 0x10000UL;
        outp(0x43, 0x34);
        outp(0x40, 0);
        outp(0x40, 0);
    }
}

static void __interrupt __far timer_isr(void)
{
    TimerFlag = 1;
    ElapsedTicks += TimerCount;
    if (ElapsedTicks >= 0x10000UL) {
        ElapsedTicks -= 0x10000UL;
        _chain_intr((void (__interrupt __far *)())OldInt8);
    }
}

int DQBAPI DQBframeReady(void)
{
    int r = 0;

    if (!TimerActive)
        return 0;
    if (TimerFlag) {
        TimerFlag = 0;
        r = -1;
    }
    return r;
}

int DQBAPI DQBsetBaseLayer(int layer)
{
    union REGS regs;
    struct SREGS sregs;
    unsigned si = (unsigned)layer & 0x7FFFu;
    unsigned short seg;
    unsigned char far *p;
    unsigned i;

    if (si >= 10 || BaseSet[si]) {
        LastError = 7;
        return 0;
    }
    regs.x.ax = 0x4800;
    regs.x.bx = 4000;
    dqb_int386(0x21, &regs, &regs);
    if (regs.x.cflag) {
        LastError = 7;
        return 0;
    }
    seg = regs.x.ax;
    (void)sregs;
    BaseLayer[si] = seg;
    BaseSet[si] = 1;
    p = (unsigned char far *)MK_FP(seg, 0);
    for (i = 0; i < 16000u; i++)
        ((unsigned long far *)p)[i] = 0;
    return seg;
}

void DQBAPI DQBpeek(int dataSeg, int dataOff, long offset, int length)
{
    {
        unsigned long off = (unsigned long)offset;
        EMSmove.len = (unsigned long)(unsigned short)length;
        EMSmove.dstType = 0;
        EMSmove.dstHdl = 0;
        EMSmove.dstOff = (unsigned short)dataOff;
        EMSmove.dstSegPg = (unsigned short)dataSeg;
        EMSmove.srcType = 1;
        EMSmove.srcHdl = EMShdl;
        EMSmove.srcOff = (unsigned short)(off & 0x3FFFUL);
        EMSmove.srcSegPg = (unsigned short)((off >> 14) + DataPage);
        {
            union REGS regs;
            regs.x.ax = 0x5700;
            regs.x.si = FP_OFF(&EMSmove);
            {
                union REGPACK rp;
                rp.w.ax = regs.x.ax;
                rp.w.si = regs.x.si;
                rp.w.ds = FP_SEG(&EMSmove);
                rp.w.flags = 0;
                intr(0x67, &rp);
            }
        }
    }
}

void DQBAPI DQBpoke(int dataSeg, int dataOff, long offset, int length)
{
    {
        unsigned long off = (unsigned long)offset;
        EMSmove.len = (unsigned long)(unsigned short)length;
        EMSmove.srcType = 0;
        EMSmove.srcHdl = 0;
        EMSmove.srcOff = (unsigned short)dataOff;
        EMSmove.srcSegPg = (unsigned short)dataSeg;
        EMSmove.dstType = 1;
        EMSmove.dstHdl = EMShdl;
        EMSmove.dstOff = (unsigned short)(off & 0x3FFFUL);
        EMSmove.dstSegPg = (unsigned short)((off >> 14) + DataPage);
        {
            union REGPACK rp;
            rp.w.ax = 0x5700;
            rp.w.si = FP_OFF(&EMSmove);
            rp.w.ds = FP_SEG(&EMSmove);
            rp.w.flags = 0;
            intr(0x67, &rp);
        }
    }
}

void DQBAPI DQBFPU(void)
{
    /* QB FPU-emulation accelerator; no-op in the C port. */
}

void DQBAPI DQBINT3D(void)
{
    /* Placeholder for INT 3Dh hook; never installed by C port. */
}
