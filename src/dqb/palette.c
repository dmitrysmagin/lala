#include "dqb_int.h"
#include <conio.h>

void DQBAPI DQBsetCol(int colorIndex, int r, int g, int b)
{
    outp(0x3C8, (unsigned char)colorIndex);
    outp(0x3C9, (unsigned char)r);
    outp(0x3C9, (unsigned char)g);
    outp(0x3C9, (unsigned char)b);
}

void DQBAPI DQBgetCol(int colorIndex, int __near *r, int __near *g, int __near *b)
{
    outp(0x3C7, (unsigned char)colorIndex);
    *r = inp(0x3C9);
    *g = inp(0x3C9);
    *b = inp(0x3C9);
}

static int wrap63(int v)
{
    while (v >= 64)
        v -= 64;
    while (v < 0)
        v += 64;
    return v;
}

int DQBAPI DQBfindCol(int red, int green, int blue)
{
    int color = 0;
    int best = 255;
    int i;

    red = wrap63(red);
    green = wrap63(green);
    blue = wrap63(blue);
    outp(0x3C7, 0);
    for (i = 0; i < 256; i++) {
        int pr = inp(0x3C9);
        int pg = inp(0x3C9);
        int pb = inp(0x3C9);
        int dr = pr - red;
        int dg = pg - green;
        int db = pb - blue;
        int dist;

        if (dr < 0)
            dr = -dr;
        if (dg < 0)
            dg = -dg;
        if (db < 0)
            db = -db;
        dist = dr + dg + db;
        if (dist == 0)
            return i;
        if (dist < best) {
            best = dist;
            color = i;
        }
    }
    return color;
}

int DQBAPI xDQBfindPalCol(char __far *pal, int red, int green, int blue)
{
    unsigned char __far *p = (unsigned char __far *)pal;
    int color = 0;
    int best = 255;
    int i;

    red = wrap63(red);
    green = wrap63(green);
    blue = wrap63(blue);
    for (i = 0; i < 256; i++) {
        int pr = p[i * 3];
        int pg = p[i * 3 + 1];
        int pb = p[i * 3 + 2];
        int dr = pr - red;
        int dg = pg - green;
        int db = pb - blue;
        int dist;

        if (dr < 0)
            dr = -dr;
        if (dg < 0)
            dg = -dg;
        if (db < 0)
            db = -db;
        dist = dr + dg + db;
        if (dist == 0)
            return i;
        if (dist < best) {
            best = dist;
            color = i;
        }
    }
    return color;
}

void DQBAPI xDQBsetPal(char __far *pal)
{
    int i;
    unsigned char __far *p = (unsigned char __far *)pal;

    outp(0x3C8, 0);
    for (i = 0; i < 768; i++)
        outp(0x3C9, p[i]);
}

void DQBAPI xDQBgetPal(char __far *pal)
{
    int i;
    unsigned char __far *p = (unsigned char __far *)pal;

    outp(0x3C7, 0);
    for (i = 0; i < 768; i++)
        p[i] = inp(0x3C9);
}

static void wait_vsync(void)
{
    while (inp(0x3DA) & 8)
        ;
    while (!(inp(0x3DA) & 8))
        ;
}

static void fade_step_pal(unsigned char __far *target)
{
    int cx;

    for (cx = 0; cx < 256; cx++) {
        unsigned char r, g, b;
        unsigned char tr, tg, tb;

        outp(0x3C7, (unsigned char)cx);
        r = inp(0x3C9);
        g = inp(0x3C9);
        b = inp(0x3C9);
        outp(0x3C8, (unsigned char)cx);
        tr = target[cx * 3];
        tg = target[cx * 3 + 1];
        tb = target[cx * 3 + 2];
        if (r > tr)
            outp(0x3C9, r - 1);
        else if (r < tr)
            outp(0x3C9, r + 1);
        else
            outp(0x3C9, r);
        if (g > tg)
            outp(0x3C9, g - 1);
        else if (g < tg)
            outp(0x3C9, g + 1);
        else
            outp(0x3C9, g);
        if (b > tb)
            outp(0x3C9, b - 1);
        else if (b < tb)
            outp(0x3C9, b + 1);
        else
            outp(0x3C9, b);
    }
}

void DQBAPI xDQBfadeIn(char __far *pal)
{
    int done;

    do {
        int si = 0;
        int cx;

        wait_vsync();
        done = 1;
        for (cx = 0; cx < 256; cx++) {
            unsigned char r, g, b;
            unsigned char __far *t = (unsigned char __far *)pal + cx * 3;

            outp(0x3C7, (unsigned char)cx);
            r = inp(0x3C9);
            g = inp(0x3C9);
            b = inp(0x3C9);
            outp(0x3C8, (unsigned char)cx);
            if (r > t[0]) {
                outp(0x3C9, r - 1);
                si = 1;
            } else if (r < t[0]) {
                outp(0x3C9, r + 1);
                si = 1;
            } else
                outp(0x3C9, r);
            if (g > t[1]) {
                outp(0x3C9, g - 1);
                si = 1;
            } else if (g < t[1]) {
                outp(0x3C9, g + 1);
                si = 1;
            } else
                outp(0x3C9, g);
            if (b > t[2]) {
                outp(0x3C9, b - 1);
                si = 1;
            } else if (b < t[2]) {
                outp(0x3C9, b + 1);
                si = 1;
            } else
                outp(0x3C9, b);
        }
        if (si)
            done = 0;
    } while (!done);
}

void DQBAPI xDQBfadeStepIn(char __far *pal)
{
    fade_step_pal((unsigned char __far *)pal);
}

static void fade_step_to(int red, int green, int blue)
{
    int cx;

    for (cx = 0; cx < 256; cx++) {
        unsigned char r, g, b;

        outp(0x3C7, (unsigned char)cx);
        r = inp(0x3C9);
        g = inp(0x3C9);
        b = inp(0x3C9);
        outp(0x3C8, (unsigned char)cx);
        if (r > (unsigned char)red)
            outp(0x3C9, r - 1);
        else if (r < (unsigned char)red)
            outp(0x3C9, r + 1);
        else
            outp(0x3C9, r);
        if (g > (unsigned char)green)
            outp(0x3C9, g - 1);
        else if (g < (unsigned char)green)
            outp(0x3C9, g + 1);
        else
            outp(0x3C9, g);
        if (b > (unsigned char)blue)
            outp(0x3C9, b - 1);
        else if (b < (unsigned char)blue)
            outp(0x3C9, b + 1);
        else
            outp(0x3C9, b);
    }
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

void DQBAPI DQBfadeStepTo(int red, int green, int blue)
{
    fade_step_to(red, green, blue);
}

void DQBAPI DQBpalOff(void)
{
    int i;

    outp(0x3C8, 0);
    for (i = 0; i < 768; i++)
        outp(0x3C9, 0);
}

static void pal_read(int idx, unsigned char *r, unsigned char *g, unsigned char *b)
{
    outp(0x3C7, (unsigned char)idx);
    *r = inp(0x3C9);
    *g = inp(0x3C9);
    *b = inp(0x3C9);
}

static void pal_write(int idx, unsigned char r, unsigned char g, unsigned char b)
{
    outp(0x3C8, (unsigned char)idx);
    outp(0x3C9, r);
    outp(0x3C9, g);
    outp(0x3C9, b);
}

void DQBAPI DQBpalRotate(int firstCol, int lastCol, int rotateDir)
{
    unsigned char r, g, b;
    int c;

    if (rotateDir == 0) {
        if (firstCol == lastCol)
            return;
        pal_read(lastCol, &r, &g, &b);
        for (c = lastCol; c > firstCol; c--) {
            unsigned char r2, g2, b2;

            pal_read(c - 1, &r2, &g2, &b2);
            pal_write(c, r2, g2, b2);
        }
        pal_write(firstCol, r, g, b);
    } else {
        pal_read(firstCol, &r, &g, &b);
        for (c = firstCol + 1; c <= lastCol; c++) {
            unsigned char r2, g2, b2;

            pal_read(c, &r2, &g2, &b2);
            pal_write(c - 1, r2, g2, b2);
        }
        pal_write(lastCol, r, g, b);
    }
}
