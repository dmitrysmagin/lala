#include <stdio.h>
#include <stdlib.h>

#include "directqb.h"
#include "engine.h"
#include "fmengine.h"

/*
DECLARE SUB showEnding ()
DECLARE FUNCTION showTitle% (prefs AS ANY, tileProperties() AS ANY, spriteProperties() AS ANY, tileset%(), spriteset%(), spriteMapping%(), flag%)

DIM tileset%(0, 0)
DIM spriteset%(0, 0)
DIM spriteProperties(0) AS TypeSpriteProperties
DIM spriteMapping%(0)
*/

#undef main
int main(void)
{
/*
PRINT "INITALIZING OPL3 LIBRARY"
i% = FMinit

' Init DirectQB for 4 layers
PRINT "INITIALIZING DIRECTQB"
i% = DQBinit(5, 11, 0)
IF i% <> 0 THEN
    PRINT "DIRECTQB FATAL ERROR!"
    PRINT DQBerror$
    SYSTEM
END IF
' Load font
PRINT "LOADING FONT"
i% = DQBloadFont("GFX\LALA.FNT")
IF i% <> 0 THEN
    PRINT "ERROR LOADING FONT!"
    PRINT DQBerror$
    DQBclose
    SYSTEM
END IF
' Install Soundblaster
PRINT "INSTALLING SOUNDBLASTER DRIVER"
i% = DQBinstallSB(0, 6, 11025, AUTO, AUTO, AUTO)
IF i% <> 0 THEN
    PRINT "ERROR SETTING UP SOUNDBLASTER!"
    PRINT DQBerror$
    DQBclose
    SYSTEM
END IF
' Load sounds
PRINT "LOADING SOUNDS"
i% = DQBloadSound(8, "SFX\AH.WAV")
i% = i% OR DQBloadSound(1, "SFX\BOLT.WAV")
i% = i% OR DQBloadSound(2, "SFX\HIT.WAV")
i% = i% OR DQBloadSound(3, "SFX\JUMP.WAV")
i% = i% OR DQBloadSound(4, "SFX\KEY.WAV")
i% = i% OR DQBloadSound(5, "SFX\LIFE.WAV")
i% = i% OR DQBloadSound(6, "SFX\OBJECT.WAV")
i% = i% OR DQBloadSound(7, "SFX\PINCHE.WAV")
i% = i% OR DQBloadSound(9, "SFX\AMBIENT1.WAV")
i% = i% OR DQBloadSound(10, "SFX\AMBIENT2.WAV")
IF i% <> 0 THEN
    PRINT "ERROR LOADING SOUNDS!"
    PRINT DQBerror$
    DQBclose
    SYSTEM
END IF
' Install keyboard
PRINT "INSTALLING KEYBOARD HANDLER"
DQBinstallKeyboard

' Init game

PRINT "INITIALIZING GAME"
*/
	engineInitVals();
	engineLoadTileProperties();
/*
engineLoadTileset tileset%(), prefs
engineLoadSpriteProperties spriteProperties(), prefs
engineLoadSpriteset spriteset%(), prefs
engineLoadSpriteMapping spriteMapping%(), prefs

DQBfadeTo 0, 0, 0
DQBinitVGA

' Load blender map
' This blender map has been created for colours 254 (white) and 255 (black).
' This way you can easily create nifty "darken"/"brighten" effects easily.
dummy& = SETMEM(-513)
i% = DQBcreateBMap(1, 254, 255)
IF i% THEN DQBinitText: PRINT "ERROR creating blender map"; DQBerror$: DQBclose: SYSTEM
i% = DQBloadBMap(1, "GFX\LALA.BMA")
IF i% THEN DQBinitText: PRINT "ERROR loading blender map"; DQBerror$: DQBclose: SYSTEM

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

DQBinitText
DQBremoveKeyboard
DQBclose

FMend

COLOR 15
SYSTEM
*/
	return 0;
}

/*
endingText:
DATA "YOU DID IT!", "GOT ALL THE", "POTIONS...", "WELL DONE!"
DATA "BUT THERE'S", "STILL MUCH", "TO DO!", "SEE YOU SOON!"

REM $DYNAMIC
SUB calcEnemsFrame (enems() AS TypeEnems, spriteMapping%())

END SUB

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
