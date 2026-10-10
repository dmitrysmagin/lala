/* globals.c — DirectQB library state (was MAIN.ASM .DATA + SOUND shared). */
#include "dqb_int.h"

unsigned short LibVersion = 0x013D;
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
unsigned char JoyDetected[2];
unsigned short JoySens = 40;
unsigned short JoyX[2], JoyY[2], JoyCX[2], JoyCY[2];
unsigned char JoyButA[2], JoyButB[2];
unsigned char JoyMask[8] = {0x01, 0x02, 0x10, 0x20, 0x04, 0x08, 0x40, 0x80};
unsigned char MouseDetected;
unsigned char MouseOn;
unsigned short MouseX, MouseY;
unsigned char MouseBut;
unsigned char MouseShape[64] = {
    0xFF, 0x3F, 0xFF, 0x1F, 0xFF, 0x0F, 0xFF, 0x07,
    0xFF, 0x03, 0xFF, 0x01, 0xFF, 0x00, 0x7F, 0x00,
    0x3F, 0x00, 0x7F, 0x00, 0xFF, 0x0F, 0xFF, 0xBF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x00, 0x00, 0x00, 0x40, 0x00, 0x60, 0x00, 0x70,
    0x00, 0x78, 0x00, 0x7C, 0x00, 0x7E, 0x00, 0x7F,
    0x80, 0x7F, 0x00, 0x70, 0x00, 0x40, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};
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
unsigned char TimerActive;
unsigned char TimerFlag;
unsigned long TimerCount;
unsigned long ElapsedTicks;
unsigned long OldInt8;
unsigned char FLIactive;
unsigned short FLIfile;
unsigned short FLIbufSeg;
unsigned char PackActive;
unsigned short PackFile;
unsigned char TextMode;
unsigned char TextBackCol;
unsigned short CharSpacing;
unsigned char FontTexture[64] = {
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,
    15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15
};
unsigned char TextureX, TextureY;
unsigned short TextBMap = 1;
unsigned char BMapOff;
unsigned char ColMethod;
short SinTable[256] = {
    256,256,256,255,255,254,253,252,251,250,248,247,245,243,241,239,237,234,231,229,226,223,220,216,213,209,206,202,198,194,190,185,
    181,177,172,167,162,157,152,147,142,137,132,126,121,115,109,104,98,92,86,80,74,68,62,56,50,44,38,31,25,19,13,6,
    0,-6,-13,-19,-25,-31,-38,-44,-50,-56,-62,-68,-74,-80,-86,-92,-98,-104,-109,-115,-121,-126,-132,-137,-142,-147,-152,-157,-162,-167,-172,-177,
    -181,-185,-190,-194,-198,-202,-206,-209,-213,-216,-220,-223,-226,-229,-231,-234,-237,-239,-241,-243,-245,-247,-248,-250,-251,-252,-253,-254,-255,-255,-256,-256,
    -256,-256,-256,-255,-255,-254,-253,-252,-251,-250,-248,-247,-245,-243,-241,-239,-237,-234,-231,-229,-226,-223,-220,-216,-213,-209,-206,-202,-198,-194,-190,-185,
    -181,-177,-172,-167,-162,-157,-152,-147,-142,-137,-132,-126,-121,-115,-109,-104,-98,-92,-86,-80,-74,-68,-62,-56,-50,-44,-38,-31,-25,-19,-13,-6,
    0,6,13,19,25,31,38,44,50,56,62,68,74,80,86,92,98,104,109,115,121,126,132,137,142,147,152,157,162,167,172,177,
    181,185,190,194,198,202,206,209,213,216,220,223,226,229,231,234,237,239,241,243,245,247,248,250,251,252,253,254,255,255,256,256
};
unsigned char TextureLen = 6;
unsigned short TextureFix = 63;
EMSmoveStruc EMSmove;
