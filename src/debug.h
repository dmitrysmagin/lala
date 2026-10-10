/* debug.h — file logger for DOSBox runs (console capture is unreliable
 * there): events go to LOG.TXT on C:, flushed after every line so a
 * crash or hang still leaves a trail up to the last logged event.
 *
 * Header-only on purpose: each .c that includes it gets its own static
 * handle, opened in APPEND mode ("at") — Watcom positions the file at
 * EOF before every write, so the lala.c and engine.c handles cannot
 * clobber each other's lines. Only lala.c calls dbgInit(), which starts
 * a fresh log by deleting the previous run's file first; the engine's
 * handle opens lazily on its first DBG.
 *
 * Line format:  <BIOS ticks, 18.2 Hz> <DGROUP DS> | <message>
 *
 * Usage (double parentheses — C89 has no variadic macros):
 *   DBG(("init: DQBinit -> %d", rc));
 *
 * Logging must never break the game: if LOG.TXT can't be opened, all
 * calls silently do nothing.
 */
#ifndef _DEBUG_H_
#define _DEBUG_H_

#include <stdio.h>
#include <stdarg.h>
#include <i86.h>    /* MK_FP, FP_SEG */

/* Far pointer as seg:off — for logging far-allocation addresses. */
#define DBG_SEG(p) ((unsigned)((unsigned long)(void __far *)(p) >> 16))
#define DBG_OFF(p) ((unsigned)((unsigned long)(void __far *)(p)))

/* dbgLog: one fopen + fclose PER LINE. Opening and closing for every
 * line is slow, but these events are rare -- and it is the only way to
 * make the trail kill-proof: DOSBox flushes its host buffers on close,
 * so every returned call is already durable when the game later hangs
 * or is killed. A closed/stolen DOS handle can only eat the single
 * in-flight line, never the whole session (and each call re-opens). */
static unsigned long dbgTick(void)
{
    /* BIOS tick counter at 0040:006C, ~18.2 Hz. */
    return *(volatile unsigned long __far *)MK_FP(0x40, 0x6C);
}

static void dbgLog(const char *fmt, ...)
{
    va_list ap;
    int ok;
    FILE *f = fopen("LOG.TXT", "at");
    if (!f)
        return;
    fprintf(f, "%8lu %04X | ", dbgTick(), FP_SEG(&f));
    va_start(ap, fmt);
    ok = vfprintf(f, fmt, ap);
    va_end(ap);
    if (ok >= 0)
        (void)fprintf(f, "\n");
    fclose(f);
}

/* Start a fresh log — call once at the top of lala.c's main(). */
#define dbgInit() (remove("LOG.TXT"))

#define DBG(msg) dbgLog msg

#endif /* _DEBUG_H_ */
