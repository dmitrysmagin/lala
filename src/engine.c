#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "directqb.h"
#include "engine.h"
#include "fmengine.h"

TypePrefs prefs;
TypePlayer player;

TypeTileProperties tileProperties[] = {
	{0,0}, {1,8}, {1,8}, {1,8}, {1,8}, {0,0}, {0,0}, {0,0}, {1,8},
	{1,8}, {1,4}, {1,4}, {0,4}, {0,4}, {0,1}, {1,8}, {1,8}, {1,8},
	{1,8}, {1,8}, {1,4}, {1,4}, {1,10}, {1,4}, {2,0}, {1,0}, {1,0},
	{1,0}, {2,0}, {1,0}, {1,0}, {1,0}, {0,4}, {1,1}, {0,0}, {0,0},
	{0,0}, {0,0}, {0,0}, {0,0}, {0,0},
};

/*
    Originally: DIM tileset%(0 TO 129, prefs.numTiles)
    FIXME: Assume we have a pointer array of max 240 tiles
*/
char *tileset[240];

/*
DEFINT A-Z

FUNCTION cToIdx% (x%, y%)
	' HUGE DISCLAIMER: This funcion has to be modified manually.
	' Sorry, this is for speed and ease of use. You can cope with it.
	' I know you can.
	'cToIdx% = (1+x%) + (1+y%) * 22
	' Optimized using shifts!
	' y*22=y*16+y*4+y*2=(ySHL4+ySHL2+ySHL1)
	yy% = 1 + y%
	cToIdx% = 1 + x% + DQBshiftLeft(yy%, 4) + DQBshiftLeft(yy%, 2) + DQBshiftLeft(yy%, 1)
END FUNCTION

SUB engineCalcEnemsFrame (enems() AS TypeEnems, spriteMapping%(), nPant%, prefs AS TypePrefs)
	FOR i% = 0 TO prefs.nEnems - 1
		IF enems(nPant%, i%).t > 0 THEN
			' Choose sprite
			enems(nPant%, i%).subFrame = enems(nPant%, i%).subFrame + 1
			IF enems(nPant%, i%).subFrame = 4 THEN
				enems(nPant%, i%).subFrame = 0
				enems(nPant%, i%).frame = (enems(nPant%, i%).frame + 1) AND 3
			END IF
			IF enems(nPant%, i%).mx + enems(nPant%, i%).my > 0 THEN enems(nPant%, i%).facing = 0 ELSE enems(nPant%, i%).facing = 4
			enems(nPant%, i%).sprId = spriteMapping%(12 + DQBshiftLeft(enems(nPant%, i%).t - 1, 3) + enems(nPant%, i%).facing + enems(nPant%, i%).frame)
		END IF
	NEXT i%
END SUB

SUB engineCalcPlayerFrame (player AS TypePlayer, spriteMapping%())
   
	' Calculate frame
	IF player.vy < 0 THEN
		player.sprId = spriteMapping%(player.facing + 4)
	ELSEIF player.vy > 0 THEN
		player.sprId = spriteMapping%(player.facing + 5)
	ELSEIF player.vx <> 0 THEN
		player.sprId = spriteMapping%(player.facing + player.frame)
		player.subFrame = player.subFrame + 1
		IF player.subFrame = 4 THEN
			player.subFrame = 0
			player.frame = player.frame + 1
			IF player.frame = 4 THEN player.frame = 0
		END IF
	ELSE
		player.sprId = spriteMapping%(player.facing)
	END IF

END SUB

FUNCTION engineDetectCollision% (i%, nPant%, enems() AS TypeEnems, player AS TypePlayer)
	x% = DQBshiftRight(player.x, 6)
	y% = DQBshiftRight(player.y, 6)
	engineDetectCollision% = ((player.state = STATENORMAL) AND (enems(nPant%, i%).x >= x% - 14 AND enems(nPant%, i%).x <= x% + 14 AND enems(nPant%, i%).y >= y% - 14 AND enems(nPant%, i%).y <= y% + 14))
END FUNCTION

FUNCTION engineDetectKeyHole% (curScreenBuff() AS TypeTileLayers, map(), xx%, yy%)
	res% = 0
	IF curScreenBuff(cToIdx%(xx%, yy%)).behaviour = 10 THEN
		curScreenBuff(cToIdx%(xx%, yy%)).layer1 = 0
		curScreenBuff(cToIdx%(xx%, yy%)).layer2 = 0
		curScreenBuff(cToIdx%(xx%, yy%)).behaviour = 0
		map%(curScreenBuff(cToIdx%(xx%, yy%)).realMapIndex) = 0
		res% = -1
	END IF
	engineDetectKeyHole% = res%
END FUNCTION

FUNCTION engineDoGame% (prefs AS TypePrefs, tileProperties() AS TypeTileProperties, spriteProperties() AS TypeSpriteProperties, tileset%(), spriteset%(), spriteMapping%(), flag%)
	' Buffer to contain current screen.
	' Screen area is 20x12, we letterbox it with blank tiles
	' This is for speed, we avoid lots of checks with this.
	DIM curScreenBuff(308) AS TypeTileLayers
	DIM map%(0)
	DIM enems(prefs.mapW * prefs.mapH - 1, 3) AS TypeEnems
	DIM hotSpots(prefs.mapW * prefs.mapH - 1) AS TypeHotSpots
	DIM hotSpotsTiles%(3)

	res% = 0
	player.gameOver = 0
	
	hotSpotsTiles%(1) = prefs.objectTile
	hotSpotsTiles%(2) = prefs.keyTile
	hotSpotsTiles%(3) = prefs.lifeTile

	lastRow% = (prefs.mapH - 1) * prefs.mapW
	lastPant% = prefs.mapH * prefs.mapW - 1

	'debug% = 1

	IF flag% THEN nPant% = prefs.iniPant ELSE nPant% = prefs.mapW * (prefs.mapH - 1)

	engineInitPlayer player, prefs

	IF flag% THEN
		DQBclearLayer 3
		i% = DQBloadImage(3, prefs.screenPos.x, prefs.screenPos.y, "GFX\" + prefs.backdropFile, prefs.pal, w%, h%)
	END IF
	engineMapLoad prefs, map%()
	engineLoadEnems enems(), prefs
	engineLoadHotSpots hotSpots(), prefs
	engineScreenPrepare nPant%, tileProperties(), map%(), curScreenBuff(), prefs, hotSpots()

	frame% = 0
	halfLife% = 0
	subFrame% = 0

	IF flag% THEN
		' ambient
		IF prefs.bgL1 THEN DQBplaySound prefs.bgL1, 5, 11025, LOOPED
		IF prefs.bgL2 THEN DQBplaySound prefs.bgL2, 6, 11025, LOOPED

		' music
		music$ = LTRIM$(prefs.bgM)
		IF music$ <> "" THEN FMload "MUSIC\" + music$
	END IF
	
	' Prepare background
	DQBcopyLayer 3, 2

	engineScreenDrawLayer1 tileset%(), prefs, curScreenBuff()
   
	DO WHILE NOT DQBkey(1)
		halfLife% = 1 - halfLife%
		subFrame% = (subFrame% + 1) AND 3
		IF subFrame% = 0 THEN frame% = frame% + 1: IF frame% = 4 THEN frame% = 0
		' Move stuff
		IF NOT player.gameOver THEN engineMovePlayer curScreenBuff(), player, prefs, map%()
		IF halfLife% THEN engineMoveEnems enems(), curScreenBuff(), prefs, player, nPant%
		' Change screen?
		IF player.attempt AND flag% THEN
			SELECT CASE player.attempt
				CASE DUP:
					IF nPant% >= prefs.mapW THEN
						nPant% = nPant% - prefs.mapW
						player.y = DQBshiftLeft(prefs.screenH - 1, 10)
					END IF
				CASE DDOWN:
					IF nPant% < lastRow% THEN
						nPant% = nPant% + prefs.mapW
						player.y = 0
					END IF
				CASE DLEFT:
					IF nPant% > 0 THEN
						nPant% = nPant% - 1
						player.x = DQBshiftLeft(prefs.screenW - 1, 10)
					END IF
				CASE DRIGHT:
					IF nPant% < lastPant% THEN
						nPant% = nPant% + 1
						player.x = 0
					END IF
			END SELECT
			engineScreenPrepare nPant%, tileProperties(), map%(), curScreenBuff(), prefs, hotSpots()
			' Prepare background
			DQBcopyLayer 3, 2
			engineScreenDrawLayer1 tileset%(), prefs, curScreenBuff()
		END IF
		' Checks
		x% = DQBshiftRight(player.x, 6)
		y% = DQBshiftRight(player.y, 6)
		IF x% >= prefs.hotSpotX - 15 AND x% <= prefs.hotSpotX + 15 AND y% >= prefs.hotSpotY - 15 AND y% <= prefs.hotSpotY + 15 THEN
			hotSpots(nPant%).s = 0
			SELECT CASE hotSpots(nPant%).t
				CASE 1:
					player.objects = player.objects + 1
					DQBplaySound 6, 4, 11025, ONCE
				CASE 2:
					player.keys = player.keys + 1
					DQBplaySound 4, 4, 11025, ONCE
				CASE 3:
					player.lives = player.lives + prefs.refill
					DQBplaySound 5, 4, 11025, ONCE
			END SELECT
			prefs.hotSpotX = 999
			prefs.hotSpotY = 999
		END IF
		' Make frames
		engineCalcPlayerFrame player, spriteMapping%()
		engineCalcEnemsFrame enems(), spriteMapping%(), nPant%, prefs
		' Render
		DQBcopyLayer 2, 1
		IF NOT player.gameOver THEN
			s% = player.sprId
			IF player.state = STATENORMAL OR halfLife% = 0 THEN
				DQBput 1, prefs.screenPos.x + x% - spriteProperties(player.sprId).offX, prefs.screenPos.y + y% - spriteProperties(player.sprId).offY, VARSEG(spriteset%(0, s%)), VARPTR(spriteset%(0, s%))
			END IF
		END IF
		FOR i% = 0 TO prefs.nEnems - 1
			IF enems(nPant%, i%).t > 0 THEN
				s% = enems(nPant%, i%).sprId
				DQBput 1, prefs.screenPos.x + enems(nPant%, i%).x - spriteProperties(s%).offX, prefs.screenPos.y + enems(nPant%, i%).y - spriteProperties(s%).offY, VARSEG(spriteset%(0, s%)), VARPTR(spriteset%(0, s%))
			END IF
		NEXT i%
		engineScreenDrawLayer2 frame%, tileset%(), prefs, curScreenBuff()
		engineDrawHotSpots nPant%, tileset%(), prefs, hotSpots(), hotSpotsTiles%()
		IF flag% THEN
			enginePrintStats player, prefs, tileset%(), spriteset%()
		ELSE
			IF player.gameOver THEN
				DQBfilterBox 1, 116, 92, 203, 107, 255, 1
				DQBprint 1, "GAME OVER", 123, 95, 0
				DQBprint 1, "GAME OVER", 124, 96, 254
			ELSE
				DQBfilterBox 1, 80, 136, 239, 151, 255, 1
				DQBprint 1, "PRESS ENTER TO PLAY", 89, 141, 0
				DQBprint 1, "PRESS ENTER TO PLAY", 88, 140, 1
			END IF
		END IF

		' Show
		DQBwait 1
		DQBcopyLayer 1, VIDEO

		' Cheat
		IF DQBkey(17) AND DQBkey(18) AND DQBkey(19) THEN
			WHILE DQBkey(17) OR DQBkey(18) OR DQBkey(19): WEND
			player.objects = player.objects + 1
		END IF

		' Exit?
		IF player.objects = prefs.maxObjs THEN res% = -1: EXIT DO
		IF player.lives < 0 THEN res% = -2: player.gameOver = -1: flag% = 0

		IF DQBkey(28) THEN IF NOT flag% THEN res% = -3: EXIT DO
	LOOP

	PLAY STOP
	BeSilent

	DQBstopVoice 5
	DQBstopVoice 6

	ERASE curScreenBuff
	ERASE map
	ERASE enems
	ERASE hotSpots
	
	engineDoGame% = res%
END FUNCTION

REM $STATIC
SUB engineDrawHotSpots (nPant%, tileset%(), prefs AS TypePrefs, hotSpots() AS TypeHotSpots, hotSpotTiles%())
	IF hotSpots(nPant%).s THEN
		nTile% = hotSpotTiles%(hotSpots(nPant%).t)
		x% = DQBshiftLeft(hotSpots(nPant%).x, 4)
		y% = DQBshiftLeft(hotSpots(nPant%).y, 4)
		DQBput 1, prefs.screenPos.x + x%, prefs.screenPos.y + y%, VARSEG(tileset%(0, nTile%)), VARPTR(tileset%(0, nTile%))
	END IF
END SUB

SUB engineInitGame (prefs AS TypePrefs)
	player.keys = 0
	player.lives = prefs.initialLives
END SUB

REM $DYNAMIC
SUB engineInitPlayer (player AS TypePlayer, prefs AS TypePrefs)
	player.x = prefs.iniTX * 16 * 64
	player.y = prefs.iniTY * 16 * 64
	player.vx = 0
	player.vy = 0
	player.frame = 0
	player.facing = 0
	player.subFrame = 0
	player.sprId = 0
	player.jumping = 0
	player.gotten = 0
	player.ctJump = 0
	player.state = STATENORMAL
	player.objects = 0
END SUB
*/

// SUB engineInitVals (prefsStore() AS TypePrefs)
void engineInitVals(void)
{
	strncpy(prefs.mapFile, "LALA.MAP", 12);
	strncpy(prefs.tilesetFile, "TILESET.PCX", 12);
	//strncpy(prefs.tilePropertiesFile, "TILEPROP.TXT", 12);
	strncpy(prefs.backdropFile, "BACKDROP.PCX", 12);
	strncpy(prefs.spritesetFile, "SPRSET.PCX", 12);
	strncpy(prefs.spritePropertiesFile, "SPRPROP.TXT", 12);
	strncpy(prefs.spriteMappingFile, "SPRMAP.TXT", 12);
	strncpy(prefs.enemsFile, "ENEMS.TXT", 12);
	strncpy(prefs.hotSpotsFile, "HOTSPOTS.TXT", 12);
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

/*
SUB engineLoadEnems (enems() AS TypeEnems, prefs AS TypePrefs)
	maxPants% = prefs.mapW * (prefs.mapH - 1) - 1
	f% = FREEFILE
	OPEN "MAP\" + prefs.enemsFile FOR INPUT AS #f%
	FOR i% = 0 TO maxPants%
		FOR j% = 0 TO 3
			INPUT #f%, enems(i%, j%).x
			INPUT #f%, enems(i%, j%).y
			INPUT #f%, enems(i%, j%).x1
			INPUT #f%, enems(i%, j%).y1
			INPUT #f%, enems(i%, j%).x2
			INPUT #f%, enems(i%, j%).y2
			INPUT #f%, enems(i%, j%).mx
			INPUT #f%, enems(i%, j%).my
			INPUT #f%, enems(i%, j%).t
		NEXT j%
	NEXT i%
	CLOSE #f%
END SUB

SUB engineLoadHotSpots (hotSpots() AS TypeHotSpots, prefs AS TypePrefs)
	maxPants% = prefs.mapW * (prefs.mapH - 1) - 1
	f% = FREEFILE
	OPEN "MAP\" + prefs.hotSpotsFile FOR INPUT AS #f%
	FOR i% = 0 TO maxPants%
		INPUT #f%, hotSpots(i%).x
		INPUT #f%, hotSpots(i%).y
		INPUT #f%, hotSpots(i%).t
		INPUT #f%, chumi%
		hotSpots(i%).s = -1
	NEXT i%
	CLOSE #f%
END SUB

SUB engineLoadSpriteMapping (spriteMapping%(), prefs AS TypePrefs)
	REDIM spriteMapping%(63)
	index% = 0
	f% = FREEFILE
	OPEN "GFX\" + prefs.spriteMappingFile FOR INPUT AS #1
	WHILE NOT EOF(f%)
		INPUT #f%, spriteMapping%(index%)
		index% = index% + 1
	WEND
	CLOSE #f%
END SUB

SUB engineLoadSpriteProperties (spriteProperties() AS TypeSpriteProperties, prefs AS TypePrefs)
	REDIM spriteProperties(63) AS TypeSpriteProperties
	f% = FREEFILE
	index% = 0
	OPEN "GFX\" + prefs.spritePropertiesFile FOR INPUT AS #f%
	WHILE NOT EOF(f%)
		INPUT #f%, spriteProperties(index%).offX
		INPUT #f%, spriteProperties(index%).offY
		index% = index% + 1
	WEND
	CLOSE #f%
	prefs.numSprites = index%
END SUB

SUB engineLoadSpriteset (spriteset%(), prefs AS TypePrefs)
	' sprites are in a 192x192 file (max 64 sprites)
	' In this game we use 6 for main sprite, 12 for enemies,
	' 2 for platforms.
	' 24x24 = 1 + 12*24 integers = 289
	numSprites% = prefs.numSprites - 1' (20-1)
	REDIM spriteset%(289, numSprites%)
	DIM dummy AS STRING * 768
	i% = DQBloadImage(3, 0, 0, "GFX\" + prefs.spritesetFile, dummy, w%, h%)
	x% = 0: y% = 0
	FOR i% = 0 TO numSprites%
		DQBget 3, x%, y%, 23 + x%, 23 + y%, VARSEG(spriteset%(0, i%)), VARPTR(spriteset%(0, i%))
		x% = x% + 24
		IF x% = 192 THEN x% = 0: y% = y% + 24
	NEXT i%
	DQBclearLayer 3
END SUB
*/

//SUB engineLoadTileProperties (tileProperties() AS TypeTileProperties, prefs AS TypePrefs)
void engineLoadTileProperties()
{
	// FIXME: load tileProperties from TILEPROP.TXT
	prefs.numTiles = sizeof(tileProperties) / sizeof(tileProperties[0]);
}

/*
SUB engineLoadTileset (tileset%(), prefs AS TypePrefs)
	REDIM tileset%(129, prefs.numTiles)
	i% = DQBloadImage(3, 0, 0, "GFX\" + prefs.tilesetFile, prefs.pal, w%, h%)
	x% = 0: y% = 0
	FOR i% = 0 TO prefs.numTiles - 1
		DQBget 3, x%, y%, 15 + x%, 15 + y%, VARSEG(tileset%(0, i%)), VARPTR(tileset%(0, i%))
		x% = x% + 16
		IF x% = 320 THEN x% = 0: y% = y% + 16
	NEXT i%
	DQBclearLayer 3
END SUB

FUNCTION engineMakeNumber$ (digits%, Value%)
	b$ = LTRIM$(STR$(Value%))
	IF LEN(b$) < digits% THEN b$ = STRING$(digits - LEN(b$), "0") + b$
	engineMakeNumber$ = b$
END FUNCTION

SUB engineMapLoad (prefs AS TypePrefs, map%())
	REDIM map%(prefs.mapW * prefs.mapH * prefs.screenW * prefs.screenH)
	DIM d AS STRING * 1
	f% = FREEFILE
	index% = 0
	OPEN "MAP\" + prefs.mapFile FOR BINARY AS #f%
	WHILE NOT EOF(f%)
		GET #f%, , d
		map%(index%) = ASC(d)
		index% = index% + 1
	WEND
	CLOSE #f%
END SUB

SUB engineMoveEnems (enems() AS TypeEnems, curScreenBuff() AS TypeTileLayers, prefs AS TypePrefs, player AS TypePlayer, nPant%)
	player.gotten = 0
	FOR i% = 0 TO prefs.nEnems - 1
		IF enems(nPant%, i%).t > 0 THEN
			' Move
			enems(nPant%, i%).x = enems(nPant%, i%).x + enems(nPant%, i%).mx
			enems(nPant%, i%).y = enems(nPant%, i%).y + enems(nPant%, i%).my
		  
			' Manage platforms
			IF enems(nPant%, i%).t = prefs.enemPlat THEN
				x% = DQBshiftRight(player.x, 6)
				y% = DQBshiftRight(player.y, 6)

				' Vertical
				IF enems(nPant%, i%).my < 0 THEN
					IF x% >= enems(nPant%, i%).x - 15 AND x% <= enems(nPant%, i%).x + 15 THEN
						IF y% >= enems(nPant%, i%).y - 16 AND y% <= enems(nPant%, i%).y - 9 THEN
							IF player.vy >= -prefs.jumpIncr THEN
								player.gotten = 1
								player.y = DQBshiftLeft(enems(nPant%, i%).y - 16, 6)
								player.vy = 0
								xx% = DQBshiftRight(x%, 4)
								yy% = DQBshiftRight(y%, 4)
								IF curScreenBuff(cToIdx%(xx%, yy%)).behaviour > 7 OR ((x% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy%)).behaviour > 7) THEN
									player.y = DQBshiftLeft(yy% + 1, 10)
								END IF
							END IF
						END IF
					END IF
				ELSEIF enems(nPant%, i%).my > 0 THEN
					IF x% >= enems(nPant%, i%).x - 15 AND x% <= enems(nPant%, i%).x + 15 THEN
						IF y% >= enems(nPant%, i%).y - 20 AND y% <= enems(nPant%, i%).y - 14 THEN
							IF player.vy >= 0 THEN
								player.gotten = 1
								player.y = DQBshiftLeft(enems(nPant%, i%).y - 16, 6)
								player.vy = 0
								xx% = DQBshiftRight(x%, 4)
								yy% = DQBshiftRight(y%, 4)
								IF curScreenBuff(cToIdx%(xx%, yy% + 1)).behaviour > 3 OR ((x% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy% + 1)).behaviour > 3) THEN
									player.y = DQBshiftLeft(yy%, 10)
								END IF
							END IF
						END IF
					END IF
				END IF
				
				' Horizontal
				IF enems(nPant%, i%).mx <> 0 THEN
					IF x% >= enems(nPant%, i%).x - 15 AND x% <= enems(nPant%, i%).x + 15 THEN
						IF y% >= enems(nPant%, i%).y - 16 AND y% <= enems(nPant%, i%).y - 11 THEN
							IF player.vy >= 0 THEN
								player.gotten = 1
								player.y = DQBshiftLeft(enems(nPant%, i%).y - 16, 6)
								x% = x% + enems(nPant%, i%).mx
								player.x = DQBshiftLeft(x%, 6)
								xx% = DQBshiftRight(x%, 4)
								yy% = DQBshiftRight(y%, 4)
								IF enems(nPant%, i%).mx < 0 THEN
									IF curScreenBuff(cToIdx%(xx%, yy%)).behaviour > 7 OR ((y% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx%, yy% + 1)).behaviour > 7) THEN
										player.vx = 0
										player.x = DQBshiftLeft(xx% + 1, 10)
									END IF
								ELSEIF enems(nPant%, i%).mx > 0 THEN
									IF curScreenBuff(cToIdx%(xx% + 1, yy%)).behaviour > 7 OR ((y% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy% + 1)).behaviour > 7) THEN
										player.vx = 0
										player.x = DQBshiftLeft(xx%, 10)
									END IF
								END IF
							END IF
						END IF
					END IF
				END IF
			ELSE
				' Detect collision
				IF engineDetectCollision(i%, nPant%, enems(), player) THEN
					player.state = STATEFLICKER
					player.ctState = 128
					' player vy, vx calculate. Repelled, double menem
					'player.vx = SGN(DQBshiftRight(player.x, 6) - enems(nPant%, i%).x) * DQBshiftRight(enems(nPant%, i%).mx, 6)
					'player.vy = SGN(DQBshiftRight(player.y, 6) - enems(nPant%, i%).y) * DQBshiftRight(enems(nPant%, i%).my, 6)
					IF enems(nPant%, i%).mx > 0 THEN player.vx = DQBshiftLeft(prefs.walkVxMax, 1) ELSE player.vx = -(DQBshiftLeft(prefs.walkVxMax, 1))
					IF enems(nPant%, i%).my > 0 THEN player.vy = DQBshiftLeft(prefs.walkVxMax, 1) ELSE player.vy = -(DQBshiftLeft(prefs.walkVxMax, 1))
					' Kill a bit
					player.lives = player.lives - 1
					DQBplaySound 2, 4, 11025, ONCE
					DQBplaySound 8, 3, 11025, ONCE
				END IF
			END IF

			' Limits
			IF enems(nPant%, i%).x = enems(nPant%, i%).x1 OR enems(nPant%, i%).x = enems(nPant%, i%).x2 THEN
				enems(nPant%, i%).mx = -enems(nPant%, i%).mx
			END IF
			IF enems(nPant%, i%).y = enems(nPant%, i%).y1 OR enems(nPant%, i%).y = enems(nPant%, i%).y2 THEN
				enems(nPant%, i%).my = -enems(nPant%, i%).my
			END IF
		END IF
	NEXT i%
END SUB

REM $STATIC
DEFSNG A-Z
SUB engineMovePlayer (curScreenBuff() AS TypeTileLayers, player AS TypePlayer, prefs AS TypePrefs, map%())
	player.attempt = 0
	' State
	IF player.state = STATEFLICKER THEN
		player.ctState = player.ctState - 1
		IF player.ctState = 0 THEN
			player.state = STATENORMAL
		END IF
	END IF

	' Vertical
	player.vy = player.vy + prefs.g
	IF player.vy > prefs.gMaxVy THEN player.vy = prefs.gMaxVy
	player.y = player.y + player.vy
	IF player.y < 0 THEN player.y = 0: player.attempt = DUP
	IF player.y > 11264 THEN player.y = 11264: player.attempt = DDOWN

	' If on movable platform...
	IF player.gotten THEN player.vy = 0
											
	y% = DQBshiftRight(player.y, 6)
	yy% = DQBshiftRight(y%, 4)
	x% = DQBshiftRight(player.x, 6)
	xx% = DQBshiftRight(x%, 4)

	' Collision? undo to tile boundary

	IF player.vy < 0 THEN
		IF curScreenBuff(cToIdx%(xx%, yy%)).behaviour > 7 OR ((x% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy%)).behaviour > 7) THEN
			player.vy = player.vy + DQBshiftRight(prefs.jumpIncr, 1)    ' 0
			player.y = DQBshiftLeft(yy% + 1, 10)
		END IF
	ELSEIF player.vy > 0 AND (y% AND 15) <= DQBshiftRight(prefs.gMaxVy, 6) THEN
		IF curScreenBuff(cToIdx%(xx%, yy% + 1)).behaviour > 3 OR ((x% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy% + 1)).behaviour > 3) THEN
			player.vy = 0
			player.y = DQBshiftLeft(yy%, 10)
		END IF
	END IF

	' Do jump (CTRL or UP)
	IF DQBkey(&H1D) OR DQBkey(&H48) THEN
		IF player.vy = 0 AND NOT player.jumping THEN
			IF player.gotten OR (curScreenBuff(cToIdx%(xx%, yy% + 1)).behaviour > 3 OR ((x% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy% + 1)).behaviour > 3)) THEN
				player.jumping = -1
				player.ctJump = 0
				DQBplaySound 3, 1, 11025 + INT(RND * 1024), ONCE
				player.x = DQBshiftLeft(x%, 6)
			END IF
		END IF
		IF player.jumping THEN
			player.vy = player.vy - (prefs.jumpVyInitial + prefs.jumpIncr - DQBshiftRight(player.ctJump, 1))
			IF player.vy < -prefs.jumpVyMax THEN player.vy = -prefs.jumpVyMax
			player.ctJump = player.ctJump + 1
			IF player.ctJump = 16 THEN
				player.jumping = 0
			END IF
		END IF
	ELSE
		player.jumping = 0
	END IF

	' Horizontal

	IF NOT (DQBkey(&H4B) OR DQBkey(&H4D)) THEN
		IF player.vx > 0 THEN
			player.vx = player.vx - prefs.walkFr
			IF player.vx < 0 THEN player.vx = 0: player.x = DQBshiftLeft(x%, 6)
		ELSEIF player.vx < 0 THEN
			player.vx = player.vx + prefs.walkFr
			IF player.vx > 0 THEN player.vx = 0: player.x = DQBshiftLeft(x%, 6)
		END IF
	END IF

	IF DQBkey(&H4B) THEN
		IF player.vx > -prefs.walkVxMax THEN
			player.facing = 6
			player.vx = player.vx - prefs.walkAx
		END IF
	END IF

	IF DQBkey(&H4D) THEN
		IF player.vx < prefs.walkVxMax THEN
			player.facing = 0
			player.vx = player.vx + prefs.walkAx
		END IF
	END IF

	player.x = player.x + player.vx
	IF player.x < 0 THEN player.x = 0: player.attempt = DLEFT
	IF player.x > 19456 THEN player.x = 19456: player.attempt = DRIGHT

	' Collision? undo to tile boundary

	y% = DQBshiftRight(player.y, 6)
	yy% = DQBshiftRight(y%, 4)
	x% = DQBshiftRight(player.x, 6)
	xx% = DQBshiftRight(x%, 4)

	IF player.vx < 0 THEN
		IF curScreenBuff(cToIdx%(xx%, yy%)).behaviour > 7 OR ((y% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx%, yy% + 1)).behaviour > 7) THEN
			player.vx = 0
			player.x = DQBshiftLeft(xx% + 1, 10)
		END IF
	ELSEIF player.vx > 0 THEN
		IF curScreenBuff(cToIdx%(xx% + 1, yy%)).behaviour > 7 OR ((y% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy% + 1)).behaviour > 7) THEN
			player.vx = 0
			player.x = DQBshiftLeft(xx%, 10)
		END IF
	ELSE
		player.x = DQBshiftLeft(x%, 6)
	END IF

	x% = DQBshiftRight(player.x, 6)
	xx% = DQBshiftRight(x%, 4)

	' Open keyhole

	IF (y% AND 15) = 0 AND (x% AND 15) = 0 AND player.keys > 0 THEN
		res% = 0
		IF DQBkey(&H4B) THEN res% = engineDetectKeyHole(curScreenBuff(), map%(), xx% - 1, yy%)
		IF DQBkey(&H4D) THEN res% = engineDetectKeyHole(curScreenBuff(), map%(), xx% + 1, yy%)
		IF res% THEN player.keys = player.keys - 1: DQBplaySound 1, 2, 11025, ONCE
	END IF
   
	' Evil tile

	IF (curScreenBuff(cToIdx%(xx%, yy%)).behaviour = 1 OR ((x% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx% + 1, yy%)).behaviour = 1) OR ((y% AND 15) <> 0 AND curScreenBuff(cToIdx%(xx%, yy% + 1)).behaviour = 1) OR ((x% AND 15) <> 0 AND (y% AND 15) <>  _
0 AND curScreenBuff(cToIdx%(xx% + 1, yy% + 1)).behaviour = 1)) THEN
		DQBplaySound 7, 4, 11025, ONCE
		IF player.state = STATENORMAL THEN
			DQBplaySound 8, 3, 11025 + INT(RND * 1024), ONCE
			player.lives = player.lives - 1
			player.state = STATEFLICKER
			player.ctState = 128
		END IF
		IF player.vy < 0 THEN
			player.vy = prefs.gMaxVy
			player.y = DQBshiftLeft(yy% + 1, 10)
		ELSE
			player.vy = -prefs.gMaxVy
			player.y = DQBshiftLeft(yy%, 10)
		END IF
	END IF

END SUB

REM $DYNAMIC
DEFINT A-Z
SUB enginePrintStats (player AS TypePlayer, prefs AS TypePrefs, tileset%(), spriteset%())
	' You'll probably have to modify this by hand for each game.
	'DQBfilterBox 1, 0, 4, 48, 52, 255, 1
	DQBput 1, 4, 4, VARSEG(tileset%(0, prefs.objectTile)), VARPTR(tileset%(0, prefs.objectTile))
	DQBput 1, 4, 20, VARSEG(tileset%(0, prefs.keyTile)), VARPTR(tileset%(0, prefs.keyTile))
	DQBput 1, 4, 36, VARSEG(tileset%(0, prefs.lifeTile)), VARPTR(tileset%(0, prefs.lifeTile))
	engineRprint 1, "x" + engineMakeNumber$(2, player.objects), 20, 4, 254
	engineRprint 1, "x" + engineMakeNumber$(2, player.keys), 20, 20, 254
	IF player.lives >= 0 THEN l% = player.lives ELSE l% = 0
	engineRprint 1, "x" + engineMakeNumber$(2, l%), 20, 36, 254
END SUB

SUB engineRprint (Layer%, Text$, x%, y%, c%)
	DQBprint Layer%, Text$, x% + 1, y% + 1, 255
	DQBprint Layer%, Text$, x%, y%, 254
END SUB

SUB engineScreenDrawLayer1 (tileset%(), prefs AS TypePrefs, curScreenBuff() AS TypeTileLayers)
	x% = 0: y% = 0
	screenPixelW% = 16 * prefs.screenW
	DQBsetTransPut
	idx% = 23 'skip letterbox
	FOR i% = 1 TO 12
		FOR j% = 1 TO 20
			id% = curScreenBuff(idx%).layer1
			IF id% THEN DQBput 2, prefs.screenPos.x + x%, prefs.screenPos.y + y%, VARSEG(tileset%(0, id%)), VARPTR(tileset%(0, id%))
			x% = x% + 16
			IF x% = screenPixelW% THEN
				x% = 0
				y% = y% + 16
			END IF
			idx% = idx% + 1
		NEXT j%
		idx% = idx% + 2 'skip border
	NEXT i%
END SUB

SUB engineScreenDrawLayer2 (frame%, tileset%(), prefs AS TypePrefs, curScreenBuff() AS TypeTileLayers)
	x% = 0: y% = 0
	screenPixelW% = 16 * prefs.screenW
	DQBsetTransPut
	idx% = 23 'skip letterbox
	FOR i% = 1 TO 12
		FOR j% = 1 TO 20
			id% = curScreenBuff(idx%).layer2
			IF curScreenBuff(idx%).anim THEN id% = id% + frame%
			IF id% THEN DQBput 1, prefs.screenPos.x + x%, prefs.screenPos.y + y%, VARSEG(tileset%(0, id%)), VARPTR(tileset%(0, id%))
			x% = x% + 16
			IF x% = screenPixelW% THEN
				x% = 0
				y% = y% + 16
			END IF
			idx% = idx% + 1
		NEXT j%
		idx% = idx% + 2 'skip border
	NEXT i%
END SUB

SUB engineScreenPrepare (nPant%, tileProperties() AS TypeTileProperties, map%(), curScreenBuff() AS TypeTileLayers, prefs AS TypePrefs, hotSpots() AS TypeHotSpots)
	ERASE curScreenBuff
	REDIM curScreenBuff(308) AS TypeTileLayers
	xPant% = nPant% MOD prefs.mapW
	yPant% = nPant% \ prefs.mapW
	mapTileWidth% = prefs.mapW * prefs.screenW
	' Calculate offset in map file

	FOR y% = 0 TO prefs.screenH - 1
		index% = (yPant% * prefs.screenH + y%) * mapTileWidth% + xPant% * prefs.screenW
		FOR x% = 0 TO prefs.screenW - 1
			' We offset +1,+1 our coordinates to make room for a
			' blank letterbox.
			'iindex% = (y% + 1) * 22 + (x% + 1)
			yy% = y% + 1
			iindex% = (x% + 1) + DQBshiftLeft(yy%, 4) + DQBshiftLeft(yy%, 2) + DQBshiftLeft(yy%, 1)
			Value% = map%(index% + x%)
			IF tileProperties(Value%).location = BACK THEN
				curScreenBuff(iindex%).layer1 = Value%
			ELSE
				curScreenBuff(iindex%).layer2 = Value%
			END IF
			IF tileProperties(Value%).location = ANIMATED THEN
				curScreenBuff(iindex%).anim = -1
			ELSE
				curScreenBuff(iindex%).anim = 0
			END IF
			curScreenBuff(iindex%).behaviour = tileProperties(Value%).flags
			curScreenBuff(iindex%).realMapIndex = index% + x%
		NEXT x%
	NEXT y%
	IF hotSpots(nPant%).s THEN
		prefs.hotSpotX = DQBshiftLeft(hotSpots(nPant%).x, 4)
		prefs.hotSpotY = DQBshiftLeft(hotSpots(nPant%).y, 4)
	ELSE
		prefs.hotSpotX = 999
		prefs.hotSpotY = 999
	END IF
END SUB

*/
