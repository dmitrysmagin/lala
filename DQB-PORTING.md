# DirectQB C port (P0–P4)

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
  font.c               P3: loadFont, xDQBprint (style 0)
  image.c              P3: PCX load + palette from file tail
  keyboard.c           P4: install/remove, DQBkey, xDQBinkey, INT 9 ISR
  sound.c              P4: install/remove, load WAV → EMS; play stubbed
```

Game-facing headers unchanged in spirit: `src/directqb.h` includes `src/dqb/dqb.h`; `src/directqb.c` keeps `DQBloadImage` / `DQBprint` wrappers.

## Build

- **Default:** `wmake` / `build.bat` links `GAMESRCS` + all `src/dqb/*.c` (no `dqb/dqb.lib`).
- **Include path:** `-i=src` on `CFLAGS` so `#include "dqb/dqb.h"` resolves.
- **Legacy ASM library:** `wmake dqblib` still builds `dqb/dqb.lib` from `dqb/*.ASM` for reference or rollback.

## Phase coverage (game scope)

| Phase | ASM sources replaced | Notes |
|-------|----------------------|--------|
| P0 | MAIN (core) | EMS init, layer copy/clear, VGA 320×200, text mode |
| P1 | BIT, PALETTE (subset) | Bit ops; full-palette set/fade/off |
| P2 | DRAW, BLENDING (subset) | Sprites, box, filter box, blender maps |
| P3 | FONT, IMAGE (PCX) | Font file; PCX decode; **768-byte palette from last 769 bytes of file** |
| P4 | KEYBOARD, SOUND (partial) | Keyboard complete in C; **sound load only** |

Not ported in this cutover: SPRITE extras, DISK, DATAFILE, MOUSE, JOYSTICK, THREED, and most unused DQB entry points.

## PCX palette

Original DQB PCX decode could run past the palette block and leave caller buffers zero. `image.c` reloads palette from the PCX tail (`0x0C` + 768 bytes, VGA `>> 2`), matching the workaround in `engineReadPcxPal()` in `src/engine.c`.

After verifying title/backdrop/tileset in DOSBox, remove `engineReadPcxPal` calls from `engine.c` and `lala.c`.

## Sound (P4 gap)

- **`xDQBloadSound`:** Reads RIFF/WAVE payload into EMS at the slot page (simplified parser).
- **`DQBinstallSB` / `DQBplaySound` / `DQBstopVoice`:** Stubs — no Sound Blaster IRQ/DMA mixer yet; game runs but SFX/ambient will not audibly play until `dqb/SOUND.ASM` is re-linked (with C↔ASM symbol aliases) or the mixer is ported to C.

## Keyboard / KeyStatus

- `KeyStatus[128]` lives in `globals.c` as a normal C symbol (`_KeyStatus`).
- Tests and `--autoplay` poke `KeyStatus` directly (`tests/engtest.c`, `src/lala.c`).
- Old `#pragma aux KeyStatus "KEYSTATUS"` was dropped; engtest uses the same `KeyStatus` name via `directqb.h`.

## Calling convention

Exported game APIs use `__far __pascal` (`DQBAPI` in `dqb.h`), same as the previous `directqb.h` bindings.

Internal ASM-compatible names for a future `SOUND.OBJ` link were prepared (`_MapEMS`, `_ReadBuffer`, etc. in `core_io.c`); a working `wlink` alias file was not finalized — full SB link remains TODO.

## Orphan / optional cleanup

These were experiments and are **not** used by the current build:

- `src/dqb/wlink.lnk`
- `src/dqb/aliases.asm`
- `src/dqb/keystatus.asm`

Safe to delete when no longer needed.

## Verification checklist

1. `build.bat` → `bin/lala.exe`, `bin/test.exe`, `bin/musplay.exe`.
2. `bin/test.exe test` (engtest + scripted `KeyStatus`).
3. DOSBox: title screen palette (`GFX\TITLE.PCX`), in-game backdrop/tileset, one playthrough.
4. Confirm `LOG.TXT` / visuals without relying on `engineReadPcxPal`.
5. Re-enable audio: port or link `SOUND.ASM`, then exercise SFX slots 1–10 and looped ambient on voices 5–6.

## Constraints

See `PORTING.md`: ~64K code+DGROUP ceiling; watch exe size after the C DQB replace. Stack remains `-k16384` on `wcl`.
