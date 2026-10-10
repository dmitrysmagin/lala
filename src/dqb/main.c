/* main.c — DQBinit, layers, VGA/text mode, wait (P0). */
#include "dqb_int.h"
#include <dos.h>
#include <i86.h>
#include <string.h>

static void reset_font_from_bios(void)
{
    unsigned i;

    for (i = 0; i < 257; i++)
        CharLen[i] = 8;
}

static int cpu_is_386(void)
{
    return 1;
}

int DQBAPI DQBinit(int numLayers, int numSounds, int memSize)
{
    unsigned short needPages;
    unsigned short bx;
    union REGS regs;
    struct SREGS sregs;
    int i;

    if (LibActive)
        return 4;

    memset(BaseSet, 0, sizeof(BaseSet));
    reset_font_from_bios();

    if (!cpu_is_386())
        return 1;

    EMSallocated = 0;
    SoundPage = (unsigned short)(numLayers * 4);
    NumSounds = (unsigned char)numSounds;
    DataPage = (unsigned short)(SoundPage + (unsigned short)(numSounds * 4));

    needPages = (unsigned short)((numLayers + numSounds) * 4);
    if (memSize) {
        needPages = (unsigned short)(needPages + (unsigned short)((memSize >> 4) + 1));
    }

    if (needPages) {
        int ok;

        ok = 0;
        {
            unsigned short seg, off;
            unsigned char far *id;

            off = *(unsigned short far *)MK_FP(0, 0x19C);
            seg = *(unsigned short far *)MK_FP(0, 0x19E);
            id = (unsigned char far *)MK_FP(seg, 0x0A);
            if (id[0] == 'E' && id[1] == 'M' && id[2] == 'M')
                ok = 1;
        }
        if (!ok)
            return 2;

        regs.x.ax = 0x4200;
        dqb_int386(0x67, &regs, &regs);
        if (regs.x.bx < needPages)
            return 3;

        EMSallocated = needPages;
        regs.x.ax = 0x4300;
        regs.x.bx = needPages;
        dqb_int386(0x67, &regs, &regs);
        EMShdl = regs.x.dx;

        regs.x.ax = 0x4100;
        dqb_int386(0x67, &regs, &regs);
        EMSseg = regs.x.bx;

        if (numSounds) {
            for (bx = (unsigned short)(numLayers + numSounds); bx > 0; bx--) {
                dqb_map_ems((unsigned short)((bx - 1) * 4));
                {
                    unsigned char far *p = (unsigned char far *)MK_FP(EMSseg, 0);
                    unsigned j;
                    for (j = 0; j < 16384u; j++)
                        ((unsigned long far *)p)[j] = 0x08080808UL;
                }
            }
        }
        if (numLayers) {
            for (bx = numLayers; bx > 0; bx--) {
                dqb_map_ems((unsigned short)((bx - 1) * 4));
                {
                    unsigned char far *p = (unsigned char far *)MK_FP(EMSseg, 0);
                    unsigned j;
                    for (j = 0; j < 16384u; j++)
                        ((unsigned long far *)p)[j] = 0;
                }
            }
        }
        dqb_map_ems(0);
    }

    /* Mouse detect (optional). */
    regs.x.ax = 0;
    dqb_int386(0x33, &regs, &regs);
    MouseDetected = (regs.x.ax != 0) ? 1 : 0;

    LibActive = 1;
    return 0;
}

void DQBAPI DQBclose(void)
{
    union REGS regs;
    struct SREGS sregs;
    int i;

    if (!LibActive)
        return;

    if (TimerActive) {
        regs.x.ax = 0;
        sregs.es = 0;
        /* Restore INT 8 vector from OldInt8. */
        _disable();
        {
            void __interrupt __far *old8;
            old8 = (void __interrupt __far *)MK_FP(
                (unsigned short)(OldInt8 >> 16), (unsigned short)OldInt8);
            _dos_setvect(8, old8);
        }
        _enable();
        outp(0x43, 0x34);
        outp(0x40, 0);
        outp(0x40, 0);
        TimerActive = 0;
    }

    if (KeyActive) {
        extern void DQBAPI DQBremoveKeyboard(void);
        DQBremoveKeyboard();
    }

    if (SoundActive) {
        extern void DQBAPI DQBremoveSB(void);
        DQBremoveSB();
    }

    if (VolActive) {
        regs.x.ax = 0x4900;
        sregs.es = VolSeg;
        dqb_int386x(0x21, &regs, &regs, &sregs);
        VolActive = 0;
    }

    if (EMSallocated) {
        regs.x.ax = 0x4500;
        regs.x.dx = EMShdl;
        dqb_int386(0x67, &regs, &regs);
        EMSallocated = 0;
    }

    for (i = 0; i < 10; i++) {
        if (BaseSet[i]) {
            regs.x.ax = 0x4900;
            sregs.es = BaseLayer[i];
            dqb_int386x(0x21, &regs, &regs, &sregs);
            BaseSet[i] = 0;
        }
    }

    for (i = 0; i < 10; i++) {
        if (BMapActive[i]) {
            BMapActive[i] = 0;
            regs.x.ax = 0x4900;
            sregs.es = BMapSeg[i];
            dqb_int386x(0x21, &regs, &regs, &sregs);
        }
    }

    if (FLIactive) {
        extern void DQBAPI DQBcloseFLI(void);
        DQBcloseFLI();
    }

    if (PackActive) {
        extern void DQBAPI DQBcloseDataFile(void);
        DQBcloseDataFile();
    }

    if (VGAon) {
        regs.x.ax = 0x0003;
        dqb_int386(0x10, &regs, &regs);
        VGAon = 0;
    }

    LibActive = 0;
}

void DQBAPI DQBcopyLayer(int srcLayer, int dstLayer)
{
    unsigned short srcSeg, dstSeg;
    unsigned char far *src;
    unsigned char far *dst;
    unsigned i;

    if (srcLayer > 0 && dstLayer > 0) {
        union REGS regs;

        srcSeg = EMSseg;
        dstSeg = EMSseg;
        regs.x.dx = EMShdl;

        regs.x.ax = 0x4400;
        regs.x.bx = (unsigned short)((srcLayer - 1) * 4);
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4401;
        regs.x.bx = (unsigned short)((srcLayer - 1) * 4 + 1);
        dqb_int386(0x67, &regs, &regs);

        regs.x.ax = 0x4402;
        regs.x.bx = (unsigned short)((dstLayer - 1) * 4);
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4403;
        regs.x.bx = (unsigned short)((dstLayer - 1) * 4 + 1);
        dqb_int386(0x67, &regs, &regs);

        src = (unsigned char far *)MK_FP(srcSeg, 0);
        dst = (unsigned char far *)MK_FP(dstSeg, 0x8000);
        for (i = 0; i < 8192u; i++)
            ((unsigned long far *)dst)[i] = ((unsigned long far *)src)[i];

        regs.x.ax = 0x4400;
        regs.x.bx = (unsigned short)((srcLayer - 1) * 4 + 2);
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4401;
        regs.x.bx = (unsigned short)((srcLayer - 1) * 4 + 3);
        dqb_int386(0x67, &regs, &regs);

        regs.x.ax = 0x4402;
        regs.x.bx = (unsigned short)((dstLayer - 1) * 4 + 2);
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4403;
        regs.x.bx = (unsigned short)((dstLayer - 1) * 4 + 3);
        dqb_int386(0x67, &regs, &regs);

        for (i = 0; i < 8192u; i++)
            ((unsigned long far *)dst)[i] = ((unsigned long far *)src)[i];

        dqb_map_ems(EMSpage);
        return;
    }

    srcSeg = dqb_get_layer_seg((unsigned)srcLayer);
    dstSeg = dqb_get_layer_seg((unsigned)dstLayer);
    src = (unsigned char far *)MK_FP(srcSeg, 0);
    dst = (unsigned char far *)MK_FP(dstSeg, 0);
    for (i = 0; i < 16000u; i++)
        ((unsigned long far *)dst)[i] = ((unsigned long far *)src)[i];
}

void DQBAPI DQBclearLayer(int layer)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *p = (unsigned char far *)MK_FP(seg, 0);
    unsigned i;

    for (i = 0; i < 16000u; i++)
        ((unsigned long far *)p)[i] = 0;
}

void DQBAPI DQBwait(int times)
{
    int t;
    unsigned char st;

    for (t = 0; t < times; t++) {
        do {
            st = inp(0x3DA);
        } while (st & 8);
        do {
            st = inp(0x3DA);
        } while (!(st & 8));
    }
}

void DQBAPI DQBinitVGA(void)
{
    union REGS regs;

    regs.x.ax = 0x0013;
    dqb_int386(0x10, &regs, &regs);
    VGAon = 1;
}

void DQBAPI DQBinitText(void)
{
    union REGS regs;

    regs.x.ax = 0x0003;
    dqb_int386(0x10, &regs, &regs);
    VGAon = 0;
}
