/* musplay.c — minimal S3M player: proves the FMENGINE port plays music.
 * Usage: musplay [SONG] [SECONDS]   (defaults: MUSIC\G66A.S3M, 10)
 * Runs with bin/ mounted as C:. Logs position + OPL write counts to
 * MUSPLAY.TXT, so headless runs still prove progression and sounding.
 * Self-timed via the ISR tick counter (no DQB dependency).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fmengine.h"

int main(int argc, char *argv[])
{
	static char songbuf[64];
	const char *song = "MUSIC\\G66A.S3M";
	int secs = 10;
	FILE *log;
	unsigned long start, target, next, w0, w1;
	int s, lastrow = -1;

	if (argc > 1) {
		strncpy(songbuf, argv[1], 63);
		songbuf[63] = 0;
		song = songbuf;
	}
	if (argc > 2)
		secs = atoi(argv[2]);

	log = fopen("MUSPLAY.TXT", "wt");
	if (!log)
		return 1;
	fprintf(log, "musplay %s %ds\n", song, secs);

	if (!FMinit()) {
		fprintf(log, "FAIL init\n");
		fclose(log);
		return 1;
	}
	fprintf(log, "ok init\n");

	FMload(song);
	fprintf(log, "song ord=%d ins=%d pat=%d A=%d T=%d o0=%d\n",
		fmdata.ordnum, fmdata.insnum, fmdata.patnum,
		fmdata.effectA, fmdata.effectT, order[0]);
	fflush(log);

	start = fm_ticks;
	target = start + (unsigned long)secs * 25UL;
	next = start + 25;
	w0 = fm_writes;
	for (s = 0; s < secs; s++) {
		int row;
		while (fm_ticks < next)
			;
		next += 25;
		row = fmdata.CurOrd * 64 + fmdata.CurRow;
		w1 = fm_writes;
		fprintf(log, "sec %d row=%d writes=%lu (+%lu)%s\n",
			s + 1, row, w1, w1 - w0,
			row != lastrow ? "" : " (STALLED?)");
		fflush(log);
		lastrow = row;
		w0 = w1;
	}
	while (fm_ticks < target)
		;

	FMend();
	fprintf(log, "MUSPLAY: DONE row=%d writes=%lu\n",
		fmdata.CurOrd * 64 + fmdata.CurRow, fm_writes);
	fclose(log);
	return 0;
}
