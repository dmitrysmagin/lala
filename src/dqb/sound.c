/* sound.c — WAV load + Sound Blaster IRQ mixer (was SOUND.ASM / sound_drv.asm). */
#include "dqb_int.h"
#include <conio.h>
#include <dos.h>
#include <i86.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFERLEN 512
#define MAX_VOICES 32
#define SB_AUTO (-1)

static unsigned char dma_store[BUFFERLEN * 2];
static unsigned char *SoundBuffer;
static int MixBuffer[BUFFERLEN / 2];
static unsigned short MixPtr;
static unsigned char DMA = 1;
static unsigned char PicANDmask;
static unsigned short DMA_Page, DMA_Base, DMA_Count;
static unsigned short SamplingRate = 22050;
static unsigned short MixChannels = 8;
static unsigned char Playing;
static unsigned short SamplePtr[MAX_VOICES];
static unsigned short LowCount[MAX_VOICES];
static unsigned short HighCount[MAX_VOICES];
static unsigned short Counter[MAX_VOICES];
static unsigned short VoiceSound[MAX_VOICES];
static unsigned short VoiceLoop[MAX_VOICES];
static unsigned short VoiceVol[MAX_VOICES];
static unsigned short VoiceLoopEnd[MAX_VOICES];
static unsigned short VoiceLoopLen[MAX_VOICES];

static void __interrupt __far sb_mix_isr(void);

static void wait_write_dsp(unsigned short port)
{
    unsigned n = 0;

    while (--n) {
        if (!(inp(port) & 0x80))
            break;
    }
}

static void wait_read_dsp(unsigned short port)
{
    unsigned n = 0;

    while (--n) {
        if (inp(port) & 0x80)
            break;
    }
}

static void dsp_write(unsigned char val)
{
    unsigned short p = (unsigned short)(BaseAddr + 0x0C);

    wait_write_dsp(p);
    outp(p, val);
}

static int dsp_reset(void)
{
    int tries = 300;
    unsigned short p6 = (unsigned short)(BaseAddr + 6);

    do {
        outp(p6, 1);
        inp(p6);
        inp(p6);
        inp(p6);
        inp(p6);
        inp(p6);
        inp(p6);
        outp(p6, 0);
        wait_read_dsp((unsigned short)(BaseAddr + 0x0E));
        if ((unsigned char)inp(BaseAddr + 0x0A) == 0xAA)
            return 1;
    } while (--tries);
    return 0;
}

/* 512-byte window inside dma_store that does not cross a 64K DMA page. */
static unsigned char *dma_window(void)
{
    unsigned long phys;
    unsigned short off;

    phys = ((unsigned long)FP_SEG(dma_store) << 4) + FP_OFF(dma_store);
    off = (unsigned short)phys;
    if (off <= (unsigned short)(0x10000UL - BUFFERLEN))
        return dma_store;
    return dma_store + (unsigned short)(0x10000UL - off);
}

static void setup_dma(void)
{
    unsigned long phys;
    unsigned short start, page, count;
    unsigned char tc;
    unsigned long rate;

    SoundBuffer = dma_window();
    phys = ((unsigned long)FP_SEG(SoundBuffer) << 4) + FP_OFF(SoundBuffer);
    page = (unsigned short)(phys >> 16);
    start = (unsigned short)phys;
    count = BUFFERLEN - 1;

    outp(0x0A, (unsigned char)(DMA + 4));
    outp(0x0C, 0);
    outp(0x0B, (unsigned char)(0x58 + DMA));
    outp(DMA_Page, (unsigned char)page);
    outp(DMA_Base, (unsigned char)start);
    outp(DMA_Base, (unsigned char)(start >> 8));
    outp(DMA_Count, (unsigned char)count);
    outp(DMA_Count, (unsigned char)(count >> 8));
    outp(0x0A, DMA);

    rate = SamplingRate ? SamplingRate : 1;
    tc = (unsigned char)(-(int)(1000000UL / rate));
    dsp_write(0x40);
    dsp_write(tc);
    dsp_write(0x48);
    dsp_write((unsigned char)((BUFFERLEN / 2) - 1));
    dsp_write((unsigned char)(((BUFFERLEN / 2) - 1) >> 8));
    dsp_write(0x1C);
}

static void ems_save_map(void)
{
    unsigned short h = EMShdl;

    _asm {
        mov ah, 47h
        mov dx, h
        int 67h
    }
}

static void ems_restore_map(void)
{
    unsigned short h = EMShdl;

    _asm {
        mov ah, 48h
        mov dx, h
        int 67h
    }
}

static void map_sound_pages(unsigned short logical)
{
    unsigned short h = EMShdl;

    _asm {
        mov dx, h
        mov bx, logical
        mov ax, 4400h
        int 67h
        inc bx
        mov ax, 4401h
        int 67h
        inc bx
        mov ax, 4402h
        int 67h
        inc bx
        mov ax, 4403h
        int 67h
    }
}

static void mix_voices(void)
{
    unsigned v, s;
    unsigned char far *ems;
    unsigned char far *vol;

    for (s = 0; s < BUFFERLEN / 2; s++)
        MixBuffer[s] = 0;
    if (!Playing)
        goto clip;
    ems = (unsigned char far *)MK_FP(EMSseg, 0);
    vol = VolActive ? (unsigned char far *)MK_FP(VolSeg, 0) : 0;
    for (v = 0; v < MixChannels && v < MAX_VOICES; v++) {
        unsigned short end;
        if (!VoiceSound[v])
            continue;
        map_sound_pages((unsigned short)((VoiceSound[v] - 1) * 4 + SoundPage));
        end = VoiceLoopEnd[v];
        for (s = 0; s < BUFFERLEN / 2; s++) {
            unsigned short ptr;
            unsigned short sample;
            unsigned short sum;

            sum = (unsigned short)(Counter[v] + LowCount[v]);
            Counter[v] = sum;
            ptr = (unsigned short)(SamplePtr[v] + HighCount[v] + (sum < LowCount[v]));
            if (ptr >= end) {
                if (VoiceLoop[v] == 1)
                    ptr = (unsigned short)(ptr - VoiceLoopLen[v]);
                else {
                    VoiceSound[v] = 0;
                    Playing--;
                    break;
                }
            }
            SamplePtr[v] = ptr;
            sample = ems[ptr];
            if (vol)
                sample = vol[(sample << 6) + VoiceVol[v]];
            MixBuffer[s] += (int)sample - 0x80;
        }
    }
clip:
    {
        unsigned char *out = SoundBuffer + MixPtr;
        for (s = 0; s < BUFFERLEN / 2; s++) {
            int x = MixBuffer[s] + 0x80;
            if (x > 255)
                x = 255;
            if (x < 0)
                x = 0;
            out[s] = (unsigned char)x;
        }
        MixPtr ^= (unsigned short)(BUFFERLEN / 2);
    }
}

static void __interrupt __far sb_mix_isr(void)
{
    ems_save_map();
    mix_voices();
    ems_restore_map();
    (void)inp(BaseAddr + 0x0E);
    outp(0x20, 0x20);
}

static int parse_blaster(int *baseAddr, int *irq, int *dma)
{
    const char *env = getenv("BLASTER");
    const char *p;

    if (!env)
        return 0;
    for (p = env; *p; p++) {
        if ((*p == 'A' || *p == 'a') && *baseAddr == SB_AUTO) {
            int v = 0;
            const char *q = p + 1;
            while (*q >= '0' && *q <= '9') {
                v = (v << 4) + (*q - '0');
                q++;
            }
            *baseAddr = v;
        } else if ((*p == 'I' || *p == 'i') && *irq == SB_AUTO)
            *irq = p[1] - '0';
        else if ((*p == 'D' || *p == 'd') && *dma == SB_AUTO)
            *dma = p[1] - '0';
    }
    return 1;
}

int DQBAPI DQBinstallSB(int volActive, int channels, int freq, int baseAddr, int irq, int dma)
{
    union REGS regs;
    struct SREGS sregs;
    unsigned vec;
    int i;

    if (!EMSallocated || !NumSounds) {
        LastError = 12;
        return 1;
    }
    if (SoundActive)
        return 0;

    if (baseAddr == SB_AUTO || irq == SB_AUTO || dma == SB_AUTO)
        parse_blaster(&baseAddr, &irq, &dma);
    if (baseAddr == SB_AUTO || irq == SB_AUTO || dma == SB_AUTO) {
        LastError = 23;
        return 5;
    }

    VolActive = 0;
    VolSeg = 0;
    if (volActive) {
        regs.h.ah = 0x48;
        regs.x.bx = 1024;
        dqb_int386(0x21, &regs, &regs);
        if (regs.x.cflag) {
            LastError = 7;
            return 7;
        }
        VolSeg = regs.x.ax;
        {
            unsigned char far *t = (unsigned char far *)MK_FP(VolSeg, 0);
            unsigned sample, v;
            for (sample = 0; sample < 256; sample++) {
                for (v = 0; v < 64; v++)
                    t[sample * 64 + v] =
                        (unsigned char)((((int)sample - 128) * (int)v) / 64 + 128);
            }
        }
        VolActive = 1;
    }

    Playing = 0;
    MixPtr = 0;
    for (i = 0; i < MAX_VOICES; i++) {
        VoiceSound[i] = 0;
        VoiceVol[i] = 63;
        SamplePtr[i] = 0;
        Counter[i] = 0;
    }

    BaseAddr = (unsigned short)baseAddr;
    IRQ = (unsigned char)irq;
    PicORmask = (unsigned char)(1 << IRQ);
    PicANDmask = (unsigned char)~PicORmask;
    DMA = (unsigned char)dma;
    switch (DMA) {
    case 0:
        DMA_Page = 0x87;
        DMA_Base = 0;
        DMA_Count = 1;
        break;
    case 1:
        DMA_Page = 0x83;
        DMA_Base = 2;
        DMA_Count = 3;
        break;
    case 2:
        DMA_Page = 0x81;
        DMA_Base = 4;
        DMA_Count = 5;
        break;
    case 3:
        DMA_Page = 0x82;
        DMA_Base = 6;
        DMA_Count = 7;
        break;
    default:
        LastError = 13;
        return 4;
    }

    if (!dsp_reset()) {
        LastError = 14;
        return 2;
    }
    if (freq > 23000) {
        LastError = 15;
        return 6;
    }
    MixChannels = (unsigned short)channels;
    SamplingRate = (unsigned short)freq;

    dsp_write(0xE1);
    wait_read_dsp((unsigned short)(BaseAddr + 0x0E));
    {
        unsigned char major = (unsigned char)inp(BaseAddr + 0x0A);
        unsigned char minor;
        wait_read_dsp((unsigned short)(BaseAddr + 0x0E));
        minor = (unsigned char)inp(BaseAddr + 0x0A);
        if (((unsigned)major << 8) + minor < 0x200) {
            LastError = 16;
            return 3;
        }
    }
    dsp_write(0xD1);

    vec = (unsigned)IRQ + 8;
    regs.x.ax = (unsigned short)(0x3500 + vec);
    dqb_int386x(0x21, &regs, &regs, &sregs);
    OldIRQoff = regs.x.bx;
    OldIRQseg = sregs.es;
    _disable();
    outp(0x21, inp(0x21) & PicANDmask);
    regs.x.ax = (unsigned short)(0x2500 + vec);
    regs.x.dx = FP_OFF(sb_mix_isr);
    sregs.ds = FP_SEG(sb_mix_isr);
    dqb_int386x(0x21, &regs, &regs, &sregs);
    _enable();
    outp(0x21, inp(0x21) & PicANDmask);
    setup_dma();
    SoundActive = 1;
    return 0;
}

void DQBAPI DQBplaySound(int soundNum, int voice, int freq, int loopFlag)
{
    unsigned long rate, rem;
    int v;

    if (!SoundActive || soundNum < 1 || soundNum > (int)NumSounds)
        return;
    v = voice - 1;
    if (v < 0 || v >= MAX_VOICES)
        return;
    if (!VoiceSound[v])
        Playing++;
    VoiceSound[v] = (unsigned short)soundNum;
    VoiceLoopEnd[v] = SoundLen[soundNum - 1];
    VoiceLoopLen[v] = SoundLen[soundNum - 1];
    VoiceLoop[v] = (unsigned short)loopFlag;
    SamplePtr[v] = 0;
    Counter[v] = 0;
    rate = SamplingRate ? SamplingRate : 1;
    HighCount[v] = (unsigned short)((unsigned)freq / rate);
    rem = (unsigned long)((unsigned)freq % rate);
    LowCount[v] = (unsigned short)((rem << 16) / rate);
}

void DQBAPI DQBstopVoice(int voice)
{
    int v = voice - 1;

    if (v < 0 || v >= MAX_VOICES)
        return;
    if (VoiceSound[v]) {
        Playing--;
        VoiceSound[v] = 0;
    }
}

void DQBAPI DQBremoveSB(void)
{
    union REGS regs;
    struct SREGS sregs;
    unsigned vec;

    if (!SoundActive)
        return;
    if (VolSeg) {
        regs.h.ah = 0x49;
        sregs.es = VolSeg;
        dqb_int386x(0x21, &regs, &regs, &sregs);
        VolSeg = 0;
        VolActive = 0;
    }
    outp(BaseAddr + 6, 1);
    inp(BaseAddr + 6);
    inp(BaseAddr + 6);
    inp(BaseAddr + 6);
    inp(BaseAddr + 6);
    outp(BaseAddr + 6, 0);
    wait_read_dsp((unsigned short)(BaseAddr + 0x0E));
    (void)inp(BaseAddr + 0x0A);
    outp(0x21, inp(0x21) | PicORmask);
    vec = (unsigned)IRQ + 8;
    regs.x.ax = (unsigned short)(0x2500 + vec);
    regs.x.dx = OldIRQoff;
    sregs.ds = OldIRQseg;
    dqb_int386x(0x21, &regs, &regs, &sregs);
    SoundActive = 0;
}

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
