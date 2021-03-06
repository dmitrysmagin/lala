#include <stdio.h>
#include <stdlib.h>

#include "directqb.h"
#include "engine.h"
#include "fmengine.h"

/*
DECLARE SUB showEnding ()
DECLARE FUNCTION showTitle% (prefs AS ANY, tileProperties() AS ANY, spriteProperties() AS ANY, tileset%(), spriteset%(), spriteMapping%(), flag%)
*/

#undef main
int main(void)
{
	int i;

	printf("INITALIZING OPL3 LIBRARY\n");
	//i = FMinit();

	// Init DirectQB for 4 layers
	printf("INITIALIZING DIRECTQB\n");
	i = DQBinit(5, 11, 0);
	if (i) {
		printf("DIRECTQB FATAL ERROR!\n");
		//PRINT DQBerror$
		exit(1);
	}

	// Load font
	printf("LOADING FONT\n");
	i = DQBloadFont("GFX/LALA.FNT");
	if (i)	{
		printf("ERROR LOADING FONT!\n");
		//PRINT DQBerror$
		DQBclose();
		exit(1);
	}

	// Install Soundblaster
	printf("INSTALLING SOUNDBLASTER DRIVER\n");
	i = DQBinstallSB(0, 6, 11025, AUTO, AUTO, AUTO);
	if (i) {
		printf("ERROR SETTING UP SOUNDBLASTER!\n");
		//PRINT DQBerror$
		DQBclose();
		exit(1);
	}


	// Load sounds
	printf("LOADING SOUNDS\n");
	i = DQBloadSound(8, "SFX/AH.WAV");
	i |= DQBloadSound(1, "SFX/BOLT.WAV");
	i |= DQBloadSound(2, "SFX/HIT.WAV");
	i |= DQBloadSound(3, "SFX/JUMP.WAV");
	i |= DQBloadSound(4, "SFX/KEY.WAV");
	i |= DQBloadSound(5, "SFX/LIFE.WAV");
	i |= DQBloadSound(6, "SFX/OBJECT.WAV");
	i |= DQBloadSound(7, "SFX/PINCHE.WAV");
	i |= DQBloadSound(9, "SFX/AMBIENT1.WAV");
	i |= DQBloadSound(10, "SFX/AMBIENT2.WAV");

	if (i) {
		printf("ERROR LOADING SOUNDS!\n");
		//PRINT DQBerror$
		DQBclose();
		exit(1);
	}

	// Install keyboard
	printf("INSTALLING KEYBOARD HANDLER\n");
	DQBinstallKeyboard();

	// Init game
	printf("INITIALIZING GAME\n");

	engineInitVals();
	engineLoadTileProperties();

	engineLoadTileset();
	engineLoadSpriteProperties();
	engineLoadSpriteset();
	engineLoadSpriteMapping();

	//DQBfadeTo 0, 0, 0
	//DQBinitVGA

	// Load blender map
	// This blender map has been created for colours 254 (white) and 255 (black).
	// This way you can easily create nifty "darken"/"brighten" effects easily.
	i = DQBcreateBMap(1, 254, 255);

	if (i) {
		//DQBinitText();
		printf("ERROR creating blender map\n" /*DQBerror$*/);
		DQBclose();
		exit(1);
	}

	i = DQBloadBMap(1, "GFX/LALA.BMA");
	if (i) {
		//DQBinitText();
		printf("ERROR loading blender map\n" /*DQBerror$*/);
		DQBclose();
		exit(0);
	}

/*
' Loop
DO
    engineInitGame prefs
    i% = showTitle(prefs, tileProperties(), spriteProperties(), tileset%(), spriteset%(), spriteMapping%(), -1)
    IF i% THEN
        DQBsetPal prefs.pal
        r% = engineDoGame(prefs, tileProperties(), spriteProperties(), tileset%(), spriteset%(), spriteMapping%(), -1)
        IF r% = -1 THEN
            showEnding
        END IF
    END IF
LOOP WHILE i%
*/
	//DQBinitText();
	DQBremoveKeyboard();

	DQBclose();

	//FMend();

	return 0;
}

/*
endingText:
DATA "YOU DID IT!", "GOT ALL THE", "POTIONS...", "WELL DONE!"
DATA "BUT THERE'S", "STILL MUCH", "TO DO!", "SEE YOU SOON!"

REM $STATIC
SUB showEnding
    pal$ = SPACE$(768)
    i% = DQBloadImage(3, 0, 0, "GFX\ENDING.PCX", pal$, w%, x%)
    DQBclearLayer VIDEO
    DQBpalOff
    DQBcopyLayer 3, 1
    FMload "MUSIC\MC12.S3M"
    DQBsetPal pal$

    DQBcopyLayer 1, VIDEO
    FOR d% = 1 TO 32
        DQBwait 1
    NEXT d%

    ' Here
    RESTORE endingText
    FOR k% = 1 TO 2
        DQBcopyLayer 3, 1
        DQBfilterBox 1, 16, 16, 135, 95, 255, 1
        DQBbox 1, 16, 16, 135, 95, 254
        y% = 24
        FOR i% = 1 TO 4
            x% = 24
            READ text$
            FOR j% = 1 TO LEN(text$)
                DQBprint 1, MID$(text$, j%, 1), x% - 1, y% - 1, 255
                DQBprint 1, MID$(text$, j%, 1), x%, y%, 254
                FOR d% = 1 TO 8
                    DQBwait 1
                NEXT d%
                DQBcopyLayer 1, VIDEO
                x% = x% + 8
            NEXT j%
            y% = y% + 16
            IF i% = 3 THEN y% = y% + 8
        NEXT i%
        FOR d% = 1 TO 120
            DQBwait 1
        NEXT d%
    NEXT k%
   
    WHILE DQBinkey$ <> "": WEND
    WHILE DQBinkey$ = "": WEND

    PLAY STOP
    BeSilent
    DQBclearLayer VIDEO
END SUB

FUNCTION showTitle% (prefs AS TypePrefs, tileProperties() AS TypeTileProperties, spriteProperties() AS TypeSpriteProperties, tileset%(), spriteset%(), spriteMapping%(), flag%)
    DQBclearLayer VIDEO
    DQBpalOff
   
    pal$ = SPACE$(768)
    i% = DQBloadImage(3, 0, 0, "GFX\TITLE.PCX", pal$, w%, x%)
   
    IF i% THEN
        DQBinitText
        DQBclose
        PRINT "ERROR!"
    END IF

    FMload "MUSIC\G66A.S3M"
    DQBsetPal pal$
    r% = engineDoGame(prefs, tileProperties(), spriteProperties(), tileset%(), spriteset%(), spriteMapping%(), 0)
    PLAY STOP
    BeSilent

    DQBclearLayer VIDEO

    showTitle% = r%
END FUNCTION

*/
