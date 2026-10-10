#include <i86.h>
#include <dos.h>

void dqb_int386(int num, union REGS *in, union REGS *out)
{
    union REGPACK rp;

    rp.w.ax = in->x.ax;
    rp.w.bx = in->x.bx;
    rp.w.cx = in->x.cx;
    rp.w.dx = in->x.dx;
    rp.w.si = in->x.si;
    rp.w.di = in->x.di;
    rp.w.flags = 0;
    intr((unsigned char)num, &rp);
    out->x.ax = rp.w.ax;
    out->x.bx = rp.w.bx;
    out->x.cx = rp.w.cx;
    out->x.dx = rp.w.dx;
    out->x.cflag = rp.w.flags & 1;
}

void dqb_int386x(int num, union REGS *in, union REGS *out, struct SREGS *sregs)
{
    union REGPACK rp;

    rp.w.ax = in->x.ax;
    rp.w.bx = in->x.bx;
    rp.w.cx = in->x.cx;
    rp.w.dx = in->x.dx;
    rp.w.si = in->x.si;
    rp.w.di = in->x.di;
    rp.w.ds = sregs->ds;
    rp.w.es = sregs->es;
    rp.w.flags = 0;
    intr((unsigned char)num, &rp);
    out->x.ax = rp.w.ax;
    out->x.bx = rp.w.bx;
    out->x.cx = rp.w.cx;
    out->x.dx = rp.w.dx;
    out->x.cflag = rp.w.flags & 1;
    sregs->ds = rp.w.ds;
    sregs->es = rp.w.es;
}
