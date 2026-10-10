#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <i86.h>

#include "directqb.h"
#include "engine.h"
#include "fmengine.h"
#include "debug.h"

TypePrefs prefs;
TypePlayer player;

/* --no-sound debug switch, defined here so every binary that links
 * engine.c (game, test, musplay) gets the symbol; only lala.c sets it. */
int g_noSound = 0;

/* Autoplay hook (PORTING.md Phase 4 debug): when lala.c's --autoplay
 * sets this, engineDoGame's frame loop calls it once per frame at the
 * top (tests/musplay never set it -> no effect). */
void (*g_autoTick)(void) = 0;

/* QB REDIMs tileProperties(59); the file holds 41 entries, rest stay 0. */
TypeTileProperties tileProperties[60];

/* QB REDIMs 64 sprite properties / 64 mapping entries; files hold fewer. */
TypeSpriteProperties spriteProperties[64];
int spriteMapping[64];

// Originally: DIM tileset%(0 TO 129, prefs.numTiles)
char __far *tileset[240];

// QB REDIMs spriteset%(289, numSprites) with numSprites = 21 - 1
char __far *spriteset[21];

/* Asset paths ("GFX\" + name) must be DGROUP-resident for the DQB
 * wrappers (they derive the far segment from DS), so build them here
 * instead of on the caller's stack. Single-threaded DOS: safe. */
static char assetPath[32];

static const char *asset(const char *dir, const char *file)
{
    sprintf(assetPath, "%s\\%s", dir, file);
    return assetPath;
}

/* QB INPUT# numeric item reader: ints separated by commas, spaces,
 * tabs or newlines, optional leading '-'. Mirrors what the TXT files
 * hold (see MAP and GFX folders). */
int qbReadInt(FILE *f)
{
    int c, neg = 0, v = 0;
    do {
        c = fgetc(f);
    } while (c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t');
    if (c == '-') {
        neg = 1;
        c = fgetc(f);
    }
    while (c >= '0' && c <= '9') {
        v = v * 10 + (c - '0');
        c = fgetc(f);
    }
    return neg ? -v : v;
}

#define NWMAX 160
static void __far *nwptr[NWMAX];
static void __far *nwbase[NWMAX];

void __far *fmalloc_nw(unsigned size)
{
    char __far *base;
    char __far *usable;
    unsigned long off;
    int i;
    base = _fmalloc(size + size);
    if (!base)
        return 0;
    off = (unsigned long)FP_OFF(base);
    if (off + (unsigned long)size > 0x10000UL)
        usable = base + size;    /* second half: provably clean */
    else
        usable = base;
    for (i = 0; i < NWMAX; i++) {
        if (!nwptr[i]) {
            nwptr[i] = usable;
            nwbase[i] = base;
            break;
        }
    }
    return usable;
}

void __far *fcalloc_nw(unsigned n, unsigned size)
{
    void __far *p = fmalloc_nw(n * size);
    if (p)
        _fmemset(p, 0, n * size);
    return p;
}

void ffree_nw(void __far *p, unsigned size)
{
    int i;
    (void)size;
    if (!p)
        return;
    for (i = 0; i < NWMAX; i++) {
        if (nwptr[i] == p) {
            _ffree(nwbase[i]);
            nwptr[i] = 0;
            nwbase[i] = 0;
            return;
        }
    }
    /* Not ours (or table full at alloc): leak rather than corrupt. */
}

/* True when only separators remain (QB's EOF(f%) for our TXT files). */
static int qbAtEof(FILE *f)
{
    int c;
    do {
        c = fgetc(f);
    } while (c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t');
    if (c == EOF)
        return 1;
    ungetc(c, f);
    return 0;
}


// SUB engineInitVals (prefsStore() AS TypePrefs)
void engineInitVals(void)
{
    strncpy(prefs.mapFile, "LALA.MAP", 12);
    strncpy(prefs.tilesetFile, "TILESET.PCX", 12);
    strncpy(prefs.tilePropertiesFile, "TILEPROP.TXT", 12);
    strncpy(prefs.backdropFile, "BACKDROP.PCX", 12);
    strncpy(prefs.spritesetFile, "SPRSET.PCX", 12);
    strncpy(prefs.spritePropertiesFile, "SPRPROP.TXT", 12);
    strncpy(prefs.spriteMappingFile, "SPRMAP.TXT", 12);
    strncpy(prefs.enemsFile, "ENEMS.TXT", 12);
    strncpy(prefs.hotSpotsFile, "HOTSPOTS.TXT", 12);
    /* Filenames are exactly 12 chars; force NUL (struct fields are [13]). */
    prefs.mapFile[12] = 0;
    prefs.tilesetFile[12] = 0;
    prefs.tilePropertiesFile[12] = 0;
    prefs.backdropFile[12] = 0;
    prefs.spritesetFile[12] = 0;
    prefs.spritePropertiesFile[12] = 0;
    prefs.spriteMappingFile[12] = 0;
    prefs.enemsFile[12] = 0;
    prefs.hotSpotsFile[12] = 0;
    prefs.bgM[12] = 0;
    prefs.mapW = 6;
    prefs.mapH = 6;
    prefs.screenW = 20;
    prefs.screenH = 12;
    prefs.screenPos.x = 0;
    prefs.screenPos.y = 4;
    // Player movement values
    prefs.gMaxVy = 192; //256
    prefs.g = 12; //16
    prefs.jumpVyInitial = 32; //64
    prefs.jumpVyMax = 192; //256
    prefs.jumpIncr = 24; //48
    prefs.walkVxMax = 128;
    prefs.walkAx = 16;
    prefs.walkFr = 24;
    // Game initial status
    prefs.iniPant = 24;
    prefs.iniTX = 2;
    prefs.iniTY = 1;
    // Enems
    prefs.nEnems = 4;
    prefs.enemPlat = 4;
    // special tiles
    prefs.boltTile = 22;
    prefs.lifeTile = 34;
    prefs.objectTile = 35;
    prefs.keyTile = 36;
    // stats
    prefs.initialLives = 15;
    prefs.maxObjs = 15;
    prefs.refill = 1;
    // music
    strncpy(prefs.bgM, "DESORUIN.S3M", 12);
    prefs.bgL1 = 9;
    prefs.bgL2 = 10;
}


// SUB engineLoadSpriteMapping (spriteMapping%(), prefs AS TypePrefs)
void engineLoadSpriteMapping()
{
    int index = 0;
    FILE *f = fopen(asset("GFX", prefs.spriteMappingFile), "rt");
    while (!qbAtEof(f) && index < 64) {
        spriteMapping[index] = qbReadInt(f);
        index++;
    }
    fclose(f);
}

// SUB engineLoadSpriteProperties (spriteProperties() AS TypeSpriteProperties, prefs AS TypePrefs)
void engineLoadSpriteProperties()
{
    int index = 0;
    FILE *f = fopen(asset("GFX", prefs.spritePropertiesFile), "rt");
    while (!qbAtEof(f) && index < 64) {
        spriteProperties[index].offX = qbReadInt(f);
        spriteProperties[index].offY = qbReadInt(f);
        index++;
    }
    fclose(f);
    prefs.numSprites = index;
}

void engineLoadSpriteset()
{
    int i, w, h, x, y;
    /* Palette of SPRSET.PCX is discarded, like the QB original's
     * `DIM dummy AS STRING * 768` (a real buffer, never NULL). */
    static char dummyPal[768];

    // sprites are in a 192x192 file (max 64 sprites)
    // In this game we use 6 for main sprite, 12 for enemies,
    // 2 for platforms.

    i = DQBloadImage(3, 0, 0, asset("GFX", prefs.spritesetFile), dummyPal, &w, &h);

    x = 0; y = 0;
    for (i = 0; i < prefs.numSprites; i++) {
        /* 24x24 sprite: 4-byte header + 576 pixels (see DQBget). */
        spriteset[i] = fmalloc_nw(580);
        DQBget(3, x, y, 23 + x, 23 + y, spriteset[i]);
        x += 24;
        if (x == 192) {
            x = 0;
            y += 24;
        }
    }

    DQBclearLayer(3);
}


//SUB engineLoadTileProperties (tileProperties() AS TypeTileProperties, prefs AS TypePrefs)
void engineLoadTileProperties()
{
    int index = 0;
    FILE *f = fopen(asset("MAP", prefs.tilePropertiesFile), "rt");
    while (!qbAtEof(f) && index < 60) {
        tileProperties[index].location = qbReadInt(f);
        tileProperties[index].flags = qbReadInt(f);
        index++;
    }
    fclose(f);
    prefs.numTiles = index;
}

/* --- Game logic (translated 1:1 from ENGINE.BAS) --- */

int cToIdx(int x, int y)
{
    /* cToIdx% = (1+x%) + (1+y%) * 22, shifts for speed (see BAS). */
    int yy = 1 + y;
    return 1 + x + DQBshiftLeft(yy, 4) + DQBshiftLeft(yy, 2) + DQBshiftLeft(yy, 1);
}

void engineCalcEnemsFrame(TypeEnems __far *enems, int nPant)
{
    int i;
    for (i = 0; i < prefs.nEnems; i++) {
        if (enems[nPant * ENEM_SLOTS + i].t > 0) {
            /* Choose sprite */
            enems[nPant * ENEM_SLOTS + i].subFrame++;
            if (enems[nPant * ENEM_SLOTS + i].subFrame == 4) {
                enems[nPant * ENEM_SLOTS + i].subFrame = 0;
                enems[nPant * ENEM_SLOTS + i].frame =
                    (enems[nPant * ENEM_SLOTS + i].frame + 1) & 3;
            }
            if (enems[nPant * ENEM_SLOTS + i].mx + enems[nPant * ENEM_SLOTS + i].my > 0)
                enems[nPant * ENEM_SLOTS + i].facing = 0;
            else
                enems[nPant * ENEM_SLOTS + i].facing = 4;
            enems[nPant * ENEM_SLOTS + i].sprId =
                spriteMapping[12 + DQBshiftLeft(enems[nPant * ENEM_SLOTS + i].t - 1, 3) +
                    enems[nPant * ENEM_SLOTS + i].facing + enems[nPant * ENEM_SLOTS + i].frame];
        }
    }
}

void engineCalcPlayerFrame(TypePlayer *pl)
{
    /* Calculate frame */
    if (pl->vy < 0) {
        pl->sprId = spriteMapping[pl->facing + 4];
    } else if (pl->vy > 0) {
        pl->sprId = spriteMapping[pl->facing + 5];
    } else if (pl->vx != 0) {
        pl->sprId = spriteMapping[pl->facing + pl->frame];
        pl->subFrame++;
        if (pl->subFrame == 4) {
            pl->subFrame = 0;
            pl->frame++;
            if (pl->frame == 4)
                pl->frame = 0;
        }
    } else {
        pl->sprId = spriteMapping[pl->facing];
    }
}

int engineDetectCollision(int i, int nPant, TypeEnems __far *enems, TypePlayer *pl)
{
    int x = DQBshiftRight(pl->x, 6);
    int y = DQBshiftRight(pl->y, 6);
    return (pl->state == STATENORMAL) &&
        (enems[nPant * ENEM_SLOTS + i].x >= x - 14 &&
         enems[nPant * ENEM_SLOTS + i].x <= x + 14 &&
         enems[nPant * ENEM_SLOTS + i].y >= y - 14 &&
         enems[nPant * ENEM_SLOTS + i].y <= y + 14);
}

int engineDetectKeyHole(TypeTileLayers __far *buff, int __far *map, int xx, int yy)
{
    int res = 0;
    if (buff[cToIdx(xx, yy)].behaviour == 10) {
        buff[cToIdx(xx, yy)].layer1 = 0;
        buff[cToIdx(xx, yy)].layer2 = 0;
        buff[cToIdx(xx, yy)].behaviour = 0;
        map[buff[cToIdx(xx, yy)].realMapIndex] = 0;
        res = -1;
    }
    return res;
}

void engineInitGame(void)
{
    player.keys = 0;
    player.lives = prefs.initialLives;
}

void engineInitPlayer(void)
{
    player.x = prefs.iniTX * 16 * 64;
    player.y = prefs.iniTY * 16 * 64;
    player.vx = 0;
    player.vy = 0;
    player.frame = 0;
    player.facing = 0;
    player.subFrame = 0;
    player.sprId = 0;
    player.jumping = 0;
    player.gotten = 0;
    player.ctJump = 0;
    player.state = STATENORMAL;
    player.objects = 0;
}

char *engineMakeNumber(int digits, int value)
{
    /* LTRIM$(STR$(value)) zero-padded to digits (values stay >= 0). */
    static char nbuf[8];
    sprintf(nbuf, "%0*d", digits, value);
    return nbuf;
}

int __far *engineMapLoad(void)
{
    int total = prefs.mapW * prefs.mapH * prefs.screenW * prefs.screenH;
    int __far *map = fmalloc_nw(total * sizeof(int));
    int index = 0;
    FILE *f = fopen(asset("MAP", prefs.mapFile), "rb");
    while (!feof(f) && index < total) {
        int c = fgetc(f);
        if (c == EOF)
            break;
        map[index] = c;
        index++;
    }
    fclose(f);
    return map;
}

void engineLoadEnems(TypeEnems __far *enems)
{
    int maxPants = prefs.mapW * (prefs.mapH - 1) - 1;
    int i, j;
    FILE *f = fopen(asset("MAP", prefs.enemsFile), "rt");
    for (i = 0; i <= maxPants; i++) {
        for (j = 0; j <= 3; j++) {
            enems[i * ENEM_SLOTS + j].x = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].y = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].x1 = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].y1 = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].x2 = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].y2 = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].mx = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].my = qbReadInt(f);
            enems[i * ENEM_SLOTS + j].t = qbReadInt(f);
        }
    }
    fclose(f);
}

void engineLoadHotSpots(TypeHotSpots __far *hs)
{
    int maxPants = prefs.mapW * (prefs.mapH - 1) - 1;
    int i, chumi;
    FILE *f = fopen(asset("MAP", prefs.hotSpotsFile), "rt");
    for (i = 0; i <= maxPants; i++) {
        hs[i].x = qbReadInt(f);
        hs[i].y = qbReadInt(f);
        hs[i].t = qbReadInt(f);
        chumi = qbReadInt(f);
        (void)chumi;
        hs[i].s = -1;
    }
    fclose(f);
}

void engineScreenPrepare(int nPant, int __far *map, TypeTileLayers __far *buff, TypeHotSpots __far *hs)
{
    /* QB: ERASE + REDIM = fresh zeros. */
    int xPant = nPant % prefs.mapW;
    int yPant = nPant / prefs.mapW;
    int mapTileWidth = prefs.mapW * prefs.screenW;
    int x, y;
    _fmemset(buff, 0, SBUFF_ENTRIES * sizeof(TypeTileLayers));

    /* Calculate offset in map file */
    for (y = 0; y < prefs.screenH; y++) {
        int index = (yPant * prefs.screenH + y) * mapTileWidth + xPant * prefs.screenW;
        for (x = 0; x < prefs.screenW; x++) {
            /* We offset +1,+1 our coordinates to make room for a
             * blank letterbox. */
            int yy = y + 1;
            int iindex = (x + 1) + DQBshiftLeft(yy, 4) + DQBshiftLeft(yy, 2) + DQBshiftLeft(yy, 1);
            int value = map[index + x];
            if (tileProperties[value].location == BACK)
                buff[iindex].layer1 = value;
            else
                buff[iindex].layer2 = value;
            if (tileProperties[value].location == ANIMATED)
                buff[iindex].anim = -1;
            else
                buff[iindex].anim = 0;
            buff[iindex].behaviour = tileProperties[value].flags;
            buff[iindex].realMapIndex = index + x;
        }
    }
    if (hs[nPant].s) {
        prefs.hotSpotX = DQBshiftLeft(hs[nPant].x, 4);
        prefs.hotSpotY = DQBshiftLeft(hs[nPant].y, 4);
    } else {
        prefs.hotSpotX = 999;
        prefs.hotSpotY = 999;
    }
}

void engineScreenDrawLayer1(TypeTileLayers __far *buff)
{
    int x = 0, y = 0;
    int screenPixelW = 16 * prefs.screenW;
    int idx = 23; /* skip letterbox */
    int i, j;
    DQBsetTransPut();
    for (i = 1; i <= 12; i++) {
        for (j = 1; j <= 20; j++) {
            int id = buff[idx].layer1;
            if (id)
                DQBput(2, prefs.screenPos.x + x, prefs.screenPos.y + y, tileset[id]);
            x += 16;
            if (x == screenPixelW) {
                x = 0;
                y += 16;
            }
            idx++;
        }
        idx += 2; /* skip border */
    }
}

void engineScreenDrawLayer2(int frame, TypeTileLayers __far *buff)
{
    int x = 0, y = 0;
    int screenPixelW = 16 * prefs.screenW;
    int idx = 23; /* skip letterbox */
    int i, j;
    DQBsetTransPut();
    for (i = 1; i <= 12; i++) {
        for (j = 1; j <= 20; j++) {
            int id = buff[idx].layer2;
            if (buff[idx].anim)
                id += frame;
            if (id)
                DQBput(1, prefs.screenPos.x + x, prefs.screenPos.y + y, tileset[id]);
            x += 16;
            if (x == screenPixelW) {
                x = 0;
                y += 16;
            }
            idx++;
        }
        idx += 2; /* skip border */
    }
}

void engineRprint(int layer, const char *text, int x, int y, int c)
{
    /* Shadowed print; text must be DGROUP (literals/statics, not stack). */
    DQBprint(layer, text, x + 1, y + 1, 255);
    DQBprint(layer, text, x, y, 254);
}

/* Number strings for the stats must also be DGROUP (see above). */
static char statBuf[16];

void enginePrintStats(void)
{
    /* You'll probably have to modify this by hand for each game. */
    DQBput(1, 4, 4, tileset[prefs.objectTile]);
    DQBput(1, 4, 20, tileset[prefs.keyTile]);
    DQBput(1, 4, 36, tileset[prefs.lifeTile]);
    sprintf(statBuf, "x%s", engineMakeNumber(2, player.objects));
    engineRprint(1, statBuf, 20, 4, 254);
    sprintf(statBuf, "x%s", engineMakeNumber(2, player.keys));
    engineRprint(1, statBuf, 20, 20, 254);
    {
        int l = player.lives >= 0 ? player.lives : 0;
        sprintf(statBuf, "x%s", engineMakeNumber(2, l));
        engineRprint(1, statBuf, 20, 36, 254);
    }
}

void engineDrawHotSpots(int nPant, TypeHotSpots __far *hs, int *hsTiles)
{
    if (hs[nPant].s) {
        int nTile = hsTiles[hs[nPant].t];
        int x = DQBshiftLeft(hs[nPant].x, 4);
        int y = DQBshiftLeft(hs[nPant].y, 4);
        DQBput(1, prefs.screenPos.x + x, prefs.screenPos.y + y, tileset[nTile]);
    }
}

void engineMoveEnems(TypeEnems __far *enems, TypeTileLayers __far *buff, int nPant)
{
    int i;
    player.gotten = 0;
    for (i = 0; i < prefs.nEnems; i++) {
        TypeEnems __far *e = &enems[nPant * ENEM_SLOTS + i];
        if (e->t > 0) {
            /* Move */
            e->x += e->mx;
            e->y += e->my;

            /* Manage platforms */
            if (e->t == prefs.enemPlat) {
                int x = DQBshiftRight(player.x, 6);
                int y = DQBshiftRight(player.y, 6);

                /* Vertical */
                if (e->my < 0) {
                    if (x >= e->x - 15 && x <= e->x + 15) {
                        if (y >= e->y - 16 && y <= e->y - 9) {
                            if (player.vy >= -prefs.jumpIncr) {
                                int xx, yy;
                                player.gotten = 1;
                                player.y = DQBshiftLeft(e->y - 16, 6);
                                player.vy = 0;
                                xx = DQBshiftRight(x, 4);
                                yy = DQBshiftRight(y, 4);
                                if (buff[cToIdx(xx, yy)].behaviour > 7 ||
                                    ((x & 15) != 0 && buff[cToIdx(xx + 1, yy)].behaviour > 7)) {
                                    player.y = DQBshiftLeft(yy + 1, 10);
                                }
                            }
                        }
                    }
                } else if (e->my > 0) {
                    if (x >= e->x - 15 && x <= e->x + 15) {
                        if (y >= e->y - 20 && y <= e->y - 14) {
                            if (player.vy >= 0) {
                                int xx, yy;
                                player.gotten = 1;
                                player.y = DQBshiftLeft(e->y - 16, 6);
                                player.vy = 0;
                                xx = DQBshiftRight(x, 4);
                                yy = DQBshiftRight(y, 4);
                                if (buff[cToIdx(xx, yy + 1)].behaviour > 3 ||
                                    ((x & 15) != 0 && buff[cToIdx(xx + 1, yy + 1)].behaviour > 3)) {
                                    player.y = DQBshiftLeft(yy, 10);
                                }
                            }
                        }
                    }
                }

                /* Horizontal */
                if (e->mx != 0) {
                    if (x >= e->x - 15 && x <= e->x + 15) {
                        if (y >= e->y - 16 && y <= e->y - 11) {
                            if (player.vy >= 0) {
                                int xx, yy;
                                player.gotten = 1;
                                player.y = DQBshiftLeft(e->y - 16, 6);
                                x = x + e->mx;
                                player.x = DQBshiftLeft(x, 6);
                                xx = DQBshiftRight(x, 4);
                                yy = DQBshiftRight(y, 4);
                                if (e->mx < 0) {
                                    if (buff[cToIdx(xx, yy)].behaviour > 7 ||
                                        ((y & 15) != 0 && buff[cToIdx(xx, yy + 1)].behaviour > 7)) {
                                        player.vx = 0;
                                        player.x = DQBshiftLeft(xx + 1, 10);
                                    }
                                } else if (e->mx > 0) {
                                    if (buff[cToIdx(xx + 1, yy)].behaviour > 7 ||
                                        ((y & 15) != 0 && buff[cToIdx(xx + 1, yy + 1)].behaviour > 7)) {
                                        player.vx = 0;
                                        player.x = DQBshiftLeft(xx, 10);
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                /* Detect collision */
                if (engineDetectCollision(i, nPant, enems, &player)) {
                    player.state = STATEFLICKER;
                    player.ctState = 128;
                    /* player vy, vx calculate. Repelled, double menem */
                    if (e->mx > 0)
                        player.vx = DQBshiftLeft(prefs.walkVxMax, 1);
                    else
                        player.vx = -(DQBshiftLeft(prefs.walkVxMax, 1));
                    if (e->my > 0)
                        player.vy = DQBshiftLeft(prefs.walkVxMax, 1);
                    else
                        player.vy = -(DQBshiftLeft(prefs.walkVxMax, 1));
                    /* Kill a bit */
                    player.lives--;
                    DBG(("collide: lives=%d", player.lives));
                    if (!g_noSound) {
                        DQBplaySound(2, 4, 11025, ONCE);
                        DQBplaySound(8, 3, 11025, ONCE);
                    }
                }
            }

            /* Limits */
            if (e->x == e->x1 || e->x == e->x2)
                e->mx = -e->mx;
            if (e->y == e->y1 || e->y == e->y2)
                e->my = -e->my;
        }
    }
}

void engineMovePlayer(TypeTileLayers __far *buff, int __far *map)
{
    int x, y, xx, yy, res;
    player.attempt = 0;
    /* State */
    if (player.state == STATEFLICKER) {
        player.ctState--;
        if (player.ctState == 0)
            player.state = STATENORMAL;
    }

    /* Vertical */
    player.vy += prefs.g;
    if (player.vy > prefs.gMaxVy)
        player.vy = prefs.gMaxVy;
    player.y += player.vy;
    if (player.y < 0) {
        player.y = 0;
        player.attempt = DUP;
    }
    if (player.y > 11264) {
        player.y = 11264;
        player.attempt = DDOWN;
    }

    /* If on movable platform... */
    if (player.gotten)
        player.vy = 0;

    y = DQBshiftRight(player.y, 6);
    yy = DQBshiftRight(y, 4);
    x = DQBshiftRight(player.x, 6);
    xx = DQBshiftRight(x, 4);

    /* Collision? undo to tile boundary */
    if (player.vy < 0) {
        if (buff[cToIdx(xx, yy)].behaviour > 7 ||
            ((x & 15) != 0 && buff[cToIdx(xx + 1, yy)].behaviour > 7)) {
            player.vy += DQBshiftRight(prefs.jumpIncr, 1); /* 0 */
            player.y = DQBshiftLeft(yy + 1, 10);
        }
    } else if (player.vy > 0 && (y & 15) <= DQBshiftRight(prefs.gMaxVy, 6)) {
        if (buff[cToIdx(xx, yy + 1)].behaviour > 3 ||
            ((x & 15) != 0 && buff[cToIdx(xx + 1, yy + 1)].behaviour > 3)) {
            player.vy = 0;
            player.y = DQBshiftLeft(yy, 10);
        }
    }

    /* Do jump (CTRL or UP) */
    if (DQBkey(0x1D) || DQBkey(0x48)) {
        if (player.vy == 0 && !player.jumping) {
            if (player.gotten ||
                (buff[cToIdx(xx, yy + 1)].behaviour > 3 ||
                 ((x & 15) != 0 && buff[cToIdx(xx + 1, yy + 1)].behaviour > 3))) {
                player.jumping = -1;
                player.ctJump = 0;
                if (!g_noSound)
                    DQBplaySound(3, 1, 11025 + (rand() >> 5), ONCE);
                player.x = DQBshiftLeft(x, 6);
            }
        }
        if (player.jumping) {
            player.vy -= prefs.jumpVyInitial + prefs.jumpIncr - DQBshiftRight(player.ctJump, 1);
            if (player.vy < -prefs.jumpVyMax)
                player.vy = -prefs.jumpVyMax;
            player.ctJump++;
            if (player.ctJump == 16)
                player.jumping = 0;
        }
    } else {
        player.jumping = 0;
    }

    /* Horizontal */
    if (!(DQBkey(0x4B) || DQBkey(0x4D))) {
        if (player.vx > 0) {
            player.vx -= prefs.walkFr;
            if (player.vx < 0) {
                player.vx = 0;
                player.x = DQBshiftLeft(x, 6);
            }
        } else if (player.vx < 0) {
            player.vx += prefs.walkFr;
            if (player.vx > 0) {
                player.vx = 0;
                player.x = DQBshiftLeft(x, 6);
            }
        }
    }

    if (DQBkey(0x4B)) {
        if (player.vx > -prefs.walkVxMax) {
            player.facing = 6;
            player.vx -= prefs.walkAx;
        }
    }

    if (DQBkey(0x4D)) {
        if (player.vx < prefs.walkVxMax) {
            player.facing = 0;
            player.vx += prefs.walkAx;
        }
    }

    player.x += player.vx;
    if (player.x < 0) {
        player.x = 0;
        player.attempt = DLEFT;
    }
    if (player.x > 19456) {
        player.x = 19456;
        player.attempt = DRIGHT;
    }

    /* Collision? undo to tile boundary */
    y = DQBshiftRight(player.y, 6);
    yy = DQBshiftRight(y, 4);
    x = DQBshiftRight(player.x, 6);
    xx = DQBshiftRight(x, 4);

    if (player.vx < 0) {
        if (buff[cToIdx(xx, yy)].behaviour > 7 ||
            ((y & 15) != 0 && buff[cToIdx(xx, yy + 1)].behaviour > 7)) {
            player.vx = 0;
            player.x = DQBshiftLeft(xx + 1, 10);
        }
    } else if (player.vx > 0) {
        if (buff[cToIdx(xx + 1, yy)].behaviour > 7 ||
            ((y & 15) != 0 && buff[cToIdx(xx + 1, yy + 1)].behaviour > 7)) {
            player.vx = 0;
            player.x = DQBshiftLeft(xx, 10);
        }
    } else {
        player.x = DQBshiftLeft(x, 6);
    }

    x = DQBshiftRight(player.x, 6);
    xx = DQBshiftRight(x, 4);

    /* Open keyhole */
    if ((y & 15) == 0 && (x & 15) == 0 && player.keys > 0) {
        res = 0;
        if (DQBkey(0x4B))
            res = engineDetectKeyHole(buff, map, xx - 1, yy);
        if (DQBkey(0x4D))
            res = engineDetectKeyHole(buff, map, xx + 1, yy);
        if (res) {
            player.keys--;
            if (!g_noSound)
                DQBplaySound(1, 2, 11025, ONCE);
        }
    }

    /* Evil tile */
    if (buff[cToIdx(xx, yy)].behaviour == 1 ||
        ((x & 15) != 0 && buff[cToIdx(xx + 1, yy)].behaviour == 1) ||
        ((y & 15) != 0 && buff[cToIdx(xx, yy + 1)].behaviour == 1) ||
        ((x & 15) != 0 && (y & 15) != 0 && buff[cToIdx(xx + 1, yy + 1)].behaviour == 1)) {
        if (!g_noSound)
            DQBplaySound(7, 4, 11025, ONCE);
        if (player.state == STATENORMAL) {
            if (!g_noSound)
                DQBplaySound(8, 3, 11025 + (rand() >> 5), ONCE);
            player.lives--;
            DBG(("evil tile: lives=%d", player.lives));
            player.state = STATEFLICKER;
            player.ctState = 128;
        }
        if (player.vy < 0) {
            player.vy = prefs.gMaxVy;
            player.y = DQBshiftLeft(yy + 1, 10);
        } else {
            player.vy = -prefs.gMaxVy;
            player.y = DQBshiftLeft(yy, 10);
        }
    }
}

int engineDoGame(int flag)
{
    /* Buffer to contain current screen.
     * Screen area is 20x12, letterboxed with blank tiles
     * (avoids lots of checks, and matches cToIdx layout). */
    TypeTileLayers __far *curScreenBuff = fcalloc_nw(SBUFF_ENTRIES, sizeof(TypeTileLayers));
    int __far *map;
    TypeEnems __far *enems = fcalloc_nw((prefs.mapW * prefs.mapH) * ENEM_SLOTS, sizeof(TypeEnems));
    TypeHotSpots __far *hotSpots = fcalloc_nw(prefs.mapW * prefs.mapH, sizeof(TypeHotSpots));
    int hotSpotsTiles[4];
    int res = 0;
    int lastRow, lastPant, nPant;
    int frame, halfLife, subFrame, ticks;
    int w, h, imgRc;

    DBG(("DoGame: enter flag=%d", flag));
    DBG(("DoGame: buff=%04X:%04X enems=%04X:%04X hot=%04X:%04X",
        DBG_SEG(curScreenBuff), DBG_OFF(curScreenBuff),
        DBG_SEG(enems), DBG_OFF(enems),
        DBG_SEG(hotSpots), DBG_OFF(hotSpots)));

    player.gameOver = 0;

    hotSpotsTiles[1] = prefs.objectTile;
    hotSpotsTiles[2] = prefs.keyTile;
    hotSpotsTiles[3] = prefs.lifeTile;

    lastRow = (prefs.mapH - 1) * prefs.mapW;
    lastPant = prefs.mapH * prefs.mapW - 1;

    if (flag)
        nPant = prefs.iniPant;
    else
        nPant = prefs.mapW * (prefs.mapH - 1);

    engineInitPlayer();

    if (flag) {
        DQBclearLayer(3);
        imgRc = DQBloadImage(3, prefs.screenPos.x, prefs.screenPos.y,
            asset("GFX", prefs.backdropFile), prefs.pal, &w, &h);
        DBG(("DoGame: backdrop rc=%d pal[0..5]=%d %d %d %d %d %d",
            imgRc, (unsigned char)prefs.pal[0], (unsigned char)prefs.pal[1],
            (unsigned char)prefs.pal[2], (unsigned char)prefs.pal[3],
            (unsigned char)prefs.pal[4], (unsigned char)prefs.pal[5]));
    }
    map = engineMapLoad();
    DBG(("DoGame: map=%04X:%04X", DBG_SEG(map), DBG_OFF(map)));
    engineLoadEnems(enems);
    engineLoadHotSpots(hotSpots);
    engineScreenPrepare(nPant, map, curScreenBuff, hotSpots);

    frame = 0;
    halfLife = 0;
    subFrame = 0;
    ticks = 0;

    if (flag && !g_noSound) {
        /* ambient */
        if (prefs.bgL1) {
            DBG(("DoGame: play bgL1=%d", prefs.bgL1));
            DQBplaySound(prefs.bgL1, 5, 11025, LOOPED);
        }
        if (prefs.bgL2) {
            DBG(("DoGame: play bgL2=%d", prefs.bgL2));
            DQBplaySound(prefs.bgL2, 6, 11025, LOOPED);
        }

        /* music */
        if (prefs.bgM[0])
            FMload(asset("MUSIC", prefs.bgM));
    }

    /* Prepare background */
    DQBcopyLayer(3, 2);

    engineScreenDrawLayer1(curScreenBuff);

    while (!DQBkey(1)) {
        int x, y, i, s;
        halfLife = 1 - halfLife;
        subFrame = (subFrame + 1) & 3;
        if (subFrame == 0) {
            frame++;
            if (frame == 4)
                frame = 0;
        }
        /* Move stuff */
        if (!player.gameOver)
            engineMovePlayer(curScreenBuff, map);
        if (halfLife)
            engineMoveEnems(enems, curScreenBuff, nPant);
        /* Change screen? */
        if (player.attempt && flag) {
            switch (player.attempt) {
            case DUP:
                if (nPant >= prefs.mapW) {
                    nPant -= prefs.mapW;
                    player.y = DQBshiftLeft(prefs.screenH - 1, 10);
                }
                break;
            case DDOWN:
                if (nPant < lastRow) {
                    nPant += prefs.mapW;
                    player.y = 0;
                }
                break;
            case DLEFT:
                if (nPant > 0) {
                    nPant--;
                    player.x = DQBshiftLeft(prefs.screenW - 1, 10);
                }
                break;
            case DRIGHT:
                if (nPant < lastPant) {
                    nPant++;
                    player.x = 0;
                }
                break;
            }
            DBG(("DoGame: screen -> %d", nPant));
            engineScreenPrepare(nPant, map, curScreenBuff, hotSpots);
            /* Prepare background */
            DQBcopyLayer(3, 2);
            engineScreenDrawLayer1(curScreenBuff);
        }
        /* Checks */
        x = DQBshiftRight(player.x, 6);
        y = DQBshiftRight(player.y, 6);
        if (x >= prefs.hotSpotX - 15 && x <= prefs.hotSpotX + 15 &&
            y >= prefs.hotSpotY - 15 && y <= prefs.hotSpotY + 15) {
            hotSpots[nPant].s = 0;
            switch (hotSpots[nPant].t) {
            case 1:
                player.objects++;
                if (!g_noSound)
                    DQBplaySound(6, 4, 11025, ONCE);
                break;
            case 2:
                player.keys++;
                if (!g_noSound)
                    DQBplaySound(4, 4, 11025, ONCE);
                break;
            case 3:
                player.lives += prefs.refill;
                if (!g_noSound)
                    DQBplaySound(5, 4, 11025, ONCE);
                break;
            }
            prefs.hotSpotX = 999;
            prefs.hotSpotY = 999;
        }
        /* Make frames */
        engineCalcPlayerFrame(&player);
        engineCalcEnemsFrame(enems, nPant);
        /* Render */
        DQBcopyLayer(2, 1);
        if (!player.gameOver) {
            s = player.sprId;
            if (player.state == STATENORMAL || halfLife == 0) {
                DQBput(1, prefs.screenPos.x + x - spriteProperties[player.sprId].offX,
                    prefs.screenPos.y + y - spriteProperties[player.sprId].offY,
                    spriteset[s]);
            }
        }
        for (i = 0; i < prefs.nEnems; i++) {
            if (enems[nPant * ENEM_SLOTS + i].t > 0) {
                s = enems[nPant * ENEM_SLOTS + i].sprId;
                DQBput(1, prefs.screenPos.x + enems[nPant * ENEM_SLOTS + i].x - spriteProperties[s].offX,
                    prefs.screenPos.y + enems[nPant * ENEM_SLOTS + i].y - spriteProperties[s].offY,
                    spriteset[s]);
            }
        }
        engineScreenDrawLayer2(frame, curScreenBuff);
        engineDrawHotSpots(nPant, hotSpots, hotSpotsTiles);
        if (flag) {
            enginePrintStats();
        } else {
            if (player.gameOver) {
                DQBfilterBox(1, 116, 92, 203, 107, 255, 1);
                DQBprint(1, "GAME OVER", 123, 95, 0);
                DQBprint(1, "GAME OVER", 124, 96, 254);
            } else {
                DQBfilterBox(1, 80, 136, 239, 151, 255, 1);
                DQBprint(1, "PRESS ENTER TO PLAY", 89, 141, 0);
                DQBprint(1, "PRESS ENTER TO PLAY", 88, 140, 1);
            }
        }
        /* Show */
        DQBwait(1);
        DQBcopyLayer(1, VIDEO);
        if (g_autoTick)
            g_autoTick();

        /* Cheat */
        if (DQBkey(17) && DQBkey(18) && DQBkey(19)) {
            while (DQBkey(17) || DQBkey(18) || DQBkey(19))
                ;
            player.objects++;
        }

        /* Exit? */
        if (player.objects == prefs.maxObjs) {
            res = -1;
            break;
        }
        if (player.lives < 0) {
            DBG(("DoGame: GAME OVER lives=%d", player.lives));
            res = -2;
            player.gameOver = -1;
            flag = 0;
        }

        ticks++;
        if (DQBkey(28) && !flag) {
            if (g_autoTick && ticks < 25) {
                KeyStatus[28] = 0;
            } else {
                res = -3;
                break;
            }
        }
    }

    /* PLAY STOP */
    if (!g_noSound) {
        FMstop();
        BeSilent();
        DQBstopVoice(5);
        DQBstopVoice(6);
    }

    ffree_nw(curScreenBuff, SBUFF_ENTRIES * sizeof(TypeTileLayers));
    ffree_nw(map, prefs.mapW * prefs.mapH * prefs.screenW * prefs.screenH * sizeof(int));
    ffree_nw(enems, (prefs.mapW * prefs.mapH) * ENEM_SLOTS * sizeof(TypeEnems));
    ffree_nw(hotSpots, prefs.mapW * prefs.mapH * sizeof(TypeHotSpots));

    DBG(("DoGame: exit res=%d lives=%d objects=%d",
        res, player.lives, player.objects));
    return res;
}


void engineLoadTileset()
{
    int i, w, h, x, y;

    i = DQBloadImage(3, 0, 0, asset("GFX", prefs.tilesetFile), prefs.pal, &w, &h);
    DBG(("loadTileset: rc=%d pal0=%d pal3=%d", i, (unsigned char)prefs.pal[0],
        (unsigned char)prefs.pal[3]));

    x = 0; y = 0;
    
    for (i = 0; i < prefs.numTiles; i++) {
        /* 16x16 tile: 4-byte header + 256 pixels (see DQBget). */
        tileset[i] = fmalloc_nw(260);
        DQBget(3, x, y, 15 + x, 15 + y, tileset[i]);
        x += 16;
        if (x == 320) {
            x = 0;
            y += 16;
        }
    }

    DQBclearLayer(3);
}


