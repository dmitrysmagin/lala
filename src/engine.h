#ifndef _ENGINE_H_
#define _ENGINE_H_

#include <stdio.h>

/* Constants from ENGINE.BI */
#define FRONT 1
#define BACK 0
#define ANIMATED 2

#define DLEFT 1
#define DRIGHT 2
#define DUP 3
#define DDOWN 4

#define STATENORMAL 0
#define STATEFLICKER 1

/* Screen buffer: 20x12 playfield + 1-tile letterbox border all around
 * laid out as 22-wide rows: (20+2) * (12+2) - ... indexed by cToIdx,
 * max index (19+1) + (11+1)*22 = 284; QB DIMs 309 entries. */
#define SBUFF_ENTRIES 309
/* Map screens: mapW * mapH, enemies use 4 slots per screen. */
#define ENEM_SLOTS 4

typedef struct {
	int x;
	int y;
} Coordinates;

typedef struct {
	int x;		/* X coordinate */
	int y;		/* Y coordinate */
	int vx;		/* speed on X */
	int vy;		/* speed on Y */
	int frame;	/* animation frame */
	int facing;	/* left or right? */
	int subFrame;	/* subframe counter */
	int sprId;	/* ID of current sprite in spriteset */
	int gotten;	/* on a platform */
	int jumping;	/* jumping */
	int ctJump;	/* for how long? */
	int lives;	/* player lives */
	int objects;	/* player objects */
	int score;	/* player score */
	int keys;	/* player keys */
	int attempt;	/* player wants to exit screen */
	int state;
	int ctState;
	int gameOver;
} TypePlayer;

typedef struct {
	char mapFile[13];
	char tilesetFile[13];
	char backdropFile[13];
	char tilePropertiesFile[13];
	char spritePropertiesFile[13];
	char spritesetFile[13];
	char spriteMappingFile[13];
	char enemsFile[13];
	char hotSpotsFile[13];
	int mapW;
	int mapH;
	int screenW;
	int screenH;
	Coordinates screenPos;
	int numTiles;
	int numSprites;
	char pal[768];
	int gMaxVy;
	int g;
	int jumpVyInitial;
	int jumpVyMax;
	int jumpIncr;
	int walkVxMax;
	int walkAx;
	int walkFr;
	int iniPant;
	int iniTX;
	int iniTY;
	int nEnems;
	int totalEnems;
	int enemPlat;
	int boltTile;
	int lifeTile;
	int objectTile;
	int keyTile;
	int initialLives;
	int maxObjs;
	int refill;
	int hotSpotX;
	int hotSpotY;
	char bgM[13];
	int bgL1;
	int bgL2;
} TypePrefs;

typedef struct {
	int location;
	int flags;
} TypeTileProperties;

typedef struct {
	int layer1;
	int layer2;
	int behaviour;
	int anim;
	int realMapIndex;
} TypeTileLayers;

typedef struct {
	int offX, offY;
} TypeSpriteProperties;

typedef struct {
	int x;
	int y;
	int t;
	int s;
} TypeHotSpots;

typedef struct {
	int x;
	int y;
	int x1;
	int y1;
	int x2;
	int y2;
	int mx;
	int my;
	int t;
	int facing;
	int frame;
	int subFrame;
	int sprId;
} TypeEnems;

/* Shared game state (QB DIM SHARED / globals). */
extern TypePrefs prefs;
extern TypePlayer player;
extern TypeTileProperties tileProperties[60];
extern char __far *tileset[240];
extern char __far *spriteset[21];
extern int spriteMapping[64];
extern TypeSpriteProperties spriteProperties[64];

/* engine.c */
void engineInitVals(void);
void engineLoadTileProperties(void);
void engineLoadTileset(void);
void engineLoadSpriteset(void);
void engineLoadSpriteMapping(void);
void engineLoadSpriteProperties(void);
int cToIdx(int x, int y);
char *engineMakeNumber(int digits, int value);
int engineDetectCollision(int i, int nPant, TypeEnems __far *enems, TypePlayer *pl);
int engineDetectKeyHole(TypeTileLayers __far *buff, int __far *map, int xx, int yy);
void engineCalcPlayerFrame(TypePlayer *pl);
void engineCalcEnemsFrame(TypeEnems __far *enems, int nPant);
void engineLoadEnems(TypeEnems __far *enems);
void engineLoadHotSpots(TypeHotSpots __far *hs);
void engineMoveEnems(TypeEnems __far *enems, TypeTileLayers __far *buff, int nPant);
void engineMovePlayer(TypeTileLayers __far *buff, int __far *map);
void enginePrintStats(void);
void engineRprint(int layer, const char *text, int x, int y, int c);
void engineDrawHotSpots(int nPant, TypeHotSpots __far *hs, int *hsTiles);
void engineInitGame(void);
void engineInitPlayer(void);
int __far *engineMapLoad(void);
void engineScreenPrepare(int nPant, int __far *map, TypeTileLayers __far *buff, TypeHotSpots __far *hs);
void engineScreenDrawLayer1(TypeTileLayers __far *buff);
void engineScreenDrawLayer2(int frame, TypeTileLayers __far *buff);
int engineDoGame(int flag);
/* QB INPUT# numeric reader (commas/newlines/spaces as separators). */
int qbReadInt(FILE *f);

/* engtest.c (headless self-test, runs as `lala.exe test`) */
int engtest_run(void);

#endif /* _ENGINE_H_ */
