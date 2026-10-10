#include "dqb_int.h"
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

void DQBAPI DQBfilterBox(int layer, int x1, int y1, int x2, int y2, int col, int bmap)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    int bi = bmap - 1;
    unsigned char far *map;
    int w, h, yy, xx;

    (void)col;
    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    w = x2 - x1 + 1;
    h = y2 - y1 + 1;
    for (yy = 0; yy < h; yy++) {
        for (xx = 0; xx < w; xx++) {
            unsigned char fg = (unsigned char)col;
            unsigned char bg;
            unsigned idx;

            if (fg < BMapFirst[bi] || fg > BMapLast[bi])
                continue;
            bg = dest[dqb_layer_offset(x1 + xx, y1 + yy)];
            idx = (unsigned)((fg - BMapFirst[bi]) * 256u + bg);
            dest[dqb_layer_offset(x1 + xx, y1 + yy)] = map[idx];
        }
    }
}

void DQBAPI DQBbPut(int layer, int x, int y, const void __far *buf, int bmap)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    const unsigned char far *src = (const unsigned char far *)buf;
    int bi = bmap - 1;
    unsigned char far *map;
    int w, h, yy, xx;
    int curY;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
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
            unsigned char bg;
            unsigned idx;

            if (PutMode == 0 && pix == 0)
                continue;
            if (px < (int)ClipX1 || px > (int)ClipX2)
                continue;
            if (pix < BMapFirst[bi] || pix > BMapLast[bi]) {
                dest[dqb_layer_offset(px, curY)] = pix;
                continue;
            }
            bg = dest[dqb_layer_offset(px, curY)];
            idx = (unsigned)((pix - BMapFirst[bi]) * 256u + bg);
            dest[dqb_layer_offset(px, curY)] = map[idx];
        }
    }
}

void DQBAPI DQBcopyBlendLayer(int srcLayer, int dstLayer, int bmap)
{
    unsigned short srcSeg, dstSeg;
    unsigned char far *src;
    unsigned char far *dst;
    unsigned char far *map;
    int bi = bmap - 1;
    unsigned long i;

    if (srcLayer == dstLayer)
        return;
    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    srcSeg = dqb_get_layer_seg((unsigned)srcLayer);
    dstSeg = dqb_get_layer_seg((unsigned)dstLayer);
    src = (unsigned char far *)MK_FP(srcSeg, 0);
    dst = (unsigned char far *)MK_FP(dstSeg, 0);
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    for (i = 0; i < 64000UL; i++) {
        unsigned char fg = src[i];
        unsigned idx;

        if (fg == 0)
            continue;
        if (fg < BMapFirst[bi] || fg > BMapLast[bi]) {
            dst[i] = fg;
            continue;
        }
        idx = (unsigned)((fg - BMapFirst[bi]) * 256u + dst[i]);
        dst[i] = map[idx];
    }
}

int DQBAPI DQBcreateBMap(int bmap, int firstCol, int lastCol)
{
    union REGS regs;
    struct SREGS sregs;
    int bi = bmap - 1;
    unsigned char fc, lc;
    int rows, cols, r, c;
    unsigned char far *es;

    if (bi < 0 || bi >= 10 || BMapActive[bi])
        return 2;

    fc = (unsigned char)firstCol;
    lc = (unsigned char)lastCol;
    cols = (int)lc - (int)fc + 1;
    rows = 256;

    regs.x.ax = 0x4800;
    regs.x.bx = (unsigned short)(cols * rows / 16 + 1);
    dqb_int386(0x21, &regs, &regs);
    if (regs.x.cflag)
        return 1;

    BMapSeg[bi] = regs.x.ax;
    BMapActive[bi] = 1;
    BMapFirst[bi] = fc;
    BMapLast[bi] = lc;
    es = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    for (r = 0; r < rows; r++) {
        for (c = 0; c < cols; c++)
            es[r * cols + c] = (unsigned char)(fc + c);
    }
    (void)sregs;
    return 0;
}

void DQBAPI DQBsetBMap(int bmap, int foreCol, int backCol, int newCol)
{
    int bi = bmap - 1;
    unsigned char far *map;
    unsigned idx;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    if (foreCol < BMapFirst[bi] || foreCol > BMapLast[bi])
        return;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    idx = (unsigned)((foreCol - BMapFirst[bi]) * 256 + (backCol & 0xFF));
    map[idx] = (unsigned char)newCol;
}

int DQBAPI DQBgetBMap(int bmap, int foreCol, int backCol)
{
    int bi = bmap - 1;
    unsigned char far *map;
    unsigned idx;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return 0xFFFF;
    if (foreCol < BMapFirst[bi] || foreCol > BMapLast[bi])
        return 0xFFFF;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    idx = (unsigned)((foreCol - BMapFirst[bi]) * 256 + (backCol & 0xFF));
    return map[idx];
}

int DQBAPI xDQBloadBMap(int bmap, char __far *file)
{
    int bi = bmap - 1;
    unsigned char hdr[6];
    unsigned char far *map;
    FILE *f;
    long id;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return 1;

    f = fopen(file, "rb");
    if (!f)
        return 2;
    if (fread(hdr, 1, 6, f) != 6) {
        fclose(f);
        return 5;
    }
    id = (long)hdr[0] | ((long)hdr[1] << 8) | ((long)hdr[2] << 16) | ((long)hdr[3] << 24);
    if (id != 0x70614D42L) { /* 'BMap' little-endian */
        fclose(f);
        return 3;
    }
    if (hdr[5] - hdr[4] != BMapLast[bi] - BMapFirst[bi]) {
        fclose(f);
        return 4;
    }
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    {
        unsigned char chunk[256];
        size_t need = (size_t)(256 * (BMapLast[bi] - BMapFirst[bi] + 1));
        while (need) {
            size_t n = need > sizeof(chunk) ? sizeof(chunk) : need;
            size_t got = fread(chunk, 1, n, f);
            if (got == 0) {
                fclose(f);
                return 5;
            }
            _fmemcpy(map, chunk, got);
            map += got;
            need -= got;
        }
    }
    fclose(f);
    return 0;
}

int DQBAPI xDQBsaveBMap(int bmap, char __far *file)
{
    int bi = bmap - 1;
    unsigned char hdr[6];
    unsigned char far *map;
    FILE *f;
    size_t need;

    if (bi < 0 || bi >= 10 || !BMapActive[bi]) {
        LastError = 8;
        return 1;
    }
    dqb_hook_int24();
    f = fopen(file, "wb");
    if (!f) {
        dqb_unhook_int24();
        LastError = 9;
        return 2;
    }
    hdr[0] = 'B';
    hdr[1] = 'M';
    hdr[2] = 'a';
    hdr[3] = 'p';
    hdr[4] = BMapFirst[bi];
    hdr[5] = BMapLast[bi];
    if (fwrite(hdr, 1, 6, f) != 6) {
        fclose(f);
        dqb_unhook_int24();
        LastError = 10;
        return 3;
    }
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    need = (size_t)(256 * (BMapLast[bi] - BMapFirst[bi] + 1));
    while (need) {
        unsigned char chunk[256];
        size_t n = need > sizeof(chunk) ? sizeof(chunk) : need;

        _fmemcpy(chunk, map, n);
        if (fwrite(chunk, 1, n, f) != n) {
            fclose(f);
            dqb_unhook_int24();
            LastError = 10;
            return 3;
        }
        map += n;
        need -= n;
    }
    fclose(f);
    dqb_unhook_int24();
    return 0;
}

void DQBAPI DQBremoveBMap(int bmap)
{
    union REGS regs;
    struct SREGS sregs;
    int bi = bmap - 1;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    BMapActive[bi] = 0;
    regs.x.ax = 0x4900;
    sregs.es = BMapSeg[bi];
    dqb_int386x(0x21, &regs, &regs, &sregs);
}
