/* joystick.c — JOYSTICK.ASM port (port 201h timing). */
#include "dqb_int.h"
#include <conio.h>
#include <dos.h>
#include <i86.h>

int DQBAPI DQBjoyDetected(int joyNum)
{
    int si = joyNum;

    if (si == 2)
        si = 0;
    return JoyDetected[si] ? -1 : 0;
}

void DQBAPI DQBpollJoy(int joyNum)
{
    unsigned char al;
    int di = joyNum;
    int si;
    unsigned char bl;
    unsigned cx;

    _disable();
    outp(0x201, 0);
    al = inp(0x201);
    if (di == 2) {
        si = 0;
        di = 0;
        JoyButA[0] = (al & JoyMask[2]) ? 0 : 1;
        JoyButB[0] = (al & JoyMask[3]) ? 0 : 1;
        JoyButA[1] = (al & JoyMask[6]) ? 0 : 1;
        JoyButB[1] = (al & JoyMask[7]) ? 0 : 1;
        bl = (unsigned char)(JoyMask[0] + JoyMask[1]);
        outp(0x201, al);
        for (cx = 0; cx < 65535u; cx++) {
            al = inp(0x201);
            if (al & JoyMask[0])
                JoyX[si] = (unsigned short)cx;
            if (al & JoyMask[1])
                JoyY[si] = (unsigned short)cx;
            if (!(al & bl))
                break;
        }
        _enable();
        return;
    }
    si = di;
    di <<= 2;
    JoyButA[si] = (al & JoyMask[di + 2]) ? 0 : 1;
    JoyButB[si] = (al & JoyMask[di + 3]) ? 0 : 1;
    bl = (unsigned char)(JoyMask[di] + JoyMask[di + 1]);
    outp(0x201, al);
    for (cx = 0; cx < 65535u; cx++) {
        al = inp(0x201);
        if (al & JoyMask[di])
            JoyX[si] = (unsigned short)cx;
        if (al & JoyMask[di + 1])
            JoyY[si] = (unsigned short)cx;
        if (!(al & bl))
            break;
    }
    _enable();
}

int DQBAPI DQBjoyMove(int joyNum, int direction)
{
    int di = joyNum;

    if (di == 2)
        di = 0;
    if (direction == 0)
        return JoyY[di] <= (unsigned)(JoyCY[di] - (int)JoySens) ? -1 : 0;
    if (direction == 1)
        return JoyY[di] >= (unsigned)(JoyCY[di] + (int)JoySens) ? -1 : 0;
    if (direction == 2)
        return JoyX[di] <= (unsigned)(JoyCX[di] - (int)JoySens) ? -1 : 0;
    return JoyX[di] >= (unsigned)(JoyCX[di] + (int)JoySens) ? -1 : 0;
}

int DQBAPI DQBjoyX(int joyNum)
{
    int di = joyNum;

    if (di == 2)
        di -= 2;
    return (int)JoyX[di] - (int)JoyCX[di];
}

int DQBAPI DQBjoyY(int joyNum)
{
    int di = joyNum;

    if (di == 2)
        di -= 2;
    return (int)JoyY[di] - (int)JoyCY[di];
}

int DQBAPI DQBjoyFire(int joyNum, int button)
{
    if (joyNum == 2) {
        if (button == 0)
            return JoyButA[0] ? -1 : 0;
        if (button == 1)
            return JoyButB[0] ? -1 : 0;
        if (button == 2)
            return JoyButA[1] ? -1 : 0;
        return JoyButB[1] ? -1 : 0;
    }
    if (button == 0)
        return JoyButA[joyNum] ? -1 : 0;
    return JoyButB[joyNum] ? -1 : 0;
}

void DQBAPI DQBresetJoy(void)
{
    extern void __far ResetJoy(void);
    ResetJoy();
}

void DQBAPI DQBsetJoySens(int newSens)
{
    JoySens = (unsigned short)newSens;
}
