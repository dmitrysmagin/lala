/* palprobe.c - isolate the empty-palette bug at the ASM boundary.
 * Prefills DGROUP buffers with 0xAA, runs both loadImage call shapes,
 * logs rc/w/h and buffer head. Runs with bin/ as C:, writes PALPROBE.TXT.
 * Build: wmake palprobe (opt-in target, not part of wmake all). */
#include <stdio.h>
#include "directqb.h"

static char pal[768];
static char pal2[768];
static int dw, dh;
static int w, h;

int main(void)
{
    int i, rc;
    FILE *log;
    for (i = 0; i < 768; i++) {
        pal[i] = (char)0xAA;
        pal2[i] = (char)0xAA;
    }
    log = fopen("PALPROBE.TXT", "wt");
    if (!log)
        return 1;
    rc = DQBinit(5, 11, 0);
    fprintf(log, "init=%d\n", rc);
    rc = DQBloadImage(3, 0, 0, "GFX\\TITLE.PCX", pal, &w, &h);
    fprintf(log, "wrapper rc=%d w=%d h=%d\n", rc, w, h);
    fprintf(log, "pal=");
    for (i = 0; i < 16; i++)
        fprintf(log, " %d", (unsigned char)pal[i]);
    fprintf(log, "\n");
    rc = xDQBloadImage(3, 0, 0, "GFX\\BACKDROP.PCX", pal2, &dw, &dh);
    fprintf(log, "xload rc=%d w=%d h=%d\n", rc, dw, dh);
    fprintf(log, "pal2=");
    for (i = 0; i < 16; i++)
        fprintf(log, " %d", (unsigned char)pal2[i]);
    fprintf(log, "\n");
    DQBclose();
    fclose(log);
    return 0;
}
