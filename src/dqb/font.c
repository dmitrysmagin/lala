#include "dqb_int.h"
#include <stdio.h>
#include <string.h>

int DQBAPI xDQBloadFont(char __far *file)
{
    FILE *f;

    dqb_hook_int24();
    f = fopen(file, "rb");
    if (!f) {
        dqb_unhook_int24();
        return 1;
    }
    if (fread(FontBuffer, 1, 2048, f) != 2048 ||
        fread(CharLen, 1, 257, f) != 257) {
        fclose(f);
        dqb_unhook_int24();
        return 2;
    }
    fclose(f);
    dqb_unhook_int24();
    return 0;
}

void DQBAPI DQBsetFontTexture(char __far *text)
{
    unsigned char far *src = (unsigned char far *)text + 4;
    int i;

    for (i = 0; i < 64; i++)
        FontTexture[i] = src[i];
}

void DQBAPI DQBsetTextSpacing(int spacing)
{
    CharSpacing = (unsigned short)spacing;
}

int DQBAPI xDQBlen(char __far *text)
{
    unsigned char far *s = (unsigned char far *)text;
    int cx = 0;

    if (!s[0])
        return 0;
    if (TextMode & 4)
        cx += CharLen[256] >> 2;
    while (*s) {
        unsigned char ch = *s++;
        cx += CharLen[ch];
        if (TextMode & 2)
            cx++;
        cx += CharSpacing;
    }
    return cx;
}

void DQBAPI DQBsetBIOSfont(void)
{
    unsigned short off = *(unsigned short far *)MK_FP(0, 0x7C);
    unsigned short seg = *(unsigned short far *)MK_FP(0, 0x7E);
    unsigned char far *src = (unsigned char far *)MK_FP(seg, off - 1024);
    int i;

    _fmemcpy(FontBuffer, src, 2048);
    for (i = 0; i < 257; i++)
        CharLen[i] = 8;
    TextMode = 0;
}

void DQBAPI xDQBsetFont(char __far *font)
{
    unsigned char far *src = (unsigned char far *)font;

    _fmemcpy(FontBuffer, src, 2048);
    _fmemcpy(CharLen, src + 2048, 257);
}

void DQBAPI DQBsetTextBackCol(int col)
{
    TextBackCol = (unsigned char)col;
}

void DQBAPI DQBsetTextBMap(int bmap)
{
    TextBMap = (unsigned short)bmap;
}

void DQBAPI DQBsetTextStyle(int style)
{
    TextMode = (unsigned char)style;
}

static void plot_glyph_pixel(unsigned char far *dest, int px, int py,
    int col, unsigned char far *bmap)
{
    unsigned char cur;

    (void)cur;
    if (px < (int)ClipX1 || px > (int)ClipX2)
        return;
    if (py < (int)ClipY1 || py > (int)ClipY2)
        return;
    if ((TextMode & 32)) {
        unsigned idx = (unsigned)TextureY * 8 + TextureX;
        unsigned char tex = FontTexture[idx & 63];
        if (TextMode & 16) {
            if (!bmap) {
                dest[dqb_layer_offset(px, py)] = tex;
                if ((TextMode & 2) && px + 1 <= (int)ClipX2)
                    dest[dqb_layer_offset(px + 1, py)] = tex;
                return;
            }
            unsigned char bg = dest[dqb_layer_offset(px, py)];
            unsigned bidx = (unsigned)((tex - BMapOff) * 256u + bg);
            unsigned char out = bmap[bidx];
            dest[dqb_layer_offset(px, py)] = out;
            if (TextMode & 2) {
                if (px + 1 <= (int)ClipX2) {
                    bg = dest[dqb_layer_offset(px + 1, py)];
                    bidx = (unsigned)((tex - BMapOff) * 256u + bg);
                    dest[dqb_layer_offset(px + 1, py)] = bmap[bidx];
                }
            }
        } else {
            dest[dqb_layer_offset(px, py)] = tex;
            if ((TextMode & 2) && px + 1 <= (int)ClipX2)
                dest[dqb_layer_offset(px + 1, py)] = tex;
        }
        return;
    }
    if (TextMode & 16) {
        if (!bmap) {
            dest[dqb_layer_offset(px, py)] = (unsigned char)col;
            if ((TextMode & 2) && px + 1 <= (int)ClipX2)
                dest[dqb_layer_offset(px + 1, py)] = (unsigned char)col;
            return;
        }
        {
        unsigned char bg = dest[dqb_layer_offset(px, py)];
        unsigned bidx = (unsigned)(((unsigned char)col - BMapOff) * 256u + bg);
        dest[dqb_layer_offset(px, py)] = bmap[bidx];
        if (TextMode & 2) {
            if (px + 1 <= (int)ClipX2) {
                bg = dest[dqb_layer_offset(px + 1, py)];
                bidx = (unsigned)(((unsigned char)col - BMapOff) * 256u + bg);
                dest[dqb_layer_offset(px + 1, py)] = bmap[bidx];
            }
        }
        }
        return;
    }
    dest[dqb_layer_offset(px, py)] = (unsigned char)col;
    if (TextMode & 2) {
        if (px + 1 <= (int)ClipX2)
            dest[dqb_layer_offset(px + 1, py)] = (unsigned char)col;
    }
}

void DQBAPI xDQBprint(int layer, char __far *text, int x, int y, int col, int style)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    unsigned char far *bmap = 0;
    unsigned char far *t = (unsigned char far *)text;
    int bx, dx, cx;
    int i;
    unsigned char savedMode;
    unsigned char height;

    {
        int bi = (int)TextBMap - 1;
        if (bi >= 0 && bi < 10 && BMapActive[bi]) {
            BMapOff = BMapFirst[bi];
            bmap = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
        } else {
            BMapOff = 0;
            /* ASM does not guard; keep null but only deref when blended. */
        }
    }
    savedMode = TextMode;
    if (style != 0xFF)
        TextMode = (unsigned char)style;

    /* Measure width. */
    cx = 0;
    for (i = 0; t[i]; i++) {
        unsigned char ch = t[i];
        cx += CharLen[ch];
        if (TextMode & 2)
            cx++;
        if (t[i + 1])
            cx += CharSpacing;
    }
    bx = x;
    if (bx == 0x8000) {
        int span = (int)ClipX2 - (int)ClipX1 + 1;
        bx = (span - cx) / 2 + ClipX1;
    }
    if (TextMode & 4)
        cx += CharLen[256] >> 2;
    height = CharLen[256];
    dx = y;

    /* Solid background pass. */
    if (TextMode & 1) {
        int row, span = cx;
        int by = y;
        for (row = 0; row < height; row++, by++) {
            int px = bx;
            unsigned off;
            int k;
            if (by < (int)ClipY1 || by > (int)ClipY2)
                continue;
            off = dqb_layer_offset(0, by);
            for (k = 0; k < span; k++, px++) {
                if (px < (int)ClipX1 || px > (int)ClipX2)
                    continue;
                if (TextMode & 16) {
                    unsigned char bg = dest[off + px];
                    unsigned bidx = (unsigned)((TextBackCol - BMapOff) * 256u + bg);
                    dest[off + px] = bmap ? bmap[bidx] : TextBackCol;
                } else
                    dest[off + px] = TextBackCol;
            }
        }
    }
    /* Underline pass. */
    if (TextMode & 8) {
        int px = bx;
        int k;
        if (dx + height >= (int)ClipY1 && dx + height <= (int)ClipY2) {
            unsigned off = dqb_layer_offset(0, dx + height);
            for (k = 0; k < cx; k++, px++) {
                if (px < (int)ClipX1 || px > (int)ClipX2)
                    continue;
                if (TextMode & 16) {
                    unsigned char bg = dest[off + px];
                    unsigned bidx = (unsigned)(((unsigned char)col - BMapOff) * 256u + bg);
                    dest[off + px] = bmap ? bmap[bidx] : (unsigned char)col;
                } else
                    dest[off + px] = (unsigned char)col;
            }
        }
    }
    if (TextMode & 4)
        bx += CharLen[256] >> 2;
    TextureX = 0;
    TextureY = 0;
    while (*t) {
        unsigned char ch = *t;
        unsigned char far *glyph = FontBuffer + ((unsigned)ch << 3);
        int row;

        for (row = 0; row < height; row++) {
            int py = y + row;
            unsigned char bits;
            int bit;

            if (py > (int)ClipY2)
                break;
            if (py < (int)ClipY1) {
                TextureY++;
                TextureX = 0;
                /* Italic fix still applies per skipped line. */
                if (TextMode & 4) {
                    int left = height - row - 1;
                    if ((left & 3) == 3)
                        bx--;
                }
                glyph++;
                continue;
            }
            bits = glyph[row];
            {
                int px = bx;
                TextureX = 0;
                for (bit = 7; bit >= 0; bit--) {
                    if (bits & (1 << bit))
                        plot_glyph_pixel(dest, px, py, col, bmap);
                    TextureX++;
                    px++;
                }
            }
            TextureY++;
            TextureX = 0;
            if (TextMode & 4) {
                int left = height - row - 1;
                if ((left & 3) == 3)
                    bx--;
            }
        }
        bx += CharLen[ch] + CharSpacing;
        if (TextMode & 2)
            bx++;
        if (TextMode & 4)
            bx += 2;
        t++;
        y = dx;
        TextureX = 0;
        TextureY = 0;
        /* Note: italic bx decrement during rows persists (ASM behavior). */
    }
    TextMode = savedMode;
}

void DQBprint(int layer, const char __far *text, int x, int y, int col)
{
    xDQBprint(layer, (char __far *)text, x, y, col, 0);
}
