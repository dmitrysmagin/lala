#include "dqb_int.h"
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

/* ---- PCX loader (existing) ---- */

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

static int load_bsv(FILE *f, unsigned char far *layer, int ox, int oy,
    char __far *pal, int __near *imgW, int __near *imgH)
{
    unsigned char hdr[10];
    unsigned seg, off, len, xs, ys;
    long fsize;

    if (fread(hdr, 1, 10, f) != 10)
        return 2;
    seg = hdr[0] | (hdr[1] << 8);
    off = hdr[2] | (hdr[3] << 8);
    len = hdr[4] | (hdr[5] << 8);
    xs = hdr[6] | (hdr[7] << 8);
    ys = hdr[8] | (hdr[9] << 8);
    (void)seg;
    (void)off;
    if (seg == 0xA000) {
        unsigned char dim[4];
        if (imgW)
            *imgW = 320;
        if (imgH)
            *imgH = 200;
        if (fread(dim, 1, 4, f) != 4)
            return 2;
        layer[0] = dim[0];
        layer[1] = dim[1];
        layer[2] = dim[2];
        layer[3] = dim[3];
        {
            unsigned char chunk[512];
            unsigned left = len;
            unsigned char far *dst = layer + 4;
            while (left) {
                size_t n = left > sizeof(chunk) ? sizeof(chunk) : left;
                size_t got = fread(chunk, 1, n, f);
                if (!got)
                    return 2;
                _fmemcpy(dst, chunk, got);
                dst += got;
                left -= (unsigned)got;
            }
        }
    } else {
        int w = (int)(xs >> 3);
        int h = (int)ys;
        int yy;

        if (imgW)
            *imgW = w;
        if (imgH)
            *imgH = h;
        for (yy = 0; yy < h; yy++) {
            unsigned char row[320];
            if (fread(row, 1, (size_t)w, f) != (size_t)w)
                return 2;
            _fmemcpy(layer + dqb_layer_offset(ox, oy + yy), row, (unsigned)w);
        }
    }
    /* Palette appended iff filesize != len+7. */
    fseek(f, 0, SEEK_END);
    fsize = ftell(f);
    if (fsize != (long)len + 7) {
        fseek(f, 0, SEEK_SET);
        if (fread(pal, 1, 768, f) != 768)
            return 2;
    }
    return 0;
}

static int load_bmp(FILE *f, unsigned char far *layer, int ox, int oy,
    char __far *pal, int __near *imgW, int __near *imgH)
{
    unsigned char hdr[54];
    unsigned long xs, ys;
    unsigned planes, bpp;
    unsigned long comp;
    int yy;

    if (fread(hdr + 1, 1, 53, f) != 53)
        return 2;
    if (hdr[1] != 'M')
        return 3;
    planes = hdr[26] | (hdr[27] << 8);
    bpp = hdr[28] | (hdr[29] << 8);
    comp = (unsigned long)hdr[30] | ((unsigned long)hdr[31] << 8) |
        ((unsigned long)hdr[32] << 16) | ((unsigned long)hdr[33] << 24);
    if (planes != 1 || bpp != 8 || comp != 0)
        return 3;
    xs = (unsigned long)hdr[18] | ((unsigned long)hdr[19] << 8) |
        ((unsigned long)hdr[20] << 16) | ((unsigned long)hdr[21] << 24);
    ys = (unsigned long)hdr[22] | ((unsigned long)hdr[23] << 8) |
        ((unsigned long)hdr[24] << 16) | ((unsigned long)hdr[25] << 24);
    if (imgW)
        *imgW = (int)xs;
    if (imgH)
        *imgH = (int)ys;
    /* Palette: 256 x (B,G,R,0). */
    for (yy = 0; yy < 256; yy++) {
        int b = fgetc(f);
        int g = fgetc(f);
        int r = fgetc(f);
        int z = fgetc(f);
        if (r == EOF || g == EOF || b == EOF || z == EOF)
            return 2;
        ((unsigned char __far *)pal)[yy * 3] = (unsigned char)(r >> 2);
        ((unsigned char __far *)pal)[yy * 3 + 1] = (unsigned char)(g >> 2);
        ((unsigned char __far *)pal)[yy * 3 + 2] = (unsigned char)(b >> 2);
    }
    for (yy = (int)ys - 1; yy >= 0; yy--) {
        int stride = (int)xs + ((int)xs & 1);
        unsigned char row[321];
        int k;
        if (fread(row, 1, (size_t)stride, f) != (size_t)stride)
            return 2;
        for (k = 0; k < (int)xs; k++)
            layer[dqb_layer_offset(ox + k, oy + yy)] = row[k];
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
        LastError = 4;
        return 1;
    }
    b0 = fgetc(f);
    if (b0 == EOF) {
        fclose(f);
        dqb_unhook_int24();
        LastError = 5;
        return 2;
    }
    if (b0 == 0xFD) {
        fseek(f, 0, SEEK_SET);
        /* Skip magic already consumed: rewind then let loader read it. */
        fseek(f, 1, SEEK_SET);
        rc = load_bsv(f, layerBase, x, y, pal, imgW, imgH);
        fclose(f);
        dqb_unhook_int24();
        if (rc == 3)
            LastError = 11;
        else if (rc == 2)
            LastError = 5;
        return rc;
    }
    if (b0 == 'B') {
        fseek(f, 0, SEEK_SET);
        rc = load_bmp(f, layerBase, x, y, pal, imgW, imgH);
        fclose(f);
        dqb_unhook_int24();
        if (rc == 3)
            LastError = 11;
        else if (rc == 2)
            LastError = 5;
        return rc;
    }
    if (b0 == 0x0A) {
        fseek(f, 0, SEEK_SET);
        rc = load_pcx(f, layerBase, x, y, pal, imgW, imgH);
        fclose(f);
        dqb_unhook_int24();
        if (rc == 3)
            LastError = 11;
        else if (rc == 2)
            LastError = 5;
        return rc;
    }
    fclose(f);
    dqb_unhook_int24();
    LastError = 11;
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

/* ---- Save (BSV/BMP/PCX) ---- */

int DQBAPI xDQBsaveImage(int layer, int x1, int y1, int x2, int y2,
    char __far *file, char __far *pal, int format)
{
    unsigned short seg = dqb_get_layer_seg((unsigned)layer);
    unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
    int w = x2 - x1 + 1;
    int h = y2 - y1 + 1;
    FILE *f;

    dqb_hook_int24();
    f = fopen((const char *)file, "wb");
    if (!f) {
        dqb_unhook_int24();
        LastError = 9;
        return 1;
    }
    if (format == 0) { /* BSV */
        unsigned char hdr[10];
        int yy;

        hdr[0] = 0xFD;
        hdr[1] = 0;
        hdr[2] = 0xA0;
        hdr[3] = 0;
        if (w == 320 && h == 200) {
            unsigned len = 64000;
            hdr[4] = (unsigned char)len;
            hdr[5] = (unsigned char)(len >> 8);
            hdr[6] = 0x40;
            hdr[7] = 0x01;
            hdr[8] = 0xC8;
            hdr[9] = 0x00;
            fwrite(hdr, 1, 7, f);
            {
                unsigned char chunk[512];
                unsigned left = 64000;
                unsigned char far *src = base;
                while (left) {
                    size_t n = left > sizeof(chunk) ? sizeof(chunk) : left;
                    _fmemcpy(chunk, src, n);
                    if (fwrite(chunk, 1, n, f) != n) {
                        fclose(f);
                        dqb_unhook_int24();
                        LastError = 10;
                        return 2;
                    }
                    src += n;
                    left -= n;
                }
            }
        } else {
            unsigned len = (unsigned)(w * h + 4);
            hdr[4] = (unsigned char)len;
            hdr[5] = (unsigned char)(len >> 8);
            hdr[6] = (unsigned char)(w << 3);
            hdr[7] = (unsigned char)((w << 3) >> 8);
            hdr[8] = (unsigned char)h;
            hdr[9] = (unsigned char)(h >> 8);
            fwrite(hdr, 1, 10, f);
            for (yy = 0; yy < h; yy++) {
                unsigned char row[320];
                _fmemcpy(row, base + dqb_layer_offset(x1, y1 + yy), (unsigned)w);
                if (fwrite(row, 1, (size_t)w, f) != (size_t)w) {
                    fclose(f);
                    dqb_unhook_int24();
                    LastError = 10;
                    return 2;
                }
            }
        }
        {
            unsigned char prow[768];
            int i;
            for (i = 0; i < 768; i++)
                prow[i] = (unsigned char)(((unsigned char __far *)pal)[i] << 2);
            if (fwrite(prow, 1, 768, f) != 768) {
                fclose(f);
                dqb_unhook_int24();
                LastError = 10;
                return 2;
            }
        }
    } else if (format == 1) { /* BMP */
        unsigned char hdr[54];
        int yy;

        memset(hdr, 0, sizeof(hdr));
        hdr[0] = 'B';
        hdr[1] = 'M';
        {
            unsigned long fsize = (unsigned long)(w * h) + 1078UL;
            hdr[2] = (unsigned char)fsize;
            hdr[3] = (unsigned char)(fsize >> 8);
            hdr[4] = (unsigned char)(fsize >> 16);
            hdr[5] = (unsigned char)(fsize >> 24);
        }
        hdr[10] = 1078 & 0xFF;
        hdr[11] = (1078 >> 8) & 0xFF;
        hdr[14] = 40;
        hdr[18] = (unsigned char)w;
        hdr[19] = (unsigned char)(w >> 8);
        hdr[22] = (unsigned char)h;
        hdr[23] = (unsigned char)(h >> 8);
        hdr[26] = 1;
        hdr[28] = 8;
        {
            unsigned long isz = (unsigned long)(w * h);
            hdr[34] = (unsigned char)isz;
            hdr[35] = (unsigned char)(isz >> 8);
            hdr[36] = (unsigned char)(isz >> 16);
            hdr[37] = (unsigned char)(isz >> 24);
        }
        hdr[38] = 0xCE;
        hdr[39] = 0x0E;
        hdr[42] = 0xC4;
        hdr[43] = 0x0E;
        if (fwrite(hdr, 1, 54, f) != 54) {
            fclose(f);
            dqb_unhook_int24();
            LastError = 10;
            return 2;
        }
        for (yy = 0; yy < 256; yy++) {
            unsigned char r = ((unsigned char __far *)pal)[yy * 3] << 2;
            unsigned char g = ((unsigned char __far *)pal)[yy * 3 + 1] << 2;
            unsigned char b = ((unsigned char __far *)pal)[yy * 3 + 2] << 2;
            fputc(b, f);
            fputc(g, f);
            fputc(r, f);
            fputc(0, f);
        }
        for (yy = h - 1; yy >= 0; yy--) {
            unsigned char row[321];
            int stride = w + (w & 1);
            int k;
            for (k = 0; k < w; k++)
                row[k] = base[dqb_layer_offset(x1 + k, y1 + yy)];
            if (stride > w)
                row[w] = 0;
            if (fwrite(row, 1, (size_t)stride, f) != (size_t)stride) {
                fclose(f);
                dqb_unhook_int24();
                LastError = 10;
                return 2;
            }
        }
    } else { /* PCX */
        unsigned char hdr[128];
        int yy, xx;

        memset(hdr, 0, sizeof(hdr));
        hdr[0] = 0x0A;
        hdr[1] = 5;
        hdr[2] = 1;
        hdr[3] = 8;
        hdr[4] = (unsigned char)x1;
        hdr[5] = (unsigned char)(x1 >> 8);
        hdr[6] = (unsigned char)y1;
        hdr[7] = (unsigned char)(y1 >> 8);
        hdr[8] = (unsigned char)x2;
        hdr[9] = (unsigned char)(x2 >> 8);
        hdr[10] = (unsigned char)y2;
        hdr[11] = (unsigned char)(y2 >> 8);
        if (fwrite(hdr, 1, 128, f) != 128) {
            fclose(f);
            dqb_unhook_int24();
            LastError = 10;
            return 2;
        }
        for (yy = 0; yy < h; yy++) {
            xx = 0;
            while (xx < w) {
                unsigned char v = base[dqb_layer_offset(x1 + xx, y1 + yy)];
                int run = 1;
                while (xx + run < w && run < 63 &&
                    base[dqb_layer_offset(x1 + xx + run, y1 + yy)] == v)
                    run++;
                if (run > 1 || (v & 0xC0) == 0xC0)
                    fputc(0xC0 | run, f);
                fputc(v, f);
                xx += run;
            }
        }
        fputc(0x0C, f);
        {
            int i;
            for (i = 0; i < 768; i++)
                fputc(((unsigned char __far *)pal)[i] << 2, f);
        }
    }
    fclose(f);
    dqb_unhook_int24();
    return 0;
}

/* ---- FLI support ---- */

static FILE *fli_file;
static long fli_frame_pos;
static int fli_frames;
static int fli_speed;

static void fli_decode_color(unsigned char far *layer, FILE *f, int packets)
{
    int i;
    int cur = 0;

    (void)layer;
    for (i = 0; i < packets; i++) {
        int skip = fgetc(f);
        int count = fgetc(f);
        int k;

        cur += skip;
        if (count == 0)
            count = 256;
        outp(0x3C8, (unsigned char)cur);
        for (k = 0; k < count; k++) {
            int r = fgetc(f);
            int g = fgetc(f);
            int b = fgetc(f);
            outp(0x3C9, (unsigned char)(r >> 2));
            outp(0x3C9, (unsigned char)(g >> 2));
            outp(0x3C9, (unsigned char)(b >> 2));
            cur++;
        }
    }
}

static void fli_decode_brun(unsigned char far *layer, FILE *f)
{
    int yy;

    for (yy = 0; yy < 200; yy++) {
        int packets = fgetc(f);
        int xx = 0;
        int p;

        if (packets == EOF)
            return;
        for (p = 0; p < packets; p++) {
            int count = (signed char)fgetc(f);
            int v;
            int k;

            if (count >= 0) {
                v = fgetc(f);
                for (k = 0; k < count; k++, xx++)
                    layer[dqb_layer_offset(xx, yy)] = (unsigned char)v;
            } else {
                count = -count;
                for (k = 0; k < count; k++, xx++) {
                    v = fgetc(f);
                    layer[dqb_layer_offset(xx, yy)] = (unsigned char)v;
                }
            }
        }
    }
}

static void fli_decode_lc(unsigned char far *layer, FILE *f)
{
    int lines = fgetc(f) | (fgetc(f) << 8);
    int yy;
    int cur = fgetc(f) | (fgetc(f) << 8);
    int i;

    (void)lines;
    for (yy = cur; yy < 200; yy++) {
        int packets = fgetc(f);
        int xx = 0;
        int p;

        if (packets == EOF)
            return;
        for (p = 0; p < packets; p++) {
            int skip = fgetc(f);
            int count = (signed char)fgetc(f);
            int k;

            xx += skip;
            if (count >= 0) {
                for (k = 0; k < count; k++, xx++) {
                    int v = fgetc(f);
                    layer[dqb_layer_offset(xx, yy)] = (unsigned char)v;
                }
            } else {
                int v = fgetc(f);
                count = -count;
                for (k = 0; k < count; k++, xx++)
                    layer[dqb_layer_offset(xx, yy)] = (unsigned char)v;
            }
        }
        if (yy + 1 < 200) {
            i = fgetc(f);
            if (i == EOF)
                return;
            ungetc(i, f);
            /* LC stores line count implicitly; simplified: continue. */
        }
    }
}

static int fli_decode_frame(unsigned char far *layer, FILE *f)
{
    unsigned char fhdr[16];
    int chunks, c;

    if (fread(fhdr, 1, 16, f) != 16)
        return -1;
    if (fhdr[4] != 0xFA || fhdr[5] != 0xF1)
        return -1;
    chunks = fhdr[6] | (fhdr[7] << 8);
    for (c = 0; c < chunks; c++) {
        unsigned char chdr[6];
        long csize;
        int cid;

        if (fread(chdr, 1, 6, f) != 6)
            return -1;
        csize = (long)chdr[0] | ((long)chdr[1] << 8) |
            ((long)chdr[2] << 16) | ((long)chdr[3] << 24);
        cid = chdr[4] | (chdr[5] << 8);
        if (cid == 11) {
            int packets = fgetc(f) | (fgetc(f) << 8);
            fli_decode_color(layer, f, packets);
        } else if (cid == 12) {
            fli_decode_lc(layer, f);
            fseek(f, csize - 6 - 4, SEEK_CUR);
        } else if (cid == 13) {
            unsigned i;
            for (i = 0; i < 64000UL; i++)
                layer[i] = 0;
        } else if (cid == 15) {
            fli_decode_brun(layer, f);
        } else if (cid == 16) {
            unsigned char chunk[512];
            unsigned long left = (unsigned long)csize - 6;
            unsigned char far *dst = layer;
            while (left) {
                size_t n = left > sizeof(chunk) ? sizeof(chunk) : (size_t)left;
                size_t got = fread(chunk, 1, n, f);
                if (!got)
                    break;
                _fmemcpy(dst, chunk, got);
                dst += got;
                left -= got;
            }
        } else {
            fseek(f, csize - 6, SEEK_CUR);
        }
    }
    return 0;
}

static void fli_vsync(int n)
{
    int i;
    for (i = 0; i < n; i++) {
        while (inp(0x3DA) & 8)
            ;
        while (!(inp(0x3DA) & 8))
            ;
    }
}

static int fli_stop_requested(int stopKey)
{
    int i;

    if (!KeyActive || stopKey == 0)
        return 0;
    if (stopKey == 0xFFFF) {
        for (i = 0; i < 128; i++)
            if (KeyStatus[i] == 1)
                return 1;
        return 0;
    }
    return KeyStatus[stopKey & 127] == 1;
}

int DQBAPI xDQBplayFLI(char __far *file, int bufLayer, int stopKey, int looped)
{
    unsigned char hdr[128];
    int frames, speed;
    unsigned short seg;
    unsigned char far *layer;
    int f;

    if (FLIactive) {
        LastError = 21;
        return 5;
    }
    dqb_hook_int24();
    fli_file = fopen((const char *)file, "rb");
    if (!fli_file) {
        dqb_unhook_int24();
        LastError = 4;
        return 2;
    }
    if (fread(hdr, 1, 128, fli_file) != 128) {
        fclose(fli_file);
        dqb_unhook_int24();
        LastError = 5;
        return 3;
    }
    if ((hdr[4] | (hdr[5] << 8)) != 0xAF11 ||
        (hdr[8] | (hdr[9] << 8)) != 320 ||
        (hdr[10] | (hdr[11] << 8)) != 200) {
        fclose(fli_file);
        dqb_unhook_int24();
        LastError = 11;
        return 4;
    }
    frames = hdr[6] | (hdr[7] << 8);
    speed = hdr[16] | (hdr[17] << 8);
    seg = dqb_get_layer_seg((unsigned)bufLayer ? bufLayer : 0);
    if (bufLayer == 0)
        seg = 0xA000;
    layer = (unsigned char far *)MK_FP(seg, 0);
    for (f = 0; f < frames; f++) {
        fli_decode_frame(layer, fli_file);
        fli_vsync(speed);
        if (bufLayer) {
            unsigned char far *video = (unsigned char far *)MK_FP(0xA000, 0);
            _fmemcpy(video, layer, 64000);
        }
        if (fli_stop_requested(stopKey))
            break;
        if (f == frames - 1 && looped && !fli_stop_requested(stopKey)) {
            fseek(fli_file, 128, SEEK_SET);
            f = -1;
        }
    }
    fclose(fli_file);
    dqb_unhook_int24();
    return 0;
}

int DQBAPI xDQBopenFLI(char __far *file, int __near *frames, int __near *speed)
{
    unsigned char hdr[128];

    if (FLIactive) {
        LastError = 21;
        return 5;
    }
    dqb_hook_int24();
    fli_file = fopen((const char *)file, "rb");
    if (!fli_file) {
        dqb_unhook_int24();
        LastError = 4;
        return 2;
    }
    if (fread(hdr, 1, 128, fli_file) != 128) {
        fclose(fli_file);
        dqb_unhook_int24();
        LastError = 5;
        return 3;
    }
    if ((hdr[4] | (hdr[5] << 8)) != 0xAF11) {
        fclose(fli_file);
        dqb_unhook_int24();
        LastError = 11;
        return 4;
    }
    fli_frames = hdr[6] | (hdr[7] << 8);
    fli_speed = hdr[16] | (hdr[17] << 8);
    if (frames)
        *frames = fli_frames;
    if (speed)
        *speed = fli_speed;
    fli_frame_pos = 128;
    FLIactive = 1;
    FLIfile = 1;
    dqb_unhook_int24();
    return 0;
}

void DQBAPI DQBcloseFLI(void)
{
    if (!FLIactive)
        return;
    if (fli_file)
        fclose(fli_file);
    fli_file = 0;
    FLIactive = 0;
}

void DQBAPI DQBplayFLIstep(int layer)
{
    unsigned short seg;
    unsigned char far *dst;

    if (!FLIactive || !fli_file)
        return;
    seg = dqb_get_layer_seg((unsigned)layer);
    dst = (unsigned char far *)MK_FP(seg, 0);
    fseek(fli_file, fli_frame_pos, SEEK_SET);
    {
        unsigned char fhdr[16];
        long fsize;
        if (fread(fhdr, 1, 16, fli_file) != 16)
            return;
        fsize = (long)fhdr[0] | ((long)fhdr[1] << 8) |
            ((long)fhdr[2] << 16) | ((long)fhdr[3] << 24);
        fseek(fli_file, fli_frame_pos, SEEK_SET);
        fli_decode_frame(dst, fli_file);
        fli_frame_pos += fsize;
    }
}
