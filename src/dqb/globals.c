/* globals.c — DirectQB library state (was MAIN.ASM .DATA + SOUND shared). */
#include "dqb_int.h"

unsigned char LibActive;
unsigned char EMMid[9] = "EMMXXXX0";
unsigned short EMSseg;
unsigned short EMShdl;
unsigned short EMSpage;
unsigned short EMSallocated;
unsigned short DataPage;
unsigned short BaseLayer[10];
unsigned char BaseSet[10];
unsigned char VGAon;
unsigned short PutMode;
unsigned short ClipX1, ClipX2 = 319, ClipY1, ClipY2 = 199;
unsigned char FontBuffer[2048];
unsigned char CharLen[257];
unsigned char BMapActive[10];
unsigned short BMapSeg[10];
unsigned char BMapFirst[10];
unsigned char BMapLast[10];
unsigned char Buffer;
unsigned char KeyActive;
unsigned short OldInt9seg, OldInt9off;
unsigned char KeyFlags;
unsigned char KeyStatus[128];
unsigned char MouseDetected;
unsigned char SoundActive;
unsigned short SoundPage;
unsigned char NumSounds;
unsigned short SoundLen[256];
unsigned char VolActive;
unsigned short VolSeg;
unsigned short BaseAddr = 0x0220;
unsigned char IRQ = 7;
unsigned char PicORmask;
unsigned short OldIRQseg;
unsigned short OldIRQoff;
unsigned short OldInt24seg, OldInt24off;
unsigned char LastError = 29;

unsigned char DMA = 1;
unsigned char PicANDmask;
unsigned short DMA_Page, DMA_Base, DMA_Count;
unsigned short SamplingRate = 22050;
unsigned short Channels = 8;
