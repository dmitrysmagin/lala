/* directqb.c — the two wrappers with real added value.
 *
 * Everything else in directqb.h binds the lib directly (__pascal).
 * DQBloadImage stages stack int locals through DGROUP statics because
 * xDQBloadImage stores imgW/imgH through DS (stack locals are SS).
 * DQBprint supplies style = 0 (DQBprints is unused by the game).
 */
#include "directqb.h"

/* xDQBloadImage writes imgW/imgH through NEAR pointers using DS, so they
 * must be DGROUP-resident; callers pass stack locals, hence staging. */
static int stagedW, stagedH;

int DQBloadImage(int layer, int x, int y, const char __far *file, void __far *pal, int *imgW, int *imgH)
{
    int rc = xDQBloadImage(layer, x, y, (char __far *)file,
        (char __far *)pal, &stagedW, &stagedH);
    if (imgW)
        *imgW = stagedW;
    if (imgH)
        *imgH = stagedH;
    return rc;
}

void DQBprint(int layer, const char __far *text, int x, int y, int col)
{
    xDQBprint(layer, (char __far *)text, x, y, col, 0);
}
