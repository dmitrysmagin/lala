#include "dqb_int.h"

int DQBAPI DQBsetBit(int value, int bit)
{
    int mask = 1;
    while (bit-- > 0)
        mask <<= 1;
    if (value & mask)
        return value;
    return value + mask;
}

int DQBAPI DQBreadBit(int value, int bit)
{
    int mask = 1;
    while (bit-- > 0)
        mask <<= 1;
    return (value & mask) ? -1 : 0;
}

int DQBAPI DQBresetBit(int value, int bit)
{
    int mask = 1;
    while (bit-- > 0)
        mask <<= 1;
    return value & (0xFFFF - mask);
}

int DQBAPI DQBtoggleBit(int value, int bit)
{
    int mask = 1;
    while (bit-- > 0)
        mask <<= 1;
    if (value & mask)
        return value - mask;
    return value + mask;
}

int DQBAPI DQBshiftLeft(int value, int nBits)
{
    return (int)((unsigned)value << (nBits & 15));
}

int DQBAPI DQBshiftRight(int value, int nBits)
{
    return (int)((unsigned)value >> (nBits & 15));
}
