/* datafile.c — DATAFILE.ASM port: packed DQBPaCk archives. */
#include "dqb_int.h"
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <string.h>

static FILE *pack_fp;
static unsigned short BytePtr;
static unsigned char ByteStream[256];
static unsigned char ByteRep;
static unsigned char LastByte;
static unsigned char Password[9];
static short PasswordPtr = -1;
static unsigned long PackOff;
static unsigned char NumPackets;

static int get_stream_byte(void)
{
    BytePtr++;
    if (BytePtr >= 256) {
        size_t got = fread(ByteStream, 1, 256, pack_fp);
        (void)got;
        BytePtr = 0;
    }
    return ByteStream[BytePtr];
}

static int read_stream_byte(void)
{
    int si;

    if (ByteRep) {
        ByteRep--;
        return LastByte;
    }
    {
        int b = get_stream_byte();
        PasswordPtr++;
        si = PasswordPtr;
        if (Password[si] == 0) {
            PasswordPtr = 0;
            si = 0;
        }
        b = (b - Password[si]) & 0xFF;
        if (b != 0xFF)
            return b;
    }
    {
        int b = get_stream_byte();
        PasswordPtr++;
        si = PasswordPtr;
        if (Password[si] == 0) {
            PasswordPtr = 0;
            si = 0;
        }
        b = (b - Password[si]) & 0xFF;
        ByteRep = (unsigned char)(b - 1);
    }
    {
        int b = get_stream_byte();
        PasswordPtr++;
        si = PasswordPtr;
        if (Password[si] == 0) {
            PasswordPtr = 0;
            si = 0;
        }
        b = (b - Password[si]) & 0xFF;
        LastByte = (unsigned char)b;
        return LastByte;
    }
}

static int seek_packet(int id)
{
    unsigned long pos;
    unsigned char offbuf[4];

    if (id > NumPackets)
        return -1;
    pos = (unsigned long)id * 4 + 8;
    if (fseek(pack_fp, (long)pos, SEEK_SET) != 0)
        return -1;
    if (fread(offbuf, 1, 4, pack_fp) != 4)
        return -1;
    PackOff = (unsigned long)offbuf[0] | ((unsigned long)offbuf[1] << 8) |
        ((unsigned long)offbuf[2] << 16) | ((unsigned long)offbuf[3] << 24);
    if (fseek(pack_fp, (long)PackOff, SEEK_SET) != 0)
        return -1;
    PasswordPtr = -1;
    ByteRep = 0;
    BytePtr = 255;
    return 0;
}

static unsigned long read_magic(void)
{
    unsigned long m = 0;
    int i;

    for (i = 0; i < 4; i++)
        m = (m << 8) | (unsigned)read_stream_byte();
    return m;
}

int DQBAPI xDQBopenDataFile(char __far *file, char __far *pwd)
{
    unsigned char hdr[8];
    int i;

    if (PackActive) {
        LastError = 28;
        return 4;
    }
    dqb_hook_int24();
    pack_fp = fopen((const char *)file, "rb");
    if (!pack_fp) {
        dqb_unhook_int24();
        LastError = 4;
        return 1;
    }
    if (fread(hdr, 1, 8, pack_fp) != 8) {
        fclose(pack_fp);
        pack_fp = 0;
        dqb_unhook_int24();
        LastError = 5;
        return 2;
    }
    if (memcmp(hdr, "DQBPaCk", 7) != 0) {
        fclose(pack_fp);
        pack_fp = 0;
        dqb_unhook_int24();
        LastError = 11;
        return 3;
    }
    NumPackets = (unsigned char)(hdr[7] + 1);
    for (i = 0; i < 8; i++) {
        Password[i] = ((unsigned char __far *)pwd)[i];
        if (Password[i] == 0)
            break;
    }
    Password[8] = 0;
    PackActive = 1;
    PackFile = 1;
    dqb_unhook_int24();
    return 0;
}

int DQBAPI xDQBunpackFont(int packID, char __far *font)
{
    unsigned long magic;
    int i;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if (magic != 0x464E541AuL && magic != 0x464E5420L) {
        /* Accept 'FNTx' family; ASM compares 'FNT\x1A'. */
        if ((magic & 0xFFFFFF00L) != 0x464E5400L) {
            LastError = 27;
            return 3;
        }
    }
    for (i = 0; i < 2305; i++)
        ((unsigned char __far *)font)[i] = (unsigned char)read_stream_byte();
    return 0;
}

int DQBAPI DQBunpackImage(int packID, int layer, int x, int y)
{
    unsigned long magic;
    int w, h, yy;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x494D4700L) {
        LastError = 27;
        return 3;
    }
    w = read_stream_byte() | (read_stream_byte() << 8);
    h = read_stream_byte() | (read_stream_byte() << 8);
    {
        unsigned short seg = dqb_get_layer_seg((unsigned)layer);
        unsigned char far *base = (unsigned char far *)MK_FP(seg, 0);
        for (yy = 0; yy < h; yy++) {
            int xx;
            for (xx = 0; xx < w; xx++)
                base[dqb_layer_offset(x + xx, y + yy)] =
                    (unsigned char)read_stream_byte();
        }
    }
    return 0;
}

int DQBAPI DQBunpackSprite(int packID, void __far *sprite)
{
    unsigned long magic;
    int w, h, i, n;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x494D4700L) {
        LastError = 27;
        return 3;
    }
    w = read_stream_byte() | (read_stream_byte() << 8);
    h = read_stream_byte() | (read_stream_byte() << 8);
    ((unsigned char __far *)sprite)[0] = (unsigned char)(w << 3);
    ((unsigned char __far *)sprite)[1] = 0;
    ((unsigned char __far *)sprite)[2] = (unsigned char)h;
    ((unsigned char __far *)sprite)[3] = 0;
    n = w * h;
    for (i = 0; i < n; i++)
        ((unsigned char __far *)sprite)[4 + i] = (unsigned char)read_stream_byte();
    return 0;
}

int DQBAPI DQBunpackSound(int packID, int slot)
{
    unsigned long magic;
    int len, i;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x534E4400L) {
        LastError = 27;
        return 3;
    }
    len = read_stream_byte() | (read_stream_byte() << 8);
    if (slot < 1 || slot > NumSounds) {
        LastError = 19;
        return 4;
    }
    SoundLen[slot - 1] = (unsigned short)len;
    dqb_map_ems((unsigned short)((slot - 1) * 4 + SoundPage));
    {
        unsigned char far *dst = (unsigned char far *)MK_FP(EMSseg, 0);
        unsigned long k;
        for (k = 0; k < 65536UL; k++)
            dst[k] = 0x80;
        for (i = 0; i < len; i++)
            dst[i] = (unsigned char)read_stream_byte();
    }
    return 0;
}

int DQBAPI xDQBunpackPal(int packID, char __far *pal)
{
    unsigned long magic;
    int i;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x50414C00L) {
        LastError = 27;
        return 3;
    }
    for (i = 0; i < 768; i++)
        ((unsigned char __far *)pal)[i] = (unsigned char)read_stream_byte();
    return 0;
}

int DQBAPI DQBunpackBMap(int packID, int bmap)
{
    unsigned long magic;
    int bi = bmap - 1;
    int count, i;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x424D4100L) {
        LastError = 27;
        return 3;
    }
    if (bi < 0 || bi >= 10 || !BMapActive[bi]) {
        LastError = 8;
        return 4;
    }
    count = read_stream_byte();
    if (count != BMapLast[bi] - BMapFirst[bi] + 1) {
        LastError = 22;
        return 5;
    }
    {
        unsigned char far *dst = (unsigned char far *)MK_FP(BMapSeg[bi], 0);
        int n = count * 256;
        for (i = 0; i < n; i++)
            dst[i] = (unsigned char)read_stream_byte();
    }
    return 0;
}

int DQBAPI xDQBunpackCursor(int packID, char __far *cursor)
{
    unsigned long magic;
    int i;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x43555200L) {
        LastError = 27;
        return 3;
    }
    for (i = 0; i < 64; i++)
        ((unsigned char __far *)cursor)[i] = (unsigned char)read_stream_byte();
    return 0;
}

int DQBAPI DQBunpackUser(int packID, void __far *data)
{
    unsigned long magic;
    int len, i;

    if (!PackActive) {
        LastError = 25;
        return 1;
    }
    if (seek_packet(packID)) {
        LastError = 26;
        return 2;
    }
    magic = read_magic();
    if ((magic & 0xFFFFFF00L) != 0x55535200L) {
        LastError = 27;
        return 3;
    }
    len = read_stream_byte() | (read_stream_byte() << 8);
    for (i = 0; i < len; i++)
        ((unsigned char __far *)data)[i] = (unsigned char)read_stream_byte();
    return 0;
}

void DQBAPI DQBcloseDataFile(void)
{
    if (!PackActive)
        return;
    if (pack_fp)
        fclose(pack_fp);
    pack_fp = 0;
    PackActive = 0;
}
