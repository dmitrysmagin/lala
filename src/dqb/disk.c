/* disk.c — DISK.ASM port: dir/drive/path/numDrives/setDrive/chDir. */
#include "dqb_int.h"
#include <dos.h>
#include <i86.h>
#include <string.h>

static unsigned char DiskDTA[318];
static unsigned char WinFind;
static unsigned short FFhdl;

void DQBAPI xDQBdir(char __far *mask, int attrib, char __far *file)
{
    union REGS regs;
    struct SREGS sregs;

    dqb_hook_int24();
    if (mask[0] != 0) {
        /* Try Win LFN findfirst. */
        regs.x.ax = 0x714E;
        regs.x.cx = (unsigned short)attrib;
        regs.x.si = FP_OFF(mask);
        sregs.ds = FP_SEG(mask);
        regs.x.dx = FP_OFF(DiskDTA);
        sregs.es = FP_SEG(DiskDTA);
        dqb_int386x(0x21, &regs, &regs, &sregs);
        if (!regs.x.cflag) {
            unsigned char far *src;
            unsigned char far *dst = (unsigned char far *)file;
            int i;

            FFhdl = regs.x.ax;
            src = (unsigned char far *)MK_FP(FP_SEG(DiskDTA), FP_OFF(DiskDTA) + 0x2C);
            for (i = 0; i < 260; i++)
                dst[i] = src[i];
            WinFind = 1;
            dqb_unhook_int24();
            return;
        }
        if (regs.x.ax != 0x7100) {
            ((unsigned char far *)file)[0] = 0;
            dqb_unhook_int24();
            return;
        }
    } else if (WinFind) {
        regs.x.ax = 0x714F;
        regs.x.bx = FFhdl;
        regs.x.si = 0;
        regs.x.dx = FP_OFF(DiskDTA);
        sregs.es = FP_SEG(DiskDTA);
        dqb_int386x(0x21, &regs, &regs, &sregs);
        if (!regs.x.cflag) {
            unsigned char far *src;
            unsigned char far *dst = (unsigned char far *)file;
            int i;

            src = (unsigned char far *)MK_FP(FP_SEG(DiskDTA), FP_OFF(DiskDTA) + 0x2C);
            for (i = 0; i < 260; i++)
                dst[i] = src[i];
            dqb_unhook_int24();
            return;
        }
        if (regs.x.ax == 0x7100)
            goto dosfind;
        regs.x.ax = 0x71A1;
        regs.x.bx = FFhdl;
        dqb_int386(0x21, &regs, &regs);
        ((unsigned char far *)file)[0] = 0;
        dqb_unhook_int24();
        return;
    }
dosfind:
    WinFind = 0;
    regs.x.ax = 0x1A00;
    regs.x.dx = FP_OFF(DiskDTA);
    sregs.ds = FP_SEG(DiskDTA);
    dqb_int386x(0x21, &regs, &regs, &sregs);
    if (mask[0] != 0) {
        regs.x.ax = 0x4E00;
        regs.x.cx = (unsigned short)attrib;
        regs.x.dx = FP_OFF(mask);
        sregs.ds = FP_SEG(mask);
        dqb_int386x(0x21, &regs, &regs, &sregs);
    } else {
        regs.x.ax = 0x4F00;
        dqb_int386(0x21, &regs, &regs);
    }
    if (regs.x.cflag) {
        ((unsigned char far *)file)[0] = 0;
        dqb_unhook_int24();
        return;
    }
    {
        unsigned char far *dta = (unsigned char far *)MK_FP(
            FP_SEG(DiskDTA), FP_OFF(DiskDTA));
        unsigned char far *dst = (unsigned char far *)file;
        int i;

        if (!(dta[21] & (unsigned char)attrib)) {
            dst[0] = 0;
            dqb_unhook_int24();
            return;
        }
        for (i = 0; i < 13; i++)
            dst[i] = dta[30 + i];
    }
    dqb_unhook_int24();
}

int DQBAPI xDQBdrive(void)
{
    union REGS regs;

    regs.x.ax = 0x1900;
    dqb_int386(0x21, &regs, &regs);
    return (regs.x.ax & 0xFF) + 65;
}

void DQBAPI xDQBpath(char __far *path)
{
    union REGS regs;
    struct SREGS sregs;

    regs.x.ax = 0x1900;
    dqb_int386(0x21, &regs, &regs);
    regs.x.dx = (unsigned short)((regs.x.ax & 0xFF) + 1);
    regs.x.ax = 0x7147;
    regs.x.si = FP_OFF(path);
    sregs.ds = FP_SEG(path);
    dqb_int386x(0x21, &regs, &regs, &sregs);
}

int DQBAPI DQBnumDrives(void)
{
    union REGS regs;
    int total, cx = 0;

    regs.x.ax = 0x1900;
    dqb_int386(0x21, &regs, &regs);
    {
        unsigned char cur = (unsigned char)regs.x.ax;
        regs.x.ax = 0x0E00;
        regs.x.dx = cur;
        dqb_int386(0x21, &regs, &regs);
        total = regs.x.ax & 0xFF;
    }
    for (cx = 0; cx < total; cx++) {
        regs.x.ax = 0x440E;
        regs.x.bx = (unsigned short)(cx + 1);
        dqb_int386(0x21, &regs, &regs);
        if (regs.x.cflag)
            break;
    }
    return cx;
}

void DQBAPI xDQBsetDrive(int driveCode)
{
    union REGS regs;

    regs.x.ax = 0x0E00;
    regs.x.dx = (unsigned short)driveCode;
    dqb_int386(0x21, &regs, &regs);
}

int DQBAPI xDQBchDir(char __far *dir)
{
    union REGS regs;
    struct SREGS sregs;

    regs.x.ax = 0x713B;
    regs.x.dx = FP_OFF(dir);
    sregs.ds = FP_SEG(dir);
    dqb_int386x(0x21, &regs, &regs, &sregs);
    return regs.x.cflag ? -1 : 0;
}
