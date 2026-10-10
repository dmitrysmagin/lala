/* dqb_int.h — shared DirectQB state and internal helpers (C port). */
#ifndef DQB_INT_H
#define DQB_INT_H

#include <dos.h>

void dqb_int386(int num, union REGS *in, union REGS *out);
void dqb_int386x(int num, union REGS *in, union REGS *out, struct SREGS *sregs);

#define DQBAPI __far __pascal

#define DQB_SCREEN_W 320
#define DQB_SCREEN_H 200
#define DQB_LAYER_BYTES (DQB_SCREEN_W * DQB_SCREEN_H)

extern unsigned char LibActive;
extern unsigned char EMMid[9];
extern unsigned short EMSseg;
extern unsigned short EMShdl;
extern unsigned short EMSpage;
extern unsigned short EMSallocated;
extern unsigned short DataPage;
extern unsigned short BaseLayer[10];
extern unsigned char BaseSet[10];
extern unsigned char VGAon;
extern unsigned short PutMode;
extern unsigned short ClipX1, ClipX2, ClipY1, ClipY2;
extern unsigned char FontBuffer[2048];
extern unsigned char CharLen[257];
extern unsigned char BMapActive[10];
extern unsigned short BMapSeg[10];
extern unsigned char BMapFirst[10];
extern unsigned char BMapLast[10];
extern unsigned char Buffer;
extern unsigned char KeyActive;
extern unsigned short OldInt9seg, OldInt9off;
extern unsigned char KeyFlags;
extern unsigned char KeyStatus[128];
extern unsigned char MouseDetected;
extern unsigned char SoundActive;
extern unsigned short SoundPage;
extern unsigned char NumSounds;
extern unsigned short SoundLen[256];
extern unsigned char VolActive;
extern unsigned short VolSeg;
extern unsigned short BaseAddr;
extern unsigned char IRQ;
extern unsigned char PicORmask;
extern unsigned short OldIRQseg, OldIRQoff;
extern unsigned short OldInt24seg, OldInt24off;
extern unsigned char LastError;

/* ASM sound module entry points (SOUND.ASM). */
extern unsigned char DMA;
extern unsigned char PicANDmask;
extern unsigned short DMA_Page, DMA_Base, DMA_Count;
extern unsigned short SamplingRate;
extern unsigned short Channels;

/* Called from SOUND.ASM — must match .MODEL medium,basic names. */
void __far MapEMS(unsigned short page);
int __far ReadBuffer(void);
void __far HookInt24(void);
void __far UnhookInt24(void);

#define dqb_layer_offset(x, y) ((unsigned short)((y) * DQB_SCREEN_W + (x)))

unsigned short dqb_get_layer_seg(unsigned layer);
void dqb_map_ems(unsigned page);
void dqb_hook_int24(void);
void dqb_unhook_int24(void);

#endif
