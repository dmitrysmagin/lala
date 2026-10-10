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
