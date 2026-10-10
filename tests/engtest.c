/* engtest.c — headless self-test for the ENGINE.BAS port.
 *
 * Runs as bin\test.exe with bin/ mounted as C:. No video, sound or
 * keyboard needed (DQBkey reads an all-zero table headless).
 * Every expectation below was hand-verified against lala-qb/ENGINE.BAS
 * and the data files. Writes TESTLOG.TXT, returns failure count.
 *
 * NOTE: engineDetectCollision returns C truth (1/0); QB returns -1/0.
 * Both are used only as IF conditions, so this is equivalent.
 *
 * NOTE 2: checks go through check()/checkstr() FUNCTIONS (not inlined
 * macros): near calls need no fixups, keeping this module small enough
 * for wlink-beta (see PORTING.md quirks).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <i86.h>

#include "directqb.h"
#include "engine.h"
#include "fmengine.h"

static int fails = 0;
static FILE *logf;

static void check(const char *name, int got, int want)
{
    if (got != want) {
        fprintf(logf, "FAIL %s: got %d want %d\n", name, got, want);
        fails++;
    } else {
        fprintf(logf, "ok   %s = %d\n", name, got);
    }
    fflush(logf);
}

static void checkstr(const char *name, const char *got, const char *want)
{
    if (strcmp(got, want) != 0) {
        fprintf(logf, "FAIL %s: got '%s' want '%s'\n", name, got, want);
        fails++;
    } else {
        fprintf(logf, "ok   %s = '%s'\n", name, got);
    }
    fflush(logf);
}

#define CHECK(n, g, w) check(n, g, w)
#define CHECKSTR(n, g, w) checkstr(n, g, w)

static void test_tables(void)
{
    CHECK("cToIdx(0,0)", cToIdx(0, 0), 23);
    CHECK("cToIdx(1,0)", cToIdx(1, 0), 24);
    CHECK("cToIdx(0,11)", cToIdx(0, 11), 265);
    CHECK("cToIdx(19,11)", cToIdx(19, 11), 284);

    CHECKSTR("makeNumber(2,5)", engineMakeNumber(2, 5), "05");
    CHECKSTR("makeNumber(2,15)", engineMakeNumber(2, 15), "15");
    CHECKSTR("makeNumber(3,7)", engineMakeNumber(3, 7), "007");
    CHECKSTR("makeNumber(2,0)", engineMakeNumber(2, 0), "00");
}

static void test_loaders(void)
{
    int __far *map;

    engineInitVals();
    CHECK("mapW", prefs.mapW, 6);
    CHECK("iniPant", prefs.iniPant, 24);
    CHECK("walkVxMax", prefs.walkVxMax, 128);
    CHECK("bgL1", prefs.bgL1, 9);
    CHECKSTR("mapFile", prefs.mapFile, "LALA.MAP");

    engineLoadTileProperties();
    CHECK("numTiles", prefs.numTiles, 41);
    CHECK("tp0.loc", tileProperties[0].location, 0);
    CHECK("tp0.flags", tileProperties[0].flags, 0);
    CHECK("tp1.loc", tileProperties[1].location, 1);
    CHECK("tp1.flags", tileProperties[1].flags, 8);
    CHECK("tp22.flags", tileProperties[22].flags, 10);
    CHECK("tp24.loc", tileProperties[24].location, 2);
    CHECK("tp33.loc", tileProperties[33].location, 1);
    CHECK("tp33.flags", tileProperties[33].flags, 1);
    CHECK("tp40.loc", tileProperties[40].location, 0);

    engineLoadSpriteMapping();
    CHECK("sm0", spriteMapping[0], 0);
    CHECK("sm1", spriteMapping[1], 1);
    CHECK("sm11", spriteMapping[11], 5);
    CHECK("sm12", spriteMapping[12], 6);
    CHECK("sm24", spriteMapping[24], 12);
    CHECK("sm31", spriteMapping[31], 16);
    CHECK("sm36", spriteMapping[36], 17);
    CHECK("sm43", spriteMapping[43], 20);
    CHECK("sm44.zero", spriteMapping[44], 0); /* only 44 values in file */

    engineLoadSpriteProperties();
    CHECK("numSprites", prefs.numSprites, 21);
    CHECK("sp0.offX", spriteProperties[0].offX, 4);
    CHECK("sp0.offY", spriteProperties[0].offY, 8);
    CHECK("sp6.offY", spriteProperties[6].offY, 7);
    CHECK("sp12.offX", spriteProperties[12].offX, 4);
    CHECK("sp13.offX", spriteProperties[13].offX, 4);
    CHECK("sp13.offY", spriteProperties[13].offY, 8);
    CHECK("sp20.offY", spriteProperties[20].offY, 8);

    map = engineMapLoad();
    CHECK("map0", map[0], 8);
    CHECK("map1", map[1], 0);
    CHECK("map22", map[22], 15);
    CHECK("map23", map[23], 24);
    CHECK("map5760", map[5760], 4);
    CHECK("map5768", map[5768], 24);
    CHECK("map5882", map[5882], 0);
    CHECK("map8639", map[8639], 0);
    ffree_nw(map, 8640 * sizeof(int));
}

static void test_enems_hotspots(void)
{
    TypeEnems __far *en = fcalloc_nw(36 * ENEM_SLOTS, sizeof(TypeEnems));
    TypeHotSpots __far *hs = fcalloc_nw(36, sizeof(TypeHotSpots));

    engineLoadEnems(en);
    CHECK("en00.x", en[0].x, 96);
    CHECK("en00.y", en[0].y, 32);
    CHECK("en00.mx", en[0].mx, 1);
    CHECK("en00.my", en[0].my, 1);
    CHECK("en00.t", en[0].t, 3);
    CHECK("en01.mx", en[1].mx, -2);
    CHECK("en24.0.x", en[24 * ENEM_SLOTS + 0].x, 112);
    CHECK("en24.0.my", en[24 * ENEM_SLOTS + 0].my, 1);
    CHECK("en24.1.t", en[24 * ENEM_SLOTS + 1].t, 4);
    CHECK("en24.2.mx", en[24 * ENEM_SLOTS + 2].mx, 1);
    CHECK("en24.3.t", en[24 * ENEM_SLOTS + 3].t, 0);
    CHECK("en30.zero", en[30 * ENEM_SLOTS + 0].t, 0);

    engineLoadHotSpots(hs);
    CHECK("hs0.x", hs[0].x, 14);
    CHECK("hs0.y", hs[0].y, 1);
    CHECK("hs0.t", hs[0].t, 2);
    CHECK("hs0.s", hs[0].s, -1);
    CHECK("hs1.x", hs[1].x, 5);
    CHECK("hs24.x", hs[24].x, 11);
    CHECK("hs24.y", hs[24].y, 3);
    CHECK("hs24.t", hs[24].t, 1);

    ffree_nw(en, 36 * ENEM_SLOTS * sizeof(TypeEnems));
    ffree_nw(hs, 36 * sizeof(TypeHotSpots));
}

static void test_prepare(void)
{
    int __far *map = engineMapLoad();
    TypeTileLayers __far *buff = fcalloc_nw(SBUFF_ENTRIES, sizeof(TypeTileLayers));
    TypeHotSpots __far *hs = fcalloc_nw(36, sizeof(TypeHotSpots));

    engineLoadHotSpots(hs);
    engineScreenPrepare(24, map, buff, hs);

    /* cell (8,0): value 24 -> {ANIMATED,0}: layer2, anim -1 */
    CHECK("p31.l1", buff[31].layer1, 0);
    CHECK("p31.l2", buff[31].layer2, 24);
    CHECK("p31.anim", buff[31].anim, -1);
    CHECK("p31.beh", buff[31].behaviour, 0);
    CHECK("p31.rmi", buff[31].realMapIndex, 5768);
    /* cell (0,0): value 4 -> {FRONT,8}: layer2 */
    CHECK("p23.l1", buff[23].layer1, 0);
    CHECK("p23.l2", buff[23].layer2, 4);
    CHECK("p23.anim", buff[23].anim, 0);
    CHECK("p23.beh", buff[23].behaviour, 8);
    CHECK("p23.rmi", buff[23].realMapIndex, 5760);
    /* cell (1,0): value 0 -> {BACK,0}: layer1 = 0 */
    CHECK("p24.l1", buff[24].layer1, 0);
    CHECK("p24.l2", buff[24].layer2, 0);
    CHECK("p24.rmi", buff[24].realMapIndex, 5761);
    /* hotspot 24 = (11,3): 11<<4, 3<<4 */
    CHECK("hotSpotX", prefs.hotSpotX, 176);
    CHECK("hotSpotY", prefs.hotSpotY, 48);

    ffree_nw(map, 8640 * sizeof(int));
    ffree_nw(buff, SBUFF_ENTRIES * sizeof(TypeTileLayers));
    ffree_nw(hs, 36 * sizeof(TypeHotSpots));
}

static void test_detect(void)
{
    TypeTileLayers __far *buff = fcalloc_nw(SBUFF_ENTRIES, sizeof(TypeTileLayers));
    int __far *maparr = fcalloc_nw(100, sizeof(int));
    TypeEnems __far *en = fcalloc_nw(ENEM_SLOTS, sizeof(TypeEnems));
    int r;

    /* keyhole: buff[23] is cToIdx(0,0), behaviour 10 */
    buff[23].layer1 = 7;
    buff[23].layer2 = 8;
    buff[23].behaviour = 10;
    buff[23].realMapIndex = 5;
    maparr[5] = 22;
    r = engineDetectKeyHole(buff, maparr, 0, 0);
    CHECK("keyhole.res", r, -1);
    CHECK("keyhole.l1", buff[23].layer1, 0);
    CHECK("keyhole.l2", buff[23].layer2, 0);
    CHECK("keyhole.beh", buff[23].behaviour, 0);
    CHECK("keyhole.map", maparr[5], 0);

    buff[30].behaviour = 8;
    buff[30].layer1 = 3;
    r = engineDetectKeyHole(buff, maparr, 7, 0);
    CHECK("nokeyhole.res", r, 0);
    CHECK("nokeyhole.l1", buff[30].layer1, 3);

    /* collision around (100,100), +/-14 */
    player.x = 100 * 64;
    player.y = 100 * 64;
    player.state = STATENORMAL;
    en[0].x = 100;
    en[0].y = 100;
    CHECK("coll.exact", engineDetectCollision(0, 0, en, &player), 1);
    en[0].x = 114;
    CHECK("coll.edge", engineDetectCollision(0, 0, en, &player), 1);
    en[0].x = 115;
    CHECK("coll.out", engineDetectCollision(0, 0, en, &player), 0);
    en[0].x = 100;
    player.state = STATEFLICKER;
    CHECK("coll.flicker", engineDetectCollision(0, 0, en, &player), 0);

    ffree_nw(buff, SBUFF_ENTRIES * sizeof(TypeTileLayers));
    ffree_nw(maparr, 100 * sizeof(int));
    ffree_nw(en, 36 * ENEM_SLOTS * sizeof(TypeEnems));
}

static void test_frames(void)
{
    TypeEnems __far *en = fcalloc_nw(ENEM_SLOTS, sizeof(TypeEnems));
    TypePlayer pl;

    /* player frames (mapping: 0,1,0,2,1,2,3,4,3,5,4,5,...) */
    pl.vy = -5;
    pl.vx = 0;
    pl.facing = 0;
    pl.frame = 0;
    pl.subFrame = 0;
    engineCalcPlayerFrame(&pl);
    CHECK("pframe.up", pl.sprId, 1);
    pl.vy = 5;
    engineCalcPlayerFrame(&pl);
    CHECK("pframe.down", pl.sprId, 2);
    pl.vy = 0;
    pl.vx = 3;
    pl.frame = 2;
    pl.subFrame = 0;
    engineCalcPlayerFrame(&pl);
    CHECK("pframe.walk", pl.sprId, 0);
    CHECK("pframe.sub", pl.subFrame, 1);
    pl.vx = 0;
    pl.facing = 6;
    engineCalcPlayerFrame(&pl);
    CHECK("pframe.still", pl.sprId, 3);

    /* enemy frames: t=3,mx=1,my=0,sub 3->0, frame 1->2, facing 0,
     * sprId = mapping[12+16+0+2] = mapping[30] = 15 */
    en[0].t = 3;
    en[0].mx = 1;
    en[0].my = 0;
    en[0].subFrame = 3;
    en[0].frame = 1;
    en[0].sprId = -99;
    en[1].t = 0;
    en[1].sprId = -99;
    engineCalcEnemsFrame(en, 0);
    CHECK("eframe.sub", en[0].subFrame, 0);
    CHECK("eframe.frame", en[0].frame, 2);
    CHECK("eframe.facing", en[0].facing, 0);
    CHECK("eframe.spr", en[0].sprId, 15);
    CHECK("eframe.skip", en[1].sprId, -99);

    ffree_nw(en, 36 * ENEM_SLOTS * sizeof(TypeEnems));
}

static void test_init_move(void)
{
    int __far *map;
    TypeTileLayers __far *buff;
    TypeEnems __far *en;
    TypeHotSpots __far *hs;
    int f;

    engineInitPlayer();
    CHECK("init.px", player.x, 2048);
    CHECK("init.py", player.y, 1024);
    CHECK("init.vx", player.vx, 0);
    CHECK("init.state", player.state, STATENORMAL);
    CHECK("init.obj", player.objects, 0);

    player.keys = 5;
    player.lives = 99;
    engineInitGame();
    CHECK("game.keys", player.keys, 0);
    CHECK("game.lives", player.lives, 15);

    /* 8-frame free-fall smoke (no keys headless): vy = 12,24,...,96;
     * y = 1024+12+24+...+96 = 1456; tiles below are air (verified). */
    engineInitPlayer();
    map = engineMapLoad();
    buff = fcalloc_nw(SBUFF_ENTRIES, sizeof(TypeTileLayers));
    en = fcalloc_nw(36 * ENEM_SLOTS, sizeof(TypeEnems));
    hs = fcalloc_nw(36, sizeof(TypeHotSpots));
    engineLoadEnems(en);
    engineLoadHotSpots(hs);
    engineScreenPrepare(24, map, buff, hs);
    for (f = 1; f <= 8; f++) {
        engineMovePlayer(buff, map);
        if (f & 1)
            engineMoveEnems(en, buff, 24);
    }
    CHECK("smoke.x", player.x, 2048);
    CHECK("smoke.y", player.y, 1456);
    CHECK("smoke.vx", player.vx, 0);
    CHECK("smoke.vy", player.vy, 96);
    CHECK("smoke.lives", player.lives, 15);
    CHECK("smoke.state", player.state, STATENORMAL);
    CHECK("smoke.attempt", player.attempt, 0);

    ffree_nw(map, 8640 * sizeof(int));
    ffree_nw(buff, SBUFF_ENTRIES * sizeof(TypeTileLayers));
    ffree_nw(en, 36 * ENEM_SLOTS * sizeof(TypeEnems));
    ffree_nw(hs, 36 * sizeof(TypeHotSpots));
}

/* Full render path with real DQB (layers are RAM buffers; works headless).
 * Proves tileset/spriteset/font loads, puts, prints and layer copies run. */
static void test_render(void)
{
    int __far *map;
    TypeTileLayers __far *buff;
    TypeEnems __far *en;
    TypeHotSpots __far *hs;
    int w, h, rc;
    static int hsTiles[4] = {0, 35, 36, 34}; /* indexed 1..3 like QB */

    fprintf(logf, "-- render\n");
    fflush(logf);

    rc = DQBinit(5, 11, 0);
    CHECK("render.init", rc, 0);
    if (rc)
        return;

    engineInitVals();
    engineLoadTileProperties();
    engineLoadSpriteProperties();
    engineLoadSpriteMapping();
    rc = xDQBloadFont("GFX\\LALA.FNT");
    CHECK("render.font", rc, 0);
    fprintf(logf, "cp tileset\n");
    fflush(logf);
    engineLoadTileset();
    fprintf(logf, "cp spriteset\n");
    fflush(logf);
    engineLoadSpriteset();

    DQBclearLayer(3);
    rc = DQBloadImage(3, prefs.screenPos.x, prefs.screenPos.y,
        "GFX\\BACKDROP.PCX", prefs.pal, &w, &h);
    CHECK("render.backdrop", rc, 0);
    fprintf(logf, "cp prepare\n");
    fflush(logf);

    map = engineMapLoad();
    en = fcalloc_nw(36 * ENEM_SLOTS, sizeof(TypeEnems));
    hs = fcalloc_nw(36, sizeof(TypeHotSpots));
    buff = fcalloc_nw(SBUFF_ENTRIES, sizeof(TypeTileLayers));
    engineLoadEnems(en);
    engineLoadHotSpots(hs);
    engineScreenPrepare(24, map, buff, hs);

    DQBcopyLayer(3, 2);
    engineScreenDrawLayer1(buff);

    engineInitPlayer();
    engineCalcPlayerFrame(&player);
    {
        int x = DQBshiftRight(player.x, 6);
        int y = DQBshiftRight(player.y, 6);
        DQBcopyLayer(2, 1);
        DQBput(1, prefs.screenPos.x + x - spriteProperties[player.sprId].offX,
            prefs.screenPos.y + y - spriteProperties[player.sprId].offY,
            spriteset[player.sprId]);
    }
    engineScreenDrawLayer2(0, buff);
    engineDrawHotSpots(24, hs, hsTiles);
    enginePrintStats();

    DQBwait(1);
    DQBcopyLayer(1, VIDEO);

    /* main/showTitle calls not covered above */
    xDQBsetPal(prefs.pal);
    DQBfadeTo(0, 0, 0);
    DQBinitVGA();
    DQBinitText();

    DQBclose();

    ffree_nw(map, 8640 * sizeof(int));
    ffree_nw(en, 36 * ENEM_SLOTS * sizeof(TypeEnems));
    ffree_nw(hs, 36 * sizeof(TypeHotSpots));
    ffree_nw(buff, SBUFF_ENTRIES * sizeof(TypeTileLayers));

    fprintf(logf, "render.done\n");
    fflush(logf);
}

static unsigned long fmWrites(void)
{
    unsigned long w;
    _disable();
    w = fm_writes;
    _enable();
    return w;
}

/* Full game loop with scripted input: pokes KeyStatus directly
 * (DQBkey reads it; no real keyboard needed). Covers title ENTER
 * exit, ESC exit, sustained physics + rendering with keys held. */
static void test_game(void)
{
    int __far *map;
    TypeTileLayers __far *buff;
    TypeEnems __far *en;
    TypeHotSpots __far *hs;
    int r, f, x0, y0;
    static int hsTiles[4] = {0, 35, 36, 34}; /* indexed 1..3 like QB */

    fprintf(logf, "-- game\n");
    fflush(logf);

    memset(KeyStatus, 0, 128);
    CHECK("keys.clean", DQBkey(28), 0);

    r = DQBinit(5, 11, 0);
    CHECK("game.init", r, 0);
    if (r)
        return;

    engineInitVals();
    engineLoadTileProperties();
    engineLoadSpriteProperties();
    engineLoadSpriteMapping();
    r = xDQBloadFont("GFX\\LALA.FNT");
    CHECK("game.font", r, 0);
    DQBinstallSB(0, 6, 11025, AUTO, AUTO, AUTO);
    xDQBloadSound(3, "SFX\\JUMP.WAV");
    xDQBloadSound(2, "SFX\\HIT.WAV");

    /* Title demo + ENTER exits with -3 (showTitle path). */
    KeyStatus[28] = 1;
    r = engineDoGame(0);
    KeyStatus[28] = 0;
    CHECK("game.enter", r, -3);

    /* ESC exits immediately with 0 (loop guard). */
    KeyStatus[1] = 1;
    r = engineDoGame(-1);
    KeyStatus[1] = 0;
    CHECK("game.esc", r, 0);

    /* 300 frames holding RIGHT: physics + full render per frame. */
    map = engineMapLoad();
    buff = fcalloc_nw(SBUFF_ENTRIES, sizeof(TypeTileLayers));
    en = fcalloc_nw(36 * ENEM_SLOTS, sizeof(TypeEnems));
    hs = fcalloc_nw(36, sizeof(TypeHotSpots));
    engineLoadEnems(en);
    engineLoadHotSpots(hs);
    engineScreenPrepare(24, map, buff, hs);
    DQBcopyLayer(3, 2);
    engineScreenDrawLayer1(buff);
    engineInitPlayer();
    x0 = player.x;
    y0 = player.y;
    KeyStatus[0x4D] = 1;
    for (f = 0; f < 300; f++) {
        int x, y, i, s;
        if (!player.gameOver)
            engineMovePlayer(buff, map);
        if (f & 1)
            engineMoveEnems(en, buff, 24);
        engineCalcPlayerFrame(&player);
        engineCalcEnemsFrame(en, 24);
        x = DQBshiftRight(player.x, 6);
        y = DQBshiftRight(player.y, 6);
        DQBcopyLayer(2, 1);
        if (!player.gameOver) {
            s = player.sprId;
            DQBput(1, prefs.screenPos.x + x - spriteProperties[player.sprId].offX,
                prefs.screenPos.y + y - spriteProperties[player.sprId].offY,
                spriteset[s]);
        }
        for (i = 0; i < prefs.nEnems; i++) {
            if (en[24 * ENEM_SLOTS + i].t > 0) {
                s = en[24 * ENEM_SLOTS + i].sprId;
                DQBput(1, prefs.screenPos.x + en[24 * ENEM_SLOTS + i].x - spriteProperties[s].offX,
                    prefs.screenPos.y + en[24 * ENEM_SLOTS + i].y - spriteProperties[s].offY,
                    spriteset[s]);
            }
        }
        engineScreenDrawLayer2(f & 3, buff);
        engineDrawHotSpots(24, hs, hsTiles);
        enginePrintStats();
        DQBwait(1);
        DQBcopyLayer(1, VIDEO);
        if ((f % 100) == 99) {
            fprintf(logf, "walk f=%d x=%d y=%d vx=%d vy=%d lives=%d objs=%d\n",
                f + 1, player.x, player.y, player.vx, player.vy,
                player.lives, player.objects);
            fflush(logf);
        }
    }
    KeyStatus[0x4D] = 0;
    CHECK("walk.moved", player.x > x0, 1);
    CHECK("walk.alive", player.lives >= 0, 1);
    (void)y0;

    /* 100 frames idle: gravity pulls down, flicker guards. */
    engineInitPlayer();
    for (f = 0; f < 100; f++) {
        if (!player.gameOver)
            engineMovePlayer(buff, map);
        if (f & 1)
            engineMoveEnems(en, buff, 24);
    }
    CHECK("idle.fell", player.y > 1024, 1);
    CHECK("idle.alive", player.lives >= 0, 1);

    memset(KeyStatus, 0, 128);
    DQBclose();
    ffree_nw(map, 8640 * sizeof(int));
    ffree_nw(en, 36 * ENEM_SLOTS * sizeof(TypeEnems));
    ffree_nw(hs, 36 * sizeof(TypeHotSpots));
    ffree_nw(buff, SBUFF_ENTRIES * sizeof(TypeTileLayers));

    fprintf(logf, "game.done\n");
    fflush(logf);
}

/* FMENGINE.BAS port: headers hand-verified against the S3M files. */
static void test_fm(void)
{
    int v, f;
    unsigned long wr0, wr1;

    fprintf(logf, "-- fm\n");
    fflush(logf);

    CHECK("fminit", FMinit(), 1);
    /* EFFECTS.S3M: ordnum=2, insnum=30 -> effpptr = 0x60+2+60 */
    CHECK("effpptr", (int)fmdata.effpptr, 158);

    FMload("MUSIC\\G66A.S3M");
    CHECK("g66.ord", fmdata.ordnum, 10);
    CHECK("g66.ins", fmdata.insnum, 9);
    CHECK("g66.pat", fmdata.patnum, 4);
    CHECK("g66.A", fmdata.effectA, 6);
    CHECK("g66.T", fmdata.effectT, 125);
    CHECK("g66.o0", order[0], 0);
    CHECK("g66.o1", order[1], 2);

    FMload("MUSIC\\MC12.S3M");
    CHECK("mc.ord", fmdata.ordnum, 10);
    CHECK("mc.ins", fmdata.insnum, 17);
    CHECK("mc.pat", fmdata.patnum, 10);
    CHECK("mc.A", fmdata.effectA, 6);
    CHECK("mc.T", fmdata.effectT, 95);
    CHECK("mc.o0", order[0], 8);

    FMload("MUSIC\\DESORUIN.S3M");
    CHECK("de.ord", fmdata.ordnum, 32);
    CHECK("de.ins", fmdata.insnum, 13);
    CHECK("de.pat", fmdata.patnum, 9);
    CHECK("de.o0", order[0], 0);

    /* note2period goldens (DESORUIN c4spd 8383/4181, int table) */
    CHECK("n2p.a", note2period(0, 4, 1), 1707);
    CHECK("n2p.b", note2period(5, 2, 2), 10265);
    CHECK("n2p.c4z", note2period(0, 4, 0), 0);

    /* VibVal (sine peak at 16, BYREF phase reset at >= 64) */
    v = 0;
    CHECK("vib0", VibVal(&v, 0), 0);
    v = 16;
    CHECK("vib16", VibVal(&v, 0), 255);
    CHECK("vib16.nomod", v, 16);
    v = 70;
    CHECK("vib70", VibVal(&v, 0), 0);
    CHECK("vib70.reset", v, 0);
    v = 8;
    CHECK("vib1", VibVal(&v, 1), -192);
    v = 0;
    CHECK("vib1.z", VibVal(&v, 1), 0);

    /* Player progression: row 0 of G66A must sound within 3 calls.
     * (The PIT ISR is parked via FMstop so direct ticks are
     * deterministic; FMload re-arms it for the ISR test below.) */
    FMload("MUSIC\\G66A.S3M");
    FMstop();
    wr0 = fmWrites();
    for (f = 0; f < 6; f++)
        FMtimer();
    wr1 = fmWrites();
    CHECK("tick.rows", fmdata.CurOrd * 64 + fmdata.CurRow >= 1, 1);
    CHECK("tick.writes", wr1 > wr0 + 30, 1);

    /* ISR test: music playing across real timer ticks. Row 0 must
     * sound and rows must advance via the interrupt handler. */
    FMload("MUSIC\\G66A.S3M");
    wr0 = fmWrites();
    DQBwait(140);
    wr1 = fmWrites();
    CHECK("isr.rows", fmdata.CurOrd * 64 + fmdata.CurRow >= 1, 1);
    CHECK("isr.writes", wr1 > wr0 + 30, 1);
    FMstop();
    FMend();

    fprintf(logf, "fm.done\n");
    fflush(logf);
}

int engtest_run(void)
{
    logf = fopen("TESTLOG.TXT", "wt");
    if (!logf)
        logf = stdout;

    fprintf(logf, "lala engine self-test\n");

    test_render();
    test_tables();
    test_loaders();
    test_enems_hotspots();
    test_prepare();
    test_detect();
    test_frames();
    test_init_move();
    test_game();
    test_fm();

    fprintf(logf, fails ? "ENGTEST: FAIL (%d)\n" : "ENGTEST: PASS\n", fails);
    printf(fails ? "ENGTEST: FAIL (%d)\n" : "ENGTEST: PASS\n", fails);

    if (logf != stdout)
        fclose(logf);
    return fails;
}
