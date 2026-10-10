/* sound.c — WAV load into EMS (C); SB IRQ mixer in sound_drv.asm. */
#include "dqb_int.h"
#include <stdio.h>
#include <string.h>

int DQBAPI xDQBloadSound(int slot, char __far *file)
{
    FILE *f;
    unsigned char hdr[12];
    unsigned char chunk[512];
    unsigned long dataLen, left;
    unsigned short page;
    unsigned char far *dst;
    size_t n, got;

    if (slot < 1 || slot > (int)NumSounds)
        return 1;

    dqb_hook_int24();
    f = fopen((const char *)file, "rb");
    if (!f) {
        dqb_unhook_int24();
        return 1;
    }
    if (fread(hdr, 1, 12, f) != 12 || memcmp(hdr, "RIFF", 4) != 0) {
        fclose(f);
        dqb_unhook_int24();
        return 3;
    }
    fseek(f, 20, SEEK_SET);
    if (fread(hdr, 1, 4, f) != 4) {
        fclose(f);
        dqb_unhook_int24();
        return 2;
    }
    fseek(f, 40, SEEK_SET);
    if (fread(hdr, 1, 4, f) != 4) {
        fclose(f);
        dqb_unhook_int24();
        return 2;
    }
    dataLen = (unsigned long)hdr[0] | ((unsigned long)hdr[1] << 8) |
        ((unsigned long)hdr[2] << 16) | ((unsigned long)hdr[3] << 24);
    if (dataLen > 0xFFFFUL) {
        fclose(f);
        dqb_unhook_int24();
        return 5;
    }
    SoundLen[slot - 1] = (unsigned short)(dataLen - 1);
    page = (unsigned short)((SoundPage / 4 + (unsigned short)(slot - 1)) * 4);
    dqb_map_ems(page);
    dst = (unsigned char __far *)MK_FP(EMSseg, 0);
    /* Medium-model fread() is near-only; a far EMS dest would truncate
     * to DGROUP:0 and smash the runtime (hang after installSB). */
    left = dataLen;
    while (left) {
        n = (left > sizeof(chunk)) ? sizeof(chunk) : (size_t)left;
        got = fread(chunk, 1, n, f);
        if (got == 0)
            break;
        _fmemcpy(dst, chunk, got);
        dst += got;
        left -= got;
    }
    fclose(f);
    dqb_unhook_int24();
    return (left == 0) ? 0 : 2;
}
