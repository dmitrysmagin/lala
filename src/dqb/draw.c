#include "dqb_int.h"
#include <string.h>

void DQBAPI DQBsetTransPut(void)
{
    PutMode = 0;
}

void DQBAPI DQBsetSolidPut(void)
{
    PutMode = 1;
}

void DQBAPI DQBcopyTransLayer(int srcLayer, int dstLayer)
{
    unsigned short srcSeg, dstSeg;
    unsigned char far *src;
    unsigned char far *dst;
    unsigned long i;

    if (srcLayer == dstLayer)
        return;
    srcSeg = dqb_get_layer_seg((unsigned)srcLayer);
    dstSeg = dqb_get_layer_seg((unsigned)dstLayer);
    src = (unsigned char far *)MK_FP(srcSeg, 0);
    dst = (unsigned char far *)MK_FP(dstSeg, 0);
    /* ASM does word-granular skip; byte loop is equivalent. */
    for (i = 0; i < 64000UL; i++) {
        unsigned char v = src[i];
        if (v)
            dst[i] = v;
    }
}

void DQBAPI DQBcopyHitLayer(int srcLayer, int dstLayer, int col)
{
    unsigned short srcSeg, dstSeg;
    unsigned char far *src;
    unsigned char far *dst;
    unsigned long i;
    unsigned char c = (unsigned char)col;

    if (srcLayer == dstLayer)
        return;
    srcSeg = dqb_get_layer_seg((unsigned)srcLayer);
    dstSeg = dqb_get_layer_seg((unsigned)dstLayer);
    src = (unsigned char far *)MK_FP(srcSeg, 0);
    dst = (unsigned char far *)MK_FP(dstSeg, 0);
    for (i = 0; i < 64000UL; i++)
        dst[i] = src[i] ? c : 0;
}

void DQBAPI DQBpset(int layer, int x, int y, int col)
{
    unsigned short seg;
    unsigned char far *base;

    if (x < (int)ClipX1 || x > (int)ClipX2)
        return;
    if (y < (int)ClipY1 || y > (int)ClipY2)
        return;
    seg = dqb_get_layer_seg((unsigned)layer);
    base = (unsigned char far *)MK_FP(seg, 0);
    base[dqb_layer_offset(x, y)] = (unsigned char)col;
}

int DQBAPI DQBpoint(int layer, int x, int y)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);

    return base[dqb_layer_offset(x, y)];
}

/* Bresenham state kept in statics to mirror ASM .DATA globals. */
static int d_deltax, d_deltay, d_d, d_dinc1, d_dinc2;
static int d_xinc1, d_xinc2, d_yinc1, d_yinc2;

static void bres_setup(int x1, int y1, int x2, int y2)
{
    d_deltax = x2 - x1;
    if (d_deltax < 0)
        d_deltax = -d_deltax;
    d_deltay = y2 - y1;
    if (d_deltay < 0)
        d_deltay = -d_deltay;
    if (d_deltax >= d_deltay) {
        d_d = 2 * d_deltay - d_deltax;
        d_dinc1 = 2 * d_deltay;
        d_dinc2 = 2 * (d_deltay - d_deltax);
        d_xinc1 = 1;
        d_xinc2 = 1;
        d_yinc1 = 0;
        d_yinc2 = 1;
    } else {
        d_d = 2 * d_deltax - d_deltay;
        d_dinc1 = 2 * d_deltax;
        d_dinc2 = 2 * (d_deltax - d_deltay);
        d_xinc1 = 0;
        d_xinc2 = 1;
        d_yinc1 = 1;
        d_yinc2 = 1;
    }
    if (x1 > x2) {
        d_xinc1 = -d_xinc1;
        d_xinc2 = -d_xinc2;
    }
    if (y1 > y2) {
        d_yinc1 = -d_yinc1;
        d_yinc2 = -d_yinc2;
    }
}

void DQBAPI DQBline(int layer, int x1, int y1, int x2, int y2, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int n, i, x, y;
    unsigned char c = (unsigned char)col;

    bres_setup(x1, y1, x2, y2);
    n = (d_deltax >= d_deltay ? d_deltax : d_deltay) + 1;
    x = x1;
    y = y1;
    for (i = 0; i < n; i++) {
        if (x >= (int)ClipX1 && x <= (int)ClipX2 &&
            y >= (int)ClipY1 && y <= (int)ClipY2)
            base[dqb_layer_offset(x, y)] = c;
        if (d_d < 0) {
            d_d += d_dinc1;
            x += d_xinc1;
            y += d_yinc1;
        } else {
            d_d += d_dinc2;
            x += d_xinc2;
            y += d_yinc2;
        }
    }
}

void DQBAPI DQBgline(int layer, int x1, int y1, int x2, int y2, int col1, int col2)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int n, i, x, y;
    long step, acc;

    bres_setup(x1, y1, x2, y2);
    n = (d_deltax >= d_deltay ? d_deltax : d_deltay) + 1;
    step = ((long)(col2 - col1 + 1) << 16) / (n ? n : 1);
    acc = 0;
    x = x1;
    y = y1;
    for (i = 0; i < n; i++) {
        int c = col1 + (int)(acc >> 16);
        if (x >= (int)ClipX1 && x <= (int)ClipX2 &&
            y >= (int)ClipY1 && y <= (int)ClipY2)
            base[dqb_layer_offset(x, y)] = (unsigned char)c;
        acc += step;
        if (d_d < 0) {
            d_d += d_dinc1;
            x += d_xinc1;
            y += d_yinc1;
        } else {
            d_d += d_dinc2;
            x += d_xinc2;
            y += d_yinc2;
        }
    }
}

static void epixel(unsigned char far *base, int x, int y, unsigned char c)
{
    if (x < (int)ClipX1 || x > (int)ClipX2)
        return;
    if (y < (int)ClipY1 || y > (int)ClipY2)
        return;
    base[dqb_layer_offset(x, y)] = c;
}

void DQBAPI DQBellipse(int layer, int x, int y, int rx, int ry, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    unsigned char c = (unsigned char)col;
    int i;

    if (rx == 0) {
        for (i = y - ry; i <= y + ry; i++)
            epixel(base, x, i, c);
        return;
    }
    if (ry == 0) {
        for (i = x - rx; i <= x + rx; i++)
            epixel(base, i, y, c);
        return;
    }
    /* Midpoint ellipse, two-region integer loop. */
    {
        long rx2 = (long)rx * rx;
        long ry2 = (long)ry * ry;
        int px = 0;
        int py = ry;
        long e = ry2 - rx2 * ry + rx2 / 4;

        epixel(base, x + px, y + py, c);
        epixel(base, x - px, y + py, c);
        epixel(base, x + px, y - py, c);
        epixel(base, x - px, y - py, c);
        while (ry2 * px < rx2 * py) {
            px++;
            if (e < 0)
                e += 2 * ry2 * px + ry2;
            else {
                py--;
                e += 2 * ry2 * px - 2 * rx2 * py + ry2;
            }
            epixel(base, x + px, y + py, c);
            epixel(base, x - px, y + py, c);
            epixel(base, x + px, y - py, c);
            epixel(base, x - px, y - py, c);
        }
        e = ry2 * (px + 1) * (px + 1) + rx2 * (py - 1) * (py - 1) - rx2 * ry2;
        while (py > 0) {
            py--;
            if (e > 0)
                e += -2 * rx2 * py + rx2;
            else {
                px++;
                e += 2 * ry2 * px - 2 * rx2 * py + rx2;
            }
            epixel(base, x + px, y + py, c);
            epixel(base, x - px, y + py, c);
            epixel(base, x + px, y - py, c);
            epixel(base, x - px, y - py, c);
        }
    }
}

void DQBAPI DQBbox(int layer, int x1, int y1, int x2, int y2, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int w, h, y, x;
    unsigned char c = (unsigned char)col;

    w = x2 - x1 + 1;
    h = y2 - y1 + 1;
    for (x = 0; x < w; x++) {
        base[dqb_layer_offset(x1 + x, y1)] = c;
        base[dqb_layer_offset(x1 + x, y2)] = c;
    }
    for (y = y1 + 1; y < y2; y++) {
        base[dqb_layer_offset(x1, y)] = c;
        base[dqb_layer_offset(x2, y)] = c;
    }
}

void DQBAPI DQBboxf(int layer, int x1, int y1, int x2, int y2, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int y, x;
    unsigned char c = (unsigned char)col;

    for (y = y1; y <= y2; y++)
        for (x = x1; x <= x2; x++)
            base[dqb_layer_offset(x, y)] = c;
}

/* Flood fill queue mirrors ASM PixData[1279] ring. */
#define PAINT_MAX 1279

void DQBAPI DQBpaint(int layer, int x, int y, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    static int qx[PAINT_MAX];
    static int qy[PAINT_MAX];
    int first = 0, last = 1;
    unsigned char bg;
    unsigned char c = (unsigned char)col;
    int cx, cy;

    if (x < (int)ClipX1 || x > (int)ClipX2 ||
        y < (int)ClipY1 || y > (int)ClipY2)
        return;
    bg = base[dqb_layer_offset(x, y)];
    if (bg == c)
        return;
    qx[0] = x;
    qy[0] = y;
    while (first != last) {
        int sx, ex, yy, xx;

        cx = qx[first];
        cy = qy[first];
        first = (first + 1) % PAINT_MAX;
        /* Scan right from seed. */
        sx = cx;
        while (sx <= (int)ClipX2 &&
            base[dqb_layer_offset(sx, cy)] == bg) {
            base[dqb_layer_offset(sx, cy)] = c;
            sx++;
        }
        sx--;
        /* Scan left from seed-1. */
        ex = cx - 1;
        while (ex >= (int)ClipX1 &&
            base[dqb_layer_offset(ex, cy)] == bg) {
            base[dqb_layer_offset(ex, cy)] = c;
            ex--;
        }
        ex++;
        /* Push up/down neighbours over filled span. */
        for (xx = ex; xx <= sx; xx++) {
            if (cy > (int)ClipY1 &&
                base[dqb_layer_offset(xx, cy - 1)] == bg) {
                qx[last] = xx;
                qy[last] = cy - 1;
                last = (last + 1) % PAINT_MAX;
            }
            if (cy < (int)ClipY2 &&
                base[dqb_layer_offset(xx, cy + 1)] == bg) {
                qx[last] = xx;
                qy[last] = cy + 1;
                last = (last + 1) % PAINT_MAX;
            }
        }
        (void)yy;
    }
}

void DQBAPI DQBscroll(int layer, int dx, int dy)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    long off = (long)dy * 320 + dx;
    unsigned i;

    if (off < 0) {
        unsigned long n = 64000UL + off;
        for (i = 0; i < n; i++)
            base[i] = base[i - off];
    } else if (off > 0) {
        unsigned long n = 64000UL - off;
        unsigned long i2;
        for (i2 = 0; i2 < n; i2++)
            base[63999 - i2] = base[63999 - off - i2];
    }
}

void DQBAPI DQBscrollArea(int layer, int x1, int y1, int x2, int y2, int direction)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int w = x2 - x1 + 1;
    int h = y2 - y1 + 1;
    int x, y;

    if (direction == 0) { /* up */
        for (y = y1; y < y2; y++)
            for (x = x1; x <= x2; x++)
                base[dqb_layer_offset(x, y)] = base[dqb_layer_offset(x, y + 1)];
    } else if (direction == 1) { /* down */
        for (y = y2; y > y1; y--)
            for (x = x1; x <= x2; x++)
                base[dqb_layer_offset(x, y)] = base[dqb_layer_offset(x, y - 1)];
    } else if (direction == 2) { /* left */
        for (y = y1; y <= y2; y++)
            for (x = x1; x < x2; x++)
                base[dqb_layer_offset(x, y)] = base[dqb_layer_offset(x + 1, y)];
    } else { /* right */
        for (y = y1; y <= y2; y++)
            for (x = x2; x > x1; x--)
                base[dqb_layer_offset(x, y)] = base[dqb_layer_offset(x - 1, y)];
    }
    (void)w;
    (void)h;
}

void DQBAPI DQBget(int layer, int x1, int y1, int x2, int y2, void __far *buf)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *src = (unsigned char far *)MK_FP(seg, 0);
    unsigned char far *dst = (unsigned char far *)buf;
    int w = x2 - x1 + 1;
    int h = y2 - y1 + 1;
    int yy;

    dst[0] = (unsigned char)(w * 8);
    dst[1] = 0;
    dst[2] = (unsigned char)h;
    dst[3] = 0;
    dst += 4;
    for (yy = 0; yy < h; yy++) {
        _fmemcpy(dst, src + dqb_layer_offset(x1, y1 + yy), (unsigned)w);
        dst += w;
    }
}

void DQBAPI DQBput(int layer, int x, int y, const void __far *buf)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w, h, yy, xx;
    int curY;

    w = (int)(unsigned char)src[0] / 8;
    h = (int)(unsigned char)src[2];
    src += 4;
    curY = y - 1;

    for (yy = 0; yy < h; yy++) {
        int px = x;
        curY++;
        if (curY < (int)ClipY1)
            continue;
        if (curY > (int)ClipY2)
            break;
        for (xx = 0; xx < w; xx++, px++) {
            unsigned char pix = src[yy * w + xx];
            if (PutMode == 0 && pix == 0)
                continue;
            if (px < (int)ClipX1 || px > (int)ClipX2)
                continue;
            dest[dqb_layer_offset(px, curY)] = pix;
        }
    }
}
