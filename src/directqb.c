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

void DQBclose()
{
}
