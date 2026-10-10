/* sound.c — WAV load into EMS + play stubs (P4; SB IRQ mixer TBD). */
#include "dqb_int.h"
#include <stdio.h>
#include <string.h>

int DQBAPI DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma)
{
    (void)volActive;
    (void)channels;
    (void)freq;
    (void)baseAddr;
    (void)irq;
    (void)dma;
    SoundActive = 1;
    return 0;
}

void DQBAPI DQBremoveSB(void)
{
    SoundActive = 0;
}

int DQBAPI xDQBloadSound(int slot, char __far *file)
{
    FILE *f;
    unsigned char hdr[12];
    unsigned long dataLen;
    unsigned short page;
    unsigned char far *dst;
    size_t n;

    if (slot < 1 || slot > (int)NumSounds)
        return 1;

    dqb_hook_int24();
    f = fopen((const char __far *)file, "rb");
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
    n = fread(dst, 1, (size_t)dataLen, f);
    fclose(f);
    dqb_unhook_int24();
    return (n == dataLen) ? 0 : 2;
}

void DQBAPI DQBplaySound(int soundNum, int voice, int freq, int loopFlag)
{
    (void)soundNum;
    (void)voice;
    (void)freq;
    (void)loopFlag;
}

void DQBAPI DQBstopVoice(int voice)
{
    (void)voice;
}
