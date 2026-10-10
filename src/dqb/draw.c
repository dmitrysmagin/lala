#include "dqb_int.h"
#include <string.h>

void DQBAPI DQBsetTransPut(void)
{
    PutMode = 0;
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
