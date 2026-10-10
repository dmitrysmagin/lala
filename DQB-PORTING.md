# DirectQB C port

Watcom C reimplementation of DirectQB 1.61 under `src/dqb/`, replacing `dqb/dqb.lib` in the default build.

## Layout

```
src/dqb/
  dqb.h, dqb_int.h     Public API and shared state/helpers
  globals.c            Library globals (was MAIN.ASM .DATA + sound shared)
  main.c               P0: init, close, layers, VGA/text, wait
  main_extra.c         P7: ver/mapLayer/error/sort/angle/frameRate/baseLayer/peek/poke/FPU
  core_io.c            MapEMS, GetLayerSeg, Read/WriteBuffer, ResetJoy, HookInt24
  doscall.c            DOS/EMS via `intr()` (REGPACK)
  bit.c                BIT: set/reset/read/toggle/shiftLeft/shiftRight
  palette.c            PALETTE: full 12 entry points
  draw.c               DRAW: full 16 entry points
  sprite.c             SPRITE: full 14 entry points
  blending.c           BLENDING: full 9 entry points
  font.c               FONT: full 10 entry points (styles/texture/blend/bold/italic)
  image.c              IMAGE: BSV/BMP/PCX load, save, FLI play/open/close/step
  keyboard.c           KEYBOARD: full 7 entry points, INT 9 ISR
  sound.c              SOUND: full 12 entry points, SB IRQ mixer
  disk.c               DISK: full 6 entry points
  datafile.c           DATAFILE: full 10 entry points
  mouse.c              MOUSE: full 12 entry points (INT 33h)
  joystick.c           JOYSTICK: full 8 entry points (port 201h)
  threed.c             THREED: full 8 entry points (flat/gouraud/textured/filtered)
```

## P5 — cutover (done)

- **Single API header:** `src/dqb/dqb.h`. `src/directqb.h` is a one-line include shim for existing `#include "directqb.h"`.
- **Wrappers in-library:** `DQBloadImage` / `DQBprint` live in `image.c` and `font.c`; **`src/directqb.c` removed** from the build.
- **No PCX palette workaround:** `engineReadPcxPal()` removed from `engine.c` / `engine.h`; title, ending, backdrop, and tileset rely on `image.c` tail palette read only.
- **Orphan link experiments removed:** `wlink.lnk`, `aliases.asm`, `keystatus.asm`.

## P6 — Sound Blaster mixer (C)

- **`src/dqb/sound.c`:** `xDQBloadSound` (stdio RIFF/WAVE → EMS) plus `DQBinstallSB` / `DQBplaySound` / `DQBstopVoice` / `DQBremoveSB`, plus `xDQBloadRawSound`, `DQBinUse`, `DQBpauseSound`, `DQBresumeSound`, `DQBsetVoiceVol`, `DQBsetFreq`, `DQBsetVolume`.
- Mixer, DSP, DMA, and BLASTER parse are C; `_asm` is only the ISR’s EMS save/map/restore (`INT 67h`).
- Default build is C-only (no `SOUND_DRV.obj`, no `dqb_alias.lnk`).

DOSBox: `ems=true`; set **`BLASTER`** (or pass explicit port/IRQ/DMA to `DQBinstallSB`) for SB playback.

## P7 — remainder (done, this change)

- **MAIN:** `DQBver`, `DQBmapLayer`, `xDQBerror`, `DQBsort`, `DQBangle` (FPU → `atan2`), `DQBsetFrameRate`/`DQBframeReady` (PIT + INT 8), `DQBsetBaseLayer`, `DQBpeek`/`DQBpoke` (INT 67h AH=57h), `DQBFPU`/`DQBINT3D` (no-op), `WriteBuffer`, `ResetJoy`; `DQBclose` now restores timer, FLI, pack.
- **BIT:** added `DQBresetBit`, `DQBtoggleBit`; shifts emulate ASM double-`SHL AX,CL`.
- **PALETTE:** all 12 (`setCol/getCol/findCol/findPalCol/setPal/getPal/fadeIn/fadeStepIn/fadeTo/fadeStepTo/palOff/palRotate`).
- **DRAW:** all 16 (`copyTransLayer/copyHitLayer/pset/point/line/gline/ellipse/box/boxf/paint/scroll/scrollArea/setTransPut/setSolidPut/get/put`).
- **SPRITE:** all 14 (`size/setClipBox/sPut/rPut/fPut/xPut/mPut/hPut/tPut/pPut/putOver/collide/collideOnLayer/setCollideMethod`); `ResetJoy` index bug fixed (`JoyCX[1]` not `[2]`).
- **BLENDING:** all 9 + fixed `filterBox` OOR (writes `Col`) and `createBMap` layout (`fore*256+bg`); added `bPut/copyBlendLayer/setBMap/getBMap/saveBMap/removeBMap` with `LastError`.
- **FONT:** full `xDQBprint` (solid/underline/bold/italic/blend/texture/center `x=8000h`, `CharSpacing`) + `setFontTexture/setTextSpacing/len/setBIOSfont/setFont/setTextBackCol/setTextBMap/setTextStyle`.
- **IMAGE:** BSV + BMP branches, `xDQBsaveImage` (BSV/BMP/PCX), FLI (`playFLI/openFLI/closeFLI/playFLIstep` + COLOR/BRUN/LC/COPY/BLACK decode).
- **KEYBOARD:** added `DQBreadKey/DQBwaitKey/DQBasc`.
- **DISK/DATAFILE/MOUSE/JOYSTICK/THREED:** full ports; `dqb/dqb.lib` retained only via `wmake dqblib` for reference.

## Build

- **Default:** `wmake` / `build.bat` links `GAMESRCS` + all `src/dqb/*.c` (no `dqb/dqb.lib`).
- **Include path:** `-i=src` on `CFLAGS`.
- **Legacy ASM library:** `wmake dqblib` still builds `dqb/dqb.lib` from `dqb/*.ASM` for reference or rollback.

## Phase coverage (full library)

| Phase | ASM sources replaced | Notes |
|-------|----------------------|--------|
| P0 | MAIN (core + extras) | EMS init, layers, VGA/text, timer, base layers, peek/poke, sort/angle |
| P1 | BIT, PALETTE (full) | Bit ops; full palette set/get/find/fade/rotate |
| P2 | DRAW, BLENDING, SPRITE (full) | Primitives, sprites, filter box, blender maps |
| P3 | FONT, IMAGE (full) | Font styles; BSV/BMP/PCX + save; FLI |
| P4 | KEYBOARD, SOUND (full) | Keyboard + SB mixer/voices/volumes |
| P5 | — | Game cutover, header/wrapper cleanup |
| P6 | SOUND (mixer) | C in `sound.c`; `_asm` INT 67h in the SB ISR |
| P7 | DISK, DATAFILE, MOUSE, JOYSTICK, THREED | Remainder; C-only default build |

## PCX palette

`image.c` reads the palette inline after pixels (`0x0C` + 768 bytes, each component `>> 2`), matching ASM (no `SEEK_END` fallback). BSV palette appended check (`filesize != len+7`) and BMP `B,G,R,0` quads likewise.

## Keyboard / KeyStatus

- `KeyStatus[128]` in `globals.c` (`_KeyStatus` at link time).
- Tests and `--autoplay` poke `KeyStatus` directly.

## Calling convention

- DQB exports: `__far __pascal` (`DQBAPI` in `dqb.h`).
- **`DQBloadImage` / `DQBprint`:** cdecl (same as the old `directqb.c` wrappers).

## Verification checklist

1. `build.bat` → `bin/lala.exe`, `bin/test.exe`, `bin/musplay.exe`.
2. `bin/test.exe test`.
3. DOSBox: title, backdrop, tileset palettes; short playthrough.
4. DOSBox audio: `BLASTER` env, SFX + looped ambient (`DQBinstallSB(0, 6, 11025, AUTO, AUTO, AUTO)` in `lala.c`).

## Constraints

See `PORTING.md`: ~64K code+DGROUP ceiling; stack `-k16384` on `wcl`. P7 adds ~15 new TUs — watch `bin\lala.map` CODE+DGROUP size after `wmake`.
