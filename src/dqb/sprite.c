/* sprite.c — SPRITE.ASM port: size/clip/scale/rotate/fast/x/m/h/t/p/over/collide. */
#include "dqb_int.h"
#include <string.h>

int DQBAPI DQBsize(int x1, int y1, int x2, int y2)
{
    int w = x2 - x1 + 1;
    int h = y2 - y1 + 1;
    return (int)((unsigned short)(w * h) + 4);
}

void DQBAPI DQBsetClipBox(int x1, int y1, int x2, int y2)
{
    if (x2 <= x1) {
        ClipX1 = (unsigned short)x2;
        ClipX2 = (unsigned short)x1;
    } else {
        ClipX1 = (unsigned short)x1;
        ClipX2 = (unsigned short)x2;
    }
    if (y2 <= y1) {
        ClipY1 = (unsigned short)y2;
        ClipY2 = (unsigned short)y1;
    } else {
        ClipY1 = (unsigned short)y1;
        ClipY2 = (unsigned short)y2;
    }
}

void DQBAPI DQBsPut(int layer, int x, int y, const void __far *buf, int newW, int newH)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int origW = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int origH = (int)(src[2] | ((unsigned)src[3] << 8));
    int xi = (origW << 7) / (newW ? newW : 1);
    int yi = (origH << 7) / (newH ? newH : 1);
    int yadd = 0;
    int cy;

    src += 4;
    for (cy = 0; cy < newH; cy++) {
        int dy = y + cy;
        int srcRow;
        int cx;
        int dxacc = 0;

        srcRow = (yadd >> 7) * origW;
        if (dy >= (int)ClipY1 && dy <= (int)ClipY2) {
            unsigned off = dqb_layer_offset(0, dy);
            for (cx = 0; cx < newW; cx++) {
                int dxx = x + cx;
                int scol = dxacc >> 7;
                unsigned char pix = src[srcRow + scol];
                if (dxx >= (int)ClipX1 && dxx <= (int)ClipX2) {
                    if (PutMode == 0) {
                        if (pix)
                            dest[off + dxx] = pix;
                    } else
                        dest[off + dxx] = pix;
                }
                dxacc += xi;
            }
        }
        yadd += yi;
    }
}

void DQBAPI DQBrPut(int layer, int x, int y, const void __far *buf, int angle, int zoom)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w, h, hw, hh;
    long cosF, sinF;
    long eax, esi;
    int cy;

    {
        int c = SinTable[(angle + 64) & 0xFF];
        int s = SinTable[angle & 0xFF];
        int z = zoom ? zoom : 100;
        cosF = (long)c * 100 * 65536L / z;
        sinF = (long)s * 100 * 65536L / z;
    }
    w = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    h = (int)(src[2] | ((unsigned)src[3] << 8));
    src += 4;
    hw = w / 2;
    hh = h / 2;
    /* Start offsets so rotation is about sprite centre. */
    esi = (long)256 * hh - (long)hw * cosF - (long)hh * sinF;
    eax = (long)256 * hw + (long)hw * sinF - (long)hh * cosF;
    /* ASM uses 24.8/16.16 mix with >>8 for u,v; emulate with >>8. */
    esi = esi;
    for (cy = 0; cy < h; cy++) {
        int dy = y + cy;
        long ru = eax;
        long rv = esi;
        int cx;

        if (dy >= (int)ClipY1 && dy <= (int)ClipY2) {
            unsigned off = dqb_layer_offset(0, dy);
            for (cx = 0; cx < w; cx++) {
                int dxx = x + cx;
                int u = (int)(ru >> 8);
                int v = (int)(rv >> 8);
                if (dxx >= (int)ClipX1 && dxx <= (int)ClipX2 &&
                    v >= 0 && v < h && u >= 0 && u < w) {
                    unsigned char pix = src[v * w + u];
                    if (PutMode != 0 || pix)
                        dest[off + dxx] = pix;
                }
                ru += sinF;
                rv += cosF;
            }
        } else {
            /* Still advance (ASM advances regardless). */
        }
        eax -= cosF;
        esi += sinF;
    }
}

void DQBAPI DQBfPut(int layer, int x, int y, const void __far *buf)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int h = (int)(src[2] | ((unsigned)src[3] << 8));
    int yy;

    src += 4;
    for (yy = 0; yy < h; yy++) {
        _fmemcpy(dest + dqb_layer_offset(x, y + yy), src + yy * w, (unsigned)w);
    }
}

void DQBAPI DQBxPut(int srcLayer, int x1, int y1, int x2, int y2, int dstLayer, int x, int y)
{
    unsigned short sseg = dqb_get_layer_seg((unsigned)srcLayer);
    unsigned short dseg = dqb_get_layer_seg((unsigned)dstLayer);
    unsigned char far *src = (unsigned char far *)MK_FP(sseg, 0);
    unsigned char far *dst = (unsigned char far *)MK_FP(dseg, 0);
    int w = x2 - x1 + 1;
    int h = y2 - y1 + 2;
    int yy;

    if (srcLayer == dstLayer)
        return;
    for (yy = 0; yy < h - 1; yy++) {
        int sy = y1 + yy;
        int dy = y + yy;
        int xx;

        if (dy < (int)ClipY1 || dy > (int)ClipY2)
            continue;
        for (xx = 0; xx < w; xx++) {
            int sx = x1 + xx;
            int dxx = x + xx;
            unsigned char pix;

            if (dxx < (int)ClipX1 || dxx > (int)ClipX2)
                continue;
            pix = src[dqb_layer_offset(sx, sy)];
            if (PutMode == 0 && pix == 0)
                continue;
            dst[dqb_layer_offset(dxx, dy)] = pix;
        }
    }
    EMSpage = 0xFFFF;
}

void DQBAPI DQBmPut(int layer, int x, int y, const void __far *buf, int flip)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int h = (int)(src[2] | ((unsigned)src[3] << 8));
    int yy;

    src += 4;
    for (yy = 0; yy < h; yy++) {
        int sy = yy;
        int dy = (flip & 2) ? (y + h - 1 - yy) : (y + yy);
        int xx;

        if (dy < (int)ClipY1 || dy > (int)ClipY2)
            continue;
        for (xx = 0; xx < w; xx++) {
            int sx = (flip & 1) ? (w - 1 - xx) : xx;
            int dxx = x + xx;
            unsigned char pix = src[sy * w + sx];

            if (dxx < (int)ClipX1 || dxx > (int)ClipX2)
                continue;
            if (PutMode == 0 && pix == 0)
                continue;
            dest[dqb_layer_offset(dxx, dy)] = pix;
        }
    }
}

void DQBAPI DQBhPut(int layer, int x, int y, const void __far *buf, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int h = (int)(src[2] | ((unsigned)src[3] << 8));
    int yy;
    unsigned char c = (unsigned char)col;

    src += 4;
    for (yy = 0; yy < h; yy++) {
        int dy = y + yy;
        int xx;

        if (dy < (int)ClipY1 || dy > (int)ClipY2)
            continue;
        for (xx = 0; xx < w; xx++) {
            int dxx = x + xx;
            if (dxx < (int)ClipX1 || dxx > (int)ClipX2)
                continue;
            if (src[yy * w + xx] == 0)
                continue;
            dest[dqb_layer_offset(dxx, dy)] = c;
        }
    }
}

void DQBAPI DQBtPut(int layer, int x, int y, const void __far *buf, int bitMode)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int h = (int)(src[2] | ((unsigned)src[3] << 8));
    int yy;
    unsigned char mode = (unsigned char)bitMode;

    src += 4;
    for (yy = 0; yy < h; yy++) {
        int dy = y + yy;
        int xx;

        if (dy < (int)ClipY1 || dy > (int)ClipY2)
            continue;
        for (xx = 0; xx < w; xx++) {
            int dxx = x + xx;
            unsigned char pix = src[yy * w + xx];
            unsigned off;

            if (dxx < (int)ClipX1 || dxx > (int)ClipX2)
                continue;
            if (PutMode == 0 && pix == 0)
                continue;
            off = dqb_layer_offset(dxx, dy);
            if (mode == 1)
                dest[off] &= pix;
            else if (mode == 2)
                dest[off] |= pix;
            else
                dest[off] ^= pix;
        }
    }
}

void DQBAPI DQBpPut(int layer, int x, int y, const void __far *buf, int pattern)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int w = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int h = (int)(src[2] | ((unsigned)src[3] << 8));
    int yy;
    unsigned char pat = (unsigned char)(pattern ^ 0xFF);

    src += 4;
    for (yy = 0; yy < h; yy++) {
        int dy = y + yy;
        int xx;
        unsigned char cursor = 1;

        pat ^= 0xFF;
        if (dy < (int)ClipY1 || dy > (int)ClipY2)
            continue;
        for (xx = 0; xx < w; xx++) {
            int dxx = x + xx;
            unsigned char pix = src[yy * w + xx];
            unsigned char bit = cursor;

            cursor <<= 1;
            if (!cursor)
                cursor = 1;
            if (!(bit & pat))
                continue;
            if (dxx < (int)ClipX1 || dxx > (int)ClipX2)
                continue;
            if (PutMode == 0 && pix == 0)
                continue;
            dest[dqb_layer_offset(dxx, dy)] = pix;
        }
    }
}

void DQBAPI DQBputOver(int backSeg, int backOff, int x, int y,
    const void __far *buf)
{
    unsigned char far *back = (unsigned char far *)MK_FP((unsigned short)backSeg, 0)
        + (unsigned)backOff;
    const unsigned char far *src = (const unsigned char far *)buf;
    int sw = (int)(src[0] | ((unsigned)src[1] << 8)) >> 3;
    int sh = (int)(src[2] | ((unsigned)src[3] << 8));
    int bw = (int)(back[0] | ((unsigned)back[1] << 8)) >> 3;
    int bh = (int)(back[2] | ((unsigned)back[3] << 8));
    int yy;

    src += 4;
    back += 4;
    for (yy = 0; yy < sh; yy++) {
        int by = y + yy;
        int xx;

        if (by < 0 || by >= bh)
            continue;
        for (xx = 0; xx < sw; xx++) {
            int bx = x + xx;
            unsigned char pix = src[yy * sw + xx];

            if (bx < 0 || bx >= bw)
                continue;
            if (pix == 0)
                continue;
            back[by * bw + bx] = pix;
        }
    }
}

void DQBAPI DQBsetCollideMethod(int method)
{
    ColMethod = (unsigned char)method;
}

int DQBAPI DQBcollide(int x1, int y1, int seg1, int off1,
    int x2, int y2, int seg2, int off2)
{
    const unsigned char far *s1 = (const unsigned char far *)MK_FP((unsigned short)seg1, 0)
        + (unsigned)off1;
    const unsigned char far *s2 = (const unsigned char far *)MK_FP((unsigned short)seg2, 0)
        + (unsigned)off2;
    int w1 = (int)(s1[0] | ((unsigned)s1[1] << 8)) >> 3;
    int h1 = (int)(s1[2] | ((unsigned)s1[3] << 8));
    int w2 = (int)(s2[0] | ((unsigned)s2[1] << 8)) >> 3;
    int h2 = (int)(s2[2] | ((unsigned)s2[3] << 8));

    if (x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)
        return 0;
    if (ColMethod == 0)
        return -1;
    {
        int ox = (x1 > x2) ? x1 : x2;
        int oy = (y1 > y2) ? y1 : y2;
        int ex = (x1 + w1 < x2 + w2) ? x1 + w1 : x2 + w2;
        int ey = (y1 + h1 < y2 + h2) ? y1 + h1 : y2 + h2;
        int yy, xx;

        for (yy = oy; yy < ey; yy++)
            for (xx = ox; xx < ex; xx++) {
                unsigned char p1 = s1[4 + (yy - y1) * w1 + (xx - x1)];
                unsigned char p2 = s2[4 + (yy - y2) * w2 + (xx - x2)];
                if (p1 && p2)
                    return -1;
            }
    }
    return 0;
}

int DQBAPI DQBcollideOnLayer(int layer, int x, int y, int spriteSeg, int spriteOff)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *sp = (const unsigned char far *)MK_FP((unsigned short)spriteSeg, 0)
        + (unsigned)spriteOff;
    int w = (int)(sp[0] | ((unsigned)sp[1] << 8)) >> 3;
    int h = (int)(sp[2] | ((unsigned)sp[3] << 8));
    int yy, xx;

    sp += 4;
    for (yy = 0; yy < h; yy++) {
        int dy = y + yy;
        if (dy < (int)ClipY1 || dy > (int)ClipY2)
            continue;
        for (xx = 0; xx < w; xx++) {
            int dxx = x + xx;
            unsigned char pix = sp[yy * w + xx];
            unsigned char bg;

            if (pix == 0)
                continue;
            if (dxx < (int)ClipX1 || dxx > (int)ClipX2)
                continue;
            bg = base[dqb_layer_offset(dxx, dy)];
            if (bg)
                return bg;
        }
    }
    return 0;
}
