#include "dqb_int.h"
#include <stdio.h>
#include <string.h>

static int load_pcx(FILE *f, unsigned char far *layer, int ox, int oy,
    char __far *pal, int __near *imgW, int __near *imgH)
{
    unsigned char hdr[128];
    int xmin, ymin, xsize, ysize;
    int y, dx;
    unsigned char block[769];
    long palPos;

    if (fread(hdr, 1, 128, f) != 128)
        return 2;
    /* DirectQB: manufacturer 0x0A, version 5, RLE, 8bpp. */
    if (hdr[0] != 0x0A || hdr[1] != 5 || hdr[2] != 1 || hdr[3] != 8)
        return 3;

    xmin = hdr[4] | (hdr[5] << 8);
    ymin = hdr[6] | (hdr[7] << 8);
    xsize = (hdr[8] | (hdr[9] << 8)) - xmin + 1;
    ysize = (hdr[10] | (hdr[11] << 8)) - ymin + 1;
    if (imgW)
        *imgW = xsize;
    if (imgH)
        *imgH = ysize;

    dx = 0;
    y = 0;
    while (y < ysize) {
        int b = fgetc(f);
        if (b == EOF)
            break;
        if ((b & 0xC0) == 0xC0) {
            int count = b & 0x3F;
            int pix = fgetc(f);
            if (pix == EOF)
                return 2;
            while (count-- > 0) {
                if (dx < xsize && y < ysize)
                    layer[dqb_layer_offset(ox + dx, oy + y)] = (unsigned char)pix;
                dx++;
                if (dx >= xsize) {
                    dx = 0;
                    y++;
                }
            }
        } else {
            if (dx < xsize && y < ysize)
                layer[dqb_layer_offset(ox + dx, oy + y)] = (unsigned char)b;
            dx++;
            if (dx >= xsize) {
                dx = 0;
                y++;
            }
        }
    }

    palPos = ftell(f);
    if (fseek(f, -769L, SEEK_END) == 0 &&
        fread(block, 1, 769, f) == 769 && block[0] == 0x0C) {
        int i;
        for (i = 0; i < 768; i++)
            ((unsigned char __far *)pal)[i] = (unsigned char)(block[i + 1] >> 2);
    } else if (palPos >= 0 && fseek(f, palPos, SEEK_SET) == 0) {
        int i;
        if (fgetc(f) == 0x0C) {
            for (i = 0; i < 768; i++) {
                int v = fgetc(f);
                if (v == EOF)
                    break;
                ((unsigned char __far *)pal)[i] = (unsigned char)(v >> 2);
            }
        }
    }
    return 0;
}

static int load_image(int layer, int x, int y, char __far *file,
    char __far *pal, int __near *imgW, int __near *imgH)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *layerBase = (unsigned char far *)MK_FP(seg, 0);
    FILE *f;
    int b0, rc;

    dqb_hook_int24();
    f = fopen((const char *)file, "rb");
    if (!f) {
        dqb_unhook_int24();
        return 1;
    }
    b0 = fgetc(f);
    if (b0 == EOF) {
        fclose(f);
        dqb_unhook_int24();
        return 2;
    }
    if (b0 == 0x0A) {
        fseek(f, 0, SEEK_SET);
        rc = load_pcx(f, layerBase, x, y, pal, imgW, imgH);
        fclose(f);
        dqb_unhook_int24();
        return rc;
    }
    fclose(f);
    dqb_unhook_int24();
    return 3;
}

int DQBAPI xDQBloadImage(int layer, int x, int y, char __far *file,
    char __far *pal, int __near *imgW, int __near *imgH)
{
    return load_image(layer, x, y, file, pal, imgW, imgH);
}

int DQBloadImage(int layer, int x, int y, const char __far *file, void __far *pal,
    int *imgW, int *imgH)
{
    return load_image(layer, x, y, (char __far *)file, (char __far *)pal,
        (int __near *)imgW, (int __near *)imgH);
}
