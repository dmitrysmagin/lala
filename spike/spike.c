/* spike.c — PORTING.md Phase 0.
 *
 * Prove that OpenWatcom C (16-bit DOS) can call the original
 * Turbo Assembler DQB objects (dqb/BIT.OBJ, .MODEL medium,basic:
 * FAR procs, params pushed left-to-right, callee cleans stack).
 *
 * Expected values are game-realistic (engine.c clamps and cToIdx
 * shifts). QB TRUE is -1, hence DQBreadBit success == -1.
 *
 * Build: wcl -mm -s -zq -fe=spike\spike.exe spike\spike.c dqb\BIT.OBJ
 * Run in DOSBox (mounts spike/ as C:); writes RESULT.TXT.
 * Exit code = number of failed checks (0 = PASS).
 */
#include <stdio.h>

/* BASIC-convention FAR functions living in dqb/BIT.OBJ */
extern int __far __pascal DQBshiftLeft(int value, int nbits);
extern int __far __pascal DQBshiftRight(int value, int nbits);
extern int __far __pascal DQBsetBit(int value, int bit);
extern int __far __pascal DQBreadBit(int value, int bit);

static int fails = 0;

static void check(FILE *rep, const char *name, int got, int want)
{
    int ok = (got == want);
    fprintf(rep, "%-16s got %6d want %6d %s\n",
            name, got, want, ok ? "ok" : "FAIL");
    printf("%-16s got %6d want %6d %s\n",
           name, got, want, ok ? "ok" : "FAIL");
    if (!ok)
        fails++;
}

int main(void)
{
    FILE *rep = fopen("RESULT.TXT", "wt");
    if (!rep)
        rep = stdout;

    fprintf(rep, "DQB link spike\n");
    printf("DQB link spike\n");

    check(rep, "SL(1,6)", DQBshiftLeft(1, 6), 64);
    check(rep, "SL(5,6)", DQBshiftLeft(5, 6), 320);
    check(rep, "SL(19,10)", DQBshiftLeft(19, 10), 19456);
    check(rep, "SL(100,2)", DQBshiftLeft(100, 2), 400);
    check(rep, "SL(7,0)", DQBshiftLeft(7, 0), 7);
    check(rep, "SL(0,3)", DQBshiftLeft(0, 3), 0);
    check(rep, "SR(19456,6)", DQBshiftRight(19456, 6), 304);
    check(rep, "SR(11264,10)", DQBshiftRight(11264, 10), 11);
    check(rep, "SR(255,1)", DQBshiftRight(255, 1), 127);
    check(rep, "SR(100,2)", DQBshiftRight(100, 2), 25);
    check(rep, "SETBIT(0,3)", DQBsetBit(0, 3), 8);
    check(rep, "READBIT(8,3)", DQBreadBit(8, 3), -1);
    check(rep, "READBIT(8,2)", DQBreadBit(8, 2), 0);

    fprintf(rep, fails ? "SPIKE: FAIL (%d)\n" : "SPIKE: PASS\n", fails);
    printf(fails ? "SPIKE: FAIL (%d)\n" : "SPIKE: PASS\n", fails);

    if (rep != stdout)
        fclose(rep);
    return fails;
}
