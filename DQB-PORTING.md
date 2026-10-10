# DirectQB C port

Watcom C reimplementation of the game-used DirectQB modules under `src/dqb/`, replacing `dqb/dqb.lib` in the default build.

## Layout

```
src/dqb/
  dqb.h, dqb_int.h     Public API and shared state/helpers
  globals.c            Library globals (was MAIN.ASM .DATA + sound shared)
  main.c               P0: init, close, layers, VGA/text, wait
  core_io.c            MapEMS, GetLayerSeg, ReadBuffer, HookInt24
  doscall.c            DOS/EMS via `intr()` (REGPACK)
  bit.c                P1: shift/bit helpers
  palette.c            P1: setPal, fadeTo, palOff
  draw.c               P2: put, get, box, setTransPut
  blending.c           P2: filterBox, createBMap, loadBMap
  font.c               P3: loadFont, xDQBprint, DQBprint (style 0)
  image.c              P3: PCX load + palette from file tail, DQBloadImage
  keyboard.c           P4: install/remove, DQBkey, xDQBinkey, INT 9 ISR
  sound.c              WAV load into EMS (`xDQBloadSound`, C far-string ABI)
  sound_drv.asm        P6: DirectQB SOUND.ASM (IRQ mixer, install/play/stop)
  dqb_alias.lnk        Linker aliases (ASM extern names ↔ C `_Foo` globals)
```

## P5 — cutover (done)

- **Single API header:** `src/dqb/dqb.h`. `src/directqb.h` is a one-line include shim for existing `#include "directqb.h"`.
- **Wrappers in-library:** `DQBloadImage` / `DQBprint` live in `image.c` and `font.c`; **`src/directqb.c` removed** from the build.
- **No PCX palette workaround:** `engineReadPcxPal()` removed from `engine.c` / `engine.h`; title, ending, backdrop, and tileset rely on `image.c` tail palette read only.
- **Orphan link experiments removed:** `wlink.lnk`, `aliases.asm`, `keystatus.asm`.

## P6 — Sound Blaster mixer (done)

- **`src/dqb/sound_drv.asm`:** Copy of `dqb/SOUND.ASM` with `xDQBloadSound` disabled (`IF 0`); mixer/install/play/stop come from ASM.
- **`src/dqb/sound.c`:** Keeps **`xDQBloadSound` only** (stdio RIFF/WAVE → EMS); avoids QB seg/off loader ABI mismatch.
- **`src/dqb/dqb_alias.lnk`:** Passed to `wcl` as `@src\dqb\dqb_alias.lnk` so Watcom ASM uppercase externs resolve to C globals (`_LastError`, `_MapEMS`, …). **`WATCOM` must be set** (see `build.bat`) or the linker pass fails.
- **`globals.c`:** Sound-only DMA/mixer locals live in `sound_drv.asm` `.DATA` (removed duplicate `DMA` / `Channels` from C).
- **Build:** `dqb\obj\SOUND_DRV.obj` from `wasm`; linked into `lala.exe`, `test.exe`, `musplay.exe`.

DOSBox: `ems=true`; set **`BLASTER`** (or pass explicit port/IRQ/DMA to `DQBinstallSB`) for SB playback.

## Build

- **Default:** `wmake` / `build.bat` links `GAMESRCS` + all `src/dqb/*.c` + `SOUND_DRV.obj` (no `dqb/dqb.lib`, no `directqb.c`).
- **Include path:** `-i=src` on `CFLAGS`.
- **Legacy ASM library:** `wmake dqblib` still builds `dqb/dqb.lib` from `dqb/*.ASM` for reference or rollback.

## Phase coverage (game scope)

| Phase | ASM sources replaced | Notes |
|-------|----------------------|--------|
| P0 | MAIN (core) | EMS init, layer copy/clear, VGA 320×200, text mode |
| P1 | BIT, PALETTE (subset) | Bit ops; full-palette set/fade/off |
| P2 | DRAW, BLENDING (subset) | Sprites, box, filter box, blender maps |
| P3 | FONT, IMAGE (PCX) | Font file; PCX decode; palette from file tail |
| P4 | KEYBOARD, SOUND (partial) | Keyboard in C; WAV load in C |
| P5 | — | Game cutover, header/wrapper cleanup |
| P6 | SOUND (mixer) | `sound_drv.asm` + `dqb_alias.lnk`; load stays in `sound.c` |

Not ported: SPRITE extras, DISK, DATAFILE, MOUSE, JOYSTICK, THREED, and most unused DQB entry points.

## PCX palette

`image.c` reads the 768-byte VGA palette from the PCX tail (`0x0C` + 768 bytes, each component `>> 2`). No engine-side reload.

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

See `PORTING.md`: ~64K code+DGROUP ceiling; stack `-k16384` on `wcl`.
