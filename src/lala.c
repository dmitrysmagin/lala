#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "directqb.h"
#include "engine.h"
#include "fmengine.h"
#include "debug.h"

/* Staging buffers: DQB string params must be DGROUP (literals/globals),
 * never stack. Title/ending art + palettes are used synchronously. */
static char pal[768];
static char prCh[2];

static const char *endingText[8] = {
    "YOU DID IT!", "GOT ALL THE", "POTIONS...", "WELL DONE!",
    "BUT THERE'S", "STILL MUCH", "TO DO!", "SEE YOU SOON!"
};

static void showEnding(void);
static int showTitle(void);

int main(int argc, char *argv[])
{
    int i, a;

    /* File log first: everything below is traced to LOG.TXT. */
    dbgInit();
    DBG(("main: start argc=%d", argc));

    /* Debug switch: --no-sound shuts the SoundBlaster AND the AdLib
     * off completely (no DQBinstallSB/loadSound, no FMinit/FMload), so
     * the game can be run with/without sound while investigating
     * memory corruption. DQBinit's voice count stays 11 — only the
     * devices are disabled. */
    for (a = 1; a < argc; a++) {
        if (strcmp(argv[a], "--no-sound") == 0)
            g_noSound = 1;
    }
    if (g_noSound) {
        printf("--no-sound: SoundBlaster + AdLib DISABLED\n");
        DBG(("main: --no-sound ON"));
    }

    if (!g_noSound) {
        printf("INITALIZING OPL3 LIBRARY\n");
        i = FMinit();
        DBG(("FMinit -> %d", i));
    } else {
        DBG(("FMinit skipped (--no-sound)"));
    }

    /* Init DirectQB for 4 layers */
    printf("INITIALIZING DIRECTQB\n");
    i = DQBinit(5, 11, 0);
    DBG(("DQBinit -> %d", i));
    if (i) {
        printf("DIRECTQB FATAL ERROR!\n");
        /* PRINT DQBerror$ (skipped: BC-compiled, see PORTING.md) */
        exit(1);
    }

    /* Load font */
    printf("LOADING FONT\n");
    i = xDQBloadFont("GFX\\LALA.FNT");
    DBG(("loadFont -> %d", i));
    if (i)    {
        printf("ERROR LOADING FONT!\n");
        DQBclose();
        exit(1);
    }

    /* Install Soundblaster */
    if (g_noSound) {
        printf("SKIPPING SOUNDBLASTER + SOUNDS (--no-sound)\n");
        DBG(("SB + sounds skipped (--no-sound)"));
    } else {
        printf("INSTALLING SOUNDBLASTER DRIVER\n");
        i = DQBinstallSB(0, 6, 11025, AUTO, AUTO, AUTO);
        DBG(("installSB -> %d", i));
        if (i) {
            printf("ERROR SETTING UP SOUNDBLASTER!\n");
            DQBclose();
            exit(1);
        }

        /* Load sounds */
        printf("LOADING SOUNDS\n");
        i = xDQBloadSound(8, "SFX\\AH.WAV");
        i |= xDQBloadSound(1, "SFX\\BOLT.WAV");
        i |= xDQBloadSound(2, "SFX\\HIT.WAV");
        i |= xDQBloadSound(3, "SFX\\JUMP.WAV");
        i |= xDQBloadSound(4, "SFX\\KEY.WAV");
        i |= xDQBloadSound(5, "SFX\\LIFE.WAV");
        i |= xDQBloadSound(6, "SFX\\OBJECT.WAV");
        i |= xDQBloadSound(7, "SFX\\PINCHE.WAV");
        i |= xDQBloadSound(9, "SFX\\AMBIENT1.WAV");
        i |= xDQBloadSound(10, "SFX\\AMBIENT2.WAV");
        DBG(("loadSounds -> %d", i));

        if (i) {
            printf("ERROR LOADING SOUNDS!\n");
            DQBclose();
            exit(1);
        }
    }

    /* Install keyboard */
    printf("INSTALLING KEYBOARD HANDLER\n");
    DQBinstallKeyboard();
    DBG(("installKeyboard"));

    /* Init game */
    printf("INITIALIZING GAME\n");

    DBG(("engineInitVals"));
    engineInitVals();
    /* engineLoadPrefs(0): QB copies prefsStore(0) into prefs; our
     * engineInitVals writes prefs directly, nothing to copy. */
    DBG(("loadTileProperties"));
    engineLoadTileProperties();
    DBG(("loadTileset"));
    engineLoadTileset();
    DBG(("loadSpriteProperties"));
    engineLoadSpriteProperties();
    DBG(("loadSpriteset"));
    engineLoadSpriteset();
    DBG(("loadSpriteMapping"));
    engineLoadSpriteMapping();

    DBG(("initVGA"));
    DQBfadeTo(0, 0, 0);
    DQBinitVGA();

    /* Load blender map.
     * This blender map has been created for colours 254 (white) and
     * 255 (black). This way you can easily create nifty
     * "darken"/"brighten" effects easily. */
    /* dummy& = SETMEM(-513) of LALA.BAS: replaced by the makefile's
     * wcl -k16384 stack directive (Watcom far heap is DOS-on-demand,
     * see PORTING.md §2) */
    i = DQBcreateBMap(1, 254, 255);
    DBG(("createBMap -> %d", i));

    if (i) {
        DQBinitText();
        printf("ERROR creating blender map\n");
        DQBclose();
        exit(1);
    }

    i = xDQBloadBMap(1, "GFX\\LALA.BMA");
    DBG(("loadBMap -> %d", i));
    if (i) {
        DQBinitText();
        printf("ERROR loading blender map\n");
        DQBclose();
        exit(0);
    }

    /* Loop */
    do {
        int r;
        DBG(("loop: engineInitGame"));
        engineInitGame();
        DBG(("loop: showTitle"));
        i = showTitle();
        DBG(("loop: showTitle -> %d", i));
        if (i) {
            xDQBsetPal(prefs.pal);
            DBG(("loop: engineDoGame(-1)"));
            r = engineDoGame(-1);
            DBG(("loop: engineDoGame -> %d", r));
            if (r == -1) {
                DBG(("loop: showEnding"));
                showEnding();
                DBG(("loop: showEnding done"));
            }
        }
    } while (i);

    DQBinitText();
    DQBremoveKeyboard();
    DQBclose();

    /* FMend restores the PIT hook FMinit installed — never call it
     * when FMinit was skipped (--no-sound), it would scribble the IVT. */
    if (!g_noSound)
        FMend();

    DBG(("main: clean exit"));
    return 0;
}

static void showEnding(void)
{
    int w, h, d, k, i, x, y, j, ti = 0;
    DBG(("showEnding: enter"));
    DQBloadImage(3, 0, 0, "GFX\\ENDING.PCX", pal, &w, &h);
    DQBclearLayer(VIDEO);
    DQBpalOff();
    DQBcopyLayer(3, 1);
    if (!g_noSound)
        FMload("MUSIC\\MC12.S3M");
    xDQBsetPal(pal);

    DQBcopyLayer(1, VIDEO);
    for (d = 1; d <= 32; d++)
        DQBwait(1);

    /* Here */
    for (k = 1; k <= 2; k++) {
        DQBcopyLayer(3, 1);
        DQBfilterBox(1, 16, 16, 135, 95, 255, 1);
        DQBbox(1, 16, 16, 135, 95, 254);
        y = 24;
        for (i = 1; i <= 4; i++) {
            const char *text = endingText[ti++];
            x = 24;
            for (j = 0; text[j]; j++) {
                prCh[0] = text[j];
                prCh[1] = 0;
                DQBprint(1, prCh, x - 1, y - 1, 255);
                DQBprint(1, prCh, x, y, 254);
                for (d = 1; d <= 8; d++)
                    DQBwait(1);
                DQBcopyLayer(1, VIDEO);
                x += 8;
            }
            y += 16;
            if (i == 3)
                y += 8;
        }
        for (d = 1; d <= 120; d++)
            DQBwait(1);
    }

    while (xDQBinkey())
        ;
    while (!xDQBinkey())
        ;

    /* PLAY STOP */
    if (!g_noSound) {
        FMstop();
        BeSilent();
    }
    DQBclearLayer(VIDEO);
    DBG(("showEnding: done"));
}

static int showTitle(void)
{
    /* QB's flag% param is unused (always runs the demo game); dropped. */
    int w, h, r;
    DBG(("showTitle: enter"));
    DQBclearLayer(VIDEO);
    DQBpalOff();

    if (DQBloadImage(3, 0, 0, "GFX\\TITLE.PCX", pal, &w, &h)) {
        DBG(("showTitle: TITLE.PCX load FAILED"));
        DQBinitText();
        DQBclose();
        printf("ERROR!");
    }

    if (!g_noSound)
        FMload("MUSIC\\G66A.S3M");
    xDQBsetPal(pal);
    r = engineDoGame(0);
    /* PLAY STOP */
    if (!g_noSound) {
        FMstop();
        BeSilent();
    }

    DQBclearLayer(VIDEO);

    DBG(("showTitle: exit r=%d", r));
    return r;
}
