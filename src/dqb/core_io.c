/* core_io.c — EMS map, layer segment, INT 24h, single-byte DOS read (ASM ABI). */
#include "dqb_int.h"
#include <dos.h>
#include <i86.h>

static void __interrupt __far CriticalISR(void);

unsigned short dqb_get_layer_seg(unsigned layer)
{
    unsigned short bx;

    if ((int)layer <= 0) {
        if (layer == 0)
            return 0xA000;
        bx = (unsigned short)(layer & 0x7FFF);
        if (bx >= 10 || !BaseSet[bx])
            return 0xA000;
        return BaseLayer[bx];
    }

    bx = (unsigned short)((layer - 1) * 4);
    if (bx != EMSpage) {
        union REGS regs;

        EMSpage = bx;
        regs.x.ax = 0x4400;
        regs.x.bx = bx;
        regs.x.dx = EMShdl;
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4401;
        regs.x.bx = (unsigned short)(bx + 1);
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4402;
        regs.x.bx = (unsigned short)(bx + 2);
        dqb_int386(0x67, &regs, &regs);
        regs.x.ax = 0x4403;
        regs.x.bx = (unsigned short)(bx + 3);
        dqb_int386(0x67, &regs, &regs);
    }
    return EMSseg;
}

void dqb_map_ems(unsigned page)
{
    unsigned char al;
    unsigned short bx;
    union REGS regs;

    EMSpage = page;
    bx = page;
    regs.x.dx = EMShdl;
    for (al = 0; al < 4; al++) {
        regs.x.ax = 0x4400 + al;
        regs.x.bx = bx;
        dqb_int386(0x67, &regs, &regs);
        bx++;
    }
}

void dqb_hook_int24(void)
{
    union REGS regs;
    struct SREGS sregs;

    regs.x.ax = 0x3524;
    dqb_int386x(0x21, &regs, &regs, &sregs);
    OldInt24seg = sregs.es;
    OldInt24off = regs.x.bx;
    regs.x.ax = 0x2524;
    regs.x.dx = FP_OFF(CriticalISR);
    sregs.ds = FP_SEG(CriticalISR);
    dqb_int386x(0x21, &regs, &regs, &sregs);
}

void dqb_unhook_int24(void)
{
    union REGS regs;
    struct SREGS sregs;

    regs.x.ax = 0x2524;
    regs.x.dx = OldInt24off;
    sregs.ds = OldInt24seg;
    dqb_int386x(0x21, &regs, &regs, &sregs);
}

static void __interrupt __far CriticalISR(void)
{
    /* DOS critical error: fail the call */
}

/* ASM sound/image call with file handle already in BX. */
#pragma aux ReadBuffer "_ReadBuffer" modify exact [ax cx dx]
int __far ReadBuffer(void)
{
    __asm {
        push ds
        mov dx, offset Buffer
        mov ax, seg Buffer
        mov ds, ax
        mov cx, 1
        mov ah, 3Fh
        int 21h
        pop ds
    }
    return 0;
}

#pragma aux MapEMS "_MapEMS" parm caller [dx] modify exact [ax bx dx]
void __far MapEMS(unsigned short page)
{
    dqb_map_ems(page);
}

/* ASM passes layer in BX, expects segment in CX. */
#pragma aux GetLayerSeg "_GetLayerSeg" parm [bx] value [cx] modify exact [ax dx]
unsigned short GetLayerSeg(unsigned short layer)
{
    return dqb_get_layer_seg(layer);
}

#pragma aux HookInt24 "_HookInt24"
void __far HookInt24(void)
{
    dqb_hook_int24();
}

#pragma aux UnhookInt24 "_UnhookInt24"
void __far UnhookInt24(void)
{
    dqb_unhook_int24();
}
