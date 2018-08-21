/*
	Wrapper DirectQB => SDL :))
*/

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "directqb.h"

// DECLARE FUNCTION DQBinit% (BYVAL NumLayers%, BYVAL NumSounds%, BYVAL MemSize%)
int DQBinit(int NumLayers, int NumSounds, int MemSize)
{
	(void)NumLayers;
	(void)NumSounds;
	(void)MemSize;

	return 0;
}

// DECLARE SUB DQBclose ()
void DQBclose()
{
}

//DECLARE SUB DQBclearLayer (BYVAL Layer%)
void DQBclearLayer(int Layer)
{
}

//DECLARE SUB DQBwait (BYVAL Times%)
void DQBwait(int Times)
{
}

// Procedures from DRAW.OBJ:

//DECLARE SUB DQBget (BYVAL Layer%, BYVAL x1%, BYVAL y1%, BYVAL x2%, BYVAL y2%, BYVAL BufSeg%, BYVAL BufOff%)
void DQBget(int Layer, int x1, int y1, int x2, int y2, char **BufOff)
{
}

//DECLARE SUB DQBput (BYVAL Layer%, BYVAL x%, BYVAL y%, BYVAL BufSeg%, BYVAL BufOff%)
void DQBput (int Layer, int x, int y, char *BufOff)
{
}

// Procedures from IMAGE.OBJ:

// DECLARE FUNCTION DQBloadImage% (Layer%, x%, y%, FileName$, Pal$, imgWidth%, imgHeight%)
int DQBloadImage(int Layer, int x, int y, char *FileName, void *Pal, int *imgWidth, int *imgHeight)
{
	return 0;
}

// Procedures from FONT.OBJ:

// DECLARE FUNCTION DQBloadFont% (FileName$)
int DQBloadFont(char *FileName)
{
	return 0;
}

// Procedures from KEYBOARD.OBJ:

// DECLARE SUB DQBinstallKeyboard ()
void DQBinstallKeyboard()
{
}

void DQBremoveKeyboard()
{
}

// Procedures from BLENDING.OBJ:

//DECLARE FUNCTION DQBcreateBMap% (BYVAL BMap%, BYVAL FirstCol%, BYVAL LastCol%)
int DQBcreateBMap(int BMap, int FirstCol, int LastCol)
{
	return 0;
}
//DECLARE FUNCTION DQBloadBMap% (BMap%, FileName$)
int DQBloadBMap(int BMap, char *FileName)
{
	return 0;
}

// Procedures from SOUND.OBJ:

// DECLARE FUNCTION DQBinstallSB% (BYVAL VolActive%, BYVAL Channels%, BYVAL Freq%, BYVAL BaseAddr%, BYVAL IRQ%, BYVAL DMA%)
int DQBinstallSB(int VolActive, int Channels, int Freq, int BaseAddr, int IRQ, int DMA)
{
	return 0;
}

// DECLARE FUNCTION DQBloadSound% (Slot%, FileName$)
int DQBloadSound(int Slot, char *FileName)
{
	return 0;
}