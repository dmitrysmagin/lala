DECLARE SUB engineInitVals (prefsStore() AS ANY)
DECLARE SUB engineLoadPrefs (id%, prefs AS ANY, prefsStore() AS ANY)
DECLARE SUB engineLoadTileProperties (tileProperties() AS ANY, prefs AS ANY)
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

TYPE Coordinates
    x AS INTEGER
    y AS INTEGER
END TYPE

TYPE TypePlayer
    x AS INTEGER            ' X coordinate
    y AS INTEGER            ' Y coordinate
    vx AS INTEGER           ' speed on X
    vy AS INTEGER           ' speed on Y
    frame AS INTEGER        ' animation frame
    facing AS INTEGER       ' left or right?
    subFrame AS INTEGER     ' subframe counter
    sprId AS INTEGER        ' ID of current sprite in spriteset
    gotten AS INTEGER       ' on a platform
    jumping AS INTEGER      ' jumping
    ctJump AS INTEGER       ' for how long?
    lives AS INTEGER        ' player lives
    objects AS INTEGER      ' player objects
    score AS INTEGER        ' player score
    keys AS INTEGER         ' player keys
    attempt AS INTEGER      ' player wants to exit screen
    state AS INTEGER
    ctState AS INTEGER
    gameOver AS INTEGER
END TYPE

TYPE TypePrefs
    mapFile AS STRING * 12
    tilesetFile AS STRING * 12
    backdropFile AS STRING * 12
    tilePropertiesFile AS STRING * 12
    spritePropertiesFile AS STRING * 12
    spritesetFile AS STRING * 12
    spriteMappingFile AS STRING * 12
    enemsFile AS STRING * 12
    hotSpotsFile AS STRING * 12
    mapW AS INTEGER
    mapH AS INTEGER
    screenW AS INTEGER
    screenH AS INTEGER
    screenPos AS Coordinates
    numTiles AS INTEGER
    numSprites AS INTEGER
    pal AS STRING * 768
    gMaxVy AS INTEGER
    g AS INTEGER
    jumpVyInitial AS INTEGER
    jumpVyMax AS INTEGER
    jumpIncr AS INTEGER
    walkVxMax AS INTEGER
    walkAx AS INTEGER
    walkFr AS INTEGER
    iniPant AS INTEGER
    iniTX AS INTEGER
    iniTY AS INTEGER
    nEnems AS INTEGER
    totalEnems AS INTEGER
    enemPlat AS INTEGER
    boltTile AS INTEGER
    lifeTile AS INTEGER
    objectTile AS INTEGER
    keyTile AS INTEGER
    initialLives AS INTEGER
    maxObjs AS INTEGER
    refill AS INTEGER
    hotSpotX AS INTEGER
    hotSpotY AS INTEGER
    bgM AS STRING * 12
    bgL1 AS INTEGER
    bgL2 AS INTEGER
END TYPE

TYPE TypeTileProperties
    location AS INTEGER
    flags AS INTEGER
END TYPE

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

