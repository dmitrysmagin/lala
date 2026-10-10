#include "dqb_int.h"
#include <stdio.h>

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

void DQBAPI xDQBprint(int layer, char __far *text, int x, int y, int col, int style)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *dest = (unsigned char far *)MK_FP(seg, 0);
    int cx = x;
    int i;
    unsigned char height = CharLen[256];

    (void)style;
    for (i = 0; text[i]; i++) {
        unsigned char ch = (unsigned char)text[i];
        unsigned char far *glyph = FontBuffer + ((unsigned)ch << 3);
        unsigned char cw = CharLen[ch];
        int row, bit;

        for (row = 0; row < (int)height; row++) {
            unsigned char bits = glyph[row];
            int px = cx;
            for (bit = 7; bit >= 0; bit--) {
                if (bits & (1 << bit)) {
                    int py = y + row;
                    if (px >= (int)ClipX1 && px <= (int)ClipX2 &&
                        py >= (int)ClipY1 && py <= (int)ClipY2)
                        dest[dqb_layer_offset(px, py)] = (unsigned char)col;
                }
                px++;
            }
        }
        cx += cw;
    }
}

void DQBprint(int layer, const char __far *text, int x, int y, int col)
{
    xDQBprint(layer, (char __far *)text, x, y, col, 0);
}
