/* testmain.c — entry point for the headless self-test binary.
 * Built as bin\test.exe (runs with bin/ mounted as C:). */
#include <stdio.h>

int engtest_run(void);

int main(void)
{
	return engtest_run();
}
