/* threed.c — THREED.ASM port: flat/gouraud/textured triangles. */
#include "dqb_int.h"

static short TStartX[200], TEndX[200];
static short TStartA[200], TEndA[200];
static short TStartB[200], TEndB[200];

static void tri_sort_y(int *x1, int *y1, int *a1, int *b1,
    int *x2, int *y2, int *a2, int *b2,
    int *x3, int *y3, int *a3, int *b3)
{
    int t;
#define SWAP(a,b) { t=(a); (a)=(b); (b)=t; }
    if (*y1 > *y2) { SWAP(*y1,*y2); SWAP(*x1,*x2); SWAP(*a1,*a2); SWAP(*b1,*b2); }
    if (*y1 > *y3) { SWAP(*y1,*y3); SWAP(*x1,*x3); SWAP(*a1,*a3); SWAP(*b1,*b3); }
    if (*y2 > *y3) { SWAP(*y2,*y3); SWAP(*x2,*x3); SWAP(*a2,*a3); SWAP(*b2,*b3); }
#undef SWAP
}

static void edge_x(int x1, int y1, int x2, int y2)
{
    int y, dy = y2 - y1;

    if (dy == 0) {
        if (y1 >= (int)ClipY1 && y1 <= (int)ClipY2 && y1 >= 0 && y1 < 200) {
            if (TStartX[y1] == (short)0x8000)
                TStartX[y1] = (short)x1;
        }
        return;
    }
    {
        long slope = ((long)(x2 - x1) << 16) / dy;
        long cur = (long)x1 << 16;
        for (y = y1; y <= y2; y++, cur += slope) {
            int v = (int)(cur >> 16);
            if (y < (int)ClipY1 || y > (int)ClipY2 || y < 0 || y >= 200)
                continue;
            TStartX[y] = (short)v;
        }
    }
}

static void edge_xa(int x1, int y1, int a1, int x2, int y2, int a2)
{
    int y, dy = y2 - y1;

    if (dy == 0) {
        if (y1 >= 0 && y1 < 200) {
            TStartA[y1] = (short)a1;
        }
        return;
    }
    {
        long sx = ((long)(x2 - x1) << 16) / dy;
        long sa = ((long)(a2 - a1) << 16) / dy;
        long cx = (long)x1 << 16;
        long ca = (long)a1 << 16;
        for (y = y1; y <= y2; y++, cx += sx, ca += sa) {
            if (y < 0 || y >= 200)
                continue;
            TStartA[y] = (short)(ca >> 16);
            if (y >= (int)ClipY1 && y <= (int)ClipY2)
                TStartX[y] = (short)(cx >> 16);
        }
    }
}

static void edge_xab(int x1, int y1, int a1, int b1, int x2, int y2, int a2, int b2)
{
    int y, dy = y2 - y1;

    if (dy == 0) {
        if (y1 >= 0 && y1 < 200) {
            TStartA[y1] = (short)a1;
            TStartB[y1] = (short)b1;
        }
        return;
    }
    {
        long sx = ((long)(x2 - x1) << 16) / dy;
        long sa = ((long)(a2 - a1) << 16) / dy;
        long sb = ((long)(b2 - b1) << 16) / dy;
        long cx = (long)x1 << 16;
        long ca = (long)a1 << 16;
        long cb = (long)b1 << 16;
        for (y = y1; y <= y2; y++, cx += sx, ca += sa, cb += sb) {
            if (y < 0 || y >= 200)
                continue;
            TStartA[y] = (short)(ca >> 16);
            TStartB[y] = (short)(cb >> 16);
            if (y >= (int)ClipY1 && y <= (int)ClipY2)
                TStartX[y] = (short)(cx >> 16);
        }
    }
}

static void edge_end_x(int x1, int y1, int x2, int y2)
{
    int y, dy = y2 - y1;

    if (dy == 0) {
        if (y1 >= (int)ClipY1 && y1 <= (int)ClipY2 && y1 >= 0 && y1 < 200) {
            TEndX[y1] = (short)x1;
            if (TStartX[y1] > x1) {
                short t = TStartX[y1];
                TStartX[y1] = (short)x1;
                TEndX[y1] = t;
            }
        }
        return;
    }
    {
        long slope = ((long)(x2 - x1) << 16) / dy;
        long cur = (long)x1 << 16;
        for (y = y1; y <= y2; y++, cur += slope) {
            int v = (int)(cur >> 16);
            if (y < (int)ClipY1 || y > (int)ClipY2 || y < 0 || y >= 200)
                continue;
            TEndX[y] = (short)v;
            if (TStartX[y] > v) {
                short t = TStartX[y];
                TStartX[y] = (short)v;
                TEndX[y] = t;
                {
                    short ta = TStartA[y];
                    TStartA[y] = TEndA[y];
                    TEndA[y] = ta;
                    ta = TStartB[y];
                    TStartB[y] = TEndB[y];
                    TEndB[y] = ta;
                }
            }
        }
    }
}

static void tri_setup(int y1, int y3, int *firstY, int *lastY, int *skip)
{
    int i;

    for (i = 0; i < 200; i++) {
        TStartX[i] = (short)0x8000;
        TEndX[i] = 0;
        TStartA[i] = TEndA[i] = 0;
        TStartB[i] = TEndB[i] = 0;
    }
    *firstY = ClipY1 > (unsigned)y1 ? ClipY1 : y1;
    *lastY = ClipY2 < (unsigned)y3 ? ClipY2 : y3;
    *skip = (y1 > (int)ClipY2);
}

void DQBAPI DQBtri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int col)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int a1 = 0, b1 = 0, a2 = 0, b2 = 0, a3 = 0, b3 = 0;
    int firstY, lastY, skip, y;
    unsigned char c = (unsigned char)col;

    tri_sort_y(&x1, &y1, &a1, &b1, &x2, &y2, &a2, &b2, &x3, &y3, &a3, &b3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_x(x1, y1, x2, y2);
    edge_x(x2, y2, x3, y3);
    edge_end_x(x1, y1, x3, y3);
    for (y = firstY; y <= lastY; y++) {
        int sx, ex, x;
        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        for (x = sx; x <= ex; x++)
            base[dqb_layer_offset(x, y)] = c;
    }
}

void DQBAPI DQBbtri(int layer, int x1, int y1, int x2, int y2, int x3, int y3, int col, int bmap)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int bi = bmap - 1;
    unsigned char far *map;
    int a1 = 0, b1 = 0, a2 = 0, b2 = 0, a3 = 0, b3 = 0;
    int firstY, lastY, skip, y;
    unsigned char c = (unsigned char)col;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    tri_sort_y(&x1, &y1, &a1, &b1, &x2, &y2, &a2, &b2, &x3, &y3, &a3, &b3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_x(x1, y1, x2, y2);
    edge_x(x2, y2, x3, y3);
    edge_end_x(x1, y1, x3, y3);
    for (y = firstY; y <= lastY; y++) {
        int sx, ex, x;
        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        for (x = sx; x <= ex; x++) {
            unsigned off = dqb_layer_offset(x, y);
            if (c < BMapFirst[bi] || c > BMapLast[bi])
                base[off] = c;
            else {
                unsigned char bg = base[off];
                base[off] = map[(c - BMapFirst[bi]) * 256u + bg];
            }
        }
    }
}

void DQBAPI DQBgtri(int layer, int x1, int y1, int c1, int x2, int y2, int c2, int x3, int y3, int c3)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int b1 = 0, b2 = 0, b3 = 0;
    int firstY, lastY, skip, y;

    tri_sort_y(&x1, &y1, &c1, &b1, &x2, &y2, &c2, &b2, &x3, &y3, &c3, &b3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_xa(x1, y1, c1, x2, y2, c2);
    {
        int i;
        for (i = 0; i < 200; i++)
            TEndA[i] = TStartA[i];
    }
    edge_xa(x2, y2, c2, x3, y3, c3);
    edge_xa(x1, y1, c1, x3, y3, c3);
    /* Merge: reuse End arrays for second walk is simplified; do full fill. */
    for (y = firstY; y <= lastY; y++) {
        int sx, ex;
        long dc, cc;
        int span, x;

        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        /* Recompute color span from stored ends (approx). */
        span = TEndX[y] - TStartX[y] + 1;
        if (span <= 0)
            span = 1;
        dc = ((long)(TEndA[y] - TStartA[y]) << 16) / span;
        cc = (long)TStartA[y] << 16;
        cc += dc * (sx - TStartX[y]);
        for (x = sx; x <= ex; x++, cc += dc)
            base[dqb_layer_offset(x, y)] = (unsigned char)(cc >> 16);
    }
}

void DQBAPI DQBbgtri(int layer, int x1, int y1, int c1, int x2, int y2, int c2, int x3, int y3, int c3, int bmap)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int bi = bmap - 1;
    unsigned char far *map;
    int b1 = 0, b2 = 0, b3 = 0;
    int firstY, lastY, skip, y;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    tri_sort_y(&x1, &y1, &c1, &b1, &x2, &y2, &c2, &b2, &x3, &y3, &c3, &b3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_xa(x1, y1, c1, x2, y2, c2);
    edge_xa(x2, y2, c2, x3, y3, c3);
    edge_end_x(x1, y1, x3, y3);
    for (y = firstY; y <= lastY; y++) {
        int sx, ex, span, x;
        long dc, cc;

        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        span = TEndX[y] - TStartX[y] + 1;
        if (span <= 0)
            span = 1;
        dc = ((long)(TEndA[y] - TStartA[y]) << 16) / span;
        cc = (long)TStartA[y] << 16;
        cc += dc * (sx - TStartX[y]);
        for (x = sx; x <= ex; x++, cc += dc) {
            unsigned char fg = (unsigned char)(cc >> 16);
            unsigned off = dqb_layer_offset(x, y);
            if (fg < BMapFirst[bi] || fg > BMapLast[bi])
                base[off] = fg;
            else {
                unsigned char bg = base[off];
                base[off] = map[(fg - BMapFirst[bi]) * 256u + bg];
            }
        }
    }
}

void DQBAPI DQBttri(int layer, int x1, int y1, int x2, int y2, int x3, int y3,
    int u1, int v1, int u2, int v2, int u3, int v3, int texSeg, int texOff)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    unsigned char far *tex = (unsigned char far *)MK_FP((unsigned short)texSeg, 0)
        + (unsigned)texOff;
    int firstY, lastY, skip, y;

    tri_sort_y(&x1, &y1, &u1, &v1, &x2, &y2, &u2, &v2, &x3, &y3, &u3, &v3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_xab(x1, y1, u1, v1, x2, y2, u2, v2);
    {
        int i;
        for (i = 0; i < 200; i++) {
            TEndA[i] = TStartA[i];
            TEndB[i] = TStartB[i];
        }
    }
    edge_xab(x2, y2, u2, v2, x3, y3, u3, v3);
    edge_xab(x1, y1, u1, v1, x3, y3, u3, v3);
    edge_end_x(x1, y1, x3, y3);
    for (y = firstY; y <= lastY; y++) {
        int sx, ex, span, x;
        long du, dv, u, v;

        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        span = TEndX[y] - TStartX[y] + 1;
        if (span <= 0)
            span = 1;
        du = ((long)(TEndA[y] - TStartA[y]) << 16) / span;
        dv = ((long)(TEndB[y] - TStartB[y]) << 16) / span;
        u = ((long)TStartA[y] << 16) + du * (sx - TStartX[y]);
        v = ((long)TStartB[y] << 16) + dv * (sx - TStartX[y]);
        for (x = sx; x <= ex; x++, u += du, v += dv) {
            int uu = (int)(u >> 16) & TextureFix;
            int vv = (int)(v >> 16) & TextureFix;
            unsigned char t = tex[4 + (unsigned)((vv << TextureLen) | uu)];
            if (t == 0)
                continue;
            base[dqb_layer_offset(x, y)] = t;
        }
    }
}

void DQBAPI DQBbttri(int layer, int x1, int y1, int x2, int y2, int x3, int y3,
    int u1, int v1, int u2, int v2, int u3, int v3, int texSeg, int texOff, int bmap)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    unsigned char far *tex = (unsigned char far *)MK_FP((unsigned short)texSeg, 0)
        + (unsigned)texOff;
    int bi = bmap - 1;
    unsigned char far *map;
    int firstY, lastY, skip, y;

    if (bi < 0 || bi >= 10 || !BMapActive[bi])
        return;
    map = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
    tri_sort_y(&x1, &y1, &u1, &v1, &x2, &y2, &u2, &v2, &x3, &y3, &u3, &v3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_xab(x1, y1, u1, v1, x2, y2, u2, v2);
    edge_xab(x2, y2, u2, v2, x3, y3, u3, v3);
    edge_xab(x1, y1, u1, v1, x3, y3, u3, v3);
    edge_end_x(x1, y1, x3, y3);
    for (y = firstY; y <= lastY; y++) {
        int sx, ex, span, x;
        long du, dv, u, v;

        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        span = TEndX[y] - TStartX[y] + 1;
        if (span <= 0)
            span = 1;
        du = ((long)(TEndA[y] - TStartA[y]) << 16) / span;
        dv = ((long)(TEndB[y] - TStartB[y]) << 16) / span;
        u = ((long)TStartA[y] << 16) + du * (sx - TStartX[y]);
        v = ((long)TStartB[y] << 16) + dv * (sx - TStartX[y]);
        for (x = sx; x <= ex; x++, u += du, v += dv) {
            int uu = (int)(u >> 16) & TextureFix;
            int vv = (int)(v >> 16) & TextureFix;
            unsigned char t = tex[4 + (unsigned)((vv << TextureLen) | uu)];
            unsigned off = dqb_layer_offset(x, y);
            unsigned char out;

            if (t < BMapFirst[bi] || t > BMapLast[bi])
                out = t;
            else {
                unsigned char bg = base[off];
                out = map[(t - BMapFirst[bi]) * 256u + bg];
                if (out == 0)
                    continue;
            }
            base[off] = out;
        }
    }
}

void DQBAPI DQBfttri(int layer, int x1, int y1, int x2, int y2, int x3, int y3,
    int u1, int v1, int u2, int v2, int u3, int v3, int texSeg, int texOff)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    unsigned char far *tex = (unsigned char far *)MK_FP((unsigned short)texSeg, 0)
        + (unsigned)texOff;
    int firstY, lastY, skip, y;

    tri_sort_y(&x1, &y1, &u1, &v1, &x2, &y2, &u2, &v2, &x3, &y3, &u3, &v3);
    tri_setup(y1, y3, &firstY, &lastY, &skip);
    if (skip)
        return;
    edge_xab(x1, y1, u1, v1, x2, y2, u2, v2);
    edge_xab(x2, y2, u2, v2, x3, y3, u3, v3);
    edge_xab(x1, y1, u1, v1, x3, y3, u3, v3);
    edge_end_x(x1, y1, x3, y3);
    for (y = firstY; y <= lastY; y++) {
        int sx, ex, span, x;
        long du, dv, u, v;

        if (y < 0 || y >= 200)
            continue;
        if (TStartX[y] == (short)0x8000)
            continue;
        sx = TStartX[y] < (int)ClipX1 ? ClipX1 : TStartX[y];
        ex = TEndX[y] > (int)ClipX2 ? ClipX2 : TEndX[y];
        span = TEndX[y] - TStartX[y] + 1;
        if (span <= 0)
            span = 1;
        du = ((long)(TEndA[y] - TStartA[y]) << 16) / span;
        dv = ((long)(TEndB[y] - TStartB[y]) << 16) / span;
        u = ((long)TStartA[y] << 16) + du * (sx - TStartX[y]);
        v = ((long)TStartB[y] << 16) + dv * (sx - TStartX[y]);
        for (x = sx; x <= ex; x++, u += du, v += dv) {
            long fu = u & 0xFFFF;
            long fv = v & 0xFFFF;
            int uu = (int)(u >> 16);
            int vv = (int)(v >> 16);
            int dx, dy;
            unsigned char t00, t10, t01, t11;
            long out;

            if (uu == 0)
                uu = 1;
            if (vv == 0)
                vv = 1;
            uu &= TextureFix;
            vv &= TextureFix;
            dx = (int)(fu >> 8);
            dy = (int)(fv >> 8);
            t00 = tex[4 + (unsigned)((vv << TextureLen) | uu)];
            t10 = tex[4 + (unsigned)((vv << TextureLen) | ((uu + 1) & TextureFix))];
            t01 = tex[4 + (unsigned)(((vv + 1) & TextureFix) << TextureLen | uu)];
            t11 = tex[4 + (unsigned)(((vv + 1) & TextureFix) << TextureLen | ((uu + 1) & TextureFix))];
            out = (long)t00 * (256 - dx) * (256 - dy) +
                (long)t10 * dx * (256 - dy) +
                (long)t01 * (256 - dx) * dy +
                (long)t11 * dx * dy;
            out >>= 16;
            if (out == 0)
                continue;
            base[dqb_layer_offset(x, y)] = (unsigned char)out;
        }
    }
}

void DQBAPI DQBsetTextureSize(int size)
{
    int ax = 128;
    int cx = 8;

    while (cx != 0) {
        if (size & ax)
            break;
        ax >>= 1;
        cx--;
    }
    TextureFix = (unsigned short)(ax - 1);
    TextureLen = (unsigned char)(cx - 1);
}
