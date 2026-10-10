#include "dqb_int.h"
#include <conio.h>

void DQBAPI xDQBsetPal(char __far *pal)
{
    int i;
    unsigned char __far *p = (unsigned char __far *)pal;

    outp(0x3C8, 0);
    for (i = 0; i < 768; i++)
        outp(0x3C9, p[i]);
}

static void wait_vsync(void)
{
    while (inp(0x3DA) & 8)
        ;
    while (!(inp(0x3DA) & 8))
        ;
}

void DQBAPI DQBfadeTo(int red, int green, int blue)
{
    int done;

    do {
        int si = 0;
        int cx;

        wait_vsync();
        done = 1;
        for (cx = 0; cx < 256; cx++) {
            unsigned char r, g, b;

            outp(0x3C7, (unsigned char)cx);
            r = inp(0x3C9);
            g = inp(0x3C9);
            b = inp(0x3C9);
            outp(0x3C8, (unsigned char)cx);
            if (r > (unsigned char)red) {
                outp(0x3C9, r - 1);
                si = 1;
            } else if (r < (unsigned char)red) {
                outp(0x3C9, r + 1);
                si = 1;
            } else
                outp(0x3C9, r);
            if (g > (unsigned char)green) {
                outp(0x3C9, g - 1);
                si = 1;
            } else if (g < (unsigned char)green) {
                outp(0x3C9, g + 1);
                si = 1;
            } else
                outp(0x3C9, g);
            if (b > (unsigned char)blue) {
                outp(0x3C9, b - 1);
                si = 1;
            } else if (b < (unsigned char)blue) {
                outp(0x3C9, b + 1);
                si = 1;
            } else
                outp(0x3C9, b);
        }
        if (si)
            done = 0;
    } while (!done);
}

void DQBAPI DQBpalOff(void)
{
    int i;

    outp(0x3C8, 0);
    for (i = 0; i < 768; i++)
        outp(0x3C9, 0);
}
