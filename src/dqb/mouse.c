/* mouse.c — MOUSE.ASM port (INT 33h). */
#include "dqb_int.h"
#include <dos.h>
#include <i86.h>

int DQBAPI DQBmouseDetected(void)
{
    return MouseDetected == 1 ? -1 : 0;
}

int DQBAPI DQBmouseX(void)
{
    return (int)(MouseX >> 1);
}

int DQBAPI DQBmouseY(void)
{
    return MouseY;
}

int DQBAPI DQBmouseLB(void)
{
    return (MouseBut & 1) ? -1 : 0;
}

int DQBAPI DQBmouseRB(void)
{
    return (MouseBut & 2) ? -1 : 0;
}

void DQBAPI DQBsetMousePos(int x, int y)
{
    union REGS regs;

    MouseX = (unsigned short)(x << 1);
    MouseY = (unsigned short)y;
    regs.x.ax = 4;
    regs.x.cx = MouseX;
    regs.x.dx = MouseY;
    dqb_int386(0x33, &regs, &regs);
}

void DQBAPI DQBmouseShow(void)
{
    union REGS regs;

    if (MouseOn == 1)
        return;
    regs.x.ax = 1;
    dqb_int386(0x33, &regs, &regs);
    MouseOn = 1;
}

void DQBAPI DQBmouseHide(void)
{
    union REGS regs;

    if (MouseOn == 0)
        return;
    regs.x.ax = 2;
    dqb_int386(0x33, &regs, &regs);
    MouseOn = 0;
}

void DQBAPI DQBsetMouseRange(int x1, int y1, int x2, int y2)
{
    union REGS regs;

    if (MouseOn) {
        regs.x.ax = 2;
        dqb_int386(0x33, &regs, &regs);
    }
    regs.x.ax = 7;
    regs.x.cx = (unsigned short)(x1 << 1);
    regs.x.dx = (unsigned short)(x2 << 1);
    dqb_int386(0x33, &regs, &regs);
    regs.x.ax = 8;
    regs.x.cx = (unsigned short)y1;
    regs.x.dx = (unsigned short)y2;
    dqb_int386(0x33, &regs, &regs);
    if (MouseOn) {
        regs.x.ax = 1;
        dqb_int386(0x33, &regs, &regs);
    }
}

void DQBAPI xDQBsetMouseShape(int hotX, int hotY, char __far *shape)
{
    union REGS regs;
    struct SREGS sregs;

    if (MouseOn) {
        regs.x.ax = 2;
        dqb_int386(0x33, &regs, &regs);
    }
    regs.x.ax = 9;
    regs.x.bx = (unsigned short)(hotX << 1);
    regs.x.cx = (unsigned short)hotY;
    regs.x.dx = FP_OFF(shape);
    sregs.es = FP_SEG(shape);
    dqb_int386x(0x33, &regs, &regs, &sregs);
    if (MouseOn) {
        regs.x.ax = 1;
        dqb_int386(0x33, &regs, &regs);
    }
}

void DQBAPI DQBsetMouseSpeed(int hor, int ver)
{
    union REGS regs;

    regs.x.ax = 0x0F;
    regs.x.cx = (unsigned short)(hor >> 1);
    regs.x.dx = (unsigned short)ver;
    dqb_int386(0x33, &regs, &regs);
}

void DQBAPI DQBresetMouse(void)
{
    union REGS regs;
    struct SREGS sregs;

    if (MouseOn) {
        regs.x.ax = 2;
        dqb_int386(0x33, &regs, &regs);
    }
    regs.x.ax = 7;
    regs.x.cx = 0;
    regs.x.dx = 639;
    dqb_int386(0x33, &regs, &regs);
    regs.x.ax = 8;
    regs.x.cx = 0;
    regs.x.dx = 199;
    dqb_int386(0x33, &regs, &regs);
    regs.x.ax = 9;
    regs.x.bx = 0;
    regs.x.cx = 0;
    regs.x.dx = FP_OFF(MouseShape);
    sregs.es = FP_SEG(MouseShape);
    dqb_int386x(0x33, &regs, &regs, &sregs);
    regs.x.ax = 0x0F;
    regs.x.cx = 8;
    regs.x.dx = 16;
    dqb_int386(0x33, &regs, &regs);
    if (MouseOn) {
        regs.x.ax = 1;
        dqb_int386(0x33, &regs, &regs);
    }
}
