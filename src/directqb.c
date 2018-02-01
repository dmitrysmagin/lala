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