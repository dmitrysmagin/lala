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

static FILE *dbgF = 0;    /* this translation unit's handle */

static unsigned long dbgTick(void)
{
    /* BIOS tick counter at 0040:006C, ~18.2 Hz. */
    return *(volatile unsigned long __far *)MK_FP(0x40, 0x6C);
}

static void dbgLog(const char *fmt, ...)
{
    va_list ap;
    int ok, retried = 0;

    for (;;) {
        if (!dbgF)
            dbgF = fopen("LOG.TXT", "at");
        if (!dbgF)
            return;
        fprintf(dbgF, "%8lu %04X | ", dbgTick(), FP_SEG(&dbgF));
        va_start(ap, fmt);
        ok = vfprintf(dbgF, fmt, ap);
        va_end(ap);
        if (ok >= 0)
            ok = fprintf(dbgF, "\n");
        if (ok >= 0)
            ok = fflush(dbgF);
        if (ok >= 0)
            return;
        /* Write failed — our DOS handle may have been closed by foreign
         * code (exactly the class of bug this log hunts). Reopen once
         * and retry the line, so the trail survives the event. */
        fclose(dbgF);
        dbgF = 0;
        if (retried)
            return;
        retried = 1;
    }
}

/* Start a fresh log — call once at the top of lala.c's main(). */
#define dbgInit() \
    do { \
        remove("LOG.TXT"); \
        if (!dbgF) \
            dbgF = fopen("LOG.TXT", "at"); \
    } while (0)

#define DBG(msg) dbgLog msg

#endif /* _DEBUG_H_ */
