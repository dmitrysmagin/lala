
//DECLARE SUB engineInitVals (prefsStore() AS ANY)
void engineInitVals(void);

//DECLARE SUB engineLoadPrefs (id%, prefs AS ANY, prefsStore() AS ANY)
// eliminated


//DECLARE SUB engineLoadTileProperties (tileProperties() AS ANY, prefs AS ANY)
void engineLoadTileProperties();

/*
DECLARE SUB engineLoadTileset (tileset%(), prefs AS ANY)
DECLARE SUB engineLoadSpriteset (spriteset%(), prefs AS ANY)
DECLARE SUB engineScreenPrepare (nPant%, tileProperties() AS ANY, map%(), curScreenBuff() AS ANY, prefs AS ANY, hotSpots() AS ANY)
DECLARE SUB engineMapLoad (prefs AS ANY, map%())
DECLARE SUB engineScreenDrawLayer1 (tileset%(), prefs AS ANY, curScreenBuff() AS ANY)
DECLARE SUB engineScreenDrawLayer2 (frame%, tileset%(), prefs AS ANY, curScreenBuff() AS ANY)
DECLARE SUB engineInitPlayer (player AS ANY, prefs AS ANY)
DECLARE SUB engineLoadSpriteProperties (spriteProperties() AS ANY, prefs AS ANY)
DECLARE SUB engineMovePlayer (curScreenBuff() AS ANY, player AS ANY, prefs AS ANY, map%())
DECLARE SUB engineLoadSpriteMapping (spriteMapping%(), prefs AS ANY)
DECLARE SUB engineCalcPlayerFrame (player AS ANY, spriteMapping%())
DECLARE SUB engineCalcEnemsFrame (enems() AS ANY, spriteMapping%(), nPant%, prefs AS ANY)
DECLARE SUB engineLoadEnems (enems() AS ANY, prefs AS ANY)
DECLARE SUB engineLoadHotSpots (hotSpots() AS ANY, prefs AS ANY)
DECLARE SUB engineMoveEnems (enems() AS ANY, curScreenBuff() AS ANY, prefs AS ANY, player AS ANY, nPant%)
DECLARE SUB enginePrintStats (player AS ANY, prefs AS ANY, tileset%(), spriteset%())
DECLARE SUB engineRprint (Layer%, Text$, x%, y%, c%)
DECLARE SUB engineDrawHotSpots (nPant%, tileset%(), prefs AS ANY, hotSpots() AS ANY, hotSpotTiles%())
DECLARE SUB engineInitGame (prefs AS ANY)

DECLARE FUNCTION cToIdx% (x%, y%)
DECLARE FUNCTION engineMakeNumber$ (digits%, value%)
DECLARE FUNCTION engineDetectCollision% (i%, nPant%, enems() AS ANY, player AS ANY)
DECLARE FUNCTION engineDetectKeyHole% (curScreenBuff() AS ANY, map%(), xx%, yy%)
DECLARE FUNCTION engineDoGame% (prefs AS ANY, tileProperties() AS ANY, spriteProperties() AS ANY, tileset%(), spriteset%(), spriteMapping%(), flag%)

CONST MAXPREFS = 1
CONST FRONT = 1
CONST BACK = 0
CONST ANIMATED = 2
CONST CNUMSPRITES = 20

CONST DLEFT = 1
CONST DRIGHT = 2
CONST DUP = 3
CONST DDOWN = 4

CONST STATENORMAL = 0
CONST STATEFLICKER = 1
*/

typedef struct {
	int x;
	int y;
} Coordinates;

typedef struct {
	int x;		// X coordinate
	int y;		// Y coordinate
	int vx;		// speed on X
	int vy;		// speed on Y
	int frame;	// animation frame
	int facing;	// left or right?
	int subFrame;	// subframe counter
	int sprId;	// ID of current sprite in spriteset
	int gotten;	// on a platform
	int jumping;	// jumping
	int ctJump;	// for how long?
	int lives;	// player lives
	int objects;	// player objects
	int score;	// player score
	int keys;	// player keys
	int attempt;	// player wants to exit screen
	int state;
	int ctState;
	int gameOver;
} TypePlayer;

typedef struct {
	char mapFile[13];
	char tilesetFile[13];
	char backdropFile[13];
	//char tilePropertiesFile[13];
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

/*
TYPE TypeTileLayers
    layer1 AS INTEGER
    layer2 AS INTEGER
    behaviour AS INTEGER
    anim AS INTEGER
    realMapIndex AS INTEGER
END TYPE

TYPE TypeSpriteProperties
    offX AS INTEGER
    offY AS INTEGER
END TYPE

TYPE TypeHotSpots
    x AS INTEGER
    y AS INTEGER
    t AS INTEGER
    s AS INTEGER
END TYPE

TYPE TypeEnems
    x AS INTEGER
    y AS INTEGER
    x1 AS INTEGER
    y1 AS INTEGER
    x2 AS INTEGER
    y2 AS INTEGER
    mx AS INTEGER
    my AS INTEGER
    t AS INTEGER
    facing AS INTEGER
    frame AS INTEGER
    subFrame AS INTEGER
    sprId AS INTEGER
END TYPE

*/
